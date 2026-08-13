extends RefCounted
## Starter's mouse FOLLOW intent adapted to a ground vehicle. Cursor distance
## still controls throttle, but steering now needs forward motion and widens at speed.

const SPEED := 18.0
const ACCEL_NEAR := 14.0
const ACCEL := 27.0
const BRAKE := 32.0
const DEADZONE := 1.0
const MAX_DISTANCE := 20.0
const CURVE := 1.0
const HEADING_DEADZONE := 0.8
const STEERING_RESPONSE_CURVE := 1.2
const TURN_NEAR := 4.0
const TURN_FAR := 1.5
const TURN_CURSOR_CURVE := 1.0
const TURN_ACCEL_NEAR := 10.0
const TURN_ACCEL_FAR := 4.5
const STEERING_SPEED_REF := 3.2
const HIGH_SPEED_TURN_SCALE := 0.70
const BRAKE_SKID_MIN_SPEED := 9.0
const BRAKE_SKID_FULL_SPEED := 17.0
const BRAKE_SKID_MIN_SPEED_DROP := 4.0
const BRAKE_SKID_FULL_SPEED_DROP := 13.0
const BRAKE_SKID_VELOCITY_RESPONSE := 4.5
const DRIFT_MIN_HEADING := deg_to_rad(25.0)
const DRIFT_FULL_HEADING := deg_to_rad(75.0)
const DRIFT_VELOCITY_RESPONSE := 3.5
const DRIFT_TURN_BOOST := 1.28
const DRIFT_YAW_ACCEL := 10.5
const DRIFT_ASSIST_ZONE_INNER := deg_to_rad(90.0)
const DRIFT_ASSIST_ZONE_FULL := deg_to_rad(112.0)
const DRIFT_ASSIST_ZONE_FADE := deg_to_rad(165.0)
const DRIFT_ASSIST_ZONE_OUTER := deg_to_rad(178.0)
const DRIFT_ASSIST_BRAKE_ONSET := 0.45
const DRIFT_ASSIST_BRAKE_FULL := 0.80
const DRIFT_ASSIST_READY_MIN_SPEED := 14.0
const DRIFT_ASSIST_READY_FULL_SPEED := 17.0
const DRIFT_ASSIST_TURN_BOOST := 1.35
const DRIFT_ASSIST_YAW_ACCEL := 16.0
const DRIFT_ASSIST_VELOCITY_RESPONSE := 1.35
const DRIFT_ASSIST_PATH_TURN_RATE := 0.85
const DRIFT_ASSIST_ARM_TIME := 0.18
const DRIFT_ASSIST_SIDE_EXIT_ANGLE := deg_to_rad(72.0)
const DRIFT_ASSIST_ACCEL_EXIT_THROTTLE := 0.72
const DRIFT_ASSIST_ACCEL_EXIT_ANGLE := deg_to_rad(85.0)
const DRIFT_ASSIST_MIN_LATCH_SPEED := 8.0
const DRIFT_ASSIST_CHARGE_TIME := 0.65
const DRIFT_ASSIST_RELEASE_TIME := 0.45
const BURST_SPEED := 28.0
const BURST_ACCEL := 38.0
const BURST_TURN := 0.9
const BURST_TURN_ACCEL := 3.4
const BURST_FLIP_ON := deg_to_rad(150.0)
const BURST_FLIP_OFF := deg_to_rad(110.0)
const REVERSE_SPEED := 6.0
const REVERSE_ACCEL := 14.0
const REVERSE_TURN := 2.4
const REVERSE_TURN_ACCEL := 7.0
const ESCAPE_MIN_REQUEST_SPEED := 4.0
const ESCAPE_STALL_SPEED := 0.6
const ESCAPE_STALL_DELAY := 0.22
const ESCAPE_DURATION := 0.7
const ESCAPE_YAW_RATE := 2.2
const ESCAPE_YAW_ACCEL := 10.0
const ESCAPE_SIDE_KICK := 2.2
const ESCAPE_DEFLECTION_ANGLE := PI * 0.5
const ESCAPE_STEER_EPSILON := 0.08
const WALL_BUMP_COOLDOWN := 0.55
const WALL_BUMP_MIN_APPROACH := 0.10
const WALL_BUMP_BASE_DELTA_SPEED := 1.8
const WALL_BUMP_IMPACT_SCALE := 0.14
const WALL_BUMP_MAX_DELTA_SPEED := 3.8
const WALL_BUMP_BASE_YAW_IMPULSE := 7.0
const WALL_BUMP_YAW_IMPACT_SCALE := 0.08
const WALL_BUMP_MAX_YAW_IMPULSE := 9.0
const UPRIGHT_STIFFNESS := 32.0
const UPRIGHT_DAMPING := 7.0
const UPRIGHT_MAX_TORQUE := 70.0
const LANDING_MIN_IMPACT_SPEED := 2.5
const LANDING_TORQUE_SCALE := 0.006
const LANDING_MAX_TORQUE_IMPULSE := 0.65
const LANDING_JOSTLE_COOLDOWN := 0.35

static func command(cursor_offset: Vector2, current_yaw: float, burst: bool,
		burst_turn_sign: float, current_speed: float = 0.0, reverse: bool = false,
		grounded: bool = true, drift_assist_charge: float = 0.0,
		drift_assist_latched: bool = false, drift_assist_side: float = 0.0) -> Dictionary:
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
	var boost_active := false
	var brake_skid_amount := 0.0
	var drift_amount := 0.0
	var drift_zone_amount := 0.0
	var drift_assist_amount := 0.0
	var yaw_acceleration := lerpf(TURN_ACCEL_NEAR, TURN_ACCEL_FAR,
		pow(cursor_reach, TURN_CURSOR_CURVE))
	# Keep Starter FOLLOW's useful relationship: a close cursor asks for a
	# tighter low-speed turn, while a far cursor asks for a broad fast arc.
	var turn_cap := lerpf(TURN_NEAR, TURN_FAR, pow(cursor_reach, TURN_CURSOR_CURVE))

	if reverse:
		throttle = 1.0
		top_speed = REVERSE_SPEED
		turn_cap = REVERSE_TURN
		yaw_acceleration = REVERSE_TURN_ACCEL
		burst_turn_sign = 0.0
	elif burst and distance > DEADZONE:
		boost_active = true
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

	var target_speed := top_speed * throttle
	if grounded and not reverse and not boost_active:
		brake_skid_amount = automatic_brake_skid(current_speed, target_speed)
		drift_amount = automatic_drift(brake_skid_amount, error)
		drift_zone_amount = automatic_drift_zone(error)
		var entry_amount := automatic_drift_assist_entry(current_speed,
			brake_skid_amount, error)
		drift_assist_amount = 1.0 if drift_assist_latched else entry_amount * 0.25
		if drift_assist_latched:
			drift_amount = maxf(drift_amount, 1.0)
		# Pulling inward during a committed turn trades velocity correction for
		# rotation. The old road momentum remains real, so the slide is authored
		# entirely by mouse placement rather than a separate drift button.
		turn_cap *= lerpf(1.0, DRIFT_TURN_BOOST, drift_amount)
		yaw_acceleration = lerpf(yaw_acceleration, DRIFT_YAW_ACCEL, drift_amount)
		# The rear-corner timing zones reinforce an already committed skid. They
		# never initiate one: peak braking, ground contact, and the cursor angle
		# must all qualify before the extra rotation and forward carry appear.
		var assist_strength := drift_assist_amount * lerpf(0.55, 1.0,
			clampf(drift_assist_charge, 0.0, 1.0))
		turn_cap *= lerpf(1.0, DRIFT_ASSIST_TURN_BOOST, assist_strength)
		yaw_acceleration = lerpf(yaw_acceleration, DRIFT_ASSIST_YAW_ACCEL,
			assist_strength)

	# Ackermann-like behavior without wheel contact simulation: no forward
	# motion means no yaw. Authority ramps in over the first 4 units/s.
	var speed_authority := clampf(current_speed / STEERING_SPEED_REF, 0.0, 1.0)
	var cursor_authority := clampf((distance - HEADING_DEADZONE) / (HEADING_DEADZONE * 0.5), 0.0, 1.0)
	var linear_steering := clampf(error / (PI * 0.5), -1.0, 1.0)
	# Preserve the full turn cap while giving small heading corrections a wider,
	# calmer mouse band for accurate racing lines and combat spacing.
	var steering_fraction := signf(linear_steering) \
		* pow(absf(linear_steering), STEERING_RESPONSE_CURVE)
	var yaw_rate := steering_fraction * turn_cap * speed_authority * cursor_authority \
		* (-1.0 if reverse else 1.0)
	if drift_assist_latched and not is_zero_approx(drift_assist_side):
		yaw_rate = signf(drift_assist_side) * turn_cap * speed_authority
	# A long line means more than a higher target speed: it also asks the Jeep
	# to reach that speed harder, preserving fine control near the body.
	var acceleration := REVERSE_ACCEL if reverse else (BURST_ACCEL \
		if burst and distance > DEADZONE else lerpf(ACCEL_NEAR, ACCEL, throttle))
	if target_speed < current_speed:
		acceleration = lerpf(BRAKE, BRAKE_SKID_VELOCITY_RESPONSE, brake_skid_amount)
		acceleration = lerpf(acceleration, DRIFT_VELOCITY_RESPONSE, drift_amount)
		acceleration = lerpf(acceleration, DRIFT_ASSIST_VELOCITY_RESPONSE,
			drift_assist_amount)

	return {
		"speed": target_speed,
		"acceleration": acceleration,
		"yaw_rate": yaw_rate,
		"yaw_acceleration": yaw_acceleration,
		"turn_cap": turn_cap * speed_authority,
		"heading_error": error,
		"burst_turn_sign": burst_turn_sign,
		"throttle": throttle,
		"drive_sign": -1.0 if reverse else 1.0,
		"boost_active": boost_active,
		"brake_skid_amount": brake_skid_amount,
		"drift_amount": drift_amount,
		"drift_zone_amount": drift_zone_amount,
		"drift_assist_amount": drift_assist_amount,
	}

## Pulling the line inward at road speed locks some tire response before the
## player turns. This makes straight hard braking slide, while a heading change
## continuously turns the same skid into a powerslide.
static func automatic_brake_skid(current_speed: float, target_speed: float) -> float:
	var speed_factor := smoothstep(BRAKE_SKID_MIN_SPEED, BRAKE_SKID_FULL_SPEED,
		current_speed)
	var speed_drop := maxf(current_speed - target_speed, 0.0)
	var inward_factor := smoothstep(BRAKE_SKID_MIN_SPEED_DROP,
		BRAKE_SKID_FULL_SPEED_DROP, speed_drop)
	return speed_factor * inward_factor

static func automatic_drift(brake_skid_amount: float, heading_error: float) -> float:
	var turn_factor := smoothstep(DRIFT_MIN_HEADING, DRIFT_FULL_HEADING,
		absf(heading_error))
	return brake_skid_amount * turn_factor

## A pair of soft zones centered on the rear corners. Sideways cursor placement
## remains an ordinary powerslide and straight-back braking remains a spin-free
## stop; only the diagonal timing window receives assistance.
static func automatic_drift_zone(heading_error: float) -> float:
	var angle := absf(wrapf(heading_error, -PI, PI))
	var enter := smoothstep(DRIFT_ASSIST_ZONE_INNER, DRIFT_ASSIST_ZONE_FULL, angle)
	var leave := 1.0 - smoothstep(DRIFT_ASSIST_ZONE_FADE,
		DRIFT_ASSIST_ZONE_OUTER, angle)
	return enter * leave

static func drift_assist_ready_fraction(current_speed: float) -> float:
	return smoothstep(DRIFT_ASSIST_READY_MIN_SPEED,
		DRIFT_ASSIST_READY_FULL_SPEED, current_speed)

static func automatic_drift_assist_entry(current_speed: float,
		brake_skid_amount: float, heading_error: float) -> float:
	var brake_commit := smoothstep(DRIFT_ASSIST_BRAKE_ONSET,
		DRIFT_ASSIST_BRAKE_FULL, clampf(brake_skid_amount, 0.0, 1.0))
	return automatic_drift_zone(heading_error) * brake_commit \
		* drift_assist_ready_fraction(current_speed)

## A short deliberate hold commits the chosen side. Once latched, the changing
## vehicle-relative cursor angle no longer has to remain inside the moving
## wedge. A far forward acceleration exits; otherwise reaching a natural side
## slip hands control back to the ordinary powerslide.
static func next_drift_assist_state(current_hold: float, current_latched: bool,
		current_side: float, entry_amount: float, heading_error: float,
		throttle: float, burst: bool, reverse: bool, grounded: bool,
		current_speed: float, delta: float) -> Dictionary:
	var hold := maxf(current_hold, 0.0)
	var latched := current_latched
	var side := signf(current_side)
	var angle := absf(wrapf(heading_error, -PI, PI))
	if not grounded or reverse or current_speed < DRIFT_ASSIST_MIN_LATCH_SPEED:
		return {"hold": 0.0, "latched": false, "side": side}
	if latched:
		var accelerate_out := burst or (throttle >= DRIFT_ASSIST_ACCEL_EXIT_THROTTLE \
			and angle <= DRIFT_ASSIST_ACCEL_EXIT_ANGLE)
		var side_skid := angle <= DRIFT_ASSIST_SIDE_EXIT_ANGLE
		if accelerate_out or side_skid:
			return {"hold": 0.0, "latched": false, "side": side}
		return {"hold": DRIFT_ASSIST_ARM_TIME, "latched": true, "side": side}
	if entry_amount <= 0.35:
		return {"hold": 0.0, "latched": false, "side": side}
	var requested_side := signf(wrapf(heading_error, -PI, PI))
	if is_zero_approx(requested_side):
		return {"hold": 0.0, "latched": false, "side": side}
	if not is_zero_approx(side) and requested_side != side:
		hold = 0.0
	side = requested_side
	hold = minf(hold + delta * lerpf(0.65, 1.0,
		clampf(entry_amount, 0.0, 1.0)), DRIFT_ASSIST_ARM_TIME)
	latched = hold >= DRIFT_ASSIST_ARM_TIME
	return {"hold": hold, "latched": latched, "side": side}

## The meter turns a continuous mouse gesture into a readable timing window.
## Filling means keep committing; MAX means move the cursor forward and drive
## out. It drains quickly enough to reset between corners.
static func next_drift_assist_charge(current_charge: float, assist_amount: float,
		delta: float) -> float:
	var charge := clampf(current_charge, 0.0, 1.0)
	if assist_amount > 0.001:
		return move_toward(charge, 1.0, delta / DRIFT_ASSIST_CHARGE_TIME \
			* lerpf(0.55, 1.0, clampf(assist_amount, 0.0, 1.0)))
	return move_toward(charge, 0.0, delta / DRIFT_ASSIST_RELEASE_TIME)

## Rotate the road momentum gradually toward the selected corner without
## snapping it to the chassis. The body turns much faster than this path, so
## the Jeep visibly travels sideways while still carving around the corner.
static func drift_carve_velocity(planar_velocity: Vector3, assist_side: float,
		assist_amount: float, assist_charge: float, delta: float) -> Vector3:
	if planar_velocity.length_squared() <= 0.0001 or is_zero_approx(assist_side) \
			or assist_amount <= 0.001:
		return planar_velocity
	var strength := clampf(assist_amount, 0.0, 1.0) \
		* lerpf(0.45, 1.0, clampf(assist_charge, 0.0, 1.0))
	return planar_velocity.rotated(Vector3.UP,
		signf(assist_side) * DRIFT_ASSIST_PATH_TURN_RATE * strength * delta)

## Mouse drive only owns the ground plane. Gravity, ramps, and impacts own Y.
static func compose_drive_velocity(planar_velocity: Vector3, vertical_velocity: float) -> Vector3:
	return Vector3(planar_velocity.x, vertical_velocity, planar_velocity.z)

## Steering owns yaw only. Rapier keeps pitch and roll from ramps, suspension-like
## low-center-of-mass response, and landing contacts.
static func compose_drive_angular_velocity(physical_velocity: Vector3, yaw_rate: float) -> Vector3:
	return Vector3(physical_velocity.x, yaw_rate, physical_velocity.z)

## Project the physical body's nose onto the road plane. Unlike Euler yaw, this
## stays stable while suspension response adds pitch and roll near +/-90 yaw.
static func heading_yaw(body_basis: Basis) -> float:
	var forward := -body_basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return 0.0
	forward = forward.normalized()
	return atan2(-forward.x, -forward.z)

## A ground vehicle's suspension resists large pitch/roll while still letting
## collision impulses move the body. This returns a real torque for Rapier to
## integrate; it never writes an orientation directly.
static func upright_torque(body_basis: Basis, angular_velocity: Vector3,
		body_mass: float) -> Vector3:
	var body_up := body_basis.y.normalized()
	var upright_dot := clampf(body_up.dot(Vector3.UP), -1.0, 1.0)
	var tilt_axis := body_up.cross(Vector3.UP)
	var restoring := Vector3.ZERO
	if not tilt_axis.is_zero_approx():
		restoring = tilt_axis.normalized() * acos(upright_dot) * UPRIGHT_STIFFNESS
	var pitch_roll_velocity := Vector3(angular_velocity.x, 0.0, angular_velocity.z)
	var torque := (restoring - pitch_roll_velocity * UPRIGHT_DAMPING) \
		* maxf(body_mass, 0.001)
	return torque.limit_length(UPRIGHT_MAX_TORQUE)

## Model the brief tire/suspension scrub at touchdown as an angular impulse.
## Its axis comes from the real support normal and travel direction, while its
## strength comes from the accumulated fall speed.
static func landing_torque_impulse(velocity: Vector3, support_normal: Vector3,
		impact_speed: float, body_mass: float) -> Vector3:
	var normal := support_normal.normalized()
	if impact_speed < LANDING_MIN_IMPACT_SPEED or normal.is_zero_approx():
		return Vector3.ZERO
	var tangent_velocity := velocity - normal * velocity.dot(normal)
	var tangent_speed := tangent_velocity.length()
	if tangent_speed < 0.1:
		return Vector3.ZERO
	var axis := normal.cross(tangent_velocity / tangent_speed).normalized()
	var magnitude := impact_speed * minf(tangent_speed, SPEED) \
		* LANDING_TORQUE_SCALE * maxf(body_mass, 0.001)
	return axis * minf(magnitude, LANDING_MAX_TORQUE_IMPULSE)

## Rollback-safe stuck detector. A genuine launch clears ESCAPE_STALL_SPEED
## before the delay; a wall or another vehicle holding the body nearly still
## arms a brief side-steer escape without introducing a reverse control mode.
static func collision_escape(requested_speed: float, current_speed: float,
		heading_error: float, stall_time: float, escape_time: float,
		escape_sign: float, delta: float, fallback_sign: float) -> Dictionary:
	var started := false
	if escape_time > 0.0:
		escape_time = maxf(escape_time - delta, 0.0)
	else:
		escape_sign = 0.0
		if requested_speed >= ESCAPE_MIN_REQUEST_SPEED and current_speed <= ESCAPE_STALL_SPEED:
			stall_time += delta
		else:
			stall_time = maxf(stall_time - delta * 3.0, 0.0)
		if stall_time >= ESCAPE_STALL_DELAY:
			stall_time = 0.0
			escape_time = ESCAPE_DURATION
			escape_sign = signf(heading_error) if absf(heading_error) >= ESCAPE_STEER_EPSILON else signf(fallback_sign)
			if is_zero_approx(escape_sign):
				escape_sign = 1.0
			started = true
	return {
		"stall_time": stall_time,
		"escape_time": escape_time,
		"escape_sign": escape_sign,
		"active": escape_time > 0.0,
		"started": started,
	}

## Turn the escape drive a full quarter-turn to match its yaw direction. This
## stops forward acceleration from continuing to press a stalled car into a
## wall while the body is trying to rotate free.
static func escape_drive_direction(forward: Vector3, escape_sign: float) -> Vector3:
	var planar_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	if planar_forward.is_zero_approx() or is_zero_approx(escape_sign):
		return planar_forward
	return planar_forward.rotated(Vector3.UP,
		signf(escape_sign) * ESCAPE_DEFLECTION_ANGLE).normalized()

## Produce a one-shot collision impulse. It has no tangent component and no
## duration: Rapier preserves the existing along-wall momentum, while the yaw
## impulse turns the body naturally after the hit.
static func wall_bump(forward: Vector3, velocity: Vector3, wall_normal: Vector3,
		preferred_turn_sign: float, body_mass: float) -> Dictionary:
	var planar_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var wall_out := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	var motion := planar_velocity.normalized() if not planar_velocity.is_zero_approx() else planar_forward
	if planar_forward.is_zero_approx() or wall_out.is_zero_approx() \
			or -motion.dot(wall_out) < WALL_BUMP_MIN_APPROACH:
		return {
			"active": false,
			"linear_impulse": Vector3.ZERO,
			"yaw_impulse": 0.0,
		}

	var tangent := motion - wall_out * motion.dot(wall_out)
	var turn_sign := 0.0
	if tangent.length_squared() >= 0.04:
		turn_sign = signf(planar_forward.cross(tangent.normalized()).y)
	if is_zero_approx(turn_sign):
		turn_sign = signf(preferred_turn_sign)
	if is_zero_approx(turn_sign):
		turn_sign = 1.0
	var approach_speed := maxf(-planar_velocity.dot(wall_out), 0.0)
	var delta_speed := clampf(WALL_BUMP_BASE_DELTA_SPEED \
		+ approach_speed * WALL_BUMP_IMPACT_SCALE,
		WALL_BUMP_BASE_DELTA_SPEED, WALL_BUMP_MAX_DELTA_SPEED)
	var yaw_magnitude := clampf(WALL_BUMP_BASE_YAW_IMPULSE \
		+ approach_speed * WALL_BUMP_YAW_IMPACT_SCALE,
		WALL_BUMP_BASE_YAW_IMPULSE, WALL_BUMP_MAX_YAW_IMPULSE)
	return {
		"active": true,
		"linear_impulse": wall_out * delta_speed * maxf(body_mass, 0.001),
		"yaw_impulse": turn_sign * yaw_magnitude,
	}
