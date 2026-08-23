extends RefCounted

## Render-only local reconciliation. Physics, rollback, and client input remain
## on the raw body; only the detached hull and camera consume this pose.

const INTERPOLATION := preload("res://net/remote_snapshot_interpolation.gd")
const SNAP_DISTANCE := 2.0
const POSITION_HALF_LIFE := 0.050
const ROTATION_HALF_LIFE := 0.060


static func advance(current: Transform3D, target: Transform3D,
		linear_velocity: Vector3, angular_velocity: Vector3, delta: float) -> Dictionary:
	if delta <= 0.0:
		return {"pose": current, "snapped": false}
	if current.origin.distance_to(target.origin) > SNAP_DISTANCE:
		return {"pose": target, "snapped": true}
	var predicted := INTERPOLATION.predict_pose(current.origin,
		current.basis.get_rotation_quaternion(), linear_velocity, angular_velocity, delta)
	return {
		"pose": INTERPOLATION.smooth_pose(predicted, target, delta,
			POSITION_HALF_LIFE, ROTATION_HALF_LIFE),
		"snapped": false,
	}
