extends RefCounted
## Client-local orbit smoothing for the always-forward camera experiment.
## The returned heading only affects presentation; vehicle simulation remains
## authoritative and unchanged.

const DEFAULT_TUNING := {
	"turn_response": 3.2,
	"max_turn_angle": 22.0,
}

var _heading := 0.0
var _initialized := false


static func direction_heading(direction: Vector3) -> float:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() < 0.000001:
		return 0.0
	planar = planar.normalized()
	return atan2(planar.x, planar.z)


static func heading_direction(heading: float) -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


static func advance_heading(current: float, desired: float, delta: float,
		response: float, max_turn_angle_degrees: float) -> float:
	var blend := 1.0 - exp(-maxf(response, 0.01) * maxf(delta, 0.0))
	var next := lerp_angle(current, desired, blend)
	var limit := deg_to_rad(clampf(max_turn_angle_degrees, 0.0, 90.0))
	var error := wrapf(desired - next, -PI, PI)
	if absf(error) > limit:
		next = desired - signf(error) * limit
	return wrapf(next, -PI, PI)


func reset() -> void:
	_initialized = false


func advance(vehicle_forward: Vector3, delta: float, tuning: Dictionary) -> Vector3:
	var desired := direction_heading(vehicle_forward)
	if not _initialized:
		_heading = desired
		_initialized = true
	else:
		_heading = advance_heading(_heading, desired, delta,
			float(tuning.get("turn_response", DEFAULT_TUNING["turn_response"])),
			float(tuning.get("max_turn_angle", DEFAULT_TUNING["max_turn_angle"])))
	return heading_direction(_heading)
