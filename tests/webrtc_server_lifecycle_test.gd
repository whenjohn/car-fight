extends SceneTree

const TRANSPORT := preload("res://net/webrtc_transport.gd")

var _failed := false
var _server_failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_listener_failure()
	await _test_pending_limits()
	await _test_defaults()
	await _test_negotiation_deadline(false)
	await _test_negotiation_deadline(true)
	await _test_peer_isolation()
	print("WEBRTC_SERVER_LIFECYCLE_TEST %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _test_listener_failure() -> void:
	var listener := TCPServer.new()
	_check(listener.listen(0, "*") == OK, "fixture reserves the signaling port")
	var server := TRANSPORT.new()
	_server_failures.clear()
	server.set_expected_failure_quiet(true)
	server.failed.connect(func(message: String): _server_failures.append(message))
	_check(server.start_server(listener.get_local_port(), []) == null, "occupied listener cannot start")
	_check(_server_failures.size() == 1 and "signaling listen" in _server_failures[0],
		"listener startup failure still emits the server-fatal signal")
	listener.stop()
	_finish_server(server)
	await process_frame


func _test_pending_limits() -> void:
	var server := _new_server(60000, 2)
	var streams: Array[StreamPeerTCP] = []
	for index in range(20):
		var stream := StreamPeerTCP.new()
		stream.connect_to_host("127.0.0.1", server._tcp.get_local_port())
		streams.append(stream)
	server._process(0.01)
	_check(server._server_signal_peers.size() + server._server_rejected_connections <= 16,
		"limited admission processes at most 16 TCP accepts per poll")
	await _wait(server, func(): return server._server_rejected_connections == 18)
	_check(server._server_signal_peers.size() == 2, "pending cap includes silent pre-WebSocket TCP peers")
	_check(server._rtc.get_peers().is_empty(), "over-cap admission does not allocate RTC peers")
	if server._server_signal_peers.has(2):
		var first = server._server_signal_peers[2]
		server._check_server_peer(first, first.accepted_msec + 59999)
		_check(server._server_signal_peers.has(2), "pending timeout does not fire early")
		server._check_server_peer(first, first.accepted_msec + 60000)
		_check(not server._server_signal_peers.has(2), "silent TCP peer expires at its deadline")
		var replacement := StreamPeerTCP.new()
		replacement.connect_to_host("127.0.0.1", server._tcp.get_local_port())
		streams.append(replacement)
		await _wait(server, func(): return server._server_signal_peers.has(4))
		_check(server._server_signal_peers.size() == 2, "expired slot admits a new pending peer")
	_check(_server_failures.is_empty(), "admission rejection and expiry are never server-fatal")
	for stream in streams:
		stream.disconnect_from_host()
	_finish_server(server)


func _test_defaults() -> void:
	var server := _new_server()
	_check(server._server_pending_timeout_msec == 0 and server._server_max_pending == 0,
		"server limits remain opt-in")
	var streams: Array[StreamPeerTCP] = []
	for index in range(3):
		var stream := StreamPeerTCP.new()
		stream.connect_to_host("127.0.0.1", server._tcp.get_local_port())
		streams.append(stream)
	await _wait(server, func(): return server._server_signal_peers.size() == 3)
	for pending in server._server_signal_peers.values():
		server._check_server_peer(pending, pending.accepted_msec + 1000000)
	_check(server._server_signal_peers.size() == 3 and server._server_rejected_connections == 0,
		"zero settings retain unlimited pending admission and wait")
	for stream in streams:
		stream.disconnect_from_host()
	_finish_server(server)


func _test_negotiation_deadline(with_offer: bool) -> void:
	var server := _new_server(60000, 1, with_offer)
	var client: Node
	var ws := WebSocketPeer.new()
	if with_offer:
		client = _new_client(server, true)
		await _wait(server, func():
			var pending = server._server_signal_peers.get(2)
			return pending != null and pending.local_answer_sent, [client])
	else:
		ws.connect_to_url(_url(server))
		await _wait(server, func(): return server._rtc.has_peer(2), [], [ws])
		ws.send_text(JSON.stringify({"type": "id_ack", "id": 2}))
		await _wait(server, func(): return server._server_signal_peers[2].id_acked, [], [ws])
	if server._server_signal_peers.has(2):
		var pending = server._server_signal_peers[2]
		_check(not pending.gameplay_connected, "fixture remains in negotiation without usable ICE")
		server._check_server_peer(pending, pending.accepted_msec + 59999)
		_check(server._rtc.has_peer(2), "ACK/SDP progress does not end the pending budget")
		server._check_server_peer(pending, pending.accepted_msec + 60000)
		_check(not server._rtc.has_peer(2) and not server._server_signal_peers.has(2),
			"deadline releases the negotiating RTC peer and signaling socket")
	_check(_server_failures.is_empty(), "negotiation expiry is peer-local")
	ws.close()
	if client != null:
		client.close()
		client.free()
	_finish_server(server)


func _test_peer_isolation() -> void:
	var server := _new_server(60000, 1)
	var survivor := _new_client(server)
	await _wait(server, func(): return server.peer_can_send(2) and survivor._client_gameplay_connected, [survivor])
	_check(server._server_signal_peers.has(2), "healthy client retains signaling")
	if not server._server_signal_peers.has(2):
		survivor.close()
		survivor.free()
		_finish_server(server)
		return
	var healthy = server._server_signal_peers[2]
	server._check_server_peer(healthy, healthy.accepted_msec + 1000000)
	_check(server.peer_can_send(2), "connected peer is exempt from pending timeout")
	var messages := [
		{"type": "offer", "sdp": "not a valid SDP"},
		{"type": "candidate", "mid": "0", "index": 0, "candidate": "not a valid ICE candidate"},
		{"type": "id_ack", "id": 5.5},
	]
	var retired_connection_id := 0
	for index in range(messages.size()):
		var peer_id := index + 3
		var ws := WebSocketPeer.new()
		ws.connect_to_url(_url(server))
		await _wait(server, func(): return server._rtc.has_peer(peer_id), [survivor], [ws])
		if server._rtc.has_peer(peer_id):
			if peer_id == 3:
				retired_connection_id = server._rtc.get_peer(peer_id).connection.get_instance_id()
			ws.send_text(JSON.stringify(messages[index]))
			await _wait(server, func(): return not server._server_signal_peers.has(peer_id), [survivor], [ws])
			_check(not server._rtc.has_peer(peer_id), "failed pending peer %d is removed" % peer_id)
		_check(_server_failures.is_empty(), "malformed signaling never emits the server-fatal signal")
		await _assert_delivery(server, survivor)
		ws.close()
	# Force reuse only in this fixture to exercise stale callback identity checks.
	server.set_forced_peer_id_provider(func(): return 3)
	var replacement_ws := WebSocketPeer.new()
	replacement_ws.connect_to_url(_url(server))
	await _wait(server, func(): return server._rtc.has_peer(3), [survivor], [replacement_ws])
	if server._rtc.has_peer(3):
		server._on_session_description("answer", "stale invalid SDP", 3, retired_connection_id)
		server._on_ice_candidate("0", 0, "stale invalid ICE", 3, retired_connection_id)
		_check(server._server_signal_peers[3].failure_reason.is_empty(), "stale RTC callbacks cannot affect a reused ID")
		server._peer_fail(3, "fixture failure before gameplay connected")
		# Model channels completing between the failure callback and cleanup pass.
		server._server_signal_peers[3].gameplay_connected = true
		await _wait(server, func(): return not server._rtc.has_peer(3), [survivor], [replacement_ws])
		_check(not server._server_signal_peers.has(3), "a failed join cannot become a surviving connected peer")
	replacement_ws.close()
	server.set_forced_peer_id_provider(Callable())
	# A valid newcomer reaches an actual SDP callback; inject failure inside RTC poll.
	var newcomer := _new_client(server)
	await _wait(server, func(): return server._rtc.has_peer(6), [survivor, newcomer])
	var callback_observed: Array[bool] = []
	if server._rtc.has_peer(6):
		server._rtc.get_peer(6).connection.session_description_created.connect(func(_kind: String, _sdp: String):
			server._peer_fail(6, "injected SDP callback failure")
			callback_observed.append(server._rtc.has_peer(6)), CONNECT_ONE_SHOT)
		await _wait(server, func(): return not server._rtc.has_peer(6), [survivor, newcomer])
		_check(callback_observed == [true], "peer stays allocated until the RTC callback unwinds")
	_check(_server_failures.is_empty(), "RTC callback failure stays peer-local")
	await _assert_delivery(server, survivor)
	newcomer.close()
	newcomer.free()
	# Reject a late offer before native SDP parsing can mutate a live connection.
	survivor._client_signal.send_text(JSON.stringify({"type": "offer", "sdp": "invalid late SDP"}))
	await _wait(server, func(): return not server._server_signal_peers.has(2), [survivor])
	_check(server.peer_can_send(2), "bad signaling after connection preserves gameplay")
	await _assert_delivery(server, survivor)
	server.reject_server_peer(2, "explicit kick after signaling closed")
	await _wait(server, func(): return not server._rtc.has_peer(2), [survivor])
	_check(_server_failures.is_empty(), "explicit kick is not server-fatal")
	survivor.close()
	survivor.free()
	_finish_server(server)


func _new_server(timeout_msec := 0, max_pending := 0, relay_only := false) -> Node:
	_server_failures.clear()
	var server := TRANSPORT.new()
	server.set_expected_failure_quiet(true)
	server.failed.connect(func(message: String): _server_failures.append(message))
	_check(server.start_server(0, [], relay_only, 1, false, timeout_msec, max_pending) != null, "server starts")
	return server


func _new_client(server: Node, relay_only := false) -> Node:
	var client := TRANSPORT.new()
	client.set_expected_failure_quiet(true)
	client.start_client(_url(server), [], relay_only)
	return client


func _url(server: Node) -> String:
	return "ws://127.0.0.1:%d" % server._tcp.get_local_port()


func _wait(server: Node, predicate: Callable, clients: Array = [], sockets: Array = []) -> void:
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and not predicate.call():
		server._rtc.poll()
		for client in clients:
			if client._client_id > 0 and not client._closed:
				client._rtc.poll()
		server._process(0.01)
		for client in clients:
			client._process(0.01)
		for socket: WebSocketPeer in sockets:
			socket.poll()
			while socket.get_available_packet_count() > 0:
				socket.get_packet()
		await create_timer(0.01).timeout
	_check(predicate.call(), "fixture reaches expected state within 3 seconds")


func _assert_delivery(server: Node, client: Node) -> void:
	_check(server.peer_can_send(2) and client.peer_can_send(1), "healthy DataChannels remain open")
	if not client.peer_can_send(1):
		return
	var payload := "survived-peer-failure".to_utf8_buffer()
	client._rtc.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	client._rtc.set_target_peer(1)
	_check(client._rtc.put_packet(payload) == OK, "healthy peer sends gameplay")
	await _wait(server, func(): return server._rtc.get_available_packet_count() > 0, [client])
	if server._rtc.get_available_packet_count() > 0:
		_check(server._rtc.get_packet_peer() == 2 and server._rtc.get_packet() == payload,
			"healthy gameplay retains sender and payload after another peer fails")


func _finish_server(server: Node) -> void:
	server.close()
	server._process(0.01)
	_check(server._server_signal_peers.is_empty() and server._rtc.get_peers().is_empty(),
		"explicit server close releases all peers and stops polling")
	server.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("FAIL: %s" % message)
