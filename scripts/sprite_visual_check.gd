extends Node
## Explicit offline-only rendered acceptance through play_monitored.sh.
## Writes captures/measurements under ignored .crash-runs, then exits.

func run(lab: Node, main: Node3D) -> void:
	await get_tree().create_timer(2.0).timeout
	if main.call("local_player") == null:
		push_error("SPRITE_VISUAL_CHECK missing offline player")
		get_tree().quit(1)
		return
	var output := "res://.crash-runs/sprite-visual-%d" % Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(output)
	# Fixture isolation: keep the fixed car/camera while comparing sprite counts.
	main.set("_ramming_lab_enabled", true)
	var car = main.call("local_player")
	car.freeze = true
	var measurements: Array = []
	var sizes := [] if OS.get_environment("CAR_FIGHT_SPRITE_VISUAL_CHECK") == "close" else [128, 512]
	for size in sizes:
		for amount in [0, 1, 16, 64]:
			lab.set("_resolution", size)
			lab.call("configure", amount > 0, maxi(1, amount), 1.0, true)
			print("SPRITE_VISUAL_PHASE count=%d resolution=%d warming" % [amount, size])
			await get_tree().create_timer(3.0).timeout
			var samples: Array[float] = []
			var until := Time.get_ticks_msec() + 5000
			var previous := Time.get_ticks_usec()
			while Time.get_ticks_msec() < until:
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				samples.append(float(now - previous) / 1000.0)
				previous = now
			samples.sort()
			var record := {"count": amount, "resolution": size,
				"median_ms": samples[samples.size() / 2], "p95_ms": samples[int(samples.size() * 0.95)],
				"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
			measurements.append(record)
			print("SPRITE_VISUAL_SAMPLE " + JSON.stringify(record))
			get_viewport().get_texture().get_image().save_png(output.path_join("%d-%d.png" % [size, amount]))
	lab.call("configure", true, 16, 1.0, false)
	lab.set("_resolution", 512)
	var first = main.get("_targets").get_node("Target_10000")
	car.position = first.position + Vector3(3, 0, 3)
	car.reset_physics_interpolation()
	main.set("_local_presentation_smoothing_enabled", false)
	main.get("_always_forward_camera_tuning")["camera_zoom"] = 2.0
	for action in ["idle", "walk", "attack", "death"]:
		lab.set("_preview", action)
		await get_tree().create_timer(7.0 if action in ["attack", "death"] else 2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(action + "-close.png"))
	lab.set("_preview", "automatic")
	main.get("_always_forward_camera_tuning")["orthographic"] = false
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("perspective.png"))
	lab.call("open")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	lab.get("_window").get_texture().get_image().save_png(output.path_join("controls.png"))
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "\t") + "\n")
	print("SPRITE_VISUAL_CHECK PASS captures=" + output)
	get_tree().quit()
