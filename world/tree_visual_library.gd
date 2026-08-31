extends RefCounted
## Optional tree art for visual auditions. Gameplay collision remains on Main's
## deterministic cylinder and no source asset is required by the repo.

const COLLECTION_SOURCE_PATH := \
	"res://assets/local/lowpoly_tree_collection_01/LowPoly_Tree_Collection_01_fbx.FBX"
const SHAPESPARK_SOURCE_PATH := \
	"res://assets/foliage/shapespark/shapespark-low-poly-plants-kit-double-sided-for-baking.fbx"
const STYLE_NAMES := [
	"Procedural baseline",
	"Collection 21-30 (light)",
	"Collection 41-50 (light)",
	"Collection 81-90 (medium)",
	"Collection 121-130 (detailed)",
	"Collection 161-170 (light)",
	"Collection 191-200 (detailed)",
	"Shapespark family 1 (4 trees)",
	"Shapespark family 2 (4 trees)",
	"Shapespark family 3 (4 trees)",
]
const STYLE_DEFINITIONS := [
	{"pack": "procedural", "start": 0, "count": 0},
	{"pack": "collection", "start": 21, "count": 10},
	{"pack": "collection", "start": 41, "count": 10},
	{"pack": "collection", "start": 81, "count": 10},
	{"pack": "collection", "start": 121, "count": 10},
	{"pack": "collection", "start": 161, "count": 10},
	{"pack": "collection", "start": 191, "count": 10},
	{"pack": "shapespark", "prefix": "Tree-01-", "count": 4},
	{"pack": "shapespark", "prefix": "Tree-02-", "count": 4},
	{"pack": "shapespark", "prefix": "Tree-03-", "count": 4},
]

var _templates := {}
var _loaded_packs := {}


static func style_available(style_index: int) -> bool:
	if style_index == 0:
		return true
	if style_index < 0 or style_index >= STYLE_DEFINITIONS.size():
		return false
	return ResourceLoader.exists(_source_path_for_pack(
		str(STYLE_DEFINITIONS[style_index]["pack"])))


static func source_available() -> bool:
	return ResourceLoader.exists(COLLECTION_SOURCE_PATH) \
		or ResourceLoader.exists(SHAPESPARK_SOURCE_PATH)


static func default_style_index() -> int:
	# Prefer the newest, much smaller Shapespark audition when installed.
	if ResourceLoader.exists(SHAPESPARK_SOURCE_PATH):
		return 7
	if ResourceLoader.exists(COLLECTION_SOURCE_PATH):
		return 1
	return 0


func build_visual(style_index: int, landmark_index: int, target_height: float) -> Node3D:
	if style_index <= 0 or style_index >= STYLE_DEFINITIONS.size():
		return null
	var definition: Dictionary = STYLE_DEFINITIONS[style_index]
	var pack_name := str(definition["pack"])
	if not _load_pack(pack_name):
		return null
	var variant_count := int(definition["count"])
	var variant_index := landmark_index % variant_count
	var asset_name := _asset_name(definition, variant_index)
	var template: Dictionary = _templates.get(_template_key(pack_name, asset_name), {})
	if template.is_empty():
		return null
	var source_mesh := template["mesh"] as Mesh
	var relative_transform: Transform3D = template["transform"]
	var bounds: AABB = template["bounds"]
	if bounds.size.y <= 0.001:
		return null
	var visual := MeshInstance3D.new()
	visual.name = "%s%s" % [pack_name.capitalize(), asset_name]
	visual.mesh = source_mesh
	visual.transform = relative_transform
	var center := bounds.position + bounds.size * 0.5
	# Strip the source pack's overview-grid placement, center the trunk footprint,
	# and put the lowest vertex on the existing arena ground.
	visual.position -= Vector3(center.x, bounds.position.y, center.z)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("arena_presentation", true)
	visual.set_meta("tree_visual", true)
	visual.set_meta("tree_asset_name", asset_name)
	visual.set_meta("tree_asset_pack", pack_name)
	var root := Node3D.new()
	root.name = "TreeVisual"
	root.scale = Vector3.ONE * (target_height / bounds.size.y)
	root.set_meta("arena_presentation", true)
	root.set_meta("tree_visual", true)
	root.add_child(visual)
	return root


func _load_pack(pack_name: String) -> bool:
	if _loaded_packs.has(pack_name):
		return bool(_loaded_packs[pack_name])
	var source_path := _source_path_for_pack(pack_name)
	if source_path.is_empty() or not ResourceLoader.exists(source_path):
		_loaded_packs[pack_name] = false
		return false
	var packed := load(source_path) as PackedScene
	if packed == null:
		_loaded_packs[pack_name] = false
		return false
	var source := packed.instantiate()
	if source == null:
		_loaded_packs[pack_name] = false
		return false
	var loaded_count := 0
	for definition_variant in STYLE_DEFINITIONS:
		var definition: Dictionary = definition_variant
		if str(definition["pack"]) != pack_name:
			continue
		for variant_index in range(int(definition["count"])):
			var asset_name := _asset_name(definition, variant_index)
			var source_mesh := source.find_child(asset_name, true, false) as MeshInstance3D
			if source_mesh == null or source_mesh.mesh == null:
				continue
			var relative_transform := _relative_transform(source_mesh, source)
			_templates[_template_key(pack_name, asset_name)] = {
				"mesh": source_mesh.mesh,
				"transform": relative_transform,
				"bounds": _transformed_aabb(source_mesh.mesh.get_aabb(), relative_transform),
			}
			loaded_count += 1
	source.free()
	_loaded_packs[pack_name] = loaded_count > 0
	return bool(_loaded_packs[pack_name])


static func _source_path_for_pack(pack_name: String) -> String:
	match pack_name:
		"collection":
			return COLLECTION_SOURCE_PATH
		"shapespark":
			return SHAPESPARK_SOURCE_PATH
	return ""


static func _asset_name(definition: Dictionary, variant_index: int) -> String:
	if definition.has("prefix"):
		return "%s%d" % [str(definition["prefix"]), variant_index + 1]
	var asset_index := int(definition["start"]) + variant_index
	return "%02d" % asset_index if asset_index < 100 else str(asset_index)


static func _template_key(pack_name: String, asset_name: String) -> String:
	return "%s:%s" % [pack_name, asset_name]


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
