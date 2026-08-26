extends SceneTree

const HINTS := preload("res://fx/occluded_support_hints.gd")

var _failures: Array[String] = []

func _init() -> void:

	var support := Vector3(0.0, 1.5, 0.0)
	var size := Vector3(0.7, 3.0, 0.7)
	_check(is_zero_approx(HINTS.visibility_strength(Vector3(-1.0, 1.0, 0.0),
		Vector3(8.0, 0.0, 0.0), support, size, false)),
		"supports on the visible deck must not project a warning")
	_check(HINTS.visibility_strength(Vector3(-2.0, 1.0, 0.0), Vector3.ZERO,
		support, size, true) > 0.1,
		"a nearby hidden support must show a stationary proximity warning")
	_check(HINTS.visibility_strength(Vector3(-7.0, 1.0, 0.0), Vector3(14.0, 0.0, 0.0),
		support, size, true) > 0.1,
		"a support in the 0.6-second travel corridor must reveal early")
	_check(is_zero_approx(HINTS.visibility_strength(Vector3(-7.0, 1.0, 4.0),
		Vector3(14.0, 0.0, 0.0), support, size, true)),
		"a support outside the driving corridor must remain hidden")
	_check(HINTS.visibility_strength(Vector3(2.0, 1.0, 0.0), Vector3(8.0, 0.0, 0.0),
		support, size, true) > 0.1,
		"a close support remains visible while the Jeep clears it")
	if _failures.is_empty():
		print("OCCLUDED_SUPPORT_HINTS_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:

	if not condition:
		_failures.append("OCCLUDED_SUPPORT_HINTS_TEST FAIL: %s" % message)
