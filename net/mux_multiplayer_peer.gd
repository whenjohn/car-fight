extends MultiplayerPeerExtension
## Server-only MultiplayerPeer that presents ENet and WebRTC clients as one peer table.
##
## SceneMultiplayer owns relay, peer exchange, RPC and spawner behavior above this interface.
## The mux only preserves the MultiplayerPeer contract: poll both inner peers, forward their
## lifecycle signals, retain per-packet metadata, and route outbound packets to the transport
## that owns the target peer id.

const TRANSPORT_ENET := "enet"
const TRANSPORT_WEBRTC := "webrtc"

signal peer_rejected(peer_id: int, transport: String)

var _inners: Dictionary = {}
var _send_guards: Dictionary = {}
var _owners: Dictionary = {}   # peer id -> transport name
var _packets: Array[Dictionary] = []
var _pending_disconnects: Array[Dictionary] = []
var _pending_disconnect_ids: Dictionary = {}
var _target_peer := 0
var _transfer_channel := 0
var _transfer_mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _refuse_new_connections := false
var _closed := false
var _first_packet_seen: Dictionary = {}


func add_inner(transport: String, peer: MultiplayerPeer) -> void:
	assert(transport in [TRANSPORT_ENET, TRANSPORT_WEBRTC])
	assert(peer != null)
	assert(not _inners.has(transport))
	_inners[transport] = peer
	peer.peer_connected.connect(_on_inner_peer_connected.bind(transport))
	peer.peer_disconnected.connect(_on_inner_peer_disconnected.bind(transport))
	peer.refuse_new_connections = _refuse_new_connections


func set_send_guard(transport: String, guard: Callable) -> void:
	_send_guards[transport] = guard


func transport_for_peer(peer_id: int) -> String:
	return str(_owners.get(peer_id, ""))


func peer_uses_webrtc(peer_id: int) -> bool:
	return transport_for_peer(peer_id) == TRANSPORT_WEBRTC


func has_enet_peer(peer_id: int) -> bool:
	return transport_for_peer(peer_id) == TRANSPORT_ENET


func has_webrtc_peer(peer_id: int) -> bool:
	return transport_for_peer(peer_id) == TRANSPORT_WEBRTC


func first_peer_for_transport(transport: String) -> int:
	for peer_variant in _owners:
		var peer_id := int(peer_variant)
		if not _pending_disconnect_ids.has(peer_id) \
				and transport_for_peer(peer_id) == transport:
			return peer_id
	return 0


func close_inner(transport: String) -> void:
	if _inners.has(transport):
		var inner: MultiplayerPeer = _inners[transport]
		inner.close()
		_inners.erase(transport)


func remove_inner(transport: String) -> void:
	_inners.erase(transport)


func _poll() -> void:
	if _closed:
		return
	# Inner peers can emit disconnected DURING poll(), while also leaving final packets
	# available to drain. SceneMultiplayer handles our disconnect signal synchronously and
	# deletes that peer's spawned nodes; emitting immediately would then deliver those final
	# packets to paths that no longer exist. A prior mux poll's packets have been consumed by
	# SceneMultiplayer before this next call, so this is the safe teardown boundary.
	_flush_pending_disconnects()
	for transport_variant in _inners:
		var transport := str(transport_variant)
		var inner: MultiplayerPeer = _inners[transport]
		# A mux server may spend its whole life serving only native ENet peers.
		# WebRTC signaling adds the concrete peer before negotiation needs polling,
		# so an empty WebRTC table has no packets or connection work to service.
		if transport == TRANSPORT_WEBRTC and inner.get_peers().is_empty():
			continue
		inner.poll()
		while inner.get_available_packet_count() > 0:
			# MultiplayerPeer metadata describes the NEXT queued packet. Capture it before
			# get_packet() consumes that packet; afterward concrete peers report an empty queue.
			var packet_peer := inner.get_packet_peer()
			var packet_channel := inner.get_packet_channel()
			var packet_mode := inner.get_packet_mode()
			if not _first_packet_seen.has(transport):
				_first_packet_seen[transport] = true
				print("[mux] first_packet transport=%s peer=%d channel=%d mode=%d" % [
					transport, packet_peer, packet_channel, packet_mode])
			var data := inner.get_packet()
			var packet_err := inner.get_packet_error()
			if packet_err != OK:
				push_warning("[mux] get_packet %s failed: %s" % [
					transport, error_string(packet_err)])
				continue
			_packets.push_back({
				"data": data,
				"peer": packet_peer,
				"channel": packet_channel,
				"mode": packet_mode,
			})


func _close() -> void:
	if _closed:
		return
	_closed = true
	for inner: MultiplayerPeer in _inners.values():
		inner.close()
	_packets.clear()
	_pending_disconnects.clear()
	_pending_disconnect_ids.clear()
	_owners.clear()


func _disconnect_peer(peer_id: int, force: bool) -> void:
	var transport := transport_for_peer(peer_id)
	if transport == "":
		push_warning("[mux] disconnect unknown peer=%d" % peer_id)
		return
	var inner: MultiplayerPeer = _inners[transport]
	inner.disconnect_peer(peer_id, force)


func _set_target_peer(peer_id: int) -> void:
	_target_peer = peer_id


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _closed:
		return ERR_UNCONFIGURED
	if _target_peer > 0:
		# The inner has already closed this id, but SceneMultiplayer has not received our
		# deferred disconnect yet. Drop sends during that one-poll drain window cleanly.
		if _pending_disconnect_ids.has(_target_peer):
			return OK
		var transport := transport_for_peer(_target_peer)
		if transport == "":
			push_warning("[mux] send to unknown peer=%d" % _target_peer)
			return ERR_DOES_NOT_EXIST
		return _send_via(str(transport), _target_peer, buffer)

	# Expand broadcast (0) and broadcast-except (-peer) across the unified owner table.
	# Exact sends let a transport-specific readiness guard suppress a DataChannel that
	# closed just before its concrete peer emits disconnected; native broadcast would
	# attempt that closed channel and produce a hard engine error.
	var first_error: Error = OK
	for peer_variant in _owners:
		var peer_id := int(peer_variant)
		if _pending_disconnect_ids.has(peer_id) \
				or (_target_peer < 0 and peer_id == -_target_peer):
			continue
		var err := _send_via(transport_for_peer(peer_id), peer_id, buffer)
		if err != OK and first_error == OK:
			first_error = err
	return first_error


func _send_via(transport: String, target: int, buffer: PackedByteArray) -> Error:
	var inner: MultiplayerPeer = _inners[transport]
	var guard: Callable = _send_guards.get(transport, Callable())
	if target > 0 and guard.is_valid() and not bool(guard.call(target)):
		return OK
	inner.set_target_peer(target)
	inner.transfer_channel = _transfer_channel
	inner.transfer_mode = _transfer_mode
	return inner.put_packet(buffer)


func _get_packet_script() -> PackedByteArray:
	if _packets.is_empty():
		return PackedByteArray()
	var packet: Dictionary = _packets.pop_front()
	return packet["data"] as PackedByteArray


func _get_packet_peer() -> int:
	return 1 if _packets.is_empty() else int(_packets[0]["peer"])


func _get_packet_channel() -> int:
	return 0 if _packets.is_empty() else int(_packets[0]["channel"])


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return (MultiplayerPeer.TRANSFER_MODE_RELIABLE if _packets.is_empty()
		else _packets[0]["mode"] as MultiplayerPeer.TransferMode)


func _get_available_packet_count() -> int:
	return _packets.size()


func _get_max_packet_size() -> int:
	var smallest := 0
	for inner: MultiplayerPeer in _inners.values():
		var size: int = inner.get_max_packet_size()
		if smallest == 0 or size < smallest:
			smallest = size
	return smallest


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_transfer_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _transfer_mode


func _get_unique_id() -> int:
	return MultiplayerPeer.TARGET_PEER_SERVER


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return MultiplayerPeer.CONNECTION_DISCONNECTED if _closed else MultiplayerPeer.CONNECTION_CONNECTED


func _is_server() -> bool:
	return true


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(refuse: bool) -> void:
	_refuse_new_connections = refuse
	for inner: MultiplayerPeer in _inners.values():
		inner.refuse_new_connections = refuse


func _get_refuse_new_connections() -> bool:
	return _refuse_new_connections


func _on_inner_peer_connected(peer_id: int, transport: String) -> void:
	if _owners.has(peer_id):
		var owner := transport_for_peer(peer_id)
		print("[mux] PEER-ID COLLISION id=%d owner=%s newcomer=%s — newcomer kicked" % [
			peer_id, owner, transport])
		var newcomer: MultiplayerPeer = _inners[transport]
		newcomer.disconnect_peer(peer_id, true)
		peer_rejected.emit(peer_id, transport)
		return
	_owners[peer_id] = transport
	print("[mux] peer_connected id=%d transport=%s" % [peer_id, transport])
	peer_connected.emit(peer_id)


func _on_inner_peer_disconnected(peer_id: int, transport: String) -> void:
	# A rejected colliding newcomer may still emit disconnected. It never owned the id,
	# so do not remove or announce the established peer from the other transport.
	if transport_for_peer(peer_id) != transport:
		return
	_pending_disconnect_ids[peer_id] = true
	_pending_disconnects.push_back({"peer": peer_id, "transport": transport})


func _flush_pending_disconnects() -> void:
	for pending in _pending_disconnects:
		var peer_id := int(pending["peer"])
		var transport := str(pending["transport"])
		if transport_for_peer(peer_id) != transport:
			continue
		_owners.erase(peer_id)
		_pending_disconnect_ids.erase(peer_id)
		print("[mux] peer_disconnected id=%d transport=%s" % [peer_id, transport])
		peer_disconnected.emit(peer_id)
	_pending_disconnects.clear()
