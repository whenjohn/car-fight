extends Node3D
## Small, auditable game shell: ENet lifecycle and spawn authority live here;
## player scripts own deterministic FOLLOW simulation and presentation.

const DEFAULT_PORT := 10080
const MAX_CLIENTS := 16
const ARENA_CONFIG := preload("res://world/arena_config.gd")
const ARENA_HALF := ARENA_CONFIG.HALF_EXTENT
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const PLAYER_RADIUS := VEHICLE_CONFIG.COLLISION_RADIUS
const PLAYER_SCRIPT := preload("res://player/player_body.gd")
const INPUT_SCRIPT := preload("res://player/player_input.gd")
const HULL_SCRIPT := preload("res://player/ground_vehicle_hull.gd")
const BOOST_VELOCITY_BLUR_SCRIPT := preload("res://fx/boost_velocity_blur.gd")
const COVERAGE := preload("res://combat/coverage_config.gd")
const AUTO_TARGETING := preload("res://combat/auto_targeting.gd")
const COVERAGE_VISUAL_SCRIPT := preload("res://combat/coverage_visual.gd")
const TARGET_DUMMY_SCRIPT := preload("res://combat/target_dummy.gd")
const TARGET_LAYOUT := preload("res://combat/target_layout.gd")
const BOLT_VISUAL_SCRIPT := preload("res://combat/bolt_visual.gd")
const ARENA_LAYOUT := preload("res://world/arena_layout.gd")
const BALL_SCRIPT := preload("res://world/arena_ball.gd")
const ELEVATED_COURSE := preload("res://world/elevated_course.gd")
const RAPIER_DRIVER_SCRIPT := preload("res://addons/netfox.extras/physics/rapier_driver_3d.gd")
const COMBAT_FIRE_INTERVAL_TICKS := 15
const COMBAT_BOLT_SPEED := 30.0
const COMBAT_BOLT_LIFETIME := 1.0
const COMBAT_TARGET_RADIUS := 0.66

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
var _course_test := false
var _reverse_test := false
var _start_tick := -1
var _next_spawn_slot := 0
var _contact_seen := false
var _minimum_pair_distance := INF
var _prediction_history := {}
var _worst_correction_error := 0.0
var _ball_seeded := false
var _maximum_ball_speed := 0.0
var _maximum_player_y := 0.0
var _course_landed := false
var _course_ground_drop_seen := false
var _course_ground_landed := false
var _course_rebound_speed := 0.0
var _course_landing_tilt := 0.0
var _maximum_player_tilt := 0.0
var _minimum_player_x := INF
var _combat_editor_active := false
var _coverage_overlay_visible := true
var _selected_zone := 0
var _coverage_drag := {}
var _coverage_configs := {}
var _editor_stage: MeshInstance3D
var _editor_presentation_state := -1
var _zone_last_fire_tick := {}
var _server_bolts := {}
var _bolt_visuals := {}
var _next_bolt_id := 1
var _combat_shot_count := 0
var _combat_hit_count := 0

var _players: Node3D
var _spawner: MultiplayerSpawner
var _balls: Node3D
var _ball_spawner: MultiplayerSpawner
var _targets: Node3D
var _combat_bolts: Node3D
var _camera: Camera3D
var _shadow_light: SpotLight3D
var _status_label: Label
var _editor_label: Label

func _ready() -> void:
	_parse_args()
	_combat_editor_active = _role == "client" and _scripted.is_empty()
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
	var target: Vector3 = Vector3.ZERO if local == null \
		else ELEVATED_COURSE.camera_target(local.global_position)
	var yaw := deg_to_rad(45.0)
	var pitch := deg_to_rad(55.0)
	var horizontal := cos(pitch) * 80.0
	var offset := Vector3(sin(yaw) * horizontal, sin(pitch) * 80.0, cos(yaw) * horizontal)
	_camera.global_position = target + offset
	_camera.look_at(target, Vector3.UP)
	_camera.size = 30.0 if _combat_editor_active else ARENA_CONFIG.CAMERA_SIZE
	_update_editor_presentation(local)
	if _shadow_light != null:
		_shadow_light.global_position = target + Vector3(-32.0, 40.0, 34.0)
		_shadow_light.look_at(target, Vector3.UP)
	if _status_label != null:
		var id := multiplayer.get_unique_id()
		var speed: float = 0.0 if local == null else local.speed()
		var mode := "COVERAGE EDITOR" if _combat_editor_active else "DRIVE + AUTO FIRE"
		_status_label.text = "CAR FIGHT  |  %s  |  peer %d  |  %.1f u/s\n%s" % [
			mode, id, speed,
			"Drag cone handles  |  Enter: drive" if _combat_editor_active \
			else "Mouse: drive  |  Space: burst  |  Tab/R: reverse  |  E: editor  |  C: cones"]
	_update_editor_label()

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
		elif arg == "--course-test":
			_course_test = true
		elif arg == "--reverse-test":
			_reverse_test = true
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
	var config := _configuration_for(id)
	_apply_coverage_config.rpc(id, config["ranges"], config["widths"], config["tips_outward"])
	var target_counts := PackedInt32Array()
	for target in _targets.get_children():
		target_counts.append(int(target.get("hit_count")))
	_sync_target_hits.rpc_id(id, target_counts)
	_next_spawn_slot += 1
	if not _ball_seeded:
		_ball_seeded = true
		_ball_spawner.spawn({"name": "ArenaBall", "position": BALL_SCRIPT.SPAWN_POSITION})

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
	_balls = Node3D.new()
	_balls.name = "Balls"
	add_child(_balls)
	_ball_spawner = MultiplayerSpawner.new()
	_ball_spawner.name = "BallSpawner"
	add_child(_ball_spawner)
	_ball_spawner.spawn_path = _balls.get_path()
	_ball_spawner.spawn_function = _spawn_ball
	_targets = Node3D.new()
	_targets.name = "CombatTargets"
	add_child(_targets)
	_combat_bolts = Node3D.new()
	_combat_bolts.name = "CombatBolts"
	add_child(_combat_bolts)
	_build_arena()
	_build_combat_targets()
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
	if not _coverage_configs.has(owner_id):
		_coverage_configs[owner_id] = {
			"ranges": COVERAGE.default_ranges(), "widths": COVERAGE.default_widths(),
			"tips_outward": COVERAGE.default_tips_outward()}
	body.gravity_scale = 1.0
	body.mass = VEHICLE_CONFIG.MASS
	body.linear_damp = 0.0
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp = VEHICLE_CONFIG.ANGULAR_DAMP
	body.axis_lock_linear_y = false
	body.axis_lock_angular_x = false
	body.axis_lock_angular_z = false
	body.can_sleep = false
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 8
	var spawn := _spawn_transform(slot)
	body.position = spawn.origin
	body.rotation.y = spawn.basis.get_euler().y
	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = VEHICLE_CONFIG.BOUNCE
	# Explicit drive owns planar motion; touchdown applies a separate one-shot
	# physics impulse instead of continuous sphere friction.
	physics_material.friction = VEHICLE_CONFIG.CONTACT_FRICTION
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
	if _reverse_test and slot == 0:
		return Transform3D(Basis(Vector3.UP, -PI * 0.5),
			Vector3(ARENA_HALF - 2.2, ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), 0.0))
	if _course_test and slot == 0:
		return Transform3D(Basis.IDENTITY,
			Vector3(0.0, ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), 27.0))
	var positions := [
		Vector3(-3.0, ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), 0.0),
		Vector3(3.0, ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), 0.0),
		Vector3(0.0, ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), -3.0),
		Vector3(0.0, ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), 3.0),
	]
	var position: Vector3 = positions[slot % positions.size()]
	var forward := -position.normalized()
	var yaw := atan2(-forward.x, -forward.z)
	return Transform3D(Basis(Vector3.UP, yaw), position)

func _spawn_ball(data: Variant) -> Node:
	var info: Dictionary = data if data is Dictionary else {}
	var body := RigidBody3D.new()
	body.set_script(BALL_SCRIPT)
	body.name = str(info.get("name", "ArenaBall"))
	body.position = info.get("position", BALL_SCRIPT.SPAWN_POSITION)
	body.gravity_scale = 1.0
	body.mass = BALL_SCRIPT.MASS
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = BALL_SCRIPT.LINEAR_DAMP
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp = 1.2
	body.axis_lock_linear_y = false
	body.axis_lock_angular_x = false
	body.axis_lock_angular_z = false
	body.can_sleep = false
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 8

	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = BALL_SCRIPT.BOUNCE
	physics_material.friction = BALL_SCRIPT.FRICTION
	body.physics_material_override = physics_material

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_SCRIPT.RADIUS
	collision.shape = sphere
	body.add_child(collision)

	var synchronizer := Node.new()
	synchronizer.name = "RollbackSynchronizer"
	synchronizer.set_script(load("res://addons/netfox/rollback/rollback-synchronizer.gd"))
	body.add_child(synchronizer)
	var interpolator := Node.new()
	interpolator.name = "TickInterpolator"
	interpolator.set_script(load("res://addons/netfox/tick-interpolator.gd"))
	body.add_child(interpolator)

	if not _is_headless():
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "BallMesh"
		var mesh := SphereMesh.new()
		mesh.radius = BALL_SCRIPT.RADIUS
		mesh.height = BALL_SCRIPT.RADIUS * 2.0
		mesh.radial_segments = 24
		mesh.rings = 12
		mesh_instance.mesh = mesh
		var ball_material := _material(Color("dc7a4d"))
		ball_material.emission_enabled = true
		ball_material.emission = Color("6d2d18")
		ball_material.emission_energy_multiplier = 0.35
		mesh_instance.material_override = ball_material
		body.add_child(mesh_instance)
	return body

func _build_player_presentation(body: RigidBody3D, owner_id: int) -> void:
	body.visible = not _combat_editor_active or owner_id == multiplayer.get_unique_id()
	var hull := Node3D.new()
	hull.name = "GroundVehicleHull"
	hull.set_script(HULL_SCRIPT)
	hull.position.y = -PLAYER_RADIUS
	body.add_child(hull)
	if owner_id == multiplayer.get_unique_id():
		var coverage_visual := Node3D.new()
		coverage_visual.name = "CoverageDebug"
		coverage_visual.set_script(COVERAGE_VISUAL_SCRIPT)
		coverage_visual.position.y = -PLAYER_RADIUS + 0.09
		body.add_child(coverage_visual)
		var config: Dictionary = _configuration_for(owner_id)
		coverage_visual.call("set_configuration", config["ranges"], config["widths"],
			config["tips_outward"])
		coverage_visual.call("set_editor_mode", _combat_editor_active)
		coverage_visual.call("set_overlay_visible", _coverage_overlay_visible)
		coverage_visual.call("set_selected_zone", _selected_zone)

	var color := _peer_color(owner_id)
	var pip := MeshInstance3D.new()
	pip.name = "PeerMarker"
	var pip_mesh := CylinderMesh.new()
	pip_mesh.top_radius = 0.16
	pip_mesh.bottom_radius = 0.16
	pip_mesh.height = 0.12
	pip.mesh = pip_mesh
	pip.position = Vector3(0.0, 1.68 - PLAYER_RADIUS, 0.0)
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
	_add_static_box("GroundCollision", Vector3(ARENA_HALF * 2.0, 1.0, ARENA_HALF * 2.0),
		Vector3(0.0, -0.5, 0.0), Color("202a2d"), 0.0, false)
	if not _is_headless():
		_build_shader_ground()
	var wall_height: float = ARENA_CONFIG.WALL_HEIGHT
	var wall_thickness: float = ARENA_CONFIG.WALL_THICKNESS
	var wall_y := wall_height * 0.5
	_add_static_box("WallNorth", Vector3(ARENA_HALF * 2.0 + wall_thickness * 2.0,
		wall_height, wall_thickness), Vector3(0.0, wall_y, -ARENA_HALF), Color("596674"))
	_add_static_box("WallSouth", Vector3(ARENA_HALF * 2.0 + wall_thickness * 2.0,
		wall_height, wall_thickness), Vector3(0.0, wall_y, ARENA_HALF), Color("596674"))
	_add_static_box("WallWest", Vector3(wall_thickness, wall_height, ARENA_HALF * 2.0),
		Vector3(-ARENA_HALF, wall_y, 0.0), Color("596674"))
	_add_static_box("WallEast", Vector3(wall_thickness, wall_height, ARENA_HALF * 2.0),
		Vector3(ARENA_HALF, wall_y, 0.0), Color("596674"))
	for obstacle in ARENA_LAYOUT.collision_objects():
		_add_static_box(str(obstacle["name"]), obstacle["size"], obstacle["position"],
			obstacle["color"], float(obstacle["yaw"]))
	_build_elevated_course()

func _build_combat_targets() -> void:
	var positions := TARGET_LAYOUT.positions()
	for index in range(positions.size()):
		var target := StaticBody3D.new()
		target.set_script(TARGET_DUMMY_SCRIPT)
		target.position = positions[index]
		target.call("setup", index, not _is_headless())
		_targets.add_child(target)

func _build_elevated_course() -> void:
	var ramp: Dictionary = ELEVATED_COURSE.ramp()
	_add_static_oriented_box(str(ramp["name"]), ramp["size"], ramp["position"],
		ramp["color"], ramp["rotation"])
	for road in ELEVATED_COURSE.upper_roads():
		_add_static_oriented_box(str(road["name"]), road["size"], road["position"],
			road["color"], road["rotation"])
	for support in ELEVATED_COURSE.supports():
		_add_static_box(str(support["name"]), support["size"], support["position"],
			support["color"])

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
	ground.set_meta("arena_presentation", true)
	add_child(ground)

func _add_static_box(node_name: String, size: Vector3, position: Vector3, color: Color,
		yaw: float = 0.0, visible: bool = true) -> void:
	_add_static_oriented_box(node_name, size, position, color, Vector3(0.0, yaw, 0.0), visible)

func _add_static_oriented_box(node_name: String, size: Vector3, position: Vector3,
		color: Color, rotation: Vector3, visible: bool = true) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation = rotation
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if not _is_headless() and visible:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _material(color)
		mesh_instance.set_meta("arena_presentation", true)
		body.add_child(mesh_instance)
	add_child(body)

func _build_presentation() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10171d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b6cad3")
	env.ambient_light_energy = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.82
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.name = "ShadowSun"
	light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	light.light_color = Color("fff1d4")
	light.light_energy = 0.28
	# A second shadow map produces striped self-shadowing on ANGLE.
	light.shadow_enabled = false
	add_child(light)
	# ANGLE's compatibility path does not consistently expose directional
	# shadows on this Intel Mac. A broad real-time spotlight supplies a shadow
	# map that the ground grid, roads, supports, cars, and ball all receive.
	_shadow_light = SpotLight3D.new()
	_shadow_light.name = "ArenaShadowLight"
	_shadow_light.position = Vector3(-32.0, 40.0, 34.0)
	_shadow_light.light_color = Color("fff0cf")
	_shadow_light.light_energy = 1.75
	_shadow_light.spot_range = 100.0
	_shadow_light.spot_angle = 66.0
	_shadow_light.spot_attenuation = 0.1
	_shadow_light.shadow_enabled = true
	_shadow_light.shadow_opacity = 0.92
	_shadow_light.shadow_bias = 0.12
	_shadow_light.shadow_normal_bias = 1.25
	# Closed box meshes can cast from their back faces without shadow acne.
	_shadow_light.shadow_reverse_cull_face = true
	add_child(_shadow_light)
	_shadow_light.look_at(Vector3.ZERO, Vector3.UP)
	_camera = Camera3D.new()
	_camera.name = "IsometricCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ARENA_CONFIG.CAMERA_SIZE
	_camera.current = true
	add_child(_camera)
	_editor_stage = MeshInstance3D.new()
	_editor_stage.name = "CoverageEditorStage"
	var editor_plane := PlaneMesh.new()
	editor_plane.size = Vector2(64.0, 64.0)
	_editor_stage.mesh = editor_plane
	_editor_stage.material_override = _material(Color("182125"))
	_editor_stage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_editor_stage.visible = false
	add_child(_editor_stage)
	var boost_blur := CanvasLayer.new()
	boost_blur.name = "BoostVelocityBlur"
	boost_blur.set_script(BOOST_VELOCITY_BLUR_SCRIPT)
	boost_blur.call("setup", _players, _camera)
	add_child(boost_blur)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	_status_label = Label.new()
	_status_label.position = Vector2(18.0, 16.0)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("e8f4f6"))
	hud.add_child(_status_label)
	_editor_label = Label.new()
	_editor_label.position = Vector2(18.0, 78.0)
	_editor_label.add_theme_font_size_override("font_size", 17)
	_editor_label.add_theme_color_override("font_color", Color("dce7e8"))
	hud.add_child(_editor_label)

func _update_editor_presentation(local: Node3D) -> void:
	if local == null or _editor_stage == null:
		return
	_editor_stage.global_position = Vector3(local.global_position.x, 0.015, local.global_position.z)
	var requested_state := 1 if _combat_editor_active else 0
	if requested_state == _editor_presentation_state:
		return
	_editor_presentation_state = requested_state
	for visual_node in find_children("*", "VisualInstance3D", true, false):
		if bool(visual_node.get_meta("arena_presentation", false)):
			(visual_node as VisualInstance3D).visible = not _combat_editor_active
	_targets.visible = not _combat_editor_active
	_balls.visible = not _combat_editor_active
	_combat_bolts.visible = not _combat_editor_active
	for player_node in _players.get_children():
		var player := player_node as Node3D
		if player != null:
			player.visible = not _combat_editor_active or player == local
	var peer_marker := local.get_node_or_null("PeerMarker") as VisualInstance3D
	if peer_marker != null:
		peer_marker.visible = not _combat_editor_active
	_editor_stage.visible = _combat_editor_active

func _update_editor_label() -> void:
	if _editor_label == null:
		return
	_editor_label.visible = _combat_editor_active
	if not _combat_editor_active:
		return
	var config := _configuration_for(multiplayer.get_unique_id())
	var ranges: PackedFloat32Array = config["ranges"]
	var widths: PackedFloat32Array = config["widths"]
	var tips_outward: PackedByteArray = config["tips_outward"]
	var used := COVERAGE.total_area(ranges, widths)
	var direction_label := "OUTWARD TIP" if bool(tips_outward[_selected_zone]) else "VEHICLE TIP"
	_editor_label.text = "%s  ·  range %.1f  ·  width %.0f°  ·  %s\nAREA  %.1f / %.1f\nF: flip selected cone" % [
		COVERAGE.ZONE_NAMES[_selected_zone], ranges[_selected_zone],
		rad_to_deg(widths[_selected_zone]), direction_label, used, COVERAGE.TOTAL_BUDGET]

func _unhandled_input(event: InputEvent) -> void:
	if _role != "client" or not _scripted.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and _combat_editor_active:
			_set_combat_editor_active(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and not _combat_editor_active:
			_set_combat_editor_active(true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C and not _combat_editor_active:
			_coverage_overlay_visible = not _coverage_overlay_visible
			_update_local_coverage_visual()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and _combat_editor_active:
			_flip_selected_cone()
			get_viewport().set_input_as_handled()
	if not _combat_editor_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_coverage_drag(event.position)
		else:
			_finish_coverage_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _coverage_drag.is_empty():
		_drag_coverage(event.position)
		get_viewport().set_input_as_handled()

func _set_combat_editor_active(enabled: bool) -> void:
	_combat_editor_active = enabled
	_coverage_drag.clear()
	_update_local_coverage_visual()
	if not enabled:
		_submit_local_coverage_config()

func _flip_selected_cone() -> void:
	var id := multiplayer.get_unique_id()
	var config := _configuration_for(id)
	var tips_outward: PackedByteArray = \
		(config["tips_outward"] as PackedByteArray).duplicate()
	tips_outward[_selected_zone] = 0 if bool(tips_outward[_selected_zone]) else 1
	config["tips_outward"] = tips_outward
	_coverage_configs[id] = config
	_update_local_coverage_visual()
	_submit_local_coverage_config()

func combat_editor_active(_body: Node3D) -> bool:
	return _combat_editor_active

func _begin_coverage_drag(screen_position: Vector2) -> void:
	var body := local_player() as Node3D
	var world_point: Variant = _mouse_world_point(screen_position, body)
	if body == null or world_point == null:
		return
	var local := COVERAGE.local_point(world_point, body.global_transform)
	var config := _configuration_for(multiplayer.get_unique_id())
	var ranges: PackedFloat32Array = config["ranges"]
	var widths: PackedFloat32Array = config["widths"]
	var tips_outward: PackedByteArray = config["tips_outward"]
	var best_distance := 1.0
	var best := {}
	var zone_order := [_selected_zone]
	for candidate_zone in range(COVERAGE.ZONE_COUNT):
		if candidate_zone != _selected_zone:
			zone_order.append(candidate_zone)
	for zone in zone_order:
		var handles: Dictionary = COVERAGE.handle_positions(zone, ranges[zone], widths[zone],
			bool(tips_outward[zone]))
		for kind in ["range", "left", "right"]:
			var distance := local.distance_to(handles[kind])
			if distance < best_distance:
				best_distance = distance
				best = {"zone": zone, "kind": kind}
	if best.is_empty():
		return
	_coverage_drag = best
	_selected_zone = int(best["zone"])
	_update_local_coverage_visual()

func _drag_coverage(screen_position: Vector2) -> void:
	var body := local_player() as Node3D
	var world_point: Variant = _mouse_world_point(screen_position, body)
	if body == null or world_point == null:
		return
	var local := COVERAGE.local_point(world_point, body.global_transform)
	var id := multiplayer.get_unique_id()
	var config := _configuration_for(id)
	var ranges: PackedFloat32Array = (config["ranges"] as PackedFloat32Array).duplicate()
	var widths: PackedFloat32Array = (config["widths"] as PackedFloat32Array).duplicate()
	var tips_outward: PackedByteArray = \
		(config["tips_outward"] as PackedByteArray).duplicate()
	var zone := int(_coverage_drag["zone"])
	if str(_coverage_drag["kind"]) == "range":
		ranges[zone] = COVERAGE.clamp_range(zone, local.length(), ranges, widths)
	else:
		var requested_width := COVERAGE.width_from_handle(zone, ranges[zone], local)
		widths[zone] = COVERAGE.clamp_width(zone, requested_width, ranges, widths)
	_coverage_configs[id] = {"ranges": ranges, "widths": widths,
		"tips_outward": tips_outward}
	_update_local_coverage_visual()

func _finish_coverage_drag() -> void:
	if _coverage_drag.is_empty():
		return
	_coverage_drag.clear()
	_submit_local_coverage_config()

func _mouse_world_point(screen_position: Vector2, body: Node3D) -> Variant:
	if _camera == null or body == null:
		return null
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.00001:
		return null
	var plane_y := body.global_position.y - PLAYER_RADIUS + 0.10
	var distance := (plane_y - origin.y) / direction.y
	return null if distance < 0.0 else origin + direction * distance

func _configuration_for(owner_id: int) -> Dictionary:
	if not _coverage_configs.has(owner_id):
		_coverage_configs[owner_id] = {
			"ranges": COVERAGE.default_ranges(), "widths": COVERAGE.default_widths(),
			"tips_outward": COVERAGE.default_tips_outward()}
	return _coverage_configs[owner_id]

func _submit_local_coverage_config() -> void:
	var config := _configuration_for(multiplayer.get_unique_id())
	_submit_coverage_config.rpc_id(1, config["ranges"], config["widths"],
		config["tips_outward"])

@rpc("any_peer", "call_remote", "reliable")
func _submit_coverage_config(ranges: PackedFloat32Array, widths: PackedFloat32Array,
		tips_outward: PackedByteArray) -> void:
	if not multiplayer.is_server() or not COVERAGE.is_valid(ranges, widths, tips_outward):
		return
	var sender := multiplayer.get_remote_sender_id()
	if _players.get_node_or_null(str(sender)) == null:
		return
	_apply_coverage_config.rpc(sender, ranges, widths, tips_outward)

@rpc("authority", "call_local", "reliable")
func _apply_coverage_config(owner_id: int, ranges: PackedFloat32Array,
		widths: PackedFloat32Array, tips_outward: PackedByteArray) -> void:
	if not COVERAGE.is_valid(ranges, widths, tips_outward):
		return
	_coverage_configs[owner_id] = {"ranges": ranges.duplicate(), "widths": widths.duplicate(),
		"tips_outward": tips_outward.duplicate()}
	if owner_id == multiplayer.get_unique_id():
		_update_local_coverage_visual()

func _update_local_coverage_visual() -> void:
	var body := local_player() as Node3D
	if body == null:
		return
	var visual := body.get_node_or_null("CoverageDebug")
	if visual == null:
		return
	var config := _configuration_for(multiplayer.get_unique_id())
	visual.call("set_configuration", config["ranges"], config["widths"],
		config["tips_outward"])
	visual.call("set_editor_mode", _combat_editor_active)
	visual.call("set_overlay_visible", _coverage_overlay_visible)
	visual.call("set_selected_zone", _selected_zone)

func cursor_offset_for(body: Node3D) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.00001:
		return Vector2.ZERO
	var road_plane_y := body.global_position.y - PLAYER_RADIUS
	var t := (road_plane_y - origin.y) / direction.y
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
		"ball":
			var target := BALL_SCRIPT.SPAWN_POSITION
			if _balls != null and _balls.get_child_count() > 0:
				target = (_balls.get_child(0) as Node3D).global_position
			var delta := target - body.global_position
			return {"cursor_offset": Vector2(delta.x, delta.z).limit_length(16.0), "burst": false}
		"ramp":
			# Slow near the end so the elevated-road drop lands before the arena wall.
			var reach := 6.0 if body.position.z < -25.0 else 16.0
			return {"cursor_offset": Vector2(0.0, -reach), "burst": false}
		"reverse":
			return {"cursor_offset": Vector2(16.0, 0.0), "burst": false, "reverse": true}
		"combat":
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": false}
		"combat-edit":
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": true}
		_:
			return {"cursor_offset": Vector2.ZERO, "burst": false}

func local_player():
	if _players == null:
		return null
	return _players.get_node_or_null(str(multiplayer.get_unique_id()))

func _on_tick(delta: float, tick: int) -> void:
	if _start_tick < 0:
		_start_tick = tick
	var elapsed := tick - _start_tick
	if multiplayer.is_server():
		_service_auto_combat(delta, tick)
		_track_server_contacts()
		_track_server_ball()
		_track_server_course()
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
			_log("RESULT players=%d minpair=%.3f contact=%d escapes=%d bumps=%d ballmax=%.3f maxy=%.3f landed=%d grounded=%d rebound=%.3f tilt=%.3f maxtilt=%.3f minx=%.3f shots=%d hits=%d" % [_players.get_child_count(), _minimum_pair_distance, 1 if _contact_seen else 0, _server_escape_count(), _server_bump_count(), _maximum_ball_speed, _maximum_player_y, 1 if _course_landed else 0, 1 if _course_ground_landed else 0, _course_rebound_speed, _course_landing_tilt, _maximum_player_tilt, _minimum_player_x, _combat_shot_count, _combat_hit_count])
		get_tree().quit()

func _service_auto_combat(delta: float, tick: int) -> void:
	_step_server_bolts(delta)
	for player_node in _players.get_children():
		var body := player_node as RigidBody3D
		if body == null:
			continue
		var input := body.get_node_or_null("Input")
		if input == null or bool(input.get("editing")):
			continue
		var owner_id := int(body.name)
		var config := _configuration_for(owner_id)
		var ranges: PackedFloat32Array = config["ranges"]
		var widths: PackedFloat32Array = config["widths"]
		var tips_outward: PackedByteArray = config["tips_outward"]
		for zone in range(COVERAGE.ZONE_COUNT):
			var cooldown_key := "%d:%d" % [owner_id, zone]
			if tick - int(_zone_last_fire_tick.get(cooldown_key, -COMBAT_FIRE_INTERVAL_TICKS)) \
					< COMBAT_FIRE_INTERVAL_TICKS:
				continue
			var target := _acquire_target(body, zone, ranges[zone], widths[zone],
				bool(tips_outward[zone]))
			if target == null:
				continue
			_zone_last_fire_tick[cooldown_key] = tick
			_fire_combat_bolt(body, target, zone)

func _acquire_target(body: RigidBody3D, zone: int, reach: float, width: float,
		tip_outward: bool) -> StaticBody3D:
	var candidates: Array[Dictionary] = []
	var by_id := {}
	for target_node in _targets.get_children():
		var target := target_node as StaticBody3D
		if target == null:
			continue
		var target_id := int(target.get("target_id"))
		var local := COVERAGE.local_point(target.global_position, body.global_transform)
		candidates.append({"id": target_id, "local_position": local,
			"visible": _has_target_line_of_sight(body, target)})
		by_id[target_id] = target
	var selected := AUTO_TARGETING.select_nearest(zone, reach, width, tip_outward, candidates)
	return by_id.get(selected) as StaticBody3D

func _has_target_line_of_sight(body: RigidBody3D, target: StaticBody3D) -> bool:
	var start := _combat_muzzle_origin(body, target.global_position)
	var query := PhysicsRayQueryParameters3D.create(start, target.global_position, 1)
	query.exclude = _combat_dynamic_rids()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _combat_dynamic_rids() -> Array[RID]:
	var excluded: Array[RID] = []
	for child in _players.get_children():
		var body := child as CollisionObject3D
		if body != null:
			excluded.append(body.get_rid())
	for child in _balls.get_children():
		var ball := child as CollisionObject3D
		if ball != null:
			excluded.append(ball.get_rid())
	return excluded

func _combat_muzzle_origin(body: RigidBody3D, aim_point: Vector3) -> Vector3:
	var planar := aim_point - body.global_position
	planar.y = 0.0
	if planar.is_zero_approx():
		planar = -body.global_basis.z
	return body.global_position + planar.normalized() * 1.2 \
		- Vector3.UP * (PLAYER_RADIUS - 0.82)

func _fire_combat_bolt(body: RigidBody3D, target: StaticBody3D, zone: int) -> void:
	var origin := _combat_muzzle_origin(body, target.global_position)
	var velocity := (target.global_position - origin).normalized() * COMBAT_BOLT_SPEED
	var bolt_id := _next_bolt_id
	_next_bolt_id += 1
	_server_bolts[bolt_id] = {"position": origin, "velocity": velocity,
		"age": 0.0, "shooter": int(body.name), "zone": zone}
	_combat_shot_count += 1
	_spawn_combat_bolt.rpc(bolt_id, int(body.name), zone, origin, velocity)

func _step_server_bolts(delta: float) -> void:
	for bolt_id_value in _server_bolts.keys():
		var bolt_id := int(bolt_id_value)
		var bolt: Dictionary = _server_bolts[bolt_id]
		var start: Vector3 = bolt["position"]
		var finish := start + (bolt["velocity"] as Vector3) * delta
		var segment := finish - start
		var wall_fraction := 1.01
		var wall_query := PhysicsRayQueryParameters3D.create(start, finish, 1)
		wall_query.exclude = _combat_dynamic_rids()
		var wall_hit := get_world_3d().direct_space_state.intersect_ray(wall_query)
		if not wall_hit.is_empty() and segment.length_squared() > 0.0001:
			wall_fraction = start.distance_to(wall_hit["position"]) / segment.length()
		var target_hit: StaticBody3D
		var target_fraction := 1.01
		for target_node in _targets.get_children():
			var target := target_node as StaticBody3D
			if target == null or segment.length_squared() <= 0.0001:
				continue
			var fraction := clampf((target.global_position - start).dot(segment) \
				/ segment.length_squared(), 0.0, 1.0)
			var closest := start + segment * fraction
			if closest.distance_to(target.global_position) <= COMBAT_TARGET_RADIUS \
					and fraction < target_fraction:
				target_hit = target
				target_fraction = fraction
		if target_hit != null and target_fraction <= wall_fraction:
			_combat_hit_count += 1
			_register_target_hit.rpc(int(target_hit.get("target_id")))
			_end_combat_bolt.rpc(bolt_id)
			_server_bolts.erase(bolt_id)
			continue
		if wall_fraction <= 1.0:
			_end_combat_bolt.rpc(bolt_id)
			_server_bolts.erase(bolt_id)
			continue
		bolt["position"] = finish
		bolt["age"] = float(bolt["age"]) + delta
		if float(bolt["age"]) >= COMBAT_BOLT_LIFETIME:
			_end_combat_bolt.rpc(bolt_id)
			_server_bolts.erase(bolt_id)
		else:
			_server_bolts[bolt_id] = bolt

@rpc("authority", "call_local", "reliable")
func _spawn_combat_bolt(bolt_id: int, shooter_id: int, zone: int,
		origin: Vector3, velocity: Vector3) -> void:
	if not _is_headless():
		var visual := Node3D.new()
		visual.name = "Bolt_%d" % bolt_id
		visual.set_script(BOLT_VISUAL_SCRIPT)
		_combat_bolts.add_child(visual)
		visual.call("setup", bolt_id, origin, velocity, COVERAGE.ZONE_COLORS[zone])
		_bolt_visuals[bolt_id] = visual
	var local := local_player() as Node3D
	if local != null and int(local.name) == shooter_id:
		var coverage_visual := local.get_node_or_null("CoverageDebug")
		if coverage_visual != null:
			coverage_visual.call("flash_zone", zone)

@rpc("authority", "call_local", "reliable")
func _end_combat_bolt(bolt_id: int) -> void:
	var visual: Node = _bolt_visuals.get(bolt_id)
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	_bolt_visuals.erase(bolt_id)

@rpc("authority", "call_local", "reliable")
func _register_target_hit(target_id: int) -> void:
	var target := _targets.get_node_or_null("Target_%02d" % target_id)
	if target != null:
		target.call("register_hit")

@rpc("authority", "call_remote", "reliable")
func _sync_target_hits(hit_counts: PackedInt32Array) -> void:
	for index in range(mini(hit_counts.size(), _targets.get_child_count())):
		_targets.get_child(index).call("set_hit_count", hit_counts[index])

func _server_escape_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("collision_escape_count"))
	return total

func _server_bump_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("wall_bump_count"))
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

func _track_server_ball() -> void:
	if _balls == null:
		return
	for child in _balls.get_children():
		var ball := child as RigidBody3D
		if ball != null:
			_maximum_ball_speed = maxf(_maximum_ball_speed, ball.linear_velocity.length())

func _track_server_course() -> void:
	var ground_body_y := ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS)
	var road_body_y := ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS) + ELEVATED_COURSE.ROAD_SURFACE_Y
	for child in _players.get_children():
		var body := child as RigidBody3D
		if body == null:
			continue
		_minimum_player_x = minf(_minimum_player_x, body.position.x)
		_maximum_player_y = maxf(_maximum_player_y, body.position.y)
		var upright := clampf(body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)
		_maximum_player_tilt = maxf(_maximum_player_tilt, rad_to_deg(acos(upright)))
		if _maximum_player_y > road_body_y + 0.35 \
				and absf(body.position.y - road_body_y) < 0.20 \
				and absf(body.position.x) < 3.8 \
				and body.position.z <= 4.5 and body.position.z >= -30.5:
			_course_landed = true
		if _course_landed and body.position.z < -30.5 \
				and body.position.y > ground_body_y + 1.0 and body.linear_velocity.y < -1.0:
			_course_ground_drop_seen = true
		if _course_ground_drop_seen and body.position.y < ground_body_y + 0.25:
			_course_ground_landed = true
		# Stop measuring before the north wall can add its own collision rotation.
		if _course_ground_landed and body.position.z > -37.0:
			_course_rebound_speed = maxf(_course_rebound_speed, body.linear_velocity.y)
			_course_landing_tilt = maxf(_course_landing_tilt, rad_to_deg(acos(upright)))

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
