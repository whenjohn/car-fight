extends SceneTree

const IMPACT := preload("res://player/impact_controller.gd")
const PLAYER_BODY := preload("res://player/player_body.gd")

func _init() -> void:
	var unshielded := IMPACT.response(Vector3(1.0, 0.0, 0.0), false)
	var shielded := IMPACT.response(Vector3(1.0, 0.0, 0.0), true)
	var full_linear: Vector3 = unshielded["linear_impulse"]
	var shield_linear: Vector3 = shielded["linear_impulse"]
	var full_torque: Vector3 = unshielded["torque_impulse"]
	var shield_torque: Vector3 = shielded["torque_impulse"]
	if absf(shield_linear.length() / full_linear.length() - 0.15) > 0.0001 \
			or absf(shield_torque.length() / full_torque.length() - 0.15) > 0.0001:
		_fail("shield must pass exactly 15% of linear and angular shove")
		return
	if full_linear.x <= 0.0 or full_torque.z >= 0.0:
		_fail("incoming direction must drive translation and perpendicular body jostle")
		return
	if IMPACT.acceleration_scale(IMPACT.RECOVERY_TIME) >= 1.0 \
			or IMPACT.acceleration_scale(0.0) != 1.0:
		_fail("impact recovery must briefly soften only active drive correction")
		return
	if float(shielded["recovery_time"]) != float(unshielded["recovery_time"]) \
			or IMPACT.upright_scale(IMPACT.RECOVERY_TIME) >= 1.0 \
			or IMPACT.upright_scale(0.0) != 1.0:
		_fail("shielded hits must retain a brief readable suspension recovery")
		return
	var fraction := IMPACT.segment_sphere_entry(Vector3(-2.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0), Vector3.ZERO, 1.0)
	if absf(fraction - 0.25) > 0.0001:
		_fail("segment sweep must return the sphere entry point")
		return
	if IMPACT.segment_sphere_entry(Vector3(-2.0, 0.0, 0.0),
			Vector3(-2.0, 0.0, 2.0), Vector3.ZERO, 1.0) <= 1.0:
		_fail("segment sweep must reject a miss")
		return
	var capsule_entry := IMPACT.segment_capsule_entry(Vector3(0.0, 0.0, -3.0),
		Vector3(0.0, 0.0, 3.0), Vector3.ZERO, Vector3.FORWARD, 1.05, 3.40)
	if absf(capsule_entry - (1.30 / 6.0)) > 0.0001:
		_fail("segment sweep must enter the capsule at its rounded front tip")
		return
	if IMPACT.segment_capsule_entry(Vector3(1.06, 0.0, -3.0),
			Vector3(1.06, 0.0, 3.0), Vector3.ZERO, Vector3.FORWARD, 1.05, 3.40) <= 1.0:
		_fail("segment sweep must reject a path beyond the capsule side")
		return
	var side_distance := IMPACT.planar_capsule_distance(Vector3(2.05, 0.0, 0.0),
		Vector3.ZERO, Vector3.FORWARD, 1.05, 3.40)
	var tip_distance := IMPACT.planar_capsule_distance(Vector3(0.0, 0.0, 2.20),
		Vector3.ZERO, Vector3.FORWARD, 1.05, 3.40)
	if absf(side_distance - 1.0) > 0.0001 or absf(tip_distance - 0.5) > 0.0001:
		_fail("area distance must follow the capsule side and rounded ends")
		return

	var body := PLAYER_BODY.new()
	body.call("_service_shield_toggle", true)
	if not bool(body.get("shield_up")):
		body.free()
		_fail("Q rising edge must raise the shield")
		return
	body.call("_service_shield_toggle", false)
	body.call("_service_cloak_toggle", true)
	if bool(body.get("shield_up")) or not bool(body.get("is_cloaked")):
		body.free()
		_fail("raising cloak must drop an active shield")
		return
	body.call("_service_shield_toggle", true)
	if bool(body.get("shield_up")):
		body.free()
		_fail("Q must not raise a shield while cloaked")
		return
	body.free()

	if not InputMap.has_action("shield"):
		_fail("shield input action must exist")
		return
	var has_q := false
	for event in InputMap.action_get_events("shield"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q:
			has_q = true
	if not has_q:
		_fail("Q must activate shield")
		return
	print("IMPACT_CONTROLLER_TEST PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("IMPACT_CONTROLLER_TEST FAIL: %s" % message)
	quit(1)
