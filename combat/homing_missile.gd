extends RefCounted
## Pure slot-1 missile guidance, ported from G2's isometric homing weapon.

const SPEED := 24.0
const TURN_DEGREES_PER_SECOND := 180.0
const STEERING_RANGE := 4.5
const CONE_DEGREES := 80.0
const COMMIT_DISTANCE := 6.5
const LIFETIME := 2.5

static func steer(velocity: Vector3, position: Vector3, target_position: Vector3,
		delta: float) -> Vector3:
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if heading.length_squared() <= 0.000001:
		heading = Vector3.RIGHT
	else:
		heading = heading.normalized()
	var to_target := target_position - position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > COMMIT_DISTANCE and distance > 0.001:
		var bearing := heading.signed_angle_to(to_target / distance, Vector3.UP)
		if absf(bearing) <= deg_to_rad(CONE_DEGREES):
			var authority := clampf(STEERING_RANGE / distance, 0.0, 1.0)
			var max_turn := deg_to_rad(TURN_DEGREES_PER_SECOND) * delta * authority
			heading = heading.rotated(Vector3.UP, clampf(bearing, -max_turn, max_turn)).normalized()
	return heading * SPEED
