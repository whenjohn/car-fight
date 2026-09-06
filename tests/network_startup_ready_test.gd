extends SceneTree

class MainStub extends Node:
	var permitted := false
	func network_startup_ready() -> bool:
		return permitted
	func is_scripted_client() -> bool:
		return true
	func scripted_input_for(_body: Node) -> Dictionary:
		return {"cursor_offset": Vector2(10, 0), "burst": true, "drop_troops": true}

class ClientPeer extends MultiplayerPeerExtension:
	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
		return MultiplayerPeer.CONNECTION_CONNECTED
	func _get_unique_id() -> int:
		return 2
	func _is_server() -> bool:
		return false
	func _get_available_packet_count() -> int:
		return 0
	func _poll() -> void:
		pass

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("NetworkEvents").enabled = false
	root.get_node("NetworkTime").stop()
	var gate = load("res://net/startup_readiness.gd").new()
	gate.observe(100000, false, false, 0, -1, -1, 0, 0, -1)
	_check(not gate.is_failed() and not gate.is_ready(), "asset loading does not consume the connection deadline")
	gate.begin(100)
	gate.observe(200, true, false, 42, 100, 100, 102, 38, 190)
	_check(not gate.is_ready(), "transport connection and spawn do not permit driving")
	gate.observe(300, true, true, 42, 100, 100, 102, 38, 290)
	_check(not gate.is_ready(), "state received before clock validation is insufficient")
	gate.observe(320, true, true, 42, 102, 101, 104, 40, 310)
	_check(not gate.is_ready(), "received state must have been consumed by rollback")
	gate.observe(330, true, true, 42, 106, 106, 104, 40, 325)
	_check(not gate.is_ready(), "future authority state does not permit driving")
	gate.observe(340, true, false, 42, 103, 103, 105, 41, 335)
	gate.observe(350, true, true, 42, 104, 104, 106, 42, 345)
	_check(not gate.is_ready(), "clock instability invalidates earlier state evidence")
	gate.observe(370, true, true, 42, 105, 105, 107, 43, 360)
	_check(gate.is_ready(), "fresh consumed state after stable timing releases startup")
	_check(gate.permits_body(42) and not gate.permits_body(43)
		and not gate.permits_body(0), "replacement input is blocked even before the next observation")
	gate.observe(400, true, false, 42, 105, 105, 108, 44, 360)
	_check(gate.is_ready(), "ordinary in-game clock jitter does not reopen startup")
	gate.observe(450, true, true, 43, 110, 110, 112, 48, 440)
	_check(not gate.is_ready(), "replacement body cannot inherit old readiness")
	gate.observe(470, true, true, 43, 111, 111, 113, 49, 460)
	_check(gate.is_ready(), "replacement requires its own fresh state")
	gate.observe(480, false, true, 43, 111, 111, 113, 49, 460)
	_check(gate.is_failed() and not gate.is_ready(), "disconnect revokes readiness")
	gate.observe(500, true, true, 43, 112, 112, 114, 50, 490)
	_check(gate.is_failed(), "failure stays latched until explicit retry")
	gate.begin(600)
	gate.observe(601, true, true, 43, 112, 112, 114, 50, 590)
	_check(not gate.is_ready(), "retry discards earlier readiness evidence")
	gate.observe(600 + gate.TIMEOUT_MSEC, true, true, 43, 112, 112, 114, 50, 590)
	_check(gate.is_failed(), "startup has a bounded timeout")
	gate.begin(1000)
	gate.observe(1001, false, false, 0, -1, -1, 0, 0, -1)
	_check(not gate.is_failed(), "initial connection may still be pending")
	# A healthy stream can always publish a newer snapshot before the client
	# reaches it. Readiness must not chase that moving target indefinitely.
	gate.begin(2000)
	gate.observe(2001, true, true, 42, 105, 105, 100, 36, 2000)
	for tick in range(101, 108):
		gate.observe(2000 + tick, true, true, 42, tick + 5, tick + 5,
			tick, tick - 64, 1999 + tick)
		if tick < 106:
			_check(not gate.is_ready(), "future witness cannot release startup early")
	_check(gate.is_ready(), "steady ahead-of-local snapshots cannot starve readiness")
	gate.begin(3000)
	gate.observe(3001, true, true, 42, 105, 105, 100, 36, 3000)
	gate.observe(3002, true, true, 42, 106, 105, 101, 37, 3002)
	gate.observe(3003, true, true, 42, 110, 105, 106, 42, 3003)
	_check(not gate.is_ready(), "receiving without consuming is not an authority witness")
	gate.begin(4000)
	gate.observe(4001, true, true, 42, 100, 100, 100, 36, 4000)
	gate.observe(4002, true, true, 42, 105, 105, 101, 37, 4002)
	gate.observe(4003, true, false, 42, 106, 106, 105, 41, 4003)
	gate.observe(4004, true, true, 42, 106, 106, 105, 41, 4003)
	_check(not gate.is_ready(), "unstable clocks discard a held witness")
	gate.begin(5000)
	gate.observe(5001, true, true, 42, 100, 100, 100, 36, 5000)
	gate.observe(5002, true, true, 42, 105, 105, 101, 37, 5002)
	gate.observe(5003, true, true, 42, 190, 190, 180, 116, 5003)
	_check(not gate.is_ready(), "history expiry discards a held witness")
	gate.observe(5004, true, true, 42, 195, 195, 190, 126, 5004)
	_check(gate.is_ready(), "fresh replacement witness releases only after local catch-up")
	gate.begin(6000)
	gate.observe(6001, true, true, 42, 100, 100, 100, 36, 6000)
	gate.observe(6002, true, true, 42, 105, 105, 101, 37, 6002)
	gate.observe(6003, true, true, 43, 105, 105, 106, 42, 6002)
	_check(not gate.is_ready(), "replacement body cannot inherit a held witness")
	gate.observe(6004, true, true, 43, 110, 110, 106, 42, 6004)
	gate.begin(6005)
	gate.observe(6006, true, true, 43, 110, 110, 111, 47, 6004)
	_check(not gate.is_ready(), "retry cannot inherit a held witness")
	var main := MainStub.new()
	root.add_child(main)
	current_scene = main
	var body := Node3D.new()
	main.add_child(body)
	var input: Node = load("res://player/player_input.gd").new()
	body.add_child(input)
	input._gather()
	_check(input.cursor_offset == Vector2.ZERO and input.editing
		and not input.burst and not input.drop_troops, "real gathered input stays neutral before readiness")
	main.permitted = true
	input._gather()
	_check(input.cursor_offset == Vector2(10, 0) and input.burst and input.drop_troops,
		"ready input uses the unchanged scripted command path")
	main.permitted = false
	input._gather()
	_check(input.cursor_offset == Vector2.ZERO and input.editing
		and not input.burst and not input.drop_troops, "revoked readiness clears held commands")
	main.free()
	var synchronizer := root.get_node("NetworkTimeSynchronizer")
	synchronizer._active = true
	synchronizer._sample_buffer = _RingBuffer.new(synchronizer.sync_samples)
	synchronizer._last_sample_msec = 100
	for sample in range(synchronizer.sync_samples - 1):
		synchronizer._sample_buffer.push(null)
	_check(not synchronizer.has_fresh_sample_window(100), "incomplete clock sample window is not ready")
	synchronizer._sample_buffer.push(null)
	_check(synchronizer.has_fresh_sample_window(100), "complete fresh sample window is available")
	_check(not synchronizer.has_fresh_sample_window(2100), "old clock samples cannot admit startup")
	synchronizer._sample_buffer.clear()
	_check(not synchronizer.has_fresh_sample_window(100), "panic-cleared samples require new evidence")
	synchronizer.stop()
	_check(not synchronizer.has_fresh_sample_window(100), "disconnect clears timing evidence")
	# Cancel while the initial timestamp is pending; a later session's signal
	# must not resurrect this NetworkTime.start coroutine or emit after_sync.
	multiplayer_poll = false
	root.multiplayer.multiplayer_peer = ClientPeer.new()
	synchronizer._active = true
	var time := root.get_node("NetworkTime")
	var completed: Array[int] = []
	var sync_events: Array[int] = []
	time.after_sync.connect(func(): sync_events.append(1))
	_wait_for_time(time, completed)
	time.stop()
	synchronizer.on_initial_sync.emit()
	_check(completed == [ERR_UNAVAILABLE] and sync_events.is_empty()
		and not time._is_active(), "cancelled initial sync cannot activate a later session")
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var overlay: CanvasLayer = load("res://ui/network_join_overlay.gd").new()
	root.add_child(overlay)
	var retries: Array[int] = []
	overlay.retry_requested.connect(func(): retries.append(1))
	for viewport_size in [Vector2i(1280, 720), Vector2i(320, 568)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		overlay.show_status(false, "Game synchronization timed out")
		await process_frame
		await process_frame
		var rect: Rect2 = overlay._message.get_global_rect()
		_check(rect.position.x >= 0 and rect.end.x <= viewport_size.x
			and rect.position.y >= 0 and rect.end.y <= viewport_size.y,
			"joining text stays inside viewport %s: rect=%s visible=%s" % [viewport_size, rect, root.get_visible_rect()])
	_check(overlay._retry.visible, "failure exposes retry")
	overlay._retry.pressed.emit()
	_check(retries.size() == 1, "retry button dispatches action")
	overlay.show_status(true, "")
	_check(not overlay.visible, "ready state reveals game")
	overlay.free()
	print("NETWORK_STARTUP_READY_TEST %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _wait_for_time(time: Node, results: Array[int]) -> void:
	results.append(await time.start())

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("FAIL: %s" % message)
