extends RefCounted
## Optional local-only scenery props. They never add collision, physics, or
## network state and are skipped entirely by normal headless processes.

const STONES_PATH := "res://assets/local/prop_auditions/stones/stones.fbx"
const STONES_TEXTURE_ROOT := "res://assets/local/prop_auditions/stones/"
const HOUSE_PATH := "res://assets/local/prop_auditions/ruin_house/Ruin+House.fbx"
const HOUSE_TEXTURE_ROOT := "res://assets/local/prop_auditions/ruin_house/textures/"
const STONE_LAYOUT := [
	{"position": Vector3(-9.0, 0.0, 7.0), "yaw": -18.0},
	{"position": Vector3(-7.0, 0.0, -8.0), "yaw": 31.0},
	{"position": Vector3(7.0, 0.0, -7.0), "yaw": -42.0},
	{"position": Vector3(10.0, 0.0, 2.0), "yaw": 14.0},
	{"position": Vector3(-11.0, 0.0, -1.0), "yaw": 47.0},
	{"position": Vector3(6.0, 0.0, 8.0), "yaw": -27.0},
]


static func source_available() -> bool:
	return ResourceLoader.exists(STONES_PATH) or ResourceLoader.exists(HOUSE_PATH)


func build_audition() -> Node3D:
	var root := Node3D.new()
	root.name = "LocalPropAuditions"
	root.set_meta("arena_presentation", true)
	var house := _build_house()
	if house != null:
		root.add_child(house)
	var stones := _build_stones()
	if stones != null:
		root.add_child(stones)
	if root.get_child_count() == 0:
		root.free()
		return null
	return root


func _build_house() -> Node3D:
	var packed := load(HOUSE_PATH) as PackedScene if ResourceLoader.exists(HOUSE_PATH) else null
	if packed == null:
		return null
	var source := packed.instantiate()
	var source_mesh := source.find_child("Ruin", true, false) as MeshInstance3D
	if source_mesh == null or source_mesh.mesh == null:
		source.free()
		return null
	var relative_transform := _relative_transform(source_mesh, source)
	var bounds := _transformed_aabb(source_mesh.mesh.get_aabb(), relative_transform)
	var visual := MeshInstance3D.new()
	visual.name = "RuinHouseMesh"
	visual.mesh = source_mesh.mesh
	visual.transform = relative_transform
	_center_and_ground(visual, bounds)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("arena_presentation", true)
	for surface_index in range(visual.mesh.get_surface_count()):
		var imported_material := visual.mesh.surface_get_material(surface_index)
		var material_name := imported_material.resource_name if imported_material != null else "Wall"
		visual.set_surface_override_material(surface_index, _house_material(material_name))
	var root := Node3D.new()
	root.name = "RuinHouseAudition"
	root.rotation_degrees.y = 10.0
	root.set_meta("arena_presentation", true)
	root.set_meta("audition_dimensions", bounds.size)
	root.add_child(visual)
	source.free()
	return root


func _build_stones() -> Node3D:
	var packed := load(STONES_PATH) as PackedScene if ResourceLoader.exists(STONES_PATH) else null
	if packed == null:
		return null
	var source := packed.instantiate()
	var root := Node3D.new()
	root.name = "StoneAuditions"
	root.set_meta("arena_presentation", true)
	var material := _stone_material()
	var maximum_height := 0.0
	for index in range(STONE_LAYOUT.size()):
		var source_mesh := source.find_child("stone%d" % (index + 1), true, false) as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			continue
		var relative_transform := _relative_transform(source_mesh, source)
		var bounds := _transformed_aabb(source_mesh.mesh.get_aabb(), relative_transform)
		maximum_height = maxf(maximum_height, bounds.size.y)
		var visual := MeshInstance3D.new()
		visual.name = "Stone%dMesh" % (index + 1)
		visual.mesh = source_mesh.mesh
		visual.transform = relative_transform
		_center_and_ground(visual, bounds)
		visual.material_override = material
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.set_meta("arena_presentation", true)
		var holder := Node3D.new()
		holder.name = "Stone%d" % (index + 1)
		holder.position = STONE_LAYOUT[index]["position"]
		holder.rotation_degrees.y = float(STONE_LAYOUT[index]["yaw"])
		holder.set_meta("arena_presentation", true)
		holder.add_child(visual)
		root.add_child(holder)
	root.set_meta("stone_count", root.get_child_count())
	root.set_meta("maximum_stone_height", maximum_height)
	source.free()
	if root.get_child_count() == 0:
		root.free()
		return null
	return root


func _stone_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "StonesAudition1K"
	material.albedo_color = Color.WHITE
	material.albedo_texture = _texture(STONES_TEXTURE_ROOT + "stones_baseColor.png")
	material.normal_enabled = true
	material.normal_texture = _texture(STONES_TEXTURE_ROOT + "stones_Normal.png")
	material.roughness = 0.9
	material.roughness_texture = _texture(STONES_TEXTURE_ROOT + "stones_Roughness.png")
	material.metallic = 0.0
	return material


func _house_material(material_name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "%sAudition1K" % material_name
	material.roughness = 0.88
	var texture_stem := material_name
	if material_name == "Wall":
		material.albedo_color = Color("867b6d")
	else:
		material.albedo_color = Color.WHITE
		material.albedo_texture = _texture(
			HOUSE_TEXTURE_ROOT + texture_stem + "_Base_Color.png")
	return material


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func _center_and_ground(visual: MeshInstance3D, bounds: AABB) -> void:
	var center := bounds.position + bounds.size * 0.5
	visual.position -= Vector3(center.x, bounds.position.y, center.z)


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
