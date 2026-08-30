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
	_check(landmarks.size() >= 130 and landmarks.size() <= 155,
		"proximity scenery has a useful, bounded object count")
	var tree_path := LAYOUT.tree_path_objects(ARENA.HALF_EXTENT)
	_check(tree_path.size() >= 70 and tree_path.size() <= 80,
		"the dedicated tree path is visibly dense but bounded")
	for tree in tree_path:
		_check(str(tree["kind"]) == "tree" and float(tree["height_scale"]) >= 1.5,
			"tree-path landmarks are consistently tall trees")
		_check(absf(float((tree["position"] as Vector3).x) - 100.0) == 12.0,
			"tree rows frame a 24-unit driving lane")
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
	var smoke_texture := load(SPEED_FX.SMOKE_TEXTURE_PATH) as Texture2D
	_check(smoke_texture != null and smoke_texture.get_width() == 512,
		"tire smoke reuses the detailed G2 isometric smoke card")
	_check(SPEED_FX.maximum_haze_card_size() >= 15.0,
		"outer billows grow several times wider than a vehicle")
	_check(SPEED_FX.SMOKE_HAZE_LIFETIME >= 7.0,
		"large smoke cards linger in world space for several seconds")
	_check(SPEED_FX.SMOKE_CORE_COUNT >= 48 and SPEED_FX.SMOKE_HAZE_COUNT >= 36,
		"sustained skids build a full overlapping cloud")
	print("SENSE_OF_SPEED_TEST PASS landmarks=%d tree_path=%d" % [
		landmarks.size(), tree_path.size()])
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("SENSE_OF_SPEED_TEST FAIL: %s" % message)
		quit(1)
