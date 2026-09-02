extends SceneTree

func _init() -> void:
	var source := FileAccess.get_file_as_string("res://Main.gd")
	var project := FileAccess.get_file_as_string("res://project.godot")
	_check("var _lighting_style_index := 4" in source,
		"Intel-safe sunlit lighting is the built-in default")
	_check("Sunlit aerial (Intel-safe)" in source,
		"the accepted Compatibility preset remains selectable")
	_check("Overcast city HDRI" in source,
		"the overcast HDRI remains an alternate city lighting preset")
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
	print("HOME_WORLD_LIGHTING_TEST PASS default=intel_safe_sunlit presets=5")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("HOME_WORLD_LIGHTING_TEST FAIL: %s" % message)
		quit(1)
