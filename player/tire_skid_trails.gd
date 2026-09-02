extends Node3D
## Bounded presentation-only tire ribbons. The caller supplies the animated
## contact points, so each mark bends with the individual tire instead of
## stamping a trail from the vehicle's center.

const SKID_SHADER := preload("res://fx/tire_skid_trail.gdshader")
## The imported Low Poly City road cap reaches roughly 0.184 units above the
## flat gameplay collision plane. Keep the presentation ribbon just above it
## while retaining normal depth testing against vehicles and buildings.
const CITY_SURFACE_OFFSET := 0.205
const MIN_STRENGTH := 0.055
const MIN_SAMPLE_DISTANCE := 0.16
const MAX_CONNECT_DISTANCE := 2.4
const MARK_LIFETIME := 12.0
const MAX_SEGMENTS := 1200
const FADE_REDRAW_INTERVAL := 0.10
const PEEL_TRIGGER := 0.72
const OIL_PEEL_TRIGGER := 0.28
const PEEL_REARM := 0.38
const REVERSE_BRAKE_MIN_FORWARD_SPEED := 7.0
const REVERSE_BRAKE_FULL_FORWARD_SPEED := 15.0

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _emitters := {}
var _segments: Array[Dictionary] = []
var _elapsed := 0.0
var _redraw_elapsed := 0.0
var _mesh_dirty := false


static func surface_point(contact: Vector3, normal: Vector3) -> Vector3:
	return contact + normal.normalized() * CITY_SURFACE_OFFSET


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
static func sustained_slide(measured_lateral_slip: float,
		drift_assist_amount: float, drift_assist_charge: float,
		drift_assist_latched: bool = false) -> float:
	if drift_assist_latched:
		return 1.0
	return maxf(absf(measured_lateral_slip), maxf(
		clampf(drift_assist_amount, 0.0, 1.0) * 0.92,
		clampf(drift_assist_charge, 0.0, 1.0) * 0.78))


static func should_start_peel(armed: bool, assist_just_latched: bool,
		measured_slide: float, oil: float) -> bool:
	if not armed:
		return false
	var trigger := lerpf(PEEL_TRIGGER, OIL_PEEL_TRIGGER,
		clampf(oil, 0.0, 1.0))
	return assist_just_latched or absf(measured_slide) >= trigger


static func reverse_brake_strength(reverse_held: bool,
		signed_forward_speed: float) -> float:
	if not reverse_held:
		return 0.0
	return smoothstep(REVERSE_BRAKE_MIN_FORWARD_SPEED,
		REVERSE_BRAKE_FULL_FORWARD_SPEED, signed_forward_speed)


static func skid_strength(brake: float, lateral_slip: float, oil: float,
		speed: float, front_tire: bool, boost_pulse: float = 0.0) -> float:
	var speed_authority := smoothstep(0.8, 6.5, maxf(speed, 0.0))
	var brake_mark := smoothstep(0.42, 0.92, clampf(brake, 0.0, 1.0))
	var slide_mark := smoothstep(0.16, 0.78, absf(lateral_slip))
	var boost_mark := clampf(boost_pulse, 0.0, 1.0)
	# Keep the visual language simple: every event is represented by the driven
	# rear pair. Front tires never emit presentation marks.
	var axle_strength := 0.0 if front_tire \
		else maxf(brake_mark, maxf(slide_mark, boost_mark))
	return clampf(axle_strength * speed_authority, 0.0, 1.0)


static func can_connect(previous: Vector3, current: Vector3) -> bool:
	var distance := previous.distance_to(current)
	return distance >= MIN_SAMPLE_DISTANCE and distance <= MAX_CONNECT_DISTANCE


func sample_tire(key: String, contact: Vector3, width_axis: Vector3,
		half_width: float, strength: float, oil: float, grounded: bool) -> void:
	if not grounded or strength < MIN_STRENGTH or width_axis.is_zero_approx():
		_finish_emitter(key)
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
		# The first connected quad ramps up from clear instead of appearing with
		# a hard rectangular cap.
		current["strength"] = 0.0
		_emitters[key] = current
		return
	var previous: Dictionary = _emitters[key]
	var previous_center: Vector3 = previous["center"]
	var distance := previous_center.distance_to(contact)
	if distance > MAX_CONNECT_DISTANCE:
		_finish_emitter(key)
		current["strength"] = 0.0
		_emitters[key] = current
		return
	if distance < MIN_SAMPLE_DISTANCE:
		return
	var travelled := float(previous.get("travelled", 0.0)) + distance
	current["travelled"] = travelled
	var segment := {
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
	}
	_segments.append(segment)
	current["last_segment"] = segment
	_emitters[key] = current
	while _segments.size() > MAX_SEGMENTS:
		_segments.pop_front()
	_mesh_dirty = true


func break_emitters() -> void:
	for key in _emitters.keys():
		_finish_emitter(str(key))


func _finish_emitter(key: String) -> void:
	if not _emitters.has(key):
		return
	var emitter: Dictionary = _emitters[key]
	var last_segment: Variant = emitter.get("last_segment")
	if last_segment is Dictionary:
		# Rebuild the final quad as a taper. The dictionary is shared with the
		# segment array, so this changes only this stroke's trailing endpoint.
		(last_segment as Dictionary)["strength"] = 0.0
		_mesh_dirty = true
	_emitters.erase(key)


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
