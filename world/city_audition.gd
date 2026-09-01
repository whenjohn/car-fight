extends Node3D
## Lightweight, optional presentation assembled from selected pieces of the
## local Low Poly City source. The extracted scene never contains collision or
## network state and is visible only while the local player is in the city map.

const MAP_LAYOUT := preload("res://world/map_layout.gd")
const CITY_LAYOUT := preload("res://world/city_layout.gd")
const TREE_VISUAL_LIBRARY := preload("res://world/tree_visual_library.gd")
const DISTRICT_PATH := "res://assets/local/city_audition/extracted/city_district.tscn"
const COLLECTION_121_STYLE := 4

var _players: Node3D
var _tree_library := TREE_VISUAL_LIBRARY.new()
var _district: Node3D
var _pending_district_batches: Array = []
var _pending_tree_visuals: Array[Node3D] = []
var _staged_lighting_style := 0


func setup(players: Node3D) -> void:
	_players = players


func build_presentation() -> bool:
	if not begin_staged_presentation():
		return false
	while has_pending_presentation_batches():
		add_next_presentation_batch()
	return true


## Prepare the local district without attaching its meshes to the active scene
## tree. Forward+ starts surface pipeline compilation when a MeshInstance3D
## enters the tree even if it is hidden, so Main advances these batches only
## after the previous batch has reached a presented frame.
func begin_staged_presentation() -> bool:
	if _district != null:
		return true
	if not ResourceLoader.exists(DISTRICT_PATH):
		return false
	var packed := load(DISTRICT_PATH) as PackedScene
	if packed == null:
		return false
	var source_district := packed.instantiate() as Node3D
	if source_district == null:
		return false
	_district = Node3D.new()
	_district.name = "LowPolyCityDistrict"
	_district.position = MAP_LAYOUT.CITY_CENTER
	_district.scale = Vector3.ONE * CITY_LAYOUT.SCALE
	for metadata_name in source_district.get_meta_list():
		_district.set_meta(metadata_name, source_district.get_meta(metadata_name))
	add_child(_district)
	_prepare_district_batches(source_district)
	_prepare_collection_tree_lining()
	set_process(true)
	return true


func _prepare_district_batches(source_district: Node3D) -> void:
	var batches_by_resource := {}
	var ordered_keys: Array[String] = []
	for holder in source_district.get_children():
		var key := _presentation_batch_key(holder)
		if not batches_by_resource.has(key):
			batches_by_resource[key] = []
			ordered_keys.append(key)
		source_district.remove_child(holder)
		(batches_by_resource[key] as Array).append(holder)
	for key in ordered_keys:
		_pending_district_batches.append(batches_by_resource[key])
	source_district.free()


func _presentation_batch_key(holder: Node) -> String:
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return "node:%s" % holder.name
	var visual := meshes[0] as MeshInstance3D
	if visual == null or visual.mesh == null:
		return "node:%s" % holder.name
	var resource_path := visual.mesh.resource_path
	return resource_path if not resource_path.is_empty() \
		else "mesh:%d" % visual.mesh.get_instance_id()


func _prepare_collection_tree_lining() -> void:
	if not TREE_VISUAL_LIBRARY.style_available(COLLECTION_121_STYLE):
		return
	var lining := Node3D.new()
	lining.name = "Collection121TreeLining"
	add_child(lining)
	var positions := CITY_LAYOUT.tree_lining_positions()
	for tree_index in range(positions.size()):
		var target_height := 8.0 + float(tree_index % 3) * 0.7
		var tree := _tree_library.build_visual(
			COLLECTION_121_STYLE, tree_index, target_height) as Node3D
		if tree == null:
			continue
		tree.name = "Collection121Tree%02d" % tree_index
		tree.position = MAP_LAYOUT.CITY_CENTER + positions[tree_index] * CITY_LAYOUT.SCALE
		tree.rotation_degrees.y = float((tree_index * 47) % 360)
		_pending_tree_visuals.append(tree)
	lining.set_meta("tree_count", _pending_tree_visuals.size())


func has_pending_presentation_batches() -> bool:
	return not _pending_district_batches.is_empty() \
		or not _pending_tree_visuals.is_empty()


func pending_presentation_batch_count() -> int:
	return _pending_district_batches.size() + _pending_tree_visuals.size()


func add_next_presentation_batch() -> bool:
	if not _pending_district_batches.is_empty():
		var batch: Array = _pending_district_batches.pop_front()
		for holder in batch:
			_apply_holder_shadow_style(holder)
			_district.add_child(holder)
	elif not _pending_tree_visuals.is_empty():
		var lining := get_node_or_null("Collection121TreeLining") as Node3D
		var tree := _pending_tree_visuals.pop_front() as Node3D
		if lining != null and tree != null:
			lining.add_child(tree)
	return has_pending_presentation_batches()


func _apply_holder_shadow_style(holder: Node) -> void:
	var cast_building_shadows := _staged_lighting_style in [3, 4]
	var holder_name := holder.name.to_lower()
	for node in holder.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if cast_building_shadows and not holder_name.begins_with("road_") \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_lighting_style(style_index: int) -> void:
	_staged_lighting_style = style_index
	var district := get_node_or_null("LowPolyCityDistrict")
	if district == null:
		return
	# Both sky-lit presets need building contact shadows. Roads remain outside the
	# atlas because they are flat receivers and considerably increase draw cost.
	var cast_building_shadows := style_index in [3, 4]
	for node in district.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		var holder_name := visual.get_parent().name.to_lower()
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if cast_building_shadows and not holder_name.begins_with("road_") \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if _players == null:
		return
	var local := _players.get_node_or_null(str(multiplayer.get_unique_id()))
	visible = local != null and int(local.get("map_id")) == MAP_LAYOUT.CITY
