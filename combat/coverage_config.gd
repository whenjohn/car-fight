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
const MAX_WIDTH := deg_to_rad(150.0)
const TOTAL_BUDGET := 4.0 * DEFAULT_RANGE * DEFAULT_RANGE
const MIN_EDITOR_HANDLE_DISTANCE := 2.4

static func default_ranges() -> PackedFloat32Array:
	return PackedFloat32Array([DEFAULT_RANGE, DEFAULT_RANGE, DEFAULT_RANGE, DEFAULT_RANGE])

static func default_widths() -> PackedFloat32Array:
	return PackedFloat32Array([DEFAULT_WIDTH, DEFAULT_WIDTH, DEFAULT_WIDTH, DEFAULT_WIDTH])

static func default_tips_outward() -> PackedByteArray:
	return PackedByteArray([0, 0, 0, 0])

static func cone_area(reach: float, width: float) -> float:
	if reach <= 0.0 or width <= 0.0:
		return 0.0
	return reach * reach * tan(minf(width, MAX_WIDTH) * 0.5)

static func total_area(ranges: PackedFloat32Array, widths: PackedFloat32Array) -> float:
	var total := 0.0
	for index in range(mini(ranges.size(), widths.size())):
		total += cone_area(ranges[index], widths[index])
	return total

static func is_valid(ranges: PackedFloat32Array, widths: PackedFloat32Array,
		tips_outward: PackedByteArray = PackedByteArray([0, 0, 0, 0])) -> bool:
	if ranges.size() != ZONE_COUNT or widths.size() != ZONE_COUNT \
			or tips_outward.size() != ZONE_COUNT:
		return false
	for index in range(ZONE_COUNT):
		if not is_finite(ranges[index]) or not is_finite(widths[index]):
			return false
		if ranges[index] < 0.0 or ranges[index] > MAX_RANGE:
			return false
		if widths[index] < 0.0 or widths[index] > MAX_WIDTH:
			return false
		if tips_outward[index] > 1:
			return false
	return total_area(ranges, widths) <= TOTAL_BUDGET + 0.001

static func clamp_range(index: int, requested: float, ranges: PackedFloat32Array,
		widths: PackedFloat32Array) -> float:
	var width := widths[index]
	if width <= 0.0001:
		return clampf(requested, 0.0, MAX_RANGE)
	var other_area := total_area(ranges, widths) - cone_area(ranges[index], width)
	var available := maxf(TOTAL_BUDGET - other_area, 0.0)
	var budget_range := sqrt(available / tan(width * 0.5))
	return clampf(requested, 0.0, minf(MAX_RANGE, budget_range))

static func clamp_width(index: int, requested: float, ranges: PackedFloat32Array,
		widths: PackedFloat32Array) -> float:
	var reach := ranges[index]
	if reach <= 0.0001:
		return clampf(requested, 0.0, MAX_WIDTH)
	var other_area := total_area(ranges, widths) - cone_area(reach, widths[index])
	var available := maxf(TOTAL_BUDGET - other_area, 0.0)
	var budget_width := 2.0 * atan(available / (reach * reach))
	return clampf(requested, 0.0, minf(MAX_WIDTH, budget_width))

static func direction_for_heading(heading: float) -> Vector2:
	return Vector2(-sin(heading), -cos(heading))

static func local_point(world_point: Vector3, body_transform: Transform3D) -> Vector2:
	var point := body_transform.affine_inverse() * world_point
	return Vector2(point.x, point.z)

static func point_in_zone(point: Vector2, zone_index: int, reach: float, width: float,
		tip_outward: bool = false) -> bool:
	if reach <= 0.0001 or width <= 0.0001:
		return false
	var center := direction_for_heading(ZONE_HEADINGS[zone_index])
	var longitudinal := point.dot(center)
	if longitudinal < 0.0 or longitudinal > reach:
		return false
	var lateral := absf(center.cross(point))
	var widening_distance := reach - longitudinal if tip_outward else longitudinal
	return lateral <= widening_distance * tan(width * 0.5) + 0.0001

static func handle_positions(index: int, reach: float, width: float,
		tip_outward: bool = false) -> Dictionary:
	var heading: float = ZONE_HEADINGS[index]
	var direction := direction_for_heading(heading)
	var perpendicular := Vector2(-direction.y, direction.x)
	var far_center := direction * reach
	var edge_center := Vector2.ZERO if tip_outward else far_center
	var half_base := reach * tan(width * 0.5)
	return {
		"range": far_center,
		"left": edge_center - perpendicular * half_base,
		"right": edge_center + perpendicular * half_base,
	}

static func editor_handle_positions(index: int, reach: float, width: float,
		tip_outward: bool = false) -> Dictionary:
	# Keep a recovery handle outside the Jeep even when the real cone is tiny.
	# This affects only editor presentation and picking, never combat geometry.
	return handle_positions(index, maxf(reach, MIN_EDITOR_HANDLE_DISTANCE), width, tip_outward)

static func width_from_handle(index: int, reach: float, point: Vector2) -> float:
	if reach <= 0.0001:
		return 0.0
	var direction := direction_for_heading(ZONE_HEADINGS[index])
	var lateral := absf(direction.cross(point))
	return clampf(2.0 * atan(lateral / reach), 0.0, MAX_WIDTH)
