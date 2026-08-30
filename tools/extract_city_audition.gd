extends SceneTree
## One-time local extraction of a small city district. Run after placing the
## source FBX and 1024 atlas under assets/local/city_audition/. The output is
## ignored by Git and avoids loading the complete three-million-vertex FBX at
## game startup.

const SOURCE_PATH := "res://assets/local/city_audition/LowPoly_City_01fbx.fbx"
const ATLAS_PATH := "res://assets/local/city_audition/textures/color_1024x1024.jpg"
const OUTPUT_ROOT := "res://assets/local/city_audition/extracted"
const CITY_LAYOUT := preload("res://world/city_layout.gd")


func _init() -> void:
	if not ResourceLoader.exists(SOURCE_PATH) or not ResourceLoader.exists(ATLAS_PATH):
		push_error("CITY_EXTRACT requires the local city FBX and 1024 atlas")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var source := (load(SOURCE_PATH) as PackedScene).instantiate()
	var root := Node3D.new()
	root.name = "CityDistrict"
	var pieces := CITY_LAYOUT.pieces()
	root.set_meta("piece_count", pieces.size())
	root.set_meta("road_piece_count", CITY_LAYOUT.roads().size())
	var atlas := StandardMaterial3D.new()
	atlas.resource_name = "LowPolyCityAtlas1K"
	atlas.albedo_texture = load(ATLAS_PATH) as Texture2D
	atlas.roughness = 0.82
	var saved_meshes := {}
	for index in range(pieces.size()):
		var spec: Dictionary = pieces[index]
		var model_name := str(spec["model"])
		var source_mesh := source.find_child(model_name, true, false) as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			push_error("CITY_EXTRACT missing model %s" % model_name)
			root.free()
			source.free()
			quit(1)
			return
		var mesh: Mesh = saved_meshes.get(model_name)
		if mesh == null:
			var output_path := "%s/%s.res" % [OUTPUT_ROOT, model_name]
			mesh = source_mesh.mesh.duplicate(true)
			if ResourceSaver.save(mesh, output_path) != OK:
				push_error("CITY_EXTRACT could not save %s" % output_path)
				quit(1)
				return
			mesh = load(output_path) as Mesh
			saved_meshes[model_name] = mesh
		var holder := Node3D.new()
		holder.name = "%s_%02d" % [model_name, index]
		holder.position = spec["position"]
		holder.rotation_degrees.y = float(spec["yaw"])
		root.add_child(holder)
		holder.owner = root
		var visual := MeshInstance3D.new()
		visual.name = "Mesh"
		visual.mesh = mesh
		visual.basis = source_mesh.transform.basis
		var bounds := _transformed_aabb(mesh.get_aabb(), Transform3D(visual.basis, Vector3.ZERO))
		var center := bounds.position + bounds.size * 0.5
		visual.position = Vector3(-center.x, -bounds.position.y, -center.z)
		visual.material_override = atlas
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(visual)
		visual.owner = root
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed,
			OUTPUT_ROOT + "/city_district.tscn") != OK:
		push_error("CITY_EXTRACT could not save district scene")
		quit(1)
		return
	print("CITY_EXTRACT PASS pieces=%d roads=%d unique_meshes=%d" % [pieces.size(),
		CITY_LAYOUT.roads().size(), saved_meshes.size()])
	root.free()
	source.free()
	quit()


func _transformed_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var result := AABB(transform * bounds.position, Vector3.ZERO)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				result = result.expand(transform * (bounds.position
					+ bounds.size * Vector3(x, y, z)))
	return result
