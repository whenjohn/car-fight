extends SceneTree

const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const ARENA_CONFIG_PATH := "res://world/arena_config.gd"
const SPAWNS := [
	Vector2(-3.0, 0.0), Vector2(3.0, 0.0),
	Vector2(0.0, -3.0), Vector2(0.0, 3.0),
]

func _init() -> void:
	var arena_config := load(ARENA_CONFIG_PATH)
	if arena_config == null:
		push_error("ARENA_LAYOUT_TEST FAIL: shared arena dimensions are missing")
		quit(1)
		return
	var arena_half: float = float(arena_config.HALF_EXTENT)
	if arena_half < 60.0:
		push_error("ARENA_LAYOUT_TEST FAIL: expanded field must be at least 120 units wide")
		quit(1)
		return
	if float(arena_config.WALL_HEIGHT) < VEHICLE_CONFIG.COLLISION_RADIUS * 2.0:
		push_error("ARENA_LAYOUT_TEST FAIL: boundary walls must contain the vehicle collider")
		quit(1)
		return
	var layout_script := load("res://world/arena_layout.gd")
	if layout_script == null:
		push_error("ARENA_LAYOUT_TEST FAIL: collision-object layout is missing")
		quit(1)
		return
	var obstacles: Array = layout_script.collision_objects()
	if obstacles.size() < 6:
		push_error("ARENA_LAYOUT_TEST FAIL: expected at least 6 collision objects")
		quit(1)
		return
	var names := {}
	for obstacle in obstacles:
		var obstacle_name := str(obstacle["name"])
		var size: Vector3 = obstacle["size"]
		var position: Vector3 = obstacle["position"]
		if names.has(obstacle_name) or minf(size.x, minf(size.y, size.z)) <= 0.0:
			push_error("ARENA_LAYOUT_TEST FAIL: duplicate or invalid obstacle %s" % obstacle_name)
			quit(1)
			return
		names[obstacle_name] = true
		var footprint := Vector2(size.x, size.z).length() * 0.5
		if maxf(absf(position.x), absf(position.z)) + footprint >= arena_half:
			push_error("ARENA_LAYOUT_TEST FAIL: %s reaches outside the arena" % obstacle_name)
			quit(1)
			return
		for spawn in SPAWNS:
			if Vector2(position.x, position.z).distance_to(spawn) <= footprint + VEHICLE_CONFIG.COLLISION_RADIUS + 2.0:
				push_error("ARENA_LAYOUT_TEST FAIL: %s blocks a spawn" % obstacle_name)
				quit(1)
				return
	print("ARENA_LAYOUT_TEST PASS objects=%d" % obstacles.size())
	quit()
