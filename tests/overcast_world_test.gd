extends SceneTree

const OVERCAST_WORLD := preload("res://world/overcast_world.gd")


func _init() -> void:
	_check(FileAccess.file_exists(OVERCAST_WORLD.HDRI_PATH),
		"the accepted overcast HDRI is present")
	_check(OVERCAST_WORLD.HALF_EXTENT >= 80.0,
		"the new level keeps a broad open driving area")
	var world := Node3D.new()
	root.add_child(world)
	OVERCAST_WORLD.build_geometry(world, true)
	_check(world.get_node_or_null("OvercastGroundCollision") is StaticBody3D,
		"the sparse level has its own ground collision")
	_check(world.get_node_or_null("NorthSouthRoad") is MeshInstance3D \
		and world.get_node_or_null("EastWestRoad") is MeshInstance3D,
		"the open cross-street is visible")
	var buildings := world.find_children("OvercastBuilding*", "StaticBody3D", false, false)
	_check(buildings.size() == 4, "only four distant building masses dress the level")
	for building in buildings:
		var position := (building as Node3D).position
		_check(absf(position.x) >= 40.0 and absf(position.z) >= 40.0,
			"building mass stays outside the central driving plaza")
	var contact_light := OVERCAST_WORLD.build_lighting(world)
	var environment_node := world.get_node_or_null("OvercastEnvironment") as WorldEnvironment
	var environment := environment_node.environment if environment_node != null else null
	_check(environment != null and environment.background_mode == Environment.BG_SKY,
		"the level renders the HDRI as its sky")
	_check(environment != null \
		and environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY \
		and environment.reflected_light_source == Environment.REFLECTION_SOURCE_SKY,
		"the HDRI supplies ambient fill and reflections")
	_check(environment != null and environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC,
		"the accepted Filmic grade is retained")
	_check(contact_light != null and contact_light.shadow_enabled \
		and contact_light.shadow_opacity <= 0.35,
		"the car keeps only a shallow Compatibility-safe contact shadow")
	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	_check("--overcast-world" in main_source and "OVERCAST_WORLD.build_geometry" in main_source,
		"the new level is independently selectable without replacing the arena")
	_check("_build_world_menu" in main_source and "Overcast City" in main_source \
		and "NetworkTime.stop()" in main_source,
		"the system menu can safely rebuild either offline debug world")
	_check("WORLD_ARENA_MENU_ID := 3300" in main_source \
		and "TREE_STYLE_MENU_ID_BASE := 3000" in main_source,
		"world and scenery menus retain separate command ranges")
	print("OVERCAST_WORLD_TEST PASS buildings=%d" % buildings.size())
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("OVERCAST_WORLD_TEST FAIL: %s" % message)
		quit(1)
