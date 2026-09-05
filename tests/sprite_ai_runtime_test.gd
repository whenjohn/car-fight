extends SceneTree
var main
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.5).timeout
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 4, 1)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0, 1, -5)
	main.add_child(wall)
	await create_timer(0.15).timeout
	root.get_node("NetworkTime").stop()
	main._ramming_lab_enabled = true
	var lab = main._sprite_test_lab
	var ai = lab.ai
	lab.requested = false
	var car = main.local_player()
	car.freeze = true
	car.position = Vector3(10, 1, 0)
	car.linear_velocity = Vector3.ZERO
	# Compare consecutive movement sweeps against fresh query objects. Alternate
	# capsule sizes, origins, motions and exclusions to catch stale reused input.
	for size in [0.5, 2.0, 1.0]:
		lab.configure(true, 1, size, false)
		ai.configure("attacker", 3.0, 32.0, 1.0, false)
		var mover = lab._fixtures[0]
		for origin in [Vector3(10, 1, -10), Vector3(0, 1, -7), Vector3(0, 1, -5)]:
			for heading in [Vector3.BACK, Vector3.FORWARD]:
				for ignore_wall in [false, true]:
					mover.position = origin
					ai.pending.clear()
					ai.spacing.clear()
					var excluded: Array[RID] = main._combat_dynamic_rids()
					if ignore_wall:
						excluded.append(wall.get_rid())
					ai._excluded = excluded
					ai.routes[mover.target_id] = PackedVector3Array([origin + heading * 10.0])
					ai.brains[mover.target_id].decision = {
						"destination": origin + heading * 10.0, "speed": 4.5, "state": "pursue"}
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = mover.get_child(0).shape
					query.transform = Transform3D(Basis.IDENTITY, origin)
					query.motion = heading * 2.25
					query.collision_mask = 1
					query.exclude = excluded
					var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
					var expected: Vector3 = origin
					if space.intersect_shape(query, 1).is_empty():
						expected += query.motion * float(space.cast_motion(query)[0])
					_check(ai.move(mover, 0.5).is_equal_approx(expected),
						"movement matches fresh sweep across size, direction, overlap and exclusions")
	# Offline simulation still advances ticks, but remote-only snapshots have
	# no consumers. Configuration and local practice-shot events stay separate.
	lab.configure(true, 256, 1.0, false)
	ai.mode = "legacy"
	ai.metrics.max_payload = 0
	var messages_before: int = ai.metrics.messages
	var tick_before: int = lab._motion_tick
	for tick in 12:
		lab.service(1.0 / 60)
	_check(lab._motion_tick == tick_before + 12, "offline simulation keeps advancing")
	_check(lab._snapshot_clock < 0.1, "offline snapshot cadence stays bounded")
	_check(ai.metrics.messages == messages_before, "no motion serialization without recipients")
	_check(ai.metrics.max_payload == 0, "offline ticks do not pack motion payloads")
	for profile in ["basic", "attacker", "evader", "ambusher"]:
		lab.configure(true, 1, 1.0, false)
		ai.configure(profile, 3.0, 32.0, 1.0, false)
		var target = lab._fixtures[0]
		target.position = Vector3(10, 1, -15)
		target.home = target.position
		ai.reset()
		await physics_frame
		await physics_frame
		var velocity: Vector3 = car.linear_velocity
		var before: int = ai.metrics.hits
		for i in 180:
			lab.service(1.0 / 60)
		if profile == "ambusher":
			_check(ai.metrics.hits > before or ai.brains[target.target_id].cover != Vector3.INF,
				"ambusher shoots in open or selects real cover")
		else:
			_check(ai.metrics.hits > before, profile + " practice shots reach real car")
		_check(car.linear_velocity == velocity, "practice shots never apply impulses")
		_check(ai.suppress_auto_fire(), "AI playground suppresses auto fire")
		var shots_before: int = ai.metrics.shots
		lab.set_hits(target.target_id, 3)
		for i in 120:
			lab.service(1.0 / 60)
		_check(ai.metrics.shots == shots_before, "dead sprite cannot shoot")
		_check(ai.shots.is_empty(), "shots expire within lifetime")
	# Attacker acquisition is independent of detection distance and sight.
	lab.configure(true, 1, 1.0, false)
	ai.configure("attacker", 3.0, 8.0, 1.0, false)
	var hunter_target = lab._fixtures[0]
	hunter_target.position = Vector3(-8, 1, -32)
	hunter_target.home = hunter_target.position
	car.position = Vector3(-55, 1, -32)
	ai.reset()
	ai._excluded = main._combat_dynamic_rids()
	var hunter_state: Dictionary = ai.brains[hunter_target.target_id]
	var observed: Dictionary = ai._observe(hunter_target, hunter_state, ai._cars())
	_check(not observed.is_empty() and not observed.visible,
		"attacker acquires player beyond detection behind a real building")
	var hunter_nav = ai._navigation(hunter_target)
	hunter_nav.advance(30000)
	var start_distance: float = hunter_target.position.distance_to(car.position)
	for tick in 480:
		lab.service(1.0 / 60)
	_check(hunter_target.position.distance_to(hunter_target.home) > 5.0,
		"attacker actually routes away from home around the building")
	_check(hunter_state.target == int(car.name), "attacker retains its player beyond old three-second timeout")
	_check(hunter_target.position.distance_to(car.position) < start_distance,
		"continued pursuit closes distance around cover")
	car.set("is_cloaked", true)
	observed = ai._observe(hunter_target, hunter_state, ai._cars())
	_check(observed.is_empty(), "hunter still respects player cloak")
	car.set("is_cloaked", false)
	# A close pair spreads even while holding firing distance; distant hunters
	# remain unaffected. Separation must also resolve exact spawn overlaps.
	lab.configure(true, 3, 1.0, false)
	ai.configure("attacker", 3.0, 32.0, 1.0, false)
	var left = lab._fixtures[0]
	var right = lab._fixtures[1]
	var distant = lab._fixtures[2]
	left.position = Vector3(10, 1, 10)
	right.position = Vector3(10.3, 1, 10)
	distant.position = Vector3(20, 1, 10)
	ai._refresh_spacing()
	_check(ai.spacing[left.target_id].x < 0 and ai.spacing[right.target_id].x > 0,
		"crowded attackers steer apart")
	_check(ai.spacing[distant.target_id] == Vector3.ZERO, "spacing leaves loose group alone")
	ai.brains[left.target_id].decision = {"destination": left.position, "speed": 4.5, "state": "aim"}
	ai._excluded = main._combat_dynamic_rids()
	_check(ai.move(left, 1.0 / 60).x < left.position.x, "holding attacker still makes room")
	right.position = left.position
	ai._refresh_spacing()
	_check(ai.spacing[left.target_id].dot(ai.spacing[right.target_id]) < 0,
		"exact overlap gets opposing deterministic steering")
	right.health = 0
	ai._refresh_spacing()
	_check(ai.spacing[left.target_id] == Vector3.ZERO, "dead neighbors do not repel")
	ai.reset()
	_check(ai.spacing.is_empty(), "reset clears cached separation")
	lab.configure(true, 16, 1.0, false)
	ai.configure("attacker", 3.0, 32.0, 1.0, false)
	car.position = Vector3(10, 1, 16)
	for member in lab._fixtures:
		member.position = Vector3(10, 1, 10)
	ai.reset()
	for tick in 360:
		lab.service(1.0 / 60)
	var nearest_total := 0.0
	for member in lab._fixtures:
		var nearest := INF
		for other in lab._fixtures:
			if member != other:
				nearest = minf(nearest, member.position.distance_to(other.position))
		nearest_total += nearest
	_check(nearest_total / 16.0 > 1.0, "stacked pack spreads into separate hunters over time")
	# Real city cover, independent of mesh presentation and visual sizing.
	lab.configure(true, 1, 1.0, false)
	ai.configure("ambusher", 3.0, 48.0, 1.0, false)
	var target = lab._fixtures[0]
	target.position = Vector3(-8, 1, -32)
	target.home = target.position
	car.position = Vector3(-8, 1, -10)
	ai.reset()
	await physics_frame
	await physics_frame
	ai._excluded = main._combat_dynamic_rids()
	var brain: Dictionary = ai.brains[target.target_id]
	brain.car = {"id": 1, "position": car.position, "velocity": Vector3.ZERO, "visible": true}
	var nav = ai._navigation(target)
	nav.advance(30000)
	ai._find_cover(target, brain, nav)
	_check(brain.cover != Vector3.INF, "real building produces reachable ambush cover")
	if brain.cover != Vector3.INF:
		_check(not ai._visible(brain.cover, car.position), "cover is physically occluded")
		_check(ai._visible(brain.peek, car.position), "peek has a real firing line")
	# The wall, rather than the car behind it, ends the bullet.
	car.position = Vector3(0, 1, 0)
	await physics_frame
	await physics_frame
	var hits: int = ai.metrics.hits
	ai.shots.clear()
	ai.shots[999] = {"position": Vector3(0, 1, -10), "velocity": Vector3(0, 0, 22), "age": 0.0}
	ai.finish(0.6)
	print("SPRITE_AI_WALL_CHECK remaining=", ai.shots.has(999), " hits_before=", hits, " hits_after=", ai.metrics.hits,
		" visible=", ai._visible(Vector3(0, 1, -10), Vector3(0, 1, 0)))
	_check(not ai.shots.has(999) and ai.metrics.hits == hits, "wall stops practice shot before car")
	wall.free()
	# Actual extended motion payloads fit the budget; stale ticks/generations
	# cannot overwrite current state. The configuration stream commits atomically.
	lab.configure(true, 256, 2.0, false)
	var debug_set: Array = ai.debug_targets(Vector3.ZERO)
	_check(debug_set.size() == 16, "debug selection bounded at 256 sprites")
	var last_distance := -1.0
	for member in debug_set:
		var distance: float = member.position.distance_squared_to(Vector3.ZERO)
		_check(distance >= last_distance, "debug selection nearest first")
		last_distance = distance
	var states: Array = lab.states()
	for batch in ai.batches(states):
		_check(var_to_bytes([lab.generation, batch, 100]).size() <= 1000, "real motion payload byte limit")
		_check(var_to_bytes([[lab.generation, true, 256, 2.0, false, 1, 64], 0, batch]).size() <= 1000, "real configuration payload byte limit")
	target = lab._fixtures[0]
	var record: Array = states[0].duplicate()
	record[1] = Vector3(0, 1, 20)
	lab._sync_motion(lab.generation, [record], 20)
	_check(target.network_position == record[1], "new motion applied")
	record[1] = Vector3(0, 1, 30)
	lab._sync_motion(lab.generation, [record], 19)
	lab._sync_motion(lab.generation - 1, [record], 21)
	_check(target.network_position == Vector3(0, 1, 20), "old tick/generation rejected")
	var parts: Array = ai.batches(states)
	var original_generation: int = lab.generation
	var meta := [original_generation + 1, true, 256, 2.0, false, 1, parts.size()]
	for index in parts.size() - 1:
		lab._configuration_part(meta, index, parts[index])
		_check(lab.generation == original_generation, "partial configuration cannot replace membership")
	lab._configuration_part(meta, parts.size() - 1, parts[-1])
	_check(lab.generation == original_generation + 1 and lab.states().size() == 256, "complete configuration commits all AI members")
	lab.set_hits(10000, 3)
	for index in parts.size():
		lab._configuration_part(meta, index, parts[index])
	_check(lab._fixtures[0].health == 0, "duplicate configuration cannot revive a dead member")
	lab._configuration_part([], 0, [])
	lab._configuration_part([lab.generation + 1, true, 256, 2.0, false, 1, 257], 0, [])
	_check(lab.generation == original_generation + 1, "malformed configuration rejected")
	var spawn := ["spawn", 50000, Vector3.ZERO, Vector3.RIGHT, 0.0]
	ai._events_received(lab.generation, [spawn, spawn])
	_check(ai._present_shots.size() == 1, "duplicate spawn deduplicated")
	ai._events_received(lab.generation, [["end", 50000, Vector3.ZERO, Vector3.ZERO, 0.0]])
	ai._events_received(lab.generation, [spawn])
	_check(ai._present_shots.is_empty(), "old spawn cannot resurrect ended shot")
	lab.configure(false, 1, 1.0, false)
	_check(ai.shots.is_empty() and ai.pending.is_empty(), "disable clears pending work")
	_check(not ai.suppress_auto_fire(), "disable restores ordinary auto fire")
	_check(ai.metrics.max_jobs <= 4 and ai.metrics.max_pending <= 256, "CPU work bounds")
	if failures.is_empty():
		print("SPRITE_AI_RUNTIME_TEST PASS")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
