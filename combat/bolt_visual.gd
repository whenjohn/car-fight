extends Node3D
## Client-side presentation for a server-authored straight projectile.

var bolt_id := 0
var velocity := Vector3.ZERO
var _age := 0.0

func setup(id: int, start: Vector3, shot_velocity: Vector3, color: Color) -> void:
	bolt_id = id
	global_position = start
	velocity = shot_velocity
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.1
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _process(delta: float) -> void:
	global_position += velocity * delta
	_age += delta
	if _age > 1.2:
		queue_free()
