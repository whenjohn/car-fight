extends SceneTree

const DOTS_SCRIPT_PATH := "res://world/dots.gd"
const DOTS_SCRIPT := preload("res://world/dots.gd")

var _failures: Array[String] = []

func _init() -> void:
	var source := FileAccess.get_file_as_string(DOTS_SCRIPT_PATH)
	_check(not source.is_empty(), "dots script exists")
	if not source.is_empty():
		_check("const DOT_COUNT := 72" in source, "field has enough dots to make routes worthwhile")
		_check("const VACUUM_RADIUS := 4.8" in source, "pickup radius reaches a moving car")
		_check("const DOT_RADIUS := 0.30" in source, "dots remain visually smaller than cars")
		_check(not "RigidBody3D" in source, "dots are not per-item physics bodies")
		_check(not "Area3D" in source, "dots use a data proximity check, not colliders")
		_check("best_distance" in source, "server resolves contested dots to one nearest car")
	_test_all_hidden_field()
	if _failures.is_empty():
		print("DOTS_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_all_hidden_field() -> void:
	var dots := DOTS_SCRIPT.new()
	dots._mesh = ImmediateMesh.new()
	dots._dots = {700001: Vector3(1.0, 0.0, 1.0)}
	dots._hidden = {700001: 0.0}
	dots._rebuild_field()
	_check(dots._mesh.get_surface_count() == 0,
		"an all-hidden prediction field remains an empty mesh without committing a surface")
	dots.free()
