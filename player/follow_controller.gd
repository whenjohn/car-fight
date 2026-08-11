extends RefCounted
## Starter's mouse FOLLOW intent adapted to a ground vehicle. Cursor distance
## still controls throttle, but steering now needs forward motion and widens at speed.

const SPEED := 14.0
const ACCEL := 18.0
const BRAKE := 26.0
const DEADZONE := 1.0
const MAX_DISTANCE := 16.0
const CURVE := 1.0
const HEADING_DEADZONE := 0.8
const TURN_NEAR := 2.2
const TURN_FAR := 1.45
const TURN_CURSOR_CURVE := 1.0
const TURN_ACCEL := 4.0
const STEERING_SPEED_REF := 4.0
const HIGH_SPEED_TURN_SCALE := 0.72
const BURST_SPEED := 23.3333333
const BURST_ACCEL := 32.0
const BURST_TURN := 0.85
const BURST_TURN_ACCEL := 3.0
const BURST_FLIP_ON := deg_to_rad(150.0)
const BURST_FLIP_OFF := deg_to_rad(110.0)

static func command(cursor_offset: Vector2, current_yaw: float, burst: bool,
		burst_turn_sign: float, current_speed: float = 0.0) -> Dictionary:
	var distance := cursor_offset.length()
	var desired_yaw := current_yaw
	if distance > 0.0001:
		# Gameplay forward is -Z. atan2(-x, -z) maps the world X/Z intent to body yaw.
		desired_yaw = atan2(-cursor_offset.x, -cursor_offset.y)
	var error := wrapf(desired_yaw - current_yaw, -PI, PI)
	var throttle := clampf((distance - DEADZONE) / (MAX_DISTANCE - DEADZONE), 0.0, 1.0)
	throttle = pow(throttle, CURVE)
	var cursor_reach := clampf(distance / MAX_DISTANCE, 0.0, 1.0)
	var top_speed := SPEED
	var yaw_acceleration := TURN_ACCEL
	# Keep Starter FOLLOW's useful relationship: a close cursor asks for a
	# tighter low-speed turn, while a far cursor asks for a broad fast arc.
	var turn_cap := lerpf(TURN_NEAR, TURN_FAR, pow(cursor_reach, TURN_CURSOR_CURVE))

	if burst and distance > DEADZONE:
		throttle = 1.0
		top_speed = BURST_SPEED
		turn_cap = BURST_TURN
		yaw_acceleration = BURST_TURN_ACCEL
		if absf(error) >= BURST_FLIP_ON and is_zero_approx(burst_turn_sign):
			burst_turn_sign = signf(error)
		if not is_zero_approx(burst_turn_sign):
			if absf(error) <= BURST_FLIP_OFF:
				burst_turn_sign = 0.0
			else:
				error = absf(error) * burst_turn_sign
	else:
		burst_turn_sign = 0.0
		# A Jeep's turning circle grows further with actual road speed. Cursor
		# reach and road speed therefore reinforce one another without pivoting.
		var road_speed := clampf(current_speed / SPEED, 0.0, 1.0)
		turn_cap *= lerpf(1.0, HIGH_SPEED_TURN_SCALE, road_speed)

	# Ackermann-like behavior without wheel contact simulation: no forward
	# motion means no yaw. Authority ramps in over the first 4 units/s.
	var speed_authority := clampf(current_speed / STEERING_SPEED_REF, 0.0, 1.0)
	var cursor_authority := clampf((distance - HEADING_DEADZONE) / (HEADING_DEADZONE * 0.5), 0.0, 1.0)
	var steering_fraction := clampf(error / (PI * 0.5), -1.0, 1.0)
	var target_speed := top_speed * throttle
	var acceleration := BURST_ACCEL if burst and distance > DEADZONE else ACCEL
	if target_speed < current_speed:
		acceleration = BRAKE

	return {
		"speed": target_speed,
		"acceleration": acceleration,
		"yaw_rate": steering_fraction * turn_cap * speed_authority * cursor_authority,
		"yaw_acceleration": yaw_acceleration,
		"turn_cap": turn_cap * speed_authority,
		"burst_turn_sign": burst_turn_sign,
		"throttle": throttle,
	}
