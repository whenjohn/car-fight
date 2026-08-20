extends Node3D
## Client presentation for a server-authored G2-style homing missile.

const HEAD_SHADER := preload("res://fx/homing_missile_head.gdshader")
const HOMING_MISSILE := preload("res://combat/homing_missile.gd")
const TRAIL_LENGTH := 2.2

var velocity := Vector3.ZERO
var target_id := -1
var _age := 0.0
var _trail: MeshInstance3D

func setup(start: Vector3, shot_velocity: Vector3, locked_target_id: int) -> void:
	global_position = start
	velocity = shot_velocity
	target_id = locked_target_id
	_build_seeker()
	_build_trail()
	_set_direction(velocity)

func _process(delta: float) -> void:
	var main := get_node_or_null("/root/Main")
	var target: Node3D = main.call("homing_target_for", target_id) if main != null else null
	if target != null:
		velocity = HOMING_MISSILE.steer(velocity, global_position,
			target.global_position, delta)
	global_position += velocity * delta
	_set_direction(velocity)
	_age += delta
	if _age >= 2.7:
		queue_free()

func _set_direction(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		basis = Basis.looking_at(direction.normalized(), Vector3.UP)

func _build_seeker() -> void:
	var shell := MeshInstance3D.new()
	shell.mesh = _dart_mesh()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = HEAD_SHADER
	shell.material_override = material
	add_child(shell)

func _build_trail() -> void:
	_trail = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.12
	mesh.height = TRAIL_LENGTH
	_trail.mesh = mesh
	_trail.position.z = TRAIL_LENGTH * 0.5
	_trail.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.08, 0.55, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail.material_override = material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)

static func _dart_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(0.0, 0.0, -0.34), Vector3(-0.13, 0.0, 0.10),
		Vector3(0.0, 0.09, 0.10), Vector3(0.13, 0.0, 0.10), Vector3(0.0, -0.09, 0.10),
	])
	var uvs := PackedVector2Array([Vector2(0.5, 0.02), Vector2(0.0, 0.9), Vector2(0.25, 0.9), Vector2(0.5, 0.9), Vector2(0.75, 0.9)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 1])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
