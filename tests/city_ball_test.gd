extends SceneTree

const BALL_SCRIPT_PATH := "res://world/city_ball.gd"
const PLAYER_MASS := 2.2

var _failures: Array[String] = []


func _init() -> void:
	var ball_script := load(BALL_SCRIPT_PATH)
	_check(ball_script != null, "city ball script loads")
	if ball_script != null:
		_check(float(ball_script.RADIUS) >= 1.0, "ball is large enough to read at isometric scale")
		_check(float(ball_script.MASS) < PLAYER_MASS, "ball is lighter than a car")
		_check(float(ball_script.BOUNCE) >= 0.5, "ball retains a visible bounce")
		_check(float(ball_script.LINEAR_DAMP) > 0.0, "ball eventually rolls to a stop")
		var ball: Node = ball_script.new()
		_check(ball.has_method("apply_external_impulse"), "ball accepts combat and tractor impulses")
		ball.free()
		var spawn: Vector3 = ball_script.SPAWN_POSITION
		_check(absf(spawn.x) < 35.0 and absf(spawn.z) < 35.0,
			"ball starts at the central city intersection")
		_check(spawn.distance_to(Vector3(-3.0, 0.0, 0.0)) \
			> float(ball_script.RADIUS) + 1.55, "ball does not overlap the first car spawn")
	if _failures.is_empty():
		print("CITY_BALL_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
