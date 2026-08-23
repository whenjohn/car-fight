extends SceneTree

func _init() -> void:
	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	var harness_source := FileAccess.get_file_as_string(
		"res://scripts/webrtc_turn_shape_test.sh")
	if 'var browser_script := _web_query("script")' not in main_source \
			or '"idle":' not in main_source \
			or '"cursor_offset": Vector2.ZERO' not in main_source \
			or 'browser_script_query="&script=idle"' not in harness_source:
		push_error("WEB_SOAK_INPUT_TEST FAIL: long soak must send explicit neutral input")
		quit(1)
		return
	print("WEB_SOAK_INPUT_TEST PASS")
	quit(0)
