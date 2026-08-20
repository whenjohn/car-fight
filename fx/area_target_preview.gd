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

func _ready() -> void:
	top_level = true
	_build_reticles()
	_build_plane()
	_set_visible(false)

func _process(delta: float) -> void:
	if owner_body == null or not is_instance_valid(owner_body) \
			or not bool(owner_body.get("area_weapon_armed")) \
			or not bool(owner_body.get("area_gesture_active")):
		_set_visible(false)
		return
	_phase += delta
	var layout := WEAPON.layout(owner_body.global_position,
		owner_body.get("area_gesture_start"), owner_body.get("area_gesture_end"))
	var impacts: PackedVector3Array = layout["impacts"]
	var radius := float(layout["radius"])
	for index in _reticles.size():
		var reticle := _reticles[index]
		reticle.visible = index < impacts.size()
		if reticle.visible:
			var point := impacts[index]
			reticle.global_position = Vector3(point.x, 0.052, point.z)
			reticle.scale = Vector3.ONE * radius
			_materials[index].set_shader_parameter("progress", 0.12 + sin(_phase * 2.4) * 0.08)
	_update_plane(layout)

func _update_plane(layout: Dictionary) -> void:
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
	_plane.global_position = start - direction * 3.2 + orbit + Vector3.UP * 4.8
	_plane.look_at(_plane.global_position + direction + Vector3.DOWN * 0.08, Vector3.UP)
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
