extends Node3D
## Compatibility-renderer ground decals for the static oil layout. Gameplay
## reads oil_slick.gd directly, so this node is safe to omit on headless peers.

const OIL_SLICK := preload("res://world/oil_slick.gd")
const MAP_LAYOUT := preload("res://world/map_layout.gd")
const DECAL_SHADER := preload("res://fx/oil_slick_decal.gdshader")
const DECAL_HEIGHT := 0.038

var _players: Node3D


func setup(players: Node3D) -> void:
	_players = players


func _ready() -> void:
	for slick in OIL_SLICK.slicks():
		_build_decal(slick)
	set_process(true)


func _process(_delta: float) -> void:
	if _players == null:
		return
	if multiplayer.multiplayer_peer == null:
		visible = true
		return
	var local := _players.get_node_or_null(str(multiplayer.get_unique_id()))
	visible = local == null or int(local.get("map_id")) == MAP_LAYOUT.CITY


func _build_decal(slick: Dictionary) -> void:
	var decal := MeshInstance3D.new()
	decal.name = str(slick["name"])
	var center: Vector3 = slick["position"]
	decal.position = center + Vector3.UP * DECAL_HEIGHT
	decal.rotation.y = float(slick["yaw"])
	var stretch: Vector2 = slick["stretch"]
	var plane := PlaneMesh.new()
	plane.size = Vector2(OIL_SLICK.RADIUS * 2.35 * stretch.x,
		OIL_SLICK.RADIUS * 2.35 * stretch.y)
	decal.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = DECAL_SHADER
	material.set_shader_parameter("seed", float(slick["seed"]))
	material.render_priority = 1
	decal.material_override = material
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.set_meta("world_presentation", true)
	add_child(decal)
