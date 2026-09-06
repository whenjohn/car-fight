extends SceneTree

var _retry_sent := false

func _process(_delta: float) -> bool:
	if OS.get_environment("CAR_FIGHT_STARTUP_TEST_RETRY") == "1" and not _retry_sent \
			and current_scene != null and current_scene.get("_startup_gate") != null \
			and current_scene.network_startup_ready():
		_retry_sent = true
		call_deferred("_retry_once")
	return false

func _retry_once() -> void:
	print("STARTUP_RETRY test-only connection failure")
	current_scene._startup_gate.fail("Test connection failure")
	current_scene._retry_network_join()

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
