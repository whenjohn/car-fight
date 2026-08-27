extends SceneTree
## Pure presentation bounds for the standalone lab and live vehicle hull.

const HULL := preload("res://player/ground_vehicle_hull.gd")

var _failures: Array[String] = []

func _init() -> void:
	_check(HULL.chassis_dynamic_pitch_target(1.0, 18.0, -1.0) < 0.0,
		"hard braking dives the nose")
	_check(HULL.chassis_dynamic_pitch_target(0.0, 8.0, 1.0) > 0.0,
		"heavy acceleration squats the rear")
	_check(HULL.chassis_dynamic_pitch_target(0.0, 8.0, 0.0, true) > 0.0,
		"boost keeps a readable acceleration squat")
	_check(absf(HULL.chassis_dynamic_roll_target(1.85, 18.0, 1.0)) \
		<= HULL.BODY_DYNAMIC_ROLL_MAX + 0.0001,
		"combined corner and drift roll remains bounded")
	var left_wheel := HULL.wheel_steer_target(1.0, -1.0)
	var right_wheel := HULL.wheel_steer_target(1.0, 1.0)
	_check(not is_equal_approx(absf(left_wheel), absf(right_wheel)),
		"front wheels use visibly different Ackermann angles")
	_check(HULL.wheel_steer_target(0.7, 1.0, 1.0) \
		< HULL.wheel_steer_target(0.7, 1.0, 0.0),
		"drift adds bounded countersteer")
	_check(HULL.wheel_suspension_target(true, 1.0, -1.0, 0.0) > 0.0,
		"braking loads the front suspension")
	_check(HULL.wheel_suspension_target(false, 1.0, 1.0, 0.0) > 0.0,
		"acceleration loads the rear suspension")
	var oil_dry := HULL.oil_fx_flash_state(0.0, 0.0)
	var oil_flash := HULL.oil_fx_flash_state(1.0,
		PI * 0.5 / HULL.OIL_FX_FLASH_SPEED)
	_check(not bool(oil_dry["active"]), "oil warning FX stays absent while dry")
	_check(bool(oil_flash["active"]) and float(oil_flash["amber"]) > 0.99 \
		and float(oil_flash["magenta"]) < 0.13,
		"oil warning FX flashes strongly between alternating hazard colors")
	var scene := load("res://tools/VehicleAnimationLab.tscn") as PackedScene
	_check(scene != null, "animation lab scene loads")

	if _failures.is_empty():
		print("VEHICLE_ANIMATION_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
