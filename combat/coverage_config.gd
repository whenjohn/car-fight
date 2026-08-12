extends RefCounted
## Pure four-zone coverage geometry. Angles are radians and positions use the
## Jeep's local X/Z plane, where forward is -Z.

const ZONE_NAMES := ["Front", "Right", "Rear", "Left"]
const ZONE_HEADINGS := [0.0, -PI * 0.5, PI, PI * 0.5]
const ZONE_COLORS := [
	Color("67d8ff"), Color("ffb45e"), Color("d184ff"), Color("78df86")]
const ZONE_COUNT := 4
const DEFAULT_RANGE := 8.0
const DEFAULT_WIDTH := PI * 0.5
const MAX_RANGE := 24.0
const MAX_WIDTH := PI
const TOTAL_BUDGET := PI * DEFAULT_RANGE * DEFAULT_RANGE

static func default_ranges() -> PackedFloat32Array:
	return PackedFloat32Array([DEFAULT_RANGE, DEFAULT_RANGE, DEFAULT_RANGE, DEFAULT_RANGE])

static func default_widths() -> PackedFloat32Array:
	return PackedFloat32Array([DEFAULT_WIDTH, DEFAULT_WIDTH, DEFAULT_WIDTH, DEFAULT_WIDTH])

static func sector_area(reach: float, width: float) -> float:
	return 0.5 * maxf(width, 0.0) * pow(maxf(reach, 0.0), 2.0)

static func total_area(ranges: PackedFloat32Array, widths: PackedFloat32Array) -> float:
	var total := 0.0
	for index in range(mini(ranges.size(), widths.size())):
		total += sector_area(ranges[index], widths[index])
	return total

static func is_valid(ranges: PackedFloat32Array, widths: PackedFloat32Array) -> bool:
	if ranges.size() != ZONE_COUNT or widths.size() != ZONE_COUNT:
		return false
	for index in range(ZONE_COUNT):
		if not is_finite(ranges[index]) or not is_finite(widths[index]):
			return false
		if ranges[index] < 0.0 or ranges[index] > MAX_RANGE:
			return false
		if widths[index] < 0.0 or widths[index] > MAX_WIDTH:
			return false
	return total_area(ranges, widths) <= TOTAL_BUDGET + 0.001

static func clamp_range(index: int, requested: float, ranges: PackedFloat32Array,
		widths: PackedFloat32Array) -> float:
	var width := widths[index]
	if width <= 0.0001:
		return clampf(requested, 0.0, MAX_RANGE)
	var other_area := total_area(ranges, widths) - sector_area(ranges[index], width)
	var available := maxf(TOTAL_BUDGET - other_area, 0.0)
	var budget_range := sqrt(2.0 * available / width)
	return clampf(requested, 0.0, minf(MAX_RANGE, budget_range))

static func clamp_width(index: int, requested: float, ranges: PackedFloat32Array,
		widths: PackedFloat32Array) -> float:
	var reach := ranges[index]
	if reach <= 0.0001:
		return clampf(requested, 0.0, MAX_WIDTH)
	var other_area := total_area(ranges, widths) - sector_area(reach, widths[index])
	var available := maxf(TOTAL_BUDGET - other_area, 0.0)
	var budget_width := 2.0 * available / (reach * reach)
	return clampf(requested, 0.0, minf(MAX_WIDTH, budget_width))

static func direction_for_heading(heading: float) -> Vector2:
	return Vector2(-sin(heading), -cos(heading))

static func local_point(world_point: Vector3, body_transform: Transform3D) -> Vector2:
	var point := body_transform.affine_inverse() * world_point
	return Vector2(point.x, point.z)

static func point_in_zone(point: Vector2, zone_index: int, reach: float, width: float) -> bool:
	var distance := point.length()
	if distance > reach or distance <= 0.0001 or width <= 0.0001:
		return false
	var direction := point / distance
	var center := direction_for_heading(ZONE_HEADINGS[zone_index])
	var angle := absf(atan2(center.cross(direction), center.dot(direction)))
	return angle <= width * 0.5 + 0.0001

static func handle_positions(index: int, reach: float, width: float) -> Dictionary:
	var heading: float = ZONE_HEADINGS[index]
	var center := direction_for_heading(heading) * reach
	var edge_reach := reach * 0.85
	return {
		"range": center,
		"left": direction_for_heading(heading - width * 0.5) * edge_reach,
		"right": direction_for_heading(heading + width * 0.5) * edge_reach,
	}
