extends SceneTree

const COURSE_PATH := "res://world/elevated_course.gd"
const FOLLOW := preload("res://player/follow_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	var course := load(COURSE_PATH)
	_check(course != null, "elevated course script loads")
	if course != null:
		var ramp: Dictionary = course.ramp()
		var roads: Array = course.upper_roads()
		var ramp_size: Vector3 = ramp["size"]
		var ramp_rotation: Vector3 = ramp["rotation"]
		var ramp_position: Vector3 = ramp["position"]
		_check(ramp_rotation.x > 0.0, "ramp rises toward the upper road")
		_check(roads.size() >= 2, "course has connected upper-level roads")
		var rise := ramp_size.z * sin(ramp_rotation.x)
		_check(absf(rise - float(course.ROAD_SURFACE_Y)) < 0.01,
			"ramp lip reaches the upper-road height")
		var lip_z := ramp_position.z - ramp_size.z * 0.5 * cos(ramp_rotation.x)
		var main_road: Dictionary = roads[0]
		var road_size: Vector3 = main_road["size"]
		var road_position: Vector3 = main_road["position"]
		var south_edge := road_position.z + road_size.z * 0.5
		var gap := lip_z - south_edge
		_check(gap >= 2.0 and gap <= 6.0, "ramp has a visible but reachable launch gap")
		for speed in [14.0, 23.3333333]:
			var flight_range: float = float(speed) * float(speed) * sin(2.0 * ramp_rotation.x) / 9.8
			var landing_z: float = lip_z - flight_range
			_check(landing_z <= south_edge and landing_z >= road_position.z - road_size.z * 0.5,
				"upper road catches a %.1f-speed launch" % speed)

	var composed: Vector3 = FOLLOW.compose_drive_velocity(Vector3(3.0, 0.0, 4.0), 6.0)
	_check(composed.is_equal_approx(Vector3(3.0, 6.0, 4.0)),
		"ground steering preserves airborne vertical velocity")

	if _failures.is_empty():
		print("ELEVATED_COURSE_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
