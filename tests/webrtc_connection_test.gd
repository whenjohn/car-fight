extends SceneTree

const TRANSPORT := preload("res://net/webrtc_transport.gd")

class SignalingFixture extends RefCounted:
	var listener := TCPServer.new()
	var stream: StreamPeerTCP
	var ws := WebSocketPeer.new()
	var handshake := true
	var accepted := false

	func poll() -> void:
		if stream == null and listener.is_connection_available():
			stream = listener.take_connection()
			accepted = true
			if handshake:
				ws.accept_stream(stream)
		if handshake:
			ws.poll()
			while ws.get_available_packet_count() > 0:
				ws.get_packet()

	func close() -> void:
		ws.close()
		ws = WebSocketPeer.new()
		if stream != null:
			stream.disconnect_from_host()
		listener.stop()

var _failures: Array[String] = []
var _checks_failed := 0
var _ready_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_refused_endpoint()
	for stage in range(3):
		await _test_timeout(stage)
	await _test_closed_signaling()
	await _test_closed_negotiation(false)
	await _test_closed_negotiation(true)
	await _test_callback_failure()
	for invalid_id in [0, 1, -1, 2.5, 2147483648, "2"]:
		await _test_invalid_id(invalid_id)
	await _test_explicit_close()
	await _test_connected_signaling_loss()
	print("WEBRTC_CONNECTION_TEST %s" % ("PASS" if _checks_failed == 0 else "FAIL"))
	quit(0 if _checks_failed == 0 else 1)


func _test_refused_endpoint() -> void:
	var listener := TCPServer.new()
	_check(listener.listen(0, "127.0.0.1") == OK, "reserve unused local port")
	var port := listener.get_local_port()
	listener.stop()
	var client := _new_client()
	client.start_client("ws://127.0.0.1:%d" % port, [])
	_check(client._client_connect_timeout_msec == 0, "deadline remains disabled by default")
	var until := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until and _failures.is_empty():
		client._process(0.01)
		await create_timer(0.01).timeout
	_check(_failures.size() == 1, "refused endpoint reports failure before signaling opens")
	_assert_terminal(client)
	client.close()
	client.free()


func _test_timeout(stage: int) -> void:
	var fixture := _new_fixture(stage > 0)
	var client := _new_client()
	client.start_client(_url(fixture), [], false, 1, false, 60000)
	await _wait_fixture(client, fixture, func():
		return fixture.accepted if stage == 0 else client._client_signal_open)
	var started: int = client._client_connect_started_msec
	if stage == 2:
		fixture.ws.send_text(JSON.stringify({"type": "id", "id": 2}))
		await _wait_fixture(client, fixture, func(): return _ready_count == 1)
		fixture.ws.send_text(JSON.stringify({"type": "id", "id": 2}))
		for index in range(10):
			await _step_fixture(client, fixture)
		_check(_ready_count == 1, "repeated ID does not recreate the gameplay peer")
	_check(client._client_connect_started_msec == started, "signaling cannot extend attempt budget")
	client._check_client_connection(started + 59999)
	_check(_failures.is_empty(), "deadline does not fire early at stage %d" % stage)
	client._check_client_connection(started + 60000)
	var expected_stage: String = ["signaling open", "peer assignment", "negotiation"][stage]
	_check(_failures.size() == 1 and expected_stage in _failures[0],
		"deadline identifies stalled %s" % expected_stage)
	_assert_terminal(client)
	fixture.close()
	client.free()


func _test_closed_signaling() -> void:
	var fixture := _new_fixture()
	var client := _new_client()
	client.start_client(_url(fixture), [])
	await _wait_fixture(client, fixture, func(): return client._client_signal_open)
	# Also exercise the default-disabled deadline against a future clock value.
	client._check_client_connection(client._client_connect_started_msec + 1000000)
	_check(_failures.is_empty(), "zero timeout keeps the existing unlimited wait")
	fixture.close()
	await _wait_fixture(client, fixture, func(): return not _failures.is_empty())
	_assert_terminal(client)
	client.free()


func _test_closed_negotiation(poll_before_check: bool) -> void:
	var fixture := _new_fixture()
	var client := _new_client()
	client.start_client(_url(fixture), [])
	await _wait_fixture(client, fixture, func(): return client._client_signal_open)
	fixture.ws.send_text(JSON.stringify({"type": "id", "id": 2}))
	await _wait_fixture(client, fixture, func(): return _ready_count == 1)
	if client._rtc.has_peer(1):
		client._rtc.get_peer(1).connection.close()
		if poll_before_check:
			client._rtc.poll()
		client._check_client_connection(Time.get_ticks_msec())
	_check(_failures.size() == 1 and "negotiation" in _failures[0],
		"closed RTC negotiation fails even with deadline disabled")
	_assert_terminal(client)
	fixture.close()
	client.free()


func _test_callback_failure() -> void:
	var fixture := _new_fixture()
	var client := _new_client()
	client.start_client(_url(fixture), [])
	await _wait_fixture(client, fixture, func(): return client._client_signal_open)
	fixture.ws.send_text(JSON.stringify({"type": "id", "id": 2}))
	await _wait_fixture(client, fixture, func(): return _ready_count == 1)
	var retiring_peer: WebRTCMultiplayerPeer = client._rtc
	if retiring_peer.has_peer(1):
		var connection: WebRTCPeerConnection = retiring_peer.get_peer(1).connection
		connection.session_description_created.connect(func(_kind: String, _sdp: String):
			client._fail("injected SDP callback failure"), CONNECT_ONE_SHOT)
		var until := Time.get_ticks_msec() + 3000
		while _failures.is_empty() and Time.get_ticks_msec() < until:
			retiring_peer.poll()
			await create_timer(0.01).timeout
		_check(_failures.size() == 1 and "injected SDP callback failure" in _failures[0],
			"failure inside real RTC poll is reported once")
		_check(retiring_peer.get_peers().is_empty(), "deferred cleanup closes the original RTC peer")
	_assert_terminal(client)
	fixture.close()
	client.free()


func _test_invalid_id(invalid_id: Variant) -> void:
	var fixture := _new_fixture()
	var client := _new_client()
	client.start_client(_url(fixture), [])
	await _wait_fixture(client, fixture, func(): return client._client_signal_open)
	fixture.ws.send_text(JSON.stringify({"type": "id", "id": invalid_id}))
	await _wait_fixture(client, fixture, func(): return not _failures.is_empty())
	_check(_ready_count == 0, "invalid ID %s cannot expose a gameplay peer" % str(invalid_id))
	_assert_terminal(client)
	fixture.close()
	client.free()


func _test_explicit_close() -> void:
	var fixture := _new_fixture()
	var client := _new_client()
	client.start_client(_url(fixture), [], false, 1, false, 60000)
	await _wait_fixture(client, fixture, func(): return client._client_signal_open)
	client.close()
	client.close()
	client._process(0.01)
	client._check_client_connection(Time.get_ticks_msec() + 1000000)
	_check(_failures.is_empty(), "explicit close is quiet and idempotent")
	fixture.close()
	client.free()


func _test_connected_signaling_loss() -> void:
	var server := TRANSPORT.new()
	var server_failures: Array[String] = []
	server.failed.connect(func(message: String): server_failures.append(message))
	_check(server.start_server(0, []) != null, "real RTC server starts")
	var client := _new_client()
	client.start_client("ws://127.0.0.1:%d" % server._tcp.get_local_port(), [], false, 1, false, 60000)
	var until := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < until and \
			not (client._client_gameplay_connected and server.peer_can_send(2)):
		await _step_pair(server, client)
	_check(client._client_gameplay_connected and server.peer_can_send(2), "real DataChannels connect")
	if client._client_gameplay_connected and server.peer_can_send(2):
		var signal_peer = server._server_signal_peers.get(2)
		_check(signal_peer != null, "connected pair retains signaling before test removal")
		if signal_peer != null:
			signal_peer.ws.close()
		until = Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < until and \
				client._client_signal.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			await _step_pair(server, client)
		_check(client._client_signal.get_ready_state() == WebSocketPeer.STATE_CLOSED,
			"signaling actually closes")
		client._check_client_connection(client._client_connect_started_msec + 1000000)
		_check(_failures.is_empty() and client.peer_can_send(1), "connected RTC outlives signaling and deadline")
		var payload := "after-signaling-close".to_utf8_buffer()
		client._rtc.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
		client._rtc.set_target_peer(1)
		_check(client._rtc.put_packet(payload) == OK, "send gameplay after signaling loss")
		until = Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < until and server._rtc.get_available_packet_count() == 0:
			await _step_pair(server, client)
		_check(server._rtc.get_available_packet_count() > 0, "server receives gameplay after signaling loss")
		if server._rtc.get_available_packet_count() > 0:
			_check(server._rtc.get_packet_peer() == 2 and server._rtc.get_packet() == payload,
				"post-signaling gameplay has the correct sender and payload")
		client._rtc.close()
		client._process(0.01)
		client._check_client_connection(Time.get_ticks_msec() + 1000000)
		_check(_failures.is_empty(), "later gameplay disconnect is not reclassified as bootstrap failure")
	_check(server_failures.is_empty(), "server reports no unexpected failures")
	client.close()
	server.close()
	client.free()
	server.free()


func _new_client() -> Node:
	_failures.clear()
	_ready_count = 0
	var client := TRANSPORT.new()
	client.set_expected_failure_quiet(true)
	client.failed.connect(func(message: String): _failures.append(message))
	client.multiplayer_peer_ready.connect(func(_peer: MultiplayerPeer): _ready_count += 1)
	return client


func _new_fixture(handshake := true) -> SignalingFixture:
	var fixture := SignalingFixture.new()
	fixture.handshake = handshake
	_check(fixture.listener.listen(0, "127.0.0.1") == OK, "fixture listens on loopback")
	return fixture


func _url(fixture: SignalingFixture) -> String:
	return "ws://127.0.0.1:%d" % fixture.listener.get_local_port()


func _wait_fixture(client: Node, fixture: SignalingFixture, predicate: Callable) -> void:
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and not predicate.call():
		await _step_fixture(client, fixture)
	_check(predicate.call(), "fixture reaches expected state within 3 seconds")


func _step_fixture(client: Node, fixture: SignalingFixture) -> void:
	fixture.poll()
	if client._client_id > 0 and not client._closed:
		client._rtc.poll()
	client._process(0.01)
	await create_timer(0.01).timeout


func _step_pair(server: Node, client: Node) -> void:
	server._rtc.poll()
	if client._client_id > 0 and not client._closed:
		client._rtc.poll()
	server._process(0.01)
	client._process(0.01)
	await create_timer(0.01).timeout


func _assert_terminal(client: Node) -> void:
	for index in range(5):
		client._process(0.01)
		client._check_client_connection(Time.get_ticks_msec() + 1000000)
	client._fail("late callback must not replace the original failure")
	_check(_failures.size() == 1, "failure is emitted once")
	_check(client._closed and client._mode.is_empty(), "terminal failure stops polling")
	_check(client._client_signal.get_ready_state() == WebSocketPeer.STATE_CLOSED,
		"terminal failure releases signaling")
	_check(client._rtc.get_peers().is_empty(), "terminal failure releases pending RTC peers")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_checks_failed += 1
		printerr("FAIL: %s" % message)
