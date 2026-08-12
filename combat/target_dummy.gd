extends StaticBody3D
## Permanent target presentation. Hit count is authored by Main's server RPC.

var target_id := 0
var hit_count := 0
var _flash_time := 0.0
var _mesh: MeshInstance3D
var _label: Label3D
var _base_material: StandardMaterial3D

func setup(id: int, with_presentation: bool) -> void:
	target_id = id
	name = "Target_%02d" % id
	collision_layer = 4
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.62
	shape.height = 1.5
	collision.shape = shape
	add_child(collision)
	if with_presentation:
		_build_presentation()

func register_hit() -> void:
	set_hit_count(hit_count + 1)
	_flash_time = 0.13
	_apply_color(Color("fff19a"))

func set_hit_count(value: int) -> void:
	hit_count = maxi(value, 0)
	if _label != null:
		_label.text = str(hit_count)

func _process(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time = maxf(_flash_time - delta, 0.0)
	if _flash_time <= 0.0:
		_apply_color(Color("d95f59"))

func _build_presentation() -> void:
	_mesh = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.62
	mesh.height = 1.5
	mesh.radial_segments = 12
	_mesh.mesh = mesh
	add_child(_mesh)
	_base_material = StandardMaterial3D.new()
	_base_material.roughness = 0.58
	_base_material.emission_enabled = true
	_base_material.emission_energy_multiplier = 0.25
	_mesh.material_override = _base_material
	_apply_color(Color("d95f59"))
	_label = Label3D.new()
	_label.name = "HitCount"
	_label.position = Vector3(0.0, 1.22, 0.0)
	_label.text = "0"
	_label.font_size = 42
	_label.outline_size = 8
	_label.modulate = Color("fff4e8")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

func _apply_color(color: Color) -> void:
	if _base_material == null:
		return
	_base_material.albedo_color = color
	_base_material.emission = color
