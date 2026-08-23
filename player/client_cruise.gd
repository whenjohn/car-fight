extends RefCounted
## Pure harness-only conversion from a local Jeep heading to ordinary FOLLOW input.

const FOLLOW := preload("res://player/follow_controller.gd")

static func cursor_for(body_basis: Basis) -> Vector2:
	# Feed the Jeep's current forward heading through the same full-reach command
	# a player produces by placing the mouse at maximum non-burst throttle.
	var forward := -body_basis.z
	var planar := Vector2(forward.x, forward.z)
	if planar.length_squared() <= 0.000001:
		return Vector2.ZERO
	return planar.normalized() * FOLLOW.MAX_DISTANCE
