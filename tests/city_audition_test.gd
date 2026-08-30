extends SceneTree

const MAP_LAYOUT := preload("res://world/map_layout.gd")
const CITY := preload("res://world/city_audition.gd")
const CITY_LAYOUT := preload("res://world/city_layout.gd")
const ARENA_CONFIG := preload("res://world/arena_config.gd")


func _init() -> void:
	_check(is_equal_approx(CITY_LAYOUT.SCALE, 1.5),
		"city composition remains uniformly enlarged to 150 percent")
	_check(MAP_LAYOUT.CITY_CENTER.z > ARENA_CONFIG.HALF_EXTENT
		+ MAP_LAYOUT.CITY_HALF_EXTENT + 40.0, "city has a clear physical gap from arena")
	_check(MAP_LAYOUT.CITY_CENTER.distance_to(MAP_LAYOUT.COURSE_CENTER)
		> MAP_LAYOUT.CITY_HALF_EXTENT + MAP_LAYOUT.COURSE_HALF_EXTENT + 40.0,
		"city has a clear physical gap from driving course")
	var to_city := MAP_LAYOUT.transition(MAP_LAYOUT.ARENA,
		MAP_LAYOUT.ARENA_CITY_GATE, 1.2)
	_check(int(to_city.get("map_id", -1)) == MAP_LAYOUT.CITY_AUDITION,
		"arena city pad targets city map")
	_check((to_city.get("position", Vector3.ZERO) as Vector3).is_equal_approx(
		Vector3(MAP_LAYOUT.city_start().x, 1.2, MAP_LAYOUT.city_start().z)),
		"city arrival is stable")
	var to_arena := MAP_LAYOUT.transition(MAP_LAYOUT.CITY_AUDITION,
		MAP_LAYOUT.city_gate(), 1.2)
	_check(int(to_arena.get("map_id", -1)) == MAP_LAYOUT.ARENA,
		"city return pad targets arena")
	_check(MAP_LAYOUT.gate_index_at(MAP_LAYOUT.CITY_AUDITION,
		to_city["position"]) < 0, "city arrival cannot immediately retrigger")
	_check(CITY_LAYOUT.roads().size() == 49, "city uses a connected 3x3 street grid")
	_check(CITY_LAYOUT.BUILDINGS.size() == 14, "city blocks have solid building footprints")
	var city := CITY.new()
	var local_scene_available := city.build_presentation()
	if local_scene_available:
		var district := city.get_node_or_null("LowPolyCityDistrict")
		_check(district != null and int(district.get_meta("piece_count", 0)) == 63,
			"local extracted district has full street and building composition")
		_check(int(district.get_meta("road_piece_count", 0)) == 49,
			"local extracted district includes every road tile")
	city.free()
	print("CITY_AUDITION_TEST PASS local_scene=%d" % (1 if local_scene_available else 0))
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CITY_AUDITION_TEST FAIL: %s" % message)
	quit(1)
