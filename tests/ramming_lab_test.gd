extends SceneTree

const LAB := preload("res://player/ramming_lab.gd")
const FOLLOW := preload("res://player/follow_controller.gd")
const HULL := preload("res://player/ground_vehicle_hull.gd")
const TUNING := preload("res://player/vehicle_tuning.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check(LAB.DRONES.size() == 3, "lab has exactly three slow drones")
	var ids := {}
	var lane_xs: Array[float] = []
	var expected_models := ["Humvee M242", "Apocalypse Bus", "LP Car A03-1"]
	var expected_masses := [3.2, 4.5, 1.6]
	for index in range(LAB.DRONES.size()):
		var drone: Dictionary = LAB.DRONES[index]
		var body_id := int(drone["id"])
		ids[body_id] = true
		lane_xs.append(float(drone["lane_x"]))
		var vehicle_index := int(drone["vehicle_index"])
		_check(str((HULL.VEHICLES[vehicle_index] as Dictionary)["name"]) \
			== expected_models[index], "drone %d uses its representative model" % index)
		_check(is_equal_approx(float(drone["model_scale"]), 1.5),
			"drone %d uses the built-in 150%% model sizing step" % index)
		_check(is_equal_approx(TUNING.default_mass(expected_models[index]),
			float(expected_masses[index])),
			"drone %d uses its representative weight class" % index)
		var spawn_index := int(drone["spawn_endpoint"])
		var origin := LAB.endpoint(drone, spawn_index)
		var destination := LAB.endpoint(drone, 1 - spawn_index)
		var forward := -Basis(Vector3.UP, LAB.spawn_yaw(drone, spawn_index)).z
		var expected := Vector3(destination.x - origin.x, 0.0,
			destination.y - origin.y).normalized()
		_check(forward.dot(expected) > 0.999, "drone %d faces its first waypoint" % index)
	_check(ids.size() == 3 and ids.keys().min() >= 2000002001 \
		and ids.keys().max() <= 2000002003,
		"drone identities use the fixed high positive StateBundle route range")
	_check(lane_xs == [-6.0, 0.0, 6.0], "lab lanes stay fixed and separated")

	var slow_command := FOLLOW.command(Vector2(0.0, LAB.CURSOR_DISTANCE), 0.0,
		false, 0.0)
	_check(absf(float(slow_command["speed"]) - 6.015789) < 0.001,
		"lab cursor distance produces the intended six-unit traffic speed")
	var first: Dictionary = LAB.DRONES[0]
	_check(not LAB.off_course(Vector3(-17.9, 0.0, 0.0), first),
		"corridor permits a hard but recoverable displacement")
	_check(LAB.off_course(Vector3(-18.1, 0.0, 0.0), first),
		"corridor detects a drone displaced beyond twelve units")
	_check(LAB.recovery_reason(2.0, 0.0, 0.0, false) == "stalled",
		"stalled drones recover after the configured delay")
	_check(LAB.recovery_reason(0.0, 2.0, 0.0, false) == "overturned",
		"overturned drones recover after the configured delay")
	_check(LAB.recovery_reason(0.0, 0.0, 3.0, false) == "off-course",
		"off-course drones recover after the configured delay")
	_check(LAB.recovery_reason(0.0, 0.0, 0.0, true) == "outside-city",
		"leaving the authoritative city recovers immediately")
	var far := LAB.far_endpoint(first, [Vector3(-6.0, 0.0, -48.0)])
	_check(far == 1, "recovery chooses the endpoint farthest from a player")
	var blocked := LAB.far_endpoint(first, [Vector3(-6.0, 0.0, -52.0),
		Vector3(-6.0, 0.0, 52.0)])
	_check(blocked == -1, "recovery waits when both endpoints are occupied")

	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	var body_source := FileAccess.get_file_as_string("res://player/player_body.gd")
	_check("--ramming-lab" in main_source and "RAMMING_LAB_READY" in main_source,
		"main exposes the explicit lab mode")
	_check("input_authority_id" in main_source and "input_authority_id" in body_source,
		"server-owned drones have identity separate from input authority")
	_check("vehicle_model_scale" in main_source and "vehicle_model_scale" in body_source,
		"drone model sizing replicates with the spawn configuration")
	_check("RAM_BASELINE" in main_source,
		"the server records an unchanged-physics contact baseline")

	if _failures.is_empty():
		print("RAMMING_LAB_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
