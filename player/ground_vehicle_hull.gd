extends Node3D
## Presentation-only CC0 Jeep from g2. The rollback collider remains a sphere.

const JEEP_SCENE: PackedScene = preload("res://assets/ground_vehicle/Jeep.fbx")
const JEEP_SCALE := 0.45

var _body: Node3D
var _suspension: Node3D
var _turret: Node3D

func _ready() -> void:
	_body = get_parent() as Node3D
	_build_jeep()

func _process(delta: float) -> void:
	if _body == null or _turret == null:
		return
	var rigid := _body as RigidBody3D
	if rigid != null and _suspension != null:
		var speed_load := clampf(Vector2(rigid.linear_velocity.x, rigid.linear_velocity.z).length() / 14.0, 0.0, 1.0)
		var target_roll := -clampf(rigid.angular_velocity.y / 2.4, -1.0, 1.0) * speed_load * deg_to_rad(5.5)
		_suspension.rotation.z = lerp_angle(_suspension.rotation.z, target_roll, 1.0 - exp(-9.0 * delta))
	var aim_value: Variant = _body.get("aim")
	if aim_value is Vector3 and (aim_value as Vector3).length_squared() > 0.001:
		var aim_direction := aim_value as Vector3
		_turret.global_rotation.y = atan2(-aim_direction.x, -aim_direction.z)

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
	_suspension = Node3D.new()
	_suspension.name = "VisualSuspension"
	add_child(_suspension)
	var jeep := JEEP_SCENE.instantiate() as Node3D
	jeep.name = "CC0Jeep"
	jeep.scale = Vector3.ONE * JEEP_SCALE
	jeep.rotation.y = PI
	jeep.position = Vector3(0.0, 0.065, -0.05)
	_suspension.add_child(jeep)

	var dark_mat := _material(Color(0.055, 0.075, 0.095), 0.3)
	var body_mat := _material(Color(0.18, 0.48, 0.22), 0.12)
	_turret = Node3D.new()
	_turret.name = "CursorTurret"
	_turret.position = Vector3(0.0, 1.34, -0.12)
	_suspension.add_child(_turret)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.28
	ring.bottom_radius = 0.34
	ring.height = 0.18
	ring.radial_segments = 16
	_turret.add_child(_mesh_node("TurretRing", ring, Vector3.ZERO, dark_mat))
	var barrel := BoxMesh.new()
	barrel.size = Vector3(0.13, 0.12, 0.9)
	_turret.add_child(_mesh_node("Barrel", barrel, Vector3(0.0, 0.07, -0.44), body_mat))

