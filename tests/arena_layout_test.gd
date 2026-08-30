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
	if arena_half < 80.0:
		push_error("ARENA_LAYOUT_TEST FAIL: driving field must be at least 160 units wide")
		quit(1)
		return
	if float(arena_config.CAMERA_SIZE) < 40.0:
		push_error("ARENA_LAYOUT_TEST FAIL: camera must show the longer driving lines")
		quit(1)
		return
	var follow := load("res://player/follow_controller.gd")
	if follow == null or float(follow.MAX_DISTANCE) / float(arena_config.CAMERA_SIZE) < 0.45:
		push_error("ARENA_LAYOUT_TEST FAIL: wider camera must retain mouse control resolution")
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
	var proximity_objects: Array = layout_script.proximity_objects(arena_half)
	if proximity_objects.size() < 130 or proximity_objects.size() > 155:
		push_error("ARENA_LAYOUT_TEST FAIL: proximity landmark count is not bounded")
		quit(1)
		return
	for landmark in proximity_objects:
		var landmark_position: Vector3 = landmark["position"]
		if maxf(absf(landmark_position.x), absf(landmark_position.z)) >= arena_half - 10.0:
			push_error("ARENA_LAYOUT_TEST FAIL: proximity landmark reaches a wall")
			quit(1)
			return
	var target_layout := load("res://combat/target_layout.gd")
	var uses_outer_field := false
	for target_position in target_layout.positions():
		uses_outer_field = uses_outer_field or maxf(absf(target_position.x),
			absf(target_position.z)) >= 40.0
	if not uses_outer_field:
		push_error("ARENA_LAYOUT_TEST FAIL: targets must draw driving into the outer field")
		quit(1)
		return
	print("ARENA_LAYOUT_TEST PASS objects=%d" % obstacles.size())
	quit()
