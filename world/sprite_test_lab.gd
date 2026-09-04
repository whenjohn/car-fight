extends Node
## Opt-in, server-owned fixture family. No rollback histories or impulses.
const TARGET := preload("res://combat/sprite_target.gd")
var requested := false
var enabled := false
var owner_id := 1
var generation := 0
var count := 16
var body_scale := 1.0
var moving := true
var _main: Node3D
var _targets: Node3D
var _players: Node3D
var _previous_cars := {}
var _fixtures: Array = []
var _snapshot_clock := 0.0
var _started := false
var _window: Window
var _status: Label
var _host_controls: Array[Control] = []
var _resolution := 128
var _preview := "automatic"
var _direction := -1
var _rate := 1.0
var _paused := false
var _metrics_clock := 0.0
var _frame_times: Array[float] = []

func setup(main: Node3D, targets: Node3D, players: Node3D, start: bool) -> void:
	_main = main
	_targets = targets
	_players = players
	requested = start
	if OS.get_environment("CAR_FIGHT_SPRITE_VISUAL_CHECK") in ["1", "close"] and main.get("_role") == "offline":
		var check := Node.new()
		check.set_script(load("res://scripts/sprite_visual_check.gd"))
		add_child(check)
		check.call_deferred("run", self, main)

func service(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if requested and not _started and _players.get_child_count() > 0:
		_started = true
		owner_id = int(_players.get_child(0).name)
		configure(true, count, body_scale, moving)
	if not enabled:
		return
	for target in _fixtures:
		if target.health <= 0:
			continue
		var previous: Vector3 = target.position
		if target.walking:
			target.age += delta
			# Eight straight headings, each traversed for one second, form a loop.
			var sector := int(target.age) % 8
			target.heading = Vector3(sin(sector * PI / 4.0), 0, cos(sector * PI / 4.0))
			var finish: Vector3 = previous + target.heading * delta * 1.5
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = target.get_child(0).shape
			query.transform = Transform3D(Basis.IDENTITY, previous)
			query.motion = finish - previous
			query.collision_mask = 1
			query.exclude = _main.call("_combat_dynamic_rids")
			var space := _main.get_world_3d().direct_space_state
			if space.intersect_shape(query, 1).is_empty():
				var sweep := space.cast_motion(query)
				target.position = previous.lerp(finish, float(sweep[0]))
		for car in _players.get_children():
			var collision := car.get_node_or_null("Collision") as CollisionShape3D
			if collision == null or not collision.shape is CapsuleShape3D:
				continue
			var shape := collision.shape as CapsuleShape3D
			var current := collision.global_transform.orthonormalized()
			var before: Transform3D = _previous_cars.get(car.get_instance_id(), current)
			if TARGET.swept_vehicle_contact(before, current, shape.radius, shape.height,
					previous, target.position, target.radius(), target.height()):
				set_hits(target.target_id, 3)
				break
	_previous_cars.clear()
	for car in _players.get_children():
		var collision := car.get_node_or_null("Collision") as CollisionShape3D
		if collision != null:
			_previous_cars[car.get_instance_id()] = collision.global_transform.orthonormalized()
	_snapshot_clock += delta
	if _snapshot_clock >= 0.1:
		_snapshot_clock = 0.0
		# Keep each unreliable packet below ENet's MTU at the 64-target gate.
		var snapshot := states()
		for offset in range(0, snapshot.size(), 16):
			_sync_motion.rpc(generation, snapshot.slice(offset, offset + 16))

func configure(active: bool, amount: int, size: float, walk: bool) -> void:
	if not multiplayer.is_server():
		_request_configuration.rpc_id(1, active, amount, size, walk)
		return
	if not is_finite(size):
		return
	var anchor := Vector3(-63, 0, 94)
	var car := _players.get_node_or_null(str(owner_id)) as Node3D
	if car != null:
		anchor = car.position
	# Snap to the closest north/south road; keep inside the city footprint.
	anchor.x = roundf(anchor.x / 63.0) * 63.0
	anchor.x = clampf(anchor.x, -63.0, 63.0)
	anchor.z = clampf(anchor.z - 12.0, -45.0, 105.0)
	var spawn: Array = []
	var selected_count := amount if amount in [1, 16, 64] else 16
	var selected_scale := clampf(size, 0.5, 2.0)
	if active:
		for index in selected_count:
			var position := anchor + Vector3((index % 4 - 1.5) * 2.0, 0.9 * selected_scale + 0.08,
				-float(index / 4) * 2.5)
			spawn.append([10000 + index, position,
				Vector3.FORWARD.rotated(Vector3.UP, (index % 8) * PI / 4.0), 0, 0.0])
	_apply_configuration.rpc(generation + 1, active, selected_count, selected_scale, walk, owner_id, spawn)

@rpc("any_peer", "call_remote", "reliable")
func _request_configuration(active: bool, amount: int, size: float, walk: bool) -> void:
	if multiplayer.is_server() and requested and multiplayer.get_remote_sender_id() == owner_id:
		configure(active, amount, size, walk)

@rpc("authority", "call_local", "reliable")
func _apply_configuration(version: int, active: bool, amount: int, size: float,
		walk: bool, owner: int, snapshot: Array) -> void:
	if version < generation:
		return
	generation = version
	enabled = active
	count = amount
	body_scale = size
	moving = walk
	owner_id = owner
	for target in _fixtures:
		_targets.remove_child(target)
		target.queue_free()
	_fixtures.clear()
	_previous_cars.clear()
	for state in snapshot:
		var target := TARGET.new()
		target.setup(int(state[0]), size, not _main.call("_is_headless"))
		target.position = state[1]
		target.home = state[1]
		target.heading = state[2]
		target.age = float(state[4])
		target.walking = walk and int(state[0]) % 2 == 0
		_targets.add_child(target)
		target.set_hit_count(int(state[3]))
		_fixtures.append(target)
	print("SPRITE_TEST_STATE generation=%d count=%d owner=%d" % [generation, _fixtures.size(), owner_id])

func states() -> Array:
	var result: Array = []
	for target in _fixtures:
		result.append([target.target_id, target.position, target.heading, target.hit_count, target.age])
	return result

func send_state_to(peer_id: int) -> void:
	if generation > 0:
		_apply_configuration.rpc_id(peer_id, generation, enabled, count, body_scale, moving, owner_id, states())

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_motion(version: int, snapshot: Array) -> void:
	if version != generation:
		return
	for state in snapshot:
		var target := _targets.get_node_or_null("Target_%02d" % int(state[0]))
		if target != null and target.health > 0:
			target.network_position = state[1]
			target.heading = state[2]

func set_hits(id: int, hits: int) -> void:
	if not multiplayer.is_server():
		return
	var target := _targets.get_node_or_null("Target_%02d" % id)
	if target != null and target.health > 0:
		_apply_hits.rpc(generation, id, clampi(hits, 0, 3), target.position, target.heading)

@rpc("authority", "call_local", "reliable")
func _apply_hits(version: int, id: int, hits: int, position: Vector3, heading: Vector3) -> void:
	if version != generation:
		return
	var target := _targets.get_node_or_null("Target_%02d" % id)
	if target != null and hits > target.hit_count:
		target.register_hit()
		target.set_hit_count(hits)
		if target.health == 0:
			target.position = position
			target.heading = heading
		print("SPRITE_TEST_HIT id=%d health=%d" % [id, target.health])

func has_input_focus() -> bool:
	return _window != null and _window.visible and _window.has_focus()

func open() -> void:
	if _window == null:
		_build_window()
	_window.popup_centered(Vector2i(430, 580))

func _build_window() -> void:
	_window = Window.new()
	_window.title = "Sprite test"
	_window.visible = false
	_window.transient = true
	_window.force_native = true
	_window.close_requested.connect(func():
		_window.hide()
		get_tree().root.grab_focus())
	add_child(_window)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_top = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -16
	_window.add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	_button(root, "Enable / reset near car", func(): configure(true, count, body_scale, moving), true)
	_button(root, "Disable test", func(): configure(false, count, body_scale, moving), true)
	_option(root, "Targets", ["1", "16", "64"], 1, func(i):
		configure(enabled, [1, 16, 64][i], body_scale, moving), true)
	_spin(root, "Body scale (reset)", 0.5, 2.0, 0.25, 1.0, func(v):
		configure(enabled, count, v, moving), true)
	_option(root, "Movement (reset)", ["Stationary", "Mixed walking"], 1, func(i):
		configure(enabled, count, body_scale, i == 1), true)
	_option(root, "Resolution", ["128", "512"], 1 if _resolution == 512 else 0, func(i): _resolution = [128, 512][i])
	_option(root, "Preview", ["Automatic", "Idle", "Walk", "Attack", "Death"],
		["automatic", "idle", "walk", "attack", "death"].find(_preview), func(i):
		_preview = ["automatic", "idle", "walk", "attack", "death"][i])
	_option(root, "Facing", ["Camera-relative", "S", "SW", "W", "NW", "N", "NE", "E", "SE"], _direction + 1,
		func(i): _direction = i - 1)
	_spin(root, "Playback speed", 0.25, 3.0, 0.25, _rate, func(v): _rate = v)
	_button(root, "Pause / resume preview", func(): _paused = not _paused)
	_button(root, "Replay preview", func():
		for target in _fixtures:
			if target.visual != null and target.health > 0:
				target.visual.replay())
	_button(root, "Return to game", func(): get_tree().root.grab_focus())

func _button(root: Control, title: String, callback: Callable, host: bool = false) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	root.add_child(button)
	if host:
		_host_controls.append(button)

func _option(root: Control, title: String, options: Array, selected: int,
		callback: Callable, host: bool = false) -> void:
	var row := HBoxContainer.new()
	root.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 170
	row.add_child(label)
	var choice := OptionButton.new()
	for value in options:
		choice.add_item(value)
	choice.select(selected)
	choice.item_selected.connect(callback)
	row.add_child(choice)
	if host:
		choice.set_meta("setting", title)
		_host_controls.append(choice)

func _spin(root: Control, title: String, low: float, high: float, step: float,
		value: float, callback: Callable, host: bool = false) -> void:
	var row := HBoxContainer.new()
	root.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 170
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.value_changed.connect(callback)
	row.add_child(spin)
	if host:
		spin.set_meta("setting", title)
		_host_controls.append(spin)

func _process(delta: float) -> void:
	for target in _fixtures:
		if target.visual == null:
			continue
		var sprite = target.visual
		sprite.resolution = _resolution
		sprite.manual_direction = _direction
		sprite.playback_rate = _rate
		sprite.frozen = _paused and target.health > 0
		sprite.clip = "death" if target.health == 0 else _preview if _preview != "automatic" \
			else "walk" if target.walking else "idle"
	if _status != null:
		var can_control := multiplayer.is_server() or (generation > 0 and multiplayer.get_unique_id() == owner_id)
		_status.text = "%d targets · %dpx · 3 hits or one run-over\n%s" % [_fixtures.size(), _resolution,
			"Host controls available" if can_control else "Host must launch with --sprite-test"]
		for control in _host_controls:
			control.set_block_signals(true)
			match str(control.get_meta("setting", "")):
				"Targets":
					(control as OptionButton).select([1, 16, 64].find(count))
				"Movement (reset)":
					(control as OptionButton).select(1 if moving else 0)
				"Body scale (reset)":
					(control as SpinBox).value = body_scale
			control.set_block_signals(false)
			if control is BaseButton:
				control.disabled = not can_control
			elif control is SpinBox:
				control.editable = can_control
	if requested and not _main.call("_is_headless"):
		_metrics_clock += delta
		_frame_times.append(delta * 1000.0)
		if _metrics_clock >= 5.0:
			_frame_times.sort()
			print("SPRITE_TEST_METRICS count=%d resolution=%d median_ms=%.2f p95_ms=%.2f draws=%d texture_bytes=%d" % [
				_fixtures.size(), _resolution, _frame_times[_frame_times.size() / 2],
				_frame_times[int(_frame_times.size() * 0.95)],
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)])
			_metrics_clock = 0.0
			_frame_times.clear()
