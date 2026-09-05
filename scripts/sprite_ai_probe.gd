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
	for amount in [16, 64, 256]:
		for mode in (["legacy", "mixed"] if lab.get("ai") != null else ["legacy"]):
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
