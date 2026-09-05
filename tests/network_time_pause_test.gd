extends SceneTree

class ReferenceClock extends NetworkClocks.SystemClock:
	var now := 0.0
	func get_raw_time() -> float:
		return now

class SimulationClock extends NetworkClocks.SteppingClock:
	var now := 0.0
	func get_raw_time() -> float:
		return now

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var reference := ReferenceClock.new()
	var synchronizer := root.get_node("NetworkTimeSynchronizer")
	var original_clock = synchronizer._clock
	synchronizer._clock = reference
	# Match startup clock corrections followed by a long rendered frame, without
	# requiring a real stall, socket, window, or operating-system clock adjustment.
	for offset in [0.0, 4.0, -4.0]:
		for backlog in [0.0, 0.5]:
			var time = load("res://addons/netfox/network-time.gd").new()
			root.add_child(time)
			var simulation := SimulationClock.new()
			simulation.now = 10.0
			simulation.set_time(10.0)
			time._clock = simulation
			time._clock_stretch_factor = 1.0
			time._last_process_time = 10.0
			time._next_tick_time = 10.0 - backlog
			time._tick = time.seconds_to_ticks(10.0 - backlog)
			simulation.now = 11.25
			reference.now = 11.25 + offset
			time._loop()
			_check(absi(time.tick - time.seconds_to_ticks(reference.now)) <= 1,
				"pause must discard old scheduled backlog, offset=%s backlog=%s" % [offset, backlog])
			# Compare against a clean timeline, including netfox's ordinary tick
			# phase/clock-stretch behavior rather than imposing a new phase policy.
			var control = load("res://addons/netfox/network-time.gd").new()
			root.add_child(control)
			var control_clock := SimulationClock.new()
			control_clock.now = simulation.now
			control_clock.set_time(reference.now)
			control._clock = control_clock
			control._clock_stretch_factor = 1.0
			control._last_process_time = reference.now
			control._next_tick_time = reference.now
			control._tick = control.seconds_to_ticks(reference.now)
			var worst_tick_drift := 0
			for frame in range(900):
				simulation.now += 1.0 / 60.0
				control_clock.now = simulation.now
				reference.now += 1.0 / 60.0
				time._loop()
				control._loop()
				worst_tick_drift = maxi(worst_tick_drift, absi(time.tick - control.tick))
			_check(worst_tick_drift == 0,
				"pause recovery must match clean timeline, offset=%s backlog=%s drift=%d ticks" % [offset, backlog, worst_tick_drift])
			control.free()
			time.free()
	synchronizer._clock = original_clock
	print("NETWORK_TIME_PAUSE_TEST %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("FAIL: %s" % message)
