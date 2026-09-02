extends RefCounted
## Static, seeded oil-slick layout and deterministic handling response. Slicks
## are shared world data, not physics bodies or independently replicated state.

const MAP_LAYOUT := preload("res://world/map_layout.gd")

const RADIUS := 4.8
const EDGE_FEATHER := 1.15
const MAX_GROUND_BODY_Y := 2.2
const DEFAULT_INSTANT_ENTRY := true
const DEFAULT_ENGAGE_SPEED := 9.0
const DEFAULT_DURATION := 4.0
const MIN_ROAD_SPEED := 3.0
const FULL_ROAD_SPEED := 15.0
const DEFAULT_MIN_GRIP_SCALE := 0.03
const DEFAULT_MIN_DRIFT_ASSIST_SCALE := 0.0
const REAR_AXLE_OFFSET := 1.25
const DEFAULT_FRONT_STEER_TORQUE := 8.5
const DEFAULT_REAR_LATERAL_GRIP := 0.18
const DEFAULT_REAR_YAW_GRIP := 0.16
const DEFAULT_YAW_DAMPING := 0.10
const DEFAULT_MAX_YAW_RATE := 6.0

static var instant_entry := DEFAULT_INSTANT_ENTRY
static var duration := DEFAULT_DURATION
static var min_grip_scale := DEFAULT_MIN_GRIP_SCALE
static var min_drift_assist_scale := DEFAULT_MIN_DRIFT_ASSIST_SCALE
static var front_steer_torque := DEFAULT_FRONT_STEER_TORQUE
static var rear_lateral_grip := DEFAULT_REAR_LATERAL_GRIP
static var rear_yaw_grip := DEFAULT_REAR_YAW_GRIP
static var yaw_damping := DEFAULT_YAW_DAMPING
static var max_yaw_rate := DEFAULT_MAX_YAW_RATE


static func slicks() -> Array[Dictionary]:
	return [
		{"name": "OilSlickWest", "position": Vector3(-48.0, 0.0, 0.0),
			"yaw": deg_to_rad(-12.0), "stretch": Vector2(1.18, 0.88), "seed": 1.7},
		{"name": "OilSlickEast", "position": Vector3(47.0, 0.0, 23.0),
			"yaw": deg_to_rad(31.0), "stretch": Vector2(1.08, 0.94), "seed": 5.3},
		{"name": "OilSlickSouth", "position": Vector3(14.0, 0.0, 50.0),
			"yaw": deg_to_rad(67.0), "stretch": Vector2(1.24, 0.84), "seed": 9.1},
	]


## Soft edges keep the handling transition readable while the visible puddle's
## irregular edge remains presentation-only.
static func footprint_strength(map_id: int, body_position: Vector3) -> float:
	if map_id != MAP_LAYOUT.CITY or body_position.y > MAX_GROUND_BODY_Y:
		return 0.0
	var best := 0.0
	for slick in slicks():
		var center: Vector3 = slick["position"]
		var local := Vector2(body_position.x - center.x,
			body_position.z - center.z).rotated(-float(slick["yaw"]))
		var stretch: Vector2 = slick["stretch"]
		var distance := Vector2(local.x / stretch.x, local.y / stretch.y).length()
		var strength := 1.0 - smoothstep(RADIUS - EDGE_FEATHER, RADIUS, distance)
		best = maxf(best, strength)
	return best


## A short residue after leaving a puddle is what lets the rear swing past the
## corrected heading. This single per-car value is rollback synchronized.
static func next_amount(current: float, footprint: float, grounded: bool,
		road_speed: float, delta: float) -> float:
	var speed_authority := smoothstep(MIN_ROAD_SPEED, FULL_ROAD_SPEED, road_speed)
	var target := clampf(footprint, 0.0, 1.0) * speed_authority if grounded else 0.0
	var clamped_current := clampf(current, 0.0, 1.0)
	if target > clamped_current:
		return target if instant_entry else move_toward(clamped_current, target,
			DEFAULT_ENGAGE_SPEED * delta)
	return move_toward(clamped_current, target, delta / maxf(duration, 0.1))


static func grip_scale(amount: float) -> float:
	return lerpf(1.0, min_grip_scale, clampf(amount, 0.0, 1.0))


static func drift_assist_scale(amount: float) -> float:
	return lerpf(1.0, min_drift_assist_scale, clampf(amount, 0.0, 1.0))


## A compact rear-axle model for the otherwise arcade-style rigid body. Steering
## becomes torque instead of a forced yaw target while oil is active. The rear
## contact velocity combines the body's lateral motion with the velocity created
## by yaw at the rear axle; weak rear grip opposes that real slip and supplies a
## correspondingly weak stabilizing torque. World momentum therefore carries on
## while the body rotates underneath it. A turn steps the tail out, countersteer
## can swing it back, and a straight settled car receives no artificial wobble.
static func axle_response(planar_velocity: Vector3, forward: Vector3,
		requested_yaw_rate: float, current_yaw_rate: float, yaw_acceleration: float,
		road_speed: float, amount: float, delta: float) -> Dictionary:
	var planar_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	if planar_forward.is_zero_approx():
		planar_forward = Vector3.FORWARD
	var right := planar_forward.cross(Vector3.UP).normalized()
	var effect := clampf(amount, 0.0, 1.0) \
		* smoothstep(MIN_ROAD_SPEED, FULL_ROAD_SPEED, road_speed)
	var dry_yaw := move_toward(current_yaw_rate, requested_yaw_rate,
		yaw_acceleration * delta)
	var lateral_speed := planar_velocity.dot(right)
	var rear_contact_slip := lateral_speed + current_yaw_rate * REAR_AXLE_OFFSET
	var steer_acceleration := requested_yaw_rate * front_steer_torque
	var rear_acceleration := -rear_contact_slip * rear_lateral_grip
	var rear_yaw_acceleration := -rear_contact_slip * rear_yaw_grip
	var physical_yaw := current_yaw_rate + (steer_acceleration \
		+ rear_yaw_acceleration - current_yaw_rate * yaw_damping) * delta
	physical_yaw = clampf(physical_yaw, -max_yaw_rate, max_yaw_rate)
	var physical_velocity := planar_velocity + right * rear_acceleration * delta
	return {
		"planar_velocity": planar_velocity.lerp(physical_velocity, effect),
		"yaw_rate": lerpf(dry_yaw, physical_yaw, effect),
		"effect": effect,
		"lateral_speed": lateral_speed,
		"rear_contact_slip": rear_contact_slip,
		"rear_acceleration": rear_acceleration,
		"steer_acceleration": steer_acceleration,
	}


static func tuning_snapshot() -> Dictionary:
	return {
		"instant_entry": instant_entry,
		"duration": duration,
		"min_grip_scale": min_grip_scale,
		"min_drift_assist_scale": min_drift_assist_scale,
		"front_steer_torque": front_steer_torque,
		"rear_lateral_grip": rear_lateral_grip,
		"rear_yaw_grip": rear_yaw_grip,
		"yaw_damping": yaw_damping,
		"max_yaw_rate": max_yaw_rate,
	}


static func set_tuning_value(key: String, value: Variant) -> bool:
	if key == "instant_entry":
		if typeof(value) != TYPE_BOOL:
			return false
	elif typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	match key:
		"instant_entry":
			instant_entry = bool(value)
		"duration":
			duration = clampf(float(value), 0.5, 12.0)
		"min_grip_scale":
			min_grip_scale = clampf(float(value), 0.0, 0.75)
		"min_drift_assist_scale":
			min_drift_assist_scale = clampf(float(value), 0.0, 1.0)
		"front_steer_torque":
			front_steer_torque = clampf(float(value), 0.0, 24.0)
		"rear_lateral_grip":
			rear_lateral_grip = clampf(float(value), 0.0, 3.0)
		"rear_yaw_grip":
			rear_yaw_grip = clampf(float(value), 0.0, 2.0)
		"yaw_damping":
			yaw_damping = clampf(float(value), 0.0, 2.0)
		"max_yaw_rate":
			max_yaw_rate = clampf(float(value), 1.0, 12.0)
		_:
			return false
	return true


static func apply_tuning_snapshot(snapshot: Dictionary) -> void:
	for key in snapshot:
		set_tuning_value(str(key), snapshot[key])


static func reset_tuning() -> void:
	instant_entry = DEFAULT_INSTANT_ENTRY
	duration = DEFAULT_DURATION
	min_grip_scale = DEFAULT_MIN_GRIP_SCALE
	min_drift_assist_scale = DEFAULT_MIN_DRIFT_ASSIST_SCALE
	front_steer_torque = DEFAULT_FRONT_STEER_TORQUE
	rear_lateral_grip = DEFAULT_REAR_LATERAL_GRIP
	rear_yaw_grip = DEFAULT_REAR_YAW_GRIP
	yaw_damping = DEFAULT_YAW_DAMPING
	max_yaw_rate = DEFAULT_MAX_YAW_RATE
