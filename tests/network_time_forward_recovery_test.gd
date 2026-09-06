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
	var cases := [
		{"name": "enabled", "recover": true},
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
		time.set_process(false)
		time.set_physics_process(false)
		time._state = 2 if config.get("active", true) else 0
		time._initial_sync_done = config.get("synced", true)
		var simulation := SimulationClock.new()
		simulation.now = 10.0
		simulation.set_time(10.0)
		time._clock = simulation
		time._last_process_time = 10.0
		time._next_tick_time = 10.0
		time._tick = time.seconds_to_ticks(10.0)
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
			_check(time.tick >= 600 and time.tick <= 602, "%s: ordinary timeline preserved" % config.name)
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
