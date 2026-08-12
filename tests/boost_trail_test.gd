extends SceneTree

const FOLLOW := preload("res://player/follow_controller.gd")
const TRAIL := preload("res://player/boost_trail.gd")
const RESAMPLER := preload("res://player/trail_resampler.gd")

var _failures: Array[String] = []

func _init() -> void:
	var burst := FOLLOW.command(Vector2(16.0, 0.0), 0.0, true, 0.0, 14.0)
	_check(bool(burst.get("boost_active", false)),
		"Space burst exposes a synchronized boost FX state")
	var idle := FOLLOW.command(Vector2.ZERO, 0.0, true, 0.0, 0.0)
	_check(not bool(idle.get("boost_active", true)),
		"Space without drive intent does not emit a boost trail")
	var reverse := FOLLOW.command(Vector2(16.0, 0.0), 0.0, true, 0.0, 4.0, true)
	_check(not bool(reverse.get("boost_active", true)),
		"reverse takes priority over the boost trail")

	var emitted: Dictionary = RESAMPLER.advance(Vector3.ZERO,
		Vector3(0.0, 0.0, 2.2), 0.55)
	var points := emitted["points"] as Array[Vector3]
	_check(points.size() == 4, "trail samples are evenly spaced in world space")
	for index in range(points.size()):
		_check(points[index].is_equal_approx(Vector3(0.0, 0.0, 0.55 * (index + 1))),
			"trail sample %d keeps fixed spacing" % index)
	var bounded: Dictionary = RESAMPLER.advance(Vector3.ZERO,
		Vector3(100.0, 0.0, 0.0), 0.55, 3)
	_check((bounded["points"] as Array[Vector3]).size() == 3,
		"a frame hitch cannot create an unbounded FX burst")
	_check(TRAIL.TRAIL_COLOR.is_equal_approx(Color(1.0, 0.62, 0.18, 0.25)),
		"boost trail keeps g2's orange color")

	if _failures.is_empty():
		print("BOOST_TRAIL_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
