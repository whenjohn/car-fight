extends SceneTree

const POLICY := preload("res://platform/window_safety_policy.gd")


func _init() -> void:
	if not POLICY.should_enable("macOS", "x86_64", "macos"):
		_fail("Intel macOS runtime must enable the guard")
		return
	if POLICY.should_enable("macOS", "arm64", "macos") \
			or POLICY.should_enable("Windows", "x86_64", "windows") \
			or POLICY.should_enable("macOS", "x86_64", "headless"):
		_fail("guard must stay scoped to rendered Intel macOS")
		return

	var usable := Rect2i(0, 25, 2880, 1775)
	var ordinary := POLICY.desired_state(DisplayServer.WINDOW_MODE_WINDOWED,
		false, usable, Vector2i(1280, 720), Vector2i(80, 100))
	if bool(ordinary["changed"]):
		_fail("ordinary inset window was changed: %s" % ordinary)
		return
	var manually_resized := POLICY.desired_state(DisplayServer.WINDOW_MODE_WINDOWED,
		false, usable, Vector2i(2000, 1100), Vector2i(100, 100))
	if bool(manually_resized["changed"]):
		_fail("large manual resize inside the safe inset was changed: %s" % manually_resized)
		return

	var expanded := POLICY.desired_state(DisplayServer.WINDOW_MODE_MAXIMIZED,
		true, usable, Vector2i(2800, 1518), Vector2i(0, 25))
	if int(expanded["mode"]) != DisplayServer.WINDOW_MODE_WINDOWED \
			or bool(expanded["borderless"]) \
			or Vector2i(expanded["size"]) != Vector2i(2784, 1518) \
			or Vector2i(expanded["position"]) != Vector2i(48, 73):
		_fail("expanded window did not return to the safe inset: %s" % expanded)
		return
	for reason in ["expanded_mode", "borderless", "oversize", "near_edge"]:
		if reason not in expanded["reasons"]:
			_fail("expanded enforcement omitted %s: %s" % [reason, expanded])
			return

	var right_edge := POLICY.desired_state(DisplayServer.WINDOW_MODE_WINDOWED,
		false, usable, Vector2i(1280, 720), Vector2i(2000, 100))
	if Vector2i(right_edge["position"]) != Vector2i(1552, 100) \
			or right_edge["reasons"] != ["near_edge"]:
		_fail("right-edge clamp is incorrect: %s" % right_edge)
		return

	var minimized := POLICY.desired_state(DisplayServer.WINDOW_MODE_MINIMIZED,
		false, usable, Vector2i(1280, 720), Vector2i(80, 100))
	if bool(minimized["changed"]) \
			or int(minimized["mode"]) != DisplayServer.WINDOW_MODE_MINIMIZED:
		_fail("ordinary minimization must remain available: %s" % minimized)
		return

	print("WINDOW_SAFETY_POLICY_TEST PASS")
	quit()


func _fail(message: String) -> void:
	push_error("WINDOW_SAFETY_POLICY_TEST FAIL: %s" % message)
	quit(1)
