extends SceneTree

const LIBRARY := preload("res://world/tree_visual_library.gd")


func _init() -> void:
	_check(LIBRARY.STYLE_NAMES.size() == LIBRARY.STYLE_STARTS.size(),
		"tree style names and source ranges stay aligned")
	_check(LIBRARY.STYLE_NAMES[0] == "Procedural baseline",
		"a clean checkout retains the procedural fallback")
	_check(LIBRARY.SOURCE_PATH.begins_with("res://assets/local/"),
		"licensed marketplace source stays in the ignored local asset area")
	var library = LIBRARY.new()
	if not LIBRARY.source_available():
		_check(library.build_visual(1, 0, 12.0) == null,
			"missing local art falls back without an invalid visual")
		print("TREE_VISUAL_LIBRARY_TEST PASS source=absent fallback=procedural")
		quit(0)
		return
	_check(library.load_source(), "the authorized local FBX loads")
	for style_index in range(1, LIBRARY.STYLE_NAMES.size()):
		var visual := library.build_visual(style_index, 3, 12.0) as Node3D
		_check(visual != null and visual.get_child_count() == 1,
			"every configured collection range builds one bounded visual")
		if visual == null or visual.get_child_count() != 1:
			continue
		var mesh := visual.get_child(0) as MeshInstance3D
		_check(mesh != null and mesh.mesh != null,
			"the collection visual retains its imported mesh")
		_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"tree audition meshes stay out of the real-time shadow pass")
		_check(visual.scale.x > 0.0 and is_finite(visual.scale.x),
			"source trees normalize to the existing landmark height")
		visual.free()
	print("TREE_VISUAL_LIBRARY_TEST PASS source=local styles=%d" %
		(LIBRARY.STYLE_NAMES.size() - 1))
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TREE_VISUAL_LIBRARY_TEST FAIL: %s" % message)
		quit(1)
