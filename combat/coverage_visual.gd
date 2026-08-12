extends Node3D
## Local-only wedge visualization. Drive mode deliberately stays faint; editor
## mode adds readable fills, outlines, and drag handles.

const COVERAGE := preload("res://combat/coverage_config.gd")
const DRIVE_FILL_ALPHA := 0.018
const DRIVE_EDGE_ALPHA := 0.055
const EDIT_FILL_ALPHA := 0.16
const EDIT_EDGE_ALPHA := 0.68
const ARC_SEGMENTS := 28

var _ranges := COVERAGE.default_ranges()
var _widths := COVERAGE.default_widths()
var _editor_mode := true
var _overlay_visible := true
var _selected_zone := 0
var _flash_zone := -1
var _flash_time := 0.0
var _fills: Array[MeshInstance3D] = []
var _edges: Array[MeshInstance3D] = []
var _handles: Array[MeshInstance3D] = []

func _ready() -> void:
	for index in range(COVERAGE.ZONE_COUNT):
		var fill := MeshInstance3D.new()
		fill.name = "%sCoverageFill" % COVERAGE.ZONE_NAMES[index]
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fill.rotation.y = COVERAGE.ZONE_HEADINGS[index]
		add_child(fill)
		_fills.append(fill)
		var edge := MeshInstance3D.new()
		edge.name = "%sCoverageEdge" % COVERAGE.ZONE_NAMES[index]
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		edge.rotation.y = COVERAGE.ZONE_HEADINGS[index]
		add_child(edge)
		_edges.append(edge)
		for handle_name in ["Range", "LeftWidth", "RightWidth"]:
			var handle := MeshInstance3D.new()
			handle.name = "%s%sHandle" % [COVERAGE.ZONE_NAMES[index], handle_name]
			handle.mesh = _handle_mesh()
			handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(handle)
			_handles.append(handle)
	_rebuild()

func _process(delta: float) -> void:
	_flash_time = maxf(_flash_time - delta, 0.0)
	if _flash_time <= 0.0 and _flash_zone >= 0:
		_flash_zone = -1
		_rebuild_materials()

func set_configuration(ranges: PackedFloat32Array, widths: PackedFloat32Array) -> void:
	_ranges = ranges.duplicate()
	_widths = widths.duplicate()
	if is_node_ready():
		_rebuild()

func set_editor_mode(enabled: bool) -> void:
	_editor_mode = enabled
	if is_node_ready():
		_rebuild()

func set_overlay_visible(enabled: bool) -> void:
	_overlay_visible = enabled
	if is_node_ready():
		_rebuild()

func set_selected_zone(index: int) -> void:
	_selected_zone = clampi(index, 0, COVERAGE.ZONE_COUNT - 1)
	if is_node_ready():
		_rebuild_materials()

func flash_zone(index: int) -> void:
	_flash_zone = index
	_flash_time = 0.14
	_rebuild_materials()

func _rebuild() -> void:
	for index in range(COVERAGE.ZONE_COUNT):
		_fills[index].mesh = _wedge_mesh(_ranges[index], _widths[index])
		_edges[index].mesh = _edge_mesh(_ranges[index], _widths[index])
		var handles := COVERAGE.handle_positions(index, _ranges[index], _widths[index])
		var handle_offset := index * 3
		_set_handle(_handles[handle_offset], handles["range"])
		_set_handle(_handles[handle_offset + 1], handles["left"])
		_set_handle(_handles[handle_offset + 2], handles["right"])
	_rebuild_materials()

func _rebuild_materials() -> void:
	visible = _overlay_visible
	for index in range(COVERAGE.ZONE_COUNT):
		var selected := _editor_mode and index == _selected_zone
		var active := index == _flash_zone and _flash_time > 0.0
		var fill_alpha := EDIT_FILL_ALPHA if _editor_mode else DRIVE_FILL_ALPHA
		var edge_alpha := EDIT_EDGE_ALPHA if _editor_mode else DRIVE_EDGE_ALPHA
		if selected:
			fill_alpha = 0.25
			edge_alpha = 0.92
		if active:
			fill_alpha = 0.20
			edge_alpha = 0.82
		_fills[index].material_override = _material(Color(COVERAGE.ZONE_COLORS[index], fill_alpha))
		_edges[index].material_override = _material(Color(COVERAGE.ZONE_COLORS[index], edge_alpha))
		for handle_index in range(3):
			var handle := _handles[index * 3 + handle_index]
			handle.visible = _editor_mode and _overlay_visible
			handle.material_override = _material(Color(COVERAGE.ZONE_COLORS[index],
				1.0 if selected else 0.72))

func _set_handle(handle: MeshInstance3D, point: Vector2) -> void:
	handle.position = Vector3(point.x, 0.05, point.y)

func _wedge_mesh(reach: float, width: float) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3(0.0, 0.01, 0.0)])
	var indices := PackedInt32Array()
	for step in range(ARC_SEGMENTS + 1):
		var angle := -width * 0.5 + width * float(step) / ARC_SEGMENTS
		vertices.append(Vector3(-sin(angle) * reach, 0.01, -cos(angle) * reach))
		if step > 0:
			indices.append_array(PackedInt32Array([0, step, step + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _edge_mesh(reach: float, width: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(Vector3.ZERO)
	for step in range(ARC_SEGMENTS + 1):
		var angle := -width * 0.5 + width * float(step) / ARC_SEGMENTS
		mesh.surface_add_vertex(Vector3(-sin(angle) * reach, 0.035, -cos(angle) * reach))
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_end()
	return mesh

func _handle_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.20
	mesh.bottom_radius = 0.20
	mesh.height = 0.10
	mesh.radial_segments = 12
	return mesh

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	return material
