extends Node
## Low-rate, opt-in telemetry for correlating gameplay with a display-system failure.
## The monitored launcher supplies a unique absolute path. Every record is flushed
## immediately so a WindowServer restart cannot strand useful data in a buffer.

const SAMPLE_INTERVAL := 1.0
const SLOW_FRAME_SECONDS := 0.050

var output_path := ""
var role := "unknown"
var console_output := false

var _file: FileAccess
var _sample_elapsed := 0.0
var _sample_frames := 0
var _slow_frames := 0
var _maximum_frame_seconds := 0.0
var _maximum_network_loop_ms := 0.0
var _maximum_rollback_loop_ms := 0.0
var _maximum_network_ticks := 0
var _maximum_rollback_ticks := 0
var _last_slow_frame_event_msec := -10000
var _last_window_mode := -1
var _started_msec := 0
var _fake_stall_after_seconds := -1.0
var _fake_stall_duration_seconds := 0.0
var _fake_stall_done := false
var _network_performance: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop != null:
		_network_performance = main_loop.root.get_node_or_null("NetworkPerformance")
	if output_path.is_empty() and not console_output:
		set_process(false)
		return
	if not output_path.is_empty():
		_file = FileAccess.open(output_path, FileAccess.WRITE)
		if _file == null:
			push_warning("Crash telemetry could not open %s: %s" % [
				output_path, error_string(FileAccess.get_open_error())])
			if not console_output:
				set_process(false)
				return
	_last_window_mode = int(DisplayServer.window_get_mode())
	_started_msec = Time.get_ticks_msec()
	_configure_fake_stall()
	var screen := DisplayServer.window_get_current_screen()
	_write_record("start", {
		"pid": OS.get_process_id(),
		"role": role,
		"display_driver": DisplayServer.get_name(),
		"rendering_method": str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "unknown")),
		"rendering_driver": _rendering_string("get_current_rendering_driver_name"),
		"video_adapter": _rendering_string("get_video_adapter_name"),
		"video_vendor": _rendering_string("get_video_adapter_vendor"),
		"video_api": _rendering_string("get_video_adapter_api_version"),
		"window_mode": _last_window_mode,
		"window_mode_name": _window_mode_name(_last_window_mode),
		"window_size": _vector2i_array(DisplayServer.window_get_size()),
		"window_position": _vector2i_array(DisplayServer.window_get_position()),
		"window_focused": DisplayServer.window_is_focused(),
		"screen": screen,
		"screen_size": _vector2i_array(DisplayServer.screen_get_size(screen)),
		"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(screen),
		"cmdline": OS.get_cmdline_args(),
		"user_args": OS.get_cmdline_user_args(),
		"fake_stall_after_seconds": _fake_stall_after_seconds,
		"fake_stall_duration_seconds": _fake_stall_duration_seconds,
	})


func _process(delta: float) -> void:
	if _file == null and not console_output:
		return
	_service_fake_stall()
	_sample_elapsed += delta
	_sample_frames += 1
	var window_mode := int(DisplayServer.window_get_mode())
	if window_mode != _last_window_mode:
		_write_record("window_mode_change", {
			"previous_window_mode": _last_window_mode,
			"previous_window_mode_name": _window_mode_name(_last_window_mode),
			"window_mode": window_mode,
			"window_mode_name": _window_mode_name(window_mode),
			"window_size": _vector2i_array(DisplayServer.window_get_size()),
		})
		_last_window_mode = window_mode
	_maximum_frame_seconds = maxf(_maximum_frame_seconds, delta)
	# Performance.TIME_PROCESS tells us that a frame was expensive, but not
	# whether netfox spent it catching up forward ticks or replaying rollback.
	# Preserve the worst network sample across the whole telemetry interval so a
	# one-frame spike is not hidden by whichever frame happens to write the row.
	if _network_performance != null:
		_maximum_network_loop_ms = maxf(_maximum_network_loop_ms,
			float(_network_performance.call("get_network_loop_duration_ms")))
		_maximum_rollback_loop_ms = maxf(_maximum_rollback_loop_ms,
			float(_network_performance.call("get_rollback_loop_duration_ms")))
		_maximum_network_ticks = maxi(_maximum_network_ticks,
			int(_network_performance.call("get_network_ticks")))
		_maximum_rollback_ticks = maxi(_maximum_rollback_ticks,
			int(_network_performance.call("get_rollback_ticks")))
	if delta >= SLOW_FRAME_SECONDS:
		_slow_frames += 1
		var now_msec := Time.get_ticks_msec()
		if now_msec - _last_slow_frame_event_msec >= 1000:
			_last_slow_frame_event_msec = now_msec
			_write_record("slow_frame", {"frame_ms": delta * 1000.0})
	if _sample_elapsed < SAMPLE_INTERVAL:
		return
	_write_sample()
	_sample_elapsed = 0.0
	_sample_frames = 0
	_slow_frames = 0
	_maximum_frame_seconds = 0.0
	_maximum_network_loop_ms = 0.0
	_maximum_rollback_loop_ms = 0.0
	_maximum_network_ticks = 0
	_maximum_rollback_ticks = 0


func _notification(what: int) -> void:
	if _file == null and not console_output:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_write_record("focus_in", {})
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_write_record("focus_out", {})
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_record("close_requested", {})


func _exit_tree() -> void:
	if _file == null and not console_output:
		return
	_write_record("stop", {})
	if _file != null:
		_file.close()
		_file = null


func record_event(event: String, data: Dictionary) -> void:
	_write_record(event, data)


func _write_sample() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var data := {
		"fps": Engine.get_frames_per_second(),
		"observed_frames": _sample_frames,
		"slow_frames": _slow_frames,
		"maximum_frame_ms": _maximum_frame_seconds * 1000.0,
		"maximum_network_loop_ms": _maximum_network_loop_ms,
		"maximum_rollback_loop_ms": _maximum_rollback_loop_ms,
		"maximum_network_ticks": _maximum_network_ticks,
		"maximum_rollback_ticks": _maximum_rollback_ticks,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_memory_peak_bytes": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives": Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_memory_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"window_mode": int(DisplayServer.window_get_mode()),
		"window_mode_name": _window_mode_name(int(DisplayServer.window_get_mode())),
		"window_size": _vector2i_array(DisplayServer.window_get_size()),
		"window_position": _vector2i_array(DisplayServer.window_get_position()),
		"window_focused": DisplayServer.window_is_focused(),
		"screen": screen,
		"screen_size": _vector2i_array(DisplayServer.screen_get_size(screen)),
		"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(screen),
	}
	var main := get_parent()
	var local = main.call("local_player") if main != null \
			and main.has_method("local_player") else null
	if local != null:
		data["player_position"] = _vector3_array(local.global_position)
		data["player_velocity"] = _vector3_array(local.linear_velocity)
		data["player_angular_velocity"] = _vector3_array(local.angular_velocity)
		data["player_speed"] = local.call("speed")
		data["map_id"] = int(local.get("map_id"))
		data["brake_skid"] = float(local.get("brake_skid_amount"))
		data["drift_assist"] = float(local.get("drift_assist_amount"))
		data["drift_charge"] = float(local.get("drift_assist_charge"))
		data["drift_latched"] = bool(local.get("drift_assist_latched"))
		data["boost"] = bool(local.get("boost_active"))
	_write_record("sample", data)


func _write_record(event: String, data: Dictionary) -> void:
	if _file == null and not console_output:
		return
	var record := data.duplicate()
	record["event"] = event
	record["role"] = role
	record["pid"] = OS.get_process_id()
	record["monotonic_msec"] = Time.get_ticks_msec()
	record["unix_time"] = Time.get_unix_time_from_system()
	record["local_time"] = Time.get_datetime_string_from_system(false, true)
	var json := JSON.stringify(record)
	if console_output:
		print("CAR_FIGHT_TELEMETRY %s" % json)
	if _file != null:
		_file.store_line(json)
		_file.flush()


func _rendering_string(method: String) -> String:
	return str(RenderingServer.call(method)) if RenderingServer.has_method(method) else "unknown"


func _configure_fake_stall() -> void:
	# Fault injection is intentionally limited to a monitored headless client. It
	# must never make a rendered test—or WindowServer itself—less stable.
	if role != "client" or DisplayServer.get_name() != "headless":
		return
	var after_text := OS.get_environment("CAR_FIGHT_FAKE_STALL_AFTER_SECONDS")
	var duration_text := OS.get_environment("CAR_FIGHT_FAKE_STALL_DURATION_SECONDS")
	if after_text.is_empty() or duration_text.is_empty():
		return
	_fake_stall_after_seconds = maxf(float(after_text), 0.25)
	_fake_stall_duration_seconds = maxf(float(duration_text), 0.25)


func _service_fake_stall() -> void:
	if _fake_stall_done or _fake_stall_after_seconds < 0.0:
		return
	var elapsed_seconds := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if elapsed_seconds < _fake_stall_after_seconds:
		return
	_fake_stall_done = true
	_write_record("fake_stall_begin", {"duration_seconds": _fake_stall_duration_seconds})
	OS.delay_msec(roundi(_fake_stall_duration_seconds * 1000.0))
	_write_record("fake_stall_end", {"duration_seconds": _fake_stall_duration_seconds})


func _vector2i_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


func _vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _window_mode_name(mode: int) -> String:
	match mode:
		DisplayServer.WINDOW_MODE_WINDOWED:
			return "windowed"
		DisplayServer.WINDOW_MODE_MINIMIZED:
			return "minimized"
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			return "maximized"
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return "fullscreen"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return "exclusive_fullscreen"
		_:
			return "unknown_%d" % mode
