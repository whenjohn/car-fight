extends SceneTree
const NAV := preload("res://world/sprite_ai_navigation.gd")
const BRAIN := preload("res://combat/sprite_ai_brain.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var nav := NAV.new()
	if not nav.has_method("cover_sector"):
		push_error("Object-based cover geometry is not implemented")
		quit(1)
		return
	nav.setup(0.35)
	_check(nav.blocks.size() == 14 and nav.cover_anchors.size() == 14, "one shared static cover registry, not per-sprite objects")
	var block: Dictionary = nav.blocks[0]
	var previous_sector := -1
	var sectors := {}
	for step in 64:
		var angle := step * TAU / 64.0
		var observer: Vector3 = block.center + Vector3(cos(angle), 0, sin(angle)) * 45.0
		var sector: int = nav.cover_sector(0, observer, previous_sector)
		var point: Vector3 = nav.cover_point(0, sector, 0.98)
		_check((point - block.center).dot(observer - block.center) < 0.0, "hiding goal stays on opposite side through complete vehicle circle")
		_check(nav.clear(point), "opposite-side anchor is outside the building")
		sectors[sector] = true
		previous_sector = sector
	_check(sectors.size() == 8, "circling vehicle moves hiding goal around all sides of same object")
	var candidates: Array = nav.cover_objects(Vector3(-8, 1, -32), 1.8)
	_check(not candidates.is_empty() and candidates.size() <= 14, "eligible cover list stays bounded")
	_check(nav.cover_objects(Vector3.ZERO, 1000.0).is_empty(), "objects too short to hide sprite are excluded")
	for candidate in candidates:
		_check(nav.blocks[candidate].height >= 1.8, "only tall-enough solid objects are eligible")
	# A prepared ambusher does not rush just because a nearby car circles or
	# faces the object. It attacks a passing/departing or turned-away vehicle.
	var settings := {"speed": 3.0, "detection": 32.0, "interval": 1.0}
	var s := BRAIN.initial(10000, "ambusher", Vector3(0, 0, 8))
	s.cover = Vector3(0, 0, 8)
	s.cover_id = 0
	var car := {"position": Vector3(0, 0, -8), "velocity": Vector3.ZERO,
		"forward": Vector3.BACK, "visible": false, "cover_center": Vector3.ZERO, "cover_distance": 4.0}
	var decision := BRAIN.decide(s, s.cover, car, 1.0, settings)
	_check(decision.state == "hide" and s.prepared, "near facing car does not trigger prepared ambusher")
	s.cover_shifted = true
	car.velocity = Vector3.RIGHT * 4.0
	car.forward = Vector3.RIGHT
	decision = BRAIN.decide(s, s.cover, car, 0.2, settings)
	_check(decision.seek_cover and decision.state != "rush", "circling car requests repositioning, not an attack")
	car.visible = true
	BRAIN.decide(s, s.cover, car, 0.2, settings)
	car.visible = false
	decision = BRAIN.decide(s, s.cover + Vector3.RIGHT * 2.0, car, 0.2, settings)
	_check(s.prepared and decision.state == "shadow", "brief exposure while repositioning does not forget prepared ambush")
	s.cover_shifted = false
	car.velocity = Vector3.FORWARD * 4.0
	car.forward = Vector3.FORWARD
	car.cover_distance = 6.0
	decision = BRAIN.decide(s, s.cover, car, 0.2, settings)
	_check(decision.state == "rush" and decision.destination == car.position, "passed/departing car creates attack opportunity")
	var turned := BRAIN.initial(10001, "ambusher", Vector3(0, 0, 8))
	turned.cover = Vector3(0, 0, 8)
	turned.cover_id = 0
	car.velocity = Vector3.ZERO
	decision = BRAIN.decide(turned, turned.cover, car, 1.0, settings)
	_check(decision.state == "rush", "car facing away is an opportunity after genuine concealment")
	var exposed := BRAIN.initial(10002, "ambusher", Vector3(0, 0, 8))
	exposed.cover = Vector3(0, 0, 8)
	exposed.cover_id = 0
	car.visible = true
	decision = BRAIN.decide(exposed, exposed.cover, car, 1.0, settings)
	_check(not exposed.prepared and decision.state != "rush", "exposed sprite must first achieve concealment")
	if failures.is_empty():
		print("SPRITE_COVER_TEST PASS")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
