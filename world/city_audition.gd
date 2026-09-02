extends Node3D
## Lightweight, optional presentation assembled from selected pieces of the
## local Low Poly City source. The extracted scene never contains collision or
## network state and is visible only while the local player is in the city map.

const MAP_LAYOUT := preload("res://world/map_layout.gd")
const CITY_LAYOUT := preload("res://world/city_layout.gd")
const TREE_VISUAL_LIBRARY := preload("res://world/tree_visual_library.gd")
const DISTRICT_PATH := "res://assets/local/city_audition/extracted/city_district.tscn"

var _players: Node3D
var _tree_library := TREE_VISUAL_LIBRARY.new()


func setup(players: Node3D) -> void:
	_players = players


func build_presentation() -> bool:
	if not ResourceLoader.exists(DISTRICT_PATH):
		return false
	var packed := load(DISTRICT_PATH) as PackedScene
	if packed == null:
		return false
	var district := packed.instantiate() as Node3D
	if district == null:
		return false
	district.name = "LowPolyCityDistrict"
	district.position = MAP_LAYOUT.CITY_CENTER
	district.scale = Vector3.ONE * CITY_LAYOUT.SCALE
	add_child(district)
	_build_collection_tree_lining()
	set_process(true)
	return true


func _build_collection_tree_lining() -> void:
	if not TREE_VISUAL_LIBRARY.source_available():
		return
	var lining := Node3D.new()
	lining.name = "Collection121TreeLining"
	var positions := CITY_LAYOUT.tree_lining_positions()
	for tree_index in range(positions.size()):
		var target_height := 8.0 + float(tree_index % 3) * 0.7
		var tree := _tree_library.build_visual(tree_index, target_height) as Node3D
		if tree == null:
			continue
		tree.name = "Collection121Tree%02d" % tree_index
		tree.position = MAP_LAYOUT.CITY_CENTER + positions[tree_index] * CITY_LAYOUT.SCALE
		tree.rotation_degrees.y = float((tree_index * 47) % 360)
		lining.add_child(tree)
	lining.set_meta("tree_count", lining.get_child_count())
	add_child(lining)


func set_lighting_style(style_index: int) -> void:
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
