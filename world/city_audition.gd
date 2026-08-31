extends Node3D
## Lightweight, optional presentation assembled from selected pieces of the
## local Low Poly City source. The extracted scene never contains collision or
## network state and is visible only while the local player is in the city map.

const MAP_LAYOUT := preload("res://world/map_layout.gd")
const CITY_LAYOUT := preload("res://world/city_layout.gd")
const DISTRICT_PATH := "res://assets/local/city_audition/extracted/city_district.tscn"

var _players: Node3D


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
	# The normal game keeps this optional district out of the shadow pass. The
	# isolated sunlit launcher restores building shadows while leaving the many
	# flat road tiles cheap.
	if OS.get_environment("CAR_FIGHT_LIGHTING_STYLE") == "4":
		for node in district.find_children("*", "MeshInstance3D", true, false):
			var visual := node as MeshInstance3D
			var holder_name := visual.get_parent().name.to_lower()
			if not holder_name.begins_with("road_"):
				visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(district)
	set_process(true)
	return true


func _process(_delta: float) -> void:
	if _players == null:
		return
	var local := _players.get_node_or_null(str(multiplayer.get_unique_id()))
	visible = local != null and int(local.get("map_id")) == MAP_LAYOUT.CITY_AUDITION
