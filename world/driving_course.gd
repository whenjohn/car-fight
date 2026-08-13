extends Node3D
## A dedicated driving test circuit. Route geometry is deterministic and
## doubles as the exact off-track test; presentation merely visualizes it.

const MAP_LAYOUT := preload("res://world/map_layout.gd")
const TRACK_HALF_WIDTH := 7.5
const BAND_HEIGHT := 0.025
const CENTERLINE_HEIGHT := 0.034
const CENTERLINE_HALF_WIDTH := 0.22
const FLASH_SPEED := 0.011

var _players: Node3D
var _band_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _section_labels: Array[Label3D] = []


func setup(players: Node3D) -> void:
	_players = players


## The letters are stable test vocabulary for live tuning discussions.
static func sections() -> Array[Dictionary]:
	return [
		{"id": "A", "name": "LONG STRAIGHT", "points": [
			Vector2(-100.0, 60.0), Vector2(20.0, 60.0)]},
		{"id": "B", "name": "FAST SWEEPER", "points": [
			Vector2(20.0, 60.0), Vector2(45.0, 52.0),
			Vector2(60.0, 35.0), Vector2(82.0, 35.0)]},
		{"id": "C", "name": "TIGHT 90", "points": [
			Vector2(82.0, 35.0), Vector2(82.0, -45.0)]},
		{"id": "D", "name": "BACK STRAIGHT", "points": [
			Vector2(82.0, -45.0), Vector2(-25.0, -45.0)]},
		{"id": "E", "name": "HAIRPIN", "points": [
			Vector2(-25.0, -45.0), Vector2(-65.0, -45.0),
			Vector2(-92.0, -25.0), Vector2(-92.0, 10.0),
			Vector2(-72.0, 28.0)]},
		{"id": "F", "name": "SLALOM", "points": [
			Vector2(-72.0, 28.0), Vector2(-48.0, 45.0),
			Vector2(-25.0, 25.0), Vector2(0.0, 45.0), Vector2(24.0, 25.0)]},
		{"id": "G", "name": "TECHNICAL RETURN", "points": [
			Vector2(24.0, 25.0), Vector2(10.0, 45.0),
			Vector2(-30.0, 45.0), Vector2(-55.0, 58.0), Vector2(-100.0, 60.0)]},
	]


static func world_point(local: Vector2) -> Vector3:
	return MAP_LAYOUT.COURSE_CENTER + Vector3(local.x, 0.0, local.y)


static func legs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section in sections():
		var points: Array = section["points"]
		for index in range(points.size() - 1):
			result.append({"section": section["id"],
				"a": world_point(points[index]), "b": world_point(points[index + 1])})
	return result


static func off_track(position: Vector3) -> bool:
	for leg in legs():
		if segment_distance_xz(position, leg["a"], leg["b"]) <= TRACK_HALF_WIDTH:
			return false
	return true


static func section_at(position: Vector3) -> Dictionary:
	var best_distance := INF
	var best_id := "A"
	for leg in legs():
		var distance := segment_distance_xz(position, leg["a"], leg["b"])
		if distance < best_distance:
			best_distance = distance
			best_id = str(leg["section"])
	for section in sections():
		if str(section["id"]) == best_id:
			return {"id": best_id, "name": section["name"], "distance": best_distance}
	return {"id": best_id, "name": "", "distance": best_distance}


static func segment_distance_xz(position: Vector3, a: Vector3, b: Vector3) -> float:
	var delta := Vector2(b.x - a.x, b.z - a.z)
	var length_squared := delta.length_squared()
	if length_squared <= 0.0001:
		return Vector2(position.x - a.x, position.z - a.z).length()
	var from_a := Vector2(position.x - a.x, position.z - a.z)
	var amount := clampf(from_a.dot(delta) / length_squared, 0.0, 1.0)
	return from_a.distance_to(delta * amount)


func build_presentation() -> void:
	_band_material = _material(Color(0.20, 0.82, 0.47, 0.19), 0.35)
	_line_material = _material(Color(0.48, 1.0, 0.66, 0.78), 1.1)
	var band := MeshInstance3D.new()
	band.name = "DrivingCourseBand"
	band.mesh = _route_mesh(TRACK_HALF_WIDTH, BAND_HEIGHT)
	band.material_override = _band_material
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	var line := MeshInstance3D.new()
	line.name = "DrivingCourseCenterline"
	line.mesh = _route_mesh(CENTERLINE_HALF_WIDTH, CENTERLINE_HEIGHT)
	line.material_override = _line_material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	for section in sections():
		var label := Label3D.new()
		label.name = "Section%s" % section["id"]
		label.text = str(section["id"])
		label.position = _section_midpoint(section) + Vector3.UP * 0.18
		label.font_size = 54
		label.outline_size = 12
		label.modulate = Color("e8fff0")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)
		_section_labels.append(label)
	set_process(true)


func _process(_delta: float) -> void:
	if _band_material == null or _players == null:
		return
	var local := _players.get_node_or_null(str(multiplayer.get_unique_id()))
	var on_course := local != null and int(local.get("map_id")) == MAP_LAYOUT.DRIVING_COURSE
	visible = on_course
	if not on_course:
		return
	var off := off_track(local.global_position)
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * FLASH_SPEED)
	if off:
		_band_material.albedo_color = Color(1.0, 0.22, 0.06, 0.22 + 0.17 * pulse)
		_line_material.albedo_color = Color(1.0, 0.48, 0.12, 0.72 + 0.28 * pulse)
		_band_material.emission = Color("ff3f12")
		_line_material.emission = Color("ff7a20")
		_band_material.emission_energy_multiplier = 1.4 + 2.0 * pulse
		_line_material.emission_energy_multiplier = 2.0 + 3.0 * pulse
	else:
		_band_material.albedo_color = Color(0.20, 0.82, 0.47, 0.19)
		_line_material.albedo_color = Color(0.48, 1.0, 0.66, 0.78)
		_band_material.emission = Color("34b96d")
		_line_material.emission = Color("70ef9b")
		_band_material.emission_energy_multiplier = 0.35
		_line_material.emission_energy_multiplier = 1.1
	for label in _section_labels:
		label.modulate = Color("ffad58") if off else Color("e8fff0")


func _section_midpoint(section: Dictionary) -> Vector3:
	var points: Array = section["points"]
	var index := (points.size() - 1) / 2
	return world_point((points[index] as Vector2).lerp(points[index + 1], 0.5))


func _route_mesh(half_width: float, height: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for leg in legs():
		_emit_band(mesh, leg["a"], leg["b"], half_width, height)
	mesh.surface_end()
	return mesh


func _emit_band(mesh: ImmediateMesh, a: Vector3, b: Vector3,
		half_width: float, height: float) -> void:
	var direction := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if direction.length_squared() <= 0.0001:
		return
	direction = direction.normalized()
	var perpendicular := Vector3(-direction.z, 0.0, direction.x) * half_width
	var start := a - direction * half_width + Vector3.UP * height
	var finish := b + direction * half_width + Vector3.UP * height
	for point in [start + perpendicular, finish + perpendicular,
			finish - perpendicular, start + perpendicular,
			finish - perpendicular, start - perpendicular]:
		mesh.surface_add_vertex(point)


func _material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
