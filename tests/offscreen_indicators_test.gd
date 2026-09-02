extends SceneTree

const SCRIPT_PATH := "res://ui/offscreen_indicators.gd"
const INDICATORS_SCRIPT := preload("res://ui/offscreen_indicators.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check(INDICATORS_SCRIPT != null, "offscreen indicator script compiles")
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	_check(not source.is_empty(), "offscreen indicator script exists")
	_check("const MAX_PLAYER_MARKERS := 3" in source,
		"only the three nearest opposing cars can claim a rim marker")
	_check("const MAX_DISTANCE := 150.0" in source,
		"markers have a deliberate awareness range")
	_check("candidates.slice(0, MAX_PLAYER_MARKERS)" in source,
		"player markers are selected by nearest distance")
	_check("dots, bolts, troops" in source and "projectile" in source,
		"high-count entities are explicitly excluded")
	_check("_heading_angle" in source and "_camera.unproject_position" in source,
		"player heading is projected through the active camera")
	_check("KIND_BALL" in source and "_diamond" in source,
		"the city ball is a distance-only objective marker")
	if _failures.is_empty():
		print("OFFSCREEN_INDICATORS_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
