extends SceneTree

const FOLLOW := preload("res://player/follow_controller.gd")
var _failures := 0

func _init() -> void:
	var idle := FOLLOW.command(Vector2.ZERO, 0.0, false, 0.0)
	_expect_close(idle["speed"], 0.0, 0.0001, "zero cursor parks")
	_expect_close(idle["yaw_rate"], 0.0, 0.0001, "zero cursor does not turn")

	var edge := FOLLOW.command(Vector2(1.0, 0.0), 0.0, false, 0.0)
	_expect_close(edge["speed"], 0.0, 0.0001, "one-unit movement deadzone")

	var half := FOLLOW.command(Vector2(8.5, 0.0), 0.0, false, 0.0)
	_expect_close(half["throttle"], 0.5, 0.0001, "cursor distance maps continuously to throttle")

	var stopped_turn := FOLLOW.command(Vector2(16.0, 0.0), 0.0, false, 0.0, 0.0)
	_expect_close(stopped_turn["yaw_rate"], 0.0, 0.0001, "a stopped ground vehicle cannot pivot")

	var full := FOLLOW.command(Vector2(16.0, 0.0), 0.0, false, 0.0, 14.0)
	_expect_close(full["speed"], 14.0, 0.0001, "far cursor reaches normal top speed")
	_expect_close(full["yaw_rate"], -1.044, 0.0001, "top-speed steering has a wide ground-vehicle radius")

	var moving := FOLLOW.command(Vector2(16.0, 0.0), 0.0, false, 0.0, 4.0)
	_expect_close(moving["yaw_rate"], -1.334, 0.0001, "steering reaches useful authority only after moving")
	var close_moving := FOLLOW.command(Vector2(4.0, 0.0), 0.0, false, 0.0, 4.0)
	if absf(close_moving["yaw_rate"]) < absf(moving["yaw_rate"]) * 1.6:
		_failures += 1
		push_error("close cursor must have a substantially tighter turn than far cursor")
	if float(close_moving["yaw_acceleration"]) <= float(moving["yaw_acceleration"]):
		_failures += 1
		push_error("close cursor must reach its tighter turn faster than far cursor")

	var burst := FOLLOW.command(Vector2(3.0, 0.0), 0.0, true, 0.0, 14.0)
	_expect_close(burst["speed"], 23.3333333, 0.0001, "Space forces full burst speed")
	_expect_close(burst["acceleration"], 32.0, 0.0001, "Space uses heavier burst acceleration")
	_expect_close(burst["yaw_rate"], -0.85, 0.0001, "burst keeps a wider committed turn")

	var escape := {
		"stall_time": 0.0,
		"escape_time": 0.0,
		"escape_sign": 0.0,
	}
	var escape_started := false
	for step in range(40):
		escape = FOLLOW.collision_escape(14.0, 0.0, 0.0,
			escape["stall_time"], escape["escape_time"], escape["escape_sign"],
			1.0 / 120.0, 1.0)
		escape_started = escape_started or bool(escape["started"])
	if not escape_started or not bool(escape["active"]):
		_failures += 1
		push_error("sustained requested movement at zero speed must arm collision escape")
	_expect_close(escape["escape_sign"], 1.0, 0.0001, "straight collision uses stable fallback side")

	var side_escape := {"stall_time": 0.0, "escape_time": 0.0, "escape_sign": 0.0}
	for step in range(40):
		side_escape = FOLLOW.collision_escape(14.0, 0.0, -0.5,
			side_escape["stall_time"], side_escape["escape_time"], side_escape["escape_sign"],
			1.0 / 120.0, 1.0)
	_expect_close(side_escape["escape_sign"], -1.0, 0.0001, "collision escape honors cursor steering side")

	var right_escape_direction := FOLLOW.escape_drive_direction(Vector3.FORWARD, -1.0)
	_expect_vector_close(right_escape_direction, Vector3.RIGHT, 0.0001,
		"right escape yaw and drive deflection agree")
	var left_escape_direction := FOLLOW.escape_drive_direction(Vector3.FORWARD, 1.0)
	_expect_vector_close(left_escape_direction, Vector3.LEFT, 0.0001,
		"left escape yaw and drive deflection agree")

	var clear_launch := FOLLOW.collision_escape(14.0, 2.0, 0.0, 0.2, 0.0, 0.0, 1.0 / 120.0, 1.0)
	if bool(clear_launch["active"]):
		_failures += 1
		push_error("a normally moving launch must not trigger collision escape")

	var head_on_bump := FOLLOW.wall_bump(
		Vector3.RIGHT, Vector3(10.0, 0.0, 0.0), Vector3.LEFT, 1.0, 2.2)
	if not bool(head_on_bump["active"]):
		_failures += 1
		push_error("a head-on wall impact must create a bump")
	var head_on_impulse: Vector3 = head_on_bump["linear_impulse"]
	if head_on_impulse.dot(Vector3.LEFT) <= 0.5:
		_failures += 1
		push_error("wall bump must push outward along the contact normal")
	if absf(head_on_impulse.dot(Vector3.FORWARD)) > 0.0001:
		_failures += 1
		push_error("wall bump must not prescribe an along-wall velocity")
	if float(head_on_bump["yaw_impulse"]) <= 0.0:
		_failures += 1
		push_error("head-on bump must add yaw on the preferred steering side")
	if absf(float(head_on_bump["yaw_impulse"])) > 10.0:
		_failures += 1
		push_error("wall yaw impulse must stay below the sphere collider's spin threshold")

	var glancing_bump := FOLLOW.wall_bump(
		Vector3(1.0, 0.0, -1.0).normalized(), Vector3(8.0, 0.0, -8.0), Vector3.LEFT, -1.0, 2.2)
	var glancing_impulse: Vector3 = glancing_bump["linear_impulse"]
	if not bool(glancing_bump["active"]) or glancing_impulse.x >= -0.5:
		_failures += 1
		push_error("a glancing impact must receive an outward normal impulse")
	if absf(glancing_impulse.z) > 0.0001:
		_failures += 1
		push_error("a glancing bump must leave its existing tangent momentum untouched")

	if _failures == 0:
		print("FOLLOW_TEST PASS")
		quit()
	else:
		push_error("FOLLOW_TEST FAIL failures=%d" % _failures)
		quit(1)

func _expect_close(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures += 1
		push_error("%s: expected %.6f, got %.6f" % [label, expected, actual])

func _expect_vector_close(actual: Vector3, expected: Vector3, tolerance: float, label: String) -> void:
	if actual.distance_to(expected) > tolerance:
		_failures += 1
		push_error("%s: expected %s, got %s" % [label, expected, actual])
