extends SceneTree

func _init() -> void:
	var source := FileAccess.get_file_as_string("res://Main.gd")
	var project := FileAccess.get_file_as_string("res://project.godot")
	_check("var _lighting_style_index := 4" in source,
		"Forward+ sunlit lighting is the built-in default")
	_check("Sunlit aerial (Forward+ 4.6)" in source,
		"the accepted Forward+ preset remains selectable")
	_check("Overcast city HDRI" in source,
		"the overcast HDRI remains an alternate city lighting preset")
	_check("--overcast-world" not in source and "_build_world_menu" not in source,
		"obsolete standalone world switching is removed")
	_check("_build_home_world()" in source and "_build_arena()" not in source,
		"Low Poly City owns the default world build")
	_check('renderer/rendering_method="forward_plus"' in project \
		and 'renderer/rendering_method.mobile="forward_plus"' in project,
		"desktop and mobile use the accepted Forward+ renderer")
	_check('config/use_custom_user_dir=true' in project \
		and 'config/custom_user_dir_name="Car Fight/godot-4.6"' in project,
		"Godot 4.6 does not share its Vulkan pipeline cache with other engines")
	_check("_world_environment.ssao_enabled = true" in source \
		and "environment/ssao/quality=0" in project,
		"the default Forward+ preset enables the accepted low SSAO pass")
	_check("_world_environment.ssil_enabled = false" in source \
		and "_world_environment.ssr_enabled = false" in source \
		and "_world_environment.sdfgi_enabled = false" in source,
		"unaccepted expensive screen-space and GI effects remain disabled")
	_check("_sun_light.shadow_enabled = true" in source \
		and "DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS" in source \
		and "lights_and_shadows/directional_shadow/size=2048" in project,
		"the default sun uses the accepted cascaded shadow configuration")
	_check("func _complete_staged_lighting()" in source \
		and source.count("await RenderingServer.frame_post_draw") >= 4 \
		and "_world_environment.ssao_enabled = not stage_expensive" in source \
		and "_sun_light.shadow_enabled = not stage_expensive" in source,
		"the costly default lighting passes are split across startup frames")
	print("HOME_WORLD_LIGHTING_TEST PASS default=forward_plus_sunlit presets=5")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("HOME_WORLD_LIGHTING_TEST FAIL: %s" % message)
		quit(1)
