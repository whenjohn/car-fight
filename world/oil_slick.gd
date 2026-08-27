extends RefCounted
## Static, seeded oil-slick layout and deterministic handling response. Slicks
## are shared world data, not physics bodies or independently replicated state.

const MAP_LAYOUT := preload("res://world/map_layout.gd")

const RADIUS := 4.8
const EDGE_FEATHER := 1.15
const MAX_GROUND_BODY_Y := 2.2
const ENGAGE_SPEED := 9.0
const RELEASE_SPEED := 0.62
const MIN_ROAD_SPEED := 3.0
const FULL_ROAD_SPEED := 15.0
const MIN_TURN_ANGLE := deg_to_rad(8.0)
const FULL_TURN_ANGLE := deg_to_rad(62.0)
const MIN_GRIP_SCALE := 0.16
const MIN_DRIFT_ASSIST_SCALE := 0.28
const TURN_MULTIPLIER := 3.4
const YAW_MOMENTUM := 0.68
const YAW_ACCELERATION_SCALE := 1.30
const FISHTAIL_YAW_RATE := 2.10
const FISHTAIL_FREQUENCY_MIN := 7.5
const FISHTAIL_FREQUENCY_MAX := 11.0
const MAX_YAW_RATE := 5.2


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
	if map_id != MAP_LAYOUT.ARENA or body_position.y > MAX_GROUND_BODY_Y:
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
	var rate := ENGAGE_SPEED if target > current else RELEASE_SPEED
	return move_toward(clampf(current, 0.0, 1.0), target, rate * delta)


static func grip_scale(amount: float) -> float:
	return lerpf(1.0, MIN_GRIP_SCALE, clampf(amount, 0.0, 1.0))


static func drift_assist_scale(amount: float) -> float:
	return lerpf(1.0, MIN_DRIFT_ASSIST_SCALE, clampf(amount, 0.0, 1.0))


## The phase is explicit rollback state instead of wall-clock animation. A fast
## crossing gets roughly one full rear swing while the residue supplies the
## correction swing after the car leaves the visible puddle.
static func next_fishtail_phase(current: float, amount: float, road_speed: float,
		delta: float) -> float:
	if amount <= 0.001:
		return 0.0
	var speed_authority := smoothstep(MIN_ROAD_SPEED, FULL_ROAD_SPEED, road_speed)
	var frequency := lerpf(FISHTAIL_FREQUENCY_MIN, FISHTAIL_FREQUENCY_MAX,
		speed_authority)
	return fposmod(current + frequency * delta, TAU)


## Oil increases requested rotation on a real turn, then feeds some current yaw
## back into the target. Correcting the wheel therefore has to overcome the old
## rear swing. The rollback phase adds an unmistakable alternating rear step-out
## even on a straight crossing; a hard fast turn can spin.
static func steering_response(requested_yaw_rate: float, current_yaw_rate: float,
		yaw_acceleration: float, heading_error: float, road_speed: float,
		amount: float, fishtail_phase: float = 0.0) -> Dictionary:
	var effect := clampf(amount, 0.0, 1.0) \
		* smoothstep(MIN_ROAD_SPEED, FULL_ROAD_SPEED, road_speed)
	var turn_demand := smoothstep(MIN_TURN_ANGLE, FULL_TURN_ANGLE,
		absf(wrapf(heading_error, -PI, PI)))
	var turn_scale := lerpf(1.0, TURN_MULTIPLIER, effect * turn_demand)
	var target := requested_yaw_rate * turn_scale
	target += current_yaw_rate * YAW_MOMENTUM * effect
	var fishtail := sin(fishtail_phase) * FISHTAIL_YAW_RATE * effect
	target += fishtail
	target = clampf(target, -MAX_YAW_RATE, MAX_YAW_RATE)
	return {
		"yaw_rate": target,
		"yaw_acceleration": yaw_acceleration \
			* lerpf(1.0, YAW_ACCELERATION_SCALE, effect),
		"effect": effect,
		"turn_demand": turn_demand,
		"fishtail": fishtail,
	}
