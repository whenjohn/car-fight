extends Node3D
## Bounded Compatibility-renderer dust at the advancing front-to-back cloak edge.

const PARTICLE_COUNT := 260
const VEHICLE_FRONT := 1.85
const VEHICLE_BACK := -1.85
const VEHICLE_HALF_WIDTH := 0.88
const VEHICLE_BOTTOM := 0.05
const VEHICLE_TOP := 1.20

var _multimesh: MultiMesh
var _positions: Array[Vector3] = []
var _velocities: Array[Vector3] = []
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _scales := PackedFloat32Array()
var _opacities := PackedFloat32Array()
var _colors: Array[Color] = []
var _active := PackedByteArray()
var _cursor := 0
var _previous_amount := 0.0
var _spawn_budget := 0.0
var _source_velocity := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	_rng.seed = 0xC10A4
	_build_pool()

func _process(delta: float) -> void:
	if _multimesh == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	for index in range(PARTICLE_COUNT):
		if _active[index] == 0:
			continue
		var age := _ages[index] + delta
		_ages[index] = age
		var lifetime := _lifetimes[index]
		if age >= lifetime:
			_active[index] = 0
			_hide(index)
			continue
		var velocity := _velocities[index]
		var position := _positions[index]
		var curl := Vector3(sin(position.y * 8.0 + now * 2.4 + index), 0.0,
			cos((position.x + position.z) * 7.0 - now * 2.1 + index * 0.7)) * 0.18
		velocity += (curl + Vector3(0.0, 0.10, 0.0)) * delta
		velocity *= exp(-0.72 * delta)
		position += velocity * delta
		_velocities[index] = velocity
		_positions[index] = position
		var life_t := age / lifetime
		var fade_in := smoothstep(0.0, 0.08, life_t)
		var fade_out := 1.0 - smoothstep(0.48, 1.0, life_t)
		var scale_envelope := fade_in * (0.82 + life_t * 0.34)
		var opacity_envelope := fade_in * fade_out \
			* (0.84 + 0.16 * sin(now * 5.0 + index * 1.91))
		_multimesh.set_instance_transform(index, Transform3D(
			Basis.IDENTITY.scaled(Vector3.ONE * _scales[index] * scale_envelope), position))
		var color := _colors[index]
		color.a = opacity_envelope * _opacities[index]
		_multimesh.set_instance_color(index, color)

## Dust emits only while the cloak removes the Jeep. Decloaking reconstructs
## cleanly while the cut itself travels back-to-front.
func set_cloak(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	var advance := amount - _previous_amount
	if advance < 0.0:
		_spawn_budget = 0.0
	elif _multimesh != null and advance > 0.0001:
		# Accumulate fractional particles so each render frame emits a few
		# scattered motes instead of one dense clump at the cut plane.
		_spawn_budget += advance * 155.0 * _rng.randf_range(0.72, 1.20)
		var count := mini(int(floor(_spawn_budget)), 14)
		_spawn_budget -= count
		for _particle in range(count):
			var sampled_amount := lerpf(_previous_amount, amount, _rng.randf())
			_spawn(lerpf(VEHICLE_FRONT, VEHICLE_BACK, sampled_amount))
	_previous_amount = amount

func set_source_velocity(velocity: Vector3) -> void:
	_source_velocity = velocity

func _build_pool() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.instance_count = PARTICLE_COUNT
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color(0.22, 0.58, 1.0)
	material.emission_energy_multiplier = 0.8
	quad.material = material
	_multimesh.mesh = quad
	var dust := MultiMeshInstance3D.new()
	dust.name = "VehicleCloakDustParticles"
	dust.multimesh = _multimesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.top_level = true
	add_child(dust)
	dust.global_transform = Transform3D.IDENTITY
	for index in range(PARTICLE_COUNT):
		_positions.append(Vector3.ZERO)
		_velocities.append(Vector3.ZERO)
		_ages.append(0.0)
		_lifetimes.append(1.0)
		_scales.append(0.0)
		_opacities.append(0.0)
		_colors.append(Color.WHITE)
		_active.append(0)
		_hide(index)

func _spawn(cut_position: float) -> void:
	var index := _cursor
	_cursor = (_cursor + 1) % PARTICLE_COUNT
	var local_position := Vector3(
		_rng.randf_range(-VEHICLE_HALF_WIDTH, VEHICLE_HALF_WIDTH),
		_rng.randf_range(VEHICLE_BOTTOM, VEHICLE_TOP),
		-cut_position + _rng.randf_range(-0.30, 0.22))
	var world_position := global_transform * local_position
	var planar_source := Vector3(_source_velocity.x, 0.0, _source_velocity.z)
	if planar_source.length_squared() > 0.01:
		world_position -= planar_source.normalized() * _rng.randf_range(0.0, 0.32)
	var local_outward := Vector3(signf(local_position.x), _rng.randf_range(0.15, 0.8),
		_rng.randf_range(-0.35, 0.35)).normalized()
	_positions[index] = world_position
	_velocities[index] = _source_velocity * _rng.randf_range(0.01, 0.10) \
		+ (global_basis * local_outward) * _rng.randf_range(0.14, 0.82)
	_ages[index] = 0.0
	_lifetimes[index] = _rng.randf_range(0.90, 2.35)
	_scales[index] = _rng.randf_range(0.32, 1.05)
	_opacities[index] = _rng.randf_range(0.15, 0.62)
	_colors[index] = [Color(0.62, 0.84, 1.0), Color(0.90, 0.98, 1.0),
		Color(0.28, 0.66, 1.0), Color(0.16, 0.40, 0.94)][_rng.randi_range(0, 3)]
	_active[index] = 1

func _hide(index: int) -> void:
	_multimesh.set_instance_transform(index, Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3.ZERO))
	_multimesh.set_instance_color(index, Color.TRANSPARENT)
