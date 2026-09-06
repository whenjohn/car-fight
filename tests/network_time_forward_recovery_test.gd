extends SceneTree

class ReferenceClock extends NetworkClocks.SystemClock:
	var now := 0.0
	func get_raw_time() -> float:
		return now

class SimulationClock extends NetworkClocks.SteppingClock:
	var now := 0.0
	func get_raw_time() -> float:
		return now

class ClientPeer extends MultiplayerPeerExtension:
	var status := MultiplayerPeer.CONNECTION_CONNECTED
	var server := false
	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
		return status
	func _get_unique_id() -> int:
		return 1 if server else 2
	func _is_server() -> bool:
		return server
	func _get_available_packet_count() -> int:
		return 0
	func _poll() -> void:
		pass
	func _close() -> void:
		status = MultiplayerPeer.CONNECTION_DISCONNECTED

const OPT_IN := "CAR_FIGHT_FORWARD_CLOCK_RECOVERY"
var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("NetworkEvents").enabled = false
	root.get_node("NetworkTime").stop()
	multiplayer_poll = false
	var synchronizer := root.get_node("NetworkTimeSynchronizer")
	var original_clock = synchronizer._clock
	var reference := ReferenceClock.new()
	synchronizer._clock = reference
	var had_env := OS.has_environment(OPT_IN)
	var original_env := OS.get_environment(OPT_IN)
	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	_check('NetworkTime.set_forward_clock_recovery_enabled(_web_query("forwardClockRecovery") == "1")'
		in main_source, "browser explicitly configures the same recovery path")
	var cases := [
		{"name": "enabled", "recover": true},
		{"name": "tick backlog with aligned clock", "offset": 0.0, "backlog": 4.0, "recover": true},
		{"name": "tick backlog default off", "offset": 0.0, "backlog": 4.0, "enabled": false},
		{"name": "small tick backlog", "offset": 0.0, "backlog": 0.5},
		{"name": "tick backlog threshold boundary", "offset": 0.0, "backlog": synchronizer.panic_threshold},
		{"name": "tick timeline ahead must not rewind", "backlog": -10.0},
		{"name": "sustained slow frames", "offset": 0.0, "slow_frames": true},
		{"name": "browser opt-in without environment", "enabled": false, "configured": true, "recover": true},
		{"name": "browser opt-out clears earlier selection", "configured": false},
		{"name": "default off", "enabled": false},
		{"name": "small adjustment", "offset": 0.5},
		{"name": "threshold boundary", "offset": synchronizer.panic_threshold},
		{"name": "negative correction", "offset": -4.7234838},
		{"name": "server", "server": true},
		{"name": "offline", "offline": true},
		{"name": "connecting", "status": MultiplayerPeer.CONNECTION_CONNECTING},
		{"name": "disconnected", "status": MultiplayerPeer.CONNECTION_DISCONNECTED},
		{"name": "inactive", "active": false},
		{"name": "initial sync pending", "synced": false},
		{"name": "fresh reconnect instance", "recover": true},
	]
	for config in cases:
		OS.unset_environment(OPT_IN)
		if config.get("enabled", true):
			OS.set_environment(OPT_IN, "1")
		var peer := ClientPeer.new()
		peer.server = config.get("server", false)
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new() if config.get("offline", false) else peer
		peer.status = config.get("status", MultiplayerPeer.CONNECTION_CONNECTED)
		var time = load("res://addons/netfox/network-time.gd").new()
		root.add_child(time)
		if config.has("configured"):
			_check(time.has_method("set_forward_clock_recovery_enabled"), "explicit recovery configuration is available")
			if time.has_method("set_forward_clock_recovery_enabled"):
				time.set_forward_clock_recovery_enabled(config.configured)
		time.set_process(false)
		time.set_physics_process(false)
		time._state = 2 if config.get("active", true) else 0
		time._initial_sync_done = config.get("synced", true)
		var simulation := SimulationClock.new()
		simulation.now = 10.0
		simulation.set_time(10.0)
		time._clock = simulation
		time._last_process_time = 10.0
		time._next_tick_time = 10.0 - float(config.get("backlog", 0.0))
		time._tick = time.seconds_to_ticks(time._next_tick_time)
		var starting_tick: int = time.tick
		var emitted: Array[int] = []
		time.on_tick.connect(func(_dt, tick): emitted.append(tick))
		simulation.now += 1.0 / 60.0
		reference.now = simulation.now + float(config.get("offset", 4.7234838))
		time._loop()
		if config.get("recover", false):
			_check(time.tick == time.seconds_to_ticks(reference.now), "%s: tick rebased" % config.name)
			_check(is_equal_approx(time._next_tick_time, reference.now), "%s: schedule rebased" % config.name)
			_check(is_equal_approx(simulation.get_time(), reference.now), "%s: clock rebased" % config.name)
			_check(emitted.is_empty(), "%s: no old-timeline input ticks emitted" % config.name)
			for frame in range(900):
				simulation.now += 1.0 / 60.0
				reference.now += 1.0 / 60.0
				time._loop()
				_check(absi(time.tick - time.seconds_to_ticks(reference.now)) <= 2,
					"%s: recovered timeline remains aligned" % config.name)
			for index in range(1, emitted.size()):
				_check(emitted[index] == emitted[index - 1] + 1, "no duplicate or skipped ordinary ticks after recovery")
		else:
			var allowed_ticks: int = time.max_ticks_per_frame if float(config.get("backlog", 0.0)) > 0.0 else 2
			_check(time.tick >= starting_tick and time.tick <= starting_tick + allowed_ticks,
				"%s: ordinary bounded timeline preserved" % config.name)
		if config.get("slow_frames", false):
			for frame in range(90):
				var before_count := emitted.size()
				simulation.now += 0.2
				reference.now += 0.2
				time._loop()
				_check(emitted.size() - before_count <= time.max_ticks_per_frame,
					"sustained slow frames preserve the per-frame tick cap")
				_check(reference.now - time.ticks_to_seconds(time.tick) < synchronizer.panic_threshold + 0.5,
					"sustained slow frames cannot accumulate unbounded tick lag")
		time.free()
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	synchronizer._clock = original_clock
	if had_env:
		OS.set_environment(OPT_IN, original_env)
	else:
		OS.unset_environment(OPT_IN)
	print("NETWORK_TIME_FORWARD_RECOVERY_TEST %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		if not _failed:
			printerr("FAIL: %s" % message)
		_failed = true
