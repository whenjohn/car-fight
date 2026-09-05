extends SceneTree
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.5).timeout
	root.get_node("NetworkTime").stop()
	main._ramming_lab_enabled = true
	var car = main.local_player()
	car.freeze = true
	car.position = Vector3(0, 1, 0)
	car.linear_velocity = Vector3.ZERO
	var lab = main._sprite_test_lab
	lab.requested = false
	var pop = lab.population
	_check(not pop.enabled, "ordinary lab does not enable population implicitly")
	lab.ai.mode = "attacker"
	_check(pop.set_enabled(true), "offline population accepted")
	_check(lab.count == 64 and pop.alive == 64 and pop.points.size() == 64,
		"explicit enable seeds 64 and caches bounded street spawners")
	lab._build_window()
	lab._process(0.0)
	var population_control: OptionButton
	for control in lab._host_controls:
		if control.get_meta("setting", "") == "Population (offline)":
			population_control = control
	_check(population_control != null and lab._status.text.contains("64 alive / 56–64"),
		"Sprite test exposes population control and live-count monitor")
	if population_control != null:
		population_control.item_selected.emit(0)
		_check(not pop.enabled, "UI off stops controller")
		population_control.item_selected.emit(1)
		_check(pop.enabled and pop.alive == 64, "UI on resets to working target")
	await physics_frame
	await physics_frame
	_check(not pop._clear(car.position), "spawn refuses nearby player")
	_check(not pop._clear(lab._fixtures[0].position), "spawn refuses living neighbor")
	# Real world collision, independent of the precomputed street layout.
	var clear_point := Vector3.INF
	for point in pop.points:
		if pop._clear(point):
			clear_point = point
			break
	_check(clear_point != Vector3.INF, "real city has a clear spawn point")
	if clear_point == Vector3.INF:
		_finish()
		return
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 4)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = clear_point
	main.add_child(wall)
	await physics_frame
	await physics_frame
	# NetworkTime.stop also stops the Rapier driver's manual space steps.
	RapierPhysicsServer3D.space_step(main.get_world_3d().space, 1.0 / 120.0)
	_check(not pop._clear(clear_point), "spawn capsule refuses actual obstacle")
	wall.free()
	await physics_frame
	# Losses within the band don't immediately replace each individual death.
	for index in 8:
		lab.set_hits(lab._fixtures[index].target_id, 3)
	pop.service(0.25)
	_check(pop.alive == 56 and pop.spawned == 0 and not pop.refilling, "56 holds without refill churn")
	var survivor = lab._fixtures[-1]
	var survivor_id: int = survivor.target_id
	lab.ai.brains[survivor_id].route_clock = 123.0
	lab.ai.routes[survivor_id] = PackedVector3Array([Vector3(1, 1, 1)])
	for index in range(8, 16):
		lab.set_hits(lab._fixtures[index].target_id, 3)
	var generation: int = lab.generation
	pop.service(0.25)
	_check(pop.alive == 49 and pop.spawned == 1 and pop.refilling, "one birth when population falls below band")
	var newborn = lab._fixtures[-1]
	_check(newborn.target_id == 10064 and newborn.ai_profile == "attacker", "fresh ID and current profile")
	_check(lab.generation == generation and lab.ai.brains[survivor_id].route_clock == 123.0 \
		and lab.ai.routes[survivor_id].size() == 1, "replacement preserves existing generation, brain and route")
	var before: int = pop.spawned
	pop.service(4.0)
	_check(pop.spawned - before <= 1, "slow frame cannot accumulate catch-up births")
	for tick in 100:
		var previous: int = pop.spawned
		pop.service(0.25)
		_check(pop.spawned - previous <= 1, "one birth per service interval")
		_check(pop.alive <= 64 and pop.corpses <= 16 and lab._fixtures.size() <= 80, "live and retained bounds")
	_check(pop.alive == 64 and not pop.refilling, "refill latches until 64 then stops")
	_check(pop.corpses == 0 and not lab.ai.brains.has(10000), "expired corpse and brain retired")
	# Churn bounded state over repeated waves; always remove recent replacements
	# so stationary fixtures don't occupy every fixed spawn point indefinitely.
	var last_id: int = lab._fixtures[-1].target_id
	for wave in 12:
		var killed := 0
		for index in range(lab._fixtures.size() - 1, -1, -1):
			var target = lab._fixtures[index]
			if target.health > 0:
				lab.set_hits(target.target_id, 3)
				killed += 1
				if killed == 20:
					break
		await physics_frame
		await physics_frame
		for tick in 100:
			pop.service(0.25)
			_check(lab._fixtures.size() <= 80 and pop.corpses <= 16 and pop.alive <= 64,
				"repeated waves stay bounded")
		_check(pop.alive == 64, "each wave reaches target")
		_check(lab._fixtures[-1].target_id > last_id, "replacement IDs never reused within generation")
		last_id = lab._fixtures[-1].target_id
		_check(lab.ai.brains.size() == 64 and pop._deaths.is_empty(), "no retained brain/death history across waves")
	# All points blocked: bounded attempts, no forced overlap or deferred burst.
	pop.points.assign([car.position])
	pop._cursor = 0
	for index in 12:
		lab.set_hits(lab._fixtures[index].target_id, 3)
	before = pop.spawned
	var blocked_before: int = pop.blocked
	pop.service(0.25)
	_check(pop.spawned == before and pop.blocked == blocked_before + 1, "blocked spawner waits safely")
	pop.set_enabled(false)
	pop.service(10.0)
	_check(pop.spawned == before, "off stops replacements")
	main._role = "client"
	_check(not pop.set_enabled(true) and not pop.enabled, "online role rejects local spawning")
	lab._process(0.0)
	_check(population_control == null or population_control.disabled, "online UI cannot enable controller")
	main._role = "offline"
	pop.set_enabled(true)
	main._role = "server"
	pop.service(0.25)
	_check(not pop.enabled, "role change stops active controller")
	main._role = "offline"
	pop.set_enabled(true)
	lab.ai.configure("evader", 3.0, 32.0, 1.0, false)
	lab.configure(true, 64, 2.0, true)
	_check(pop.enabled and pop.spawned == 0 and pop._deaths.is_empty(), "profile/size reset preserves population selection, clears history")
	_check(is_equal_approx(pop._query.shape.radius, lab._fixtures[0].radius()), "spawn clearance follows actual capsule size")
	for index in 10:
		lab.set_hits(lab._fixtures[index].target_id, 3)
	await physics_frame
	await physics_frame
	pop.service(0.25)
	_check(pop.spawned == 1 and lab._fixtures[-1].ai_profile == "evader" \
		and lab._fixtures[-1].body_scale == 2.0, "newborn inherits selected evader profile and size")
	before = pop.spawned
	for tick in 90:
		lab.service(1.0 / 60.0)
	_check(pop.spawned > before, "ordinary offline lab ticks service the population before snapshot early-out")
	_check(lab.ai.brains.has(lab._fixtures[-1].target_id), "newborns join ordinary AI service")
	lab.configure(true, 128, 1.0, true)
	_check(not pop.enabled, "manual larger-count benchmark turns controller off")
	pop.set_enabled(true)
	lab.configure(false, 64, 1.0, true)
	_check(not pop.enabled and pop.points.is_empty(), "disable clears controller")
	pop.set_enabled(true)
	lab.retire()
	_check(not pop.enabled and pop.points.is_empty() and pop._deaths.is_empty(), "retire clears controller state")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("SPRITE_POPULATION_TEST PASS")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
