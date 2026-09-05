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
	var seen := {"id": 2, "position": Vector3(0, 0, -15), "velocity": Vector3.ZERO, "visible": true}
	var settings := {"speed": 3.0, "detection": 32.0, "interval": 1.0}
	for profile in ["basic", "attacker", "evader"]:
		var state: Dictionary = brain.initial(10000, profile, Vector3.ZERO)
		var result: Dictionary = brain.decide(state, Vector3.ZERO, seen, 0.2, settings)
		_check(result["state"] == "aim", profile + " aims at visible car in range")
		result = brain.decide(state, Vector3.ZERO, seen, 0.4, settings)
		_check(result["fire"], profile + " fires after aiming delay")
		result = brain.decide(state, Vector3.ZERO, seen, 0.1, settings)
		_check(not result["fire"], "cooldown prevents duplicate shot")
	var evader: Dictionary = brain.initial(10000, "evader", Vector3.ZERO)
	seen.position = Vector3(0, 0, -5)
	var evade: Dictionary = brain.decide(evader, Vector3.ZERO, seen, 0.2, settings)
	_check(evade.state == "evade" and evade.destination.z > 0, "evader retreats away from car")
	seen.position = Vector3(0, 0, -15)
	seen.velocity = Vector3(0, 0, 20)
	evader = brain.initial(10000, "evader", Vector3.ZERO)
	evade = brain.decide(evader, Vector3.ZERO, seen, 0.2, settings)
	_check(evade.state == "evade" and absf(evade.destination.x) > 1, "evader sidesteps predicted crossing")
	var basic: Dictionary = brain.initial(10001, "basic", Vector3.ZERO)
	var wander: Dictionary = brain.decide(basic, Vector3.ZERO, {}, 0.2, settings)
	_check(wander.destination.length() <= 8.01 and not wander.fire, "unthreatened basic wanders locally")
	var ambusher: Dictionary = brain.initial(10000, "ambusher", Vector3.ZERO)
	ambusher.cover = Vector3.ZERO
	ambusher.peek = Vector3(4, 0, 0)
	ambusher.state = "cover"
	seen = {"id": 2, "position": Vector3(4, 0, -10), "velocity": Vector3.ZERO, "visible": false}
	var ambush: Dictionary = brain.decide(ambusher, Vector3.ZERO, seen, 0.5, settings)
	_check(ambush.state == "hide" and not ambush.fire, "ambush waits concealed")
	ambush = brain.decide(ambusher, Vector3.ZERO, seen, 0.5, settings)
	_check(ambush.state == "peek", "nearby tracked car triggers step out")
	seen.visible = true
	for shot in 3:
		ambush = brain.decide(ambusher, ambusher.peek, seen, 1.0, settings)
		_check(ambush.fire, "ambush burst shot confirmed")
	ambush = brain.decide(ambusher, ambusher.peek, seen, 0.2, settings)
	_check(ambush.state == "cover" and not ambush.fire, "three-shot burst returns to cover")
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
