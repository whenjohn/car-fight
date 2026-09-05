extends Node
## Explicit offline-only monitored drawing A/B. No simulation optimization.
func run(lab, main) -> void:
	if lab.batch == null or lab._sample not in ["survivor", "thug"]:
		push_error("BATCH_PROFILE requires rendered offline play with survivor or thug art")
		get_tree().quit(1)
		return
	await get_tree().create_timer(3.0).timeout
	var car = main.local_player()
	car.freeze = true
	car.position = Vector3(0, 1, 0)
	car.linear_velocity = Vector3.ZERO
	main._ramming_lab_enabled = true
	lab.requested = false
	var output := "res://.crash-runs/sprite-batch-%d" % Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(output)
	var results: Array = []
	var phases := [] if OS.get_environment("CAR_FIGHT_BATCH_VISUAL_ONLY") == "1" else ["original", "batch", "original_repeat", "batch_repeat"]
	if OS.get_environment("CAR_FIGHT_BATCH_PERF_ONLY") == "1":
		phases = ["batch", "batch_repeat"]
	for phase in phases:
		lab.configure(true, 256, 1.0, true)
		lab.ai.configure("attacker", 3.0, 32.0, 1.0, false)
		lab.ai.show_debug = false
		lab.batch.enabled = phase.begins_with("batch")
		print("BATCH_PROFILE_PHASE ", phase)
		await get_tree().create_timer(15.0).timeout
		var samples: Array[float] = []
		var finish := Time.get_ticks_msec() + 6000
		var previous := Time.get_ticks_usec()
		while Time.get_ticks_msec() < finish:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0)
			previous = now
		samples.sort()
		var alive := 0
		for target in lab._fixtures:
			alive += int(target.health > 0)
		var record := {"phase": phase, "frames": samples.size(), "median_ms": samples[samples.size()/2],
			"p95_ms": samples[int(samples.size()*0.95)], "alive": alive, "batched": lab.batch.drawn,
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		results.append(record)
		print("BATCH_PROFILE_RESULT ", JSON.stringify(record))
		FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	if OS.get_environment("CAR_FIGHT_BATCH_PERF_ONLY") == "1":
		print("BATCH_PROFILE_COMPLETE captures=", output)
		get_tree().quit()
		return
	# Match native animation and uploaded transform/frame data on real GLES.
	get_node("/root/NetworkTime").stop()
	# Offline service can continue outside NetworkTime. Explicitly hold motion
	# and presentation intent so the paired pictures use identical inputs.
	lab.ai.mode = "legacy"
	lab.set_process(false)
	for target in lab._fixtures:
		target.walking = false
		target.visual.frozen = true
		target.visual.pause()
	for mode in [false, true]:
		lab.batch.enabled = mode
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("batch.png" if mode else "original.png"))
	lab.batch._process(0.0)
	var indices := {}
	for target in lab._fixtures:
		var sprite = target.visual
		var action: String = sprite._key.get_slice("/", 1)
		var index: int = indices.get(action, 0)
		var instances: MultiMesh = lab.batch.batches[action].multimesh
		if not instances.get_instance_transform(index).is_equal_approx(lab.batch.instance_transform(sprite)) \
				or not instances.get_instance_custom_data(index).is_equal_approx(lab.batch.instance_data(sprite, get_viewport().get_camera_3d())):
			push_error("BATCH_PROFILE upload mismatch")
			get_tree().quit(1)
			return
		indices[action] = index + 1
	lab.batch.enabled = false
	lab.batch._process(0.0)
	if not lab.batch.batches.is_empty():
		push_error("BATCH_PROFILE fallback retained batches")
		get_tree().quit(1)
		return
	print("BATCH_PROFILE_COMPLETE captures=", output)
	get_tree().quit()
