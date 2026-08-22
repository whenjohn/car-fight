extends Node3D
## Server-authoritative, lightweight auto-pickups. Each dot is shared data and
## rendered through one mesh; it is never a physics body, collider, or rollback state.

const ARENA_CONFIG := preload("res://world/arena_config.gd")
const DOT_COUNT := 72
const DOT_ID_BASE := 700001
const DOT_RADIUS := 0.30
const DOT_HEIGHT := 0.055
const VACUUM_RADIUS := 4.8
const WALL_INSET := 5.0
const SPAWN_CLEAR_RADIUS := 7.0
const FLYIN_MS := 180.0
const PREDICTION_TIMEOUT := 1.0
const RING_SEGMENTS := 16

var _dots := {}
var _scores := {}
var _hidden := {}
var _flyins: Array[Dictionary] = []
var _next_id := DOT_ID_BASE
var _mesh: ImmediateMesh
var _fx_mesh: ImmediateMesh
var _material: StandardMaterial3D
var _field_dirty := true
var _draw_to: ImmediateMesh
var _vacuum_tell := 0.0
var _fx_active := false

func _ready() -> void:
	if not _is_headless():
		_build_render()
	var network_time := get_node_or_null("/root/NetworkTime")
	if network_time != null:
		network_time.connect("on_tick", _on_tick)

func generate() -> void:
	if not multiplayer.is_server():
		return
	_dots.clear()
	_scores.clear()
	_next_id = DOT_ID_BASE
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE
	for _index in DOT_COUNT:
		_dots[_next_id] = _random_spot(rng)
		_next_id += 1
	_field_dirty = true
	_broadcast_full()
	print("[dots] DOTS gen n=%d seed=0xC0FFEE" % DOT_COUNT)

func send_state_to(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var ids := PackedInt32Array()
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for id in _dots:
		ids.append(int(id))
		var pos: Vector3 = _dots[id]
		xs.append(pos.x)
		zs.append(pos.z)
	_dots_set.rpc_id(peer_id, ids, xs, zs)
	var peers := PackedInt32Array()
	var counts := PackedInt32Array()
	for id in _scores:
		peers.append(int(id))
		counts.append(int(_scores[id]))
	_scores_set.rpc_id(peer_id, peers, counts)

func collected_by(peer_id: int) -> int:
	return int(_scores.get(peer_id, 0))

func remaining() -> int:
	return _dots.size()

func _on_tick(_delta: float, _tick: int) -> void:
	if not multiplayer.is_server() or _dots.is_empty():
		return
	var players := get_parent().get_node_or_null("Players")
	if players == null:
		return
	var ids := PackedInt32Array()
	var collectors := PackedInt32Array()
	var radius_squared := VACUUM_RADIUS * VACUUM_RADIUS
	for id in _dots:
		var position: Vector3 = _dots[id]
		var best_id := -1
		var best_distance := radius_squared
		for body_node in players.get_children():
			var body := body_node as Node3D
			if body == null:
				continue
			var distance := body.global_position.distance_squared_to(position)
			if distance <= best_distance:
				best_distance = distance
				best_id = int(body.name)
		if best_id >= 0:
			ids.append(int(id))
			collectors.append(best_id)
	if not ids.is_empty():
		_dots_collect.rpc(ids, collectors)
		_collect_local(ids, collectors)

func _random_spot(rng: RandomNumberGenerator) -> Vector3:
	var limit := ARENA_CONFIG.HALF_EXTENT - WALL_INSET
	for _attempt in 12:
		var point := Vector3(rng.randf_range(-limit, limit), 0.0, rng.randf_range(-limit, limit))
		if point.length() >= SPAWN_CLEAR_RADIUS:
			return point
	return Vector3(limit, 0.0, limit)

func _broadcast_full() -> void:
	var ids := PackedInt32Array()
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for id in _dots:
		ids.append(int(id))
		var position: Vector3 = _dots[id]
		xs.append(position.x)
		zs.append(position.z)
	_dots_set.rpc(ids, xs, zs)

@rpc("authority", "reliable", "call_remote")
func _dots_set(ids: PackedInt32Array, xs: PackedFloat32Array, zs: PackedFloat32Array) -> void:
	_dots.clear()
	for index in ids.size():
		_dots[ids[index]] = Vector3(xs[index], 0.0, zs[index])
	_field_dirty = true

@rpc("authority", "reliable", "call_remote")
func _dots_collect(ids: PackedInt32Array, collectors: PackedInt32Array) -> void:
	_collect_local(ids, collectors)

@rpc("authority", "reliable", "call_remote")
func _scores_set(peers: PackedInt32Array, counts: PackedInt32Array) -> void:
	_scores.clear()
	for index in peers.size():
		_scores[peers[index]] = counts[index]

func _collect_local(ids: PackedInt32Array, collectors: PackedInt32Array) -> void:
	for index in ids.size():
		var id := ids[index]
		var position: Vector3 = _dots.get(id, Vector3.ZERO)
		var existed := _dots.erase(id)
		var predicted := _hidden.erase(id)
		if existed or predicted:
			_field_dirty = true
		if existed and not predicted:
			_start_flyin(position, collectors[index])
		var peer_id := collectors[index]
		_scores[peer_id] = int(_scores.get(peer_id, 0)) + 1

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		_predict(delta)
	if _mesh == null:
		return
	if _field_dirty:
		_field_dirty = false
		_rebuild_field()
	if _vacuum_tell > 0.001 or not _flyins.is_empty() or _fx_active:
		_rebuild_fx()

func _predict(delta: float) -> void:
	var me := _local_body()
	for id in _hidden.keys():
		_hidden[id] = float(_hidden[id]) + delta
		if float(_hidden[id]) > PREDICTION_TIMEOUT:
			_hidden.erase(id)
			_field_dirty = true
	var in_range := false
	if me != null:
		var radius_squared := VACUUM_RADIUS * VACUUM_RADIUS
		for id in _dots:
			if _hidden.has(id) or me.global_position.distance_squared_to(_dots[id]) > radius_squared:
				continue
			_hidden[id] = 0.0
			_field_dirty = true
			in_range = true
			_start_flyin(_dots[id], int(me.name))
	var target := 1.0 if in_range or _has_local_flyin(me) else 0.0
	_vacuum_tell = move_toward(_vacuum_tell, target, (12.0 if target > _vacuum_tell else 4.0) * delta)

func _has_local_flyin(me: Node3D) -> bool:
	if me == null:
		return false
	for flyin in _flyins:
		if int(flyin["pid"]) == int(me.name):
			return true
	return false

func _local_body() -> Node3D:
	var players := get_parent().get_node_or_null("Players")
	return null if players == null else players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D

func _start_flyin(from: Vector3, peer_id: int) -> void:
	if _mesh != null:
		_flyins.append({"from": from, "pid": peer_id, "started": float(Time.get_ticks_msec())})

func _display_position(peer_id: int, fallback: Vector3) -> Vector3:
	var players := get_parent().get_node_or_null("Players")
	var body := null if players == null else players.get_node_or_null(str(peer_id)) as Node3D
	return fallback if body == null else body.global_position

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _build_render() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = ImmediateMesh.new()
	var field := MeshInstance3D.new()
	field.name = "DotField"
	field.mesh = _mesh
	field.material_override = _material
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)
	_fx_mesh = ImmediateMesh.new()
	var fx := MeshInstance3D.new()
	fx.name = "DotFx"
	fx.mesh = _fx_mesh
	fx.material_override = _material
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fx)

func _rebuild_field() -> void:
	_mesh.clear_surfaces()
	if _dots.is_empty():
		return
	var visible_ids := []
	for id in _dots:
		if not _hidden.has(id):
			visible_ids.append(id)
	# During prediction/rejoin every remaining dot can briefly be hidden. Do not
	# ask ImmediateMesh to commit an empty surface; the next authoritative update
	# marks the field dirty and rebuilds the visible set.
	if visible_ids.is_empty():
		return
	_draw_to = _mesh
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for id in visible_ids:
		var point: Vector3 = _dots[id]
		point.y = DOT_HEIGHT
		_disc(point, DOT_RADIUS * 1.7, Color(1.0, 0.76, 0.18, 0.16))
		_disc(point, DOT_RADIUS * 0.86, Color(1.0, 0.88, 0.30, 1.0))
		_disc(point, DOT_RADIUS * 0.32, Color(1.0, 1.0, 0.92, 0.92))
	_mesh.surface_end()

func _rebuild_fx() -> void:
	_fx_mesh.clear_surfaces()
	var now := float(Time.get_ticks_msec())
	var active_flyins: Array[Dictionary] = []
	for flyin in _flyins:
		if (now - float(flyin["started"])) / FLYIN_MS < 1.0:
			active_flyins.append(flyin)
	_flyins = active_flyins
	var me := _local_body()
	var vacuum_visible := _vacuum_tell > 0.001 and me != null
	if not vacuum_visible and _flyins.is_empty():
		_fx_active = false
		return
	_fx_active = true
	_draw_to = _fx_mesh
	_fx_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	if vacuum_visible:
		var center := me.global_position
		center.y = DOT_HEIGHT
		_annulus(center, VACUUM_RADIUS, 0.07, Color(0.58, 0.86, 1.0, 0.14 * _vacuum_tell))
	_draw_flyins(now)
	_fx_mesh.surface_end()

func _draw_flyins(now: float) -> void:
	var keep: Array[Dictionary] = []
	for flyin in _flyins:
		var t := clampf((now - float(flyin["started"])) / FLYIN_MS, 0.0, 1.0)
		var target := _display_position(int(flyin["pid"]), flyin["from"])
		if t >= 1.0:
			continue
		keep.append(flyin)
		var point: Vector3 = (flyin["from"] as Vector3).lerp(target, t * t)
		point.y = DOT_HEIGHT
		_disc(point, DOT_RADIUS * (1.0 - 0.45 * t), Color(1.0, 0.88, 0.30, 1.0 - 0.3 * t))
		_disc(point, DOT_RADIUS * 0.30, Color.WHITE)
	_flyins = keep

func _annulus(center: Vector3, radius: float, width: float, color: Color) -> void:
	var inner := radius - width * 0.5
	var outer := radius + width * 0.5
	for index in range(RING_SEGMENTS * 3):
		var a0 := TAU * float(index) / float(RING_SEGMENTS * 3)
		var a1 := TAU * float(index + 1) / float(RING_SEGMENTS * 3)
		var p0 := Vector3(cos(a0), 0.0, sin(a0))
		var p1 := Vector3(cos(a1), 0.0, sin(a1))
		_tri(center + p0 * inner, center + p0 * outer, center + p1 * outer, color)
		_tri(center + p0 * inner, center + p1 * outer, center + p1 * inner, color)

func _disc(center: Vector3, radius: float, color: Color) -> void:
	for index in RING_SEGMENTS:
		_tri(center, center + _radial(index) * radius, center + _radial(index + 1) * radius, color)

func _radial(index: int) -> Vector3:
	var angle := TAU * float(index) / float(RING_SEGMENTS)
	return Vector3(cos(angle), 0.0, sin(angle))

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_draw_to.surface_set_color(color)
	_draw_to.surface_add_vertex(a)
	_draw_to.surface_set_color(color)
	_draw_to.surface_add_vertex(b)
	_draw_to.surface_set_color(color)
	_draw_to.surface_add_vertex(c)
