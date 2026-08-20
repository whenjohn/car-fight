extends SceneTree

const WEAPON := preload("res://combat/area_weapon.gd")

var _failures: Array[String] = []

func _init() -> void:
	var origin := Vector3.ZERO
	var tap := WEAPON.layout(origin, Vector3(8.0, 0.0, -3.0), Vector3(8.4, 0.0, -3.1))
	_check(not bool(tap["is_drag"]), "short release remains a compact tap strike")
	_check((tap["impacts"] as PackedVector3Array).size() == WEAPON.BOMB_COUNT,
		"tap creates all five ordered bomb impacts")
	_check(is_equal_approx(float(tap["radius"]), WEAPON.TAP_RADIUS),
		"tap retains its broad overlapping burn radius")
	var drag := WEAPON.layout(origin, Vector3(-4.0, 0.0, 1.0), Vector3(30.0, 0.0, 1.0))
	var impacts: PackedVector3Array = drag["impacts"]
	_check(bool(drag["is_drag"]), "long hold-and-drag becomes a bombing run")
	_check(is_equal_approx((drag["end"] as Vector3).distance_to(drag["start"] as Vector3), 18.0),
		"drag length is capped to the auditable 18-unit run")
	_check(impacts[0].x < impacts[impacts.size() - 1].x,
		"drag impacts preserve the player's start-to-end direction")
	_check(is_equal_approx(float(drag["radius"]), WEAPON.DRAG_RADIUS),
		"drag uses smaller individual pools across the full line")
	if _failures.is_empty():
		print("AREA_WEAPON_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
