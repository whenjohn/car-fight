extends RefCounted
## Builds the accepted Collection 121-130 city trees from optional local art.
## Gameplay collision remains deterministic and independent of these visuals.

const COLLECTION_SOURCE_PATH := \
	"res://assets/local/lowpoly_tree_collection_01/LowPoly_Tree_Collection_01_fbx.FBX"
const FIRST_ASSET_INDEX := 121
const VARIANT_COUNT := 10

var _templates := {}
var _load_attempted := false
var _loaded := false


static func source_available() -> bool:
	return ResourceLoader.exists(COLLECTION_SOURCE_PATH)


func build_visual(tree_index: int, target_height: float) -> Node3D:
	if not _load_source():
		return null
	var asset_index := FIRST_ASSET_INDEX + posmod(tree_index, VARIANT_COUNT)
	var asset_name := str(asset_index)
	var template: Dictionary = _templates.get(asset_name, {})
	if template.is_empty():
		return null
	var source_mesh := template["mesh"] as Mesh
	var relative_transform: Transform3D = template["transform"]
	var bounds: AABB = template["bounds"]
	if bounds.size.y <= 0.001:
		return null
	var visual := MeshInstance3D.new()
	visual.name = "Collection%s" % asset_name
	visual.mesh = source_mesh
	visual.transform = relative_transform
	var center := bounds.position + bounds.size * 0.5
	# Strip the source pack's overview-grid placement, center the trunk footprint,
	# and put the lowest vertex on the existing city ground.
	visual.position -= Vector3(center.x, bounds.position.y, center.z)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("world_presentation", true)
	visual.set_meta("tree_visual", true)
	visual.set_meta("tree_asset_name", asset_name)
	visual.set_meta("tree_asset_pack", "collection")
	var root := Node3D.new()
	root.name = "TreeVisual"
	root.scale = Vector3.ONE * (target_height / bounds.size.y)
	root.set_meta("world_presentation", true)
	root.set_meta("tree_visual", true)
	root.add_child(visual)
	return root


func _load_source() -> bool:
	if _load_attempted:
		return _loaded
	_load_attempted = true
	if not source_available():
		return false
	var packed := load(COLLECTION_SOURCE_PATH) as PackedScene
	if packed == null:
		return false
	var source := packed.instantiate()
	if source == null:
		return false
	for offset in range(VARIANT_COUNT):
		var asset_name := str(FIRST_ASSET_INDEX + offset)
		var source_mesh := source.find_child(asset_name, true, false) as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			continue
		var relative_transform := _relative_transform(source_mesh, source)
		_templates[asset_name] = {
			"mesh": source_mesh.mesh,
			"transform": relative_transform,
			"bounds": _transformed_aabb(source_mesh.mesh.get_aabb(), relative_transform),
		}
	source.free()
	_loaded = not _templates.is_empty()
	return _loaded


static func _relative_transform(target: Node3D, source: Node) -> Transform3D:
	var result := target.transform
	var ancestor := target.get_parent() as Node3D
	while ancestor != null and ancestor != source:
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
