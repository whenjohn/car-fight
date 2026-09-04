extends SceneTree
var failures: Array[String] = []
var main

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
	main._apply_area_targets(1, Vector3(0, 0.5, -17), 10.0, 0, false)
	_check(target.health == 2, "wall blocks area damage")
	wall.free()
	await create_timer(0.15).timeout
	main._apply_area_targets(1, Vector3(0, 0.5, -10), 1.0, 0, false)
	_check(target.health == 1, "area hit removes one health")
	_fire(Vector3(0, 1, -20), Vector3(0, 0, 20))
	_check(target.health == 0, "third hit kills")
	_check(main.homing_target_for(10000) == null, "dead target cannot be acquired")
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
