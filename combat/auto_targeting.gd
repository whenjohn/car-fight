extends RefCounted
## Pure nearest-target selection. Main supplies vehicle-local positions and
## line-of-sight results from authoritative physics queries.

const COVERAGE := preload("res://combat/coverage_config.gd")

static func select_nearest(zone_index: int, reach: float, width: float,
		tip_outward: bool, candidates: Array[Dictionary]) -> int:
	var selected_id := -1
	var selected_distance := INF
	for candidate in candidates:
		if not bool(candidate.get("visible", true)):
			continue
		var local_position: Vector2 = candidate.get("local_position", Vector2.ZERO)
		if not COVERAGE.point_in_zone(local_position, zone_index, reach, width, tip_outward):
			continue
		var distance := local_position.length_squared()
		if distance < selected_distance:
			selected_distance = distance
			selected_id = int(candidate.get("id", -1))
	return selected_id
