extends SceneTree
var failures: Array[String] = []
var main
const COVERAGE := preload("res://combat/coverage_config.gd")
const TARGETING := preload("res://combat/auto_targeting.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.5).timeout
	# Disable unrelated automatic combat while exercising the real combat path.
	main._ramming_lab_enabled = true
	var lab = main._sprite_test_lab
	lab.requested = false
	lab.configure(true, 1, 1.0, false)
	var target = main._targets.get_node("Target_10000")
	target.position = Vector3(0, 1, -10)
	await physics_frame
	await physics_frame
	var shooter := RigidBody3D.new()
	shooter.freeze = true
	main.add_child(shooter)
	shooter.position = Vector3(0, 1, -20)
	_check(main._acquire_target(shooter, 2, 12.0, 0.1, false) == target,
		"automatic acquisition sees live sprite before wall")
	_fire(Vector3(0, 1, -20), Vector3(0, 0, 20))
	_check(target.health == 2, "real projectile consumes one health")
	_check(main._server_bolts.is_empty(), "projectile consumed")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 1)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0, 1, -15)
	main.add_child(wall)
	await create_timer(0.15).timeout
	_fire(Vector3(0, 1, -20), Vector3(0, 0, 20))
	_check(target.health == 2, "wall blocks projectile before capsule")
	_check(main._acquire_target(shooter, 2, 12.0, 0.1, false) != target,
		"real wall blocks automatic acquisition")
	main._apply_area_targets(1, Vector3(0, 0.5, -17), 10.0, 0, false)
	_check(target.health == 2, "wall blocks area damage")
	wall.free()
	await create_timer(0.15).timeout
	main._apply_area_targets(1, Vector3(0, 0.5, -10), 1.0, 0, false)
	_check(target.health == 1, "area hit removes one health")
	_fire(Vector3(0, 1, -20), Vector3(0, 0, 20))
	_check(target.health == 0, "third hit kills")
	_check(main.homing_target_for(10000) == null, "dead target cannot be acquired")
	_check(main._acquire_target(shooter, 2, 12.0, 0.1, false) != target,
		"automatic acquisition excludes killed sprite")
	shooter.free()
	lab.configure(true, 1, 1.0, false)
	target = main._targets.get_node("Target_10000")
	_check(target.health == 3, "reset restores health")
	var car = main.local_player()
	var car_shape: CollisionShape3D = car.get_node("Collision")
	target.position = car_shape.global_position
	var velocity: Vector3 = car.linear_velocity
	lab.service(0.016)
	_check(target.health == 0, "real vehicle contact kills target")
	_check(car.linear_velocity == velocity, "run-over applies no vehicle impulse")
	for amount in [16, 64, 128, 256]:
		lab.configure(true, amount, 1.0, false)
		_check(lab.states().size() == amount, "bounded fixture count")
	lab.configure(true, 256, 1.0, true)
	await physics_frame
	await physics_frame
	_profile_acquisition(car)
	lab.configure(false, 1, 1.0, false)
	_check(lab.states().is_empty(), "disable clears fixtures")
	if failures.is_empty():
		print("SPRITE_COMBAT_TEST PASS")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _fire(position: Vector3, velocity: Vector3) -> void:
	main._server_bolts.clear()
	main._server_bolts[900001] = {"position": position, "velocity": velocity,
		"age": 0.0, "shooter": 1, "zone": 0, "kind": main.BOLT_KIND_PLAYER}
	main._step_server_bolts(1.0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

# Matched CPU-only comparison in the real 256-fixture physics world. No frame
# or GPU claims: both implementations see identical frozen simulation state.
func _profile_acquisition(car: RigidBody3D) -> void:
	var old_times: Array[int] = []
	var new_times: Array[int] = []
	for sample in range(22):
		var expected: Array[Node3D] = []
		var started := Time.get_ticks_usec()
		for zone in range(4):
			expected.append(_eager_acquire(car, zone))
		var old_us := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		for zone in range(4):
			_check(main._acquire_target(car, zone, 8.0, PI / 2, false) == expected[zone],
				"256-fixture real-ray selection matches eager baseline")
		var new_us := Time.get_ticks_usec() - started
		if sample >= 2:
			old_times.append(old_us)
			new_times.append(new_us)
	old_times.sort()
	new_times.sort()
	print("ACQUISITION_CPU_PROFILE fixtures=256 samples=20 zones=4 old_median_us=%d new_median_us=%d old_p95_us=%d new_p95_us=%d" % [
		old_times[10], new_times[10], old_times[19], new_times[19]])

func _eager_acquire(car: RigidBody3D, zone: int) -> Node3D:
	var candidates: Array[Dictionary] = []
	var nodes: Array[Node3D] = []
	for container in [main._targets, main._balls]:
		for child in container.get_children():
			var target: Node3D
			if container == main._targets:
				target = child as StaticBody3D
				if not main._combat_target_active(target):
					continue
			else:
				target = child as RigidBody3D
				if target == null:
					continue
			candidates.append({"id": nodes.size(),
				"local_position": COVERAGE.local_point(target.global_position, car.global_transform),
				"visible": main._has_target_line_of_sight(car, target)})
			nodes.append(target)
	var selected := TARGETING.select_nearest(zone, 8.0, PI / 2, false, candidates)
	return nodes[selected] if selected >= 0 else null
