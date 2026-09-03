extends SceneTree


func _init() -> void:
	var main := FileAccess.get_file_as_string("res://Main.gd")
	var editor := FileAccess.get_file_as_string("res://ui/always_forward_camera_editor.gd")
	var input := FileAccess.get_file_as_string("res://player/player_input.gd")
	_check("Always-forward camera" in main and "Camera tuning…" in main,
		"the Debug system menu exposes the experiment toggle and tuner")
	_check("_always_forward_camera_enabled := false" in main,
		"the rejected nose-up behavior now starts disabled but remains available for comparison")
	_check('ALWAYS_FORWARD_CAMERA_SECTION, "enabled"' not in main,
		"the orientation toggle is session-only and cannot restore itself on launch")
	_check("_gameplay_text_visible := false" in main \
		and "_hotkey_hints_visible := false" in main \
		and "Show control hints" in main,
		"gameplay text and control hints start hidden but remain available in Debug")
	for field in ["turn_response", "turn_dead_zone", "max_turn_speed", "camera_pitch", "camera_zoom",
			"look_ahead_distance", "acceleration_response", "braking_response"]:
		_check(('"%s"' % field) in editor,
			"the live camera editor exposes %s" % field)
	_check("user://always_forward_camera.cfg" in main \
		and "_save_persisted_always_forward_camera" in main,
		"the camera toggle and tuning autosave locally")
	_check("_window.force_native = true" in editor and "Return to game" in editor,
		"the tuner uses a compact native tool window with explicit focus return")
	_check("Orthographic (no perspective)" in editor and '"orthographic"' in main \
		and "PROJECTION_PERSPECTIVE" in main,
		"projection can switch between orthographic and perspective views")
	_check("tool_window_has_input_focus" in main and "tool_window_has_input_focus" in input,
		"camera tuning focus sends neutral vehicle controls")
	print("ALWAYS_FORWARD_CAMERA_UI_TEST PASS menu=debug tuning=live autosave=yes")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("ALWAYS_FORWARD_CAMERA_UI_TEST FAIL: %s" % message)
		quit(1)
