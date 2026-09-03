extends SceneTree


func _init() -> void:
	var main := FileAccess.get_file_as_string("res://Main.gd")
	var editor := FileAccess.get_file_as_string("res://ui/always_forward_camera_editor.gd")
	var input := FileAccess.get_file_as_string("res://player/player_input.gd")
	_check("Always-forward camera" in main and "Always-forward camera tuning…" in main,
		"the Debug system menu exposes the experiment toggle and tuner")
	_check("_always_forward_camera_enabled := true" in main,
		"the experimental worktree starts with nose-up camera behavior enabled")
	for field in ["turn_response", "max_turn_angle", "look_ahead_distance",
			"acceleration_response", "braking_response"]:
		_check(('"%s"' % field) in editor,
			"the live camera editor exposes %s" % field)
	_check("user://always_forward_camera.cfg" in main \
		and "_save_persisted_always_forward_camera" in main,
		"the camera toggle and tuning autosave locally")
	_check("_window.force_native = true" in editor and "Return to game" in editor,
		"the tuner uses a compact native tool window with explicit focus return")
	_check("tool_window_has_input_focus" in main and "tool_window_has_input_focus" in input,
		"camera tuning focus sends neutral vehicle controls")
	print("ALWAYS_FORWARD_CAMERA_UI_TEST PASS menu=debug tuning=live autosave=yes")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("ALWAYS_FORWARD_CAMERA_UI_TEST FAIL: %s" % message)
		quit(1)
