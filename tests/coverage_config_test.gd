extends SceneTree

const COVERAGE := preload("res://combat/coverage_config.gd")
const TARGETING := preload("res://combat/auto_targeting.gd")

var _failures: Array[String] = []

func _init() -> void:
	var ranges := COVERAGE.default_ranges()
	var widths := COVERAGE.default_widths()
	_check(is_equal_approx(COVERAGE.total_area(ranges, widths), COVERAGE.TOTAL_BUDGET),
		"default four-cone preset exactly fills the shared budget")
	_check(COVERAGE.is_valid(ranges, widths), "default coverage is valid")
	var specialized_ranges := PackedFloat32Array([16.0, 0.0, 0.0, 0.0])
	var specialized_widths := PackedFloat32Array([PI * 0.5, 0.0, 0.0, 0.0])
	_check(is_equal_approx(COVERAGE.total_area(specialized_ranges, specialized_widths),
		COVERAGE.TOTAL_BUDGET), "one narrow long zone can spend the whole budget")
	_check(not COVERAGE.is_valid(PackedFloat32Array([24.0, 8.0, 8.0, 8.0]), widths),
		"server validation rejects an over-budget configuration")
	var clamped := COVERAGE.clamp_range(0, 24.0, ranges, widths)
	_check(is_equal_approx(clamped, 8.0), "range drag clamps against the other three zones")
	widths[1] = 0.0
	_check(is_equal_approx(COVERAGE.clamp_range(1, 24.0, ranges, widths), 24.0),
		"a disabled zero-width zone may move its range handle without spending area")
	_check(COVERAGE.point_in_zone(Vector2(0.0, -7.9), 0, 8.0, PI * 0.5),
		"front zone contains a close forward point")
	_check(not COVERAGE.point_in_zone(Vector2(7.0, -1.0), 0, 8.0, PI * 0.5),
		"front zone rejects a point beyond its angle")
	_check(COVERAGE.point_in_zone(Vector2(7.0, 0.0), 1, 8.0, PI * 0.5),
		"right zone is anchored to the Jeep's positive-X side")
	_check(not COVERAGE.point_in_zone(Vector2(3.0, -1.0), 0, 8.0, PI * 0.5),
		"vehicle-pointing cone is narrow beside the Jeep")
	_check(COVERAGE.point_in_zone(Vector2(3.0, -1.0), 0, 8.0, PI * 0.5, true),
		"outward-pointing cone starts wide beside the Jeep")
	_check(not COVERAGE.point_in_zone(Vector2(1.0, -7.5), 0, 8.0, PI * 0.5, true),
		"outward-pointing cone narrows toward its far tip")
	var collapsed_handles := COVERAGE.editor_handle_positions(0, 0.0, PI * 0.5)
	_check((collapsed_handles["range"] as Vector2).length() >= COVERAGE.MIN_EDITOR_HANDLE_DISTANCE,
		"collapsed cones keep an editor recovery handle outside the Jeep")
	var candidates: Array[Dictionary] = [
		{"id": 1, "local_position": Vector2(0.0, -6.0), "visible": true},
		{"id": 2, "local_position": Vector2(0.0, -3.0), "visible": true},
		{"id": 3, "local_position": Vector2(0.0, -2.0), "visible": false},
		{"id": 4, "local_position": Vector2(6.0, 0.0), "visible": true},
	]
	_check(TARGETING.select_nearest(0, 8.0, PI * 0.5, false, candidates) == 2,
		"nearest visible in-zone target wins; blocked and side targets are rejected")
	if _failures.is_empty():
		print("COVERAGE_CONFIG_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
