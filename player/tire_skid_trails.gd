extends Node3D
## Bounded presentation-only tire ribbons. The caller supplies the animated
## contact points, so each mark bends with the individual tire instead of
## stamping a trail from the vehicle's center.

const SKID_SHADER := preload("res://fx/tire_skid_trail.gdshader")
const MIN_STRENGTH := 0.055
const MIN_SAMPLE_DISTANCE := 0.16
const MAX_CONNECT_DISTANCE := 2.4
const MARK_LIFETIME := 12.0
const MAX_SEGMENTS := 1200
const FADE_REDRAW_INTERVAL := 0.10

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _emitters := {}
var _segments: Array[Dictionary] = []
var _elapsed := 0.0
var _redraw_elapsed := 0.0
var _mesh_dirty := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TireSkidMesh"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.extra_cull_margin = 8.0
	_material = ShaderMaterial.new()
	_material.shader = SKID_SHADER
	_material.render_priority = 2
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)


func _process(delta: float) -> void:
	_elapsed += delta
	_redraw_elapsed += delta
	var expired := false
	while not _segments.is_empty() \
			and _elapsed - float(_segments[0]["born"]) > MARK_LIFETIME:
		_segments.pop_front()
		expired = true
	if _mesh_dirty or expired \
			or (_redraw_elapsed >= FADE_REDRAW_INTERVAL and not _segments.is_empty()):
		_rebuild_mesh()


## Marks all ordinary causes of tire scrub. Actual lateral slip covers impacts
## and unassisted slides in addition to the named brake, drift, and oil cases.
static func skid_strength(brake: float, lateral_slip: float, oil: float,
		speed: float, front_tire: bool) -> float:
	var speed_authority := smoothstep(2.5, 9.0, maxf(speed, 0.0))
	var brake_mark := smoothstep(0.42, 0.92, clampf(brake, 0.0, 1.0))
	var slide_mark := smoothstep(0.16, 0.78, absf(lateral_slip))
	var oil_mark := smoothstep(0.04, 0.62, clampf(oil, 0.0, 1.0))
	var axle_strength := maxf(brake_mark, maxf(
		slide_mark * (0.48 if front_tire else 1.0),
		oil_mark * (0.68 if front_tire else 1.0)))
	return clampf(axle_strength * speed_authority, 0.0, 1.0)


static func can_connect(previous: Vector3, current: Vector3) -> bool:
	var distance := previous.distance_to(current)
	return distance >= MIN_SAMPLE_DISTANCE and distance <= MAX_CONNECT_DISTANCE


func sample_tire(key: String, contact: Vector3, width_axis: Vector3,
		half_width: float, strength: float, oil: float, grounded: bool) -> void:
	if not grounded or strength < MIN_STRENGTH or width_axis.is_zero_approx():
		_emitters.erase(key)
		return
	var width := width_axis.normalized() * half_width
	var current := {
		"center": contact,
		"left": contact - width,
		"right": contact + width,
		"strength": clampf(strength, 0.0, 1.0),
		"oil": clampf(oil, 0.0, 1.0),
	}
	if not _emitters.has(key):
		_emitters[key] = current
		return
	var previous: Dictionary = _emitters[key]
	var previous_center: Vector3 = previous["center"]
	var distance := previous_center.distance_to(contact)
	if distance > MAX_CONNECT_DISTANCE:
		_emitters[key] = current
		return
	if distance < MIN_SAMPLE_DISTANCE:
		return
	var travelled := float(previous.get("travelled", 0.0)) + distance
	current["travelled"] = travelled
	_segments.append({
		"previous_left": previous["left"],
		"previous_right": previous["right"],
		"current_left": current["left"],
		"current_right": current["right"],
		"previous_strength": previous["strength"],
		"strength": current["strength"],
		"oil": maxf(float(previous["oil"]), float(current["oil"])),
		"uv_start": float(previous.get("travelled", 0.0)),
		"uv_end": travelled,
		"born": _elapsed,
	})
	_emitters[key] = current
	while _segments.size() > MAX_SEGMENTS:
		_segments.pop_front()
	_mesh_dirty = true


func break_emitters() -> void:
	_emitters.clear()


func segment_count() -> int:
	return _segments.size()


func _rebuild_mesh() -> void:
	_redraw_elapsed = 0.0
	_mesh_dirty = false
	if _mesh_instance == null:
		return
	if _segments.is_empty():
		_mesh_instance.mesh = null
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for segment in _segments:
		var age := _elapsed - float(segment["born"])
		var fade := 1.0 - smoothstep(MARK_LIFETIME * 0.62, MARK_LIFETIME, age)
		var oil := float(segment["oil"])
		var previous_alpha := float(segment["previous_strength"]) * fade
		var current_alpha := float(segment["strength"]) * fade
		var tint := Color(0.72 + oil * 0.20, 0.72 + oil * 0.08,
			0.75 + oil * 0.25, 1.0)
		_append_vertex(vertices, normals, colors, uvs, segment["previous_left"],
			Vector2(0.0, float(segment["uv_start"])), tint, previous_alpha)
		_append_vertex(vertices, normals, colors, uvs, segment["previous_right"],
			Vector2(1.0, float(segment["uv_start"])), tint, previous_alpha)
		_append_vertex(vertices, normals, colors, uvs, segment["current_left"],
			Vector2(0.0, float(segment["uv_end"])), tint, current_alpha)
		_append_vertex(vertices, normals, colors, uvs, segment["current_left"],
			Vector2(0.0, float(segment["uv_end"])), tint, current_alpha)
		_append_vertex(vertices, normals, colors, uvs, segment["previous_right"],
			Vector2(1.0, float(segment["uv_start"])), tint, previous_alpha)
		_append_vertex(vertices, normals, colors, uvs, segment["current_right"],
			Vector2(1.0, float(segment["uv_end"])), tint, current_alpha)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh


func _append_vertex(vertices: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, uvs: PackedVector2Array, position: Vector3,
		uv: Vector2, tint: Color, alpha: float) -> void:
	vertices.append(position)
	normals.append(Vector3.UP)
	colors.append(Color(tint.r, tint.g, tint.b, clampf(alpha, 0.0, 1.0)))
	uvs.append(uv)
