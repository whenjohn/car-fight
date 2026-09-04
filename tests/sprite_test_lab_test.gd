extends SceneTree
const TARGET := preload("res://combat/sprite_target.gd")
const VISUAL := preload("res://fx/directional_sprite.gd")
const LAB := preload("res://world/sprite_test_lab.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for size in [1.0, 2.0]:
		var positions := LAB.spawn_positions(Vector3.ZERO, 256, size)
		_check(positions.size() == 256, "spread layout fills maximum count")
		for index in positions.size():
			var position := positions[index]
			_check(absf(position.x) <= 84.0 and absf(position.z) <= 84.0, "layout stays in city")
			_check(Vector2(position.x, position.z).length() >= 6.0, "spawn keeps car clear")
			for other in range(index):
				_check(position.distance_to(positions[other]) >= 4.0, "fixtures spread at least four units apart")
	for index in 8:
		var facing := Vector3.FORWARD.rotated(Vector3.UP, index * PI / 4.0)
		_check(VISUAL.direction_index(facing, facing) == 0, "toward camera selects S")
		_check(VISUAL.direction_index(facing, -facing) == 4, "away selects N")
	_check(VISUAL.direction_index(Vector3.FORWARD, Vector3.FORWARD.rotated(Vector3.UP, TAU)) == 0, "angle wraps")
	_check(VISUAL.direction_index(Vector3.RIGHT, Vector3.BACK) == 6, "east faces screen right")
	_check(VISUAL.direction_index(Vector3.LEFT, Vector3.BACK) == 2, "west faces screen left")
	for size in [128, 512]:
		for action in ["idle", "walk", "attack", "death"]:
			for direction in VISUAL.DIRECTIONS:
				var base := "res://assets/sprites/ghoul/%d/%s/%s" % [size, action, direction]
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + "/frames.json"))
				_check(data is Dictionary and not data["frames"].is_empty(), "complete clip " + base)
				if data is Dictionary:
					for frame in data["frames"]:
						_check(ResourceLoader.exists(base.path_join("%02d.png" % int(frame[0]))), "atlas exists")
	var target := TARGET.new()
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	var sprite := VISUAL.new()
	stage.add_child(sprite)
	sprite.manual_direction = 0
	sprite._process(0.0)
	_check(sprite.sprite_frames.get_frame_texture("default", 0).get_size() == Vector2(128, 128), "atlas margins restore full canvas")
	sprite.set_frame_and_progress(7, 0.4)
	sprite.manual_direction = 6
	sprite._process(0.0)
	_check(sprite.frame == 7 and is_equal_approx(sprite.frame_progress, 0.4), "direction change preserves progress")
	var width := sprite.pixel_size * 128.0
	sprite.resolution = 512
	sprite._process(0.0)
	_check(is_equal_approx(sprite.pixel_size * 512.0, width), "resolution preserves world size")
	sprite.clip = "death"
	sprite._process(0.0)
	sprite.set_frame_and_progress(68, 1.0)
	sprite.pause()
	sprite.manual_direction = 4
	sprite._process(0.0)
	_check(sprite.frame == 68 and not sprite.is_playing(), "finished death survives direction change")
	sprite.replay()
	_check(sprite.frame == 0 and sprite.is_playing(), "explicit replay restarts preview")
	_check(not VISUAL.sample_available("missing-sample"), "unknown sample rejected")
	_check(VISUAL.load_clip(128, "idle", 0, "missing-sample") != null, "missing sample falls back to ghoul")
	for character in ["survivor", "thug"]:
		if not VISUAL.sample_available(character):
			print("SPRITE_SAMPLE_SKIP local art absent: ", character)
			continue
		var native := VISUAL.native_size(character)
		var frame_count := 14 if character == "survivor" else 8
		for action in ["idle", "walk", "attack", "death"]:
			for direction in 8:
				var frames := VISUAL.load_clip(512, action, direction, character)
				_check(frames != null and frames.get_frame_count("default") == frame_count, "modern complete clip")
				_check(frames == VISUAL.load_clip(128, action, direction, character), "modern frames shared; ghoul resolution ignored")
				_check(frames.get_animation_loop("default") == (action in ["idle", "walk"]), "modern loop policy")
				var texture := frames.get_frame_texture("default", 0) as AtlasTexture
				_check(texture.region == Rect2(0, VISUAL.MODERN_ROWS[direction] * native, native, native), "modern source row mapping")
		sprite.clip = "death"
		sprite.sample = character
		sprite._process(0.0)
		sprite.set_frame_and_progress(frame_count - 1, 1.0)
		sprite.pause()
		sprite.manual_direction = 2
		sprite._process(0.0)
		_check(sprite.frame == frame_count - 1 and not sprite.is_playing(), "modern death holds across direction changes")
		_check(is_equal_approx(sprite.pixel_size * native * 44.0 / 128.0, 1.8), "modern standing height")
	# A dead fixture stays on the final frame when changing character packs.
	if VISUAL.sample_available("survivor") and VISUAL.sample_available("thug"):
		sprite.sample = "survivor"
		sprite._process(0.0)
		_check(sprite.frame == 13 and not sprite.is_playing(), "character switch preserves completed death")
	stage.free()
	target.setup(10000, 1.0, false)
	root.add_child(target)
	_check(target.segment_entry(Vector3(-10, 0, 0), Vector3(10, 0, 0)) < 0.5, "swept shot hits capsule")
	_check(target.segment_entry(Vector3(-10, 3, 0), Vector3(10, 3, 0)) > 1.0, "shot above misses")
	for _hit in 2:
		target.register_hit()
	_check(target.health == 1 and target.collision_layer == 8, "two hits remain alive")
	target.register_hit()
	target.register_hit()
	_check(target.health == 0 and target.hit_count == 3 and target.collision_layer == 0, "death is idempotent and removes hitbox")
	_check(target.segment_entry(Vector3(-10, 0, 0), Vector3(10, 0, 0)) > 1.0, "dead target misses")
	var from := Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-20, 0, 0))
	var to := Transform3D(from.basis, Vector3(20, 0, 0))
	_check(TARGET.swept_vehicle_contact(from, to, 0.6, 3.0, Vector3.ZERO, Vector3.ZERO, 0.35, 1.8), "fast crossing hits")
	_check(not TARGET.swept_vehicle_contact(from, to, 0.6, 3.0, Vector3(0, 5, 0), Vector3(0, 5, 0), 0.35, 1.8), "airborne car separation misses")
	var parked := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	_check(not TARGET.swept_vehicle_contact(parked, parked, 0.5, 2.0, Vector3(1.4, 0, 0), Vector3(1.4, 0, 0), 0.35, 1.8), "small car misses")
	_check(TARGET.swept_vehicle_contact(parked, parked, 1.1, 4.0, Vector3(1.4, 0, 0), Vector3(1.4, 0, 0), 0.35, 1.8), "scaled car hits")
	var main := Node3D.new()
	root.add_child(main)
	var targets := Node3D.new()
	main.add_child(targets)
	var players := Node3D.new()
	main.add_child(players)
	var lab := LAB.new()
	main.add_child(lab)
	lab.setup(main, targets, players, false)
	# Empty snapshots exercise generation fencing without building presentation.
	lab._apply_configuration(2, false, 16, 1.0, false, 1, [])
	lab._apply_configuration(1, true, 64, 1.0, true, 1, [])
	_check(lab.generation == 2 and not lab.enabled, "stale reset ignored")
	target.free()
	main.free()
	if failures.is_empty():
		print("SPRITE_TEST_LAB_TEST PASS")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
