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

var _body: Node3D
var _chassis_lean: Node3D
var _turret: Node3D
var _front_steer_nodes: Array[Node3D] = []
var _wheel_spin_nodes: Array[Node3D] = []
var _wheel_spin_angle := 0.0

func _ready() -> void:
	_body = get_parent() as Node3D
	_build_jeep()

func _process(delta: float) -> void:
	if _body == null or _turret == null:
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
	var aim_value: Variant = _body.get("aim")
	if aim_value is Vector3 and (aim_value as Vector3).length_squared() > 0.001:
		var aim_direction := aim_value as Vector3
		_turret.global_rotation.y = atan2(-aim_direction.x, -aim_direction.z)

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
	_turret = Node3D.new()
	_turret.name = "CursorTurret"
	_turret.position = Vector3(0.0, 1.34, -0.12)
	_chassis_lean.add_child(_turret)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.28
	ring.bottom_radius = 0.34
	ring.height = 0.18
	ring.radial_segments = 16
	_turret.add_child(_mesh_node("TurretRing", ring, Vector3.ZERO, dark_mat))
	var barrel := BoxMesh.new()
	barrel.size = Vector3(0.13, 0.12, 0.9)
	_turret.add_child(_mesh_node("Barrel", barrel, Vector3(0.0, 0.07, -0.44), body_mat))

func _model_root(node_name: String, parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = node_name
	model.scale = Vector3.ONE * JEEP_SCALE
	model.rotation.y = PI
	model.position = Vector3(0.0, 0.065, -0.05)
	parent.add_child(model)
	return model
