extends SceneTree

const LIBRARY := preload("res://world/prop_audition_library.gd")


func _init() -> void:
	_check(LIBRARY.STONES_PATH.begins_with("res://assets/local/"),
		"stone audition source stays optional and local")
	_check(LIBRARY.HOUSE_PATH.begins_with("res://assets/local/"),
		"house audition source stays optional and local")
	var library = LIBRARY.new()
	var audition := library.build_audition() as Node3D
	if not LIBRARY.source_available():
		_check(audition == null, "a clean checkout skips optional props")
		print("PROP_AUDITION_LIBRARY_TEST PASS source=absent")
		quit(0)
		return
	_check(audition != null, "available local props build an audition root")
	if audition == null:
		quit(1)
		return
	var house := audition.get_node_or_null("RuinHouseAudition") as Node3D
	if ResourceLoader.exists(LIBRARY.HOUSE_PATH):
		_check(house != null, "the ruined house builds")
		if house != null:
			var dimensions: Vector3 = house.get_meta("audition_dimensions", Vector3.ZERO)
			_check(dimensions.y >= 8.0 and dimensions.y <= 12.0,
				"house height remains believable beside the vehicles")
			var house_mesh := house.get_child(0) as MeshInstance3D
			_check(house_mesh != null and house_mesh.cast_shadow ==
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"the heavy house stays out of the shadow pass")
	var stones := audition.get_node_or_null("StoneAuditions") as Node3D
	if ResourceLoader.exists(LIBRARY.STONES_PATH):
		_check(stones != null and int(stones.get_meta("stone_count", 0)) == 6,
			"all six stones build")
		_check(float(stones.get_meta("maximum_stone_height", 0.0)) <= 3.0,
			"stones remain vehicle-scale")
	audition.free()
	print("PROP_AUDITION_LIBRARY_TEST PASS source=local")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("PROP_AUDITION_LIBRARY_TEST FAIL: %s" % message)
		quit(1)
