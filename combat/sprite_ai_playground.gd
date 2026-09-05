extends Node
## Server simulation + event-only shot presentation for the opted-in lab.
const BRAIN := preload("res://combat/sprite_ai_brain.gd")
const NAV := preload("res://world/sprite_ai_navigation.gd")
const CONNECTION := preload("res://net/connection_state.gd")
const MODES := ["legacy", "basic", "attacker", "evader", "ambusher", "mixed"]
const MAX_PAYLOAD := 1000
var mode := "legacy"
var settings := {"speed": 3.0, "detection": 32.0, "interval": 1.0, "auto_fire": false}
var lab
var brains := {}
var routes := {}
var pending := {}
var navs := {}
var shots := {}
var visuals := {}
var labels := {}
var markers := {}
var show_debug := false
var metrics := {"cpu_us": 0, "ticks": 0, "jobs": 0, "max_jobs": 0,
	"max_pending": 0, "shots": 0, "hits": 0, "messages": 0, "bytes": 0,
	"max_payload": 0, "active_peak": 0}
var _events: Array = []
var _next_shot := 1
var _clock := 0.0
var _tick := 0
# Movement queries run synchronously, so one object can serve all fixtures.
# Replace exclusions once per tick, not once per moving sprite. Assign a new
# list when exclusions change (including tests); do not mutate it in place.
var _move_query := PhysicsShapeQueryParameters3D.new()
var _excluded: Array[RID] = []:
	set(value):
		_excluded = value
		_move_query.exclude = value
var _last_spawn := 0
var _present_shots := {}
var _settings_version := -1
var _was_connected := false
var spacing := {}
var _spacing_clock := 0.0
var _debug_clock := 0.0
const DEBUG_LIMIT := 16

func setup(owner_lab: Node) -> void:
	lab = owner_lab
	multiplayer.server_disconnected.connect(_disconnected)
	multiplayer.peer_disconnected.connect(_peer_left)
	var selected := OS.get_environment("CAR_FIGHT_SPRITE_AI")
	if selected in MODES:
		mode = selected

func connected() -> bool:
	return CONNECTION.has_connected_peer(multiplayer)

func active() -> bool:
	return connected() and lab.enabled and mode != "legacy"

func suppress_auto_fire() -> bool:
	return active() and not settings.auto_fire

func configure(value: String, speed: float, detection: float, interval: float, auto_fire: bool) -> void:
	if not connected() or value not in MODES or not is_finite(speed) \
			or not is_finite(detection) or not is_finite(interval):
		return
	if not multiplayer.is_server():
		_request.rpc_id(1, value, speed, detection, interval, auto_fire)
		return
	_apply_settings.rpc(lab.generation + 1, value, {"speed": clampf(speed, 0.5, 8.0),
		"detection": clampf(detection, 8.0, 48.0), "interval": clampf(interval, 0.5, 3.0),
		"auto_fire": auto_fire})
	lab.configure(lab.enabled, lab.count, lab.body_scale, lab.moving)

@rpc("any_peer", "call_remote", "reliable")
func _request(value: String, speed: float, detection: float, interval: float, auto_fire: bool) -> void:
	if connected() and multiplayer.is_server() and lab.requested \
			and multiplayer.get_remote_sender_id() == lab.owner_id:
		configure(value, speed, detection, interval, auto_fire)

@rpc("authority", "call_local", "reliable")
func _apply_settings(version: int, value: String, values: Dictionary) -> void:
	if version < lab.generation or version <= _settings_version:
		return
	_settings_version = version
	mode = value
	settings = values
	reset()

func reset() -> void:
	# Release the last fixture's shape and obsolete body exclusions on reset.
	_move_query = PhysicsShapeQueryParameters3D.new()
	_excluded = []
	_debug_clock = 0.0
	spacing.clear()
	_spacing_clock = 0.0
	brains.clear()
	routes.clear()
	pending.clear()
	shots.clear()
	_present_shots.clear()
	_last_spawn = 0
	_events.clear()
	for container in [visuals, labels, markers]:
		for node in container.values():
			if is_instance_valid(node):
				node.queue_free()
		container.clear()
	_clock = 0.0
	_tick = 0
	for target in lab._fixtures:
		add_fixture(target)

func add_fixture(target) -> void:
	var profile: String = BRAIN.PROFILES[(target.target_id - 10000) % 4] if mode == "mixed" else mode
	var state := BRAIN.initial(target.target_id, profile, target.home)
	state["perception"] = float(target.target_id % 12) / 60.0
	state["route_clock"] = 0.0
	state["car"] = {}
	state["decision"] = {"destination": target.position, "speed": 0.0, "state": "idle"}
	brains[target.target_id] = state
	if connected() and multiplayer.is_server():
		target.ai_profile = profile
		target.ai_state = "idle"
		target.attack_serial = 0

func forget_fixture(id: int) -> void:
	for container in [brains, routes, pending, spacing]:
		container.erase(id)
	if labels.has(id):
		labels[id].queue_free()
		labels.erase(id)
	for key in markers.keys():
		if int(str(key).get_slice(":", 0)) == id:
			markers[key].queue_free()
			markers.erase(key)

func _disconnected() -> void:
	_settings_version = -1
	reset()
	lab.retire()

func _peer_left(id: int) -> void:
	if not connected() or not multiplayer.is_server() or id != lab.owner_id:
		return
	var peers := multiplayer.get_peers()
	peers.sort()
	if peers.is_empty():
		lab.configure(false, lab.count, lab.body_scale, lab.moving)
		lab._started = false
	else:
		lab.owner_id = peers[0]
		_owner.rpc(lab.generation, peers[0])

@rpc("authority", "call_local", "reliable")
func _owner(version: int, id: int) -> void:
	if version == lab.generation:
		lab.owner_id = id

func send_state_to(peer_id: int) -> void:
	if not connected() or not multiplayer.is_server():
		return
	_apply_settings.rpc_id(peer_id, lab.generation, mode, settings)
	var entries: Array = []
	for id in shots:
		var shot: Dictionary = shots[id]
		entries.append(["spawn", id, shot.position, shot.velocity, shot.age])
	_send_events(entries, peer_id)

func _navigation(target) -> RefCounted:
	var key := snappedf(target.radius(), 0.001)
	if not navs.has(key):
		# Reset drops obsolete size caches rather than retaining an unbounded set.
		navs.clear()
		var nav := NAV.new()
		nav.setup(key, true)
		navs[key] = nav
	return navs[key]

func begin(delta: float) -> void:
	if not active() or not multiplayer.is_server():
		return
	_clock += delta
	_tick += 1
	_excluded = lab._main.call("_combat_dynamic_rids")
	var start := Time.get_ticks_usec()
	var nav: RefCounted = null
	if not lab._fixtures.is_empty():
		nav = _navigation(lab._fixtures[0])
		if not nav.ready:
			nav.advance(512)
	var cars := _cars()
	_spacing_clock -= delta
	if _spacing_clock <= 0.0:
		_spacing_clock = 0.2
		_refresh_spacing()
	for target in lab._fixtures:
		if target.health <= 0:
			pending.erase(target.target_id)
			continue
		var state: Dictionary = brains[target.target_id]
		state.perception -= delta
		state.route_clock = maxf(0, state.route_clock - delta)
		if state.perception > 0:
			continue
		state.perception += 0.2
		var car := _observe(target, state, cars)
		state.car = car
		var decision := BRAIN.decide(state, target.position, car, 0.2, settings)
		state.decision = decision
		target.ai_state = decision.state
		if decision.seek_cover:
			pending[target.target_id] = {"cover": true, "destination": decision.destination}
		elif target.position.distance_to(decision.destination) > 0.6 and state.route_clock <= 0:
			pending[target.target_id] = {"cover": false, "destination": decision.destination}
		if decision.fire and not car.is_empty() and car.visible:
			_fire(target, car.position)
		if decision.state in ["aim", "fire", "watch"] and not car.is_empty():
			target.heading = BRAIN.planar(target.position, state.last_seen).normalized()
	var jobs := 0
	for id in pending.keys():
		if jobs == 4 or nav == null or not nav.ready:
			break
		var target = lab._targets.get_node_or_null("Target_%02d" % id)
		var request: Dictionary = pending[id]
		pending.erase(id)
		if target == null or target.health <= 0:
			continue
		jobs += 1
		var state: Dictionary = brains[id]
		state.route_clock = 0.5
		if request.cover:
			_find_cover(target, state, nav)
		else:
			routes[id] = nav.route(target.position, request.destination)
	metrics.jobs += jobs
	metrics.max_jobs = maxi(metrics.max_jobs, jobs)
	metrics.max_pending = maxi(metrics.max_pending, pending.size())
	metrics.cpu_us += Time.get_ticks_usec() - start
	metrics.ticks += 1

func _cars() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for car in lab._players.get_children():
		var id := int(car.name)
		if id != 1 and not id in multiplayer.get_peers():
			continue
		var input: Node = car.get_node_or_null("Input")
		if input == null or bool(input.get("editing")) or bool(car.get("is_cloaked")) \
				or bool(car.get("rc_pilot_active")) or int(car.get("map_id")) != 0:
			continue
		var collider := car.get_node_or_null("Collision") as CollisionShape3D
		var clearance := 2.5
		if collider != null and collider.shape is CapsuleShape3D:
			clearance = collider.shape.height * 0.5 + 0.7
		result.append({"id": id, "position": car.global_position,
			"velocity": car.linear_velocity, "clearance": clearance})
	result.sort_custom(func(a, b): return a.id < b.id)
	return result

func _observe(target, state: Dictionary, cars: Array[Dictionary]) -> Dictionary:
	var chosen: Dictionary = {}
	if state.profile in ["attacker", "ambusher"]:
		var nearest := INF
		for car in cars:
			var distance: float = target.position.distance_squared_to(car.position)
			if int(car.id) == int(state.target):
				chosen = car.duplicate()
				break
			if distance < nearest:
				nearest = distance
				chosen = car.duplicate()
		state.target = chosen.get("id", 0)
		if not chosen.is_empty():
			# Range filtering bounds ray work even when the hunter pursues across
			# the whole city. Existing eligible-player filtering still applies.
			# Ambushers prepare against the eligible car even before sight.
			# Their hiding check needs real occlusion, not a range-based false.
			chosen.visible = (state.profile == "ambusher" or target.position.distance_squared_to(chosen.position) <= 18.0 * 18.0) \
				and _visible(target.position, chosen.position)
		return chosen
	var best := float(settings.detection) * float(settings.detection)
	for car in cars:
		var distance: float = target.position.distance_squared_to(car.position)
		if distance > best and int(car.id) != int(state.target):
			continue
		var visible: bool = distance <= settings.detection * settings.detection and _visible(target.position, car.position)
		if int(car.id) == int(state.target) and (visible or state.lost < 3.0 \
				or (state.profile == "ambusher" and state.cover != Vector3.INF)):
			chosen = car.duplicate()
			chosen.visible = visible
			return chosen
		if visible and distance < best:
			best = distance
			chosen = car.duplicate()
			chosen.visible = true
	state.target = chosen.get("id", 0)
	return chosen

func _visible(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = _excluded
	return lab._main.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _find_cover(target, state: Dictionary, nav) -> void:
	if state.car.is_empty():
		return
	var candidates: Array[Dictionary] = nav.cover_candidates(target.position, 64.0)
	candidates.sort_custom(func(a, b): return target.position.distance_squared_to(a.cover) < target.position.distance_squared_to(b.cover))
	# Progress through a bounded slice. No all-candidates path/ray burst for
	# every sprite on the first tick, and no requirement for a visible peek.
	for attempt in mini(4, candidates.size()):
		var pair: Dictionary = candidates[int(state.cover_cursor) % candidates.size()]
		state.cover_cursor = (int(state.cover_cursor) + 1) % candidates.size()
		var route: PackedVector3Array = nav.route(target.position, pair.cover)
		if route.is_empty():
			continue
		# Use reached grid cells, not unverified ideal corner coordinates.
		var cover: Vector3 = route[-1]
		if not _position_clear(target, cover) or _visible(cover, state.car.position):
			continue
		state.cover = cover
		state.peek = Vector3.INF
		state.hidden = 0.0
		state.state = "cover"
		routes[target.target_id] = route
		return

func _position_clear(target, position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = target.get_child(0).shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 1
	query.exclude = _excluded
	return lab._main.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _refresh_spacing() -> void:
	spacing.clear()
	var hunters: Array = []
	var gap := 2.5
	for target in lab._fixtures:
		if target.health > 0 and brains[target.target_id].profile == "attacker":
			hunters.append(target)
			gap = maxf(gap, target.radius() * 2.0 + 1.5)
	# Snapshot positions once at 5 Hz. At most 16 representatives per cell
	# bound each query to 9 * 16 candidates even in a fully stacked crowd.
	var cells := {}
	for target in hunters:
		var cell := Vector2i(floori(target.position.x / gap), floori(target.position.z / gap))
		if not cells.has(cell):
			cells[cell] = []
		if cells[cell].size() < 16:
			cells[cell].append({"id": target.target_id, "position": target.position})
	for target in hunters:
		var cell := Vector2i(floori(target.position.x / gap), floori(target.position.z / gap))
		var push := Vector3.ZERO
		for x in range(-1, 2):
			for z in range(-1, 2):
				for other in cells.get(cell + Vector2i(x, z), []):
					if other.id == target.target_id:
						continue
					var away := BRAIN.planar(other.position, target.position)
					var distance := away.length()
					if distance >= gap:
						continue
					if distance < 0.001:
						var angle := float((other.id + target.target_id) * 137 % 360) * PI / 180.0
						away = Vector3(cos(angle), 0, sin(angle)) * (1.0 if target.target_id < other.id else -1.0)
					else:
						away /= distance
					push += away * (1.0 - distance / gap)
		spacing[target.target_id] = push.limit_length(1.0)

func move(target, delta: float) -> Vector3:
	var previous: Vector3 = target.position
	var state: Dictionary = brains[target.target_id]
	var decision: Dictionary = state.decision
	if pending.has(target.target_id):
		target.walking = false
		return previous
	var separation: Vector3 = spacing.get(target.target_id, Vector3.ZERO)
	var route: PackedVector3Array = routes.get(target.target_id, PackedVector3Array())
	while not route.is_empty() and previous.distance_to(route[0]) < 0.5:
		route.remove_at(0)
	routes[target.target_id] = route
	var direction := Vector3.ZERO
	if previous.distance_to(decision.destination) >= 0.6 and not route.is_empty():
		direction = BRAIN.planar(previous, route[0]).limit_length(1.0)
		# Fade near waypoints so personality does not prevent corner arrival.
		var fade := clampf(previous.distance_to(route[0]) / 2.0, 0.0, 1.0)
		direction = direction.rotated(Vector3.UP, float(decision.get("steer", 0.0)) * fade)
	# Soft spacing, not rigid crowd collision: hunters can squeeze through
	# passages. Existing world sweeps still validate the combined movement.
	direction += separation * 1.4
	if direction.length_squared() < 0.0025:
		target.walking = false
		return previous
	var step := direction.limit_length(float(decision.speed) * delta)
	if state.profile == "attacker":
		# Fade the correction near the preferred gap instead of taking a
		# full-speed step for even a tiny separation signal.
		step = direction.limit_length(1.0) * float(decision.speed) * delta
	var query := _move_query
	query.shape = target.get_child(0).shape
	query.transform = Transform3D(Basis.IDENTITY, previous)
	query.motion = step
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = lab._main.get_world_3d().direct_space_state
	var finish := previous
	if space.intersect_shape(query, 1).is_empty():
		finish += step * float(space.cast_motion(query)[0])
	if finish.distance_squared_to(previous) < 0.000001:
		routes.erase(target.target_id)
		target.walking = false
	else:
		if decision.state != "fire":
			target.heading = direction.normalized()
		target.walking = true
	return finish

func _fire(target, aim: Vector3) -> void:
	var cap: int = lab.count * (ceili(2.0 / settings.interval) + 1)
	if shots.size() >= cap or not _visible(target.position, aim):
		return
	var origin: Vector3 = target.position
	var velocity := (aim - origin).normalized() * 22.0
	var id := _next_shot
	_next_shot += 1
	shots[id] = {"position": origin, "velocity": velocity, "age": 0.0}
	target.attack_serial += 1
	_events.append(["spawn", id, origin, velocity, 0.0])
	metrics.shots += 1
	metrics.active_peak = maxi(metrics.active_peak, shots.size())

func finish(delta: float) -> void:
	if not active() or not multiplayer.is_server():
		return
	for id in shots.keys():
		var shot: Dictionary = shots[id]
		var start: Vector3 = shot.position
		var end: Vector3 = start + shot.velocity * delta
		var fraction := 1.01
		var hit_car := false
		var query := PhysicsRayQueryParameters3D.create(start, end, 1)
		query.exclude = _excluded
		var wall: Dictionary = lab._main.get_world_3d().direct_space_state.intersect_ray(query)
		if not wall.is_empty():
			fraction = start.distance_to(wall.position) / maxf(start.distance_to(end), 0.0001)
		for car in lab._players.get_children():
			var collision: float = lab._main.call("_segment_player_entry", start, end, car)
			if collision < fraction:
				fraction = collision
				hit_car = true
		shot.position = end
		shot.age += delta
		if fraction <= 1.0 or shot.age >= 2.0:
			if hit_car:
				metrics.hits += 1
			_events.append(["end", id, start.lerp(end, minf(fraction, 1.0)), Vector3.ZERO, 1.0 if hit_car else 0.0])
			shots.erase(id)
	_send_events(_events)
	_events.clear()

static func batches(entries: Array) -> Array:
	var result: Array = []
	var batch: Array = []
	for entry in entries:
		var candidate := batch.duplicate()
		candidate.append(entry)
		# Reserve 100 bytes for generation/tick/chunk metadata and RPC framing.
		if var_to_bytes(candidate).size() > MAX_PAYLOAD - 160 and not batch.is_empty():
			result.append(batch)
			batch = []
		batch.append(entry)
	if not batch.is_empty():
		result.append(batch)
	return result

func record_payload(category: String, args: Array, recipients: int) -> void:
	var size := var_to_bytes(args).size()
	metrics.max_payload = maxi(metrics.max_payload, size)
	metrics.messages += recipients
	metrics.bytes += size * recipients
	var performance := get_node_or_null("/root/NetworkPerformance")
	if performance != null:
		performance.record_app_message("out", category, args, recipients)

func _send_events(entries: Array, peer_id: int = 0) -> void:
	for batch in batches(entries):
		if peer_id > 0:
			record_payload("sprite_ai_events", [lab.generation, batch], 1)
			_events_received.rpc_id(peer_id, lab.generation, batch)
		else:
			record_payload("sprite_ai_events", [lab.generation, batch], multiplayer.get_peers().size())
			_events_received.rpc(lab.generation, batch)

@rpc("authority", "call_local", "reliable")
func _events_received(version: int, entries: Array) -> void:
	if version != lab.generation or not lab.enabled:
		return
	for entry in entries:
		var id := int(entry[1])
		if entry[0] == "spawn":
			if id <= _last_spawn:
				continue
			_last_spawn = id
			_present_shots[id] = true
			if not multiplayer.is_server():
				metrics.shots += 1
				shots[id] = {"position": entry[2], "velocity": entry[3], "age": entry[4]}
			if not lab._main.call("_is_headless") and not visuals.has(id):
				visuals[id] = _dot(entry[2], Color.ORANGE, 0.09)
		else:
			if not _present_shots.has(id):
				continue
			_present_shots.erase(id)
			if not multiplayer.is_server():
				if entry[4] > 0:
					metrics.hits += 1
				shots.erase(id)
			if visuals.has(id):
				visuals[id].queue_free()
				visuals.erase(id)
			if not lab._main.call("_is_headless"):
				var flash := _dot(entry[2], Color.YELLOW if entry[4] > 0 else Color.GRAY, 0.22)
				var tween := flash.create_tween()
				tween.tween_property(flash, "scale", Vector3.ZERO, 0.15)
				tween.tween_callback(flash.queue_free)

func _dot(position: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	sphere.radial_segments = 6
	sphere.rings = 3
	node.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = position
	return node

func _process(delta: float) -> void:
	var ready := connected()
	if _was_connected and not ready:
		_disconnected()
	_was_connected = ready
	if not active():
		return
	for id in shots.keys():
		var shot: Dictionary = shots[id]
		if not multiplayer.is_server():
			shot.position += shot.velocity * delta
			shot.age += delta
		if visuals.has(id):
			visuals[id].global_position = shot.position
		if not multiplayer.is_server() and shot.age > 2.5:
			shots.erase(id)
			if visuals.has(id):
				visuals[id].queue_free()
				visuals.erase(id)
	_debug_clock -= delta
	if not show_debug:
		for container in [labels, markers]:
			for node in container.values():
				node.queue_free()
			container.clear()
		_debug_clock = 0.0
		return
	if _debug_clock > 0.0 or lab._main.call("_is_headless"):
		return
	_debug_clock = 0.2
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var selected := debug_targets(camera.global_position)
	var selected_ids := {}
	for target in selected:
		selected_ids[target.target_id] = true
	for id in labels.keys():
		if not selected_ids.has(id):
			labels[id].queue_free()
			labels.erase(id)
	for key in markers.keys():
		if not selected_ids.has(int(str(key).get_slice(":", 0))):
			markers[key].queue_free()
			markers.erase(key)
	for target in selected:
		var id: int = target.target_id
		if not labels.has(id):
			var label := Label3D.new()
			label.font_size = 28
			label.pixel_size = 0.015
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			add_child(label)
			labels[id] = label
		if labels.has(id):
			labels[id].visible = show_debug and target.health > 0
			labels[id].global_position = target.global_position + Vector3.UP * (target.height() * 0.5 + 0.3)
			var caption: String = target.ai_profile + " / " + target.ai_state
			if labels[id].text != caption:
				labels[id].text = caption
			# Destinations are server debug facts; clients show replicated state
			# labels without inventing routes from smoothed presentation.
			if multiplayer.is_server() and show_debug and brains.has(id):
				for kind in ["destination", "cover", "peek"]:
					var key := "%d:%s" % [id, kind]
					var point: Vector3 = brains[id].decision.destination if kind == "destination" else brains[id][kind]
					if point == Vector3.INF and not markers.has(key):
						continue
					if not markers.has(key):
						markers[key] = _dot(target.position, Color.CYAN if kind == "destination" else Color.GREEN, 0.16)
					markers[key].visible = point != Vector3.INF and target.health > 0
					if point != Vector3.INF:
						markers[key].global_position = point

func debug_targets(origin: Vector3) -> Array:
	var candidates: Array = []
	for target in lab._fixtures:
		if target.health > 0:
			candidates.append(target)
	candidates.sort_custom(func(a, b):
		var da: float = a.position.distance_squared_to(origin)
		var db: float = b.position.distance_squared_to(origin)
		return a.target_id < b.target_id if da == db else da < db)
	return candidates.slice(0, DEBUG_LIMIT)
