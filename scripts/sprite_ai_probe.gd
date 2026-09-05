extends SceneTree
## Matched headless service CPU/application-payload probe, not rendered FPS.
var main

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.5).timeout
	main._ramming_lab_enabled = true
	var lab = main._sprite_test_lab
	lab.requested = false
	var car = main.local_player()
	car.freeze = true
	car.position = Vector3(0, 1, 0)
	if OS.get_environment("CAR_FIGHT_AI_PROBE_SCENARIO") == "cover":
		_cover_probe(lab, car)
		quit()
		return
	var selected := OS.get_environment("CAR_FIGHT_AI_PROBE_MODE")
	if selected not in ["mixed", "attacker"]:
		selected = "mixed"
	for amount in [16, 64, 256]:
		for mode in (["legacy", selected] if lab.get("ai") != null else ["legacy"]):
			lab.configure(true, amount, 1.0, true)
			if lab.get("ai") != null:
				lab.ai.configure(mode, 3.0, 32.0, 1.0, false)
			await physics_frame
			var samples: Array[int] = []
			var warmup_max := 0
			for tick in 720:
				var start := Time.get_ticks_usec()
				lab.service(1.0 / 60.0)
				if tick >= 120:
					samples.append(Time.get_ticks_usec() - start)
				else:
					warmup_max = maxi(warmup_max, Time.get_ticks_usec() - start)
			samples.sort()
			print("SPRITE_AI_PROBE mode=%s count=%d samples=600 median_us=%d p95_us=%d max_us=%d warmup_max_us=%d snapshot_bytes=%d" % [
				mode, amount, samples[300], samples[570], samples.back(), warmup_max, var_to_bytes(lab.states()).size()])
			if lab.get("ai") != null:
				print("SPRITE_AI_COST ", JSON.stringify(lab.ai.metrics))
	lab.configure(false, 1, 1.0, false)
	quit()

func _cover_probe(lab, car) -> void:
	# Same 64-sprite workload before/after cover changes. Simulation CPU only.
	root.get_node("NetworkTime").stop()
	car.position = Vector3(-63, 1, 0)
	car.linear_velocity = Vector3.ZERO
	lab.configure(true, 64, 1.0, true)
	lab.ai.configure("ambusher", 3.0, 32.0, 1.0, false)
	var corners := [Vector3(-63, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, -63), Vector3(-63, 1, -63)]
	for phase in ["prepare", "circle", "grass_pass"]:
		var samples: Array[int] = []
		var prevented_deaths := 0
		for tick in 1800:
			if phase == "circle":
				var along := fmod(tick * 10.0 / 60.0, 252.0)
				var edge := int(along / 63.0)
				var direction: Vector3 = (corners[(edge + 1) % 4] - corners[edge]).normalized()
				car.position = corners[edge] + direction * fmod(along, 63.0)
				car.linear_velocity = direction * 10.0
				car.rotation.y = atan2(-direction.x, -direction.z)
			elif phase == "grass_pass":
				# Repeated passes through the real grass, including actual rushes,
				# shots and run-over work. The original two phases stay comparable.
				var along := fmod(tick * 10.0 / 60.0, 80.0)
				var direction := Vector3.RIGHT if along < 40.0 else Vector3.LEFT
				car.position = Vector3(40.0 + (along if along < 40.0 else 80.0 - along), 1, 10)
				car.linear_velocity = direction * 10.0
				car.rotation.y = atan2(-direction.x, -direction.z)
			var start := Time.get_ticks_usec()
			lab.service(1.0 / 60.0)
			samples.append(Time.get_ticks_usec() - start)
			# Diagnostic only: every next measured tick has 64 living sprites.
			# Keep contact calculation; restore deaths outside the CPU timer.
			for target in lab._fixtures:
				if target.health <= 0:
					target.set_hit_count(0)
					prevented_deaths += 1
		var alive := 0
		for target in lab._fixtures:
			alive += int(target.health > 0)
		samples.sort()
		print("COVER_CPU phase=%s ticks=1800 alive=%d median_us=%d p95_us=%d max_us=%d jobs=%d prevented_deaths=%d" % [
			phase, alive, samples[900], samples[1710], samples.back(), lab.ai.metrics.jobs, prevented_deaths])
	print("COVER_CPU_METRICS ", JSON.stringify(lab.ai.metrics))
