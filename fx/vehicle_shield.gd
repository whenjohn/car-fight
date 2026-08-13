extends Node3D
## Presentation-only glass shield. State comes from PlayerBody rollback state;
## hit events only choose where the already-live shader ripples.

const SHIELD_SHADER := preload("res://fx/vehicle_shield.gdshader")
const SHELL_RADIUS := 2.15
const FADE_TIME := 0.18
const IMPACT_TIME := 0.52

var _body: Node3D
var _material := ShaderMaterial.new()
var _strength := 0.0
var _impact_age := 1.2
var _seen := {}

func _ready() -> void:
	_body = get_parent() as Node3D
	var shell := MeshInstance3D.new()
	shell.name = "GlassShell"
	var sphere := SphereMesh.new()
	sphere.radius = SHELL_RADIUS
	sphere.height = SHELL_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	shell.mesh = sphere
	_material.shader = SHIELD_SHADER
	_material.set_shader_parameter("shield_strength", 0.0)
	_material.set_shader_parameter("impact_age", 1.2)
	shell.material_override = _material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)

func _process(delta: float) -> void:
	if _body == null:
		return
	var target := 1.0 if bool(_body.get("shield_up")) else 0.0
	_strength = move_toward(_strength, target, delta / FADE_TIME)
	_impact_age = minf(_impact_age + delta / IMPACT_TIME, 1.2)
	_material.set_shader_parameter("shield_strength", _strength)
	_material.set_shader_parameter("impact_age", _impact_age)
	for projectile_id in _seen.keys():
		var age := float(_seen[projectile_id]) + delta
		if age > 3.0:
			_seen.erase(projectile_id)
		else:
			_seen[projectile_id] = age

func register_impact(projectile_id: int, world_position: Vector3,
		incoming_direction: Vector3) -> void:
	if _seen.has(projectile_id) or _body == null:
		return
	_seen[projectile_id] = 0.0
	var world_direction := world_position - _body.global_position
	if world_direction.is_zero_approx():
		world_direction = -incoming_direction
	var local_direction := _body.global_basis.inverse() * world_direction.normalized()
	_material.set_shader_parameter("impact_direction", local_direction)
	_impact_age = 0.0
