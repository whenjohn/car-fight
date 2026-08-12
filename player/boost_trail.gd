extends Node3D
## Presentation-only boost trail adapted from g2's world-space dotted trail.

const RESAMPLER := preload("res://player/trail_resampler.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")

const TRAIL_COLOR := Color(1.0, 0.62, 0.18, 0.25)
const TRAIL_POOL_POINTS := 24
const TRAIL_LIFETIME := 0.85
const TRAIL_SAMPLE_DISTANCE := 0.55
const TRAIL_RESET_DISTANCE := 30.0
const TRAIL_DOT_RADIUS := 0.15
const TRAIL_HEIGHT := 0.14
const TRAIL_HEAD_GAP := VEHICLE_CONFIG.COLLISION_RADIUS + 0.2

var _body: RigidBody3D
var _dot_mesh := SphereMesh.new()
var _dots: Array[MeshInstance3D] = []
var _dot_materials: Array[StandardMaterial3D] = []
var _samples: Array[Dictionary] = []
var _last_sample_position := Vector3.ZERO
var _has_last_sample := false

func _ready() -> void:
	_body = get_parent() as RigidBody3D
	_build_dot_pool()

func _process(delta: float) -> void:
	if _body == null:
		return
	var origin := _trail_origin()
	var boosting := bool(_body.get("boost_active"))
	_age_samples(delta)
	if boosting:
		_emit_samples(origin)
	else:
		# A later boost begins here instead of bridging the idle path with dots.
		_last_sample_position = origin
		_has_last_sample = true
	_draw_samples(origin)

func _trail_origin() -> Vector3:
	return _body.global_position - Vector3.UP \
		* (VEHICLE_CONFIG.COLLISION_RADIUS - TRAIL_HEIGHT)

func _age_samples(delta: float) -> void:
	for sample in _samples:
		sample["age"] = float(sample.get("age", 0.0)) + delta
	while not _samples.is_empty() and float(_samples[0].get("age", 0.0)) >= TRAIL_LIFETIME:
		_samples.pop_front()

func _emit_samples(origin: Vector3) -> void:
	if not _has_last_sample:
		_last_sample_position = origin
		_has_last_sample = true
		return
	if _last_sample_position.distance_to(origin) > TRAIL_RESET_DISTANCE:
		_samples.clear()
		_last_sample_position = origin
		return
	var emitted := RESAMPLER.advance(_last_sample_position, origin,
		TRAIL_SAMPLE_DISTANCE, TRAIL_POOL_POINTS)
	_last_sample_position = emitted["anchor"] as Vector3
	for point in emitted["points"] as Array[Vector3]:
		_samples.append({"position": point, "age": 0.0})
	while _samples.size() > TRAIL_POOL_POINTS:
		_samples.pop_front()

func _draw_samples(origin: Vector3) -> void:
	var dot_index := 0
	for sample in _samples:
		var position := sample["position"] as Vector3
		if position.distance_to(origin) < TRAIL_HEAD_GAP:
			continue
		var alive := 1.0 - clampf(float(sample["age"]) / TRAIL_LIFETIME, 0.0, 1.0)
		var radius := TRAIL_DOT_RADIUS * (0.82 + alive * 0.18)
		var dot := _dots[dot_index]
		dot.global_position = position
		dot.scale = Vector3.ONE * radius
		var color := Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, alive * 0.95)
		_dot_materials[dot_index].albedo_color = color
		_dot_materials[dot_index].emission = color
		dot_index += 1
	while dot_index < TRAIL_POOL_POINTS:
		_dots[dot_index].scale = Vector3.ONE * 0.001
		dot_index += 1

func _build_dot_pool() -> void:
	_dot_mesh.radius = 1.0
	_dot_mesh.height = 2.0
	_dot_mesh.radial_segments = 8
	_dot_mesh.rings = 4
	var base_material := StandardMaterial3D.new()
	base_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_material.albedo_color = TRAIL_COLOR
	base_material.emission_enabled = true
	base_material.emission = TRAIL_COLOR
	base_material.emission_energy_multiplier = 0.4
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for index in range(TRAIL_POOL_POINTS):
		var dot := MeshInstance3D.new()
		dot.name = "BoostTrailDot_%d" % index
		dot.top_level = true
		dot.mesh = _dot_mesh
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.scale = Vector3.ONE * 0.001
		var material := base_material.duplicate() as StandardMaterial3D
		dot.material_override = material
		add_child(dot)
		_dots.append(dot)
		_dot_materials.append(material)
