extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Register before NetworkTime awaits initial sync. Only this test entry point
	# seeds a stale timestamp; real ping samples must discover and repair it.
	var synchronizer := root.get_node("NetworkTimeSynchronizer")
	synchronizer.on_initial_sync.connect(func():
		if synchronizer.get_time() < 5.0:
			printerr("STARTUP_SEED_FAIL server must have five seconds of uptime")
			quit(1)
			return
		synchronizer._clock.adjust(-4.7234838)
		print("STARTUP_SEED offset=-4.7234838 reference=%f" % synchronizer.get_time())
	, CONNECT_ONE_SHOT)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
