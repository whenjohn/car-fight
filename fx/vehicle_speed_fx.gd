extends Node3D
## Local dust, gravel, and tire smoke derived from an already-presented car.

const DUST_START_SPEED := 8.0
const DUST_FULL_SPEED := 20.0
const SKID_SMOKE_START_SPEED := 7.0

var _dust: CPUParticles3D
var _debris: CPUParticles3D
var _smoke: CPUParticles3D


func _ready() -> void:
	_dust = _particles("RoadDust", 54, 0.8, Color(0.52, 0.43, 0.31, 0.34), 0.24)
	_dust.position = Vector3(0.0, 0.18, 1.25)
	_dust.direction = Vector3(0.0, 0.35, 1.0)
	_dust.spread = 34.0
	_dust.initial_velocity_min = 1.4
	_dust.initial_velocity_max = 4.2
	_dust.gravity = Vector3(0.0, 1.15, 0.0)
	_dust.scale_amount_min = 0.45
	_dust.scale_amount_max = 1.35
	add_child(_dust)

	_debris = _particles("RoadDebris", 22, 0.55, Color(0.22, 0.18, 0.13, 0.72), 0.075)
	_debris.position = Vector3(0.0, 0.12, 1.2)
	_debris.direction = Vector3(0.0, 0.7, 1.0)
	_debris.spread = 48.0
	_debris.initial_velocity_min = 2.0
	_debris.initial_velocity_max = 5.4
	_debris.gravity = Vector3(0.0, -7.0, 0.0)
	add_child(_debris)

	_smoke = _particles("TireSmoke", 70, 1.05, Color(0.68, 0.70, 0.69, 0.30), 0.34)
	_smoke.position = Vector3(0.0, 0.16, 1.28)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(0.78, 0.05, 0.16)
	_smoke.direction = Vector3(0.0, 0.8, 0.35)
	_smoke.spread = 42.0
	_smoke.initial_velocity_min = 0.7
	_smoke.initial_velocity_max = 2.2
	_smoke.gravity = Vector3(0.0, 0.9, 0.0)
	_smoke.scale_amount_min = 0.45
	_smoke.scale_amount_max = 1.5
	add_child(_smoke)


static func dust_strength(speed: float, grounded: bool) -> float:
	return smoothstep(DUST_START_SPEED, DUST_FULL_SPEED, maxf(speed, 0.0)) \
		if grounded else 0.0


static func smoke_strength(speed: float, brake: float, drift: float,
		grounded: bool) -> float:
	if not grounded or speed < SKID_SMOKE_START_SPEED:
		return 0.0
	return clampf(maxf(brake, absf(drift)), 0.0, 1.0) \
		* smoothstep(SKID_SMOKE_START_SPEED, 16.0, speed)


func update_effects(speed: float, brake: float, drift: float, boosting: bool,
		grounded: bool) -> void:
	if _dust == null:
		return
	var dust_amount := dust_strength(speed, grounded)
	if boosting:
		dust_amount = maxf(dust_amount, 0.72)
	var smoke_amount := smoke_strength(speed, brake, drift, grounded)
	_set_emission(_dust, dust_amount)
	_set_emission(_debris, maxf(dust_amount - 0.28, 0.0) / 0.72)
	_set_emission(_smoke, smoke_amount)


func _particles(node_name: String, count: int, lifetime: float, color: Color,
		size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.amount = count
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.fixed_fps = 30
	particles.emitting = false
	particles.set_meta("maximum_amount", count)
	particles.color = color
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.orientation = PlaneMesh.FACE_Z
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	quad.material = material
	particles.mesh = quad
	return particles


func _set_emission(particles: CPUParticles3D, strength: float) -> void:
	var amount := clampf(strength, 0.0, 1.0)
	var maximum_amount := int(particles.get_meta("maximum_amount", particles.amount))
	var desired_amount := maxi(1, roundi(maximum_amount * amount))
	if particles.amount != desired_amount:
		particles.amount = desired_amount
	particles.emitting = amount > 0.01
