extends Node3D
## Presentation-only CC0 Jeep from g2. Chassis lean and wheel animation are
## derived locally; the rollback collider remains one equal-mass sphere.

const JEEP_SCENE: PackedScene = preload("res://assets/ground_vehicle/Jeep.fbx")
const JEEP_SPLITTER := preload("res://player/jeep_mesh_splitter.gd")
const JEEP_SCALE := 0.45
const WHEEL_RADIUS := 0.31
const MAX_VISUAL_STEER := deg_to_rad(30.0)
const STEER_RATE_REFERENCE := 1.85
const BODY_ROLL_MAX := deg_to_rad(11.0)
const BODY_ROLL_SPEED_REF := 8.0
const BOOST_ECHO_COUNT := 4
const BOOST_ECHO_INTERVAL := 0.075
const BOOST_ECHO_LIFETIME := 0.34
const BOOST_ECHO_MIN_SPEED := 1.0
const BOOST_ECHO_COLOR := Color(1.0, 0.38, 0.08, 0.28)

var _body: Node3D
var _chassis_lean: Node3D
var _front_steer_nodes: Array[Node3D] = []
var _wheel_spin_nodes: Array[Node3D] = []
var _wheel_spin_angle := 0.0
var _visual_parts: Array[Node3D] = []
var _boost_echoes: Array[Node3D] = []
var _boost_echo_materials: Array[StandardMaterial3D] = []
var _boost_echo_ages: Array[float] = []
var _boost_echo_cursor := 0
var _boost_echo_accum := 0.0

func _ready() -> void:
	_body = get_parent() as Node3D
	_build_jeep()
	_build_boost_echoes()

func _process(delta: float) -> void:
	if _body == null:
		return
	var rigid := _body as RigidBody3D
	if rigid != null and _chassis_lean != null:
		var planar_speed := Vector2(rigid.linear_velocity.x, rigid.linear_velocity.z).length()
		var steer_fraction := clampf(rigid.angular_velocity.y / STEER_RATE_REFERENCE, -1.0, 1.0)
		var target_roll := chassis_roll_target(rigid.angular_velocity.y, planar_speed)
		_chassis_lean.rotation.z = lerp_angle(_chassis_lean.rotation.z, target_roll, 1.0 - exp(-9.0 * delta))
		var target_steer := steer_fraction * MAX_VISUAL_STEER
		for steer_node in _front_steer_nodes:
			steer_node.rotation.y = lerp_angle(steer_node.rotation.y, target_steer, 1.0 - exp(-12.0 * delta))
		var forward := -rigid.global_basis.z
		var signed_speed := rigid.linear_velocity.dot(forward)
		_wheel_spin_angle = fposmod(_wheel_spin_angle + signed_speed / WHEEL_RADIUS * delta, TAU)
		for spin_node in _wheel_spin_nodes:
			spin_node.rotation.x = _wheel_spin_angle
		_update_boost_echoes(delta, bool(_body.get("boost_active")), planar_speed)

static func chassis_roll_target(yaw_rate: float, road_speed: float) -> float:
	var steer_load := clampf(yaw_rate / STEER_RATE_REFERENCE, -1.0, 1.0)
	var speed_load := clampf(road_speed / BODY_ROLL_SPEED_REF, 0.0, 1.0)
	return -steer_load * speed_load * BODY_ROLL_MAX

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.62
	return material

func _mesh_node(node_name: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.material_override = material
	return node

func _build_jeep() -> void:
	var source := JEEP_SCENE.instantiate() as Node3D
	var source_mesh_instance := source.find_child("*", true, false) as MeshInstance3D
	var split: Dictionary = JEEP_SPLITTER.split(source_mesh_instance.mesh, source_mesh_instance.transform)
	source.free()

	_chassis_lean = Node3D.new()
	_chassis_lean.name = "ChassisLean"
	add_child(_chassis_lean)
	var chassis_model := _model_root("ChassisModel", _chassis_lean)
	var chassis := MeshInstance3D.new()
	chassis.name = "SeparatedChassis"
	chassis.mesh = split["chassis"]
	chassis_model.add_child(chassis)

	var wheel_model := _model_root("WheelModel", self)
	_visual_parts = [_chassis_lean, wheel_model]
	var wheels: Dictionary = split["wheels"]
	for wheel_name in wheels.keys():
		var wheel: Dictionary = wheels[wheel_name]
		var steer_anchor := Node3D.new()
		steer_anchor.name = "%sSteer" % str(wheel_name).to_pascal_case()
		steer_anchor.position = wheel["center"]
		wheel_model.add_child(steer_anchor)
		if bool(wheel["front"]):
			_front_steer_nodes.append(steer_anchor)
		var spin_anchor := Node3D.new()
		spin_anchor.name = "%sSpin" % str(wheel_name).to_pascal_case()
		steer_anchor.add_child(spin_anchor)
		_wheel_spin_nodes.append(spin_anchor)
		var wheel_mesh := MeshInstance3D.new()
		wheel_mesh.name = "%sMesh" % str(wheel_name).to_pascal_case()
		wheel_mesh.mesh = wheel["mesh"]
		spin_anchor.add_child(wheel_mesh)

	var dark_mat := _material(Color(0.055, 0.075, 0.095), 0.3)
	var body_mat := _material(Color(0.18, 0.48, 0.22), 0.12)
	_build_weapon_mounts(dark_mat, body_mat)

func _build_weapon_mounts(dark_material: Material, body_material: Material) -> void:
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.17
	ring_mesh.bottom_radius = 0.21
	ring_mesh.height = 0.13
	ring_mesh.radial_segments = 12
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.11, 0.10, 0.72)
	for index in range(4):
		var mount := Node3D.new()
		mount.name = "%sWeaponMount" % ["Front", "Right", "Rear", "Left"][index]
		mount.position = Vector3(0.0, 1.30, -0.04)
		mount.rotation.y = [0.0, -PI * 0.5, PI, PI * 0.5][index]
		_chassis_lean.add_child(mount)
		mount.add_child(_mesh_node("Mount", ring_mesh, Vector3.ZERO, dark_material))
		mount.add_child(_mesh_node("Barrel", barrel_mesh,
			Vector3(0.0, 0.04, -0.34), body_material))

## A tiny pool of frozen Jeep snapshots, matching g2's accepted boost echoes.
## They clone only render nodes and never add collision, physics, or network state.
func _build_boost_echoes() -> void:
	for index in range(BOOST_ECHO_COUNT):
		var echo := Node3D.new()
		echo.name = "BoostEcho_%d" % index
		add_child(echo)
		echo.top_level = true
		echo.visible = false
		for part in _visual_parts:
			echo.add_child(part.duplicate())
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(BOOST_ECHO_COLOR.r, BOOST_ECHO_COLOR.g,
			BOOST_ECHO_COLOR.b, 0.0)
		material.emission_enabled = true
		material.emission = BOOST_ECHO_COLOR
		material.emission_energy_multiplier = 0.45
		_apply_echo_material(echo, material)
		_boost_echoes.append(echo)
		_boost_echo_materials.append(material)
		_boost_echo_ages.append(BOOST_ECHO_LIFETIME)

func _update_boost_echoes(delta: float, boosting: bool, speed: float) -> void:
	for index in range(_boost_echoes.size()):
		var age := _boost_echo_ages[index] + delta
		_boost_echo_ages[index] = age
		var alive := 1.0 - clampf(age / BOOST_ECHO_LIFETIME, 0.0, 1.0)
		var echo := _boost_echoes[index]
		echo.visible = alive > 0.01
		if echo.visible:
			# Keep sampled position but use the live vehicle facing, preventing a
			# fan of stale headings during a curved boost.
			var echo_transform := echo.global_transform
			echo_transform.basis = global_transform.basis
			echo.global_transform = echo_transform
		var alpha := BOOST_ECHO_COLOR.a * alive * alive
		_boost_echo_materials[index].albedo_color = Color(BOOST_ECHO_COLOR.r,
			BOOST_ECHO_COLOR.g, BOOST_ECHO_COLOR.b, alpha)
	if not boosting or speed < BOOST_ECHO_MIN_SPEED or _boost_echoes.is_empty():
		_boost_echo_accum = 0.0
		return
	_boost_echo_accum += delta
	if _boost_echo_accum < BOOST_ECHO_INTERVAL:
		return
	_boost_echo_accum = fmod(_boost_echo_accum, BOOST_ECHO_INTERVAL)
	_emit_boost_echo()

func _emit_boost_echo() -> void:
	if _boost_echoes.is_empty():
		return
	var echo := _boost_echoes[_boost_echo_cursor]
	for index in range(_visual_parts.size()):
		_copy_pose(_visual_parts[index], echo.get_child(index) as Node3D)
	echo.global_transform = global_transform
	echo.visible = true
	_boost_echo_ages[_boost_echo_cursor] = 0.0
	_boost_echo_cursor = (_boost_echo_cursor + 1) % _boost_echoes.size()

func _copy_pose(source: Node3D, target: Node3D) -> void:
	target.transform = source.transform
	var child_count := mini(source.get_child_count(), target.get_child_count())
	for index in range(child_count):
		var source_child := source.get_child(index) as Node3D
		var target_child := target.get_child(index) as Node3D
		if source_child != null and target_child != null:
			_copy_pose(source_child, target_child)

func _apply_echo_material(node: Node, material: StandardMaterial3D) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.material_override = material
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_echo_material(child, material)

func _model_root(node_name: String, parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = node_name
	model.scale = Vector3.ONE * JEEP_SCALE
	model.rotation.y = PI
	model.position = Vector3(0.0, 0.065, -0.05)
	parent.add_child(model)
	return model
