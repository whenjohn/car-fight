extends SceneTree

class ClientPeer extends MultiplayerPeerExtension:
	var status := MultiplayerPeer.CONNECTION_CONNECTED
	var server := false

	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
		return status

	func _get_unique_id() -> int:
		return 1 if server else 2

	func _is_server() -> bool:
		return server

	func _get_available_packet_count() -> int:
		return 0

	func _poll() -> void:
		pass

	func _close() -> void:
		status = MultiplayerPeer.CONNECTION_DISCONNECTED

class Receiver extends Node:
	var remote_state_generation := 1
	var deliveries := 0
	var relevant := true

	func remote_position_transport_controlled() -> bool:
		return true

	func is_remote_position_relevant() -> bool:
		return relevant

	func set_remote_position_relevant(value: bool, _tick: int) -> void:
		relevant = value

	func receive_remote_position(_generation: int, _tick: int, _position: Vector3,
			_rotation: Quaternion, _velocity: Vector3, _angular: Vector3) -> bool:
		deliveries += 1
		return true

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("NetworkTime").stop()
	root.get_node("NetworkEvents").enabled = false
	multiplayer_poll = false
	var peer := ClientPeer.new()
	root.multiplayer.multiplayer_peer = peer
	var transport = root.get_node("RemotePositionTransport")
	transport.set_process(false)
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var players := Node.new()
	players.name = "Players"
	main.add_child(players)
	var body := Receiver.new()
	body.name = "42"
	players.add_child(body)
	body.add_to_group("pilotable")
	var path := "user://presentation-trace-test-%d.jsonl" % OS.get_process_id()
	transport.configure_presentation("fixed", 75.0, 150.0, path, 60.0)
	transport._push_legacy(1, 100, 42, 1, Vector3.ZERO, Quaternion.IDENTITY,
		Vector3.RIGHT, Vector3.ZERO)
	_check(body.deliveries == 1, "tracing preserves legacy delivery")
	var records: Array = transport._presentation_trace_records
	_check(records.size() == 1, "legacy arrival starts and records the trace")
	if records.is_empty():
		main.free()
		quit(1)
		return
	_check(records[0].get("type") == "legacy" and records[0].get("delivered") == true,
		"legacy record identifies delivery, body and publication")
	_check(records[0].get("body_id") == 42 and records[0].get("publication") == 1,
		"legacy identity is retained without inventing batch membership")
	transport._process(1.0 / 60.0)
	_check(records.back().get("wall_delta_msec") == -1.0,
		"first frame has no fabricated wall-clock gap")
	transport.observe_presentation_body("42", true, false, 40.0, 75.0, 95.5, "hold")
	OS.delay_msec(260)
	transport._process(1.0 / 60.0)
	var frame: Dictionary = records.back()
	_check(float(frame.get("wall_delta_msec", 0.0)) >= 250.0,
		"wall gap captures a stall even when engine delta stays small")
	_check(bool(frame.get("wall_hitch", false)) and not bool(frame["hitch"]),
		"wall-clock evidence does not alter engine-delta/adaptive semantics")
	_check(frame.has("window_focused"), "frame records window focus")
	_check((frame["bodies"] as Array).size() == 1
		and frame["bodies"][0]["mode"] == "hold"
		and frame["bodies"][0].has("at_msec"),
		"fixed-mode body observations retain their own sampling time")
	_check(transport.presentation_delay_msec() == 75.0,
		"diagnostics do not adjust fixed presentation delay")
	var count := records.size()
	for status in [MultiplayerPeer.CONNECTION_CONNECTING, MultiplayerPeer.CONNECTION_DISCONNECTED]:
		peer.status = status
		transport._process(0.016)
		_check(records.size() == count, "inactive peers do not produce frame evidence")
	peer.status = MultiplayerPeer.CONNECTION_CONNECTED
	peer.server = true
	transport._process(0.016)
	_check(records.size() == count, "server does not record client presentation frames")
	peer.server = false
	transport._reset_receiver_epoch()
	transport._process(0.016)
	_check(records.back().get("wall_delta_msec") == -1.0,
		"reconnect epoch resets wall-clock baseline")
	transport._push_batch(1, 2, 101, 0, PackedInt64Array(), PackedInt32Array(),
		PackedVector3Array(), PackedVector4Array(), PackedVector3Array(), PackedVector3Array())
	transport._process(0.016)
	_check(records.any(func(record): return record.get("type") == "batch"),
		"batch arrival tracing remains available")
	transport._presentation_trace_duration_msec = 1
	transport._presentation_trace_started_msec = Time.get_ticks_msec() - 2
	transport._process(0.016)
	_check(transport._presentation_trace_flushed, "duration automatically flushes trace")
	_check(not transport.presentation_trace_enabled(), "completed trace disables gathering")
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "completed trace is written")
	if file != null:
		var header: Dictionary = JSON.parse_string(file.get_line())
		_check(int(header["record_count"]) == records.size(), "header counts captured records")
		file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	count = records.size()
	transport._push_legacy(3, 102, 42, 1, Vector3.ZERO, Quaternion.IDENTITY,
		Vector3.RIGHT, Vector3.ZERO)
	transport.observe_presentation_body("42", true, false, 40.0, 75.0, 97.0, "hold")
	transport._process(0.016)
	_check(records.size() == count and transport._presentation_body_samples.is_empty(),
		"completed trace stops retaining observations while legacy delivery continues")
	_check(body.deliveries == 2, "completion never blocks delivery")
	transport.configure_presentation("fixed", 75.0, 150.0)
	transport._process(0.016)
	_check(transport._presentation_trace_records.is_empty(), "default play does not record")
	transport.configure_presentation("fixed", 75.0, 150.0, path, 60.0)
	transport._process(0.016)
	_check(transport._presentation_trace_records.size() == 1,
		"connected frames start a trace even before the first publication")
	for index in transport.PRESENTATION_TRACE_RECORD_CAP:
		transport._trace_record({"type": "test", "index": index})
	_check(transport._presentation_trace_records.size() == transport.PRESENTATION_TRACE_RECORD_CAP
		and transport._presentation_trace_dropped == 1, "record storage remains capped")
	transport._exit_tree()
	_check(transport._presentation_trace_flushed, "early exit flushes a partial trace")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	transport.configure_presentation("fixed", 75.0, 150.0)
	main.free()
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if not _failed:
		print("PRESENTATION_TRACE_TEST PASS")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("PRESENTATION_TRACE_TEST FAIL: %s" % message)
