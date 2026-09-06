extends SceneTree

const CONNECTION_STATE := preload("res://net/connection_state.gd")

class TrackingPeer extends MultiplayerPeerExtension:
	var status := MultiplayerPeer.CONNECTION_CONNECTED
	var inactive_queries := 0

	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
		return status

	func _get_unique_id() -> int:
		if status != MultiplayerPeer.CONNECTION_CONNECTED:
			inactive_queries += 1
			if inactive_queries == 1:
				print_stack()
		return 1

	func _is_server() -> bool:
		return true

	func _get_available_packet_count() -> int:
		return 0

	func _poll() -> void:
		pass

	func _close() -> void:
		status = MultiplayerPeer.CONNECTION_DISCONNECTED

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(not CONNECTION_STATE.has_connected_peer(null), "missing multiplayer API is inactive")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	root.get_node("NetworkTime").stop()
	var events := root.get_node("NetworkEvents")
	events.enabled = false
	multiplayer_poll = false
	var peer := TrackingPeer.new()
	root.multiplayer.multiplayer_peer = peer
	_check(main.local_player() != null, "connected/offline identity still resolves the player")
	for status in [MultiplayerPeer.CONNECTION_CONNECTING, MultiplayerPeer.CONNECTION_DISCONNECTED]:
		peer.status = status
		_check(main.local_player() == null, "inactive connection has no local gameplay player")
		main._process(0.016)
		main._on_tick(0.016, 100)
		main._send_settled_authority_probes()
		main._on_peer_leave(42)
		main._dots._process(0.016)
		_check(main._dots._local_body() == null, "pickup prediction cannot find an inactive player")
		main.get_node("OilSlicks")._process(0.016)
		main.get_node("LowPolyCity")._process(0.016)
		await process_frame
		_check(peer.inactive_queries == 0, "frame callbacks never query inactive peer identity")
	main._role = "client"
	main._client_cruise_active = true
	events.on_client_stop.emit()
	_check(main._network_status == "DISCONNECTED", "ordinary client records disconnection without quitting")
	_check(not main._client_cruise_active, "disconnect clears automatic client cruise")
	var editor_active: bool = main._combat_editor_active
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	main._unhandled_input(key)
	_check(main._combat_editor_active == editor_active, "disconnected input cannot change gameplay mode")
	await process_frame
	_check(peer.inactive_queries == 0, "disconnect event and following frame stay safe")
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._role = "offline"
	_check(main.local_player() != null, "offline play remains available after replacing the peer")
	main._webrtc_failure_reported = true
	main._network_status = "WEBRTC FAILED: original connection timeout"
	events.on_client_stop.emit()
	main._on_connection_failed()
	main._on_webrtc_failed("late failure callback")
	_check(main._network_status == "WEBRTC FAILED: original connection timeout",
		"late stop/failure callbacks preserve the original WebRTC failure")
	main._startup_gate = load("res://net/startup_readiness.gd").new()
	main._startup_gate.begin(Time.get_ticks_msec())
	var stop_events: Array[int] = []
	events.on_client_stop.connect(func(): stop_events.append(1))
	events.on_client_stop.emit()
	main._update_startup_readiness()
	main._close_startup_connection()
	_check(main._startup_gate.is_failed() and stop_events.size() == 1,
		"readiness cleanup does not duplicate a natural disconnect notification")
	_check(root.multiplayer.multiplayer_peer == null, "failed join releases its peer")
	main.free()
	if not _failed:
		print("CONNECTION_LIFECYCLE_TEST PASS")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("CONNECTION_LIFECYCLE_TEST FAIL: %s" % message)
		_failed = true
