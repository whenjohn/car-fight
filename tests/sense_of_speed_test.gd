extends SceneTree

const CAMERA := preload("res://fx/speed_camera.gd")
const SPEED_FX := preload("res://fx/vehicle_speed_fx.gd")
const MAPS := preload("res://world/map_layout.gd")
const CITY := preload("res://world/city_layout.gd")


func _init() -> void:
	_check(MAPS.CITY_HALF_EXTENT == 165.0,
		"normal play uses the accepted 150-percent Low Poly City scale")
	_check(MAPS.map_name(MAPS.CITY) == "LOW POLY CITY",
		"the city is the sole player-facing world")
	var roads := CITY.roads()
	_check(roads.size() == 49, "the city has a connected, bounded street grid")
	var trees := CITY.tree_lining_positions()
	_check(trees.size() >= 32 and trees.size() <= 64,
		"street trees provide dense but bounded proximity motion cues")
	for tree in trees:
		_check(maxf(absf(tree.x), absf(tree.z)) < MAPS.CITY_HALF_EXTENT - 10.0,
			"street trees stay clear of the city boundary walls")
	_check(CAMERA.lead_strength(0.0) == 0.0, "camera does not lead a parked car")
	_check(CAMERA.lead_strength(18.0) > 0.99, "camera reaches full lead at road speed")
	_check(CAMERA.desired_offset(Vector3(0.0, 0.0, -18.0), 0.0).z < -7.0,
		"camera target looks ahead along travel")
	_check(CAMERA.desired_offset(Vector3(0.0, 0.0, -18.0), CAMERA.BOOST_LAG_DISTANCE).z > -3.0,
		"boost onset pulls the camera target back before recovery")
	_check(CAMERA.desired_offset(Vector3(0.0, 0.0, -18.0), 0.0, 12.0).z < -11.5,
		"always-forward tuning can increase the speed-scaled look-ahead distance")
	_check(float(CAMERA.DEFAULT_TUNING["acceleration_response"]) \
		< float(CAMERA.DEFAULT_TUNING["braking_response"]),
		"look-ahead eases outward on acceleration and returns faster under braking")
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
	_check(SPEED_FX.SMOKE_VARIANT_COUNT >= 4,
		"large billows randomly select multiple smoke silhouettes")
	print("SENSE_OF_SPEED_TEST PASS roads=%d street_trees=%d" % [
		roads.size(), trees.size()])
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("SENSE_OF_SPEED_TEST FAIL: %s" % message)
		quit(1)
