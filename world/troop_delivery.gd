extends Node3D
## A server-authoritative, event-driven pickup and delivery loop. Troops are
## presentation agents, never physics or rollback bodies: the car must remain
## in the source area to collect, then hold F inside the destination radius to
## deploy. Spawn/arrival events keep every peer's visible stream coherent.

const SOURCE_POSITION := Vector3(-32.0, 0.0, 12.0)
const PLAYER_PARTICIPATION := preload("res://net/player_participation.gd")
const DESTINATION_POSITION := Vector3(32.0, 0.0, -12.0)
const COLLECTION_RADIUS := 8.0
const DROP_RADIUS := 9.0
const EMIT_RATE := 3.0
const DEPLOY_RATE := 4.0
const TROOP_SPEED := 7.0
const TROOP_HEIGHT := 0.32

var _players: Node3D
var _troops := {}
var _carried := {}
var _delivered := {}
var _emit_credit := {}
var _deploy_credit := {}
var _next_id := 1
var _troop_mesh := SphereMesh.new()
var _troop_material := StandardMaterial3D.new()

func setup(players: Node3D) -> void:
	_players = players

func _ready() -> void:
	_troop_mesh.radius = 0.18
	_troop_mesh.height = 0.36
	_troop_material.albedo_color = Color("f7d66b")
	_troop_material.emission_enabled = true
	_troop_material.emission = Color("6b5520")
	if not _is_headless():
		_build_pad("RecruitmentArea", SOURCE_POSITION, COLLECTION_RADIUS, Color("52d28d"), "STAY IN AREA: LOAD TROOPS")
		_build_pad("DropOffArea", DESTINATION_POSITION, DROP_RADIUS, Color("ff7966"), "HOLD F IN AREA: DEPLOY")
	NetworkTime.on_tick.connect(_on_tick)

func carried_by(peer_id: int) -> int:
	return int(_carried.get(peer_id, 0))

func delivered_by(peer_id: int) -> int:
	return int(_delivered.get(peer_id, 0))

static func in_collection_area(position: Vector3) -> bool:
	return _flat_distance(position, SOURCE_POSITION) <= COLLECTION_RADIUS

static func in_drop_area(position: Vector3) -> bool:
	return _flat_distance(position, DESTINATION_POSITION) <= DROP_RADIUS

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _on_tick(delta: float, _tick: int) -> void:
	if multiplayer.is_server():
		_service_source(delta)
		_service_deploy(delta)
	_service_troops(delta)

func _service_source(delta: float) -> void:
	if _players == null:
		return
	for child in PLAYER_PARTICIPATION.children(_players):
		var car := child as Node3D
		if car == null or not in_collection_area(car.global_position):
			continue
		var peer_id := int(car.name)
		var credit := float(_emit_credit.get(peer_id, 0.0)) + EMIT_RATE * delta
		while credit >= 1.0:
			credit -= 1.0
			_spawn_troop(peer_id, false, SOURCE_POSITION)
		_emit_credit[peer_id] = credit

func _service_deploy(delta: float) -> void:
	if _players == null:
		return
	for child in PLAYER_PARTICIPATION.children(_players):
		var car := child as Node3D
		if car == null:
			continue
		var peer_id := int(car.name)
		var input := car.get_node_or_null("Input")
		if input == null or not bool(input.get("drop_troops")) or not in_drop_area(car.global_position):
			_deploy_credit[peer_id] = 0.0
			continue
		var credit := float(_deploy_credit.get(peer_id, 0.0)) + DEPLOY_RATE * delta
		while credit >= 1.0 and carried_by(peer_id) > 0:
			credit -= 1.0
			_carried[peer_id] = carried_by(peer_id) - 1
			_spawn_troop(peer_id, true, car.global_position)
		_deploy_credit[peer_id] = credit

func _spawn_troop(peer_id: int, deploying: bool, position: Vector3) -> void:
	var troop_id := _next_id
	_next_id += 1
	_troop_spawn.rpc(troop_id, peer_id, deploying, position)
	_troop_spawn_local(troop_id, peer_id, deploying, position)

func _service_troops(delta: float) -> void:
	var arrived: Array[int] = []
	for troop_id in _troops:
		var troop: Dictionary = _troops[troop_id]
		var target := DESTINATION_POSITION if bool(troop["deploying"]) else _car_position(int(troop["peer_id"]))
		if target == Vector3.INF:
			continue
		var position: Vector3 = troop["position"]
		position = position.move_toward(target, TROOP_SPEED * delta)
		troop["position"] = position
		_troops[troop_id] = troop
		var visual := troop.get("visual") as MeshInstance3D
		if visual != null:
			visual.global_position = position + Vector3.UP * TROOP_HEIGHT
		if position.distance_to(target) <= 0.12:
			arrived.append(int(troop_id))
	if multiplayer.is_server():
		for troop_id in arrived:
			var troop: Dictionary = _troops.get(troop_id, {})
			if troop.is_empty():
				continue
			var peer_id := int(troop["peer_id"])
			if bool(troop["deploying"]):
				_delivered[peer_id] = delivered_by(peer_id) + 1
			else:
				_carried[peer_id] = carried_by(peer_id) + 1
			_troop_arrive.rpc(troop_id, peer_id, bool(troop["deploying"]), carried_by(peer_id), delivered_by(peer_id))
			_troop_arrive_local(troop_id, peer_id, bool(troop["deploying"]), carried_by(peer_id), delivered_by(peer_id))

func _car_position(peer_id: int) -> Vector3:
	if _players == null:
		return Vector3.INF
	var car := _players.get_node_or_null(str(peer_id)) as Node3D
	return Vector3.INF if car == null else car.global_position

@rpc("authority", "call_remote", "reliable")
func _troop_spawn(troop_id: int, peer_id: int, deploying: bool, position: Vector3) -> void:
	_troop_spawn_local(troop_id, peer_id, deploying, position)

func _troop_spawn_local(troop_id: int, peer_id: int, deploying: bool, position: Vector3) -> void:
	var troop := {"peer_id": peer_id, "deploying": deploying, "position": position}
	if not _is_headless():
		var visual := MeshInstance3D.new()
		visual.mesh = _troop_mesh
		visual.material_override = _troop_material
		add_child(visual)
		visual.global_position = position + Vector3.UP * TROOP_HEIGHT
		troop["visual"] = visual
	_troops[troop_id] = troop

@rpc("authority", "call_remote", "reliable")
func _troop_arrive(troop_id: int, peer_id: int, deploying: bool, carried: int, delivered: int) -> void:
	_troop_arrive_local(troop_id, peer_id, deploying, carried, delivered)

func _troop_arrive_local(troop_id: int, peer_id: int, _deploying: bool, carried: int, delivered: int) -> void:
	var troop: Dictionary = _troops.get(troop_id, {})
	var visual := troop.get("visual") as MeshInstance3D
	if visual != null:
		visual.queue_free()
	_troops.erase(troop_id)
	_carried[peer_id] = carried
	_delivered[peer_id] = delivered

func _build_pad(node_name: String, position: Vector3, radius: float, color: Color, label_text: String) -> void:
	var pad := Node3D.new()
	pad.name = node_name
	pad.position = position
	add_child(pad)
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.06
	disc.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color * 0.35
	disc.material_override = material
	pad.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	ring.mesh = torus
	ring.position.y = 0.08
	ring.material_override = material
	pad.add_child(ring)
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 1.3, 0.0)
	label.outline_size = 4
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pad.add_child(label)

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
