extends RefCounted
## Optional local-only tree art for visual auditions. Gameplay collision remains
## on Main's deterministic cylinder and no source asset is required by the repo.

const SOURCE_PATH := \
	"res://assets/local/lowpoly_tree_collection_01/LowPoly_Tree_Collection_01_fbx.FBX"
const STYLE_NAMES := [
	"Procedural baseline",
	"Collection 21-30 (light)",
	"Collection 41-50 (light)",
	"Collection 81-90 (medium)",
	"Collection 121-130 (detailed)",
	"Collection 161-170 (light)",
	"Collection 191-200 (detailed)",
]
const STYLE_STARTS := [0, 21, 41, 81, 121, 161, 191]
const VARIANTS_PER_STYLE := 10

var _source: Node
var _templates := {}
var _loaded := false


static func source_available() -> bool:
	return ResourceLoader.exists(SOURCE_PATH)


func load_source() -> bool:
	if _loaded:
		return true
	if not source_available():
		return false
	var packed := load(SOURCE_PATH) as PackedScene
	if packed == null:
		return false
	_source = packed.instantiate()
	if _source == null:
		return false
	for style_index in range(1, STYLE_STARTS.size()):
		for offset in range(VARIANTS_PER_STYLE):
			var asset_index: int = int(STYLE_STARTS[style_index]) + offset
			var asset_name: String = "%02d" % asset_index \
				if asset_index < 100 else str(asset_index)
			var source_mesh := _source.find_child(asset_name, true, false) as MeshInstance3D
			if source_mesh == null or source_mesh.mesh == null:
				continue
			var relative_transform := _relative_transform(source_mesh)
			_templates[asset_index] = {
				"mesh": source_mesh.mesh,
				"transform": relative_transform,
				"bounds": _transformed_aabb(source_mesh.mesh.get_aabb(), relative_transform),
			}
	_source.free()
	_source = null
	_loaded = not _templates.is_empty()
	return _loaded


func build_visual(style_index: int, landmark_index: int, target_height: float) -> Node3D:
	if style_index <= 0 or style_index >= STYLE_STARTS.size() or not load_source():
		return null
	var asset_index: int = int(STYLE_STARTS[style_index]) \
		+ landmark_index % VARIANTS_PER_STYLE
	var asset_name: String = "%02d" % asset_index if asset_index < 100 else str(asset_index)
	var template: Dictionary = _templates.get(asset_index, {})
	if template.is_empty():
		return null
	var source_mesh := template["mesh"] as Mesh
	var relative_transform: Transform3D = template["transform"]
	var bounds: AABB = template["bounds"]
	if bounds.size.y <= 0.001:
		return null
	var visual := MeshInstance3D.new()
	visual.name = "CollectionTree%s" % asset_name
	visual.mesh = source_mesh
	visual.transform = relative_transform
	var center := bounds.position + bounds.size * 0.5
	# Strip the source pack's overview-grid placement, center the trunk footprint,
	# and put the lowest vertex on the existing arena ground.
	visual.position -= Vector3(center.x, bounds.position.y, center.z)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("arena_presentation", true)
	visual.set_meta("tree_visual", true)
	visual.set_meta("tree_asset_index", asset_index)
	var root := Node3D.new()
	root.name = "TreeVisual"
	root.scale = Vector3.ONE * (target_height / bounds.size.y)
	root.set_meta("arena_presentation", true)
	root.set_meta("tree_visual", true)
	root.add_child(visual)
	return root


func _relative_transform(target: Node3D) -> Transform3D:
	var result := target.transform
	var ancestor := target.get_parent() as Node3D
	while ancestor != null and ancestor != _source:
		result = ancestor.transform * result
		ancestor = ancestor.get_parent() as Node3D
	return result


static func _transformed_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var first := true
	var result := AABB()
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := transform * (bounds.position + bounds.size * Vector3(x, y, z))
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result
