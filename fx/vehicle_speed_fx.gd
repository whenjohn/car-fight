extends Node3D
## Local dust, gravel, and tire smoke derived from an already-presented car.

const DUST_START_SPEED := 8.0
const DUST_FULL_SPEED := 20.0
const SKID_SMOKE_START_SPEED := 7.0
const SMOKE_TEXTURE_PATH := "res://assets/vfx/starter_vfx_fire/tex_smoke_07.png"
const SMOKE_TEXTURE := preload(SMOKE_TEXTURE_PATH)
const SMOKE_CORE_CARD_SIZE := 1.55
const SMOKE_HAZE_CARD_SIZE := 2.75
const SMOKE_CORE_LIFETIME := 1.65
const SMOKE_HAZE_LIFETIME := 3.20
const SMOKE_CORE_MAX_SCALE := 1.15
const SMOKE_HAZE_MAX_SCALE := 1.60
const SMOKE_GROWTH_PEAK := 1.30

var _dust: CPUParticles3D
var _debris: CPUParticles3D
var _smoke_core: CPUParticles3D
var _smoke_haze: CPUParticles3D


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

	_smoke_core = _particles("TireSmokeCore", 22, SMOKE_CORE_LIFETIME,
		Color.WHITE, SMOKE_CORE_CARD_SIZE, true)
	_configure_smoke(_smoke_core, Vector3(0.0, 0.14, 1.28),
		Vector3(0.78, 0.04, 0.14), Vector3(0.0, 0.56, 0.30), 0.90,
		SMOKE_CORE_MAX_SCALE, 0.42, Color(0.38, 0.39, 0.37), 0.72)
	add_child(_smoke_core)

	# A second, slower layer outlives the dark tire puff. Different size, rise,
	# rotation, and fade timing keep the trail from reading as cloned discs.
	_smoke_haze = _particles("TireSmokeHaze", 14, SMOKE_HAZE_LIFETIME,
		Color.WHITE, SMOKE_HAZE_CARD_SIZE, true)
	_configure_smoke(_smoke_haze, Vector3(0.0, 0.18, 1.30),
		Vector3(0.86, 0.05, 0.20), Vector3(0.0, 0.72, 0.18), 0.56,
		SMOKE_HAZE_MAX_SCALE, 0.28, Color(0.56, 0.57, 0.54), 0.52)
	add_child(_smoke_haze)


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
	_set_emission(_smoke_core, smoke_amount)
	_set_emission(_smoke_haze, smoke_amount * 0.82)


func _particles(node_name: String, count: int, lifetime: float, color: Color,
		size: float, billowy: bool = false) -> CPUParticles3D:
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
	if billowy:
		material.albedo_texture = SMOKE_TEXTURE
		material.billboard_keep_scale = true
	quad.material = material
	particles.mesh = quad
	return particles


func _configure_smoke(particles: CPUParticles3D, local_position: Vector3,
		emission_extents: Vector3, initial_direction: Vector3,
		maximum_velocity: float, maximum_scale: float, rise_acceleration: float,
		tone: Color, peak_alpha: float) -> void:
	particles.position = local_position
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = emission_extents
	particles.direction = initial_direction
	particles.spread = 68.0
	particles.initial_velocity_min = maximum_velocity * 0.34
	particles.initial_velocity_max = maximum_velocity
	particles.gravity = Vector3(0.0, rise_acceleration, 0.0)
	particles.damping_min = 1.25
	particles.damping_max = 2.15
	particles.lifetime_randomness = 0.40
	particles.angle_min = -360.0
	particles.angle_max = 360.0
	particles.angular_velocity_min = -92.0
	particles.angular_velocity_max = 92.0
	particles.scale_amount_min = maximum_scale * 0.74
	particles.scale_amount_max = maximum_scale
	var growth := Curve.new()
	growth.min_value = 0.0
	growth.max_value = SMOKE_GROWTH_PEAK
	growth.add_point(Vector2(0.0, 0.34))
	growth.add_point(Vector2(0.14, 0.72))
	growth.add_point(Vector2(0.50, 1.08))
	growth.add_point(Vector2(1.0, SMOKE_GROWTH_PEAK))
	particles.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(tone.r, tone.g, tone.b, 0.0))
	fade.add_point(0.07, Color(tone.r, tone.g, tone.b, peak_alpha))
	fade.add_point(0.42, Color(tone.r + 0.08, tone.g + 0.08, tone.b + 0.08,
		peak_alpha * 0.76))
	fade.add_point(0.74, Color(tone.r + 0.16, tone.g + 0.16, tone.b + 0.16,
		peak_alpha * 0.38))
	fade.set_offset(fade.get_point_count() - 1, 1.0)
	fade.set_color(fade.get_point_count() - 1,
		Color(tone.r + 0.20, tone.g + 0.20, tone.b + 0.20, 0.0))
	particles.color_ramp = fade


static func maximum_haze_card_size() -> float:
	return SMOKE_HAZE_CARD_SIZE * SMOKE_HAZE_MAX_SCALE * SMOKE_GROWTH_PEAK


func _set_emission(particles: CPUParticles3D, strength: float) -> void:
	var amount := clampf(strength, 0.0, 1.0)
	var maximum_amount := int(particles.get_meta("maximum_amount", particles.amount))
	var desired_amount := maxi(1, roundi(maximum_amount * amount))
	if particles.amount != desired_amount:
		particles.amount = desired_amount
	particles.emitting = amount > 0.01
