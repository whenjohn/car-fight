extends Node
## Stage 11 adds a local ENet server/client connection and netfox time sync.
## It still has no multiplayer spawning, replicated state, or rollback nodes.

const STAGE := 11
const JEEP_SCENE: PackedScene = preload("res://assets/ground_vehicle/Jeep.fbx")
const DEFAULT_PORT := 10080

var _telemetry: FileAccess
var _sample_elapsed := 0.0
var _quit_after_ticks := 0
var _ticks := 0
var _role := "client"
var _host := "127.0.0.1"
var _port := DEFAULT_PORT

func _ready() -> void:
	_parse_args()
	_build_3d_view()
	_open_telemetry()
	var details := _display_details()
	print("RENDER_ISOLATION_READY stage=%d driver=%s mode=%s size=%s" % [
		STAGE,
		details["rendering_driver"],
		details["window_mode_name"],
		str(details["window_size"]),
	])
	_write("start", details)
	_start_network()


func _start_network() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := OK
	if _role == "server":
		error = peer.create_server(_port, 4)
	else:
		error = peer.create_client(_host, _port)
	if error != OK:
		push_error("ENet %s setup failed: %s" % [_role, error_string(error)])
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	print("RENDER_ISOLATION_NETWORK role=%s host=%s port=%d" % [
		_role, _host, _port])


func _build_3d_view() -> void:
	var world := Node3D.new()
	world.name = "Empty3DWorld"
	add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.04, 0.065)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	world.add_child(world_environment)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 3.0, 8.0)
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var body := RigidBody3D.new()
	body.name = "SimulatedJeepBody"
	body.position = Vector3(0.0, 0.55, 0.0)
	body.mass = 2.2
	body.angular_velocity = Vector3(0.0, 1.35, 0.0)
	body.continuous_cd = true
	world.add_child(body)

	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(2.2, 1.1, 3.4)
	body_shape.shape = body_box
	body.add_child(body_shape)

	var jeep := JEEP_SCENE.instantiate() as Node3D
	jeep.name = "ImportedJeep"
	jeep.scale = Vector3.ONE * 0.45
	jeep.rotation.y = PI
	jeep.position.y = -0.55
	body.add_child(jeep)

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.16, 0.19, 0.23)
	floor_material.roughness = 0.9
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(20.0, 20.0)
	floor_mesh.material = floor_material
	var floor := MeshInstance3D.new()
	floor.name = "ShadowFloor"
	floor.mesh = floor_mesh
	floor.position.y = -0.75
	world.add_child(floor)
	var floor_body := StaticBody3D.new()
	floor_body.name = "StaticFloorBody"
	floor_body.position.y = -0.85
	world.add_child(floor_body)
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20.0, 0.2, 20.0)
	floor_collision.shape = floor_box
	floor_body.add_child(floor_collision)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	world.add_child(light)


func _process(delta: float) -> void:
	_sample_elapsed += delta
	if _sample_elapsed < 1.0:
		return
	_sample_elapsed = 0.0
	var details := _display_details()
	details["fps"] = Engine.get_frames_per_second()
	_write("sample", details)


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _quit_after_ticks > 0 and _ticks >= _quit_after_ticks:
		get_tree().quit()


func _exit_tree() -> void:
	_write("stop", {})
	if _telemetry != null:
		_telemetry.close()
		_telemetry = null


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		if args[index] == "--server":
			_role = "server"
		elif args[index] == "--client":
			_role = "client"
		elif args[index] == "--host" and index + 1 < args.size():
			index += 1
			_host = args[index]
		elif args[index].begins_with("--host="):
			_host = args[index].get_slice("=", 1)
		elif args[index] == "--port" and index + 1 < args.size():
			index += 1
			_port = int(args[index])
		elif args[index].begins_with("--port="):
			_port = int(args[index].get_slice("=", 1))
		elif args[index] == "--ticks" and index + 1 < args.size():
			index += 1
			_quit_after_ticks = int(args[index])
		elif args[index].begins_with("--ticks="):
			_quit_after_ticks = int(args[index].get_slice("=", 1))
		index += 1


func _open_telemetry() -> void:
	var path := OS.get_environment("CAR_FIGHT_TELEMETRY_FILE")
	if path.is_empty():
		return
	_telemetry = FileAccess.open(path, FileAccess.WRITE)
	if _telemetry == null:
		push_warning("Could not open telemetry path: %s" % path)


func _display_details() -> Dictionary:
	var mode := int(DisplayServer.window_get_mode())
	var screen := DisplayServer.window_get_current_screen()
	return {
		"stage": STAGE,
		"role": _role,
		"display_driver": DisplayServer.get_name(),
		"rendering_driver": str(RenderingServer.get_current_rendering_driver_name()),
		"video_adapter": str(RenderingServer.get_video_adapter_name()),
		"video_api": str(RenderingServer.get_video_adapter_api_version()),
		"window_mode": mode,
		"window_mode_name": _window_mode_name(mode),
		"window_size": _vector2i_array(DisplayServer.window_get_size()),
		"screen": screen,
		"screen_size": _vector2i_array(DisplayServer.screen_get_size(screen)),
	}


func _write(event: String, data: Dictionary) -> void:
	if _telemetry == null:
		return
	var record := data.duplicate()
	record["event"] = event
	record["pid"] = OS.get_process_id()
	record["local_time"] = Time.get_datetime_string_from_system(false, true)
	record["monotonic_msec"] = Time.get_ticks_msec()
	_telemetry.store_line(JSON.stringify(record))
	_telemetry.flush()


func _vector2i_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


func _window_mode_name(mode: int) -> String:
	match mode:
		DisplayServer.WINDOW_MODE_WINDOWED:
			return "windowed"
		DisplayServer.WINDOW_MODE_MINIMIZED:
			return "minimized"
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			return "maximized"
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return "fullscreen"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return "exclusive_fullscreen"
		_:
			return "unknown_%d" % mode
