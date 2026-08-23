extends SceneTree

const CLIENT_CRUISE := preload("res://player/client_cruise.gd")
const FOLLOW := preload("res://player/follow_controller.gd")

func _init() -> void:
	var forward := CLIENT_CRUISE.cursor_for(Basis.IDENTITY)
	if forward.distance_to(Vector2(0.0, -FOLLOW.MAX_DISTANCE)) > 0.0001:
		push_error("CLIENT_CRUISE_TEST FAIL: identity heading is not full forward input")
		quit(1)
		return
	var right := CLIENT_CRUISE.cursor_for(Basis(Vector3.UP, -PI * 0.5))
	if right.distance_to(Vector2(FOLLOW.MAX_DISTANCE, 0.0)) > 0.0001:
		push_error("CLIENT_CRUISE_TEST FAIL: rotated heading is not full forward input")
		quit(1)
		return
	var command := FOLLOW.command(forward, 0.0, false, 0.0)
	if absf(float(command["speed"]) - FOLLOW.SPEED) > 0.0001 \
			or bool(command["boost_active"]):
		push_error("CLIENT_CRUISE_TEST FAIL: cruise must request max ordinary speed without burst")
		quit(1)
		return
	print("CLIENT_CRUISE_TEST PASS")
	quit()
