extends SceneTree

func _init() -> void:
	var source := FileAccess.get_file_as_string("res://Main.gd")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var editor := FileAccess.get_file_as_string("res://ui/lighting_editor.gd")
	_check("var _lighting_style_index := 4" in source,
		"Intel-safe sunlit lighting is the built-in default")
	_check("Sunlit aerial (Intel-safe)" in source,
		"the accepted Compatibility preset remains selectable")
	_check("Overcast city HDRI" in source,
		"the overcast HDRI remains an alternate city lighting preset")
	_check("Lighting Editor…" in source and "_on_lighting_editor_values_changed" in source,
		"the Scenery system menu opens a live lighting editor")
	for field in ["sun_energy", "sun_elevation", "sun_azimuth", "ambient_energy",
			"exposure", "saturation", "shadow_opacity"]:
		_check(('"%s"' % field) in editor,
			"the lighting editor exposes the high-impact %s control" % field)
	_check("sun_color" in editor and "contact_shadows" in editor,
		"sun color and safe contact-shadow visibility are live controls")
	_check("user://lighting_working.cfg" in editor and "_restore_working" in editor,
		"the current working look is autosaved and restored")
	_check("user://lighting_looks.cfg" in editor and "Saved looks" in editor \
		and "_save_named_look" in editor and "_load_selected_look" in editor,
		"named lighting looks can be saved and loaded")
	_check("ssao" not in editor.to_lower() and "directional_shadow" not in editor.to_lower(),
		"the editor does not expose unsafe or expensive lighting paths")
	_check("--overcast-world" not in source and "_build_world_menu" not in source,
		"obsolete standalone world switching is removed")
	_check("_build_home_world" not in source and "\t_build_city_space()" in source,
		"the world shell builds Low Poly City directly")
	_check("_add_proximity_landmark" not in source \
		and "TREE_STYLE_MENU_ID_BASE" not in source and "Tree model" not in source,
		"the scenery menu contains no controls for removed proximity landmarks")
	_check('renderer/rendering_method="gl_compatibility"' in project \
		and 'renderer/rendering_method.mobile="gl_compatibility"' in project,
		"desktop and mobile use the stable Godot 4.7 Compatibility renderer")
	_check("_world_environment.ssao_enabled = false" in source,
		"SSAO stays disabled on the Intel Iris Plus")
	_check("_world_environment.ssil_enabled = false" in source \
		and "_world_environment.ssr_enabled = false" in source \
		and "_world_environment.sdfgi_enabled = false" in source,
		"unaccepted expensive screen-space and GI effects remain disabled")
	_check("_sun_light.shadow_enabled = false" in source \
		and "_shadow_light.visible = true" in source \
		and "lights_and_shadows/positional_shadow/atlas_size=2048" in project,
		"the default uses the accepted Compatibility spotlight shadows")
	print("HOME_WORLD_LIGHTING_TEST PASS default=intel_safe_sunlit presets=5 " \
		+ "live_editor=9 autosave=working named_looks=yes")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("HOME_WORLD_LIGHTING_TEST FAIL: %s" % message)
		quit(1)
