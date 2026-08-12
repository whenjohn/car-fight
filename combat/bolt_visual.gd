extends Node3D
## Client-side presentation for a server-authored straight projectile.

var bolt_id := 0
var velocity := Vector3.ZERO
var _age := 0.0

# Auto-fire can create four bolts per second while a target is in range. Keep
# their render resources shared so entering a combat lane does not continually
# allocate meshes/materials or introduce an emission-only shader variant.
static var _shared_mesh: SphereMesh
static var _shared_materials := {}

func setup(id: int, start: Vector3, shot_velocity: Vector3, color: Color) -> void:
	bolt_id = id
	global_position = start
	velocity = shot_velocity
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _bolt_mesh()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _bolt_material(color)
	add_child(mesh_instance)

func _process(delta: float) -> void:
	global_position += velocity * delta
	_age += delta
	if _age > 1.2:
		queue_free()

static func _bolt_mesh() -> SphereMesh:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.12
		_shared_mesh.height = 0.24
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4
	return _shared_mesh

static func _bolt_material(color: Color) -> StandardMaterial3D:
	if not _shared_materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Unshaded albedo is already full-bright; emission was visually redundant
		# and forced ANGLE to compile another program on the first nearby shot.
		material.albedo_color = color.lightened(0.12)
		_shared_materials[color] = material
	return _shared_materials[color] as StandardMaterial3D
