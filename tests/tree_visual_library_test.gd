extends SceneTree

const LIBRARY := preload("res://world/tree_visual_library.gd")


func _init() -> void:
	_check(LIBRARY.COLLECTION_SOURCE_PATH.begins_with("res://assets/local/"),
		"marketplace source stays in the ignored local asset area")
	_check(LIBRARY.FIRST_ASSET_INDEX == 121 and LIBRARY.VARIANT_COUNT == 10,
		"the library exposes only the accepted Collection 121-130 family")
	var library = LIBRARY.new()
	if not LIBRARY.source_available():
		_check(library.build_visual(0, 12.0) == null,
			"missing local art falls back without an invalid visual")
		print("TREE_VISUAL_LIBRARY_TEST PASS source=absent fallback=procedural")
		quit(0)
		return
	for tree_index in range(LIBRARY.VARIANT_COUNT):
		var visual := library.build_visual(tree_index, 12.0) as Node3D
		_check(visual != null and visual.get_child_count() == 1,
			"every accepted collection tree builds one bounded visual")
		if visual == null or visual.get_child_count() != 1:
			continue
		var mesh := visual.get_child(0) as MeshInstance3D
		_check(mesh != null and mesh.mesh != null,
			"the audition visual retains its imported mesh")
		_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"tree audition meshes stay out of the real-time shadow pass")
		_check(visual.scale.x > 0.0 and is_finite(visual.scale.x),
			"source trees normalize to the accepted city height")
		visual.free()
	print("TREE_VISUAL_LIBRARY_TEST PASS source=local variants=%d" % LIBRARY.VARIANT_COUNT)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TREE_VISUAL_LIBRARY_TEST FAIL: %s" % message)
		quit(1)
