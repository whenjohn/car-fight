extends RefCounted
const CITY := preload("res://world/city_layout.gd")
const MAP := preload("res://world/map_layout.gd")
const CELL := 2.0
var radius := 0.35
var grid := AStarGrid2D.new()
var blocks: Array[Dictionary] = []
var ready := false
var _build_cursor := 0

func setup(capsule_radius: float, incremental: bool = false) -> void:
	radius = capsule_radius
	blocks.clear()
	for building in CITY.BUILDINGS:
		blocks.append({"center": building.position * CITY.SCALE,
			"half": building.footprint * CITY.SCALE * 0.5,
			"yaw": deg_to_rad(float(building.yaw))})
	var edge := int(MAP.CITY_HALF_EXTENT / CELL)
	grid.region = Rect2i(-edge, -edge, edge * 2 + 1, edge * 2 + 1)
	grid.cell_size = Vector2.ONE * CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	_build_cursor = 0
	ready = false
	if not incremental:
		advance(grid.region.size.x * grid.region.size.y)

func advance(cells: int = 512) -> void:
	var width := grid.region.size.x
	var total := width * grid.region.size.y
	var finish := mini(_build_cursor + cells, total)
	while _build_cursor < finish:
		var x := grid.region.position.x + _build_cursor % width
		var z := grid.region.position.y + _build_cursor / width
		# Half a cell diagonal provides conservative edge/corner clearance.
		grid.set_point_solid(Vector2i(x, z), not clear(Vector3(x * CELL, 0, z * CELL), CELL * 0.71))
		_build_cursor += 1
	ready = _build_cursor == total

func clear(point: Vector3, extra: float = 0.0) -> bool:
	if maxf(absf(point.x), absf(point.z)) >= MAP.CITY_HALF_EXTENT - radius - extra - 1.0:
		return false
	for block in blocks:
		var relative := (point - Vector3(block.center)).rotated(Vector3.UP, -block.yaw)
		if absf(relative.x) <= block.half.x + radius + extra \
				and absf(relative.z) <= block.half.y + radius + extra:
			return false
	return true

func cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not ready:
		return PackedVector3Array()
	var start := _nearest(cell(from))
	var finish := _nearest(cell(to))
	if start == Vector2i(9999, 9999) or finish == Vector2i(9999, 9999):
		return PackedVector3Array()
	var result := PackedVector3Array()
	for point in grid.get_point_path(start, finish):
		result.append(Vector3(point.x, from.y, point.y))
	return result

func _nearest(origin: Vector2i) -> Vector2i:
	for ring in 4:
		for x in range(-ring, ring + 1):
			for y in range(-ring, ring + 1):
				var point := origin + Vector2i(x, y)
				if grid.is_in_boundsv(point) and not grid.is_point_solid(point):
					return point
	return Vector2i(9999, 9999)

func cover_candidates(from: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for block in blocks:
		var half: Vector2 = block.half
		var margin := radius + 2.0
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				# One point along each face near a shared corner. Each can be
				# cover or peek depending on which side the observer occupies.
				var a := Vector3(x * (half.x + margin), 0, z * maxf(0, half.y - 2.0))
				var b := Vector3(x * maxf(0, half.x - 2.0), 0, z * (half.y + margin))
				a = Vector3(block.center) + a.rotated(Vector3.UP, block.yaw)
				b = Vector3(block.center) + b.rotated(Vector3.UP, block.yaw)
				a.y = from.y
				b.y = from.y
				if from.distance_to(a) <= 32.0 and clear(a) and clear(b):
					result.append({"cover": a, "peek": b})
					result.append({"cover": b, "peek": a})
	return result
