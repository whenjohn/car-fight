extends SceneTree

class Trace extends "res://diagnostics/network_stage_trace.gd":
	var clock := 1000000
	func _now_usec() -> int:
		return clock

class StartupBody extends RigidBody3D:
	var remote_state_generation := 2
	var admission_required := true
	var activation_tick := -1
	func gameplay_active() -> bool:
		return false
	var physics_state := [Vector3(4, 0, 0), Quaternion.IDENTITY,
		Vector3(3, 0, 0), Vector3.ZERO, false]
	func presented_position() -> Vector3:
		return global_position + Vector3.RIGHT

class StartupMain extends Node:
	func network_startup_ready() -> bool:
		return false
	func local_player() -> Node:
		return get_node_or_null("Players/42")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("NETWORK_STAGE_TRACE_TEST FAIL: %s" % message)


func _run() -> void:
	root.get_node("NetworkTime").stop()
	root.get_node("NetworkEvents").enabled = false
	var trace := Trace.new()
	root.add_child(trace)
	_check(not trace._running and trace._connections.is_empty(), "default has no signal observers")
	var output := "user://network-stages-test-%d.jsonl" % OS.get_process_id()
	trace.start(output, 2.0)
	trace.set_process(false)
	var initial_count := trace._records.size()
	trace._startup_panic(6.0)
	_check(trace._records.size() == initial_count, "startup observers default off")
	trace._begin_loop()
	trace._begin_forward(0.016, 10)
	trace.clock += 2000
	trace._end_forward(0.016, 10)
	trace._begin_rollback()
	trace._prepare(9)
	trace.clock += 3000
	trace._simulate(9)
	trace.clock += 5000
	trace._record_state(10)
	trace.clock += 7000
	trace._end_rollback()
	trace._end_loop()
	var loop: Dictionary = trace._records.back()
	_check(loop["forward_usec"] == 2000 and loop["forward_ticks"] == 1, "forward span")
	_check(loop["prepare_usec"] == 3000 and loop["simulate_usec"] == 5000
		and loop["record_usec"] == 7000, "rollback phases remain separate")
	_check(loop["rollback_usec"] == 15000 and loop["rollback_ticks"] == 1, "nested rollback total")
	_check(loop["end_usec"] - loop["start_usec"] == 17000, "outer elapsed span")
	trace._process(0.016)
	trace.clock += 250000
	trace._process(0.016)
	_check(trace._records.back()["wall_gap_usec"] == 250000, "wall gap independent of engine delta")
	var started := trace.publication_started()
	trace.clock += 300
	trace.record_publication(started, "legacy", 1, 10, 42, 2)
	_check(trace._records.back()["end_usec"] - started == 300, "publication queueing span")
	trace._begin_loop()
	trace._reset_epoch()
	trace._end_loop()
	_check(trace._records.back()["event"] == "connection_epoch", "disconnect discards unfinished span")
	trace.clock += 2000000
	trace._process(0.016)
	_check(not trace._running and trace._connections.is_empty(), "deadline disconnects observers")
	_check(trace.publication_started() == -1, "disabled publication marker is a no-op")
	var file := FileAccess.open(output, FileAccess.READ)
	_check(file != null, "trace file exists")
	if file != null:
		var lines := file.get_as_text().strip_edges().split("\n")
		var complete: Dictionary = JSON.parse_string(lines[-1])
		_check(complete["event"] == "complete" and complete["dropped"] == 0, "completion footer")
		file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output))
	trace.start(output, 1.0)
	trace.set_process(false)
	for i in trace.RECORD_CAP:
		trace._record({"event": "test", "index": i})
	_check(trace._records.size() == trace.RECORD_CAP and trace._dropped > 0, "bounded record storage")
	trace.free()
	_check(FileAccess.file_exists(output), "early exit flushes")
	if FileAccess.file_exists(output):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output))
	_test_startup(output)
	if not _failed:
		print("NETWORK_STAGE_TRACE_TEST PASS")
	quit(1 if _failed else 0)


func _test_startup(output: String) -> void:
	var main := StartupMain.new()
	root.add_child(main)
	current_scene = main
	var players := Node3D.new()
	players.name = "Players"
	main.add_child(players)
	var body := StartupBody.new()
	body.name = "42"
	body.position = Vector3(2, 0, 0)
	var sync: Node = load("res://addons/netfox/rollback/rollback-synchronizer.gd").new()
	sync.name = "RollbackSynchronizer"
	body.add_child(sync)
	players.add_child(body)
	sync.root = body
	sync.process_settings()
	sync._history_transmitter._latest_state_tick = 90
	sync._states.set_snapshot(89, {":physics_state": body.physics_state})
	sync._inputs.set_snapshot(95, {"Input:cursor_offset": Vector2(12, 0), "Input:editing": false})
	var trace := Trace.new()
	root.add_child(trace)
	trace.start(output, 2.0, 60.0)
	trace.set_process(false)
	_check(trace._startup_deadline_usec == trace.clock + 2000000, "startup bounded by parent duration")
	trace._startup_synced()
	trace._startup_panic(6.0)
	_check(trace._records.back()["event"] == "startup_panic"
		and trace._records.back()["offset_seconds"] == 6.0, "panic marker retains offset")
	trace._sample_startup(trace.clock)
	var sample: Dictionary = trace._records.back()
	_check(sample["event"] == "startup_sample" and sample["generation"] == 2, "body identity")
	_check(sample["startup_ready"] == false, "startup gate selection is observed with the pose")
	_check(sample["clock_offset_seconds"] == null and sample["remote_offset_seconds"] == null
		and sample["fresh_clock_samples"] == false, "unsynchronized clock readiness is unavailable, not zero")
	var time := root.get_node("NetworkTime")
	var synchronizer := root.get_node("NetworkTimeSynchronizer")
	var original_offset: float = synchronizer._offset
	time._initial_sync_done = true
	synchronizer._offset = 0.25
	var clock_record: Dictionary = trace._startup_clock()
	_check(clock_record["clock_offset_seconds"] is float
		and is_equal_approx(clock_record["remote_offset_seconds"], 0.25),
		"trace exposes both distinct readiness clock offsets")
	time._initial_sync_done = false
	synchronizer._offset = original_offset
	_check(sample["admission_required"] == true and sample["activation_tick"] == -1,
		"server admission state is observed with the pose")
	_check(sample["node_position"] == [2.0, 0.0, 0.0]
		and sample["presented_position"] == [3.0, 0.0, 0.0]
		and sample["physics"]["position"] == [4.0, 0.0, 0.0], "separate node, visual and physics poses")
	_check(sample["history_at_latest_state"] == null, "missing exact state is not replaced by older history")
	_check(sample["latest_input_tick"] == 95 and sample["recorded_cursor"] == [12.0, 0.0]
		and sample["recorded_editing"] == false, "exact recorded input")
	sync._states.set_snapshot(90, {":physics_state": body.physics_state})
	trace._sample_startup(trace.clock)
	_check(trace._records.back()["history_at_latest_state"]["position"] == [4.0, 0.0, 0.0], "exact state lookup")
	body.physics_state[0] = Vector3.ZERO
	_check(trace._records.back()["physics"]["position"] == [4.0, 0.0, 0.0], "retained samples do not alias state")
	sync._inputs.clear()
	trace._sample_startup(trace.clock)
	_check(trace._records.back()["latest_input_tick"] == -1
		and trace._records.back()["recorded_cursor"] == null, "empty input history remains unknown")
	body.free()
	var count := trace._records.size()
	trace._sample_startup(trace.clock)
	_check(trace._records.size() == count, "freed body not sampled")
	trace._reset_epoch()
	var replacement := StartupBody.new()
	replacement.name = "42"
	replacement.remote_state_generation = 3
	players.add_child(replacement)
	trace._sample_startup(trace.clock)
	_check(trace._records.back()["epoch"] == 1 and trace._records.back()["generation"] == 3
		and trace._records.back()["instance_id"] != sample["instance_id"], "replacement starts new identity")
	trace._startup_samples = trace.STARTUP_SAMPLE_CAP
	trace._sample_startup(trace.clock)
	_check(trace._startup_dropped == 1, "startup sample storage is bounded and drops counted")
	trace.clock = trace._startup_deadline_usec
	count = trace._records.size()
	trace._sample_startup(trace.clock)
	trace._startup_panic(7.0)
	_check(trace._records.size() == count, "deadline excludes samples and events")
	trace.finish()
	_check(trace._connections.is_empty(), "startup signals disconnected at finish")
	var lines := FileAccess.get_file_as_string(output).strip_edges().split("\n")
	var footer: Dictionary = JSON.parse_string(lines[-1])
	_check(footer["startup_dropped"] == 1, "startup truncation visible in footer")
	trace.free()
	main.free()
	current_scene = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(output))
