extends SceneTree

const CAMERA := preload("res://fx/always_forward_camera.gd")


func _init() -> void:
	var north := CAMERA.direction_heading(Vector3(0.0, 0.0, -1.0))
	var east := CAMERA.direction_heading(Vector3(1.0, 0.0, 0.0))
	_check(CAMERA.heading_direction(north).distance_to(Vector3(0.0, 0.0, -1.0)) < 0.0001,
		"heading conversion preserves the vehicle nose direction")
	var limited := CAMERA.advance_heading(north, east, 1.0 / 60.0, 0.5, 22.0)
	var remaining := absf(wrapf(east - limited, -PI, PI))
	_check(remaining <= deg_to_rad(22.0) + 0.0001,
		"camera lag never lets the vehicle exceed its visible turn angle")
	_check(remaining > 0.1, "camera catch-up leaves a readable temporary turn angle")
	var settled := limited
	for frame in range(300):
		settled = CAMERA.advance_heading(settled, east, 1.0 / 60.0, 3.2, 22.0)
	_check(absf(wrapf(east - settled, -PI, PI)) < 0.001,
		"camera eases back to nose-up after a turn")
	print("ALWAYS_FORWARD_CAMERA_TEST PASS max_angle=22 settled=yes")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("ALWAYS_FORWARD_CAMERA_TEST FAIL: %s" % message)
		quit(1)
