extends RefCounted
## Client-local orbit smoothing for the always-forward camera experiment.
## The returned heading only affects presentation; vehicle simulation remains
## authoritative and unchanged.

const DEFAULT_TUNING := {
	"turn_response": 3.2,
	"turn_dead_zone": 10.0,
	"max_turn_speed": 95.0,
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
		response: float, turn_dead_zone_degrees: float, max_turn_speed_degrees: float,
		vehicle_turn_speed: float = 0.0) -> float:
	var safe_delta := maxf(delta, 0.0)
	var error := wrapf(desired - current, -PI, PI)
	# While the vehicle is actively yawing, let it move within a soft screen-space
	# zone before rotating the whole world. The zone fades away when steering
	# settles so the nose still returns precisely to screen-up.
	var turning_strength := clampf(absf(vehicle_turn_speed) / 1.0, 0.0, 1.0)
	var dead_zone := deg_to_rad(clampf(turn_dead_zone_degrees, 0.0, 45.0)) \
		* turning_strength
	var assisted_error := signf(error) * maxf(absf(error) - dead_zone, 0.0)
	var spring_step := assisted_error * (1.0 - exp(-maxf(response, 0.01) * safe_delta))
	var max_step := deg_to_rad(clampf(max_turn_speed_degrees, 1.0, 360.0)) * safe_delta
	return wrapf(current + clampf(spring_step, -max_step, max_step), -PI, PI)


func reset() -> void:
	_initialized = false


func advance(vehicle_forward: Vector3, vehicle_turn_speed: float, delta: float,
		tuning: Dictionary) -> Vector3:
	var desired := direction_heading(vehicle_forward)
	if not _initialized:
		_heading = desired
		_initialized = true
	else:
		_heading = advance_heading(_heading, desired, delta,
			float(tuning.get("turn_response", DEFAULT_TUNING["turn_response"])),
			float(tuning.get("turn_dead_zone", DEFAULT_TUNING["turn_dead_zone"])),
			float(tuning.get("max_turn_speed", DEFAULT_TUNING["max_turn_speed"])),
			vehicle_turn_speed)
	return heading_direction(_heading)
