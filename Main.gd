extends Node3D
## Small, auditable game shell: ENet lifecycle and spawn authority live here;
## player scripts own deterministic FOLLOW simulation and presentation.

const DEFAULT_PORT := 10080
const MAX_CLIENTS := 16
const ARENA_HALF := 40.0
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const PLAYER_RADIUS := VEHICLE_CONFIG.COLLISION_RADIUS
const PLAYER_SCRIPT := preload("res://player/player_body.gd")
const INPUT_SCRIPT := preload("res://player/player_input.gd")
const HULL_SCRIPT := preload("res://player/ground_vehicle_hull.gd")
const ARENA_LAYOUT := preload("res://world/arena_layout.gd")
const RAPIER_DRIVER_SCRIPT := preload("res://addons/netfox.extras/physics/rapier_driver_3d.gd")

var _role := "client"
var _host := "127.0.0.1"
var _port := DEFAULT_PORT
var _player_name := "driver"
var _scripted := ""
var _quit_after_ticks := 0
var _to_port := DEFAULT_PORT
var _latency_ms := 0
var _jitter_ms := 0
var _loss_pct := 0.0
var _force_presentation := false
var _start_tick := -1
var _next_spawn_slot := 0
var _contact_seen := false
var _minimum_pair_distance := INF
var _prediction_history := {}
var _worst_correction_error := 0.0

var _players: Node3D
var _spawner: MultiplayerSpawner
var _camera: Camera3D
var _status_label: Label

func _ready() -> void:
	_parse_args()
	if _role == "proxy":
		_start_proxy()
		return
	_connect_network_events()
	_build_world()
	NetworkTime.on_tick.connect(_on_tick)
	if _role == "server":
		_start_server()
	else:
		_start_client()

func _process(_delta: float) -> void:
	if _camera == null:
		return
	var local: Node3D = local_player()
	var target: Vector3 = Vector3.ZERO if local == null else local.global_position
	var yaw := deg_to_rad(45.0)
	var pitch := deg_to_rad(55.0)
	var horizontal := cos(pitch) * 80.0
	var offset := Vector3(sin(yaw) * horizontal, sin(pitch) * 80.0, cos(yaw) * horizontal)
	_camera.global_position = target + offset
	_camera.look_at(target, Vector3.UP)
	if _status_label != null:
		var id := multiplayer.get_unique_id()
		var speed: float = 0.0 if local == null else local.speed()
		_status_label.text = "CAR FIGHT  |  peer %d  |  %.1f u/s\nMouse: direction + distance speed  |  Space: burst" % [id, speed]

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var arg: String = args[index]
		if arg == "--server":
			_role = "server"
		elif arg == "--client":
			_role = "client"
		elif arg == "--proxy":
			_role = "proxy"
		elif arg == "--presentation-test":
			_force_presentation = true
		elif arg.begins_with("--host="):
			_host = arg.get_slice("=", 1)
		elif arg == "--host" and index + 1 < args.size():
			index += 1
			_host = args[index]
		elif arg.begins_with("--port="):
			_port = int(arg.get_slice("=", 1))
		elif arg == "--port" and index + 1 < args.size():
			index += 1
			_port = int(args[index])
		elif arg.begins_with("--name="):
			_player_name = arg.get_slice("=", 1)
		elif arg == "--name" and index + 1 < args.size():
			index += 1
			_player_name = args[index]
		elif arg.begins_with("--script="):
			_scripted = arg.get_slice("=", 1)
		elif arg == "--script" and index + 1 < args.size():
			index += 1
			_scripted = args[index]
		elif arg.begins_with("--ticks="):
			_quit_after_ticks = int(arg.get_slice("=", 1))
		elif arg == "--ticks" and index + 1 < args.size():
			index += 1
			_quit_after_ticks = int(args[index])
		elif arg.begins_with("--to-port="):
			_to_port = int(arg.get_slice("=", 1))
		elif arg == "--to-port" and index + 1 < args.size():
			index += 1
			_to_port = int(args[index])
		elif arg.begins_with("--latency="):
			_latency_ms = int(arg.get_slice("=", 1))
		elif arg == "--latency" and index + 1 < args.size():
			index += 1
			_latency_ms = int(args[index])
		elif arg.begins_with("--jitter="):
			_jitter_ms = int(arg.get_slice("=", 1))
		elif arg.begins_with("--loss="):
			_loss_pct = float(arg.get_slice("=", 1))
		index += 1

func _start_proxy() -> void:
	var proxy := Node.new()
	proxy.name = "LatencyProxy"
	proxy.set_script(load("res://net/latency_proxy.gd"))
	proxy.set("listen_port", _port)
	proxy.set("server_port", _to_port)
	proxy.set("latency_ms", _latency_ms)
	proxy.set("jitter_ms", _jitter_ms)
	proxy.set("loss_pct", _loss_pct)
	add_child(proxy)
	proxy.call("start")

func _connect_network_events() -> void:
	NetworkEvents.on_server_start.connect(func(): _log("SERVER_READY port=%d" % _port))
	NetworkEvents.on_client_start.connect(func(id: int): _log("CLIENT_READY id=%d name=%s" % [id, _player_name]))
	NetworkEvents.on_client_stop.connect(func():
		_log("CLIENT_STOPPED")
		if _quit_after_ticks > 0:
			get_tree().quit(2)
	)
	NetworkEvents.on_peer_join.connect(_on_peer_join)
	NetworkEvents.on_peer_leave.connect(_on_peer_leave)

func _start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(_port, MAX_CLIENTS)
	if error != OK:
		push_error("Could not listen on UDP %d: %s" % [_port, error_string(error)])
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	_log("server listening on udp://0.0.0.0:%d" % _port)

func _start_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(_host, _port)
	if error != OK:
		push_error("Could not connect to %s:%d: %s" % [_host, _port, error_string(error)])
		get_tree().quit(2)
		return
	multiplayer.connection_failed.connect(func():
		push_error("Connection failed to %s:%d" % [_host, _port])
		if _quit_after_ticks > 0:
			get_tree().quit(2)
	)
	multiplayer.multiplayer_peer = peer
	_log("connecting to udp://%s:%d as %s" % [_host, _port, _player_name])

func _on_peer_join(id: int) -> void:
	if not multiplayer.is_server():
		return
	_log("PEER_JOIN id=%d slot=%d" % [id, _next_spawn_slot])
	_spawner.spawn({"id": id, "slot": _next_spawn_slot})
	_next_spawn_slot += 1

func _on_peer_leave(id: int) -> void:
	if not multiplayer.is_server():
		return
	var body := _players.get_node_or_null(str(id))
	if body != null:
		body.queue_free()
	_log("PEER_LEAVE id=%d" % id)

func _build_world() -> void:
	var driver := Node.new()
	driver.name = "RapierDriver3D"
	driver.set_script(RAPIER_DRIVER_SCRIPT)
	driver.set("rollback_physics_space", false)
	add_child(driver)

	_players = Node3D.new()
	_players.name = "Players"
	add_child(_players)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _players.get_path()
	_spawner.spawn_function = _spawn_player
	_build_arena()
	if not _is_headless():
		_build_presentation()

func _spawn_player(data: Variant) -> Node:
	var info: Dictionary = data if data is Dictionary else {"id": int(data), "slot": 0}
	var owner_id := int(info.get("id", 0))
	var slot := int(info.get("slot", 0))
	var body := RigidBody3D.new()
	body.set_script(PLAYER_SCRIPT)
	body.name = str(owner_id)
	body.set("owner_id", owner_id)
	body.set("spawn_slot", slot)
	body.gravity_scale = 0.0
	body.mass = 2.2
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.axis_lock_linear_y = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_z = true
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 8
	var spawn := _spawn_transform(slot)
	body.position = spawn.origin
	body.rotation.y = spawn.basis.get_euler().y
	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = 0.35
	physics_material.friction = 0.1
	body.physics_material_override = physics_material

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var sphere := SphereShape3D.new()
	sphere.radius = PLAYER_RADIUS
	collision.shape = sphere
	body.add_child(collision)

	var input := Node.new()
	input.name = "Input"
	input.set_script(INPUT_SCRIPT)
	body.add_child(input)
	var synchronizer := Node.new()
	synchronizer.name = "RollbackSynchronizer"
	synchronizer.set_script(load("res://addons/netfox/rollback/rollback-synchronizer.gd"))
	body.add_child(synchronizer)
	var interpolator := Node.new()
	interpolator.name = "TickInterpolator"
	interpolator.set_script(load("res://addons/netfox/tick-interpolator.gd"))
	body.add_child(interpolator)

	if not _is_headless():
		_build_player_presentation(body, owner_id)
	return body

func _spawn_transform(slot: int) -> Transform3D:
	var positions := [
		Vector3(-3.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -3.0), Vector3(0.0, 0.0, 3.0),
	]
	var position: Vector3 = positions[slot % positions.size()]
	var forward := -position.normalized()
	var yaw := atan2(-forward.x, -forward.z)
	return Transform3D(Basis(Vector3.UP, yaw), position)

func _build_player_presentation(body: RigidBody3D, owner_id: int) -> void:
	var hull := Node3D.new()
	hull.name = "GroundVehicleHull"
	hull.set_script(HULL_SCRIPT)
	body.add_child(hull)

	var color := _peer_color(owner_id)
	var pip := MeshInstance3D.new()
	pip.name = "PeerMarker"
	var pip_mesh := CylinderMesh.new()
	pip_mesh.top_radius = 0.16
	pip_mesh.bottom_radius = 0.16
	pip_mesh.height = 0.12
	pip.mesh = pip_mesh
	pip.position = Vector3(0.0, 1.68, 0.0)
	pip.material_override = _material(color, true)
	body.add_child(pip)

	var is_local := owner_id == multiplayer.get_unique_id()
	var marker := MeshInstance3D.new()
	marker.name = "CursorMarker"
	marker.top_level = true
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.28
	marker_mesh.bottom_radius = 0.28
	marker_mesh.height = 0.04
	marker.mesh = marker_mesh
	marker.material_override = _material(Color(color, 0.85), true)
	marker.visible = is_local
	body.add_child(marker)

	var line := MeshInstance3D.new()
	line.name = "CursorLine"
	line.top_level = true
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.045, 0.025, 1.0)
	line.mesh = line_mesh
	line.material_override = _material(Color(color, 0.7), true)
	line.visible = is_local
	body.add_child(line)

func _build_arena() -> void:
	# Bodies are Y-locked, so the floor is deliberately visual-only. A collider
	# whose top is y=0 would start every spherical car half embedded in it and
	# compromise horizontal contact resolution.
	if not _is_headless():
		_build_shader_ground()
	_add_static_box("WallNorth", Vector3(ARENA_HALF * 2.0 + 2.0, 2.0, 1.0), Vector3(0.0, 1.0, -ARENA_HALF), Color("596674"))
	_add_static_box("WallSouth", Vector3(ARENA_HALF * 2.0 + 2.0, 2.0, 1.0), Vector3(0.0, 1.0, ARENA_HALF), Color("596674"))
	_add_static_box("WallWest", Vector3(1.0, 2.0, ARENA_HALF * 2.0), Vector3(-ARENA_HALF, 1.0, 0.0), Color("596674"))
	_add_static_box("WallEast", Vector3(1.0, 2.0, ARENA_HALF * 2.0), Vector3(ARENA_HALF, 1.0, 0.0), Color("596674"))
	for obstacle in ARENA_LAYOUT.collision_objects():
		_add_static_box(str(obstacle["name"]), obstacle["size"], obstacle["position"],
			obstacle["color"], float(obstacle["yaw"]))

func _build_shader_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "ShaderGridGround"
	ground.position.y = -0.01
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_HALF * 2.0, ARENA_HALF * 2.0)
	ground.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = load("res://world/grid_ground.gdshader")
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

func _add_static_box(node_name: String, size: Vector3, position: Vector3, color: Color,
		yaw: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation.y = yaw
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if not _is_headless():
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _material(color)
		body.add_child(mesh_instance)
	add_child(body)

func _build_presentation() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10171d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b6cad3")
	env.ambient_light_energy = 0.55
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)
	_camera = Camera3D.new()
	_camera.name = "IsometricCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 24.0
	_camera.current = true
	add_child(_camera)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	_status_label = Label.new()
	_status_label.position = Vector2(18.0, 16.0)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("e8f4f6"))
	hud.add_child(_status_label)

func cursor_offset_for(body: Node3D) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.00001:
		return Vector2.ZERO
	var t := (body.global_position.y - origin.y) / direction.y
	if t < 0.0:
		return Vector2.ZERO
	var hit := origin + direction * t
	var delta := hit - body.global_position
	return Vector2(delta.x, delta.z).limit_length(16.0)

func is_scripted_client() -> bool:
	return not _scripted.is_empty()

func scripted_input_for(body: Node3D) -> Dictionary:
	match _scripted:
		"converge", "converge-burst":
			# Fixed opposing headings make the network gate test collision rather
			# than the far-distance FOLLOW turning radius around a moving target.
			var slot := int(body.get("spawn_slot"))
			var intent := Vector2(16.0, 0.0) if slot % 2 == 0 else Vector2(-16.0, 0.0)
			return {"cursor_offset": intent, "burst": _scripted == "converge-burst"}
		"right":
			return {"cursor_offset": Vector2(16.0, 0.0), "burst": false}
		"burst-right":
			return {"cursor_offset": Vector2(16.0, 0.0), "burst": true}
		_:
			return {"cursor_offset": Vector2.ZERO, "burst": false}

func local_player():
	if _players == null:
		return null
	return _players.get_node_or_null(str(multiplayer.get_unique_id()))

func _on_tick(_delta: float, tick: int) -> void:
	if _start_tick < 0:
		_start_tick = tick
	var elapsed := tick - _start_tick
	if multiplayer.is_server():
		_track_server_contacts()
		if elapsed % 30 == 0:
			for child in _players.get_children():
				var body := child as Node3D
				if body != null:
					_receive_authority_probe.rpc_id(int(body.name), tick, int(body.name), body.position)
		if elapsed % 60 == 0:
			_log("SERVER_TICK tick=%d players=%d minpair=%.3f contact=%d" % [elapsed, _players.get_child_count(), _minimum_pair_distance, 1 if _contact_seen else 0])
	else:
		var local: Node3D = local_player()
		if local != null:
			_prediction_history[tick] = local.position
			for old_tick in _prediction_history.keys():
				if int(old_tick) < tick - 240:
					_prediction_history.erase(old_tick)
			if elapsed % 60 == 0:
				_log("CLIENT_TICK tick=%d id=%d pos=(%.3f,%.3f) speed=%.3f" % [elapsed, multiplayer.get_unique_id(), local.position.x, local.position.z, local.speed()])
	if _quit_after_ticks > 0 and elapsed >= _quit_after_ticks:
		if multiplayer.is_server():
			_log("RESULT players=%d minpair=%.3f contact=%d escapes=%d" % [_players.get_child_count(), _minimum_pair_distance, 1 if _contact_seen else 0, _server_escape_count()])
		get_tree().quit()

func _server_escape_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("collision_escape_count"))
	return total

@rpc("authority", "call_remote", "unreliable")
func _receive_authority_probe(tick: int, owner_id: int, authoritative_position: Vector3) -> void:
	if owner_id != multiplayer.get_unique_id() or not _prediction_history.has(tick):
		return
	var predicted_position: Vector3 = _prediction_history[tick]
	var error := predicted_position.distance_to(authoritative_position)
	_worst_correction_error = maxf(_worst_correction_error, error)
	_log("CORRECTION tick=%d error=%.3f worst=%.3f" % [tick, error, _worst_correction_error])

func _track_server_contacts() -> void:
	var bodies := _players.get_children()
	for i in range(bodies.size()):
		var a := bodies[i] as RigidBody3D
		if a == null:
			continue
		for j in range(i + 1, bodies.size()):
			var b := bodies[j] as RigidBody3D
			if b == null:
				continue
			_minimum_pair_distance = minf(_minimum_pair_distance, a.position.distance_to(b.position))
			if a.get_colliding_bodies().has(b):
				if not _contact_seen:
					_log("CONTACT a=%s b=%s" % [a.name, b.name])
				_contact_seen = true

func _peer_color(id: int) -> Color:
	var palette := [Color("63d8ff"), Color("ffb45e"), Color("b080ff"), Color("72df80"), Color("ff7096")]
	return palette[abs(id) % palette.size()]

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" and not _force_presentation

func _log(message: String) -> void:
	print("[car-fight:%s] %s" % [_role, message])
