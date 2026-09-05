extends SceneTree

const Interp := preload("res://net/remote_snapshot_interpolation.gd")

class CursorBody extends "res://player/player_body.gd":
	var controlled := true
	var test_usec := 1000000
	func _ready() -> void:
		set_process(false)
	func remote_position_transport_controlled() -> bool:
		return controlled
	func _ensure_remote_visual_roots() -> void:
		pass
	func _remote_cursor_delta(delta: float, elapsed: bool, _now_usec := -1) -> float:
		return super._remote_cursor_delta(delta, elapsed, test_usec)

var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("CURSOR CLOCK ASSERT: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("NetworkTime").stop()
	root.get_node("NetworkEvents").enabled = false
	var transport = root.get_node("RemotePositionTransport")
	transport.set_process(false)
	var old_env := OS.get_environment("CAR_FIGHT_REMOTE_CURSOR_CLOCK")
	OS.unset_environment("CAR_FIGHT_REMOTE_CURSOR_CLOCK")
	transport.configure_presentation("fixed", 75.0, 150.0)
	check(transport.presentation_cursor_clock() == "engine", "default remains engine")
	OS.set_environment("CAR_FIGHT_REMOTE_CURSOR_CLOCK", "invalid")
	transport.configure_presentation("fixed", 75.0, 150.0)
	check(transport.presentation_cursor_clock() == "engine", "unknown opt-in fails closed")
	OS.set_environment("CAR_FIGHT_REMOTE_CURSOR_CLOCK", "elapsed")
	transport.configure_presentation("fixed", 75.0, 150.0)
	check(transport.presentation_cursor_clock() == "elapsed", "explicit opt-in selected")
	check(transport.presentation_delay_msec() == 75.0, "delay unchanged")
	var body := CursorBody.new()
	var input := Node.new()
	input.name = "Input"
	body.add_child(input)
	root.add_child(body)
	var engine_cursor := 100.0
	var elapsed_cursor := 100.0
	var desired := 100.0
	var min_engine := 2.0
	var max_engine := 0.0
	body._remote_cursor_clock_usec = body.test_usec
	for frame in range(120):
		var gap_usec := 20000 if frame % 2 == 0 else 46667
		var wall := float(gap_usec) / 1000000.0
		body.test_usec += gap_usec
		desired += wall * 60.0
		var dt := body._remote_cursor_delta(1.0 / 30.0, true)
		var next := Interp.advance_cursor(elapsed_cursor, desired, dt, 60.0)
		check(absf((next - elapsed_cursor) / (wall * 60.0) - 1.0) < 0.000001,
			"elapsed cursor tracks ordinary jitter")
		var engine_next := Interp.advance_cursor(engine_cursor, desired, 1.0 / 30.0, 60.0)
		var speed := (engine_next - engine_cursor) / (wall * 60.0)
		min_engine = minf(min_engine, speed)
		max_engine = maxf(max_engine, speed)
		engine_cursor = engine_next
		elapsed_cursor = next
	check(min_engine < 0.8 and max_engine > 1.5, "control reproduces pacing mismatch")
	body.test_usec += 6000000
	check(body._remote_cursor_delta(0.016, true) == 0.016, "pause keeps original recovery delta")
	body.test_usec += 20000
	check(is_equal_approx(body._remote_cursor_delta(0.033, true), 0.020), "pause refreshes baseline")
	check(body._remote_cursor_delta(0.033, true) == 0.0, "duplicate clock does not advance")
	body.test_usec -= 1000
	check(body._remote_cursor_delta(0.033, true) == 0.0, "backward monotonic input does not advance")
	check(body._remote_cursor_delta(0.033, false) == 0.033 and body._remote_cursor_clock_usec == -1,
		"disabled mode preserves delta and clears timestamp")
	body._remote_cursor_clock_usec = body.test_usec
	body.controlled = false
	body._process_remote_position(0.016)
	check(body._remote_cursor_clock_usec == -1, "disconnect clears measurement")
	body.controlled = true
	body._remote_cursor_clock_usec = body.test_usec
	body._process_remote_position(0.016)
	check(body._remote_cursor_clock_usec == -1, "missing history clears measurement")
	body._remote_cursor_clock_usec = body.test_usec
	body.set_remote_position_relevant(false, 100)
	check(body._remote_cursor_clock_usec == -1, "relevance leave clears measurement")
	body.set_remote_position_relevant(true, 101)
	check(not body._remote_render_tick_initialized, "relevance entry needs fresh cursor")
	for tick in range(-100, 401):
		body._remote_samples[tick] = Vector3(float(tick), 0.0, 0.0)
		body._remote_rotation_samples[tick] = Quaternion.IDENTITY
	body._process_remote_position(0.016)
	var initial: float = body._remote_render_tick
	body.test_usec += 20000
	body._process_remote_position(0.033)
	check(body._remote_render_tick - initial > 1.1 and body._remote_render_tick - initial < 1.3,
		"real body selects elapsed delta for cursor")
	body._remote_render_tick += 1000.0
	body._remote_interp_warmup_samples = 20
	body.test_usec += 20000
	body._process_remote_position(0.033)
	check(absf(body._remote_render_tick - initial) < 2.0 and body._remote_interp_warmup_samples == 0,
		"large clock discontinuity retains rebase and warmup reset")
	var before: float = body._remote_render_tick
	body.test_usec += 20000
	body._process_remote_position(0.033)
	check(body._remote_render_tick >= before, "ordinary clock correction never reverses cursor")
	body.free()
	if old_env.is_empty():
		OS.unset_environment("CAR_FIGHT_REMOTE_CURSOR_CLOCK")
	else:
		OS.set_environment("CAR_FIGHT_REMOTE_CURSOR_CLOCK", old_env)
	if not failed:
		print("REMOTE_CURSOR_CLOCK_TEST PASS opt-in, jitter, pause, lifecycle and rebase")
	quit(1 if failed else 0)
