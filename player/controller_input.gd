extends RefCounted
## Presentation-local joypad helpers. The resulting intent enters the existing
## PlayerInput rollback timeline; no controller state is sent separately.

const STICK_DEADZONE := 0.22


static func shaped_stick(raw_stick: Vector2) -> Vector2:
	var length := raw_stick.length()
	if length <= STICK_DEADZONE:
		return Vector2.ZERO
	var strength := inverse_lerp(STICK_DEADZONE, 1.0, minf(length, 1.0))
	return raw_stick.normalized() * strength


static func cursor_offset(raw_stick: Vector2, camera_right: Vector3,
		camera_up: Vector3, max_distance: float) -> Vector2:
	var stick := shaped_stick(raw_stick)
	if stick.is_zero_approx():
		return Vector2.ZERO
	var right := Vector2(camera_right.x, camera_right.z).normalized()
	var screen_up := Vector2(camera_up.x, camera_up.z).normalized()
	if right.is_zero_approx() or screen_up.is_zero_approx():
		return Vector2.ZERO
	# Joypad Y grows downward. Camera +Y points toward the top of the screen.
	var world_direction := right * stick.x - screen_up * stick.y
	if world_direction.is_zero_approx():
		return Vector2.ZERO
	return world_direction.normalized() * stick.length() * maxf(max_distance, 0.0)
