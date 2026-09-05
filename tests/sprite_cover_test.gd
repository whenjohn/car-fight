extends SceneTree
const NAV := preload("res://world/sprite_ai_navigation.gd")
const BRAIN := preload("res://combat/sprite_ai_brain.gd")
const TARGET := preload("res://combat/sprite_target.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var nav := NAV.new()
	nav.setup(0.35)
	if nav.get("grass_slots") == null:
		push_error("Grass hiding spots are not implemented")
		quit(1)
		return
	_check(nav.grass_slots.size() >= 64 and nav.grass_slots.size() <= 100, "shared grass slots support 64 with a fixed bound")
	var unique := {}
	for point in nav.grass_slots:
		_check(nav.clear(point, 1.42), "grass spots have grid and capsule clearance")
		_check(absf(point.x - 58.0) < 19.0 and absf(point.z - 18.0) < 19.0, "hiding spots inside actual grass field")
		unique[nav.cell(point)] = true
	_check(unique.size() == nav.grass_slots.size(), "hiding slots do not collapse to same route cell")
	var settings := {"speed": 3.0, "detection": 32.0, "interval": 1.0}
	var spot := Vector3(62, 1, 18)
	var s := BRAIN.initial(10000, "ambusher", spot)
	s.cover = spot
	s.cover_id = 0
	var car := {"position": spot + Vector3(-10, 0, 5), "velocity": Vector3.ZERO,
		"forward": Vector3.LEFT, "visible": true}
	var d := BRAIN.decide(s, spot, car, 1.0, settings)
	_check(d.state == "hide" and s.prepared and not d.fire, "grass conceals despite clear sight; parked facing-away car does not trigger")
	car.velocity = Vector3.RIGHT * 6.0
	car.forward = Vector3.RIGHT
	d = BRAIN.decide(s, spot, car, 0.2, settings)
	_check(d.state == "hide", "approaching car arms pass without premature attack")
	car.position = spot + Vector3(0, 0, 5)
	d = BRAIN.decide(s, spot, car, 0.2, settings)
	_check(d.state == "hide", "alongside car does not trigger")
	car.position = spot + Vector3(4, 0, 5)
	d = BRAIN.decide(s, spot, car, 0.2, settings)
	_check(d.state == "rush" and d.destination == car.position, "car moves past hiding sprite before rear rush")
	var fresh := BRAIN.initial(10001, "ambusher", spot)
	fresh.cover = spot
	fresh.cover_id = 1
	d = BRAIN.decide(fresh, spot, car, 1.0, settings)
	_check(d.state == "hide", "already-departing car without observed approach does not trigger")
	d = BRAIN.decide(fresh, spot + Vector3.RIGHT * 4.0, car, 1.0, settings)
	_check(d.state == "cover" and not fresh.prepared, "cannot blend before arriving or after displacement")
	var target := TARGET.new()
	target.ai_profile = "ambusher"
	target.ai_state = "hide"
	_check(target.presentation_tint().a < 0.5, "hidden sprite blends visually")
	target.ai_state = "rush"
	_check(target.presentation_tint() == Color.WHITE, "rush restores visibility")
	target.ai_state = "hide"
	target.health = 0
	_check(target.presentation_tint() == Color.WHITE, "death restores visibility")
	target.free()
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
