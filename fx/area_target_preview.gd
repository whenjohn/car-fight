extends Node3D
## Local, pre-release designation tell. It deliberately calls the same shared
## layout function as the server, so there is no optimistic shape to unlearn.

const WEAPON := preload("res://combat/area_weapon.gd")
const TARGET_SHADER := preload("res://fx/area_weapon_target.gdshader")

var owner_body: Node3D
var _reticles: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _plane: Node3D
var _phase := 0.0
var _aircraft_entering := false
var _aircraft_visible := false

func _ready() -> void:
	top_level = true
	_build_reticles()
	_build_plane()
	_set_visible(false)

func _process(delta: float) -> void:
	if owner_body == null or not is_instance_valid(owner_body) \
			or not bool(owner_body.get("area_weapon_armed")):
		_set_visible(false)
		_aircraft_visible = false
		return
	_phase += delta
	var hovering_target := _live_cursor_target()
	if not _aircraft_visible:
		_aircraft_visible = true
		_aircraft_entering = true
		var arrival_direction := hovering_target - owner_body.global_position
		arrival_direction.y = 0.0
		arrival_direction = arrival_direction.normalized() if arrival_direction.length_squared() > 0.0001 else Vector3.FORWARD
		_plane.global_position = hovering_target - arrival_direction * 40.0 + Vector3.UP * 9.0
		_plane.visible = true
	var active_gesture := bool(owner_body.get("area_gesture_active"))
	var layout := WEAPON.layout(owner_body.global_position,
		owner_body.get("area_gesture_start") if active_gesture else hovering_target,
		owner_body.get("area_gesture_end") if active_gesture else hovering_target)
	var impacts: PackedVector3Array = layout["impacts"]
	var radius := float(layout["radius"])
	for index in _reticles.size():
		var reticle := _reticles[index]
		reticle.visible = active_gesture and index < impacts.size()
		if reticle.visible:
			var point := impacts[index]
			reticle.global_position = Vector3(point.x, 0.052, point.z)
			reticle.scale = Vector3.ONE * radius
			_materials[index].set_shader_parameter("progress", 0.12 + sin(_phase * 2.4) * 0.08)
	_update_plane(layout, hovering_target, delta)

func _live_cursor_target() -> Vector3:
	var offset: Vector2 = owner_body.get_node("Input").get("cursor_offset")
	return Vector3(owner_body.global_position.x + offset.x, 0.0,
		owner_body.global_position.z + offset.y)

func _update_plane(layout: Dictionary, hovering_target: Vector3, delta: float) -> void:
	var start: Vector3 = layout["start"]
	var finish: Vector3 = layout["end"]
	var direction := finish - start
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = start - owner_body.global_position
	direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var right := Vector3.UP.cross(direction).normalized()
	var orbit := right * cos(_phase * 1.35) * 1.55
	orbit += direction * sin(_phase * 1.35) * 0.72
	var hover_anchor := (start if bool(owner_body.get("area_gesture_active")) else hovering_target) \
		- direction * 3.2 + orbit + Vector3.UP * 4.8
	var previous := _plane.global_position
	if _aircraft_entering:
		_plane.global_position = _plane.global_position.move_toward(hover_anchor, 25.0 * delta)
		if _plane.global_position.distance_to(hover_anchor) <= 0.9:
			_aircraft_entering = false
	else:
		_plane.global_position = _plane.global_position.lerp(hover_anchor, 1.0 - exp(-4.0 * delta))
	var travel := _plane.global_position - previous
	var facing := travel.normalized() if travel.length_squared() > 0.0001 else direction
	_plane.look_at(_plane.global_position + facing + Vector3.DOWN * 0.08, Vector3.UP)
	_plane.visible = true

func _build_reticles() -> void:
	for _index in WEAPON.BOMB_COUNT:
		var reticle := MeshInstance3D.new()
		reticle.top_level = true
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		reticle.mesh = quad
		reticle.rotation.x = -PI * 0.5
		reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = TARGET_SHADER
		reticle.material_override = material
		add_child(reticle)
		_reticles.append(reticle)
		_materials.append(material)

func _build_plane() -> void:
	_plane = Node3D.new()
	_plane.name = "AreaWeaponPreviewAircraft"
	add_child(_plane)
	var hull := _material(Color(0.10, 0.12, 0.15), Color(0.18, 0.10, 0.035), 0.45)
	var hot := _material(Color(1.0, 0.20, 0.015), Color(1.0, 0.08, 0.005), 4.0)
	_add_box("Fuselage", Vector3(0.48, 0.38, 3.5), Vector3.ZERO, hull)
	_add_box("MainWing", Vector3(4.6, 0.12, 0.82), Vector3(0.0, 0.02, 0.25), hull)
	for side in [-1.0, 1.0]:
		_add_box("Engine", Vector3(0.32, 0.30, 1.05), Vector3(side * 1.05, -0.16, 0.20), hull)
		_add_box("EngineGlow", Vector3(0.18, 0.18, 0.10), Vector3(side * 1.05, -0.16, 0.77), hot)

func _add_box(node_name: String, size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane.add_child(mesh)

func _material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.62
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _set_visible(value: bool) -> void:
	for reticle in _reticles:
		reticle.visible = value
	if _plane != null:
		_plane.visible = value
