extends SceneTree
var main
var role := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sprite-network-role="):
			role = arg.get_slice("=", 1)
	call_deferred("_run")

func _wait_until(predicate: Callable, seconds: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			return false
		await create_timer(0.05).timeout
	return true

func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._ramming_lab_enabled = true
	var lab = main._sprite_test_lab
	if role == "server":
		if not await _wait_until(func(): return lab.enabled):
			_fail("initial host did not connect")
			return
		lab.configure(true, 256, 1.0, false)
		await create_timer(1.0).timeout
		lab.set_hits(10000, 1)
		await create_timer(1.0).timeout
		lab.set_hits(10000, 3)
		if not await _wait_until(func(): return main._players.get_child_count() >= 2):
			_fail("late observer did not join")
			return
		await create_timer(1.5).timeout
		if not lab.enabled or lab.count != 256:
			_fail("non-owner changed server configuration")
			return
		lab.configure(false, 1, 1.0, false)
		await create_timer(0.5).timeout
	else:
		if not await _wait_until(func(): return lab.generation >= 2):
			_fail("configuration snapshot missing")
			return
		var target = main._targets.get_node_or_null("Target_10000")
		if target == null or lab.count != 256 or lab.states().size() != 256:
			_fail("wrong target snapshot")
			return
		if role == "owner":
			if not await _wait_until(func(): return target.health == 2):
				_fail("confirmed hit not replicated")
				return
			if not await _wait_until(func(): return target.health == 0):
				_fail("confirmed death not replicated")
				return
		else:
			if target.health != 0 or target.collision_layer != 0:
				_fail("late join did not receive dead state")
				return
			lab.configure(false, 64, 2.0, true)
		if not await _wait_until(func(): return not lab.enabled):
			_fail("host disable not replicated")
			return
	print("SPRITE_NETWORK_FIXTURE PASS role=" + role)
	quit()

func _fail(message: String) -> void:
	push_error("SPRITE_NETWORK_FIXTURE FAIL " + role + ": " + message)
	quit(1)
