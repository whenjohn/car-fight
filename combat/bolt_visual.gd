extends Node3D
## Client-side presentation for a server-authored straight projectile.

const IMPACT := preload("res://player/impact_controller.gd")
const PLAYER_RADIUS := preload("res://player/vehicle_config.gd").COLLISION_RADIUS

var bolt_id := 0
var velocity := Vector3.ZERO
var _age := 0.0
var _hostile := false
var _predicted_contact := false

# Auto-fire can create four bolts per second while a target is in range. Keep
# their render resources shared so entering a combat lane does not continually
# allocate meshes/materials or introduce an emission-only shader variant.
static var _shared_mesh: SphereMesh
static var _shared_materials := {}

func setup(id: int, start: Vector3, shot_velocity: Vector3, color: Color,
		hostile: bool = false) -> void:
	bolt_id = id
	global_position = start
	velocity = shot_velocity
	_hostile = hostile
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _bolt_mesh()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _bolt_material(color)
	add_child(mesh_instance)

func _process(delta: float) -> void:
	var start := global_position
	var finish := start + velocity * delta
	global_position = finish
	if _hostile and not _predicted_contact:
		var main := get_node_or_null("/root/Main")
		var local: Node3D = main.call("local_player") if main != null else null
		if local != null:
			var fraction := IMPACT.segment_sphere_entry(start, finish,
				local.global_position, PLAYER_RADIUS)
			if fraction <= 1.0:
				_predicted_contact = true
				main.call("predict_drone_impact_visual", bolt_id, int(local.name),
					start + (finish - start) * fraction, velocity.normalized())
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
