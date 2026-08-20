extends Node3D
## Presentation-only counterpart to the server's lightweight RC orb state.

const ORB_SHADER := preload("res://fx/rc_orb_skin.gdshader")
const FLOW_SHADER := preload("res://fx/rc_orb_flow.gdshader")
const WARNING_SECONDS := 2.25

var _orb_material: ShaderMaterial
var _flow_material: ShaderMaterial
var _satellite_material: ShaderMaterial
var _satellites: Array[MeshInstance3D] = []
var _elapsed := 0.0
var _remaining_life := 6.0

func setup(position: Vector3, remaining_life: float) -> void:
	global_position = position
	_remaining_life = remaining_life

func _ready() -> void:
	_build_orb()
	_build_flow()
	_build_satellites()

func update_state(position: Vector3, remaining_life: float) -> void:
	global_position = position
	_remaining_life = remaining_life

func _process(delta: float) -> void:
	_elapsed += delta
	var warning := clampf(1.0 - _remaining_life / WARNING_SECONDS, 0.0, 1.0)
	_orb_material.set_shader_parameter("warning", warning)
	_flow_material.set_shader_parameter("warning", warning)
	_satellite_material.set_shader_parameter("warning", warning)
	for index in _satellites.size():
		var angle := _elapsed * 3.8 + PI * float(index)
		_satellites[index].position = Vector3(cos(angle) * 0.48, sin(angle) * 0.18, sin(angle) * 0.30)

func _build_orb() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	# The Web camera covers a large arena; keep the RC orb readable at a glance
	# instead of reducing it to a sub-pixel projectile.
	sphere.radius = 0.32
	sphere.height = 0.64
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb_material = ShaderMaterial.new()
	_orb_material.shader = ORB_SHADER
	mesh.material_override = _orb_material
	add_child(mesh)

func _build_flow() -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.35, 1.35)
	mesh.mesh = quad
	mesh.extra_cull_margin = 0.5
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flow_material = ShaderMaterial.new()
	_flow_material.shader = FLOW_SHADER
	mesh.material_override = _flow_material
	add_child(mesh)

func _build_satellites() -> void:
	_satellite_material = ShaderMaterial.new()
	_satellite_material.shader = ORB_SHADER
	_satellite_material.set_shader_parameter("satellite_mode", true)
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	sphere.radial_segments = 8
	sphere.rings = 4
	for index in 2:
		var satellite := MeshInstance3D.new()
		satellite.mesh = sphere
		satellite.material_override = _satellite_material
		satellite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(satellite)
		_satellites.append(satellite)
