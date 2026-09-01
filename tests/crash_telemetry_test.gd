extends SceneTree

const CRASH_TELEMETRY := preload("res://diagnostics/crash_telemetry.gd")
const TEST_PATH := "user://crash-telemetry-test.jsonl"


func _init() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute_path)
	var telemetry := CRASH_TELEMETRY.new()
	telemetry.output_path = absolute_path
	telemetry.role = "test"
	telemetry.call("_ready")
	telemetry.call("_process", 1.1)
	telemetry.call("record_event", "window_safety_enforced", {
		"reasons": ["oversize"],
		"safe_size": [1280, 720],
	})
	var contents := FileAccess.get_file_as_string(absolute_path)
	telemetry.call("_exit_tree")
	telemetry.free()
	var saw_start := false
	var saw_sample := false
	var saw_window_safety := false
	for line in contents.split("\n", false):
		var record = JSON.parse_string(line)
		if not record is Dictionary:
			_fail("telemetry record is not valid JSON")
			return
		if record.get("event", "") == "start":
			saw_start = record.has("rendering_driver") and record.has("window_mode") \
				and record.has("screen")
		elif record.get("event", "") == "sample":
			saw_sample = record.has("fps") and record.has("draw_calls") \
				and record.has("maximum_frame_ms") and record.has("window_focused") \
				and record.has("maximum_network_loop_ms") \
				and record.has("maximum_rollback_loop_ms") \
				and record.has("maximum_network_ticks") \
				and record.has("maximum_rollback_ticks")
		elif record.get("event", "") == "window_safety_enforced":
			var reasons: Array = record.get("reasons", [])
			var safe_size: Array = record.get("safe_size", [])
			saw_window_safety = reasons.size() == 1 and reasons[0] == "oversize" \
				and safe_size.size() == 2 and int(safe_size[0]) == 1280 \
				and int(safe_size[1]) == 720
	if not saw_start or not saw_sample or not saw_window_safety:
		_fail("flushed output must include start, render, frame, and window evidence; got %s" \
			% contents)
		return
	DirAccess.remove_absolute(absolute_path)
	print("CRASH_TELEMETRY_TEST PASS")
	quit()


func _fail(message: String) -> void:
	push_error("CRASH_TELEMETRY_TEST FAIL: %s" % message)
	quit(1)
