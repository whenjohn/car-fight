extends RefCounted
## Small symmetric obstacle set. The center stays clear for all four spawns.

static func collision_objects() -> Array[Dictionary]:
	return [
		{
			"name": "BarrierNorthWest",
			"size": Vector3(8.0, 1.2, 1.4),
			"position": Vector3(-20.0, 0.6, -17.0),
			"yaw": deg_to_rad(25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BarrierNorthEast",
			"size": Vector3(1.4, 1.2, 8.0),
			"position": Vector3(20.0, 0.6, -17.0),
			"yaw": deg_to_rad(-25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BarrierSouthWest",
			"size": Vector3(1.4, 1.2, 8.0),
			"position": Vector3(-20.0, 0.6, 17.0),
			"yaw": deg_to_rad(-25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BarrierSouthEast",
			"size": Vector3(8.0, 1.2, 1.4),
			"position": Vector3(20.0, 0.6, 17.0),
			"yaw": deg_to_rad(25.0),
			"color": Color("6c665c"),
		},
		{
			"name": "BlockNorth",
			"size": Vector3(4.0, 2.4, 4.0),
			"position": Vector3(0.0, 1.2, -31.0),
			"yaw": deg_to_rad(12.0),
			"color": Color("56656b"),
		},
		{
			"name": "BlockSouth",
			"size": Vector3(4.0, 2.4, 4.0),
			"position": Vector3(-12.0, 1.2, 32.0),
			"yaw": deg_to_rad(-12.0),
			"color": Color("56656b"),
		},
	]


## Four landmark rows frame two broad, intersecting driving boulevards. They
## are static/seeded world objects: deterministic, network-free, and bounded.
static func proximity_objects(half_extent: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var spacing := 21
	var limit := floori((half_extent - 20.0) / spacing) * spacing
	for along in range(-limit, limit + 1, spacing):
		if abs(along) < 30:
			continue
		for side in [-1, 1]:
			result.append(_landmark("NorthSouth", side * 16.0, float(along),
				result.size()))
			# Leave the east boulevard open where it crosses the dedicated tree lane.
			if along < 75 or along > 126:
				result.append(_landmark("EastWest", float(along), side * 16.0,
					result.size()))
	result.append_array(tree_path_objects(half_extent))
	return result


## A deliberately dense, tall tree corridor on the east side of the arena.
## The 24-unit clear lane remains generous for cars while nine-unit tree
## spacing makes speed legible continuously instead of as isolated landmarks.
static func tree_path_objects(half_extent: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var end := mini(180, floori(half_extent - 30.0))
	for along in range(-end, end + 1, 9):
		if abs(along) < 13:
			continue
		for x in [88.0, 112.0]:
			result.append({
				"name": "TallTreePath%03d" % result.size(),
				"position": Vector3(x, 0.0, float(along)),
				"kind": "tree",
				"height_scale": 1.55,
				"crown_scale": 1.25,
			})
	return result


static func _landmark(route: String, x: float, z: float, index: int) -> Dictionary:
	return {
		"name": "Proximity%s%03d" % [route, index],
		"position": Vector3(x, 0.0, z),
		"kind": "tree" if index % 4 == 0 else "lamp",
	}
