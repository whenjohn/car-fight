extends SceneTree

class Trace extends "res://diagnostics/network_stage_trace.gd":
	var clock := 1000000
	func _now_usec() -> int:
		return clock

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
	if not _failed:
		print("NETWORK_STAGE_TRACE_TEST PASS")
	quit(1 if _failed else 0)
