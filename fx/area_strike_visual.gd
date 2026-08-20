extends Node3D
## Isometric Splash presentation carried over for Car Fight: the armed plane
## dives across a tap cluster or the full user-drawn bombing line.

const TARGET_SHADER := preload("res://fx/area_weapon_target.gdshader")
const WEAPON := preload("res://combat/area_weapon.gd")
const CALL_DELAY := 1.25

var owner_position := Vector3.ZERO
var start := Vector3.ZERO
var finish := Vector3.ZERO
var impacts := PackedVector3Array()
var radius := WEAPON.TAP_RADIUS
var is_drag := false
var _elapsed := 0.0
var _plane: Node3D
var _reticles: Array[MeshInstance3D] = []
var _reticle_materials: Array[ShaderMaterial] = []
var _bombs: Array[MeshInstance3D] = []

func configure(origin: Vector3, layout: Dictionary) -> void:
	owner_position = origin
	start = layout["start"]
	finish = layout["end"]
	impacts = layout["impacts"]
	radius = float(layout["radius"])
	is_drag = bool(layout["is_drag"])

func _ready() -> void:
	_build_plane()
	_build_reticles()
	_build_bombs()

func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / CALL_DELAY, 0.0, 1.0)
	_update_plane(progress)
	_update_reticles(progress)
	_update_bombs(progress)
	if _elapsed > CALL_DELAY + 0.9:
		queue_free()

func _update_plane(progress: float) -> void:
	var heading := finish - start
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = start - owner_position
	heading = heading.normalized() if heading.length_squared() > 0.0001 else Vector3.FORWARD
	var first := start - heading * 5.0 + Vector3.UP * 5.6
	var last := (finish if is_drag else start) + heading * 8.0 + Vector3.UP * 5.8
	var plane_position := first.lerp(last, progress)
	_plane.global_position = plane_position
	_plane.look_at(last + Vector3.UP * 0.15, Vector3.UP)

func _update_reticles(progress: float) -> void:
	for index in _reticles.size():
		var reticle := _reticles[index]
		reticle.visible = index < impacts.size() and progress < 0.88
		if reticle.visible:
			var impact := impacts[index]
			reticle.global_position = Vector3(impact.x, 0.05, impact.z)
			reticle.scale = Vector3.ONE * radius
			_reticle_materials[index].set_shader_parameter("progress", progress)

func _update_bombs(progress: float) -> void:
	for index in _bombs.size():
		var release := 0.46 + float(index) * 0.075
		var impact_time := 0.68 + float(index) * 0.06
		var bomb := _bombs[index]
		bomb.visible = progress >= release and progress < impact_time
		if not bomb.visible:
			continue
		var fall := inverse_lerp(release, impact_time, progress)
		var target := impacts[index]
		var plane_start := _plane.global_position
		bomb.global_position = plane_start.lerp(target + Vector3.UP * 0.12, fall)

func _build_plane() -> void:
	_plane = Node3D.new()
	_plane.name = "AreaWeaponAircraft"
	add_child(_plane)
	var hull := _material(Color(0.10, 0.12, 0.15), Color(0.18, 0.10, 0.035), 0.45)
	var hot := _material(Color(1.0, 0.20, 0.015), Color(1.0, 0.08, 0.005), 4.0)
	_add_box(_plane, "Fuselage", Vector3(0.48, 0.38, 3.5), Vector3.ZERO, hull)
	_add_box(_plane, "MainWing", Vector3(4.6, 0.12, 0.82), Vector3(0.0, 0.02, 0.25), hull)
	_add_box(_plane, "TailWing", Vector3(1.75, 0.10, 0.50), Vector3(0.0, 0.13, 1.35), hull)
	for side in [-1.0, 1.0]:
		_add_box(_plane, "Engine", Vector3(0.32, 0.30, 1.05), Vector3(side * 1.05, -0.16, 0.20), hull)
		_add_box(_plane, "EngineGlow", Vector3(0.18, 0.18, 0.10), Vector3(side * 1.05, -0.16, 0.77), hot)

func _build_reticles() -> void:
	for index in WEAPON.BOMB_COUNT:
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
		_reticle_materials.append(material)

func _build_bombs() -> void:
	var material := _material(Color(0.16, 0.13, 0.09), Color(1.0, 0.13, 0.005), 2.8)
	for _index in WEAPON.BOMB_COUNT:
		var bomb := MeshInstance3D.new()
		bomb.top_level = true
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.11
		capsule.height = 0.48
		bomb.mesh = capsule
		bomb.material_override = material
		bomb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bomb.visible = false
		add_child(bomb)
		_bombs.append(bomb)

func _add_box(parent: Node3D, node_name: String, size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

func _material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.62
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
