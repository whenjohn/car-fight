extends MeshInstance3D

const ZONE_SHADER := preload("res://fx/area_weapon_zone.gdshader")

var lifetime := 3.6
var _age := 0.0
var _material: ShaderMaterial

func configure(centre: Vector3, radius: float) -> void:
	global_position = centre + Vector3.UP * 0.03
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.025
	disc.radial_segments = 48
	mesh = disc
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = ZONE_SHADER
	_material.set_shader_parameter("duration", lifetime)
	material_override = _material

func _process(delta: float) -> void:
	_age += delta
	_material.set_shader_parameter("age", _age)
	if _age >= lifetime:
		queue_free()
