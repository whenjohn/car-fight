extends Node3D
## Bounded triangle-mesh impact layer. Bursts are data records, not nodes, so
## repeated slow drone fire cannot accumulate timers, materials, or particles.

const MAX_BURSTS := 24
const TTL := 0.24
const SEGMENTS := 18

var _bursts: Array[Dictionary] = []
var _seen := {}
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()

func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = "ImpactBursts"
	instance.mesh = _mesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func burst(projectile_id: int, position: Vector3, incoming_direction: Vector3,
		shielded: bool = false) -> void:
	if _seen.has(projectile_id):
		return
	_seen[projectile_id] = 0.0
	if _bursts.size() >= MAX_BURSTS:
		_bursts.remove_at(0)
	var direction := incoming_direction
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	_bursts.append({
		"id": projectile_id,
		"position": position,
		"direction": direction.normalized(),
		"shielded": shielded,
		"age": 0.0,
	})

func _process(delta: float) -> void:
	for projectile_id in _seen.keys():
		var age := float(_seen[projectile_id]) + delta
		if age > 3.0:
			_seen.erase(projectile_id)
		else:
			_seen[projectile_id] = age
	_mesh.clear_surfaces()
	for index in range(_bursts.size() - 1, -1, -1):
		var data: Dictionary = _bursts[index]
		data["age"] = float(data["age"]) + delta
		var elapsed := float(data["age"]) / TTL
		if elapsed >= 1.0:
			_bursts.remove_at(index)
			continue
		_draw_burst(data, elapsed)

func _draw_burst(data: Dictionary, elapsed: float) -> void:
	var fade := 1.0 - elapsed
	var centre: Vector3 = data["position"]
	var direction: Vector3 = data["direction"]
	var shielded := bool(data["shielded"])
	var color := Color(0.42, 0.82, 1.0, 0.92) if shielded \
		else Color(1.0, 0.78, 0.36, 0.95)
	color.a *= fade
	var radius := lerpf(0.08, 0.72 if shielded else 0.52, elapsed)
	var width := lerpf(0.10, 0.025, elapsed)
	# Face the burst upward so it reads cleanly from the isometric camera while
	# retaining the true 3D impact height.
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	_annulus(centre, radius, width, color)
	var travel := direction * lerpf(0.05, 0.72, elapsed)
	var side := Vector3(-direction.z, 0.0, direction.x)
	for spark_index in range(4):
		var spread := (float(spark_index) - 1.5) * 0.16
		var spark_direction := (-direction + side * spread).normalized()
		_spoke(centre, spark_direction, radius * 0.25, radius + travel.length(),
			width * 0.38, color)
	_mesh.surface_end()

func _annulus(centre: Vector3, radius: float, width: float, color: Color) -> void:
	var inner := maxf(radius - width * 0.5, 0.002)
	var outer := radius + width * 0.5
	for index in range(SEGMENTS):
		var d0 := _radial(index)
		var d1 := _radial(index + 1)
		_quad(centre + d0 * inner, centre + d0 * outer,
			centre + d1 * outer, centre + d1 * inner, color)

func _spoke(centre: Vector3, direction: Vector3, from_radius: float,
		to_radius: float, half_width: float, color: Color) -> void:
	var side := Vector3(-direction.z, 0.0, direction.x) * half_width
	var near := centre + direction * from_radius
	var far := centre + direction * to_radius
	_quad(near - side, far - side, far + side, near + side, color)

func _radial(index: int) -> Vector3:
	var angle := TAU * float(index) / float(SEGMENTS)
	return Vector3(cos(angle), 0.0, sin(angle))

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(a, b, c, color)
	_tri(a, c, d, color)

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(c)
