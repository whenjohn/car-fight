extends SceneTree

const CAMERA := preload("res://fx/always_forward_camera.gd")


func _init() -> void:
	var north := CAMERA.direction_heading(Vector3(0.0, 0.0, -1.0))
	var east := CAMERA.direction_heading(Vector3(1.0, 0.0, 0.0))
	_check(CAMERA.heading_direction(north).distance_to(Vector3(0.0, 0.0, -1.0)) < 0.0001,
		"heading conversion preserves the vehicle nose direction")
	var assisted := CAMERA.advance_heading(north, east, 1.0 / 60.0,
		3.2, 10.0, 95.0, 2.0)
	var first_step := absf(wrapf(assisted - north, -PI, PI))
	_check(first_step <= deg_to_rad(95.0) / 60.0 + 0.0001,
		"camera world rotation is capped during a sharp turn")
	_check(first_step < deg_to_rad(5.0),
		"camera does not chase a sudden vehicle turn one-to-one")
	var settled := assisted
	for frame in range(300):
		settled = CAMERA.advance_heading(settled, east, 1.0 / 60.0,
			3.2, 10.0, 95.0, 0.0)
	_check(absf(wrapf(east - settled, -PI, PI)) < 0.001,
		"camera eases back to nose-up after a turn")
	print("ALWAYS_FORWARD_CAMERA_TEST PASS capped_turn=yes comfort_zone=10 settled=yes")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("ALWAYS_FORWARD_CAMERA_TEST FAIL: %s" % message)
		quit(1)
