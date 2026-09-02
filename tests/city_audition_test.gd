extends SceneTree

const MAP_LAYOUT := preload("res://world/map_layout.gd")
const CITY := preload("res://world/city_audition.gd")
const CITY_LAYOUT := preload("res://world/city_layout.gd")
const TREE_VISUAL_LIBRARY := preload("res://world/tree_visual_library.gd")


func _init() -> void:
	_check(is_equal_approx(CITY_LAYOUT.SCALE, 1.5),
		"city composition remains uniformly enlarged to 150 percent")
	_check(MAP_LAYOUT.CITY == 0 and MAP_LAYOUT.CITY_CENTER == Vector3.ZERO,
		"city is the canonical home map at the world origin")
	_check(MAP_LAYOUT.CITY_HALF_EXTENT == 165.0,
		"city owns the accepted 150-percent world boundary")
	_check(MAP_LAYOUT.map_name(MAP_LAYOUT.CITY) == "LOW POLY CITY",
		"city owns the player-facing home-world name")
	_check(CITY_LAYOUT.roads().size() == 49, "city uses a connected 3x3 street grid")
	_check(CITY_LAYOUT.BUILDINGS.size() == 14, "city blocks have solid building footprints")
	var tree_positions := CITY_LAYOUT.tree_lining_positions()
	_check(tree_positions.size() >= 32,
		"city has a substantial deterministic street-tree lining")
	var city := CITY.new()
	var local_scene_available := city.build_presentation()
	if local_scene_available:
		var district := city.get_node_or_null("LowPolyCityDistrict")
		_check(district != null and int(district.get_meta("piece_count", 0)) == 63,
			"local extracted district has full street and building composition")
		_check(int(district.get_meta("road_piece_count", 0)) == 49,
			"local extracted district includes every road tile")
		if ResourceLoader.exists(TREE_VISUAL_LIBRARY.COLLECTION_SOURCE_PATH):
			var lining := city.get_node_or_null("Collection121TreeLining")
			_check(lining != null and int(lining.get_meta("tree_count", 0))
				== tree_positions.size(), "every clear tree site uses Collection 121-130")
	city.free()
	print("CITY_AUDITION_TEST PASS local_scene=%d" % (1 if local_scene_available else 0))
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("CITY_AUDITION_TEST FAIL: %s" % message)
	quit(1)
