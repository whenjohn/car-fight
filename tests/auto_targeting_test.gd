extends SceneTree

const COVERAGE := preload("res://combat/coverage_config.gd")
const TARGETING := preload("res://combat/auto_targeting.gd")

class Fixture extends StaticBody3D:
	var health := 3

class Shooter extends RigidBody3D:
	var map_id := 0
	var is_cloaked := false
	var area_weapon_armed := false
	var rc_pilot_active := false

class Controls extends Node:
	var editing := false

var failures: Array[String] = []
var main
var body: RigidBody3D
var world := Node3D.new()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.add_child(world)
	main = load("res://tests/auto_targeting_harness.gd").new()
	main._targets = Node3D.new()
	main._balls = Node3D.new()
	world.add_child(main._targets)
	world.add_child(main._balls)
	body = RigidBody3D.new()
	body.freeze = true
	world.add_child(body)

	var blocked := _fixture(Vector2(0, -2), false)
	var nearest := _fixture(Vector2(0, -3))
	_fixture(Vector2(0, -3))
	_fixture(Vector2(0, -7))
	_fixture(Vector2(30, -2))
	_check(_pick() == nearest, "blocked nearest falls back; first visible tie wins")
	_check(main.rays == 2 and main.setups == 1 and main.reused,
		"skip farther/tied/outside rays and reuse one query/exclusion setup")
	blocked.set_meta("visible", true)
	_check(_pick() == blocked, "visibility is refreshed on the next acquisition")
	blocked.health = 0
	_check(_pick() == nearest, "dead sprite is immediately ineligible")
	var ball := RigidBody3D.new()
	ball.freeze = true
	main._balls.add_child(ball)
	ball.position = Vector3(0, 0, -3)
	_check(_pick() == nearest, "dummy/sprite wins equal-distance tie with ball")
	ball.position.z = -1
	_check(_pick() == ball, "nearer ball can replace sprite")
	_check(_pick(0, 0.0) == null and main.rays == 0 and main.setups == 0,
		"disabled coverage does no visibility work")
	_clear()
	var corner := _fixture(Vector2(8, -8))
	_check(_pick() == corner, "triangle corner beyond circular reach remains eligible")
	corner.position = Vector3(7, 0, -1)
	_check(_pick(0, 8.0, PI / 2, true) == corner, "reversed tip preserves wide near base")
	_check(_pick() == null, "ordinary tip excludes same point")

	corner.position = Vector3(2, 0, -2)
	_check(_pick(0, 8.0, COVERAGE.MAX_WIDTH) == corner
		and _pick(1, 8.0, COVERAGE.MAX_WIDTH) == corner,
		"overlapping zones independently acquire the same target")

	main.rays = 0
	main.setups = 0
	main.seen_query = null
	var wide := PackedFloat32Array([COVERAGE.MAX_WIDTH, COVERAGE.MAX_WIDTH, 0, 0])
	var shared: Array[Node3D] = main._acquire_targets(body, COVERAGE.default_ranges(),
		wide, COVERAGE.default_tips_outward())
	_check(shared[0] == corner and shared[1] == corner and main.rays == 1 and main.setups == 1,
		"overlapping zones share one ray and one setup")
	corner.set_meta("visible", false)
	shared = main._acquire_targets(body, COVERAGE.default_ranges(), wide,
		COVERAGE.default_tips_outward())
	_check(shared[0] == null and shared[1] == null, "blocked overlap refreshes on next call")
	corner.set_meta("visible", true)
	shared = main._acquire_targets(body, COVERAGE.default_ranges(), wide,
		COVERAGE.default_tips_outward(), 2)
	_check(shared[0] == null and shared[1] == corner, "cooldown mask excludes unready zone")
	main.rays = 0
	main.setups = 0
	shared = main._acquire_targets(body, COVERAGE.default_ranges(), wide,
		COVERAGE.default_tips_outward(), 0)
	_check(shared == [null, null, null, null] and main.rays == 0 and main.setups == 0,
		"all zones cooling down do no visibility setup")

	# Differential oracle uses the original eager selector with seeded geometry,
	# rotated/scaled car transforms, visibility and dead sprites.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4319
	for batch in range(30):
		_clear()
		body.transform = Transform3D(Basis.from_euler(Vector3(0.1, batch * 0.23, 0.05))
			.scaled(Vector3(1.2, 0.9, 1.2)), Vector3(9, 2, -4))
		for index in range(64):
			var target := _fixture(Vector2(rng.randf_range(-28, 28), rng.randf_range(-28, 28)),
				rng.randf() > 0.35)
			if index % 9 == 0:
				target.health = 0
		for zone in range(4):
			for tip in [false, true]:
				var reach := rng.randf_range(0.1, 24.0)
				var width := rng.randf_range(0.1, COVERAGE.MAX_WIDTH)
				_check(_pick(zone, reach, width, tip) == _reference(zone, reach, width, tip),
					"seeded nearest-visible equivalence")
		var ranges := PackedFloat32Array()
		var widths := PackedFloat32Array()
		var tips := PackedByteArray()
		for zone in range(4):
			ranges.append(rng.randf_range(0.1, 24.0))
			widths.append(rng.randf_range(0.1, COVERAGE.MAX_WIDTH))
			tips.append(rng.randi_range(0, 1))
		var mask := rng.randi_range(0, 15)
		shared = main._acquire_targets(body, ranges, widths, tips, mask)
		for zone in range(4):
			var expected := _reference(zone, ranges[zone], widths[zone], bool(tips[zone])) \
				if mask & (1 << zone) else null
			_check(shared[zone] == expected, "shared pass matches independent eager zones and cooldowns")
	_clear()
	body.transform = Transform3D.IDENTITY
	nearest = _fixture(Vector2(0, -2))
	for index in range(255):
		_fixture(Vector2(20 + index, -4))
	_check(_pick() == nearest and main.rays == 1 and main.setups == 1,
		"256 candidates need only one ray when 255 are outside coverage")
	_clear()
	var shooter := Shooter.new()
	shooter.freeze = true
	shooter.name = "2"
	var controls := Controls.new()
	controls.name = "Input"
	shooter.add_child(controls)
	main._players = Node3D.new()
	world.add_child(main._players)
	main._players.add_child(shooter)
	_fixture(Vector2(0, -3))
	main._service_auto_combat(0.0, 100)
	_check(main.fired_zones == [0], "ready front zone fires immediately")
	main.fired_zones.clear()
	main._service_auto_combat(0.0, 114)
	_check(main.fired_zones.is_empty(), "front zone waits the full 15-tick interval")
	_fixture(Vector2(3, 0))
	main._service_auto_combat(0.0, 114)
	_check(main.fired_zones == [1], "empty zone reacquires immediately while front cools down")
	main.fired_zones.clear()
	main._service_auto_combat(0.0, 115)
	_check(main.fired_zones == [0], "front fires exactly at the original cooldown boundary")
	main.fired_zones.clear()
	controls.editing = true
	main._service_auto_combat(0.0, 200)
	_check(main.fired_zones.is_empty(), "editing suppresses all acquisitions")
	controls.editing = false
	shooter.is_cloaked = true
	main._service_auto_combat(0.0, 200)
	_check(main.fired_zones.is_empty(), "cloak suppresses all acquisitions")
	main.free()
	world.free()
	if failures.is_empty():
		print("AUTO_TARGETING_TEST PASS differential_cases=360 crowded_rays=1/256")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _fixture(point: Vector2, visible_target: bool = true) -> Fixture:
	var target := Fixture.new()
	target.add_to_group("sprite_test_target")
	target.set_meta("visible", visible_target)
	main._targets.add_child(target)
	target.global_position = body.global_transform * Vector3(point.x, 0, point.y)
	return target

func _pick(zone: int = 0, reach: float = 8.0, width: float = PI / 2,
		tip: bool = false) -> Node3D:
	main.rays = 0
	main.setups = 0
	main.seen_query = null
	main.reused = true
	return main._acquire_target(body, zone, reach, width, tip)

func _reference(zone: int, reach: float, width: float, tip: bool) -> Node3D:
	var candidates: Array[Dictionary] = []
	var nodes: Array[Node] = []
	for container in [main._targets, main._balls]:
		for target in container.get_children():
			if container == main._targets and not main._combat_target_active(target):
				continue
			candidates.append({"id": nodes.size(),
				"local_position": COVERAGE.local_point(target.global_position, body.global_transform),
				"visible": target.get_meta("visible", true)})
			nodes.append(target)
	var selected := TARGETING.select_nearest(zone, reach, width, tip, candidates)
	return nodes[selected] as Node3D if selected >= 0 else null

func _clear() -> void:
	for container in [main._targets, main._balls]:
		for child in container.get_children():
			child.free()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
