extends Control
## Client-local rim awareness.  This deliberately marks only the nearest few
## opposing cars plus the city ball: dots, bolts, troops, targets, and scenery
## are plentiful enough that marking them would turn the rim into decoration.

const KIND_PLAYER := 0
const PLAYER_PARTICIPATION := preload("res://net/player_participation.gd")
const KIND_BALL := 1
const MAX_PLAYER_MARKERS := 3
const MAX_DISTANCE := 150.0
const DOT_DISTANCE := 92.0
const NEAR_DISTANCE := 20.0
const SIZE_MAX := 16.0
const SIZE_MIN := 7.0
const DOT_RADIUS := 4.0
const MARGIN := 28.0
const ALPHA := 0.84
const STILL_SPEED := 1.5
const HEADING_PROBE := 1.0
const VELOCITY_SMOOTHING := 0.08

var _main: Node3D
var _camera: Camera3D
var _items: Array[Dictionary] = []
var _last_positions := {}
var _velocities := {}
var _headings := {}


func setup(main: Node3D, camera: Camera3D) -> void:
	_main = main
	_camera = camera
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1 # Ambient information, beneath menus and status text.


func _process(delta: float) -> void:
	_items = _collect(delta)
	queue_redraw()


func _draw() -> void:
	if _camera == null or _main == null:
		return
	var me: Node3D = _main.local_player()
	if me == null:
		return
	var view := size
	var center := view * 0.5
	var half_width := maxf(8.0, view.x * 0.5 - MARGIN)
	var half_height := maxf(8.0, view.y * 0.5 - MARGIN)
	var my_position := _display_position(me)

	for item in _items:
		var world_position: Vector3 = item["position"]
		var distance := _planar_distance(my_position, world_position)
		if distance > MAX_DISTANCE:
			continue
		var delta := _camera.unproject_position(world_position) - center
		if _camera.is_position_behind(world_position):
			delta = -delta
		elif absf(delta.x) <= half_width and absf(delta.y) <= half_height:
			continue # It is already visible.
		if delta.length_squared() < 0.001:
			delta = Vector2.RIGHT
		var edge_t := 1.0 / maxf(absf(delta.x) / half_width, absf(delta.y) / half_height)
		var marker := center + delta * edge_t
		var color: Color = item["color"]
		color.a = ALPHA
		if distance > DOT_DISTANCE:
			draw_circle(marker, DOT_RADIUS, color)
			continue
		var marker_size := lerpf(SIZE_MAX, SIZE_MIN,
			clampf(inverse_lerp(NEAR_DISTANCE, DOT_DISTANCE, distance), 0.0, 1.0))
		if int(item["kind"]) == KIND_PLAYER:
			draw_colored_polygon(_triangle(marker,
				_heading_angle(int(item["id"]), world_position, item["velocity"]), marker_size), color)
		else:
			# The ball is important, but a direction would be invented information.
			draw_colored_polygon(_diamond(marker, marker_size * 0.8), color)


func _collect(delta: float) -> Array[Dictionary]:
	var me: Node3D = _main.local_player()
	if me == null:
		return []
	var my_id := multiplayer.get_unique_id()
	var my_map := int(me.get("map_id"))
	var candidates: Array[Dictionary] = []
	var seen := {}
	var players := _main.get_node_or_null("Players")
	if players != null:
		for player_variant in PLAYER_PARTICIPATION.children(players):
			var player := player_variant as Node3D
			if player == null or int(player.name) == my_id or int(player.get("map_id")) != my_map:
				continue
			var id := int(player.name)
			var position := _display_position(player)
			seen[id] = true
			candidates.append({"id": id, "position": position,
				"velocity": _track(id, position, delta), "color": _peer_color(id), "kind": KIND_PLAYER,
				"distance": _planar_distance(_display_position(me), position)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["distance"]) < float(b["distance"]))
	var result: Array[Dictionary] = candidates.slice(0, MAX_PLAYER_MARKERS)

	# One objective marker is useful.  Do not add every combat target, dot, troop,
	# projectile, or static fixture; that is the failure mode this UI replaces.
	if my_map == 0:
		var balls := _main.get_node_or_null("Balls")
		if balls != null and balls.get_child_count() > 0:
			var ball := balls.get_child(0) as Node3D
			if ball != null:
				result.append({"id": -1, "position": ball.global_position, "velocity": Vector3.ZERO,
					"color": Color("dc7a4d"), "kind": KIND_BALL})
	for id in _last_positions.keys():
		if not seen.has(id):
			_last_positions.erase(id)
			_velocities.erase(id)
			_headings.erase(id)
	return result


func _track(id: int, position: Vector3, delta: float) -> Vector3:
	if delta <= 0.0:
		return _velocities.get(id, Vector3.ZERO)
	if not _last_positions.has(id):
		_last_positions[id] = position
		_velocities[id] = Vector3.ZERO
		return Vector3.ZERO
	var raw: Vector3 = (position - (_last_positions[id] as Vector3)) / delta
	_last_positions[id] = position
	var smoothed: Vector3 = (_velocities.get(id, raw) as Vector3).lerp(raw, VELOCITY_SMOOTHING)
	_velocities[id] = smoothed
	return smoothed


func _heading_angle(id: int, position: Vector3, velocity: Vector3) -> float:
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if flat_velocity.length() >= STILL_SPEED:
		var start := _camera.unproject_position(position)
		var finish := _camera.unproject_position(position + flat_velocity.normalized() * HEADING_PROBE)
		var screen_velocity := finish - start
		if screen_velocity.length_squared() > 0.0001:
			_headings[id] = screen_velocity.angle()
	return float(_headings.get(id, 0.0))


func _display_position(body: Node3D) -> Vector3:
	return body.call("presented_position") if body.has_method("presented_position") else body.global_position


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _peer_color(id: int) -> Color:
	var palette := [Color("63d8ff"), Color("ffb45e"), Color("b080ff"), Color("72df80"), Color("ff7096")]
	return palette[abs(id) % palette.size()]


func _triangle(center: Vector2, heading: float, marker_size: float) -> PackedVector2Array:
	var forward := Vector2.RIGHT.rotated(heading)
	var side := Vector2.UP.rotated(heading)
	return PackedVector2Array([center + forward * (marker_size * 1.15),
		center - forward * (marker_size * 0.65) + side * (marker_size * 0.70),
		center - forward * (marker_size * 0.65) - side * (marker_size * 0.70)])


func _diamond(center: Vector2, marker_size: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0.0, -marker_size), center + Vector2(marker_size, 0.0),
		center + Vector2(0.0, marker_size), center + Vector2(-marker_size, 0.0)])
