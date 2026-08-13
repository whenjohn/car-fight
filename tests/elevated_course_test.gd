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
		var supports: Array = course.supports()
		var ramp_size: Vector3 = ramp["size"]
		var ramp_rotation: Vector3 = ramp["rotation"]
		var ramp_position: Vector3 = ramp["position"]
		_check(ramp_rotation.x > 0.0, "ramp rises toward the upper road")
		_check(roads.size() >= 2, "course has connected upper-level roads")
		_check(supports.size() >= 4, "upper roads have visible height supports")
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
		for speed in [FOLLOW.SPEED, FOLLOW.BURST_SPEED]:
			var flight_range: float = float(speed) * float(speed) * sin(2.0 * ramp_rotation.x) / 9.8
			var landing_z: float = lip_z - flight_range
			_check(landing_z <= south_edge and landing_z >= road_position.z - road_size.z * 0.5,
				"upper road catches a %.1f-speed launch" % speed)
		var camera_target: Vector3 = course.camera_target(Vector3(7.0, 5.0, -9.0))
		_check(camera_target.is_equal_approx(Vector3(7.0, 0.0, -9.0)),
			"camera follows X/Z without cancelling visible jump height")

	var composed: Vector3 = FOLLOW.compose_drive_velocity(Vector3(3.0, 0.0, 4.0), 6.0)
	_check(composed.is_equal_approx(Vector3(3.0, 6.0, 4.0)),
		"ground steering preserves airborne vertical velocity")
	var angular := FOLLOW.compose_drive_angular_velocity(Vector3(0.7, 4.0, -0.4), 1.2)
	_check(angular.is_equal_approx(Vector3(0.7, 1.2, -0.4)),
		"steering preserves physical landing pitch and roll")
	var tilted_basis := Basis(Vector3.FORWARD, deg_to_rad(10.0))
	var restoring := FOLLOW.upright_torque(tilted_basis, Vector3.ZERO, 2.2)
	_check(restoring.dot(tilted_basis.y.cross(Vector3.UP)) > 0.0,
		"suspension torque physically restores a tilted vehicle")
	_check(FOLLOW.upright_torque(Basis.IDENTITY, Vector3.ZERO, 2.2).is_zero_approx(),
		"an upright settled vehicle receives no artificial torque")
	var tilted_sideways := Basis(Vector3.UP, -PI * 0.5) \
		* Basis(Vector3.RIGHT, deg_to_rad(12.0))
	_check(absf(FOLLOW.heading_yaw(tilted_sideways) + PI * 0.5) < 0.001,
		"physical pitch does not corrupt a sideways vehicle heading")
	var touchdown := FOLLOW.landing_torque_impulse(
		Vector3(0.0, -8.0, -5.0), Vector3.UP, 8.0, 2.2)
	_check(touchdown.x < -0.1 and absf(touchdown.y) < 0.001,
		"moving touchdown produces a physical pitch impulse")
	_check(touchdown.length() <= FOLLOW.LANDING_MAX_TORQUE_IMPULSE + 0.001,
		"landing jostle remains a small bounded impulse")
	_check(FOLLOW.landing_torque_impulse(
		Vector3(0.0, -1.0, -5.0), Vector3.UP, 1.0, 2.2).is_zero_approx(),
		"minor road contact does not trigger a landing jostle")

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
