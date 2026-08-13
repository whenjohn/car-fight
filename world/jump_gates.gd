extends Node3D
## Presentation for the deterministic two-way map gates. Transit itself lives
## in player rollback simulation through map_layout.gd.

const MAP_LAYOUT := preload("res://world/map_layout.gd")

var _players: Node3D
var _gate_nodes: Array[Node3D] = []


func setup(players: Node3D) -> void:
	_players = players


func build_presentation() -> void:
	for gate in MAP_LAYOUT.gates():
		var root := Node3D.new()
		root.name = "Gate_%s" % str(gate["label"]).replace(" ", "_")
		root.position = gate["position"]
		root.set_meta("map_id", int(gate["map_id"]))
		var pad := MeshInstance3D.new()
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = MAP_LAYOUT.GATE_HALF_SIZE
		pad_mesh.bottom_radius = MAP_LAYOUT.GATE_HALF_SIZE
		pad_mesh.height = 0.05
		pad.mesh = pad_mesh
		pad.material_override = _material(Color(0.22, 0.68, 1.0, 0.28), 1.2)
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pad)
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.outer_radius = MAP_LAYOUT.GATE_HALF_SIZE + 0.18
		ring_mesh.inner_radius = MAP_LAYOUT.GATE_HALF_SIZE - 0.18
		ring_mesh.rings = 40
		ring_mesh.ring_segments = 6
		ring.mesh = ring_mesh
		ring.material_override = _material(Color(0.42, 0.86, 1.0, 0.90), 2.8)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		var label := Label3D.new()
		label.text = str(gate["label"])
		label.position = Vector3(0.0, 0.35, 0.0)
		label.font_size = 30
		label.outline_size = 9
		label.modulate = Color("bfeeff")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		root.add_child(label)
		add_child(root)
		_gate_nodes.append(root)
	set_process(true)


func _process(_delta: float) -> void:
	if _players == null:
		return
	var local := _players.get_node_or_null(str(multiplayer.get_unique_id()))
	if local == null:
		return
	var local_map := int(local.get("map_id"))
	for gate in _gate_nodes:
		gate.visible = int(gate.get_meta("map_id")) == local_map


func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = energy
	return material
