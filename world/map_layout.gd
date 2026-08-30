extends RefCounted
## Explicit world spaces. An entity belongs to a map; gameplay must not infer
## membership from a large world coordinate.

const ARENA := 0
const DRIVING_COURSE := 1
const CITY_AUDITION := 2

const COURSE_CENTER := Vector3(560.0, 0.0, 0.0)
const COURSE_HALF_EXTENT := 120.0
const CITY_CENTER := Vector3(0.0, 0.0, 600.0)
const CITY_HALF_EXTENT := 110.0
const GATE_HALF_SIZE := 7.5
const GATE_COOLDOWN := 1.25

const ARENA_GATE := Vector3(68.0, 0.0, 66.0)
const ARENA_LANDING := Vector3(57.0, 0.0, 57.0)
const COURSE_GATE_LOCAL := Vector3(-108.0, 0.0, 100.0)
const COURSE_START_LOCAL := Vector3(-100.0, 0.0, 60.0)
const ARENA_CITY_GATE := Vector3(-68.0, 0.0, 66.0)
const CITY_GATE_LOCAL := Vector3(-94.0, 0.0, 92.0)
const CITY_START_LOCAL := Vector3(-42.0, 0.0, 80.0)


static func map_name(map_id: int) -> String:
	match map_id:
		DRIVING_COURSE:
			return "DRIVING COURSE"
		CITY_AUDITION:
			return "LOW POLY CITY"
		_:
			return "ARENA"


static func course_gate() -> Vector3:
	return COURSE_CENTER + COURSE_GATE_LOCAL


static func course_start() -> Vector3:
	return COURSE_CENTER + COURSE_START_LOCAL


static func city_gate() -> Vector3:
	return CITY_CENTER + CITY_GATE_LOCAL


static func city_start() -> Vector3:
	return CITY_CENTER + CITY_START_LOCAL


static func gates() -> Array[Dictionary]:
	return [
		{"map_id": ARENA, "position": ARENA_GATE, "label": "DRIVING COURSE",
			"target_map_id": DRIVING_COURSE, "landing": course_start(), "yaw": -PI * 0.5},
		{"map_id": DRIVING_COURSE, "position": course_gate(), "label": "RETURN TO ARENA",
			"target_map_id": ARENA, "landing": ARENA_LANDING, "yaw": PI * 0.25},
		{"map_id": ARENA, "position": ARENA_CITY_GATE, "label": "LOW POLY CITY",
			"target_map_id": CITY_AUDITION, "landing": city_start(), "yaw": 0.0},
		{"map_id": CITY_AUDITION, "position": city_gate(), "label": "RETURN TO ARENA",
			"target_map_id": ARENA, "landing": ARENA_LANDING, "yaw": PI * 0.25},
	]


static func gate_index_at(map_id: int, position: Vector3) -> int:
	for index in range(gates().size()):
		var gate: Dictionary = gates()[index]
		if int(gate["map_id"]) != map_id:
			continue
		var delta: Vector3 = position - (gate["position"] as Vector3)
		if absf(delta.x) <= GATE_HALF_SIZE and absf(delta.z) <= GATE_HALF_SIZE:
			return index
	return -1


## Deterministic two-way transit. Y is supplied by the caller because the
## rigid body owns its exact suspension height.
static func transition(map_id: int, position: Vector3, body_y: float) -> Dictionary:
	var gate := gate_index_at(map_id, position)
	if gate < 0:
		return {}
	var gate_data: Dictionary = gates()[gate]
	var landing: Vector3 = gate_data["landing"]
	landing.y = body_y
	return {"map_id": int(gate_data["target_map_id"]), "position": landing,
		"yaw": float(gate_data["yaw"])}
