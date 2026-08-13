extends Node
## Stage 0 contains no 2D or 3D content. It only opens Godot's rendered window
## and emits low-rate evidence so fullscreen behavior can be compared safely.

const STAGE := 0

var _telemetry: FileAccess
var _sample_elapsed := 0.0
var _quit_after_ticks := 0
var _ticks := 0


func _ready() -> void:
	_parse_args()
	_open_telemetry()
	var details := _display_details()
	print("RENDER_ISOLATION_READY stage=%d driver=%s mode=%s size=%s" % [
		STAGE,
		details["rendering_driver"],
		details["window_mode_name"],
		str(details["window_size"]),
	])
	_write("start", details)


func _process(delta: float) -> void:
	_sample_elapsed += delta
	if _sample_elapsed < 1.0:
		return
	_sample_elapsed = 0.0
	var details := _display_details()
	details["fps"] = Engine.get_frames_per_second()
	_write("sample", details)


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _quit_after_ticks > 0 and _ticks >= _quit_after_ticks:
		get_tree().quit()


func _exit_tree() -> void:
	_write("stop", {})
	if _telemetry != null:
		_telemetry.close()
		_telemetry = null


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		if args[index] == "--ticks" and index + 1 < args.size():
			index += 1
			_quit_after_ticks = int(args[index])
		elif args[index].begins_with("--ticks="):
			_quit_after_ticks = int(args[index].get_slice("=", 1))
		index += 1


func _open_telemetry() -> void:
	var path := OS.get_environment("CAR_FIGHT_TELEMETRY_FILE")
	if path.is_empty():
		return
	_telemetry = FileAccess.open(path, FileAccess.WRITE)
	if _telemetry == null:
		push_warning("Could not open telemetry path: %s" % path)


func _display_details() -> Dictionary:
	var mode := int(DisplayServer.window_get_mode())
	var screen := DisplayServer.window_get_current_screen()
	return {
		"stage": STAGE,
		"display_driver": DisplayServer.get_name(),
		"rendering_driver": str(RenderingServer.get_current_rendering_driver_name()),
		"video_adapter": str(RenderingServer.get_video_adapter_name()),
		"video_api": str(RenderingServer.get_video_adapter_api_version()),
		"window_mode": mode,
		"window_mode_name": _window_mode_name(mode),
		"window_size": _vector2i_array(DisplayServer.window_get_size()),
		"screen": screen,
		"screen_size": _vector2i_array(DisplayServer.screen_get_size(screen)),
	}


func _write(event: String, data: Dictionary) -> void:
	if _telemetry == null:
		return
	var record := data.duplicate()
	record["event"] = event
	record["pid"] = OS.get_process_id()
	record["local_time"] = Time.get_datetime_string_from_system(false, true)
	record["monotonic_msec"] = Time.get_ticks_msec()
	_telemetry.store_line(JSON.stringify(record))
	_telemetry.flush()


func _vector2i_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


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
