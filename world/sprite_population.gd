extends Node
## Offline lab prototype: bounded births and corpse retention, not replicated.
const TARGET := preload("res://combat/sprite_target.gd")
const GOAL := 64
const LOW_WATER := 56
const INTERVAL := 0.25
const CORPSE_SECONDS := 5.0
const MAX_CORPSES := 16
const MAX_ATTEMPTS := 8
var lab
var enabled := false
var alive := 0
var corpses := 0
var spawned := 0
var blocked := 0
var refilling := false
var points: Array[Vector3] = []
var _deaths := {}
var _next_id := 10000
var _cursor := 0
var _clock := 0.0
var _elapsed := 0.0
var _query := PhysicsShapeQueryParameters3D.new()

func available() -> bool:
	return lab._main.get("_role") == "offline" and lab.ai.connected() \
		and multiplayer.multiplayer_peer is OfflineMultiplayerPeer

func set_enabled(value: bool) -> bool:
	if value and not available():
		return false
	if value == enabled:
		return true
	enabled = value
	if value:
		# An explicit UI reset, never a reset on individual replacement births.
		lab.configure(true, GOAL, lab.body_scale, lab.moving)
	else:
		refilling = false
	return true

func reset() -> void:
	enabled = enabled and lab.enabled and lab.count == GOAL and available()
	_deaths.clear()
	points.clear()
	_next_id = 10000
	_cursor = 0
	_clock = 0.0
	_elapsed = 0.0
	spawned = 0
	blocked = 0
	refilling = false
	alive = 0
	corpses = 0
	for target in lab._fixtures:
		_next_id = maxi(_next_id, target.target_id + 1)
		if target.health > 0:
			alive += 1
		else:
			corpses += 1
	if not enabled:
		return
	# Cache a spread of street spawn points once, not a city search every tick.
	var candidates: Array[Vector3] = lab.spawn_positions(Vector3.ZERO, 256, lab.body_scale)
	for index in range(0, candidates.size(), 4):
		points.append(candidates[index])
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = lab._fixtures[0].get_child(0).shape.duplicate()
	_query.collision_mask = 1 | 8

func service(delta: float) -> void:
	if not enabled:
		return
	if not available() or not lab.enabled or lab.count != GOAL:
		enabled = false
		refilling = false
		return
	_elapsed += delta
	_clock += delta
	if _clock < INTERVAL:
		return
	# At most one birth per service call; never accumulate overdue requests.
	_clock = 0.0
	alive = 0
	for target in lab._fixtures:
		if target.health > 0:
			alive += 1
		elif not _deaths.has(target.target_id):
			_deaths[target.target_id] = _elapsed
	# Dictionary insertion order removes oldest corpses first, including ties.
	for id in _deaths.keys():
		if _elapsed - float(_deaths[id]) >= CORPSE_SECONDS or _deaths.size() > MAX_CORPSES:
			_remove(id)
	corpses = _deaths.size()
	if alive < LOW_WATER:
		refilling = true
	if alive >= GOAL:
		refilling = false
	if not refilling or points.is_empty():
		return
	for attempt in mini(MAX_ATTEMPTS, points.size()):
		var position := points[_cursor]
		_cursor = (_cursor + 1) % points.size()
		if not _clear(position):
			blocked += 1
			continue
		_spawn(position)
		alive += 1
		refilling = alive < GOAL
		break

func _clear(position: Vector3) -> bool:
	for car in lab._players.get_children():
		if Vector2(position.x - car.position.x, position.z - car.position.z).length_squared() < 144.0:
			return false
	for target in lab._fixtures:
		if target.health > 0 and position.distance_to(target.position) < \
				float(_query.shape.radius) + target.radius() + 1.5:
			return false
	_query.transform = Transform3D(Basis.IDENTITY, position)
	return lab._main.get_world_3d().direct_space_state.intersect_shape(_query, 1).is_empty()

func _spawn(position: Vector3) -> void:
	var target := TARGET.new()
	target.setup(_next_id, lab.body_scale, not lab._main.call("_is_headless"))
	_next_id += 1
	target.position = position
	target.home = position
	target.heading = Vector3.FORWARD.rotated(Vector3.UP, (target.target_id % 8) * PI / 4.0)
	target.walking = lab.moving and target.target_id % 2 == 0
	if target.visual != null:
		target.visual.sample = lab._sample
	lab._targets.add_child(target)
	lab._fixtures.append(target)
	lab.ai.add_fixture(target)
	spawned += 1

func _remove(id: int) -> void:
	var target = lab._targets.get_node_or_null("Target_%02d" % id)
	if target != null:
		if lab.batch != null and target.visual != null:
			lab.batch.release_sprite(target.visual)
		lab.ai.forget_fixture(id)
		lab._fixtures.erase(target)
		lab._targets.remove_child(target)
		target.queue_free()
	_deaths.erase(id)

func status() -> String:
	if not enabled:
		return "Population: off (offline only)"
	return "Population: %d alive / 56–64 · %d corpses\n%s · %d replacements · %d blocked attempts" % [
		alive, corpses, "Refilling (max 4/sec)" if refilling else "Holding", spawned, blocked]
