extends RefCounted
## Pure incoming-hit math shared by rollback gameplay and focused tests.

const DRONE_IMPULSE := 4.0
const DRONE_TORQUE_IMPULSE := 0.45
const SHIELD_PASSTHROUGH := 0.15
const RECOVERY_TIME := 0.28
const RECOVERY_ACCELERATION_SCALE := 0.25

static func response(incoming_direction: Vector3, shielded: bool) -> Dictionary:
	var direction := incoming_direction
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var scale := SHIELD_PASSTHROUGH if shielded else 1.0
	return {
		"linear_impulse": direction * DRONE_IMPULSE * scale,
		"torque_impulse": Vector3.UP.cross(direction).normalized()
			* DRONE_TORQUE_IMPULSE * scale,
		"recovery_time": RECOVERY_TIME * scale,
	}

static func acceleration_scale(recovery_time: float) -> float:
	return RECOVERY_ACCELERATION_SCALE if recovery_time > 0.0 else 1.0

## Earliest point where a segment enters a sphere, expressed as 0..1.
## Returns a value above 1 when there is no contact.
static func segment_sphere_entry(from: Vector3, to: Vector3, centre: Vector3,
		radius: float) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return 0.0 if from.distance_to(centre) <= radius else 1.01
	var offset := from - centre
	var b := 2.0 * offset.dot(segment)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - 4.0 * length_squared * c
	if discriminant < 0.0:
		return 1.01
	var root := sqrt(discriminant)
	var entry := (-b - root) / (2.0 * length_squared)
	var exit := (-b + root) / (2.0 * length_squared)
	if entry >= 0.0 and entry <= 1.0:
		return entry
	if exit >= 0.0 and exit <= 1.0:
		return 0.0
	return 1.01
