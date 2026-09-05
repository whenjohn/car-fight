extends SceneTree
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var script = load("res://combat/sprite_ai_brain.gd")
	if script == null:
		push_error("Sprite AI controller not implemented")
		quit(1)
		return
	var brain = script.new()
	var seen := {"id": 2, "position": Vector3(0, 0, -5), "velocity": Vector3.ZERO, "visible": true}
	var settings := {"speed": 3.0, "detection": 32.0, "interval": 1.0}
	for profile in ["basic", "attacker", "evader"]:
		seen.position = Vector3(0, 0, -15 if profile == "evader" else -5)
		var state: Dictionary = brain.initial(10000, profile, Vector3.ZERO)
		var result: Dictionary = brain.decide(state, Vector3.ZERO, seen, 0.2, settings)
		_check(result["state"] == "aim", profile + " aims at visible car in range")
		result = brain.decide(state, Vector3.ZERO, seen, 0.4, settings)
		_check(result["fire"], profile + " fires after aiming delay")
		result = brain.decide(state, Vector3.ZERO, seen, 0.1, settings)
		_check(not result["fire"], "cooldown prevents duplicate shot")
	var hunter: Dictionary = brain.initial(10000, "attacker", Vector3(30, 0, 30))
	var hidden := {"id": 2, "position": Vector3(0, 0, -90), "velocity": Vector3.ZERO, "visible": false}
	for step in 150:
		hidden.position.x = float(step)
		var hunt: Dictionary = brain.decide(hunter, Vector3.ZERO, hidden, 0.2, settings)
		_check(hunt.state == "pursue" and hunt.destination == hidden.position,
			"attacker tracks moving player beyond detection and never times out")
		_check(not hunt.fire, "attacker cannot shoot through cover")
		_check(hunt.speed >= 3.96 and hunt.speed <= 5.04, "attacker pace stays within twelve percent")
		_check(absf(hunt.steer) <= 0.36, "movement variation stays forward-directed")
	var twin_a: Dictionary = brain.initial(10001, "attacker", Vector3.ZERO)
	var twin_b: Dictionary = brain.initial(10001, "attacker", Vector3.ZERO)
	var other: Dictionary = brain.initial(10002, "attacker", Vector3.ZERO)
	var previous_steer := 0.0
	var changed := false
	for step in 100:
		var a: Dictionary = brain.decide(twin_a, Vector3.ZERO, hidden, 0.2, settings)
		var b: Dictionary = brain.decide(twin_b, Vector3.ZERO, hidden, 0.2, settings)
		_check(a == b, "same seeded hunter reproduces movement")
		if step > 0:
			_check(absf(a.steer - previous_steer) < 0.09, "steering variation changes gently")
			changed = changed or not is_equal_approx(a.steer, previous_steer)
		previous_steer = a.steer
	_check(changed and twin_a.pace != other.pace, "individual hunters differ and weave over time")
	seen.position = Vector3(0, 0, -15)
	var approach: Dictionary = brain.decide(hunter, Vector3.ZERO, seen, 0.4, settings)
	_check(approach.fire and approach.destination == seen.position, "attacker fires while closing distance")
	seen.position = Vector3(0, 0, -3)
	var close: Dictionary = brain.decide(hunter, Vector3.ZERO, seen, 0.2, settings)
	_check(close.destination == Vector3.ZERO and close.state != "retreat", "close attacker holds and fights instead of retreating")
	var waiting: Dictionary = brain.decide(hunter, Vector3.ZERO, {}, 0.2, settings)
	_check(waiting.destination == Vector3.ZERO and not waiting.fire, "no eligible player means wait, not chase stale position")
	_check(waiting.steer == 0.0 and close.steer == 0.0, "variation does not create idle wandering")
	var evader: Dictionary = brain.initial(10000, "evader", Vector3.ZERO)
	seen.position = Vector3(0, 0, -5)
	var evade: Dictionary = brain.decide(evader, Vector3.ZERO, seen, 0.2, settings)
	_check(evade.state == "evade" and evade.destination.z > 0, "evader retreats away from car")
	seen.position = Vector3(0, 0, -15)
	seen.velocity = Vector3(0, 0, 20)
	evader = brain.initial(10000, "evader", Vector3.ZERO)
	evade = brain.decide(evader, Vector3.ZERO, seen, 0.2, settings)
	_check(evade.state == "evade" and absf(evade.destination.x) > 1, "evader sidesteps predicted crossing")
	_check(evade.steer == 0.0 and is_equal_approx(evade.speed, settings.speed * 1.5),
		"imminent crossing keeps full-speed sidestep, not a zig back into traffic")
	seen.velocity = Vector3.ZERO
	for base_speed in [0.5, 3.0, 8.0]:
		var tuning := {"speed": base_speed, "detection": 32.0, "interval": 1.0}
		var runner: Dictionary = brain.initial(10003, "evader", Vector3.ZERO)
		var previous_speed := 0.0
		for gap in [9.0, 6.0, 3.0, 2.0, 0.0]:
			seen.position = Vector3(0, 0, -gap)
			var run: Dictionary = brain.decide(runner, Vector3.ZERO, seen, 0.2, tuning)
			_check(run.state == "evade" and run.speed >= previous_speed and run.speed <= base_speed * 1.5,
				"closer pursuer increases speed without exceeding existing evader cap")
			if gap > 2.0:
				_check(run.speed > previous_speed and run.speed < base_speed * 1.5, "speed ramps before reaching cap")
			else:
				_check(is_equal_approx(run.speed, base_speed * 1.5), "point-blank runner reaches but never exceeds cap")
			_check(run.destination.is_finite(), "coincident car gets a finite escape direction")
			previous_speed = run.speed
		seen.position = Vector3(0, 0, -12)
		var easing: Dictionary = brain.decide(runner, Vector3.ZERO, seen, 0.2, tuning)
		_check(easing.state == "evade" and is_equal_approx(easing.speed, base_speed), "runner eases off as gap opens while retaining hysteresis")
		seen.position.z = -(float(runner.get("evade_distance", 10.0)) + 4.1)
		easing = brain.decide(runner, Vector3.ZERO, seen, 0.2, tuning)
		_check(easing.state != "evade" and easing.steer == 0.0, "zigzag ends when safely outside retreat distance")
	var zig_a: Dictionary = brain.initial(10005, "evader", Vector3.ZERO)
	var zig_b: Dictionary = brain.initial(10005, "evader", Vector3.ZERO)
	var zig_other: Dictionary = brain.initial(10006, "evader", Vector3.ZERO)
	seen.position = Vector3(0, 0, -5)
	var positive := false
	var negative := false
	var individual := false
	for step in 40:
		var a: Dictionary = brain.decide(zig_a, Vector3.ZERO, seen, 0.2, settings)
		var b: Dictionary = brain.decide(zig_b, Vector3.ZERO, seen, 0.2, settings)
		var c: Dictionary = brain.decide(zig_other, Vector3.ZERO, seen, 0.2, settings)
		_check(a == b, "same seeded evader reproduces zigzag")
		_check(absf(a.steer) <= 0.65 and not a.fire, "zigzag remains forward-directed without firing during retreat")
		positive = positive or a.steer > 0.3
		negative = negative or a.steer < -0.3
		individual = individual or not is_equal_approx(a.steer, c.steer)
	_check(positive and negative and individual, "evaders alternate left/right at individual timings")
	var safe: Dictionary = brain.decide(zig_a, Vector3.ZERO, {}, 0.2, settings)
	_check(safe.steer == 0.0, "no eligible pursuer means no evasive zigzag")
	var patient := 0
	var cautious := 0
	var far_reactions := 0
	for id in range(10000, 10064):
		var personality: Dictionary = brain.initial(id, "evader", Vector3.ZERO)
		var threshold := float(personality.get("evade_distance", 10.0))
		_check(threshold == 10.0 or (threshold >= 14.0 and threshold <= 22.0), "reaction distances stay in intended bands")
		_check(personality == brain.initial(id, "evader", Vector3.ZERO), "reaction personality repeats for same ID")
		patient += int(threshold == 10.0)
		cautious += int(threshold >= 14.0)
		# Slow approaching car cannot hit within a second: test awareness, not
		# the existing emergency crossing trigger. Y velocity is irrelevant.
		var approach_car := {"position": Vector3(0, 0, -18), "velocity": Vector3(0, 7, 2), "visible": true}
		var reaction: Dictionary = brain.decide(personality, Vector3.ZERO, approach_car, 0.2, settings)
		_check((reaction.state == "evade") == (threshold > 18.0), "only cautious sprites react to farther approaching car")
		far_reactions += int(reaction.state == "evade")
		if reaction.state == "evade":
			approach_car.position.z = -(threshold + 2.0)
			approach_car.velocity = Vector3.ZERO
			reaction = brain.decide(personality, Vector3.ZERO, approach_car, 0.2, settings)
			_check(reaction.state == "evade", "early evader retains personal four-unit release buffer")
			approach_car.position.z = -(threshold + 4.1)
			reaction = brain.decide(personality, Vector3.ZERO, approach_car, 0.2, settings)
			_check(reaction.state != "evade", "personal release distance ends retreat")
		for velocity in [Vector3.ZERO, Vector3(0, 0, -2), Vector3(2, 0, 0)]:
			personality = brain.initial(id, "evader", Vector3.ZERO)
			approach_car = {"position": Vector3(0, 0, -13), "velocity": velocity, "visible": true}
			reaction = brain.decide(personality, Vector3.ZERO, approach_car, 0.2, settings)
			_check(reaction.state != "evade", "far parked, departing or tangential car does not trigger early evasion")
		personality = brain.initial(id, "evader", Vector3.ZERO)
		approach_car.position.z = -9.0
		approach_car.velocity = Vector3.ZERO
		reaction = brain.decide(personality, Vector3.ZERO, approach_car, 0.2, settings)
		_check(reaction.state == "evade", "every personality retains existing close-range reaction")
	_check(patient > 0 and cautious > 0 and far_reactions > 0 and far_reactions < 64,
		"64-sprite population mixes patient and early-reacting evaders")
	var basic: Dictionary = brain.initial(10001, "basic", Vector3.ZERO)
	var wander: Dictionary = brain.decide(basic, Vector3.ZERO, {}, 0.2, settings)
	_check(wander.destination.length() <= 8.01 and not wander.fire, "unthreatened basic wanders locally")
	var ambusher: Dictionary = brain.initial(10000, "ambusher", Vector3.ZERO)
	seen = {"id": 2, "position": Vector3(4, 0, -10), "velocity": Vector3.ZERO, "visible": false}
	var ambush: Dictionary = brain.decide(ambusher, Vector3.ZERO, seen, 0.2, settings)
	_check(ambush.seek_cover and not ambush.fire, "ambusher prepares cover before direct sight")
	seen.visible = true
	ambusher = brain.initial(10000, "ambusher", Vector3.ZERO)
	for step in 20:
		ambush = brain.decide(ambusher, Vector3.ZERO, seen, 0.2, settings)
		_check(not ambush.fire and ambush.state == "seek_cover", "no Basic shooting fallback while exposed without cover")
	ambusher.cover = Vector3.ZERO
	ambusher.peek = Vector3(4, 0, 0)
	ambusher.state = "cover"
	seen.visible = false
	ambush = brain.decide(ambusher, Vector3.ZERO, seen, 0.5, settings)
	_check(ambush.state == "hide" and not ambush.fire, "ambush waits concealed")
	ambush = brain.decide(ambusher, Vector3.ZERO, seen, 0.5, settings)
	_check(ambush.state == "rush" and ambush.destination == seen.position and is_equal_approx(ambush.speed, 4.5),
		"concealed ambusher launches full rush toward car, not a peek point")
	seen.visible = true
	for shot in 3:
		seen.position.x += 1.0
		ambush = brain.decide(ambusher, ambusher.peek, seen, 1.0, settings)
		_check(ambush.fire and ambush.destination == seen.position, "ambush fires while pursuing current car position")
	ambush = brain.decide(ambusher, ambusher.peek, seen, 0.2, settings)
	_check(ambush.state == "cover" and not ambush.fire, "three-shot burst returns to cover")
	ambush = brain.decide(ambusher, ambusher.cover, seen, 0.2, settings)
	_check(ambush.state == "seek_cover" and ambush.seek_cover, "exposed former cover is rejected, never counted as hidden")
	ambusher = brain.initial(10000, "ambusher", Vector3.ZERO)
	ambusher.cover = Vector3.ZERO
	seen.visible = false
	ambush = brain.decide(ambusher, Vector3.ZERO, seen, 1.0, settings)
	seen.position = Vector3(0, 0, -80)
	for step in 40:
		ambush = brain.decide(ambusher, Vector3(0, 0, -5), seen, 0.2, settings)
	_check(ambush.state == "cover" and not ambush.fire, "escaped player cannot cause an endless rush")
	ambush = brain.decide(ambusher, Vector3(0, 0, -5), {}, 0.2, settings)
	_check(not ambush.fire and ambush.destination == ambusher.cover, "lost eligible player aborts ambush and returns to cover")
	var nav_script = load("res://world/sprite_ai_navigation.gd")
	var nav = nav_script.new()
	for radius in [0.175, 0.35, 0.7]:
		nav.setup(radius)
		var route: PackedVector3Array = nav.route(Vector3(-8, 1, -32), Vector3(-55, 1, -32))
		_check(not route.is_empty(), "route goes around city building")
		for point in route:
			_check(nav.clear(point), "route respects scaled building clearance")
	_check(not nav.clear(Vector3(-31.5, 1, -31.5)), "building interior blocked")
	if failures.is_empty():
		print("SPRITE_AI_TEST PASS")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
