extends SceneTree

const TRACTOR := preload("res://player/tractor_controller.gd")

func _init() -> void:
	var origin := Vector3.ZERO
	var target := Vector3(8.0, 1.0, 0.0)
	if not TRACTOR.can_pull(origin, target, 1.15):
		push_error("TRACTOR_AREA_TEST FAIL: ball inside the vacuum must be pulled")
		quit(1)
		return
	if TRACTOR.can_pull(origin, Vector3(14.0, 0.0, 0.0), 1.15):
		push_error("TRACTOR_AREA_TEST FAIL: ball outside the circumference must be ignored")
		quit(1)
		return
	var reel := TRACTOR.reel(origin, Vector3.ZERO, 2.2, target, Vector3.ZERO, 0.85,
		1.55, 1.15, 1.0 / 120.0)
	var ball_impulse: Vector3 = reel["target_impulse"]
	var car_impulse: Vector3 = reel["origin_impulse"]
	if ball_impulse.x >= 0.0 or car_impulse.x <= 0.0:
		push_error("TRACTOR_REEL_TEST FAIL: ball must pull inward and car must feel reaction")
		quit(1)
		return
	if ball_impulse.length() <= car_impulse.length():
		push_error("TRACTOR_MASS_TEST FAIL: anchored car should move less than the ball")
		quit(1)
		return
	print("TRACTOR_CONTROLLER_TEST PASS")
	quit(0)
