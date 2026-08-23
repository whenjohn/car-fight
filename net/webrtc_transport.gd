extends Node
## WebRTC transport bootstrap for g2's authoritative client/server topology.
##
## The WebSocket in this file is SIGNALING ONLY: it carries peer ids, SDP and
## ICE candidates. Once negotiation completes, Godot MultiplayerAPI traffic
## travels exclusively over WebRTC DataChannels. The authoritative server is
## peer 1 and every client creates exactly one WebRTC connection, to peer 1.

signal failed(message: String)
signal multiplayer_peer_ready(peer: MultiplayerPeer)

const TYPE_ID := "id"
const TYPE_ID_ACK := "id_ack"
const TYPE_OFFER := "offer"
const TYPE_ANSWER := "answer"
const TYPE_CANDIDATE := "candidate"
const MAX_SIGNAL_MESSAGE := 1024 * 1024
const CHANNEL_TELEMETRY_INTERVAL_MSEC := 1000

class SignalPeer extends RefCounted:
	var id: int
	var announced := false
	var id_acked := false
	var last_id_sent_msec := 0
	var remote_candidates := 0
	var local_candidates := 0
	var remote_offer_received := false
	var local_answer_sent := false
	var ws := WebSocketPeer.new()

	func _init(peer_id: int, stream: StreamPeer) -> void:
		id = peer_id
		ws.inbound_buffer_size = MAX_SIGNAL_MESSAGE
		ws.outbound_buffer_size = MAX_SIGNAL_MESSAGE
		ws.accept_stream(stream)

var _mode := ""
var _rtc := WebRTCMultiplayerPeer.new()
var _tcp := TCPServer.new()
var _server_signal_peers := {}
var _client_signal := WebSocketPeer.new()
var _client_signal_open := false
var _client_id := 0
var _next_peer_id := 2
var _ice_servers: Array = []
var _relay_only := false
var _unreliable_lifetime_ms := 1
var _channel_telemetry_enabled := false
var _last_channel_telemetry_msec := 0
## Server-only peer-id reservation hook used by the integrated ENet+WebRTC mux. The WebRTC
## allocator already skips its own live ids; this adds the other transport's live table.
var _peer_id_reserved := Callable()
## HARNESS ONLY: returns an exact id to assign before the normal allocator. Used to
## prove the mux collision kick with a live ENet id.
var _forced_peer_id_provider := Callable()
var _expected_failure_quiet := false


func set_peer_id_reserved_provider(provider: Callable) -> void:
	_peer_id_reserved = provider


func set_forced_peer_id_provider(provider: Callable) -> void:
	_forced_peer_id_provider = provider


func set_expected_failure_quiet(enabled: bool) -> void:
	_expected_failure_quiet = enabled


func start_server(signaling_port: int, ice_servers: Array, relay_only := false,
		unreliable_lifetime_ms := 1, channel_telemetry_enabled := false) -> MultiplayerPeer:
	_mode = "server"
	_ice_servers = ice_servers.duplicate(true)
	_relay_only = relay_only
	_unreliable_lifetime_ms = clampi(unreliable_lifetime_ms, 1, 65534)
	_channel_telemetry_enabled = channel_telemetry_enabled
	var err := _rtc.create_server()
	if err != OK:
		_fail("WebRTC create_server failed: %s" % error_string(err))
		return null
	err = _tcp.listen(signaling_port, "*")
	if err != OK:
		_fail("WebRTC signaling listen on :%d failed: %s" % [signaling_port, error_string(err)])
		return null
	print("[webrtc] authoritative peer=1 signaling=ws://0.0.0.0:%d gameplay=WebRTC" % signaling_port)
	return _rtc


func start_client(signaling_url: String, ice_servers: Array, relay_only := false,
		unreliable_lifetime_ms := 1, channel_telemetry_enabled := false) -> MultiplayerPeer:
	_mode = "client"
	_ice_servers = ice_servers.duplicate(true)
	_relay_only = relay_only
	_unreliable_lifetime_ms = clampi(unreliable_lifetime_ms, 1, 65534)
	_channel_telemetry_enabled = channel_telemetry_enabled
	_client_signal.inbound_buffer_size = MAX_SIGNAL_MESSAGE
	_client_signal.outbound_buffer_size = MAX_SIGNAL_MESSAGE
	var err := _client_signal.connect_to_url(signaling_url)
	if err != OK:
		_fail("WebRTC signaling connect to %s failed: %s" % [signaling_url, error_string(err)])
		return null
	print("[webrtc] signaling connecting to %s; gameplay will use WebRTC DataChannels" % signaling_url)
	# The MultiplayerAPI peer becomes usable after signaling assigns this client
	# an id and create_client() is called. Main may assign it now; it remains in
	# CONNECTION_CONNECTING until the server DataChannels open.
	return _rtc


func close() -> void:
	_tcp.stop()
	for signal_peer: SignalPeer in _server_signal_peers.values():
		signal_peer.ws.close()
	_server_signal_peers.clear()
	_client_signal.close()
	_rtc.close()


func reject_server_peer(peer_id: int, reason: String) -> void:
	if _server_signal_peers.has(peer_id):
		var signal_peer: SignalPeer = _server_signal_peers[peer_id]
		signal_peer.ws.close(4001, reason)
	if _rtc.has_peer(peer_id):
		_rtc.remove_peer(peer_id)


func _process(_delta: float) -> void:
	if _mode == "server":
		_poll_server_signaling()
	elif _mode == "client":
		_poll_client_signaling()
	if _channel_telemetry_enabled:
		_log_channel_telemetry()


## Total bytes currently queued toward one peer, summed across that peer's data channels. The channels share
## one SCTP association and congestion window, so the sum is the honest send-pressure signal for StateBundle's
## dispatch backpressure. Unknown peers report 0.
##
## Non-positive ids follow MultiplayerPeer target semantics: 0 broadcasts to every peer and -N to every peer
## except N. A broadcast queues on each link independently, so its honest pressure is the WORST link's — the
## first valve wiring passed the raw rpc target id straight through, has_peer(0) was false, pressure read 0
## forever, and the input valve sat dead while the browser queued 113KB (2026-07-19 inputbp run).
func peer_buffered_bytes(peer_id: int) -> int:
	if _rtc == null:
		return 0
	if peer_id > 0:
		if not _rtc.has_peer(peer_id):
			return 0
		return _peer_channel_buffered(_rtc.get_peer(peer_id))
	var worst := 0
	for other: int in _rtc.get_peers():
		if peer_id < 0 and other == -peer_id:
			continue
		worst = maxi(worst, _peer_channel_buffered(_rtc.get_peer(other)))
	return worst


## A DataChannel can close one frame before WebRTCMultiplayerPeer emits peer_disconnected.
## The mux consults this before each exact send so that teardown window drops cleanly.
func peer_can_send(peer_id: int) -> bool:
	if _rtc == null or not _rtc.has_peer(peer_id):
		return false
	var channels: Array = _rtc.get_peer(peer_id).get("channels", [])
	if channels.is_empty():
		return false
	for channel: WebRTCDataChannel in channels:
		if channel.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
			return false
	return true


func _peer_channel_buffered(peer: Dictionary) -> int:
	var total := 0
	for channel: WebRTCDataChannel in peer.get("channels", []):
		total += channel.get_buffered_amount()
	return total


func _log_channel_telemetry() -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_channel_telemetry_msec < CHANNEL_TELEMETRY_INTERVAL_MSEC:
		return
	_last_channel_telemetry_msec = now_msec
	for peer_id: int in _rtc.get_peers():
		var peer: Dictionary = _rtc.get_peer(peer_id)
		var connection: WebRTCPeerConnection = peer.connection
		var signal_peer: SignalPeer = _server_signal_peers.get(peer_id) \
			if _mode == "server" else null
		print("[webrtc-connection] mode=%s peer=%d connection=%d gathering=%d signaling=%d remote_candidates=%d local_candidates=%d remote_offer=%s local_answer=%s" % [
			_mode, peer_id, connection.get_connection_state(), connection.get_gathering_state(),
			connection.get_signaling_state(), signal_peer.remote_candidates if signal_peer else -1,
			signal_peer.local_candidates if signal_peer else -1,
			str(signal_peer.remote_offer_received) if signal_peer else "n/a",
			str(signal_peer.local_answer_sent) if signal_peer else "n/a",
		])
		for channel: WebRTCDataChannel in peer.get("channels", []):
			print("[webrtc-channel] mode=%s peer=%d label=%s state=%s buffered_bytes=%d selected_lifetime_ms=%s reported_lifetime_ms=%s" % [
				_mode, peer_id, channel.get_label(), _channel_state_name(channel.get_ready_state()),
				channel.get_buffered_amount(), _selected_channel_lifetime(channel),
				_reported_channel_lifetime(channel),
			])


func _channel_state_name(state: WebRTCDataChannel.ChannelState) -> String:
	match state:
		WebRTCDataChannel.STATE_CONNECTING:
			return "connecting"
		WebRTCDataChannel.STATE_OPEN:
			return "open"
		WebRTCDataChannel.STATE_CLOSING:
			return "closing"
		WebRTCDataChannel.STATE_CLOSED:
			return "closed"
	return "unknown(%d)" % state


func _selected_channel_lifetime(channel: WebRTCDataChannel) -> String:
	return "unbounded" if channel.get_label() == "reliable" else str(_unreliable_lifetime_ms)


func _reported_channel_lifetime(channel: WebRTCDataChannel) -> String:
	var lifetime := channel.get_max_packet_life_time()
	if lifetime < 0:
		return "unavailable"
	return "unbounded" if lifetime == 65535 else str(lifetime)


func _poll_server_signaling() -> void:
	while _tcp.is_connection_available():
		var id := _allocate_peer_id()
		_server_signal_peers[id] = SignalPeer.new(id, _tcp.take_connection())

	var remove: Array[int] = []
	for id: int in _server_signal_peers:
		var signal_peer: SignalPeer = _server_signal_peers[id]
		signal_peer.ws.poll()
		var state := signal_peer.ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN and not signal_peer.announced:
			signal_peer.announced = true
			var err := _create_connection(id, false)
			if err != OK:
				remove.push_back(id)
				continue
			print("[webrtc] signaling assigned peer=%d" % id)
		# A reverse proxy can finish its upstream WebSocket transition just after
		# Godot reports OPEN. Retry this tiny assignment until the browser ACKs;
		# SDP/ICE remains unchanged and gameplay never uses this socket.
		var now_msec := Time.get_ticks_msec()
		if state == WebSocketPeer.STATE_OPEN and signal_peer.announced and not signal_peer.id_acked and \
				now_msec - signal_peer.last_id_sent_msec >= 500:
			_send(signal_peer.ws, {"type": TYPE_ID, "id": id})
			signal_peer.last_id_sent_msec = now_msec
		while state == WebSocketPeer.STATE_OPEN and signal_peer.ws.get_available_packet_count() > 0:
			if not _parse_server_message(signal_peer, signal_peer.ws.get_packet()):
				signal_peer.ws.close(4000, "invalid signaling message")
				break
		if signal_peer.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			# Losing signaling after ICE completes does not kill gameplay. Before
			# DataChannels connect, however, this peer can never finish joining.
			if _rtc.has_peer(id) and not bool(_rtc.get_peer(id).get("connected", false)):
				_rtc.remove_peer(id)
			remove.push_back(id)
	for id in remove:
		_server_signal_peers.erase(id)


func _poll_client_signaling() -> void:
	_client_signal.poll()
	var state := _client_signal.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _client_signal_open:
		_client_signal_open = true
		print("[webrtc] signaling open")
	while state == WebSocketPeer.STATE_OPEN and _client_signal.get_available_packet_count() > 0:
		if not _parse_client_message(_client_signal.get_packet()):
			_client_signal.close(4000, "invalid signaling message")
			_fail("WebRTC signaling server sent an invalid message")
			return
	if _client_signal_open and state == WebSocketPeer.STATE_CLOSED:
		var gameplay_connected := _client_id > 0 and _rtc.has_peer(1) \
			and bool(_rtc.get_peer(1).get("connected", false))
		if not gameplay_connected:
			_fail("WebRTC signaling closed before gameplay connected")


func _parse_server_message(signal_peer: SignalPeer, packet: PackedByteArray) -> bool:
	var msg = JSON.parse_string(packet.get_string_from_utf8())
	if typeof(msg) != TYPE_DICTIONARY or typeof(msg.get("type")) != TYPE_STRING:
		return false
	var kind: String = msg.type
	if kind == TYPE_ID_ACK and typeof(msg.get("id")) == TYPE_FLOAT and int(msg.id) == signal_peer.id:
		signal_peer.id_acked = true
		return true
	if kind == TYPE_OFFER and typeof(msg.get("sdp")) == TYPE_STRING:
		signal_peer.id_acked = true
		signal_peer.remote_offer_received = true
		return _set_remote_description(signal_peer.id, "offer", msg.sdp)
	if kind == TYPE_CANDIDATE:
		signal_peer.remote_candidates += 1
		return _add_candidate(signal_peer.id, msg)
	return false


func _parse_client_message(packet: PackedByteArray) -> bool:
	var msg = JSON.parse_string(packet.get_string_from_utf8())
	if typeof(msg) != TYPE_DICTIONARY or typeof(msg.get("type")) != TYPE_STRING:
		return false
	var kind: String = msg.type
	if kind == TYPE_ID and typeof(msg.get("id")) == TYPE_FLOAT:
		var assigned_id := int(msg.id)
		if _client_id != 0:
			if assigned_id != _client_id:
				return false
			_send(_client_signal, {"type": TYPE_ID_ACK, "id": _client_id})
			return true
		_client_id = assigned_id
		var err := _rtc.create_client(_client_id)
		if err != OK:
			_fail("WebRTC create_client(%d) failed: %s" % [_client_id, error_string(err)])
			return false
		err = _create_connection(MultiplayerPeer.TARGET_PEER_SERVER, true)
		if err == OK:
			_send(_client_signal, {"type": TYPE_ID_ACK, "id": _client_id})
			multiplayer_peer_ready.emit(_rtc)
		return err == OK
	if kind == TYPE_ANSWER and typeof(msg.get("sdp")) == TYPE_STRING:
		return _set_remote_description(MultiplayerPeer.TARGET_PEER_SERVER, "answer", msg.sdp)
	if kind == TYPE_CANDIDATE:
		return _add_candidate(MultiplayerPeer.TARGET_PEER_SERVER, msg)
	return false


func _create_connection(peer_id: int, make_offer: bool) -> Error:
	var connection := WebRTCPeerConnection.new()
	var config := {}
	if not _ice_servers.is_empty():
		config["iceServers"] = _ice_servers
	if _relay_only:
		# Godot Web forwards this standard RTCConfiguration key to the browser.
		# The native plugin ignores unknown keys; candidate filtering below is
		# retained as the portable signaling-side backstop.
		config["iceTransportPolicy"] = "relay"
	print("[webrtc] initializing peer=%d ice_servers=%d relay_only=%s credentials=%s unreliable_lifetime_ms=%d" % [
		peer_id, _ice_servers.size(), str(_relay_only),
		str(not _ice_servers.is_empty() and _ice_servers[0].has("credential")),
		_unreliable_lifetime_ms,
	])
	var err := connection.initialize(config)
	if err != OK:
		_fail("WebRTC initialize peer=%d failed: %s" % [peer_id, error_string(err)])
		return err
	connection.session_description_created.connect(_on_session_description.bind(peer_id))
	connection.ice_candidate_created.connect(_on_ice_candidate.bind(peer_id))
	err = _rtc.add_peer(connection, peer_id, _unreliable_lifetime_ms)
	if err != OK:
		_fail("WebRTC add_peer(%d) failed: %s" % [peer_id, error_string(err)])
		return err
	if make_offer:
		err = connection.create_offer()
		if err != OK:
			_fail("WebRTC create_offer failed: %s" % error_string(err))
	return err


func _on_session_description(kind: String, sdp: String, peer_id: int) -> void:
	if not _rtc.has_peer(peer_id):
		return
	var connection: WebRTCPeerConnection = _rtc.get_peer(peer_id).connection
	if _relay_only:
		sdp = _relay_candidates_only(sdp)
	var err := connection.set_local_description(kind, sdp)
	if err != OK:
		_fail("WebRTC set_local_description(%s) failed: %s" % [kind, error_string(err)])
		return
	var msg := {"type": kind, "sdp": sdp}
	if _mode == "server":
		var signal_peer: SignalPeer = _server_signal_peers.get(peer_id)
		if signal_peer:
			if kind == "answer":
				signal_peer.local_answer_sent = true
			_send(signal_peer.ws, msg)
	else:
		_send(_client_signal, msg)


func _on_ice_candidate(mid: String, index: int, candidate: String, peer_id: int) -> void:
	if _relay_only:
		var relay_candidate := " typ relay" in candidate
		if not relay_candidate:
			return
	var msg := {
		"type": TYPE_CANDIDATE,
		"mid": mid,
		"index": index,
		"candidate": candidate,
	}
	if _mode == "server":
		var signal_peer: SignalPeer = _server_signal_peers.get(peer_id)
		if signal_peer:
			signal_peer.local_candidates += 1
			_send(signal_peer.ws, msg)
	else:
		_send(_client_signal, msg)


func _relay_candidates_only(sdp: String) -> String:
	var kept := PackedStringArray()
	for line in sdp.split("\n"):
		if not line.begins_with("a=candidate:") or " typ relay " in line:
			kept.push_back(line)
	return "\n".join(kept)


func _set_remote_description(peer_id: int, kind: String, sdp: String) -> bool:
	if not _rtc.has_peer(peer_id):
		return false
	var connection: WebRTCPeerConnection = _rtc.get_peer(peer_id).connection
	var err := connection.set_remote_description(kind, sdp)
	if err != OK:
		_fail("WebRTC set_remote_description(%s) failed: %s" % [kind, error_string(err)])
	return err == OK


func _add_candidate(peer_id: int, msg: Dictionary) -> bool:
	if not _rtc.has_peer(peer_id) or typeof(msg.get("mid")) != TYPE_STRING or \
			typeof(msg.get("index")) != TYPE_FLOAT or typeof(msg.get("candidate")) != TYPE_STRING:
		return false
	var connection: WebRTCPeerConnection = _rtc.get_peer(peer_id).connection
	var err := connection.add_ice_candidate(msg.mid, int(msg.index), msg.candidate)
	if err != OK:
		_fail("WebRTC add_ice_candidate failed: %s" % error_string(err))
	return err == OK


func _send(ws: WebSocketPeer, msg: Dictionary) -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var err := ws.send_text(JSON.stringify(msg))
	if err != OK:
		_fail("WebRTC signaling send failed: %s" % error_string(err))


func _allocate_peer_id() -> int:
	if _forced_peer_id_provider.is_valid():
		var forced := int(_forced_peer_id_provider.call())
		if forced > 1 and not _server_signal_peers.has(forced) and not _rtc.has_peer(forced):
			print("[webrtc-test] forcing peer id=%d" % forced)
			return forced
	while _server_signal_peers.has(_next_peer_id) or _rtc.has_peer(_next_peer_id) \
			or (_peer_id_reserved.is_valid() and bool(_peer_id_reserved.call(_next_peer_id))):
		_next_peer_id += 1
		if _next_peer_id > 2147483647:
			_next_peer_id = 2
	var id := _next_peer_id
	_next_peer_id += 1
	return id


func _fail(message: String) -> void:
	if _expected_failure_quiet:
		print("[webrtc-test] expected failure: %s" % message)
	else:
		push_error(message)
	failed.emit(message)
