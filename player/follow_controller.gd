extends RefCounted
## Deterministic FOLLOW steering ported from godot-sandbox/starter and converted
## from its 30 px/world-unit scale. Direction steers; cursor distance controls speed.

const SPEED := 14.0
const ACCEL := 86.6666667
const DEADZONE := 1.0
const MAX_DISTANCE := 16.0
const CURVE := 1.0
const TURN_NEAR := 30.0
const TURN_FAR := 2.4
const TURN_CURVE := 1.0
const STEER_GAIN := 30.0
const HEADING_DEADZONE := 0.8
const BURST_SPEED := 23.3333333
const BURST_ACCEL := 416.6666667
const BURST_TURN := 6.0
const BURST_FLIP_ON := deg_to_rad(150.0)
const BURST_FLIP_OFF := deg_to_rad(110.0)

static func command(cursor_offset: Vector2, current_yaw: float, burst: bool,
		burst_turn_sign: float) -> Dictionary:
	var distance := cursor_offset.length()
	var desired_yaw := current_yaw
	if distance > 0.0001:
		# Gameplay forward is -Z. atan2(-x, -z) maps the world X/Z intent to body yaw.
		desired_yaw = atan2(-cursor_offset.x, -cursor_offset.y)
	var error := wrapf(desired_yaw - current_yaw, -PI, PI)
	var throttle := clampf((distance - DEADZONE) / (MAX_DISTANCE - DEADZONE), 0.0, 1.0)
	throttle = pow(throttle, CURVE)
	var reach := clampf(distance / MAX_DISTANCE, 0.0, 1.0)
	var turn_cap := lerpf(TURN_NEAR, TURN_FAR, pow(reach, TURN_CURVE))
	var authority := clampf((distance - HEADING_DEADZONE) / (HEADING_DEADZONE * 0.5), 0.0, 1.0)
	var top_speed := SPEED
	var acceleration := ACCEL

	if burst and distance > DEADZONE:
		throttle = 1.0
		top_speed = BURST_SPEED
		acceleration = BURST_ACCEL
		turn_cap = BURST_TURN
		if absf(error) >= BURST_FLIP_ON and is_zero_approx(burst_turn_sign):
			burst_turn_sign = signf(error)
		if not is_zero_approx(burst_turn_sign):
			if absf(error) <= BURST_FLIP_OFF:
				burst_turn_sign = 0.0
			else:
				error = absf(error) * burst_turn_sign
	else:
		burst_turn_sign = 0.0

	return {
		"speed": top_speed * throttle,
		"acceleration": acceleration,
		"yaw_rate": clampf(error * STEER_GAIN, -turn_cap, turn_cap) * authority,
		"burst_turn_sign": burst_turn_sign,
		"throttle": throttle,
	}

