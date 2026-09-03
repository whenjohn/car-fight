extends RefCounted
## Deterministic configuration for the opt-in networked ramming range.
## Drones use ordinary player physics; only their input source and recovery are
## fixture-specific.

const CURSOR_DISTANCE := 7.35
const WAYPOINT_RADIUS := 3.0
const CORRIDOR_HALF_WIDTH := 12.0
const STALL_SPEED := 0.5
const STALL_RECOVERY_TIME := 2.0
const OVERTURNED_UP_DOT := 0.342 # cos(70 degrees)
const OVERTURNED_RECOVERY_TIME := 2.0
const OFF_COURSE_RECOVERY_TIME := 3.0
const CLEAR_ENDPOINT_DISTANCE := 8.0

const DRONES := [
	{
		"id": 2000002001,
		"lane_x": -6.0,
		"endpoints": [Vector2(-6.0, -52.0), Vector2(-6.0, 52.0)],
		"spawn_endpoint": 0,
		"target_endpoint": 1,
		"vehicle_index": 5, # Humvee M242: source-separated wheels.
		"model_scale": 1.5,
	},
	{
		"id": 2000002002,
		"lane_x": 0.0,
		"endpoints": [Vector2(0.0, -52.0), Vector2(0.0, 52.0)],
		"spawn_endpoint": 1,
		"target_endpoint": 0,
		"vehicle_index": 7, # Apocalypse Bus: bounded wheel extraction.
		"model_scale": 1.5,
	},
	{
		"id": 2000002003,
		"lane_x": 6.0,
		"endpoints": [Vector2(6.0, -52.0), Vector2(6.0, 52.0)],
		"spawn_endpoint": 0,
		"target_endpoint": 1,
		"vehicle_index": 10, # LP Car A03-1: wheels baked into the body.
		"model_scale": 1.5,
	},
]


static func drone_for_id(body_id: int) -> Dictionary:
	for drone in DRONES:
		if int(drone["id"]) == body_id:
			return drone
	return {}


static func endpoint(drone: Dictionary, endpoint_index: int) -> Vector2:
	var endpoints: Array = drone["endpoints"]
	return endpoints[clampi(endpoint_index, 0, endpoints.size() - 1)]


static func spawn_yaw(drone: Dictionary, endpoint_index: int) -> float:
	var other_index := 1 - clampi(endpoint_index, 0, 1)
	var direction := endpoint(drone, other_index) - endpoint(drone, endpoint_index)
	return atan2(-direction.x, -direction.y)


static func off_course(position: Vector3, drone: Dictionary) -> bool:
	return absf(position.x - float(drone["lane_x"])) > CORRIDOR_HALF_WIDTH


static func recovery_reason(stall_time: float, overturned_time: float,
		off_course_time: float, outside_city: bool) -> String:
	if outside_city:
		return "outside-city"
	if overturned_time >= OVERTURNED_RECOVERY_TIME:
		return "overturned"
	if stall_time >= STALL_RECOVERY_TIME:
		return "stalled"
	if off_course_time >= OFF_COURSE_RECOVERY_TIME:
		return "off-course"
	return ""


static func far_endpoint(drone: Dictionary, human_positions: Array[Vector3]) -> int:
	var best_index := -1
	var best_clearance := -INF
	for endpoint_index in range(2):
		var point := endpoint(drone, endpoint_index)
		var clearance := INF
		for position in human_positions:
			clearance = minf(clearance, Vector2(position.x, position.z).distance_to(point))
		if clearance > best_clearance:
			best_clearance = clearance
			best_index = endpoint_index
	return best_index if best_clearance >= CLEAR_ENDPOINT_DISTANCE else -1
