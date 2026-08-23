extends RefCounted
## Pure incoming-hit math shared by rollback gameplay and focused tests.

const DRONE_IMPULSE := 6.0
const DRONE_TORQUE_IMPULSE := 5.6
const SHIELD_PASSTHROUGH := 0.15
const RECOVERY_TIME := 0.30
const RECOVERY_ACCELERATION_SCALE := 0.25
const RECOVERY_UPRIGHT_SCALE := 0.20

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
		# Absorption changes the shove, not how quickly the suspension settles.
		# Keeping the short recovery window lets even the shielded body kick read.
		"recovery_time": RECOVERY_TIME,
	}

static func acceleration_scale(recovery_time: float) -> float:
	return RECOVERY_ACCELERATION_SCALE if recovery_time > 0.0 else 1.0

static func upright_scale(recovery_time: float) -> float:
	return RECOVERY_UPRIGHT_SCALE if recovery_time > 0.0 else 1.0

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

## Earliest point where a segment enters a capsule. `axis` follows the
## capsule's full-height direction and `height` includes both rounded caps.
static func segment_capsule_entry(from: Vector3, to: Vector3, centre: Vector3,
		axis: Vector3, radius: float, height: float) -> float:
	var capsule_axis := axis.normalized()
	if capsule_axis.is_zero_approx():
		return segment_sphere_entry(from, to, centre, radius)
	var half_segment := maxf(height * 0.5 - radius, 0.0)
	var axis_from := centre - capsule_axis * half_segment
	var axis_to := centre + capsule_axis * half_segment
	var closest := _segment_closest_parameter(from, to, axis_from, axis_to)
	if _point_segment_distance_squared(from.lerp(to, closest), axis_from, axis_to) \
			> radius * radius:
		return 1.01
	if _point_segment_distance_squared(from, axis_from, axis_to) <= radius * radius:
		return 0.0
	var low := 0.0
	var high := closest
	for _iteration in 24:
		var middle := (low + high) * 0.5
		if _point_segment_distance_squared(from.lerp(to, middle), axis_from, axis_to) \
				<= radius * radius:
			high = middle
		else:
			low = middle
	return high

static func planar_capsule_distance(point: Vector3, centre: Vector3, axis: Vector3,
		radius: float, height: float) -> float:
	var planar_axis := Vector2(axis.x, axis.z).normalized()
	if planar_axis.is_zero_approx():
		return maxf(Vector2(point.x - centre.x, point.z - centre.z).length() - radius, 0.0)
	var half_segment := maxf(height * 0.5 - radius, 0.0)
	var planar_centre := Vector2(centre.x, centre.z)
	var offset := Vector2(point.x, point.z) - planar_centre
	var along := clampf(offset.dot(planar_axis), -half_segment, half_segment)
	return maxf((offset - planar_axis * along).length() - radius, 0.0)

static func _point_segment_distance_squared(point: Vector3, from: Vector3,
		to: Vector3) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_squared_to(from)
	var fraction := clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(from + segment * fraction)

static func _segment_closest_parameter(from_a: Vector3, to_a: Vector3,
		from_b: Vector3, to_b: Vector3) -> float:
	var direction_a := to_a - from_a
	var direction_b := to_b - from_b
	var offset := from_a - from_b
	var a := direction_a.dot(direction_a)
	var e := direction_b.dot(direction_b)
	if a <= 0.000001:
		return 0.0
	var c := direction_a.dot(offset)
	if e <= 0.000001:
		return clampf(-c / a, 0.0, 1.0)
	var b := direction_a.dot(direction_b)
	var f := direction_b.dot(offset)
	var denominator := a * e - b * b
	var along_a := clampf((b * f - c * e) / denominator, 0.0, 1.0) \
		if absf(denominator) > 0.000001 else 0.0
	var along_b := (b * along_a + f) / e
	if along_b < 0.0:
		return clampf(-c / a, 0.0, 1.0)
	if along_b > 1.0:
		return clampf((b - c) / a, 0.0, 1.0)
	return along_a
