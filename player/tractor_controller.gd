extends RefCounted
## Pure area-vacuum geometry and servo math shared by gameplay and tests.

const VACUUM_RADIUS := 12.0
const REEL_SPEED := 4.2
const STIFFNESS := 0.58
const ANCHOR := 0.60
const MIN_GAP := 0.18

static func can_pull(origin: Vector3, target: Vector3, target_radius: float) -> bool:
	var flat_origin := Vector3(origin.x, 0.0, origin.z)
	var flat_target := Vector3(target.x, 0.0, target.z)
	return flat_origin.distance_to(flat_target) <= VACUUM_RADIUS + target_radius

## Momentum-conserving impulse pair. The ball receives target_impulse; the car
## receives a reduced reaction impulse so heavy cargo would pull the car too.
static func reel(origin: Vector3, origin_velocity: Vector3, origin_mass: float,
		target: Vector3, target_velocity: Vector3, target_mass: float,
		origin_radius: float, target_radius: float, delta: float) -> Dictionary:
	var separation := target - origin
	separation.y = 0.0
	var distance := separation.length()
	if distance <= 0.01:
		return {"target_impulse": Vector3.ZERO, "origin_impulse": Vector3.ZERO,
			"distance": distance}
	var direction := separation / distance
	var relative_separation_rate := (target_velocity - origin_velocity).dot(direction)
	var minimum_length := origin_radius + target_radius + MIN_GAP
	var closing_speed := minf(maxf(distance - minimum_length, 0.0) \
		/ maxf(delta, 0.0001), REEL_SPEED)
	var relative_delta_velocity := -closing_speed - relative_separation_rate
	var reduced_mass := origin_mass * target_mass / maxf(origin_mass + target_mass, 0.0001)
	var impulse := direction * relative_delta_velocity * reduced_mass * STIFFNESS
	return {
		"target_impulse": impulse,
		"origin_impulse": -impulse * (1.0 - ANCHOR),
		"distance": distance,
	}
