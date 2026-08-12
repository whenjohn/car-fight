extends SceneTree
## Focused contract for g2-style frozen Jeep echoes and screen velocity blur.

const FOLLOW := preload("res://player/follow_controller.gd")
const HULL := preload("res://player/ground_vehicle_hull.gd")
const BLUR := preload("res://fx/boost_velocity_blur.gd")

var _failures: Array[String] = []

func _init() -> void:
	var burst := FOLLOW.command(Vector2(16.0, 0.0), 0.0, true, 0.0, 14.0)
	_check(bool(burst.get("boost_active", false)),
		"Space burst exposes a synchronized boost FX state")
	var idle := FOLLOW.command(Vector2.ZERO, 0.0, true, 0.0, 0.0)
	_check(not bool(idle.get("boost_active", true)),
		"Space without drive intent does not emit boost afterimages")
	var reverse := FOLLOW.command(Vector2(16.0, 0.0), 0.0, true, 0.0, 4.0, true)
	_check(not bool(reverse.get("boost_active", true)),
		"reverse takes priority over the boost FX")

	_check(HULL.BOOST_ECHO_COUNT == 4,
		"boost prepares g2's four frozen body echoes")
	_check(is_equal_approx(HULL.BOOST_ECHO_INTERVAL, 0.075),
		"body echoes retain g2's cadence")
	_check(HULL.BOOST_ECHO_COLOR.is_equal_approx(Color(1.0, 0.38, 0.08, 0.28)),
		"body echoes retain g2's orange emission")
	_check(is_zero_approx(BLUR.effect_strength(false, 23.0)),
		"screen blur stays off outside boost")
	_check(is_zero_approx(BLUR.effect_strength(true, BLUR.MIN_EFFECT_SPEED)),
		"screen blur stays off below its motion threshold")
	_check(BLUR.effect_strength(true, BLUR.FULL_EFFECT_SPEED) > 0.99,
		"screen blur reaches full strength at boost speed")
	var blur_shader := load("res://fx/boost_velocity_blur.gdshader") as Shader
	_check(blur_shader != null and "hint_screen_texture" in blur_shader.code,
		"boost blur samples the rendered scene")
	_check(blur_shader != null and blur_shader.code.count("texture(screen_texture") == 6,
		"boost blur uses the accepted six current-frame taps")

	if _failures.is_empty():
		print("BOOST_AFTERIMAGE_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
