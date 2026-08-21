extends Node3D
## Small, auditable game shell: ENet lifecycle and spawn authority live here;
## player scripts own deterministic FOLLOW simulation and presentation.

const DEFAULT_PORT := 10080
const DEFAULT_SIGNAL_PORT := 10181
const MAX_CLIENTS := 16
const ARENA_CONFIG := preload("res://world/arena_config.gd")
const ARENA_HALF := ARENA_CONFIG.HALF_EXTENT
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const FOLLOW := preload("res://player/follow_controller.gd")
const PLAYER_RADIUS := VEHICLE_CONFIG.COLLISION_RADIUS
const PLAYER_SCRIPT := preload("res://player/player_body.gd")
const INPUT_SCRIPT := preload("res://player/player_input.gd")
const HULL_SCRIPT := preload("res://player/ground_vehicle_hull.gd")
const DRIFT_GUIDE_SCRIPT := preload("res://player/drift_guide.gd")
const TRACTOR_CONTROLLER := preload("res://player/tractor_controller.gd")
const IMPACT_CONTROLLER := preload("res://player/impact_controller.gd")
const BOOST_VELOCITY_BLUR_SCRIPT := preload("res://fx/boost_velocity_blur.gd")
const INTERACTIVE_GRASS_SCRIPT := preload("res://fx/interactive_grass.gd")
const CLOAK_DISSOLVE_SHADER := preload("res://fx/vehicle_cloak_dissolve.gdshader")
const CLOAK_GHOST_SHADER := preload("res://fx/vehicle_cloak_ghost.gdshader")
const SHIELD_SHADER := preload("res://fx/vehicle_shield.gdshader")
const HOMING_MISSILE_SHADER := preload("res://fx/homing_missile_head.gdshader")
const SHIELD_VISUAL_SCRIPT := preload("res://fx/vehicle_shield.gd")
const DET_BUBBLE_SCRIPT := preload("res://fx/det_bubble.gd")
const IMPACT_FX_SCRIPT := preload("res://fx/impact_fx.gd")
const COVERAGE := preload("res://combat/coverage_config.gd")
const AUTO_TARGETING := preload("res://combat/auto_targeting.gd")
const COVERAGE_VISUAL_SCRIPT := preload("res://combat/coverage_visual.gd")
const TARGET_DUMMY_SCRIPT := preload("res://combat/target_dummy.gd")
const TARGET_LAYOUT := preload("res://combat/target_layout.gd")
const BOLT_VISUAL_SCRIPT := preload("res://combat/bolt_visual.gd")
const HOMING_MISSILE := preload("res://combat/homing_missile.gd")
const HOMING_MISSILE_VISUAL_SCRIPT := preload("res://combat/homing_missile_visual.gd")
const RC_ORB_VISUAL_SCRIPT := preload("res://combat/rc_orb_visual.gd")
const SHIELD_DRONE_SCRIPT := preload("res://combat/shield_drone.gd")
const AREA_WEAPON := preload("res://combat/area_weapon.gd")
const AREA_STRIKE_SCRIPT := preload("res://combat/area_strike.gd")
const AREA_BURN_ZONE_SCRIPT := preload("res://combat/area_burn_zone.gd")
const AREA_STRIKE_VISUAL_SCRIPT := preload("res://fx/area_strike_visual.gd")
const AREA_BURN_VISUAL_SCRIPT := preload("res://fx/area_burn_visual.gd")
const AREA_TARGET_PREVIEW_SCRIPT := preload("res://fx/area_target_preview.gd")
const ARENA_LAYOUT := preload("res://world/arena_layout.gd")
const BALL_SCRIPT := preload("res://world/arena_ball.gd")
const ELEVATED_COURSE := preload("res://world/elevated_course.gd")
const MAP_LAYOUT := preload("res://world/map_layout.gd")
const DRIVING_COURSE_SCRIPT := preload("res://world/driving_course.gd")
const JUMP_GATES_SCRIPT := preload("res://world/jump_gates.gd")
const DOTS_SCRIPT := preload("res://world/dots.gd")
const CRASH_TELEMETRY_SCRIPT := preload("res://diagnostics/crash_telemetry.gd")
const WINDOW_SAFETY_POLICY_SCRIPT := preload("res://platform/window_safety_policy.gd")
const RAPIER_DRIVER_SCRIPT := preload("res://addons/netfox.extras/physics/rapier_driver_3d.gd")
const WEBRTC_TRANSPORT_SCRIPT := preload("res://net/webrtc_transport.gd")
const MUX_MULTIPLAYER_PEER_SCRIPT := preload("res://net/mux_multiplayer_peer.gd")
const COMBAT_FIRE_INTERVAL_TICKS := 15
const COMBAT_BOLT_SPEED := 30.0
const COMBAT_BOLT_LIFETIME := 1.0
const COMBAT_TARGET_RADIUS := 0.66
const COMBAT_BALL_IMPULSE := 4.2
const BALL_TARGET_ID_BASE := -1000
const BOLT_KIND_PLAYER := 0
const BOLT_KIND_DRONE := 1
const BOLT_KIND_HOMING := 2
const RC_ORB_SPEED := 14.0
const RC_ORB_ACCEL := 30.0
const RC_ORB_TURN := 3.2
const RC_ORB_DEADZONE := 1.0
const RC_ORB_MAX_DISTANCE := 23.0
const RC_ORB_LIFETIME := 6.0
const RC_ORB_RADIUS := 0.47
const RC_ORB_BLAST_RADIUS := 2.7
const RC_ORB_LAUNCH_OFFSET := 0.72
const SERVER_DRIVER_SPAWN := Vector2(-42.0, -48.0)
const SERVER_DRIVER_ROUTE := [
	Vector2(-42.0, -48.0), Vector2(0.0, -52.0),
	Vector2(38.0, -48.0), Vector2(52.0, -40.0),
	Vector2(58.0, -18.0), Vector2(56.0, 12.0),
	Vector2(44.0, 30.0), Vector2(20.0, 42.0),
	Vector2(-12.0, 45.0), Vector2(-38.0, 38.0),
	Vector2(-52.0, 22.0), Vector2(-58.0, -5.0),
	Vector2(-54.0, -30.0),
]
const SERVER_DRIVER_WAYPOINT_RADIUS := 5.0
const SERVER_DRIVER_PROGRESS_DISTANCE := 2.0
const SERVER_DRIVER_STUCK_TICKS := 180
const SERVER_DRIVER_ARENA_LIMIT := ARENA_HALF + 4.0

var _role := "client"
var _transport := "enet"
var _host := "100.113.2.60" # macai2 over Tailscale; local tools pass 127.0.0.1 explicitly.
var _port := DEFAULT_PORT
var _signal_port := DEFAULT_SIGNAL_PORT
var _signal_url := ""
var _ice_servers: Array = []
var _ice_relay_only := false
var _webrtc_channel_telemetry := false
var _state_bundles := false
var _input_broadcast := false
var _packed_input := false
var _packed_state := false
var _state_rate_divisor := 1
var _adaptive_state_rate := false
var _network_app_telemetry := false
var _remote_state_push := true
var _remote_state_transport := "legacy"
var _remote_state_rate := 60
var _remote_state_relevance := "all"
var _remote_state_include_self := true
var _resim_budget_ms := 0.0
var _mux_collision_test := false
var _mux_close_transport_test := ""
var _player_name := "driver"
var _session_label := ""
var _scripted := ""
var _server_driver_enabled := false
var _ramps_enabled := true
var _server_driver_waypoint := 1
var _server_driver_progress_tick := -1
var _server_driver_progress_position := Vector2.ZERO
var _quit_after_ticks := 0
var _to_port := DEFAULT_PORT
var _proxy_server_host := "127.0.0.1"
var _latency_ms := 0
var _jitter_ms := 0
var _loss_pct := 0.0
var _shape_seed := 0xCA4F19
var _force_presentation := false
var _course_test := false
var _reverse_test := false
var _gate_test := false
var _drone_enabled := true
var _start_tick := -1
var _next_spawn_slot := 0
var _next_remote_state_generation := 1
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
var _coverage_overlay_visible := false
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
var _combat_ball_hit_count := 0
var _drone_last_fire_tick := -100000
var _drone_shot_count := 0
var _det_nullification_count := 0
var _maximum_impact_speed := 0.0
var _crash_telemetry: Node
var _grass_contacts := {}
var _area_strike_serial_seen := {}
var _area_strikes: Node3D
var _area_burns: Node3D
var _homing_held_last := {}
var _server_rc_orbs := {}
var _rc_orb_visuals := {}
var _rc_fire_prev := {}
var _rc_shot_count := 0
var _rc_detonation_count := 0
var _rc_hit_count := 0

var _players: Node3D
var _spawner: MultiplayerSpawner
var _balls: Node3D
var _ball_spawner: MultiplayerSpawner
var _targets: Node3D
var _combat_bolts: Node3D
var _shield_drone: Node3D
var _impact_fx: Node3D
var _camera: Camera3D
var _shadow_light: SpotLight3D
var _status_label: Label
var _editor_label: Label
var _fps_label: Label
var _shader_prewarm: Node3D
var _driving_course: Node3D
var _jump_gates: Node3D
var _dots: Node3D
var _webrtc_transport: Node
var _mux_peer
var _network_status := ""

func _ready() -> void:
	_parse_args()
	_configure_network_stack()
	_set_client_window_title()
	_start_crash_telemetry()
	_start_window_safety()
	# Launch directly into driving. The coverage editor remains available on E,
	# and its cones remain opt-in during driving on C.
	_combat_editor_active = false
	if _role == "proxy":
		_start_proxy()
		return
	_connect_network_events()
	_build_world()
	NetworkTime.on_tick.connect(_on_tick)
	NetworkTime.after_sync.connect(_inject_join_stall_for_test)
	if _role == "server":
		_start_server()
	elif _role == "offline":
		await _start_offline()
	else:
		if DisplayServer.get_name() != "headless" and _shader_prewarm != null:
			# Compile the cloak pipelines before ENet/netfox starts its clock. Doing
			# this after spawn can consume the rollback history on Intel Compatibility.
			# Presentation gates still use a headless display and cannot produce the
			# frame_post_draw signal even though they build presentation nodes.
			await RenderingServer.frame_post_draw
			_shader_prewarm.visible = false
		_start_client()


func _exit_tree() -> void:
	if _webrtc_transport != null:
		_webrtc_transport.call("close")

## Deterministic positive control for the late-join/render-stall regression.
## A real rendered client can pause here for shader compilation after netfox
## synchronizes. Headless gates use the otherwise-unset environment variables
## to reproduce that pause without changing ordinary client behavior.
func _inject_join_stall_for_test() -> void:
	if _role != "client":
		return
	var stall_ms := int(OS.get_environment("CAR_FIGHT_JOIN_STALL_MS"))
	if stall_ms <= 0:
		return
	var after_ms := int(OS.get_environment("CAR_FIGHT_JOIN_STALL_AFTER_MS"))
	if after_ms > 0:
		await get_tree().create_timer(float(after_ms) / 1000.0).timeout
	_log("JOINSTALL begin ms=%d tick=%d" % [stall_ms, NetworkTime.tick])
	OS.delay_msec(stall_ms)
	_log("JOINSTALL end ms=%d tick=%d" % [stall_ms, NetworkTime.tick])

func _start_crash_telemetry() -> void:
	var telemetry_path := OS.get_environment("CAR_FIGHT_TELEMETRY_FILE")
	var web_console := OS.has_feature("web")
	if telemetry_path.is_empty() and not web_console:
		return
	_crash_telemetry = Node.new()
	_crash_telemetry.name = "CrashTelemetry"
	_crash_telemetry.set_script(CRASH_TELEMETRY_SCRIPT)
	_crash_telemetry.set("output_path", telemetry_path)
	_crash_telemetry.set("role", _role)
	_crash_telemetry.set("console_output", web_console)
	add_child(_crash_telemetry)


func _start_window_safety() -> void:
	if _role == "server" or _role == "proxy":
		return
	var policy := Node.new()
	policy.name = "WindowSafetyPolicy"
	policy.set_script(WINDOW_SAFETY_POLICY_SCRIPT)
	policy.connect("enforced", _on_window_safety_enforced)
	add_child(policy)


func _on_window_safety_enforced(event: String, details: Dictionary) -> void:
	if _crash_telemetry != null:
		_crash_telemetry.call("record_event", event, details)

func _process(_delta: float) -> void:
	if multiplayer.is_server():
		_sample_impact_motion()
	if _camera == null:
		return
	var local: Node3D = local_player()
	var target: Vector3 = Vector3.ZERO if local == null \
		else ELEVATED_COURSE.camera_target(local.global_position)
	# The RC orb is the player's active viewpoint. Its visual is fed by the
	# authoritative lightweight projectile snapshots, so the camera follows the
	# same state every observer sees and cleanly returns to the Jeep on the
	# reliable terminal event.
	if local != null:
		var rc_visual: Variant = _rc_orb_visuals.get(int(local.name))
		if is_instance_valid(rc_visual):
			target = ELEVATED_COURSE.camera_target((rc_visual as Node3D).global_position)
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
		var location := "ARENA"
		if local != null:
			location = MAP_LAYOUT.map_name(int(local.get("map_id")))
			if int(local.get("map_id")) == MAP_LAYOUT.DRIVING_COURSE:
				var section: Dictionary = DRIVING_COURSE_SCRIPT.section_at(local.global_position)
				location = "%s  ·  %s — %s%s" % [location, section["id"],
					section["name"], "  ·  OFF TRACK" if DRIVING_COURSE_SCRIPT.off_track(
						local.global_position) else ""]
		if not _combat_editor_active and local != null and bool(local.get("is_cloaked")):
			mode = "DRIVE + CLOAKED (AUTO FIRE OFF)"
		elif not _combat_editor_active and local != null and bool(local.get("shield_up")):
			mode = "DRIVE + SHIELDED"
		if _dots != null:
			mode = "%s  ·  dots %d (%d left)" % [mode, int(_dots.call("collected_by", id)),
				int(_dots.call("remaining"))]
		_status_label.text = "CAR FIGHT  |  %s  |  peer %d  |  %.1f u/s\n%s\n%s" % [
			mode, id, speed, location,
			"Drag cone handles  |  F: flip  |  R: reset  |  Enter: drive" if _combat_editor_active \
			else "Mouse: drive  |  V: vehicle  |  1: homing missile  |  2: RC orb  |  Click: detonate RC orb  |  3: area weapon  |  Cmd: det  |  Q: shield  |  R: cloak  |  Shift: vacuum  |  Space: burst  |  Tab: reverse  |  E: editor  |  C: cones"]
		if local != null and bool(local.get("area_weapon_armed")):
			_status_label.text += "\nAREA WEAPON ARMED  ·  Hold and drag Left Mouse, then release to bomb  ·  3: stow"
		if local == null and not _network_status.is_empty():
			_status_label.text = "CAR FIGHT  |  BROWSER NETWORK\n%s\n%s" % [
				_network_status, _connection_target()]
	if _fps_label != null:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_update_editor_label()

func _parse_args() -> void:
	_ramps_enabled = OS.get_environment("CAR_FIGHT_NO_RAMPS") != "1"
	# Keep the accepted offline export unchanged. The separate Web Network
	# preset opts into the browser WebRTC client with a custom feature.
	if OS.has_feature("web"):
		if OS.has_feature("web_network"):
			_role = "client"
			_transport = "webrtc"
			_signal_url = _web_query("signal")
			if _signal_url.is_empty():
				_signal_url = _default_web_signaling_url()
			var browser_name := _web_query("name")
			if not browser_name.is_empty():
				_player_name = browser_name
			_webrtc_channel_telemetry = _web_query("webrtcTelemetry") == "1"
			var bundles_query := _web_query("stateBundles")
			if not bundles_query.is_empty():
				_state_bundles = bundles_query == "1"
			var input_broadcast_query := _web_query("inputBroadcast")
			if not input_broadcast_query.is_empty():
				_input_broadcast = input_broadcast_query == "1"
			var packed_input_query := _web_query("packedInput")
			if not packed_input_query.is_empty():
				_packed_input = packed_input_query == "1"
			var packed_state_query := _web_query("packedState")
			if not packed_state_query.is_empty():
				_packed_state = packed_state_query == "1"
			var state_rate_query := _web_query("stateRateDivisor")
			if state_rate_query.is_valid_int():
				_state_rate_divisor = maxi(1, int(state_rate_query))
			var adaptive_rate_query := _web_query("adaptiveStateRate")
			if not adaptive_rate_query.is_empty():
				_adaptive_state_rate = adaptive_rate_query == "1"
			_network_app_telemetry = _web_query("netTelemetry") == "1"
			var remote_transport_query := _web_query("remoteStateTransport")
			if remote_transport_query in ["legacy", "batch"]:
				_remote_state_transport = remote_transport_query
			var remote_rate_query := _web_query("remoteStateRate")
			if int(remote_rate_query) in [20, 30, 60]:
				_remote_state_rate = int(remote_rate_query)
			var remote_relevance_query := _web_query("remoteStateRelevance")
			if remote_relevance_query in ["all", "same-map"]:
				_remote_state_relevance = remote_relevance_query
			var remote_self_query := _web_query("remoteStateIncludeSelf")
			if not remote_self_query.is_empty():
				_remote_state_include_self = remote_self_query == "1"
			var resim_budget_query := _web_query("resimBudgetMs")
			if resim_budget_query.is_valid_float():
				_resim_budget_ms = maxf(0.0, float(resim_budget_query))
			var turn_url := _web_query("turn")
			if not turn_url.is_empty():
				var ice_server := {"urls": [turn_url]}
				var turn_username := _web_query("turnUser")
				var turn_credential := _web_query("turnCredential")
				if not turn_username.is_empty():
					ice_server["username"] = turn_username
				if not turn_credential.is_empty():
					ice_server["credential"] = turn_credential
				_ice_servers.push_back(ice_server)
			_ice_relay_only = _web_query("relay") == "1"
			if not turn_url.is_empty() or _ice_relay_only:
				print("[network-shape] transport=webrtc turn=%s relay_only=%s credentials=%s" % [
					str(not turn_url.is_empty()), str(_ice_relay_only),
					str(not _web_query("turnUser").is_empty() and
						not _web_query("turnCredential").is_empty()),
				])
		else:
			_role = "offline"
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var arg: String = args[index]
		if arg == "--server":
			_role = "server"
		elif arg == "--client":
			_role = "client"
		elif arg == "--offline":
			_role = "offline"
		elif arg == "--proxy":
			_role = "proxy"
		elif arg.begins_with("--transport="):
			_transport = arg.get_slice("=", 1).to_lower()
		elif arg == "--transport" and index + 1 < args.size():
			index += 1
			_transport = args[index].to_lower()
		elif arg.begins_with("--signal-port="):
			_signal_port = int(arg.get_slice("=", 1))
		elif arg == "--signal-port" and index + 1 < args.size():
			index += 1
			_signal_port = int(args[index])
		elif arg.begins_with("--signal-url="):
			_signal_url = arg.get_slice("=", 1)
		elif arg == "--signal-url" and index + 1 < args.size():
			index += 1
			_signal_url = args[index]
		elif arg == "--webrtc-telemetry":
			_webrtc_channel_telemetry = true
		elif arg == "--net-telemetry":
			_network_app_telemetry = true
		elif arg.begins_with("--remote-state-transport="):
			_remote_state_transport = arg.get_slice("=", 1).to_lower()
		elif arg == "--remote-state-transport" and index + 1 < args.size():
			index += 1
			_remote_state_transport = args[index].to_lower()
		elif arg.begins_with("--remote-state-rate="):
			_remote_state_rate = int(arg.get_slice("=", 1))
		elif arg == "--remote-state-rate" and index + 1 < args.size():
			index += 1
			_remote_state_rate = int(args[index])
		elif arg.begins_with("--remote-state-relevance="):
			_remote_state_relevance = arg.get_slice("=", 1).to_lower()
		elif arg == "--remote-state-relevance" and index + 1 < args.size():
			index += 1
			_remote_state_relevance = args[index].to_lower()
		elif arg.begins_with("--remote-state-include-self="):
			_remote_state_include_self = int(arg.get_slice("=", 1)) != 0
		elif arg == "--remote-state-include-self" and index + 1 < args.size():
			index += 1
			_remote_state_include_self = int(args[index]) != 0
		elif arg.begins_with("--resim-budget-ms="):
			_resim_budget_ms = maxf(0.0, float(arg.get_slice("=", 1)))
		elif arg == "--resim-budget-ms" and index + 1 < args.size():
			index += 1
			_resim_budget_ms = maxf(0.0, float(args[index]))
		elif arg == "--state-bundles":
			_state_bundles = true
		elif arg == "--no-state-bundles":
			_state_bundles = false
		elif arg == "--packed-input":
			_packed_input = true
		elif arg == "--no-packed-input":
			_packed_input = false
		elif arg == "--packed-state":
			_packed_state = true
		elif arg == "--no-packed-state":
			_packed_state = false
		elif arg.begins_with("--input-broadcast="):
			_input_broadcast = int(arg.get_slice("=", 1)) != 0
		elif arg == "--input-broadcast" and index + 1 < args.size():
			index += 1
			_input_broadcast = int(args[index]) != 0
		elif arg.begins_with("--state-rate-divisor="):
			_state_rate_divisor = maxi(1, int(arg.get_slice("=", 1)))
		elif arg == "--state-rate-divisor" and index + 1 < args.size():
			index += 1
			_state_rate_divisor = maxi(1, int(args[index]))
		elif arg.begins_with("--adaptive-state-rate="):
			_adaptive_state_rate = int(arg.get_slice("=", 1)) != 0
		elif arg == "--adaptive-state-rate" and index + 1 < args.size():
			index += 1
			_adaptive_state_rate = int(args[index]) != 0
		elif arg == "--ice-relay-only":
			_ice_relay_only = true
		elif arg == "--ice-server" and index + 1 < args.size():
			index += 1
			_ice_servers.push_back({"urls": [args[index]]})
		elif arg == "--ice-username" and index + 1 < args.size():
			index += 1
			if not _ice_servers.is_empty():
				_ice_servers[-1]["username"] = args[index]
		elif arg == "--ice-credential" and index + 1 < args.size():
			index += 1
			if not _ice_servers.is_empty():
				_ice_servers[-1]["credential"] = args[index]
		elif arg == "--mux-collision-test":
			_mux_collision_test = true
		elif arg == "--mux-close-transport-test" and index + 1 < args.size():
			index += 1
			_mux_close_transport_test = args[index].to_lower()
		elif arg == "--presentation-test":
			_force_presentation = true
		elif arg == "--server-driver":
			_server_driver_enabled = true
		elif arg == "--no-ramps":
			_ramps_enabled = false
		elif arg == "--course-test":
			_course_test = true
		elif arg == "--reverse-test":
			_reverse_test = true
		elif arg == "--gate-test":
			_gate_test = true
		elif arg == "--no-drone":
			_drone_enabled = false
		elif arg.begins_with("--host="):
			_host = arg.get_slice("=", 1)
			_proxy_server_host = _host
		elif arg == "--host" and index + 1 < args.size():
			index += 1
			_host = args[index]
			_proxy_server_host = _host
		elif arg.begins_with("--to-host="):
			_proxy_server_host = arg.get_slice("=", 1)
		elif arg == "--to-host" and index + 1 < args.size():
			index += 1
			_proxy_server_host = args[index]
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
		elif arg.begins_with("--session-label="):
			_session_label = arg.get_slice("=", 1)
		elif arg == "--session-label" and index + 1 < args.size():
			index += 1
			_session_label = args[index]
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
		elif arg == "--jitter" and index + 1 < args.size():
			index += 1
			_jitter_ms = int(args[index])
		elif arg.begins_with("--loss="):
			_loss_pct = float(arg.get_slice("=", 1))
		elif arg == "--loss" and index + 1 < args.size():
			index += 1
			_loss_pct = float(args[index])
		elif arg.begins_with("--shape-seed="):
			_shape_seed = int(arg.get_slice("=", 1))
		elif arg == "--shape-seed" and index + 1 < args.size():
			index += 1
			_shape_seed = int(args[index])
		index += 1


func _configure_network_stack() -> void:
	NetworkPerformance.set_app_telemetry_enabled(_network_app_telemetry)
	RemotePositionTransport.configure(_remote_state_push, _remote_state_transport,
		_remote_state_rate, _network_app_telemetry, _remote_state_relevance,
		_remote_state_include_self)
	StateBundle.set_enabled(_state_bundles)
	StateBundle.set_input_broadcast(_input_broadcast)
	StateBundle.set_input_packing(_packed_input)
	StateBundle.set_state_packing(_packed_state)
	StateBundle.set_state_rate_divisor(_state_rate_divisor)
	StateBundle.set_adaptive_state_rate(_adaptive_state_rate)
	NetworkRollback.resim_budget_ms = _resim_budget_ms
	print("[resim-budget] ms=%.1f" % _resim_budget_ms)


func _web_query(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval(
		"new URLSearchParams(location.search).get(%s) || ''" % JSON.stringify(key)))


func _default_web_signaling_url() -> String:
	var protocol := str(JavaScriptBridge.eval("location.protocol"))
	var hostname := str(JavaScriptBridge.eval("location.hostname"))
	return "%s://%s:%d" % ["wss" if protocol == "https:" else "ws", hostname, _signal_port]

func _set_client_window_title() -> void:
	if _role != "client" or DisplayServer.get_name() == "headless":
		return
	if _session_label.is_empty():
		_session_label = OS.get_environment("CAR_FIGHT_SESSION_LABEL")
	if _session_label.is_empty():
		_session_label = "unlabelled session"
	DisplayServer.window_set_title("CAR FIGHT — %s — %s" % [_session_label, _player_name])

func _start_proxy() -> void:
	var proxy := Node.new()
	proxy.name = "LatencyProxy"
	proxy.set_script(load("res://net/latency_proxy.gd"))
	proxy.set("listen_port", _port)
	proxy.set("server_host", _proxy_server_host)
	proxy.set("server_port", _to_port)
	proxy.set("latency_ms", _latency_ms)
	proxy.set("jitter_ms", _jitter_ms)
	proxy.set("loss_pct", _loss_pct)
	proxy.set("seed", _shape_seed)
	add_child(proxy)
	proxy.call("start")

func _connect_network_events() -> void:
	NetworkEvents.on_server_start.connect(func(): _log("SERVER_READY port=%d" % _port))
	NetworkEvents.on_client_start.connect(func(id: int):
		_network_status = ""
		_log("CLIENT_READY id=%d name=%s" % [id, _player_name])
	)
	NetworkEvents.on_client_stop.connect(func():
		_log("CLIENT_STOPPED")
		if _quit_after_ticks > 0:
			get_tree().quit(2)
	)
	NetworkEvents.on_peer_join.connect(_on_peer_join)
	NetworkEvents.on_peer_leave.connect(_on_peer_leave)

func _start_server() -> void:
	var peer: MultiplayerPeer
	var error := OK
	if _transport == "webrtc":
		_webrtc_transport = WEBRTC_TRANSPORT_SCRIPT.new()
		add_child(_webrtc_transport)
		_webrtc_transport.connect("failed", _on_webrtc_failed)
		peer = _webrtc_transport.call("start_server", _signal_port, _ice_servers,
			_ice_relay_only, 1, _webrtc_channel_telemetry)
		error = OK if peer != null else ERR_CANT_CREATE
		if peer != null:
			StateBundle.set_send_pressure_provider(_webrtc_transport.peer_buffered_bytes)
	elif _transport == "mux":
		var enet_peer := ENetMultiplayerPeer.new()
		error = enet_peer.create_server(_port, MAX_CLIENTS)
		if error == OK:
			_mux_peer = MUX_MULTIPLAYER_PEER_SCRIPT.new()
			_mux_peer.call("add_inner", "enet", enet_peer)
			_mux_peer.connect("peer_rejected", _on_mux_peer_rejected)
			_webrtc_transport = WEBRTC_TRANSPORT_SCRIPT.new()
			add_child(_webrtc_transport)
			_webrtc_transport.connect("failed", _on_webrtc_failed)
			_webrtc_transport.call("set_peer_id_reserved_provider",
				_mux_peer.has_enet_peer)
			if _mux_collision_test:
				_webrtc_transport.call("set_forced_peer_id_provider",
					_mux_peer.first_peer_for_transport.bind("enet"))
			var rtc_peer: MultiplayerPeer = _webrtc_transport.call("start_server",
				_signal_port, _ice_servers, _ice_relay_only, 1, _webrtc_channel_telemetry)
			if rtc_peer == null:
				error = ERR_CANT_CREATE
				enet_peer.close()
			else:
				_mux_peer.call("add_inner", "webrtc", rtc_peer)
				_mux_peer.call("set_send_guard", "webrtc", _webrtc_transport.peer_can_send)
				peer = _mux_peer
				StateBundle.set_peer_transport_provider(_mux_peer.transport_for_peer)
				StateBundle.set_send_pressure_provider(_webrtc_transport.peer_buffered_bytes)
	else:
		_transport = "enet"
		peer = ENetMultiplayerPeer.new()
		error = (peer as ENetMultiplayerPeer).create_server(_port, MAX_CLIENTS)
	if error != OK:
		push_error("Could not start %s server: %s" % [_transport, error_string(error)])
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	_dots.call("generate")
	if _server_driver_enabled:
		_spawn_server_driver()
	if _transport == "mux":
		_log("server listening transport=mux enet=:%d webrtc_signal=:%d" % [_port, _signal_port])
	elif _transport == "webrtc":
		_log("server listening transport=webrtc signal=:%d" % _signal_port)
	else:
		_log("server listening on udp://0.0.0.0:%d" % _port)

func _start_client() -> void:
	multiplayer.connection_failed.connect(func():
		_network_status = "CONNECTION FAILED"
		push_error("Connection failed to %s" % _connection_target())
		if _quit_after_ticks > 0:
			get_tree().quit(2)
	)
	if _transport == "webrtc":
		if _signal_url.is_empty():
			_signal_url = "ws://%s:%d" % [_host, _signal_port]
		_network_status = "CONNECTING TO WEBRTC"
		_webrtc_transport = WEBRTC_TRANSPORT_SCRIPT.new()
		add_child(_webrtc_transport)
		_webrtc_transport.connect("failed", _on_webrtc_failed)
		_webrtc_transport.connect("multiplayer_peer_ready", _on_webrtc_peer_ready,
			CONNECT_ONE_SHOT)
		var rtc_peer: MultiplayerPeer = _webrtc_transport.call("start_client", _signal_url,
			_ice_servers, _ice_relay_only, 1, _webrtc_channel_telemetry)
		if rtc_peer == null:
			_on_webrtc_failed("Could not create WebRTC client")
			return
		StateBundle.set_send_pressure_provider(_webrtc_transport.peer_buffered_bytes)
		_set_client_window_title()
		_log("client signaling transport=webrtc at %s as %s" % [_signal_url, _player_name])
		return
	_transport = "enet"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(_host, _port)
	if error != OK:
		push_error("Could not connect to %s:%d: %s" % [_host, _port, error_string(error)])
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	_set_client_window_title()
	_log("connecting to udp://%s:%d as %s" % [_host, _port, _player_name])


func _connection_target() -> String:
	return _signal_url if _transport == "webrtc" else "%s:%d" % [_host, _port]


func _on_webrtc_peer_ready(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	_network_status = "JOINING AUTHORITATIVE WORLD"
	_log("client connecting transport=webrtc to %s" % _signal_url)


func _on_webrtc_failed(message: String) -> void:
	_network_status = "WEBRTC FAILED: %s" % message
	if _quit_after_ticks > 0 or DisplayServer.get_name() == "headless":
		get_tree().quit(2)


func _on_mux_peer_rejected(peer_id: int, transport: String) -> void:
	if transport == "webrtc" and _webrtc_transport != null:
		_webrtc_transport.call("reject_server_peer", peer_id, "peer id collision")

func _start_offline() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var owner_id := multiplayer.get_unique_id()
	var body := _spawn_player({"id": owner_id, "slot": 0,
		"remote_generation": _allocate_remote_state_generation()})
	_players.add_child(body, true)
	var config := _configuration_for(owner_id)
	_apply_coverage_config(owner_id, config["ranges"], config["widths"],
		config["tips_outward"])
	var ball := _spawn_ball({"name": "ArenaBall", "position": BALL_SCRIPT.SPAWN_POSITION})
	_balls.add_child(ball, true)
	_ball_seeded = true
	_next_spawn_slot = 1
	var time_error: int = await NetworkTime.start()
	if time_error != OK:
		push_error("Could not start offline simulation clock: %s" % error_string(time_error))
		get_tree().quit(2)
		return
	_log("OFFLINE_READY id=%d players=%d balls=%d" % [owner_id,
		_players.get_child_count(), _balls.get_child_count()])
	if _crash_telemetry != null:
		_crash_telemetry.call("record_event", "offline_ready", {
			"peer_id": owner_id,
			"players": _players.get_child_count(),
			"balls": _balls.get_child_count(),
		})

func _on_peer_join(id: int) -> void:
	if not multiplayer.is_server():
		return
	_log("PEER_JOIN id=%d slot=%d" % [id, _next_spawn_slot])
	if _transport == "mux":
		# Push before spawn: synchronizers latch input-broadcast policy while
		# entering the tree, so native peers need the WebRTC recipient map now.
		_broadcast_peer_transport_map()
	var spawn_data := {"id": id, "slot": _next_spawn_slot,
		"remote_generation": _allocate_remote_state_generation()}
	if _server_driver_enabled:
		var observer_position := Vector3(SERVER_DRIVER_SPAWN.x + 8.0,
			ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), SERVER_DRIVER_SPAWN.y + 6.0)
		var driver := _players.get_node_or_null("1") as Node3D
		if driver != null:
			observer_position.x = clampf(driver.global_position.x - 8.0,
				-ARENA_HALF + 3.0, ARENA_HALF - 3.0)
			observer_position.z = clampf(driver.global_position.z + 6.0,
				-ARENA_HALF + 3.0, ARENA_HALF - 3.0)
		spawn_data["position"] = observer_position
		spawn_data["yaw"] = -PI * 0.5
	_spawner.spawn(spawn_data)
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
	_dots.call("send_state_to", id)

func _spawn_server_driver() -> void:
	if not multiplayer.is_server() or _players.get_node_or_null("1") != null:
		return
	_log("SERVER_DRIVER spawn id=1 slot=%d path=open-perimeter" % _next_spawn_slot)
	_spawner.spawn({"id": 1, "slot": _next_spawn_slot,
		"position": Vector3(SERVER_DRIVER_SPAWN.x,
			ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), SERVER_DRIVER_SPAWN.y),
		"yaw": -PI * 0.5,
		"remote_generation": _allocate_remote_state_generation()})
	_server_driver_waypoint = 1
	_server_driver_progress_tick = -1
	_server_driver_progress_position = SERVER_DRIVER_SPAWN
	_next_spawn_slot += 1

func _on_peer_leave(id: int) -> void:
	StateBundle.forget_peer_transport(id)
	if not multiplayer.is_server():
		return
	var body := _players.get_node_or_null(str(id))
	if body != null:
		if _transport == "mux":
			var synchronizer := body.get_node_or_null("RollbackSynchronizer")
			if synchronizer != null and synchronizer.has_method("suspend_for_departure"):
				synchronizer.call("suspend_for_departure")
			_free_mux_departure_later(body, id)
		else:
			body.queue_free()
	_log("PEER_LEAVE id=%d" % id)


func _broadcast_peer_transport_map() -> void:
	if _role != "server" or _transport != "mux" or _mux_peer == null:
		return
	var transports := {}
	for peer_variant in multiplayer.get_peers():
		var peer_id := int(peer_variant)
		transports[peer_id] = _mux_peer.transport_for_peer(peer_id)
	_apply_peer_transport_map.rpc(transports)


@rpc("authority", "reliable", "call_local")
func _apply_peer_transport_map(transports: Dictionary) -> void:
	var clean := {}
	for peer_variant in transports:
		var peer_id := int(peer_variant)
		var transport := str(transports[peer_variant])
		if peer_id > 1 and transport in ["enet", "webrtc"]:
			clean[peer_id] = transport
	StateBundle.set_peer_transport_map(clean)


func _free_mux_departure_later(body: Node, peer_id: int) -> void:
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(body):
		body.queue_free()
		_log("MUX_DEPARTURE_DRAINED id=%d" % peer_id)

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
	_area_strikes = Node3D.new()
	_area_strikes.name = "AreaStrikes"
	add_child(_area_strikes)
	_area_burns = Node3D.new()
	_area_burns.name = "AreaBurns"
	add_child(_area_burns)
	_shield_drone = Node3D.new()
	_shield_drone.name = "ShieldTestDrone"
	_shield_drone.set_script(SHIELD_DRONE_SCRIPT)
	_shield_drone.position = SHIELD_DRONE_SCRIPT.ARENA_POSITION
	add_child(_shield_drone)
	if not _is_headless():
		_shield_drone.call("build_presentation")
	_build_arena()
	_driving_course = Node3D.new()
	_driving_course.name = "DrivingCourse"
	_driving_course.set_script(DRIVING_COURSE_SCRIPT)
	_driving_course.call("setup", _players)
	add_child(_driving_course)
	_jump_gates = Node3D.new()
	_jump_gates.name = "JumpGates"
	_jump_gates.set_script(JUMP_GATES_SCRIPT)
	_jump_gates.call("setup", _players)
	add_child(_jump_gates)
	_dots = Node3D.new()
	_dots.name = "Dots"
	_dots.set_script(DOTS_SCRIPT)
	add_child(_dots)
	_build_combat_targets()
	if not _is_headless():
		# Grass is intentionally presentation-only. The existing GroundCollision
		# remains the sole static collider on server and predicting clients.
		var grass := Node3D.new()
		grass.name = "InteractiveGrass"
		grass.set_script(INTERACTIVE_GRASS_SCRIPT)
		grass.call("setup", _players, _combat_bolts)
		# A deliberate 36 m test plot on the quiet east side of the arena: dense
		# enough to read as a real patch, but small enough to compare with bare ground.
		grass.position = Vector3(58.0, 0.0, 18.0)
		add_child(grass)
		_driving_course.call("build_presentation")
		_jump_gates.call("build_presentation")
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
	body.set("remote_state_generation", int(info.get("remote_generation", 0)))
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
	if info.has("position"):
		spawn.origin = info["position"] as Vector3
	if info.has("yaw"):
		spawn.basis = Basis(Vector3.UP, float(info["yaw"]))
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
	if _role != "offline":
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


func _allocate_remote_state_generation() -> int:
	var generation := _next_remote_state_generation
	_next_remote_state_generation += 1
	return generation

func _spawn_transform(slot: int) -> Transform3D:
	if _gate_test and slot == 0:
		return Transform3D(Basis.IDENTITY, Vector3(MAP_LAYOUT.ARENA_GATE.x,
			ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), MAP_LAYOUT.ARENA_GATE.z))
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

	if _role != "offline":
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
	var shield_visual := Node3D.new()
	shield_visual.name = "VehicleShield"
	shield_visual.set_script(SHIELD_VISUAL_SCRIPT)
	body.add_child(shield_visual)
	var det_bubble := Node3D.new()
	det_bubble.name = "DetBubble"
	det_bubble.set_script(DET_BUBBLE_SCRIPT)
	body.add_child(det_bubble)
	if owner_id == multiplayer.get_unique_id():
		var drift_guide := Node3D.new()
		drift_guide.name = "DriftGuide"
		drift_guide.set_script(DRIFT_GUIDE_SCRIPT)
		drift_guide.position.y = -PLAYER_RADIUS + 0.11
		body.add_child(drift_guide)
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
	var max_speed_marker := MeshInstance3D.new()
	max_speed_marker.name = "MaxSpeedMarker"
	max_speed_marker.top_level = true
	var max_speed_mesh := CylinderMesh.new()
	max_speed_mesh.top_radius = 0.15
	max_speed_mesh.bottom_radius = 0.15
	max_speed_mesh.height = 0.045
	max_speed_marker.mesh = max_speed_mesh
	max_speed_marker.material_override = _material(Color("fff1b8"), true)
	max_speed_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	max_speed_marker.visible = is_local
	body.add_child(max_speed_marker)

	var line := MeshInstance3D.new()
	line.name = "CursorLine"
	line.top_level = true
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.045, 0.025, 1.0)
	line.mesh = line_mesh
	line.material_override = _material(Color(color, 0.7), true)
	line.visible = is_local
	body.add_child(line)

	if is_local:
		var area_preview := Node3D.new()
		area_preview.name = "AreaTargetPreview"
		area_preview.set_script(AREA_TARGET_PREVIEW_SCRIPT)
		area_preview.set("owner_body", body)
		body.add_child(area_preview)
		var catch_ring := MeshInstance3D.new()
		catch_ring.name = "TractorCatchRing"
		catch_ring.top_level = true
		var ring_mesh := TorusMesh.new()
		ring_mesh.outer_radius = TRACTOR_CONTROLLER.VACUUM_RADIUS
		ring_mesh.inner_radius = TRACTOR_CONTROLLER.VACUUM_RADIUS - 0.12
		ring_mesh.rings = 36
		ring_mesh.ring_segments = 6
		catch_ring.mesh = ring_mesh
		var ring_material := _material(Color(0.39, 0.82, 1.0, 0.86), true)
		ring_material.emission_enabled = true
		ring_material.emission = Color("63d8ff")
		ring_material.emission_energy_multiplier = 1.8
		catch_ring.material_override = ring_material
		catch_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		catch_ring.visible = false
		body.add_child(catch_ring)

	var rope := MeshInstance3D.new()
	rope.name = "TractorRope"
	rope.top_level = true
	var rope_mesh := BoxMesh.new()
	rope_mesh.size = Vector3(0.065, 0.055, 1.0)
	rope.mesh = rope_mesh
	var rope_material := _material(Color(0.38, 0.78, 1.0, 0.88), true)
	rope_material.emission_enabled = true
	rope_material.emission = Color("63d8ff")
	rope_material.emission_energy_multiplier = 2.1
	rope.material_override = rope_material
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.visible = false
	body.add_child(rope)

func _build_arena() -> void:
	_add_static_box("GroundCollision", Vector3(ARENA_HALF * 2.0, 1.0, ARENA_HALF * 2.0),
		Vector3(0.0, -0.5, 0.0), Color("202a2d"), 0.0, false)
	if not _is_headless():
		_build_shader_ground("ShaderGridGround", Vector3.ZERO, ARENA_HALF)
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
	if _ramps_enabled:
		_build_elevated_course()
	_build_driving_course_space()


func _build_driving_course_space() -> void:
	var center := MAP_LAYOUT.COURSE_CENTER
	var half := MAP_LAYOUT.COURSE_HALF_EXTENT
	_add_static_box("CourseGroundCollision", Vector3(half * 2.0, 1.0, half * 2.0),
		center + Vector3(0.0, -0.5, 0.0), Color("182225"), 0.0, false)
	if not _is_headless():
		_build_shader_ground("CourseShaderGridGround", center, half)
	var wall_height: float = ARENA_CONFIG.WALL_HEIGHT
	var wall_thickness: float = ARENA_CONFIG.WALL_THICKNESS
	var wall_y := wall_height * 0.5
	_add_static_box("CourseWallNorth", Vector3(half * 2.0 + wall_thickness * 2.0,
		wall_height, wall_thickness), center + Vector3(0.0, wall_y, -half), Color("40545b"))
	_add_static_box("CourseWallSouth", Vector3(half * 2.0 + wall_thickness * 2.0,
		wall_height, wall_thickness), center + Vector3(0.0, wall_y, half), Color("40545b"))
	_add_static_box("CourseWallWest", Vector3(wall_thickness, wall_height, half * 2.0),
		center + Vector3(-half, wall_y, 0.0), Color("40545b"))
	_add_static_box("CourseWallEast", Vector3(wall_thickness, wall_height, half * 2.0),
		center + Vector3(half, wall_y, 0.0), Color("40545b"))

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

func _build_shader_ground(node_name: String, center: Vector3, half_extent: float) -> void:
	var ground := MeshInstance3D.new()
	ground.name = node_name
	ground.position = center + Vector3(0.0, -0.01, 0.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_extent * 2.0, half_extent * 2.0)
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
		# Static arena geometry receives the vehicle/ball shadows but does not
		# enter the moving spotlight's shadow pass every rendered frame.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	# Compatibility's soft positional-shadow filter uses a rotating sample
	# pattern that crawls across plain walls. project.godot selects hard filtering
	# with a 32-bit depth atlas; keep per-light blur disabled to match it.
	_shadow_light.shadow_blur = 0.0
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
	_build_shader_prewarm()
	_impact_fx = Node3D.new()
	_impact_fx.name = "ImpactFX"
	_impact_fx.set_script(IMPACT_FX_SCRIPT)
	add_child(_impact_fx)
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
	_fps_label = Label.new()
	_fps_label.name = "FPSCounter"
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -110.0
	_fps_label.offset_top = 16.0
	_fps_label.offset_right = -18.0
	_fps_label.offset_bottom = 42.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_color", Color("aebfc3"))
	hud.add_child(_fps_label)

func _build_shader_prewarm() -> void:
	_shader_prewarm = Node3D.new()
	_shader_prewarm.name = "ShaderPrewarm"
	_camera.add_child(_shader_prewarm)
	_shader_prewarm.position = Vector3(0.0, 0.0, -2.0)
	for shader in [CLOAK_DISSOLVE_SHADER, CLOAK_GHOST_SHADER, SHIELD_SHADER, HOMING_MISSILE_SHADER]:
		var instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.001
		sphere.height = 0.002
		instance.mesh = sphere
		var material := ShaderMaterial.new()
		material.shader = shader
		if shader == CLOAK_DISSOLVE_SHADER:
			material.set_shader_parameter("cut_position", -999.0)
		elif shader == CLOAK_GHOST_SHADER:
			material.set_shader_parameter("cloak_strength", 0.0)
		elif shader == SHIELD_SHADER:
			material.set_shader_parameter("shield_strength", 0.0)
			material.set_shader_parameter("impact_age", 1.2)
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shader_prewarm.add_child(instance)

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
	if _shield_drone != null:
		_shield_drone.visible = not _combat_editor_active and _drone_enabled
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
	_editor_label.text = "%s  ·  range %.1f  ·  width %.0f°  ·  %s\nAREA  %.1f / %.1f\nF: flip selected cone  ·  R: reset presets" % [
		COVERAGE.ZONE_NAMES[_selected_zone], ranges[_selected_zone],
		rad_to_deg(widths[_selected_zone]), direction_label, used, COVERAGE.TOTAL_BUDGET]

func _unhandled_input(event: InputEvent) -> void:
	if _role not in ["client", "offline"] or not _scripted.is_empty():
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
		elif event.keycode == KEY_V:
			_cycle_local_vehicle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and _combat_editor_active:
			_flip_selected_cone()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and _combat_editor_active:
			_reset_coverage_cones()
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

func _cycle_local_vehicle() -> void:
	var local: Node3D = local_player()
	if local == null:
		return
	var hull: Node = local.get_node_or_null("GroundVehicleHull")
	if hull != null and hull.has_method("cycle_vehicle"):
		hull.call("cycle_vehicle")

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

func _reset_coverage_cones() -> void:
	var id := multiplayer.get_unique_id()
	_coverage_configs[id] = {
		"ranges": COVERAGE.default_ranges(),
		"widths": COVERAGE.default_widths(),
		"tips_outward": COVERAGE.default_tips_outward(),
	}
	_coverage_drag.clear()
	_selected_zone = 0
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
		var handles: Dictionary = COVERAGE.editor_handle_positions(zone, ranges[zone], widths[zone],
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
	if _role == "offline":
		_apply_coverage_config(multiplayer.get_unique_id(), config["ranges"],
			config["widths"], config["tips_outward"])
	else:
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
	var control_origin := body.global_position
	# During RC flight the camera is centered on the orb. Measure the mouse at
	# that same world point, otherwise its angular change is compressed by the
	# parked Jeep-to-orb distance and steering appears unresponsive.
	var rc_visual: Variant = _rc_orb_visuals.get(int(body.name))
	if is_instance_valid(rc_visual):
		control_origin = (rc_visual as Node3D).global_position
	var road_plane_y := control_origin.y - PLAYER_RADIUS
	var t := (road_plane_y - origin.y) / direction.y
	if t < 0.0:
		return Vector2.ZERO
	var hit := origin + direction * t
	var delta := hit - control_origin
	return Vector2(delta.x, delta.z).limit_length(FOLLOW.MAX_DISTANCE)

func is_scripted_client() -> bool:
	return not _scripted.is_empty() \
		or (_server_driver_enabled and multiplayer.is_server())

func scripted_input_for(body: Node3D) -> Dictionary:
	if _server_driver_enabled and multiplayer.is_server() and int(body.name) == 1:
		return _server_driver_input(body)
	match _scripted:
		"converge", "converge-burst":
			# Fixed opposing headings make the network gate test collision rather
			# than the far-distance FOLLOW turning radius around a moving target.
			var slot := int(body.get("spawn_slot"))
			var intent := Vector2(FOLLOW.MAX_DISTANCE, 0.0) if slot % 2 == 0 \
				else Vector2(-FOLLOW.MAX_DISTANCE, 0.0)
			return {"cursor_offset": intent, "burst": _scripted == "converge-burst"}
		"right":
			return {"cursor_offset": Vector2(FOLLOW.MAX_DISTANCE, 0.0), "burst": false}
		"burst-right":
			return {"cursor_offset": Vector2(FOLLOW.MAX_DISTANCE, 0.0), "burst": true}
		"ball":
			var target := BALL_SCRIPT.SPAWN_POSITION
			if _balls != null and _balls.get_child_count() > 0:
				target = (_balls.get_child(0) as Node3D).global_position
			var delta := target - body.global_position
			return {"cursor_offset": Vector2(delta.x, delta.z).limit_length(FOLLOW.MAX_DISTANCE), "burst": false}
		"ramp":
			# Begin the inward braking request before the road edge. Automatic skid
			# now preserves more momentum, so the deterministic landing needs the
			# same longer braking approach a player would use.
			var reach := 6.0 if body.position.z < -20.0 else FOLLOW.MAX_DISTANCE
			return {"cursor_offset": Vector2(0.0, -reach), "burst": false}
		"reverse":
			return {"cursor_offset": Vector2(FOLLOW.MAX_DISTANCE, 0.0), "burst": false, "reverse": true}
		"cloak":
			# Hold the level so rollback's rising-edge detector toggles exactly once.
			# Burst is deliberately requested to prove cloak's move-only gate.
			return {"cursor_offset": Vector2(FOLLOW.MAX_DISTANCE, 0.0), "burst": true,
				"cloak_held": true, "editing": false}
		"shield":
			return {"cursor_offset": Vector2.ZERO, "shield_held": true,
				"editing": false}
		"det":
			return {"cursor_offset": Vector2.ZERO, "det": true, "editing": false}
		"cloak-shield":
			return {"cursor_offset": Vector2.ZERO, "cloak_held": true,
				"shield_held": true, "editing": false}
		"drone-hit":
			return {"cursor_offset": Vector2.ZERO, "editing": false}
		"tractor":
			# Vacuum has no aim input. A zero drive cursor proves the ball enters
			# solely because it is inside the centered field.
			return {"cursor_offset": Vector2.ZERO, "tractor": true, "editing": false}
		"rc-orb":
			var elapsed: int = NetworkTime.tick - _start_tick
			return {"cursor_offset": Vector2(FOLLOW.MAX_DISTANCE, 0.0),
				"rc_fire_held": elapsed >= 20 and elapsed < 24,
				"rc_detonate_held": elapsed >= 130 and elapsed < 134,
				"editing": false}
		"combat":
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": false}
		"combat-edit":
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": true}
		"gate-loop":
			if int(body.get("map_id")) == MAP_LAYOUT.DRIVING_COURSE:
				var gate_delta := MAP_LAYOUT.course_gate() - body.global_position
				return {"cursor_offset": Vector2(gate_delta.x, gate_delta.z).limit_length(
					FOLLOW.MAX_DISTANCE), "burst": false, "editing": false}
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": false}
		_:
			return {"cursor_offset": Vector2.ZERO, "burst": false}

func _server_driver_input(body: Node3D) -> Dictionary:
	var waypoint: Vector2 = SERVER_DRIVER_ROUTE[_server_driver_waypoint]
	var delta := Vector2(waypoint.x - body.global_position.x,
		waypoint.y - body.global_position.z)
	return {"cursor_offset": delta.limit_length(
		FOLLOW.MAX_DISTANCE), "burst": false, "editing": false}

func _service_server_driver_route(tick: int) -> void:
	if not _server_driver_enabled:
		return
	var body := _players.get_node_or_null("1") as RigidBody3D
	if body == null:
		return
	if int(body.get("map_id")) != MAP_LAYOUT.ARENA \
			or absf(body.global_position.x) > SERVER_DRIVER_ARENA_LIMIT \
			or absf(body.global_position.z) > SERVER_DRIVER_ARENA_LIMIT:
		_recover_server_driver(body, tick)
	var position := Vector2(body.global_position.x, body.global_position.z)
	var waypoint: Vector2 = SERVER_DRIVER_ROUTE[_server_driver_waypoint]
	if position.distance_to(waypoint) <= SERVER_DRIVER_WAYPOINT_RADIUS:
		_server_driver_waypoint = (_server_driver_waypoint + 1) % SERVER_DRIVER_ROUTE.size()
		_server_driver_progress_tick = tick
		_server_driver_progress_position = position
		waypoint = SERVER_DRIVER_ROUTE[_server_driver_waypoint]
	elif _server_driver_progress_tick < 0 \
			or position.distance_to(_server_driver_progress_position) \
			>= SERVER_DRIVER_PROGRESS_DISTANCE:
		_server_driver_progress_tick = tick
		_server_driver_progress_position = position
	elif tick - _server_driver_progress_tick >= SERVER_DRIVER_STUCK_TICKS:
		_server_driver_waypoint = (_server_driver_waypoint + 1) % SERVER_DRIVER_ROUTE.size()
		_server_driver_progress_tick = tick
		_server_driver_progress_position = position
		waypoint = SERVER_DRIVER_ROUTE[_server_driver_waypoint]
		_log("SERVER_DRIVER escape tick=%d next=%d" % [tick, _server_driver_waypoint])
	if tick % 60 == 0:
		_log("SERVER_DRIVER tick=%d waypoint=%d pos=(%.1f,%.1f) target=(%.1f,%.1f) speed=%.1f" % [
			tick, _server_driver_waypoint, position.x, position.y,
			waypoint.x, waypoint.y, body.linear_velocity.length()])

func _recover_server_driver(body: RigidBody3D, tick: int) -> void:
	body.set("map_id", MAP_LAYOUT.ARENA)
	body.set("gate_cooldown", MAP_LAYOUT.GATE_COOLDOWN)
	body.position = Vector3(SERVER_DRIVER_SPAWN.x,
		ELEVATED_COURSE.ground_body_y(PLAYER_RADIUS), SERVER_DRIVER_SPAWN.y)
	body.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false
	body.reset_physics_interpolation()
	_server_driver_waypoint = 1
	_server_driver_progress_tick = tick
	_server_driver_progress_position = SERVER_DRIVER_SPAWN
	_log("SERVER_DRIVER recovered tick=%d reason=left-arena" % tick)

func local_player():
	if _players == null:
		return null
	return _players.get_node_or_null(str(multiplayer.get_unique_id()))

func _client_world_positions() -> String:
	var entries: PackedStringArray = []
	for child in _players.get_children():
		var body := child as Node3D
		if body != null:
			entries.append("%s:%.2f,%.2f" % [body.name, body.position.x, body.position.z])
	entries.sort()
	return "|".join(entries)

func _on_tick(delta: float, tick: int) -> void:
	if _start_tick < 0:
		_start_tick = tick
	var elapsed := tick - _start_tick
	if multiplayer.is_server() and _transport == "mux" and elapsed == 180 \
			and _mux_close_transport_test in ["enet", "webrtc"]:
		if _mux_close_transport_test == "webrtc":
			_webrtc_transport.call("close")
			_mux_peer.call("remove_inner", "webrtc")
		else:
			_mux_peer.call("close_inner", "enet")
		_log("MUX_TEST_CLOSED transport=%s tick=%d" % [_mux_close_transport_test, elapsed])
	if multiplayer.is_server():
		_service_server_driver_route(tick)
		_service_area_weapons()
		_service_rc_orbs(delta, tick)
		_service_auto_combat(delta, tick)
		_track_server_contacts()
		_track_server_ball()
		_track_server_course()
		if elapsed % 30 == 0:
			for child in _players.get_children():
				var body := child as Node3D
				var peer_id := 0 if body == null else int(body.name)
				# queue_free keeps a departed peer's body visible until the end of the
				# frame. Never target that stale body after ENet has removed its peer.
				if body != null and multiplayer.get_peers().has(peer_id):
					_receive_authority_probe.rpc_id(peer_id, tick, peer_id, body.position)
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
				_log("CLIENT_TICK tick=%d id=%d players=%d world=%s pos=(%.3f,%.3f) speed=%.3f map=%d cloak=%d shield=%d" % [elapsed, multiplayer.get_unique_id(), _players.get_child_count(), _client_world_positions(), local.position.x, local.position.z, local.speed(), int(local.get("map_id")), 1 if bool(local.get("is_cloaked")) else 0, 1 if bool(local.get("shield_up")) else 0])
	if _quit_after_ticks > 0 and elapsed >= _quit_after_ticks:
		if multiplayer.is_server():
			_log("RESULT players=%d minpair=%.3f contact=%d escapes=%d bumps=%d ballmax=%.3f maxy=%.3f landed=%d grounded=%d rebound=%.3f tilt=%.3f maxtilt=%.3f minx=%.3f cloaked=%d shields=%d boosting=%d tractorgrabs=%d tractorticks=%d shots=%d hits=%d ballhits=%d droneshots=%d dets=%d impacthits=%d shieldhits=%d impactmax=%.3f rcshots=%d rcdets=%d rchits=%d coursemaps=%d courseoff=%d gatetransitions=%d" % [_players.get_child_count(), _minimum_pair_distance, 1 if _contact_seen else 0, _server_escape_count(), _server_bump_count(), _maximum_ball_speed, _maximum_player_y, 1 if _course_landed else 0, 1 if _course_ground_landed else 0, _course_rebound_speed, _course_landing_tilt, _maximum_player_tilt, _minimum_player_x, _server_cloaked_count(), _server_shield_count(), _server_boosting_count(), _server_tractor_grabs(), _server_tractor_ticks(), _combat_shot_count, _combat_hit_count, _combat_ball_hit_count, _drone_shot_count, _det_nullification_count, _server_impact_hits(), _server_shield_hits(), _maximum_impact_speed, _rc_shot_count, _rc_detonation_count, _rc_hit_count, _server_course_map_count(), _server_course_off_count(), _server_gate_transition_count()])
		get_tree().quit()

## RC orbs are an event-driven, server-authored object family: only a small
## position/velocity record exists on the server, and presentation receives
## spawn/end events plus lightweight snapshots. They deliberately are not
## rollback rigid bodies; a player may only have one, so the cost remains
## bounded as the arena gains ordinary physics objects.
func _service_rc_orbs(delta: float, tick: int) -> void:
	for player_node in _players.get_children():
		var pilot := player_node as RigidBody3D
		if pilot == null:
			continue
		var input := pilot.get_node_or_null("Input")
		var pilot_id := int(pilot.name)
		var fire_held := input != null and bool(input.get("rc_fire_held")) \
			and not bool(input.get("editing")) and not bool(pilot.get("is_cloaked"))
		if fire_held and not bool(_rc_fire_prev.get(pilot_id, false)) \
			and not _server_rc_orbs.has(pilot_id):
			_spawn_rc_orb(pilot_id, pilot)
		_rc_fire_prev[pilot_id] = fire_held

	for pilot_id_value in _server_rc_orbs.keys():
		var pilot_id := int(pilot_id_value)
		var orb: Dictionary = _server_rc_orbs[pilot_id]
		var pilot := _players.get_node_or_null(str(pilot_id)) as RigidBody3D
		if pilot == null:
			_end_rc_orb(pilot_id, false, "pilot_left", tick)
			continue
		var input := pilot.get_node_or_null("Input")
		var detonate := input != null and bool(input.get("rc_detonate_held"))
		var detonate_previous := bool(orb.get("detonate_previous", false))
		if detonate and not detonate_previous:
			_end_rc_orb(pilot_id, true, "manual", tick)
			continue
		orb["detonate_previous"] = detonate
		var position: Vector3 = orb["position"]
		var velocity: Vector3 = orb["velocity"]
		var cursor_offset: Vector2 = input.get("cursor_offset") if input != null else Vector2.ZERO
		# The cursor is a steering ray from the parked Jeep, not an RC waypoint.
		# Using the orb-to-cursor distance here made it brake at the line and turn
		# back toward it. Keep its full motor speed so it can cross the arena and
		# only end through detonation, a collision, or its fuse.
		var steer := Vector3(cursor_offset.x, 0.0, cursor_offset.y)
		var heading := Vector3(velocity.x, 0.0, velocity.z).normalized()
		if heading.is_zero_approx():
			heading = pilot.get("aim") as Vector3
		if heading.is_zero_approx():
			heading = -pilot.global_basis.z
		if not steer.is_zero_approx():
			var bearing := heading.signed_angle_to(steer.normalized(), Vector3.UP)
			heading = heading.rotated(Vector3.UP,
				clampf(bearing, -RC_ORB_TURN * delta, RC_ORB_TURN * delta)).normalized()
		velocity = velocity.move_toward(heading * RC_ORB_SPEED, RC_ORB_ACCEL * delta)
		var finish := position + velocity * delta
		var wall_query := PhysicsRayQueryParameters3D.create(position, finish, 1)
		wall_query.exclude = _combat_dynamic_rids()
		if not get_world_3d().direct_space_state.intersect_ray(wall_query).is_empty():
			orb["position"] = finish
			_end_rc_orb(pilot_id, true, "wall", tick)
			continue
		var hit_player: RigidBody3D
		for candidate_node in _players.get_children():
			var candidate := candidate_node as RigidBody3D
			if candidate == null or candidate == pilot:
				continue
			if IMPACT_CONTROLLER.segment_sphere_entry(position, finish, candidate.global_position,
					PLAYER_RADIUS + RC_ORB_RADIUS) <= 1.0:
				hit_player = candidate
				break
		orb["position"] = finish
		orb["velocity"] = velocity
		orb["age"] = float(orb["age"]) + delta
		if hit_player != null:
			_end_rc_orb(pilot_id, true, "ram", tick)
		elif float(orb["age"]) >= RC_ORB_LIFETIME:
			_end_rc_orb(pilot_id, true, "fuse", tick)
		else:
			_server_rc_orbs[pilot_id] = orb
			_sync_rc_orb.rpc(pilot_id, finish, velocity, RC_ORB_LIFETIME - float(orb["age"]))

func _spawn_rc_orb(pilot_id: int, pilot: RigidBody3D) -> void:
	var heading: Vector3 = pilot.get("aim")
	if heading.is_zero_approx():
		heading = -pilot.global_basis.z
	heading.y = 0.0
	heading = heading.normalized()
	# Start at the Jeep's nose rather than outside its collision envelope; the
	# pilot is excluded from the RC collision sweep, so this stays safe.
	var origin := pilot.global_position + heading * RC_ORB_LAUNCH_OFFSET
	_server_rc_orbs[pilot_id] = {"position": origin, "velocity": heading * RC_ORB_SPEED,
		"age": 0.0, "detonate_previous": false}
	_set_rc_pilot_active.rpc(pilot_id, true)
	_rc_shot_count += 1
	_log("RCSPAWN tick=%d shooter=%d" % [NetworkTime.tick, pilot_id])
	_spawn_rc_orb_visual.rpc(pilot_id, origin, RC_ORB_LIFETIME)

func _end_rc_orb(pilot_id: int, detonate: bool, reason: String, tick: int) -> void:
	var orb: Dictionary = _server_rc_orbs.get(pilot_id, {})
	if orb.is_empty():
		return
	var position: Vector3 = orb["position"]
	_server_rc_orbs.erase(pilot_id)
	_set_rc_pilot_active.rpc(pilot_id, false)
	if detonate:
		_rc_detonation_count += 1
		_apply_rc_blast(pilot_id, position)
		_register_world_impact.rpc(-100000 - pilot_id - tick, position, Vector3.UP)
	_log("RCDET tick=%d shooter=%d reason=%s" % [tick, pilot_id, reason])
	_end_rc_orb_visual.rpc(pilot_id)

func _apply_rc_blast(pilot_id: int, position: Vector3) -> void:
	for player_node in _players.get_children():
		var target := player_node as RigidBody3D
		if target == null or int(target.name) == pilot_id:
			continue
		var away := target.global_position - position
		away.y = 0.0
		var distance := away.length()
		if distance > RC_ORB_BLAST_RADIUS + PLAYER_RADIUS:
			continue
		var strength := clampf(1.0 - distance / (RC_ORB_BLAST_RADIUS + PLAYER_RADIUS), 0.25, 1.0)
		var response := IMPACT_CONTROLLER.response(away.normalized(), bool(target.get("shield_up")))
		target.call("apply_external_impact", (response["linear_impulse"] as Vector3) * strength,
			(response["torque_impulse"] as Vector3) * strength, response["recovery_time"],
			bool(target.get("shield_up")))
		_rc_hit_count += 1

@rpc("authority", "call_local", "reliable")
func _spawn_rc_orb_visual(pilot_id: int, position: Vector3, remaining_life: float) -> void:
	if _is_headless():
		return
	var visual := Node3D.new()
	visual.name = "RcOrb_%d" % pilot_id
	visual.set_script(RC_ORB_VISUAL_SCRIPT)
	_combat_bolts.add_child(visual)
	visual.call("setup", position, remaining_life)
	_rc_orb_visuals[pilot_id] = visual

# Offline Web has no remote peer, so the authoritative snapshot must also
# update the local presentation. Native peers still receive the same cheap
# unreliable snapshot over the network.
@rpc("authority", "call_local", "unreliable")
func _sync_rc_orb(pilot_id: int, position: Vector3, _velocity: Vector3, remaining_life: float) -> void:
	var visual: Variant = _rc_orb_visuals.get(pilot_id)
	if is_instance_valid(visual):
		(visual as Node).call("update_state", position, remaining_life)

@rpc("authority", "call_local", "reliable")
func _end_rc_orb_visual(pilot_id: int) -> void:
	var visual: Variant = _rc_orb_visuals.get(pilot_id)
	if is_instance_valid(visual):
		(visual as Node).queue_free()
	_rc_orb_visuals.erase(pilot_id)

@rpc("authority", "call_local", "reliable")
func _set_rc_pilot_active(pilot_id: int, active: bool) -> void:
	var pilot := _players.get_node_or_null(str(pilot_id))
	if pilot != null:
		pilot.call("set_rc_pilot_active", active)

func _service_auto_combat(delta: float, tick: int) -> void:
	_step_server_bolts(delta)
	_service_homing_missiles(tick)
	_service_shield_drone(tick)
	for player_node in _players.get_children():
		var body := player_node as RigidBody3D
		if body == null or int(body.get("map_id")) != MAP_LAYOUT.ARENA:
			continue
		if _server_driver_enabled and int(body.name) == 1:
			continue
		var input := body.get_node_or_null("Input")
		if input == null or bool(input.get("editing")) or bool(body.get("is_cloaked")) \
				or bool(body.get("area_weapon_armed")) or bool(body.get("rc_pilot_active")):
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

func _service_area_weapons() -> void:
	for player_node in _players.get_children():
		var body := player_node as RigidBody3D
		if body == null:
			continue
		var owner_id := int(body.name)
		var serial := int(body.get("area_strike_serial"))
		var seen := int(_area_strike_serial_seen.get(owner_id, 0))
		if serial <= seen:
			continue
		_area_strike_serial_seen[owner_id] = serial
		var layout := AREA_WEAPON.layout(body.global_position,
			body.get("area_gesture_start"), body.get("area_gesture_end"))
		var strike := Node.new()
		strike.name = "AreaStrike_%d_%d" % [owner_id, serial]
		strike.set_script(AREA_STRIKE_SCRIPT)
		_area_strikes.add_child(strike)
		strike.call("configure", owner_id, layout["impacts"], float(layout["radius"]))
		_present_area_strike.rpc(body.global_position, layout)

func resolve_area_bomb(owner_id: int, position: Vector3, radius: float, tick: int) -> void:
	_apply_area_targets(owner_id, position, radius, tick, true)
	var burn := Node3D.new()
	burn.name = "AreaBurn_%d" % _next_bolt_id
	burn.set_script(AREA_BURN_ZONE_SCRIPT)
	_area_burns.add_child(burn)
	burn.call("configure", owner_id, position, radius)
	_present_area_burn.rpc(position, radius)
	_register_world_impact.rpc(_next_bolt_id, position, Vector3.UP)
	_next_bolt_id += 1

func apply_area_burn(owner_id: int, position: Vector3, radius: float, tick: int) -> void:
	_apply_area_targets(owner_id, position, radius, tick, false)

func _apply_area_targets(owner_id: int, position: Vector3, radius: float, tick: int,
		impact: bool) -> void:
	for target_node in _targets.get_children():
		var target := target_node as StaticBody3D
		if target != null and _planar_distance(position, target.global_position) <= radius + COMBAT_TARGET_RADIUS:
			_register_target_hit.rpc(int(target.get("target_id")))
	for player_node in _players.get_children():
		var player := player_node as RigidBody3D
		if player == null or int(player.name) == owner_id:
			continue
		if _planar_distance(position, player.global_position) > radius + PLAYER_RADIUS:
			continue
		var direction := player.global_position - position
		direction.y = 0.0
		direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
		var shielded := bool(player.get("shield_up"))
		var response := IMPACT_CONTROLLER.response(direction, shielded)
		var strength := 1.5 if impact else 0.24
		player.call("apply_external_impact", response["linear_impulse"] * strength,
			response["torque_impulse"] * strength, float(response["recovery_time"]) * strength, shielded)
		if impact:
			_register_player_impact.rpc(_next_bolt_id, int(player.name), position, direction, shielded)

func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _service_homing_missiles(_tick: int) -> void:
	for player_node in _players.get_children():
		var body := player_node as RigidBody3D
		if body == null:
			continue
		var input := body.get_node_or_null("Input")
		var owner_id := int(body.name)
		var held := input != null and bool(input.get("homing_held")) and not bool(input.get("editing"))
		var was_held := bool(_homing_held_last.get(owner_id, false))
		_homing_held_last[owner_id] = held
		if held and not was_held:
			_fire_homing_missile(body)

func _fire_homing_missile(body: RigidBody3D) -> void:
	var target := _nearest_homing_target(body)
	# Match G2: target acquisition is optional. With no opponent the seeker is
	# still a visible straight shot rather than a swallowed key press.
	var aim_point: Vector3 = body.global_position + body.aim
	if target != null:
		aim_point = target.global_position
	var origin := _combat_muzzle_origin(body, aim_point)
	# Preserve G2's dodge model: the player launches along their aim, then the
	# locked target can only pull the missile through its capped cone.
	var direction := Vector3(body.aim.x, 0.0, body.aim.z).normalized()
	if direction.is_zero_approx():
		direction = (target.global_position - origin).normalized()
	var velocity := direction * HOMING_MISSILE.SPEED
	var bolt_id := _next_bolt_id
	_next_bolt_id += 1
	_server_bolts[bolt_id] = {"position": origin, "velocity": velocity, "age": 0.0,
		"shooter": int(body.name), "zone": -1, "kind": BOLT_KIND_HOMING,
		"target_id": _homing_target_id(target)}
	_combat_shot_count += 1
	_spawn_combat_bolt.rpc(bolt_id, int(body.name), -1, origin, velocity,
		BOLT_KIND_HOMING, _homing_target_id(target))

func _nearest_homing_target(shooter: RigidBody3D) -> Node3D:
	var selected: Node3D
	var best_distance := HOMING_MISSILE.ACQUIRE_RANGE * HOMING_MISSILE.ACQUIRE_RANGE
	for target_node in _targets.get_children():
		var candidate := target_node as StaticBody3D
		if candidate == null:
			continue
		var distance := shooter.global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			selected = candidate
			best_distance = distance
	for index in range(_balls.get_child_count()):
		var candidate := _balls.get_child(index) as RigidBody3D
		if candidate == null:
			continue
		var distance := shooter.global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			selected = candidate
			best_distance = distance
	return selected

func _homing_target_id(target: Node3D) -> int:
	if target == null:
		return -1
	if target.is_in_group("arena_ball"):
		return BALL_TARGET_ID_BASE - target.get_index()
	return int(target.get("target_id"))

func homing_target_for(target_id: int) -> Node3D:
	if target_id >= 0:
		return _targets.get_node_or_null("Target_%02d" % target_id) as Node3D
	var ball_index := BALL_TARGET_ID_BASE - target_id
	return _balls.get_child(ball_index) as Node3D if ball_index >= 0 \
		and ball_index < _balls.get_child_count() else null

func _acquire_target(body: RigidBody3D, zone: int, reach: float, width: float,
		tip_outward: bool) -> Node3D:
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
	for index in range(_balls.get_child_count()):
		var ball := _balls.get_child(index) as RigidBody3D
		if ball == null:
			continue
		var target_id := BALL_TARGET_ID_BASE - index
		var local := COVERAGE.local_point(ball.global_position, body.global_transform)
		candidates.append({"id": target_id, "local_position": local,
			"visible": _has_target_line_of_sight(body, ball)})
		by_id[target_id] = ball
	var selected := AUTO_TARGETING.select_nearest(zone, reach, width, tip_outward, candidates)
	return by_id.get(selected) as Node3D

func _has_target_line_of_sight(body: RigidBody3D, target: Node3D) -> bool:
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

func _fire_combat_bolt(body: RigidBody3D, target: Node3D, zone: int) -> void:
	var origin := _combat_muzzle_origin(body, target.global_position)
	var velocity := (target.global_position - origin).normalized() * COMBAT_BOLT_SPEED
	var bolt_id := _next_bolt_id
	_next_bolt_id += 1
	_server_bolts[bolt_id] = {"position": origin, "velocity": velocity,
		"age": 0.0, "shooter": int(body.name), "zone": zone,
		"kind": BOLT_KIND_PLAYER}
	_combat_shot_count += 1
	_spawn_combat_bolt.rpc(bolt_id, int(body.name), zone, origin, velocity,
		BOLT_KIND_PLAYER)

func _service_shield_drone(tick: int) -> void:
	if not _drone_enabled or _shield_drone == null or tick - _start_tick < SHIELD_DRONE_SCRIPT.ARM_TICKS:
		return
	if tick - _drone_last_fire_tick < SHIELD_DRONE_SCRIPT.FIRE_INTERVAL_TICKS:
		return
	var target := _nearest_drone_target()
	if target == null:
		return
	var origin: Vector3 = _shield_drone.call("muzzle_position")
	var target_position: Vector3 = target.global_position
	var target_velocity: Vector3 = target.linear_velocity
	target_velocity.y = 0.0
	var lead_time := clampf(origin.distance_to(target_position)
		/ SHIELD_DRONE_SCRIPT.BOLT_SPEED, 0.0, 0.75)
	var aim_point := target_position + target_velocity * lead_time
	var direction := (aim_point - origin).normalized()
	if direction.is_zero_approx():
		return
	var bolt_id := _next_bolt_id
	_next_bolt_id += 1
	var velocity := direction * SHIELD_DRONE_SCRIPT.BOLT_SPEED
	_server_bolts[bolt_id] = {"position": origin, "velocity": velocity,
		"age": 0.0, "shooter": 0, "zone": -1, "kind": BOLT_KIND_DRONE}
	_drone_last_fire_tick = tick
	_drone_shot_count += 1
	_spawn_combat_bolt.rpc(bolt_id, 0, -1, origin, velocity, BOLT_KIND_DRONE)

func _nearest_drone_target() -> RigidBody3D:
	var best: RigidBody3D
	var best_distance := INF
	var origin: Vector3 = _shield_drone.call("muzzle_position")
	for player_node in _players.get_children():
		var body := player_node as RigidBody3D
		if body == null or int(body.get("map_id")) != MAP_LAYOUT.ARENA \
				or bool(body.get("is_cloaked")) or bool(body.get("rc_pilot_active")):
			continue
		var input := body.get_node_or_null("Input")
		if input == null or bool(input.get("editing")):
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, body.global_position, 1)
		query.exclude = _combat_dynamic_rids()
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var distance := origin.distance_squared_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

func _step_server_bolts(delta: float) -> void:
	for bolt_id_value in _server_bolts.keys():
		var bolt_id := int(bolt_id_value)
		var bolt: Dictionary = _server_bolts[bolt_id]
		var start: Vector3 = bolt["position"]
		var kind := int(bolt.get("kind", BOLT_KIND_PLAYER))
		if kind == BOLT_KIND_HOMING:
			var target := homing_target_for(int(bolt.get("target_id", -1)))
			if target != null:
				bolt["velocity"] = HOMING_MISSILE.steer(bolt["velocity"], start, target.global_position, delta)
		var finish := start + (bolt["velocity"] as Vector3) * delta
		var segment := finish - start
		var wall_fraction := 1.01
		var wall_position := finish
		var wall_query := PhysicsRayQueryParameters3D.create(start, finish, 1)
		wall_query.exclude = _combat_dynamic_rids()
		var wall_hit := get_world_3d().direct_space_state.intersect_ray(wall_query)
		if not wall_hit.is_empty() and segment.length_squared() > 0.0001:
			wall_fraction = start.distance_to(wall_hit["position"]) / segment.length()
			wall_position = wall_hit["position"]
		var detonator: RigidBody3D
		var det_fraction := 1.01
		for player_node in _players.get_children():
			var candidate := player_node as RigidBody3D
			if candidate == null or int(candidate.name) == int(bolt["shooter"]):
				continue # A defensive det field never eats its owner's shots.
			var input := candidate.get_node_or_null("Input")
			if input != null and bool(input.get("editing")):
				continue
			var radius := float(candidate.call("det_radius"))
			if radius <= 0.0:
				continue
			var fraction := IMPACT_CONTROLLER.segment_sphere_entry(start, finish,
				candidate.global_position, radius)
			if fraction < det_fraction:
				det_fraction = fraction
				detonator = candidate
		if detonator != null and det_fraction <= wall_fraction:
			var det_position := start + segment * det_fraction
			_det_nullification_count += 1
			_register_det_nullification.rpc(bolt_id, int(detonator.name), det_position)
			_end_combat_bolt.rpc(bolt_id)
			_server_bolts.erase(bolt_id)
			continue
		if kind == BOLT_KIND_DRONE:
			var player_hit: RigidBody3D
			var player_fraction := 1.01
			for player_node in _players.get_children():
				var player := player_node as RigidBody3D
				if player == null:
					continue
				var input := player.get_node_or_null("Input")
				if input != null and bool(input.get("editing")):
					continue
				var fraction := IMPACT_CONTROLLER.segment_sphere_entry(start, finish,
					player.global_position, PLAYER_RADIUS)
				if fraction < player_fraction:
					player_fraction = fraction
					player_hit = player
			if player_hit != null and player_fraction <= wall_fraction:
				var impact_position := start + segment * player_fraction
				var incoming_direction: Vector3 = (bolt["velocity"] as Vector3).normalized()
				var shielded := bool(player_hit.get("shield_up"))
				var response := IMPACT_CONTROLLER.response(incoming_direction, shielded)
				player_hit.call("apply_external_impact", response["linear_impulse"],
					response["torque_impulse"], response["recovery_time"], shielded)
				_register_player_impact.rpc(bolt_id, int(player_hit.name), impact_position,
					incoming_direction, shielded)
				_end_combat_bolt.rpc(bolt_id)
				_server_bolts.erase(bolt_id)
				continue
			if wall_fraction <= 1.0:
				_register_world_impact.rpc(bolt_id, wall_position,
					(bolt["velocity"] as Vector3).normalized())
				_end_combat_bolt.rpc(bolt_id)
				_server_bolts.erase(bolt_id)
				continue
		elif kind == BOLT_KIND_HOMING:
			var target_hit: Node3D
			var target_fraction := 1.01
			for target_node in _targets.get_children():
				var target := target_node as StaticBody3D
				if target == null or segment.length_squared() <= 0.0001:
					continue
				var fraction := clampf((target.global_position - start).dot(segment) \
					/ segment.length_squared(), 0.0, 1.0)
				if (start + segment * fraction).distance_to(target.global_position) <= COMBAT_TARGET_RADIUS \
						and fraction < target_fraction:
					target_hit = target
					target_fraction = fraction
			for ball_node in _balls.get_children():
				var ball := ball_node as RigidBody3D
				if ball == null or segment.length_squared() <= 0.0001:
					continue
				var fraction := clampf((ball.global_position - start).dot(segment) \
					/ segment.length_squared(), 0.0, 1.0)
				if (start + segment * fraction).distance_to(ball.global_position) <= BALL_SCRIPT.RADIUS \
						and fraction < target_fraction:
					target_hit = ball
					target_fraction = fraction
			if target_hit != null and target_fraction <= wall_fraction:
				_combat_hit_count += 1
				if target_hit.is_in_group("arena_ball"):
					target_hit.call("apply_external_impulse",
						(bolt["velocity"] as Vector3).normalized() * COMBAT_BALL_IMPULSE)
					_combat_ball_hit_count += 1
				else:
					_register_target_hit.rpc(int(target_hit.get("target_id")))
				_end_combat_bolt.rpc(bolt_id)
				_server_bolts.erase(bolt_id)
				continue
			if wall_fraction <= 1.0:
				_register_world_impact.rpc(bolt_id, wall_position,
					(bolt["velocity"] as Vector3).normalized())
				_end_combat_bolt.rpc(bolt_id)
				_server_bolts.erase(bolt_id)
				continue
		else:
			var target_hit: Node3D
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
			for ball_node in _balls.get_children():
				var ball := ball_node as RigidBody3D
				if ball == null or segment.length_squared() <= 0.0001:
					continue
				var fraction := clampf((ball.global_position - start).dot(segment) \
					/ segment.length_squared(), 0.0, 1.0)
				var closest := start + segment * fraction
				if closest.distance_to(ball.global_position) <= BALL_SCRIPT.RADIUS \
						and fraction < target_fraction:
					target_hit = ball
					target_fraction = fraction
			if target_hit != null and target_fraction <= wall_fraction:
				_combat_hit_count += 1
				if target_hit.is_in_group("arena_ball"):
					var hit_direction: Vector3 = (bolt["velocity"] as Vector3).normalized()
					target_hit.call("apply_external_impulse", hit_direction * COMBAT_BALL_IMPULSE)
					_combat_ball_hit_count += 1
				else:
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
		var lifetime: float = SHIELD_DRONE_SCRIPT.BOLT_LIFETIME if kind == BOLT_KIND_DRONE \
			else HOMING_MISSILE.LIFETIME if kind == BOLT_KIND_HOMING else COMBAT_BOLT_LIFETIME
		if float(bolt["age"]) >= lifetime:
			_end_combat_bolt.rpc(bolt_id)
			_server_bolts.erase(bolt_id)
		else:
			_server_bolts[bolt_id] = bolt

@rpc("authority", "call_local", "reliable")
func _spawn_combat_bolt(bolt_id: int, shooter_id: int, zone: int,
		origin: Vector3, velocity: Vector3, kind: int, target_id: int = -1) -> void:
	if not _is_headless():
		var visual := Node3D.new()
		visual.name = "Missile_%d" % bolt_id if kind == BOLT_KIND_HOMING else "Bolt_%d" % bolt_id
		visual.set_script(HOMING_MISSILE_VISUAL_SCRIPT
			if kind == BOLT_KIND_HOMING else BOLT_VISUAL_SCRIPT)
		_combat_bolts.add_child(visual)
		if kind == BOLT_KIND_HOMING:
			visual.call("setup", origin, velocity, target_id)
		else:
			var color: Color = SHIELD_DRONE_SCRIPT.BOLT_COLOR \
				if kind == BOLT_KIND_DRONE else COVERAGE.ZONE_COLORS[zone]
			visual.call("setup", bolt_id, origin, velocity, color, kind == BOLT_KIND_DRONE)
		_bolt_visuals[bolt_id] = visual
	var local := local_player() as Node3D
	if kind == BOLT_KIND_PLAYER and local != null and int(local.name) == shooter_id:
		var coverage_visual := local.get_node_or_null("CoverageDebug")
		if coverage_visual != null:
			coverage_visual.call("flash_zone", zone)

@rpc("authority", "call_local", "reliable")
func _present_area_strike(origin: Vector3, layout: Dictionary) -> void:
	if _is_headless():
		return
	var visual := Node3D.new()
	visual.name = "AreaStrikeVisual"
	visual.set_script(AREA_STRIKE_VISUAL_SCRIPT)
	_area_strikes.add_child(visual)
	visual.call("configure", origin, layout)

@rpc("authority", "call_local", "reliable")
func _present_area_burn(position: Vector3, radius: float) -> void:
	if _is_headless():
		return
	var visual := MeshInstance3D.new()
	visual.name = "AreaBurnVisual"
	visual.set_script(AREA_BURN_VISUAL_SCRIPT)
	_area_burns.add_child(visual)
	visual.call("configure", position, radius)

@rpc("authority", "call_local", "reliable")
func _end_combat_bolt(bolt_id: int) -> void:
	# Reliable end events may overlap prediction cleanup. Keep the dictionary
	# lookup untyped so a previously freed Object can be rejected safely.
	var visual: Variant = _bolt_visuals.get(bolt_id)
	if is_instance_valid(visual):
		(visual as Node).queue_free()
	_bolt_visuals.erase(bolt_id)

@rpc("authority", "call_local", "reliable")
func _register_det_nullification(bolt_id: int, owner_id: int, contact: Vector3) -> void:
	var owner := _players.get_node_or_null(str(owner_id))
	if owner != null:
		var bubble := owner.get_node_or_null("DetBubble")
		if bubble != null:
			bubble.call("register_nullification", bolt_id, contact)

@rpc("authority", "call_local", "reliable")
func _register_player_impact(bolt_id: int, target_id: int, impact_position: Vector3,
		incoming_direction: Vector3, shielded: bool) -> void:
	_show_player_impact(bolt_id, target_id, impact_position, incoming_direction, shielded)

func predict_drone_impact_visual(bolt_id: int, target_id: int, impact_position: Vector3,
		incoming_direction: Vector3) -> void:
	var target := _players.get_node_or_null(str(target_id))
	if target == null:
		return
	_show_player_impact(bolt_id, target_id, impact_position, incoming_direction,
		bool(target.get("shield_up")))

func _show_player_impact(bolt_id: int, target_id: int, impact_position: Vector3,
		incoming_direction: Vector3, shielded: bool) -> void:
	if _impact_fx != null:
		_impact_fx.call("burst", bolt_id, impact_position, incoming_direction, shielded)
	var target := _players.get_node_or_null(str(target_id))
	if shielded and target != null:
		var shield_visual := target.get_node_or_null("VehicleShield")
		if shield_visual != null:
			shield_visual.call("register_impact", bolt_id, impact_position, incoming_direction)

@rpc("authority", "call_local", "reliable")
func _register_world_impact(bolt_id: int, impact_position: Vector3,
		incoming_direction: Vector3) -> void:
	if _impact_fx != null:
		_impact_fx.call("burst", bolt_id, impact_position, incoming_direction, false)

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

func _server_cloaked_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += 1 if bool(child.get("is_cloaked")) else 0
	return total

func _server_shield_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += 1 if bool(child.get("shield_up")) else 0
	return total

func _server_impact_hits() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("impact_hit_count"))
	return total

func _server_shield_hits() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("shield_hit_count"))
	return total

func _server_boosting_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += 1 if bool(child.get("boost_active")) else 0
	return total

func _server_course_map_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += 1 if int(child.get("map_id")) == MAP_LAYOUT.DRIVING_COURSE else 0
	return total

func _server_course_off_count() -> int:
	var total := 0
	for child in _players.get_children():
		if int(child.get("map_id")) == MAP_LAYOUT.DRIVING_COURSE \
				and DRIVING_COURSE_SCRIPT.off_track(child.global_position):
			total += 1
	return total

func _server_gate_transition_count() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("gate_transition_count"))
	return total

func _server_tractor_grabs() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("tractor_grab_count"))
	return total

func _server_tractor_ticks() -> int:
	var total := 0
	for child in _players.get_children():
		total += int(child.get("tractor_reel_ticks"))
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
	var active_grass_contacts := {}
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
				var contact_key := "%s:%s" % [a.name, b.name]
				active_grass_contacts[contact_key] = true
				if not _grass_contacts.has(contact_key):
					var impact_speed := (a.linear_velocity - b.linear_velocity).length()
					if impact_speed >= 2.0:
						_broadcast_grass_impact((a.global_position + b.global_position) * 0.5,
							clampf(impact_speed * 0.24, 3.0, 6.0))
				if not _contact_seen:
					_log("CONTACT a=%s b=%s" % [a.name, b.name])
				_contact_seen = true
	_grass_contacts = active_grass_contacts

func _broadcast_grass_impact(world_position: Vector3, radius: float) -> void:
	_play_grass_impact.rpc(world_position, radius)

@rpc("authority", "call_remote", "unreliable")
func _play_grass_impact(world_position: Vector3, radius: float) -> void:
	get_tree().call_group("interactive_grass", "trigger_impact_ripple", world_position, radius)

func _sample_impact_motion() -> void:
	if _players == null:
		return
	for player_node in _players.get_children():
		var body := player_node as RigidBody3D
		if body == null or int(body.get("impact_hit_count")) <= 0:
			continue
		_maximum_impact_speed = maxf(_maximum_impact_speed,
			Vector2(body.linear_velocity.x, body.linear_velocity.z).length())

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
