extends Node3D
## Render-only grass: collision stays on Main's single static ground body, while
## the GPU bends blades away from every replicated Jeep and live bolt.

const GRASS_SHADER := preload("res://fx/interactive_grass.gdshader")
const CHUNK_SIZE := 14.0
const CHUNKS_PER_SIDE := 3
const TUFTS_PER_CHUNK := 900
const FIELD_HALF_EXTENT := CHUNK_SIZE * CHUNKS_PER_SIDE * 0.5
const OFF_FIELD := Vector3(10000.0, 0.0, 10000.0)
const SHOCKWAVE_DURATION := 2.1

var _players: Node3D
var _bolts: Node3D
var _material: ShaderMaterial
var _shockwave_age := SHOCKWAVE_DURATION

func setup(players: Node3D, bolts: Node3D) -> void:
	_players = players
	_bolts = bolts

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	_material = ShaderMaterial.new()
	_material.shader = GRASS_SHADER
	add_to_group("interactive_grass")
	var tuft_mesh := _build_tuft_mesh()
	var random := RandomNumberGenerator.new()
	random.seed = 0xCA4F17
	for z in CHUNKS_PER_SIDE:
		for x in CHUNKS_PER_SIDE:
			_add_chunk(x, z, tuft_mesh, random)

func _build_tuft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_material)
	for blade in 3:
		var angle := float(blade) * PI / 3.0
		var right := Vector3(cos(angle), 0.0, sin(angle))
		var normal := Vector3(-right.z, 0.18, right.x).normalized()
		var offset := Vector3(cos(angle + 0.31), 0.0, sin(angle + 0.31)) * 0.11
		for segment in 2:
			var lo := float(segment) * 0.5
			var hi := float(segment + 1) * 0.5
			var lo_width := lerpf(0.085, 0.012, lo)
			var hi_width := lerpf(0.085, 0.012, hi)
			var lo_center := offset + Vector3.UP * lo * 1.65
			var hi_center := offset + Vector3.UP * hi * 1.65
			_add_quad(surface, lo_center - right * lo_width, lo_center + right * lo_width,
				hi_center + right * hi_width, hi_center - right * hi_width, lo, hi, normal)
	surface.index()
	return surface.commit()

func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		lo: float, hi: float, normal: Vector3) -> void:
	for vertex in [[a, Vector2(0.0, lo)], [b, Vector2(1.0, lo)], [c, Vector2(1.0, hi)],
		[b, Vector2(1.0, lo)], [d, Vector2(0.0, hi)], [c, Vector2(1.0, hi)]]:
		surface.set_uv(vertex[1])
		surface.set_normal(normal)
		surface.add_vertex(vertex[0])

func _add_chunk(x: int, z: int, tuft_mesh: ArrayMesh, random: RandomNumberGenerator) -> void:
	var chunk := MultiMeshInstance3D.new()
	chunk.name = "GrassChunk%d_%d" % [x, z]
	chunk.position = Vector3((float(x) + 0.5) * CHUNK_SIZE - FIELD_HALF_EXTENT, 0.035,
		(float(z) + 0.5) * CHUNK_SIZE - FIELD_HALF_EXTENT)
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = tuft_mesh
	multimesh.instance_count = TUFTS_PER_CHUNK
	multimesh.custom_aabb = AABB(Vector3(-CHUNK_SIZE * 0.5 - 1.5, -0.3, -CHUNK_SIZE * 0.5 - 1.5),
		Vector3(CHUNK_SIZE + 3.0, 2.2, CHUNK_SIZE + 3.0))
	for index in TUFTS_PER_CHUNK:
		var position := Vector3(random.randf_range(-CHUNK_SIZE * 0.5, CHUNK_SIZE * 0.5), 0.0,
			random.randf_range(-CHUNK_SIZE * 0.5, CHUNK_SIZE * 0.5))
		var width := random.randf_range(0.70, 1.18)
		var height := random.randf_range(0.80, 1.48)
		var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(Vector3(width, height, width))
		multimesh.set_instance_transform(index, Transform3D(basis, position))
		multimesh.set_instance_custom_data(index, Color(random.randf_range(0.0, TAU), width,
			random.randf(), random.randf()))
	chunk.multimesh = multimesh
	add_child(chunk)

func _process(delta: float) -> void:
	if _material == null:
		return
	var positions := PackedVector3Array()
	var trails := PackedVector3Array()
	for index in 4:
		positions.append(OFF_FIELD)
		trails.append(OFF_FIELD)
	if _players != null:
		var index := 0
		for child in _players.get_children():
			if index >= 4:
				break
			var body := child as RigidBody3D
			if body == null:
				continue
			positions[index] = body.global_position
			trails[index] = body.global_position - Vector3(body.linear_velocity.x, 0.0,
				body.linear_velocity.z) * 0.11
			index += 1
	_material.set_shader_parameter("vehicle_positions", positions)
	_material.set_shader_parameter("vehicle_trail_positions", trails)
	_update_bolt_wakes()
	_update_impact_ripple(delta)

## One bounded event slot keeps collision presentation cheap: a new Jeep impact
## replaces an older ring instead of retaining per-blade or per-impact state.
func trigger_impact_ripple(world_position: Vector3, radius: float) -> void:
	_shockwave_age = 0.0
	_material.set_shader_parameter("shockwave_position", world_position)
	_material.set_shader_parameter("shockwave_radius", radius)
	_material.set_shader_parameter("shockwave_age", _shockwave_age)
	_material.set_shader_parameter("shockwave_active", 1.0)

func _update_impact_ripple(delta: float) -> void:
	if _shockwave_age >= SHOCKWAVE_DURATION:
		return
	_shockwave_age = minf(_shockwave_age + delta, SHOCKWAVE_DURATION)
	_material.set_shader_parameter("shockwave_age", _shockwave_age)
	if _shockwave_age >= SHOCKWAVE_DURATION:
		_material.set_shader_parameter("shockwave_active", 0.0)

func _update_bolt_wakes() -> void:
	var positions := PackedVector3Array()
	var trails := PackedVector3Array()
	for index in 3:
		positions.append(OFF_FIELD)
		trails.append(OFF_FIELD)
	if _bolts != null:
		var index := 0
		for child in _bolts.get_children():
			if index >= 3:
				break
			var bolt := child as Node3D
			if bolt == null:
				continue
			var velocity: Vector3 = bolt.get("velocity")
			positions[index] = bolt.global_position
			trails[index] = bolt.global_position - velocity.normalized() * minf(velocity.length() * 0.45, 14.0)
			index += 1
	_material.set_shader_parameter("bolt_positions", positions)
	_material.set_shader_parameter("bolt_trail_positions", trails)
