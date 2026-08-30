extends SceneTree

const CONTROLLER := preload("res://player/controller_input.gd")


func _init() -> void:
	var input_source := FileAccess.get_file_as_string("res://player/player_input.gd")
	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	for required in ["JOY_BUTTON_A", "JOY_BUTTON_B", "JOY_BUTTON_X", "JOY_BUTTON_Y",
			"JOY_BUTTON_LEFT_SHOULDER", "JOY_BUTTON_RIGHT_SHOULDER",
			"JOY_AXIS_TRIGGER_LEFT", "JOY_AXIS_TRIGGER_RIGHT"]:
		_assert(required in input_source, "missing gameplay mapping %s" % required)
	_assert("JOY_BUTTON_DPAD_LEFT" in main_source,
		"D-pad-left must cycle the local vehicle")
	_assert(CONTROLLER.shaped_stick(Vector2(0.1, -0.1)).is_zero_approx(),
		"small stick noise must remain neutral")
	var half := CONTROLLER.shaped_stick(Vector2(0.61, 0.0))
	_assert(absf(half.x - 0.5) < 0.001 and is_zero_approx(half.y),
		"stick magnitude must be rescaled after the deadzone")
	var right := CONTROLLER.cursor_offset(Vector2.RIGHT, Vector3.RIGHT,
		Vector3.FORWARD, 20.0)
	_assert(right.distance_to(Vector2(20.0, 0.0)) < 0.001,
		"screen-right stick must follow the camera's right axis")
	var up := CONTROLLER.cursor_offset(Vector2.UP, Vector3.RIGHT,
		Vector3.FORWARD, 20.0)
	_assert(up.distance_to(Vector2(0.0, -20.0)) < 0.001,
		"screen-up stick must follow the camera's up axis")
	var diagonal := CONTROLLER.cursor_offset(Vector2(0.5, -0.5), Vector3.RIGHT,
		Vector3.FORWARD, 20.0)
	_assert(diagonal.length() < 20.0 and diagonal.x > 0.0 and diagonal.y < 0.0,
		"partial diagonal input must preserve direction and analog speed")
	print("CONTROLLER_INPUT_TEST PASS")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CONTROLLER_INPUT_TEST FAIL: %s" % message)
	quit(1)
