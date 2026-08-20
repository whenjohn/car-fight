extends SceneTree

const HOMING := preload("res://combat/homing_missile.gd")

func _init() -> void:
	var start := Vector3.ZERO
	var target := Vector3(12.0, 0.0, -12.0)
	var initial := Vector3(0.0, 0.0, -HOMING.SPEED)
	var steered := HOMING.steer(initial, start, target, 1.0 / 60.0)
	if steered.x <= 0.0 or not is_equal_approx(steered.length(), HOMING.SPEED):
		push_error("HOMING_MISSILE_TEST FAIL: eligible target must bend the fixed-speed missile")
		quit(1)
		return
	var behind := HOMING.steer(initial, start, Vector3(0.0, 0.0, 12.0), 1.0 / 60.0)
	if is_zero_approx(behind.x):
		push_error("HOMING_MISSILE_TEST FAIL: a confirmed target must steer from any bearing")
		quit(1)
		return
	var committed := HOMING.steer(initial,
		target + Vector3(HOMING.COMMIT_DISTANCE - 0.1, 0.0, 0.0), target, 1.0 / 60.0)
	if not is_equal_approx(committed.x, 0.0):
		push_error("HOMING_MISSILE_TEST FAIL: missile must go ballistic inside commit distance")
		quit(1)
		return
	var fallback := HOMING.steer(initial, start, Vector3.ZERO, 1.0 / 60.0)
	if not fallback.is_equal_approx(initial):
		push_error("HOMING_MISSILE_TEST FAIL: no-lock missile must keep its launch heading")
		quit(1)
		return
	if HOMING.ACQUIRE_RANGE <= HOMING.COMMIT_DISTANCE:
		push_error("HOMING_MISSILE_TEST FAIL: immediate-lock range must exceed the terminal hit envelope")
		quit(1)
		return
	print("HOMING_MISSILE_TEST PASS")
	quit(0)
