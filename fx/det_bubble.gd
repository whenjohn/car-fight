extends Node3D
## Presentation-only amber field for the rollback-synchronized det radius.

const COLOR := Color(1.0, 0.62, 0.14, 0.28)

var _body: Node3D
var _mesh: MeshInstance3D
var _flash := 0.0
var _seen := {}

func _ready() -> void:
	_body = get_parent() as Node3D
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = COLOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

func _process(delta: float) -> void:
	if _body == null:
		return
	var radius := float(_body.call("det_radius"))
	_mesh.visible = radius > 0.001
	_mesh.scale = Vector3.ONE * radius
	_flash = maxf(_flash - delta * 3.5, 0.0)
	var material := _mesh.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = COLOR.lightened(_flash * 0.35)
	for id in _seen.keys():
		var age := float(_seen[id]) + delta
		if age > 3.0:
			_seen.erase(id)
		else:
			_seen[id] = age

func register_nullification(bolt_id: int, _contact: Vector3) -> void:
	if _seen.has(bolt_id):
		return
	_seen[bolt_id] = 0.0
	_flash = 1.0
