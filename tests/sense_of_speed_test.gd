extends SceneTree

const CAMERA := preload("res://fx/speed_camera.gd")
const SPEED_FX := preload("res://fx/vehicle_speed_fx.gd")
const ARENA := preload("res://world/arena_config.gd")
const MAPS := preload("res://world/map_layout.gd")
const LAYOUT := preload("res://world/arena_layout.gd")


func _init() -> void:
	_check(ARENA.HALF_EXTENT == 240.0, "normal play uses the proven large arena scale")
	_check(MAPS.COURSE_CENTER.x > ARENA.HALF_EXTENT + MAPS.COURSE_HALF_EXTENT + 40.0,
		"the larger arena remains physically separate from the driving course")
	var landmarks := LAYOUT.proximity_objects(ARENA.HALF_EXTENT)
	_check(landmarks.size() >= 64 and landmarks.size() <= 96,
		"proximity scenery has a useful, bounded object count")
	for landmark in landmarks:
		var position: Vector3 = landmark["position"]
		_check(maxf(absf(position.x), absf(position.z)) < ARENA.HALF_EXTENT - 10.0,
			"proximity scenery stays clear of boundary walls")
	_check(CAMERA.lead_strength(0.0) == 0.0, "camera does not lead a parked car")
	_check(CAMERA.lead_strength(18.0) > 0.99, "camera reaches full lead at road speed")
	_check(CAMERA.desired_offset(Vector3(0.0, 0.0, -18.0), 0.0).z < -7.0,
		"camera target looks ahead along travel")
	_check(CAMERA.desired_offset(Vector3(0.0, 0.0, -18.0), CAMERA.BOOST_LAG_DISTANCE).z > -3.0,
		"boost onset pulls the camera target back before recovery")
	_check(CAMERA.vibration_strength(15.0) == 0.0,
		"ordinary driving remains free of top-speed vibration")
	_check(CAMERA.vibration_strength(28.0) > 0.99,
		"burst speed reaches full chassis vibration")
	_check(SPEED_FX.dust_strength(7.0, true) == 0.0,
		"slow driving does not spray dust")
	_check(SPEED_FX.dust_strength(20.0, true) > 0.99,
		"high speed sprays full dust")
	_check(SPEED_FX.smoke_strength(14.0, 1.0, 0.0, true) > 0.5,
		"a fast skid emits tire smoke")
	_check(SPEED_FX.smoke_strength(14.0, 1.0, 0.0, false) == 0.0,
		"airborne tires do not emit smoke")
	print("SENSE_OF_SPEED_TEST PASS landmarks=%d" % landmarks.size())
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("SENSE_OF_SPEED_TEST FAIL: %s" % message)
		quit(1)
