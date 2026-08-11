extends SceneTree

const FOLLOW := preload("res://player/follow_controller.gd")
var _failures := 0

func _init() -> void:
	var idle := FOLLOW.command(Vector2.ZERO, 0.0, false, 0.0)
	_expect_close(idle["speed"], 0.0, 0.0001, "zero cursor parks")
	_expect_close(idle["yaw_rate"], 0.0, 0.0001, "zero cursor does not turn")

	var edge := FOLLOW.command(Vector2(1.0, 0.0), 0.0, false, 0.0)
	_expect_close(edge["speed"], 0.0, 0.0001, "one-unit movement deadzone")

	var half := FOLLOW.command(Vector2(8.5, 0.0), 0.0, false, 0.0)
	_expect_close(half["throttle"], 0.5, 0.0001, "cursor distance maps continuously to throttle")

	var full := FOLLOW.command(Vector2(16.0, 0.0), 0.0, false, 0.0)
	_expect_close(full["speed"], 14.0, 0.0001, "far cursor reaches normal top speed")
	_expect_close(full["yaw_rate"], -2.4, 0.0001, "far cursor uses the 2.4 rad/s turn cap")

	var burst := FOLLOW.command(Vector2(3.0, 0.0), 0.0, true, 0.0)
	_expect_close(burst["speed"], 23.3333333, 0.0001, "Space forces full burst speed")
	_expect_close(burst["acceleration"], 416.6666667, 0.0001, "Space uses burst acceleration")

	if _failures == 0:
		print("FOLLOW_TEST PASS")
		quit()
	else:
		push_error("FOLLOW_TEST FAIL failures=%d" % _failures)
		quit(1)

func _expect_close(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures += 1
		push_error("%s: expected %.6f, got %.6f" % [label, expected, actual])

