extends SceneTree
var main
var role := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sprite-network-role="):
			role = arg.get_slice("=", 1)
	call_deferred("_run")

func _wait(predicate: Callable, seconds: float = 25.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			return false
		await create_timer(0.05).timeout
	return true

func _scene() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._ramming_lab_enabled = true

func _run() -> void:
	_scene()
	var lab = main._sprite_test_lab
	if not await _wait(func(): return lab.enabled and lab.generation > 0):
		_fail("fixture did not become ready")
		return
	if role == "server":
		if not await _wait(func(): return main.multiplayer.get_peers().size() == 2):
			_fail("two clients did not join")
			return
		# Matched scenario: same stationary cars, count and timing. Record
		# application bytes separately from actual encrypted transport traffic.
		for amount in [16, 64, 256]:
			for mode in ["legacy", "mixed"]:
				lab.configure(true, amount, 1.0, true)
				lab.ai.configure(mode, 3.0, 32.0, 1.0, false)
				await create_timer(0.5).timeout
				var before: Dictionary = lab.ai.metrics.duplicate()
				await create_timer(2.0).timeout
				var after: Dictionary = lab.ai.metrics
				print("SPRITE_AI_NETWORK_COST mode=%s count=%d peers=2 seconds=2 bytes=%d messages=%d decision_us=%d shots=%d max_payload=%d max_jobs=%d" % [
					mode, amount, after.bytes - before.bytes, after.messages - before.messages,
					after.cpu_us - before.cpu_us, after.shots - before.shots, after.max_payload, after.max_jobs])
		var old_owner: int = lab.owner_id
		if not await _wait(func(): return lab.owner_id != old_owner):
			_fail("owner departure did not transfer controls")
			return
		if not await _wait(func(): return lab.ai.mode == "basic" and lab.count == 64):
			_fail("new owner could not configure AI")
			return
		var remaining: int = lab.owner_id
		if not await _wait(func(): return not main.multiplayer.get_peers().has(remaining)):
			_fail("observer did not disconnect")
			return
		if not await _wait(func(): return lab.enabled and main.multiplayer.get_peers().size() == 1):
			_fail("same-process rejoin did not restore fixture")
			return
		await create_timer(2.0).timeout
		if lab.ai.metrics.max_payload > 1000 or lab.ai.metrics.max_jobs > 4:
			_fail("bounded work/payload contract exceeded")
			return
		lab.configure(false, 64, 1.0, false)
		await create_timer(0.4).timeout
	elif role == "owner":
		if not await _wait(func(): return lab.count == 256 and lab.ai.mode == "mixed"):
			_fail("maximum AI population never replicated")
			return
		await create_timer(3.0).timeout
		if lab.states().size() != 256 or lab.ai.metrics.shots == 0:
			_fail("AI membership or shot events missing")
			return
	else:
		# A non-owner must not reset, resize or disable the family.
		var original_owner: int = lab.owner_id
		lab.ai.configure("evader", 8.0, 48.0, 0.5, true)
		await create_timer(0.2).timeout
		if lab.ai.mode == "evader":
			_fail("non-owner changed AI settings")
			return
		if not await _wait(func(): return lab.owner_id != original_owner):
			_fail("owner transfer was not replicated")
			return
		lab.configure(true, 64, 1.0, true)
		lab.ai.configure("basic", 3.0, 32.0, 1.0, false)
		if not await _wait(func(): return lab.ai.mode == "basic" and lab.count == 64):
			_fail("new owner configuration rejected")
			return
		await create_timer(0.5).timeout
		# Reconnect within this engine process, rebuilding the session scene.
		# This is explicitly not a claim of in-place UI/browser recovery.
		root.get_node("NetworkTime").stop()
		var peer: MultiplayerPeer = main.multiplayer.multiplayer_peer
		peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		main.queue_free()
		await process_frame
		await create_timer(1.0).timeout
		_scene()
		lab = main._sprite_test_lab
		if not await _wait(func(): return lab.enabled and lab.ai.mode == "basic" and lab.count == 64):
			_fail("same-process rejoin state missing")
			return
		if not await _wait(func(): return not lab.enabled):
			_fail("final disable not replicated")
			return
	print("SPRITE_AI_NETWORK PASS role=" + role)
	quit()

func _fail(message: String) -> void:
	push_error("SPRITE_AI_NETWORK FAIL " + role + ": " + message)
	quit(1)
