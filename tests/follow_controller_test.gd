extends SceneTree

const FOLLOW := preload("res://player/follow_controller.gd")
var _failures := 0

func _init() -> void:
	var idle := FOLLOW.command(Vector2.ZERO, 0.0, false, 0.0)
	_expect_close(idle["speed"], 0.0, 0.0001, "zero cursor parks")
	_expect_close(idle["yaw_rate"], 0.0, 0.0001, "zero cursor does not turn")

	var edge := FOLLOW.command(Vector2(1.0, 0.0), 0.0, false, 0.0)
	_expect_close(edge["speed"], 0.0, 0.0001, "one-unit movement deadzone")

	var half_distance := (FOLLOW.DEADZONE + FOLLOW.MAX_DISTANCE) * 0.5
	var half := FOLLOW.command(Vector2(half_distance, 0.0), 0.0, false, 0.0)
	_expect_close(half["throttle"], 0.5, 0.0001, "cursor distance maps continuously to throttle")

	var full_offset := Vector2(FOLLOW.MAX_DISTANCE, 0.0)
	var stopped_turn := FOLLOW.command(full_offset, 0.0, false, 0.0, 0.0)
	_expect_close(stopped_turn["yaw_rate"], 0.0, 0.0001, "a stopped ground vehicle cannot pivot")

	var full := FOLLOW.command(full_offset, 0.0, false, 0.0, FOLLOW.SPEED)
	_expect_close(full["speed"], FOLLOW.SPEED, 0.0001, "far cursor reaches normal top speed")
	_expect_close(full["acceleration"], FOLLOW.ACCEL, 0.0001,
		"far cursor requests full drive acceleration")
	if float(full["acceleration"]) <= float(half["acceleration"]):
		_failures += 1
		push_error("cursor length must continuously increase drive acceleration")
	_expect_close(full["yaw_rate"], -1.05, 0.0001, "top-speed steering has a wide ground-vehicle radius")

	var moving := FOLLOW.command(full_offset, 0.0, false, 0.0, 4.0)
	_expect_close(moving["yaw_rate"], -1.4, 0.0001, "steering reaches useful authority only after moving")
	var close_moving := FOLLOW.command(Vector2(4.0, 0.0), 0.0, false, 0.0, 4.0)
	if absf(close_moving["yaw_rate"]) < absf(moving["yaw_rate"]) * 1.6:
		_failures += 1
		push_error("close cursor must have a substantially tighter turn than far cursor")
	if float(close_moving["yaw_acceleration"]) <= float(moving["yaw_acceleration"]):
		_failures += 1
		push_error("close cursor must reach its tighter turn faster than far cursor")

	var fine_angle := deg_to_rad(15.0)
	var fine_offset := Vector2(sin(fine_angle), -cos(fine_angle)) * FOLLOW.MAX_DISTANCE
	var fine := FOLLOW.command(fine_offset, 0.0, false, 0.0, FOLLOW.SPEED)
	if absf(float(fine["yaw_rate"])) >= absf(float(full["yaw_rate"])) * (15.0 / 90.0):
		_failures += 1
		push_error("small heading corrections must use the expanded precision band")

	var planted := FOLLOW.command(full_offset, 0.0, false, 0.0, FOLLOW.SPEED)
	var straight_skid := FOLLOW.command(Vector2(0.0, -4.0), 0.0, false, 0.0,
		FOLLOW.SPEED)
	var drifting := FOLLOW.command(Vector2(4.0, 0.0), 0.0, false, 0.0, FOLLOW.SPEED)
	var airborne := FOLLOW.command(Vector2(4.0, 0.0), 0.0, false, 0.0,
		FOLLOW.SPEED, false, false)
	if float(planted["drift_amount"]) != 0.0:
		_failures += 1
		push_error("a wide full-speed turn must remain planted")
	if float(straight_skid["brake_skid_amount"]) < 0.95 \
			or float(straight_skid["drift_amount"]) != 0.0 \
			or float(straight_skid["acceleration"]) > 5.0:
		_failures += 1
		push_error("pulling inward from top speed must preserve a dramatic braking skid")
	if float(drifting["drift_amount"]) < 0.95 \
			or float(drifting["acceleration"]) >= FOLLOW.BRAKE:
		_failures += 1
		push_error("pulling inward during a sharp fast turn must automatically slide")
	if float(airborne["drift_amount"]) != 0.0:
		_failures += 1
		push_error("automatic drift must require ground support")
	var rear_corner := Vector2(sin(deg_to_rad(45.0)), cos(deg_to_rad(45.0))) * 4.0
	var assisted := FOLLOW.command(rear_corner, 0.0, false, 0.0, FOLLOW.SPEED,
		false, true, 1.0)
	var directly_back := FOLLOW.command(Vector2(0.0, 4.0), 0.0, false, 0.0,
		FOLLOW.SPEED, false, true, 1.0)
	var slow_corner := FOLLOW.command(rear_corner, 0.0, false, 0.0, 4.0,
		false, true, 1.0)
	if float(assisted["drift_assist_amount"]) < 0.95 \
			or float(assisted["yaw_acceleration"]) <= FOLLOW.DRIFT_YAW_ACCEL \
			or float(assisted["acceleration"]) >= FOLLOW.DRIFT_VELOCITY_RESPONSE:
		_failures += 1
		push_error("peak braking in a rear corner must add bounded drift assistance")
	if float(directly_back["drift_assist_amount"]) != 0.0:
		_failures += 1
		push_error("straight-back hard braking must stay outside the corner assist zones")
	if float(slow_corner["drift_assist_amount"]) != 0.0:
		_failures += 1
		push_error("rear-corner placement must not assist without a hard high-speed brake")
	var carved := FOLLOW.drift_carve_velocity(Vector3(0.0, 0.0, -18.0),
		1.0, 1.0, 1.0, 0.5)
	if carved.x >= -1.0 or absf(carved.length() - 18.0) > 0.001:
		_failures += 1
		push_error("drift assistance must bend high-speed momentum around the corner without killing speed")
	var assist_charge := 0.0
	for step in range(40):
		assist_charge = FOLLOW.next_drift_assist_charge(assist_charge, 1.0, 1.0 / 60.0)
	if assist_charge < 0.99:
		_failures += 1
		push_error("drift assist meter must reach MAX after a deliberate corner commit")
	for step in range(28):
		assist_charge = FOLLOW.next_drift_assist_charge(assist_charge, 0.0, 1.0 / 60.0)
	if assist_charge > 0.001:
		_failures += 1
		push_error("drift assist meter must reset quickly after accelerating out")

	var burst := FOLLOW.command(Vector2(3.0, 0.0), 0.0, true, 0.0, FOLLOW.SPEED)
	_expect_close(burst["speed"], FOLLOW.BURST_SPEED, 0.0001, "Space forces full burst speed")
	_expect_close(burst["acceleration"], FOLLOW.BURST_ACCEL, 0.0001, "Space uses heavier burst acceleration")
	_expect_close(burst["yaw_rate"], -0.9, 0.0001, "burst keeps a wider committed turn")

	var reverse_idle := FOLLOW.command(Vector2.ZERO, 0.0, false, 0.0, 0.0, true)
	_expect_close(reverse_idle["speed"], 6.0, 0.0001, "reverse works without cursor throttle")
	_expect_close(reverse_idle["drive_sign"], -1.0, 0.0001, "reverse drives opposite vehicle forward")
	_expect_close(reverse_idle["yaw_rate"], 0.0, 0.0001, "stopped reverse does not pivot")
	var reverse_turn := FOLLOW.command(full_offset, 0.0, false, 0.0, 4.0, true)
	if signf(float(reverse_turn["yaw_rate"])) == signf(float(moving["yaw_rate"])):
		_failures += 1
		push_error("reverse must invert steering response like a ground vehicle")
	if not InputMap.has_action("reverse"):
		_failures += 1
		push_error("reverse action must exist in the project input map")
	else:
		var has_tab := false
		for event in InputMap.action_get_events("reverse"):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_TAB:
				has_tab = true
		if not has_tab:
			_failures += 1
			push_error("Tab must activate reverse")

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
