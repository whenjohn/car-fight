extends RefCounted
## Simple jump course: a floor-level ramp launches north across a short gap
## onto a long elevated road, which connects to an east-west upper road.

const ROAD_SURFACE_Y := 3.5
const ROAD_THICKNESS := 0.5
const RAMP_LENGTH := 14.0
const RAMP_WIDTH := 8.0
const RAMP_ANGLE := asin(ROAD_SURFACE_Y / RAMP_LENGTH)
const RAMP_CENTER_Z := 16.0
const RAMP_CENTER_Y := ROAD_SURFACE_Y * 0.5 - ROAD_THICKNESS * 0.5 * cos(RAMP_ANGLE)


static func ground_body_y(radius: float) -> float:
	return radius + 0.04


static func camera_target(body_position: Vector3) -> Vector3:
	return Vector3(body_position.x, 0.0, body_position.z)


static func ramp() -> Dictionary:
	return {
		"name": "LaunchRamp",
		"size": Vector3(RAMP_WIDTH, ROAD_THICKNESS, RAMP_LENGTH),
		"position": Vector3(0.0, RAMP_CENTER_Y, RAMP_CENTER_Z),
		"rotation": Vector3(RAMP_ANGLE, 0.0, 0.0),
		"color": Color("68777c"),
	}


static func upper_roads() -> Array[Dictionary]:
	return [
		{
			"name": "UpperRoadNorth",
			"size": Vector3(8.0, ROAD_THICKNESS, 36.0),
			"position": Vector3(0.0, ROAD_SURFACE_Y - ROAD_THICKNESS * 0.5, -13.0),
			"rotation": Vector3.ZERO,
			"color": Color("596a70"),
		},
		{
			"name": "UpperRoadCross",
			"size": Vector3(36.0, ROAD_THICKNESS, 8.0),
			"position": Vector3(0.0, ROAD_SURFACE_Y - ROAD_THICKNESS * 0.5, -16.0),
			"rotation": Vector3.ZERO,
			"color": Color("53656b"),
		},
	]


static func supports() -> Array[Dictionary]:
	var height := ROAD_SURFACE_Y - ROAD_THICKNESS
	var y := height * 0.5
	return [
		{"name": "UpperSupportSouthWest", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(-3.2, y, 1.0), "color": Color("39484d")},
		{"name": "UpperSupportSouthEast", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(3.2, y, 1.0), "color": Color("39484d")},
		{"name": "UpperSupportMidWest", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(-3.2, y, -14.0), "color": Color("39484d")},
		{"name": "UpperSupportMidEast", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(3.2, y, -14.0), "color": Color("39484d")},
		{"name": "UpperSupportNorthWest", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(-3.2, y, -28.0), "color": Color("39484d")},
		{"name": "UpperSupportNorthEast", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(3.2, y, -28.0), "color": Color("39484d")},
		{"name": "CrossSupportWest", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(-15.0, y, -16.0), "color": Color("39484d")},
		{"name": "CrossSupportEast", "size": Vector3(0.7, height, 0.7),
			"position": Vector3(15.0, y, -16.0), "color": Color("39484d")},
	]
