extends Node3D
## Clean-room rendering control made only from Godot engine primitives.

const SAMPLE_INTERVAL_SECONDS := 1.0

var _telemetry: FileAccess
var _started_msec := 0
var _sample_elapsed := 0.0
var _last_window_mode := -1
var _auto_quit_after_seconds := -1.0
var _quit_requested := false


func _ready() -> void:
	_build_control_scene()
	_started_msec = Time.get_ticks_msec()
	_last_window_mode = int(DisplayServer.window_get_mode())
	_configure_auto_quit()
	_open_telemetry()
	_write_record("stage0_start", _display_state())


func _process(delta: float) -> void:
	var window_mode := int(DisplayServer.window_get_mode())
	if window_mode != _last_window_mode:
		var mode_change := _display_state()
		mode_change["previous_window_mode"] = _last_window_mode
		_write_record("window_mode_change", mode_change)
		_last_window_mode = window_mode
	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_INTERVAL_SECONDS:
		_sample_elapsed = 0.0
		var sample := _display_state()
		sample["fps"] = Engine.get_frames_per_second()
		sample["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sample["static_memory_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
		sample["render_objects"] = Performance.get_monitor(
			Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		sample["render_primitives"] = Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		sample["draw_calls"] = Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_write_record("stage0_sample", sample)
	_service_auto_quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_write_record("focus_in", {})
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_write_record("focus_out", {})
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_record("close_requested", {})


func _exit_tree() -> void:
	_write_record("stage0_stop", {})
	if _telemetry != null:
		_telemetry.close()
		_telemetry = null


func _build_control_scene() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("182235")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c8e8")
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	camera.position = Vector3(7.0, 5.5, 8.0)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	plane.material = _material(Color("34485c"))
	ground.mesh = plane
	add_child(ground)

	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.0, 3.0)
	box.material = _material(Color("d98545"))
	marker.mesh = box
	marker.position = Vector3(0.0, 0.5, 0.0)
	add_child(marker)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


func _configure_auto_quit() -> void:
	var value := OS.get_environment("CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS")
	if value.is_empty():
		return
	_auto_quit_after_seconds = maxf(float(value), 1.0)


func _service_auto_quit() -> void:
	if _quit_requested or _auto_quit_after_seconds < 0.0:
		return
	var elapsed_seconds := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if elapsed_seconds < _auto_quit_after_seconds:
		return
	_quit_requested = true
	_write_record("auto_quit", {"elapsed_seconds": elapsed_seconds})
	get_tree().quit()


func _open_telemetry() -> void:
	var path := OS.get_environment("CAR_FIGHT_BISECT_TELEMETRY")
	if path.is_empty():
		return
	_telemetry = FileAccess.open(path, FileAccess.WRITE)
	if _telemetry == null:
		push_warning("Could not open render-control telemetry: %s" % error_string(
			FileAccess.get_open_error()))


func _write_record(event: String, data: Dictionary) -> void:
	if _telemetry == null:
		return
	var record := data.duplicate()
	record["event"] = event
	record["pid"] = OS.get_process_id()
	record["monotonic_msec"] = Time.get_ticks_msec()
	record["unix_time"] = Time.get_unix_time_from_system()
	_telemetry.store_line(JSON.stringify(record))
	_telemetry.flush()


func _display_state() -> Dictionary:
	var screen := DisplayServer.window_get_current_screen()
	return {
		"display_driver": DisplayServer.get_name(),
		"rendering_method": str(ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "unknown")),
		"rendering_driver": _rendering_string("get_current_rendering_driver_name"),
		"video_adapter": _rendering_string("get_video_adapter_name"),
		"video_vendor": _rendering_string("get_video_adapter_vendor"),
		"window_mode": int(DisplayServer.window_get_mode()),
		"window_size": _vector2i_array(DisplayServer.window_get_size()),
		"window_position": _vector2i_array(DisplayServer.window_get_position()),
		"window_focused": DisplayServer.window_is_focused(),
		"screen": screen,
		"screen_size": _vector2i_array(DisplayServer.screen_get_size(screen)),
		"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(screen),
	}


func _rendering_string(method: String) -> String:
	return str(RenderingServer.call(method)) if RenderingServer.has_method(method) else "unknown"


func _vector2i_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]
