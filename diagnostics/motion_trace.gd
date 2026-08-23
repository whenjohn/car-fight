extends Node
## Harness-only presented-motion recorder and fixed-screen heartbeat trace.

const GRAPH_SCRIPT := preload("res://diagnostics/motion_trace_graph.gd")
const EXPECTED_ACCEL_LIMIT := 45.0
const TELEMETRY_BATCH := 60
const MAX_CAPTURE_SAMPLES := 18000

var _main: Node
var _players: Node3D
var _camera: Camera3D
var _graph: Control
var _status: Label
var _recording := false
var _capture_id := 0
var _target_id := 0
var _previous_position := Vector3.ZERO
var _expected_velocity := Vector2.ZERO
var _expected_frame_seconds := 1.0 / 60.0
var _initialized := false
var _sample_count := 0
var _telemetry_buffer: Array = []


func setup(main: Node, players: Node3D, camera: Camera3D) -> void:
	_main = main
	_players = players
	_camera = camera
	process_priority = 100
	var layer := CanvasLayer.new()
	layer.name = "MotionTraceHUD"
	layer.layer = 12
	add_child(layer)
	_graph = Control.new()
	_graph.name = "MotionHeartbeatGraph"
	_graph.set_script(GRAPH_SCRIPT)
	_graph.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_graph.offset_left = -430.0
	_graph.offset_top = -205.0
	_graph.offset_right = 430.0
	_graph.offset_bottom = -55.0
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_graph)
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status.offset_left = -320.0
	_status.offset_top = -50.0
	_status.offset_right = 320.0
	_status.offset_bottom = -18.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color("8de8ff"))
	_status.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_status)
	_update_status()


func toggle() -> void:
	if _recording:
		stop_capture()
	else:
		start_capture()


func start_capture() -> void:
	_flush_telemetry()
	_graph.call("clear_samples")
	_capture_id += 1
	_recording = true
	_target_id = 0
	_initialized = false
	_sample_count = 0
	_telemetry_buffer.clear()
	_emit_event("start")
	_update_status()


func stop_capture() -> void:
	if not _recording:
		return
	_recording = false
	_flush_telemetry()
	_emit_event("stop")
	_update_status()


func _exit_tree() -> void:
	if _recording:
		stop_capture()
	else:
		_flush_telemetry()


func _process(delta: float) -> void:
	if not _recording or _players == null or _camera == null or delta <= 0.0:
		return
	var target := _human_remote()
	if target == null:
		_update_status()
		return
	var observed_id := int(target.name)
	if observed_id != _target_id:
		_target_id = observed_id
		_initialized = false
		_emit_event("target")
		_update_status()
	var position: Vector3 = target.call("presented_position") \
		if target.has_method("presented_position") else target.global_position
	if not _initialized:
		_previous_position = position
		_expected_velocity = Vector2(target.linear_velocity.x, target.linear_velocity.z) \
			if target is RigidBody3D else Vector2.ZERO
		_expected_frame_seconds = delta
		_initialized = true
		return
	var actual_delta3 := position - _previous_position
	var actual_delta := Vector2(actual_delta3.x, actual_delta3.z)
	var actual_velocity := actual_delta / delta
	var next_expected := bounded_expected_velocity(_expected_velocity,
		actual_velocity, delta, EXPECTED_ACCEL_LIMIT)
	var expected_delta := (_expected_velocity + next_expected) * 0.5 * delta
	var residual := actual_delta - expected_delta
	var heading := next_expected.normalized() if next_expected.length_squared() > 0.0001 \
		else (actual_velocity.normalized() if actual_velocity.length_squared() > 0.0001 \
		else Vector2(0.0, -1.0))
	var side := Vector2(-heading.y, heading.x)
	var longitudinal := residual.dot(heading)
	var lateral := residual.dot(side)
	var residual_magnitude := residual.length()
	var frame_excess := maxf(delta - maxf(_expected_frame_seconds * 1.8, 0.050), 0.0)
	var stall_distance := frame_excess * next_expected.length()
	_graph.call("add_sample", longitudinal, lateral, frame_excess * 1000.0)
	_record_sample(target, position, actual_velocity, next_expected, longitudinal,
		lateral, residual_magnitude, frame_excess, delta)
	_previous_position = position
	_expected_velocity = next_expected
	_expected_frame_seconds = lerpf(_expected_frame_seconds, delta,
		1.0 - exp(-delta / 0.5))
	_sample_count += 1
	if _sample_count >= MAX_CAPTURE_SAMPLES:
		stop_capture()


static func bounded_expected_velocity(previous: Vector2, measured: Vector2,
		delta: float, acceleration_limit: float = EXPECTED_ACCEL_LIMIT) -> Vector2:
	return previous.move_toward(measured, maxf(acceleration_limit, 0.0) * maxf(delta, 0.0))


func _human_remote() -> RigidBody3D:
	if _main == null or not _main.has_method("local_player"):
		return null
	var local := _main.call("local_player") as Node
	if local == null:
		return null
	var local_id := int(local.name)
	for child in _players.get_children():
		if child is RigidBody3D and int(child.name) not in [1, local_id]:
			return child as RigidBody3D
	return null


func _record_sample(target: RigidBody3D, position: Vector3, actual_velocity: Vector2,
		expected_velocity: Vector2, longitudinal: float, lateral: float,
		residual_magnitude: float, frame_excess: float, delta: float) -> void:
	var local := _main.call("local_player") as Node3D
	var remote_screen := Vector2.ZERO
	var local_screen := Vector2.ZERO
	if _camera.is_inside_tree():
		remote_screen = _camera.unproject_position(position)
		if local != null and local.is_inside_tree():
			local_screen = _camera.unproject_position(local.global_position)
	var context: Dictionary = _main.call("motion_trace_context") \
		if _main.has_method("motion_trace_context") else {}
	# Compact fixed-order rows keep 60 Hz capture from perturbing the browser.
	# Schema is emitted with every start event and samples flush once per second.
	_telemetry_buffer.append([
		Time.get_ticks_usec(), int(Time.get_unix_time_from_system() * 1000.0),
		Engine.get_process_frames(), int(context.get("tick", -1)), delta * 1000.0,
		int(target.name), position.x, position.y, position.z,
		actual_velocity.x, actual_velocity.y, expected_velocity.x, expected_velocity.y,
		longitudinal, lateral, residual_magnitude, frame_excess * 1000.0,
		remote_screen.x - local_screen.x, remote_screen.y - local_screen.y,
		float(context.get("fps", 0.0)), float(context.get("rtt_ms", 0.0)),
		float(context.get("presentation_ms", 0.0)),
		float(context.get("headroom_ms", 0.0)),
		float(context.get("interp", 0.0)), float(context.get("extrapolate", 0.0)),
		float(context.get("hold", 0.0)), float(context.get("correction", 0.0)),
		int(context.get("recoveries", 0)), float(context.get("rollback_ms", 0.0)),
		int(context.get("rollback_ticks", 0)),
	])
	if _telemetry_buffer.size() >= TELEMETRY_BATCH:
		_flush_telemetry()


func _emit_event(event_name: String) -> void:
	var context: Dictionary = _main.call("motion_trace_context") \
		if _main != null and _main.has_method("motion_trace_context") else {}
	var event := {
		"event": event_name, "capture": _capture_id, "target": _target_id,
		"run_id": context.get("run_id", ""), "monotonic_us": Time.get_ticks_usec(),
		"unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"frame": Engine.get_process_frames(), "tick": context.get("tick", -1),
		"schema": ["monotonic_us", "unix_ms", "frame", "tick", "frame_ms",
			"target", "world_x", "world_y", "world_z", "actual_vx", "actual_vz",
			"expected_vx", "expected_vz", "residual_longitudinal",
			"residual_lateral", "residual_magnitude", "frame_excess_ms",
			"screen_relative_x", "screen_relative_y", "fps", "rtt_ms",
			"presentation_ms", "headroom_ms", "interp", "extrapolate", "hold",
			"worst_correction", "recoveries", "rollback_ms", "rollback_ticks"],
	}
	print("MOTIONTRACE_EVENT %s" % JSON.stringify(event))


func _flush_telemetry() -> void:
	if _telemetry_buffer.is_empty():
		return
	print("MOTIONTRACE_SAMPLES %s" % JSON.stringify({
		"capture": _capture_id, "samples": _telemetry_buffer}))
	_telemetry_buffer = []


func _update_status() -> void:
	if _status == null:
		return
	var context: Dictionary = _main.call("motion_trace_context") \
		if _main != null and _main.has_method("motion_trace_context") else {}
	var observer := "%s peer %d" % [str(context.get("transport", "client")).to_upper(),
		int(context.get("local_peer", 0))]
	if _recording:
		_status.text = "%s OBSERVING %s  ·  TRACE %d ● RECORDING  ·  L: STOP" % [
			observer, "waiting for other human" if _target_id == 0 \
			else "human peer %d" % _target_id, _capture_id]
		_status.add_theme_color_override("font_color", Color("ff6b8f"))
	elif _capture_id > 0:
		_status.text = "%s  ·  TRACE %d ■ FROZEN  ·  L: CLEAR + START NEW" % [
			observer, _capture_id]
		_status.add_theme_color_override("font_color", Color("8de8ff"))
	else:
		_status.text = "MOTION TRACE OFF  ·  L: START"
		_status.add_theme_color_override("font_color", Color("8de8ff"))
