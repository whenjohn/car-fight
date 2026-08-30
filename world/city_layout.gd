extends RefCounted
## Deterministic city-block composition shared by local art extraction and the
## simple gameplay collision proxies. Imported meshes remain visual-only.

const STREET_LINES := [-42.0, 0.0, 42.0]
const CONNECTOR_CENTERS := [-31.0, -21.0, -11.0, 11.0, 21.0, 31.0]

const BUILDINGS := [
	{"model": "house_01", "position": Vector3(-21, 0, -21), "yaw": 90.0,
		"footprint": Vector2(15, 23), "height": 7.6},
	{"model": "house_02", "position": Vector3(-21, 0, 21), "yaw": 90.0,
		"footprint": Vector2(14, 14), "height": 6.9},
	{"model": "house_03", "position": Vector3(21, 0, -21), "yaw": -90.0,
		"footprint": Vector2(14, 19), "height": 6.7},
	{"model": "house_04", "position": Vector3(21, 0, 21), "yaw": -90.0,
		"footprint": Vector2(14, 14), "height": 7.0},
	{"model": "house_05", "position": Vector3(0, 0, 68), "yaw": 0.0,
		"footprint": Vector2(14, 14), "height": 11.1},
	{"model": "caffeeshop", "position": Vector3(-22, 0, -63), "yaw": 0.0,
		"footprint": Vector2(4.5, 4.0), "height": 5.3},
	{"model": "fruitshop", "position": Vector3(0, 0, -63), "yaw": 0.0,
		"footprint": Vector2(4.2, 4.0), "height": 6.3},
	{"model": "musicshop", "position": Vector3(22, 0, -63), "yaw": 0.0,
		"footprint": Vector2(9.0, 14.0), "height": 16.7},
	{"model": "highlivingbuilding_c", "position": Vector3(-69, 0, 22), "yaw": 0.0,
		"footprint": Vector2(23, 38), "height": 31.4},
	{"model": "highlivingbuilding_d", "position": Vector3(69, 0, 22), "yaw": 0.0,
		"footprint": Vector2(14, 28), "height": 24.2},
	{"model": "skyscraper_b", "position": Vector3(-70, 0, -68), "yaw": 8.0,
		"footprint": Vector2(29, 34), "height": 37.3},
	{"model": "skyscraper_c", "position": Vector3(70, 0, -68), "yaw": -8.0,
		"footprint": Vector2(48, 29), "height": 51.0},
	{"model": "gasstation_a", "position": Vector3(72, 0, -14), "yaw": 0.0,
		"footprint": Vector2(48, 28), "height": 7.3},
	{"model": "factorybuilding_a", "position": Vector3(-70, 0, -14), "yaw": 0.0,
		"footprint": Vector2(25, 27), "height": 21.5},
]


static func roads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for x in STREET_LINES:
		for z in STREET_LINES:
			result.append({"model": "road_a_13", "position": Vector3(x, 0.01, z),
				"yaw": 0.0})
	for z in STREET_LINES:
		for x in CONNECTOR_CENTERS:
			result.append({"model": "road_a_02", "position": Vector3(x, 0.01, z),
				"yaw": 90.0})
	for x in STREET_LINES:
		for z in CONNECTOR_CENTERS:
			result.append({"model": "road_a_02", "position": Vector3(x, 0.01, z),
				"yaw": 0.0})
	# A continuous entrance avenue takes the arrival point into the southwest
	# corner of the grid without crossing a building footprint.
	for z in [53.0, 63.0, 73.0, 83.0]:
		result.append({"model": "road_a_02", "position": Vector3(-42, 0.01, z),
			"yaw": 0.0})
	return result


static func pieces() -> Array[Dictionary]:
	var result := roads()
	for building in BUILDINGS:
		result.append(building)
	return result
