extends Node3D
## Small, auditable game shell: ENet lifecycle and spawn authority live here;
## player scripts own deterministic FOLLOW simulation and presentation.

const DEFAULT_PORT := 10080
const DEFAULT_SIGNAL_PORT := 10181
const MAX_CLIENTS := 16
const WORLD_CONFIG := preload("res://world/world_config.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const FOLLOW := preload("res://player/follow_controller.gd")
const PLAYER_RADIUS := VEHICLE_CONFIG.COLLISION_RADIUS
const SERVER_DRIVER_COLLISION := preload("res://player/server_driver_collision.gd")
const CORRECTION_CLASSIFIER := preload("res://player/correction_classifier.gd")
const PLAYER_SCRIPT := preload("res://player/player_body.gd")
const INPUT_SCRIPT := preload("res://player/player_input.gd")
const HULL_SCRIPT := preload("res://player/ground_vehicle_hull.gd")
const DRIFT_GUIDE_SCRIPT := preload("res://player/drift_guide.gd")
const TRACTOR_CONTROLLER := preload("res://player/tractor_controller.gd")
const IMPACT_CONTROLLER := preload("res://player/impact_controller.gd")
const BOOST_VELOCITY_BLUR_SCRIPT := preload("res://fx/boost_velocity_blur.gd")
const CONTROLLER_INPUT := preload("res://player/controller_input.gd")
const DRIVE_CURSOR_VISUAL := preload("res://player/drive_cursor_visual.gd")
const SPEED_CAMERA_SCRIPT := preload("res://fx/speed_camera.gd")
const OFFSCREEN_INDICATORS_SCRIPT := preload("res://ui/offscreen_indicators.gd")
const LIGHTING_EDITOR_SCRIPT := preload("res://ui/lighting_editor.gd")
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
const CITY_PRESENTATION_SCRIPT := preload("res://world/city_audition.gd")
const CITY_LAYOUT := preload("res://world/city_layout.gd")
const BALL_SCRIPT := preload("res://world/city_ball.gd")
const MAP_LAYOUT := preload("res://world/map_layout.gd")
const HOME_HALF := MAP_LAYOUT.CITY_HALF_EXTENT
const GROUND_BODY_Y := PLAYER_RADIUS + 0.04
const DOTS_SCRIPT := preload("res://world/dots.gd")
const TROOP_DELIVERY_SCRIPT := preload("res://world/troop_delivery.gd")
const OIL_SLICK := preload("res://world/oil_slick.gd")
const OIL_SLICKS_SCRIPT := preload("res://world/oil_slicks.gd")
const OVERCAST_HDRI_PATH := "res://assets/environment/kloofendal_overcast_puresky_2k.hdr"
const CRASH_TELEMETRY_SCRIPT := preload("res://diagnostics/crash_telemetry.gd")
const MOTION_TRACE_SCRIPT := preload("res://diagnostics/motion_trace.gd")
const SERVER_RESULT := preload("res://diagnostics/server_result.gd")
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
const SERVER_DRIVER_SPAWN := Vector2(-52.0, -63.0)
const SERVER_DRIVER_ROUTE := [
	Vector2(-52.0, -63.0), Vector2(52.0, -63.0),
	Vector2(63.0, -52.0), Vector2(63.0, 52.0),
	Vector2(52.0, 63.0), Vector2(-52.0, 63.0),
	Vector2(-63.0, 52.0), Vector2(-63.0, -52.0),
]
const SERVER_DRIVER_LANE_SPAWN := Vector2(0.0, -52.0)
const SERVER_DRIVER_LANE_ROUTE := [Vector2(0.0, -52.0), Vector2(0.0, 52.0)]
## Networking-1 interactive observer: clear of the slow lane, city ball, and
## walls so a no-contact/stall observation starts
## with no uncontrolled collision variable.
const SERVER_DRIVER_LANE_OBSERVER_SPAWN := Vector2(22.0, 0.0)
const SERVER_DRIVER_OBSERVER_SPACING := 12.0
## Networking-2 moving-observer lanes start near the enlarged west wall and
## stay clear of the slow fixture, city gate, buildings, and outer targets.
const NETWORK_TEST_OBSERVER_SPAWN := Vector2(-220.0, 40.0)
const SERVER_DRIVER_LANE_CURSOR_DISTANCE := 7.35
const SERVER_DRIVER_WAYPOINT_RADIUS := 5.0
const SERVER_DRIVER_PROGRESS_DISTANCE := 2.0
const SERVER_DRIVER_STUCK_TICKS := 180
const SERVER_DRIVER_HOME_LIMIT := HOME_HALF + 4.0
const NETWORK_TEST_HOME_HALF := 240.0
const CORRECTION_REPORT_FLOOR := 0.10
const AUTHORITY_PROBE_SEND_DELAY_TICKS := 20

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
var _remote_interp_mode := "fixed"
var _remote_interp_ms := 75.0
var _remote_interp_max_ms := 150.0
var _presentation_trace_path := ""
var _presentation_trace_seconds := 0.0
var _presentation_control_path := ""
var _presentation_control_elapsed := 0.0
var _presentation_control_last_command := ""
var _network_hud_enabled := false
var _network_profile := "unshaped"
var _hotkey_hints_visible := true
var _controller_drive_active := false
var _active_controller_id := -1
var _resim_budget_ms := 0.0
var _mux_collision_test := false
var _mux_close_transport_test := ""
var _player_name := "driver"
var _session_label := ""
var _run_id := ""
var _scripted := ""
var _server_driver_enabled := false
var _server_driver_lane := false
var _player_capsule_enabled := VEHICLE_CONFIG.DEFAULT_CAPSULE_ENABLED
var _client_cruise_allowed := false
var _client_cruise_active := false
var _network_test_world_enabled := false
var _home_half := HOME_HALF
var _motion_trace_enabled := false
var _local_presentation_smoothing_enabled := false
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
var _reverse_test := false
var _drone_enabled := true
var _ball_enabled := true
var _start_tick := -1
var _next_spawn_slot := 0
var _next_remote_state_generation := 1
var _contact_seen := false
var _minimum_pair_distance := INF
var _prediction_history := {}
var _worst_correction_error := 0.0
var _last_authority_probe_tick := -1
var _authority_probe_queue: Array[Dictionary] = []
var _correction_counts := {"corr": 0, "stall": 0, "stale": 0,
	"impact": 0, "unknown": 0}
var _frame_ms_current := 0.0
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
var _speed_camera
var _shadow_light: SpotLight3D
var _sun_light: DirectionalLight3D
var _rim_light: DirectionalLight3D
var _world_environment: Environment
var _sunlit_sky: Sky
var _overcast_sky: Sky
var _status_label: Label
var _editor_label: Label
var _fps_label: Label
var _network_hud_label: Label
var _network_hud_elapsed := 0.0
var _network_hud_frames := 0
var _network_hud_frame_ms_sum := 0.0
var _network_hud_frame_ms_max := 0.0
var _network_hud_rb_ms_max := 0.0
var _network_hud_rb_ticks_max := 0
var _network_tier_label: Label
var _system_menu_bar: MenuBar
var _debug_popup: PopupMenu
var _oil_popup: PopupMenu
var _oil_submenus := {}
var _vehicle_model_popup: PopupMenu
var _scenery_popup: PopupMenu
var _lighting_editor: Node
var _vehicle_model_scales := {}
var _city_presentation: Node3D
var _lighting_style_index := 4
var _gameplay_collision_debug_enabled := false
var _gameplay_text_visible := true
const DEBUG_COLLISION_MENU_ID := 1
const DEBUG_GAMEPLAY_TEXT_MENU_ID := 2
const OIL_INSTANT_MENU_ID := 1001
const OIL_RESET_MENU_ID := 1002
const OIL_AUTOSAVE_INFO_MENU_ID := 1003
const OIL_TUNING_PATH := "user://oil_slick_tuning.cfg"
const OIL_TUNING_SECTION := "oil_slick"
const VEHICLE_MODEL_SCALE_MENU_ID_BASE := 2000
const VEHICLE_MODEL_RESET_MENU_ID := 2100
const VEHICLE_MODEL_AUTOSAVE_INFO_MENU_ID := 2101
const VEHICLE_MODEL_COLLIDER_INFO_MENU_ID := 2102
const VEHICLE_MODEL_CURRENT_INFO_MENU_ID := 2103
const LIGHTING_STYLE_MENU_ID_BASE := 3100
const SCENERY_LIGHTING_INFO_MENU_ID := 3201
const SCENERY_LIGHTING_EDITOR_MENU_ID := 3202
const LIGHTING_STYLE_NAMES := [
	"Current warm shadow",
	"G2 warm key + cool fill",
	"G2 key + fill + rim",
	"Overcast city HDRI",
	"Sunlit aerial (Intel-safe)",
]
const VEHICLE_MODEL_SCALE_OPTIONS := [
	1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0,
	3.5, 4.0, 4.5, 5.0,
]
const VEHICLE_MODEL_SCALE_PATH := "user://vehicle_model_debug.cfg"
const VEHICLE_MODEL_SCALE_SECTION := "vehicle_model"
const OIL_MENU_ORDER := [
	"duration", "min_grip_scale", "min_drift_assist_scale",
	"rear_lateral_grip", "rear_yaw_grip", "front_steer_torque",
	"yaw_damping", "max_yaw_rate",
]
const OIL_MENU_OPTIONS := {
	"duration": {"label": "Duration", "values": [1.0, 2.0, 4.0, 6.0, 8.0, 12.0]},
	"min_grip_scale": {"label": "Road grip", "values": [0.0, 0.03, 0.08, 0.15, 0.30, 0.50]},
	"min_drift_assist_scale": {"label": "Drift assist", "values": [0.0, 0.10, 0.25, 0.50, 0.75, 1.0]},
	"rear_lateral_grip": {"label": "Rear lateral grip", "values": [0.05, 0.10, 0.18, 0.35, 0.70, 1.50]},
	"rear_yaw_grip": {"label": "Rear yaw recovery", "values": [0.0, 0.08, 0.16, 0.30, 0.60, 1.20]},
	"front_steer_torque": {"label": "Steering torque", "values": [2.5, 5.0, 8.5, 12.0, 16.0, 22.0]},
	"yaw_damping": {"label": "Spin damping", "values": [0.0, 0.05, 0.10, 0.25, 0.50, 1.0]},
	"max_yaw_rate": {"label": "Maximum spin", "values": [2.5, 4.0, 6.0, 8.0, 10.0, 12.0]},
}
var _motion_trace: Node
var _network_last_target_msec := -1.0
var _network_last_mode := ""
var _network_tier_notice_remaining := 0.0
var _shader_prewarm: Node3D
var _dots: Node3D
var _troop_delivery: Node3D
var _webrtc_transport: Node
var _mux_peer
var _network_status := ""
var _join_stall_ms := 0
var _join_stall_after_ms := 0
var _join_stall_started := false
var _persisted_oil_tuning := {}
var _persisted_oil_tuning_pending := false

func _ready() -> void:
	_parse_args()
	# Licensed audition art is optional and local-only. A clean checkout keeps
	# the exact procedural baseline without warnings or missing dependencies.
	# Normal headless servers/gates do not even probe the optional FBX path.
	if not _is_headless():
		var requested_lighting_style := OS.get_environment("CAR_FIGHT_LIGHTING_STYLE")
		if requested_lighting_style.is_valid_int():
			_lighting_style_index = clampi(int(requested_lighting_style), 0,
				LIGHTING_STYLE_NAMES.size() - 1)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_load_persisted_oil_tuning()
	_load_persisted_vehicle_model_scale()
	if not _run_id.is_empty():
		_log("RUN_ID id=%s role=%s transport=%s" % [_run_id, _role, _transport])
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
	NetworkRollback.after_loop.connect(_send_settled_authority_probes)
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


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_active_controller_id = device
	elif device == _active_controller_id:
		_active_controller_id = -1
		_controller_drive_active = false

## Deterministic positive control for the late-join/render-stall regression.
## A real rendered client can pause here for shader compilation after netfox
## synchronizes. Headless gates use the otherwise-unset environment variables
## to reproduce that pause without changing ordinary client behavior.
func _inject_join_stall_for_test() -> void:
	if _role != "client" or _join_stall_started:
		return
	var stall_ms := _join_stall_ms
	if stall_ms <= 0:
		return
	_join_stall_started = true
	var after_ms := _join_stall_after_ms
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
	_frame_ms_current = _delta * 1000.0
	_poll_presentation_control(_delta)
	if _network_hud_enabled:
		_update_network_hud(_delta)
	if multiplayer.is_server():
		_sample_impact_motion()
	if _camera == null:
		return
	var local: Node3D = local_player()
	if _gameplay_collision_debug_enabled and local != null \
			and local.has_method("set_gameplay_collision_debug_visible"):
		local.call("set_gameplay_collision_debug_visible", true)
	var local_camera_position := Vector3.ZERO if local == null else local.global_position
	if local != null and _local_presentation_smoothing_enabled \
			and local.has_method("presented_position"):
		local_camera_position = local.call("presented_position")
	var target: Vector3 = Vector3.ZERO if local == null \
		else Vector3(local_camera_position.x, 0.0, local_camera_position.z)
	# The RC orb is the player's active viewpoint. Its visual is fed by the
	# authoritative lightweight projectile snapshots, so the camera follows the
	# same state every observer sees and cleanly returns to the Jeep on the
	# reliable terminal event.
	if local != null:
		var rc_visual: Variant = _rc_orb_visuals.get(int(local.name))
		if is_instance_valid(rc_visual):
			var rc_position := (rc_visual as Node3D).global_position
			target = Vector3(rc_position.x, 0.0, rc_position.z)
	var yaw := deg_to_rad(45.0)
	var pitch := deg_to_rad(55.0)
	var horizontal := cos(pitch) * 80.0
	var offset := Vector3(sin(yaw) * horizontal, sin(pitch) * 80.0, cos(yaw) * horizontal)
	var camera_target := target
	if _speed_camera != null:
		if local is RigidBody3D and not is_instance_valid(_rc_orb_visuals.get(int(local.name))):
			camera_target += _speed_camera.advance(local as RigidBody3D, _delta)
		else:
			_speed_camera.reset()
	_camera.global_position = camera_target + offset
	_camera.look_at(camera_target, Vector3.UP)
	_camera.size = 30.0 if _combat_editor_active else WORLD_CONFIG.CAMERA_SIZE
	_update_editor_presentation(local)
	if _shadow_light != null:
		_shadow_light.global_position = target + Vector3(-32.0, 40.0, 34.0)
		_shadow_light.look_at(target, Vector3.UP)
	if _status_label != null:
		_status_label.visible = _gameplay_text_visible or local == null
		var id := multiplayer.get_unique_id()
		var speed: float = 0.0 if local == null else local.speed()
		var mode := "COVERAGE EDITOR" if _combat_editor_active else "DRIVE + AUTO FIRE"
		var location := "LOW POLY CITY"
		if local != null:
			location = MAP_LAYOUT.map_name(int(local.get("map_id")))
		if not _combat_editor_active and local != null and bool(local.get("is_cloaked")):
			mode = "DRIVE + CLOAKED (AUTO FIRE OFF)"
		elif not _combat_editor_active and local != null and bool(local.get("shield_up")):
			mode = "DRIVE + SHIELDED"
		if _dots != null:
			mode = "%s  ·  dots %d (%d left)" % [mode, int(_dots.call("collected_by", id)),
				int(_dots.call("remaining"))]
		if _troop_delivery != null:
			mode = "%s  ·  troops %d carried / %d delivered" % [mode,
				int(_troop_delivery.call("carried_by", id)), int(_troop_delivery.call("delivered_by", id))]
		_status_label.text = "CAR FIGHT  |  %s  |  peer %d  |  %.1f u/s\n%s" % [
			mode, id, speed, location]
		if _hotkey_hints_visible:
			_status_label.text += "\n%s" % (
				"Drag cone handles  |  F: flip  |  R: reset  |  Enter: drive" \
				if _combat_editor_active else _drive_control_hint())
		if _client_cruise_allowed:
			_status_label.text += "\nP: %s client cruise (full speed, no burst)" % [
				"STOP" if _client_cruise_active else "START"]
		if local != null and bool(local.get("area_weapon_armed")):
			_status_label.text += "\nAREA WEAPON ARMED  ·  Hold and drag Left Mouse, then release to bomb  ·  3: stow"
		if local == null and not _network_status.is_empty():
			_status_label.text = "CAR FIGHT  |  BROWSER NETWORK\n%s\n%s" % [
				_network_status, _connection_target()]
	if _fps_label != null:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_update_editor_label()

func _parse_args() -> void:
	_drone_enabled = OS.get_environment("CAR_FIGHT_NO_DRONE") != "1"
	_ball_enabled = OS.get_environment("CAR_FIGHT_NO_BALL") != "1"
	_join_stall_ms = maxi(0, int(OS.get_environment("CAR_FIGHT_JOIN_STALL_MS")))
	_join_stall_after_ms = maxi(0,
		int(OS.get_environment("CAR_FIGHT_JOIN_STALL_AFTER_MS")))
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
			var browser_script := _web_query("script")
			if not browser_script.is_empty():
				_scripted = browser_script
			_run_id = _web_query("runId")
			var join_stall_query := _web_query("joinStallMs")
			if join_stall_query.is_valid_int():
				_join_stall_ms = maxi(0, int(join_stall_query))
			var join_stall_after_query := _web_query("joinStallAfterMs")
			if join_stall_after_query.is_valid_int():
				_join_stall_after_ms = maxi(0, int(join_stall_after_query))
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
			_network_hud_enabled = _web_query("networkHud") == "1"
			_hotkey_hints_visible = _web_query("hotkeyHints") != "0"
			_client_cruise_allowed = _web_query("clientCruise") == "1"
			_motion_trace_enabled = _web_query("motionTrace") == "1"
			_local_presentation_smoothing_enabled = \
				_web_query("localPresentationSmoothing") == "1"
			_network_test_world_enabled = _web_query("expandedCity") == "1"
			if _network_test_world_enabled:
				_home_half = NETWORK_TEST_HOME_HALF
			var profile_query := _web_query("networkProfile")
			if not profile_query.is_empty():
				_network_profile = profile_query
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
			var interp_mode_query := _web_query("remoteInterpMode")
			if interp_mode_query in ["fixed", "adaptive", "predictive", "proxy"]:
				_remote_interp_mode = interp_mode_query
			var interp_query := _web_query("remoteInterpMs")
			if interp_query.is_valid_float():
				_remote_interp_ms = maxf(0.0, float(interp_query))
			var interp_max_query := _web_query("remoteInterpMaxMs")
			if interp_max_query.is_valid_float():
				_remote_interp_max_ms = maxf(_remote_interp_ms, float(interp_max_query))
			var trace_seconds_query := _web_query("presentationTraceSeconds")
			if trace_seconds_query.is_valid_float():
				_presentation_trace_path = "console"
				_presentation_trace_seconds = maxf(0.0, float(trace_seconds_query))
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
		elif arg == "--network-hud":
			_network_hud_enabled = true
		elif arg == "--hide-hotkey-hints":
			_hotkey_hints_visible = false
		elif arg.begins_with("--network-profile="):
			_network_profile = arg.get_slice("=", 1)
		elif arg == "--network-profile" and index + 1 < args.size():
			index += 1
			_network_profile = args[index]
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
		elif arg.begins_with("--remote-interp-mode="):
			_remote_interp_mode = arg.get_slice("=", 1).to_lower()
		elif arg == "--remote-interp-mode" and index + 1 < args.size():
			index += 1
			_remote_interp_mode = args[index].to_lower()
		elif arg.begins_with("--remote-interp="):
			_remote_interp_ms = maxf(0.0, float(arg.get_slice("=", 1)))
		elif arg == "--remote-interp" and index + 1 < args.size():
			index += 1
			_remote_interp_ms = maxf(0.0, float(args[index]))
		elif arg.begins_with("--remote-interp-max="):
			_remote_interp_max_ms = maxf(_remote_interp_ms,
				float(arg.get_slice("=", 1)))
		elif arg == "--remote-interp-max" and index + 1 < args.size():
			index += 1
			_remote_interp_max_ms = maxf(_remote_interp_ms, float(args[index]))
		elif arg.begins_with("--presentation-trace="):
			_presentation_trace_path = arg.get_slice("=", 1)
		elif arg == "--presentation-trace" and index + 1 < args.size():
			index += 1
			_presentation_trace_path = args[index]
		elif arg.begins_with("--presentation-trace-seconds="):
			_presentation_trace_seconds = maxf(0.0, float(arg.get_slice("=", 1)))
		elif arg == "--presentation-trace-seconds" and index + 1 < args.size():
			index += 1
			_presentation_trace_seconds = maxf(0.0, float(args[index]))
		elif arg.begins_with("--presentation-control="):
			_presentation_control_path = arg.get_slice("=", 1)
		elif arg == "--presentation-control" and index + 1 < args.size():
			index += 1
			_presentation_control_path = args[index]
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
		elif arg == "--server-driver-lane":
			_server_driver_enabled = true
			_server_driver_lane = true
		elif arg == "--player-capsule":
			_player_capsule_enabled = true
		elif arg == "--no-player-capsule":
			_player_capsule_enabled = false
		elif arg == "--client-cruise":
			_client_cruise_allowed = true
		elif arg == "--expanded-city":
			_network_test_world_enabled = true
			_home_half = NETWORK_TEST_HOME_HALF
		elif arg == "--motion-trace":
			_motion_trace_enabled = true
		elif arg == "--local-presentation-smoothing":
			_local_presentation_smoothing_enabled = true
		elif arg == "--reverse-test":
			_reverse_test = true
		elif arg == "--no-drone":
			_drone_enabled = false
		elif arg == "--no-ball":
			_ball_enabled = false
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
		elif arg.begins_with("--run-id="):
			_run_id = arg.get_slice("=", 1)
		elif arg == "--run-id" and index + 1 < args.size():
			index += 1
			_run_id = args[index]
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
	if _remote_interp_mode not in ["fixed", "adaptive", "predictive", "proxy"]:
		push_error("--remote-interp-mode must be fixed, adaptive, predictive, or proxy")
		_remote_interp_mode = "fixed"
	NetworkPerformance.set_app_telemetry_enabled(_network_app_telemetry)
	RemotePositionTransport.configure(_remote_state_push, _remote_state_transport,
		_remote_state_rate, _network_app_telemetry, _remote_state_relevance,
		_remote_state_include_self)
	RemotePositionTransport.configure_presentation(_remote_interp_mode,
		_remote_interp_ms, _remote_interp_max_ms, _presentation_trace_path,
		_presentation_trace_seconds)
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
	if _dots != null:
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
	var spawn_info := {"id": owner_id, "slot": 0,
		"remote_generation": _allocate_remote_state_generation(),
		"map_id": MAP_LAYOUT.CITY}
	var body := _spawn_player(spawn_info)
	_players.add_child(body, true)
	var config := _configuration_for(owner_id)
	_apply_coverage_config(owner_id, config["ranges"], config["widths"],
		config["tips_outward"])
	if _ball_enabled:
		var ball := _spawn_ball({"name": "CityBall", "position": BALL_SCRIPT.SPAWN_POSITION})
		_balls.add_child(ball, true)
		_ball_seeded = true
	_next_spawn_slot = 1
	var time_error: int = await NetworkTime.start()
	if time_error != OK:
		push_error("Could not start offline simulation clock: %s" % error_string(time_error))
		get_tree().quit(2)
		return
	_log("OFFLINE_READY id=%d players=%d balls=%d map=%d" % [owner_id,
		_players.get_child_count(), _balls.get_child_count(), int(body.get("map_id"))])
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
		"remote_generation": _allocate_remote_state_generation(),
		"player_capsule": _player_capsule_enabled}
	if _server_driver_enabled:
		var driver_spawn := SERVER_DRIVER_LANE_SPAWN if _server_driver_lane \
			else SERVER_DRIVER_SPAWN
		var observer_spawn := NETWORK_TEST_OBSERVER_SPAWN if _network_test_world_enabled \
			else (SERVER_DRIVER_LANE_OBSERVER_SPAWN if _server_driver_lane \
			else driver_spawn + Vector2(8.0, 6.0))
		# The interactive Networking-1 observer retains its accepted spawn. Long
		# mux soaks add a stationary native survivor first, so stagger later
		# harness-only observers instead of stacking every peer at one position.
		observer_spawn += Vector2(0.0,
			float(maxi(0, _next_spawn_slot - 1)) * SERVER_DRIVER_OBSERVER_SPACING)
		var observer_position := Vector3(observer_spawn.x,
			GROUND_BODY_Y, observer_spawn.y)
		spawn_data["position"] = observer_position
		spawn_data["yaw"] = -PI * 0.5
	_spawner.spawn(spawn_data)
	var config := _configuration_for(id)
	_apply_coverage_config.rpc(id, config["ranges"], config["widths"], config["tips_outward"])
	_apply_oil_tuning_snapshot.rpc_id(id, OIL_SLICK.tuning_snapshot())
	var target_counts := PackedInt32Array()
	for target in _targets.get_children():
		target_counts.append(int(target.get("hit_count")))
	_sync_target_hits.rpc_id(id, target_counts)
	_next_spawn_slot += 1
	if _ball_enabled and not _ball_seeded:
		_ball_seeded = true
		_ball_spawner.spawn({"name": "CityBall", "position": BALL_SCRIPT.SPAWN_POSITION})
	if _dots != null:
		_dots.call("send_state_to", id)

func _spawn_server_driver() -> void:
	if not multiplayer.is_server() or _players.get_node_or_null("1") != null:
		return
	var driver_spawn := SERVER_DRIVER_LANE_SPAWN if _server_driver_lane \
		else SERVER_DRIVER_SPAWN
	_log("SERVER_DRIVER spawn id=1 slot=%d path=%s" % [_next_spawn_slot,
		"slow-left-lane" if _server_driver_lane else "open-perimeter"])
	_spawner.spawn({"id": 1, "slot": _next_spawn_slot,
		"position": Vector3(driver_spawn.x,
			GROUND_BODY_Y, driver_spawn.y),
		"yaw": PI,
		"server_driver": true,
		"player_capsule": _player_capsule_enabled,
		"disable_collision_escape": _server_driver_lane,
		"remote_generation": _allocate_remote_state_generation()})
	_server_driver_waypoint = 1
	_server_driver_progress_tick = -1
	_server_driver_progress_position = driver_spawn
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
	_shield_drone.position = SHIELD_DRONE_SCRIPT.CITY_POSITION
	add_child(_shield_drone)
	if not _is_headless():
		_shield_drone.call("build_presentation")
	_build_city_space()
	_dots = Node3D.new()
	_dots.name = "Dots"
	_dots.set_script(DOTS_SCRIPT)
	add_child(_dots)
	_troop_delivery = Node3D.new()
	_troop_delivery.name = "TroopDelivery"
	_troop_delivery.set_script(TROOP_DELIVERY_SCRIPT)
	_troop_delivery.call("setup", _players)
	add_child(_troop_delivery)
	_build_combat_targets()
	if not _is_headless():
		# Oil decals and grass remain presentation-only and never add rollback bodies.
		var oil_slicks := Node3D.new()
		oil_slicks.name = "OilSlicks"
		oil_slicks.set_script(OIL_SLICKS_SCRIPT)
		oil_slicks.call("setup", _players)
		add_child(oil_slicks)
		var grass := Node3D.new()
		grass.name = "InteractiveGrass"
		grass.set_script(INTERACTIVE_GRASS_SCRIPT)
		grass.call("setup", _players, _combat_bolts)
		grass.position = Vector3(58.0, 0.0, 18.0)
		add_child(grass)
		_build_presentation()
		_build_city_presentation()
		if _motion_trace_enabled:
			_motion_trace = Node.new()
			_motion_trace.name = "PresentedMotionTrace"
			_motion_trace.set_script(MOTION_TRACE_SCRIPT)
			add_child(_motion_trace)
			_motion_trace.call("setup", self, _players, _camera)

func _spawn_player(data: Variant) -> Node:
	var info: Dictionary = data if data is Dictionary else {"id": int(data), "slot": 0}
	var owner_id := int(info.get("id", 0))
	var slot := int(info.get("slot", 0))
	var body := RigidBody3D.new()
	body.set_script(PLAYER_SCRIPT)
	body.name = str(owner_id)
	body.set("owner_id", owner_id)
	body.set("spawn_slot", slot)
	body.set("disable_collision_escape", bool(info.get("disable_collision_escape", false)))
	body.set("remote_state_generation", int(info.get("remote_generation", 0)))
	body.set("local_presentation_smoothing", _local_presentation_smoothing_enabled)
	body.set("map_id", int(info.get("map_id", MAP_LAYOUT.CITY)))
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
	# physics impulse instead of continuous collider friction.
	physics_material.friction = VEHICLE_CONFIG.CONTACT_FRICTION
	body.physics_material_override = physics_material

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	if bool(info.get("player_capsule", _player_capsule_enabled)):
		SERVER_DRIVER_COLLISION.configure(collision)
	else:
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
	if _reverse_test and slot == 0:
		return Transform3D(Basis(Vector3.UP, -PI * 0.5),
			Vector3(_home_half - 2.4, GROUND_BODY_Y, 0.0))
	var positions := [
		Vector3(-3.0, GROUND_BODY_Y, 0.0),
		Vector3(3.0, GROUND_BODY_Y, 0.0),
		Vector3(0.0, GROUND_BODY_Y, -3.0),
		Vector3(0.0, GROUND_BODY_Y, 3.0),
	]
	var position: Vector3 = positions[slot % positions.size()]
	var forward := -position.normalized()
	var yaw := atan2(-forward.x, -forward.z)
	return Transform3D(Basis(Vector3.UP, yaw), position)

func _spawn_ball(data: Variant) -> Node:
	var info: Dictionary = data if data is Dictionary else {}
	var body := RigidBody3D.new()
	body.set_script(BALL_SCRIPT)
	body.name = str(info.get("name", "CityBall"))
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
	if owner_id == multiplayer.get_unique_id():
		hull.call("set_model_scale_multiplier", _vehicle_model_scale_for("Jeep"))
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
	pip.visible = OS.get_environment("CAR_FIGHT_HIDE_PEER_MARKERS") != "1"
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
	marker.material_override = DRIVE_CURSOR_VISUAL.material(Color(color, 0.85))
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
	max_speed_marker.material_override = DRIVE_CURSOR_VISUAL.material(Color("fff1b8"))
	max_speed_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	max_speed_marker.visible = is_local
	body.add_child(max_speed_marker)

	var line := MeshInstance3D.new()
	line.name = "CursorLine"
	line.top_level = true
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.045, 0.025, 1.0)
	line.mesh = line_mesh
	line.material_override = DRIVE_CURSOR_VISUAL.material(Color(color, 0.7))
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

func _build_city_space() -> void:
	var center := MAP_LAYOUT.CITY_CENTER
	var half := _home_half
	_add_static_box("CityGroundCollision", Vector3(half * 2.0, 1.0, half * 2.0),
		center + Vector3(0.0, -0.5, 0.0), Color("24282b"), 0.0, false)
	if not _is_headless():
		_build_shader_ground("CityShaderGridGround", center, half)
	var wall_height: float = WORLD_CONFIG.WALL_HEIGHT
	var wall_thickness: float = WORLD_CONFIG.WALL_THICKNESS
	var wall_y := wall_height * 0.5
	_add_static_box("CityWallNorth", Vector3(half * 2.0 + wall_thickness * 2.0,
		wall_height, wall_thickness), center + Vector3(0.0, wall_y, -half), Color("4f5559"))
	_add_static_box("CityWallSouth", Vector3(half * 2.0 + wall_thickness * 2.0,
		wall_height, wall_thickness), center + Vector3(0.0, wall_y, half), Color("4f5559"))
	_add_static_box("CityWallWest", Vector3(wall_thickness, wall_height, half * 2.0),
		center + Vector3(-half, wall_y, 0.0), Color("4f5559"))
	_add_static_box("CityWallEast", Vector3(wall_thickness, wall_height, half * 2.0),
		center + Vector3(half, wall_y, 0.0), Color("4f5559"))
	for index in range(CITY_LAYOUT.BUILDINGS.size()):
		var building: Dictionary = CITY_LAYOUT.BUILDINGS[index]
		var footprint: Vector2 = building["footprint"]
		var height := float(building["height"]) * CITY_LAYOUT.SCALE
		_add_static_box("CityBuildingCollision%02d" % index,
			Vector3(footprint.x * CITY_LAYOUT.SCALE, height,
				footprint.y * CITY_LAYOUT.SCALE),
			center + (building["position"] as Vector3) * CITY_LAYOUT.SCALE
				+ Vector3(0.0, height * 0.5, 0.0),
			Color.TRANSPARENT, deg_to_rad(float(building["yaw"])), false)

func _build_combat_targets() -> void:
	var positions := TARGET_LAYOUT.positions()
	for index in range(positions.size()):
		var target := StaticBody3D.new()
		target.set_script(TARGET_DUMMY_SCRIPT)
		target.position = positions[index]
		target.call("setup", index, not _is_headless())
		_targets.add_child(target)

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
	ground.set_meta("world_presentation", true)
	add_child(ground)

func _add_static_box(node_name: String, size: Vector3, position: Vector3, color: Color,
		yaw: float = 0.0, visible: bool = true) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation = Vector3(0.0, yaw, 0.0)
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
		# Static city geometry receives the vehicle/ball shadows but does not
		# enter the moving spotlight's shadow pass every rendered frame.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.material_override = _material(color)
		mesh_instance.set_meta("world_presentation", true)
		body.add_child(mesh_instance)
	add_child(body)


func _build_presentation() -> void:
	_build_city_lighting()
	_camera = Camera3D.new()
	_camera.name = "IsometricCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = WORLD_CONFIG.CAMERA_SIZE
	_camera.current = true
	add_child(_camera)
	_speed_camera = SPEED_CAMERA_SCRIPT.new()
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
	_build_hud(hud)


func _build_city_lighting() -> void:
	var environment := WorldEnvironment.new()
	_world_environment = Environment.new()
	_world_environment.background_mode = Environment.BG_COLOR
	_world_environment.background_color = Color("10171d")
	_world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world_environment.ambient_light_color = Color("b6cad3")
	_world_environment.ambient_light_energy = 0.08
	_world_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_world_environment.tonemap_exposure = 0.82
	_world_environment.ssao_enabled = false
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.42, 0.72)
	sky_material.sky_horizon_color = Color(0.72, 0.82, 0.92)
	sky_material.ground_bottom_color = Color(0.16, 0.19, 0.12)
	sky_material.ground_horizon_color = Color(0.58, 0.62, 0.52)
	sky_material.sky_curve = 0.12
	sky_material.ground_curve = 0.18
	sky_material.sun_angle_max = 1.0
	sky_material.sun_curve = 0.08
	sky_material.energy_multiplier = 0.78
	_sunlit_sky = Sky.new()
	_sunlit_sky.sky_material = sky_material
	_sunlit_sky.radiance_size = Sky.RADIANCE_SIZE_256
	_sunlit_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	var overcast_material := PanoramaSkyMaterial.new()
	overcast_material.panorama = load(OVERCAST_HDRI_PATH) as Texture2D
	overcast_material.energy_multiplier = 1.0
	_overcast_sky = Sky.new()
	_overcast_sky.sky_material = overcast_material
	_overcast_sky.radiance_size = Sky.RADIANCE_SIZE_128
	_overcast_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.environment = _world_environment
	add_child(environment)
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "ShadowSun"
	_sun_light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	_sun_light.light_color = Color("fff1d4")
	_sun_light.light_energy = 0.28
	# A second shadow map produces striped self-shadowing on ANGLE.
	_sun_light.shadow_enabled = false
	add_child(_sun_light)
	_rim_light = DirectionalLight3D.new()
	_rim_light.name = "SceneryRimLight"
	_rim_light.rotation_degrees = Vector3(-34.0, 142.0, 0.0)
	_rim_light.light_color = Color(0.48, 0.72, 1.0)
	_rim_light.light_energy = 0.32
	_rim_light.shadow_enabled = false
	_rim_light.visible = false
	add_child(_rim_light)
	# ANGLE's compatibility path does not consistently expose directional
	# shadows on this Intel Mac. A broad real-time spotlight supplies a shadow
	# map that the ground grid, roads, supports, cars, and ball all receive.
	_shadow_light = SpotLight3D.new()
	_shadow_light.name = "CityShadowLight"
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
	_apply_lighting_style()


func _build_hud(hud: CanvasLayer) -> void:
	var indicators := Control.new()
	indicators.name = "OffscreenIndicators"
	indicators.set_script(OFFSCREEN_INDICATORS_SCRIPT)
	hud.add_child(indicators)
	indicators.call("setup", self, _camera)
	_system_menu_bar = MenuBar.new()
	_system_menu_bar.name = "SystemMenuBar"
	_system_menu_bar.prefer_global_menu = true
	_system_menu_bar.start_index = -1
	_system_menu_bar.position = Vector2(10.0, 8.0)
	_system_menu_bar.size = Vector2(340.0, 32.0)
	hud.add_child(_system_menu_bar)
	_debug_popup = PopupMenu.new()
	_debug_popup.name = "Debug"
	_debug_popup.title = "Debug"
	_system_menu_bar.add_child(_debug_popup)
	_debug_popup.add_check_item("Show collision capsule", DEBUG_COLLISION_MENU_ID)
	_debug_popup.set_item_checked(_debug_popup.get_item_index(DEBUG_COLLISION_MENU_ID),
		_gameplay_collision_debug_enabled)
	_debug_popup.add_check_item("Show gameplay text", DEBUG_GAMEPLAY_TEXT_MENU_ID)
	_debug_popup.set_item_checked(_debug_popup.get_item_index(DEBUG_GAMEPLAY_TEXT_MENU_ID),
		_gameplay_text_visible)
	_debug_popup.id_pressed.connect(_on_debug_menu_item_pressed)
	_build_vehicle_model_menu()
	_build_oil_tuning_menu()
	_build_scenery_menu()
	_build_lighting_editor()
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
	_fps_label.visible = not _network_hud_enabled
	hud.add_child(_fps_label)
	_network_hud_label = Label.new()
	_network_hud_label.name = "NetworkDiagnostics"
	_network_hud_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_network_hud_label.offset_left = -455.0
	_network_hud_label.offset_top = 16.0
	_network_hud_label.offset_right = -18.0
	_network_hud_label.offset_bottom = 150.0
	_network_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_network_hud_label.add_theme_font_size_override("font_size", 16)
	_network_hud_label.add_theme_color_override("font_color", Color("b8efcc"))
	_network_hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_network_hud_label.add_theme_constant_override("shadow_offset_x", 2)
	_network_hud_label.add_theme_constant_override("shadow_offset_y", 2)
	_network_hud_label.visible = _network_hud_enabled
	hud.add_child(_network_hud_label)
	_network_tier_label = Label.new()
	_network_tier_label.name = "NetworkTierNotice"
	_network_tier_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_network_tier_label.offset_left = -270.0
	_network_tier_label.offset_top = 28.0
	_network_tier_label.offset_right = 270.0
	_network_tier_label.offset_bottom = 72.0
	_network_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_network_tier_label.add_theme_font_size_override("font_size", 24)
	_network_tier_label.add_theme_color_override("font_color", Color("ffd166"))
	_network_tier_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_network_tier_label.add_theme_constant_override("shadow_offset_x", 2)
	_network_tier_label.add_theme_constant_override("shadow_offset_y", 2)
	_network_tier_label.visible = false
	hud.add_child(_network_tier_label)


func _build_city_presentation() -> void:
	_city_presentation = Node3D.new()
	_city_presentation.name = "LowPolyCity"
	_city_presentation.set_script(CITY_PRESENTATION_SCRIPT)
	_city_presentation.call("setup", _players)
	add_child(_city_presentation)
	_city_presentation.call("build_presentation")
	_city_presentation.call("set_lighting_style", _lighting_style_index)

func _on_debug_menu_item_pressed(id: int) -> void:
	if id == DEBUG_COLLISION_MENU_ID:
		_gameplay_collision_debug_enabled = not _gameplay_collision_debug_enabled
		_debug_popup.set_item_checked(_debug_popup.get_item_index(id),
			_gameplay_collision_debug_enabled)
		var local: Node3D = local_player()
		if local != null and local.has_method("set_gameplay_collision_debug_visible"):
			local.call("set_gameplay_collision_debug_visible", _gameplay_collision_debug_enabled)
	elif id == DEBUG_GAMEPLAY_TEXT_MENU_ID:
		_gameplay_text_visible = not _gameplay_text_visible
		_debug_popup.set_item_checked(_debug_popup.get_item_index(id), _gameplay_text_visible)
		if _status_label != null:
			_status_label.visible = _gameplay_text_visible or local_player() == null
		_update_editor_label()


func _build_scenery_menu() -> void:
	_scenery_popup = PopupMenu.new()
	_scenery_popup.name = "Scenery"
	_scenery_popup.title = "Scenery"
	_system_menu_bar.add_child(_scenery_popup)
	_scenery_popup.add_item("Lighting Editor…", SCENERY_LIGHTING_EDITOR_MENU_ID)
	_scenery_popup.add_separator()
	_scenery_popup.add_item("Lighting presets", SCENERY_LIGHTING_INFO_MENU_ID)
	_scenery_popup.set_item_disabled(
		_scenery_popup.get_item_index(SCENERY_LIGHTING_INFO_MENU_ID), true)
	for index in range(LIGHTING_STYLE_NAMES.size()):
		_scenery_popup.add_radio_check_item(LIGHTING_STYLE_NAMES[index],
			LIGHTING_STYLE_MENU_ID_BASE + index)
	_scenery_popup.id_pressed.connect(_on_scenery_menu_pressed)
	_refresh_scenery_menu()


func _refresh_scenery_menu() -> void:
	if _scenery_popup == null:
		return
	for index in range(LIGHTING_STYLE_NAMES.size()):
		_scenery_popup.set_item_checked(_scenery_popup.get_item_index(
			LIGHTING_STYLE_MENU_ID_BASE + index), index == _lighting_style_index)


func _on_scenery_menu_pressed(id: int) -> void:
	if id == SCENERY_LIGHTING_EDITOR_MENU_ID:
		_lighting_editor.call("open")
		return
	var lighting_index := id - LIGHTING_STYLE_MENU_ID_BASE
	if lighting_index >= 0 and lighting_index < LIGHTING_STYLE_NAMES.size():
		_lighting_style_index = lighting_index
		_apply_lighting_style()
		_refresh_scenery_menu()


func _build_lighting_editor() -> void:
	_lighting_editor = Node.new()
	_lighting_editor.name = "LightingEditor"
	_lighting_editor.set_script(LIGHTING_EDITOR_SCRIPT)
	add_child(_lighting_editor)
	_lighting_editor.connect("values_changed", _on_lighting_editor_values_changed)
	_lighting_editor.connect("look_loaded", _on_lighting_editor_look_loaded)
	_lighting_editor.connect("reset_requested", _on_lighting_editor_reset_requested)
	_lighting_editor.call("setup", _current_lighting_editor_values(),
		LIGHTING_STYLE_NAMES[_lighting_style_index])


func _current_lighting_editor_values() -> Dictionary:
	return {
		"sun_color": _sun_light.light_color,
		"sun_energy": _sun_light.light_energy,
		"sun_elevation": -_sun_light.rotation_degrees.x,
		"sun_azimuth": _sun_light.rotation_degrees.y,
		"ambient_energy": _world_environment.ambient_light_energy,
		"exposure": _world_environment.tonemap_exposure,
		"saturation": _world_environment.adjustment_saturation,
		"contact_shadows": _shadow_light.visible,
		"shadow_opacity": _shadow_light.shadow_opacity,
	}


func _on_lighting_editor_values_changed(values: Dictionary) -> void:
	_sun_light.light_color = values.get("sun_color", _sun_light.light_color) as Color
	_sun_light.light_energy = clampf(float(values.get("sun_energy", 1.0)), 0.0, 3.0)
	var rotation := _sun_light.rotation_degrees
	rotation.x = -clampf(float(values.get("sun_elevation", 45.0)), 5.0, 85.0)
	rotation.y = clampf(float(values.get("sun_azimuth", 0.0)), -180.0, 180.0)
	_sun_light.rotation_degrees = rotation
	_world_environment.ambient_light_energy = clampf(
		float(values.get("ambient_energy", 1.0)), 0.0, 2.0)
	_world_environment.tonemap_exposure = clampf(
		float(values.get("exposure", 1.0)), 0.25, 2.0)
	_world_environment.adjustment_enabled = true
	_world_environment.adjustment_saturation = clampf(
		float(values.get("saturation", 1.0)), 0.0, 2.0)
	_shadow_light.visible = bool(values.get("contact_shadows", true))
	_shadow_light.shadow_opacity = clampf(
		float(values.get("shadow_opacity", 0.8)), 0.0, 1.0)


func _on_lighting_editor_reset_requested() -> void:
	_apply_lighting_style()


func _on_lighting_editor_look_loaded(base_preset: String, values: Dictionary) -> void:
	var preset_index := LIGHTING_STYLE_NAMES.find(base_preset)
	if preset_index >= 0:
		_lighting_style_index = preset_index
		_apply_lighting_style()
		_refresh_scenery_menu()
	_on_lighting_editor_values_changed(values)


func _apply_lighting_style() -> void:
	if _world_environment == null or _sun_light == null \
			or _rim_light == null or _shadow_light == null:
		return
	# Screen-space effects stay disabled on this Intel-safe Compatibility path.
	_world_environment.ssao_enabled = false
	_world_environment.ssil_enabled = false
	_world_environment.ssr_enabled = false
	_world_environment.sdfgi_enabled = false
	_world_environment.adjustment_enabled = false
	_world_environment.adjustment_brightness = 1.0
	_world_environment.adjustment_contrast = 1.0
	_world_environment.adjustment_saturation = 1.0
	_world_environment.background_mode = Environment.BG_COLOR
	_world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_world_environment.tonemap_white = 1.0
	_sun_light.shadow_enabled = false
	_sun_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_sun_light.light_specular = 0.5
	_shadow_light.light_color = Color("fff0cf")
	_shadow_light.light_energy = 1.75
	_shadow_light.light_specular = 0.5
	_shadow_light.shadow_opacity = 0.92
	_rim_light.visible = false
	match _lighting_style_index:
		1, 2:
			_world_environment.background_color = Color(0.085, 0.105, 0.15)
			_world_environment.ambient_light_color = Color(0.48, 0.60, 0.82)
			_world_environment.ambient_light_energy = 0.62
			_world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			_world_environment.tonemap_exposure = 1.08
			_sun_light.rotation_degrees = Vector3(-56.0, -38.0, 0.0)
			_sun_light.light_color = Color(1.0, 0.86, 0.72)
			_sun_light.light_energy = 1.18
			_shadow_light.visible = false
			_rim_light.visible = _lighting_style_index == 2
		3:
			# Retain the accepted broad overcast HDRI as an alternate grade for the
			# production city geometry and normal game controls.
			_world_environment.background_mode = Environment.BG_SKY
			_world_environment.sky = _overcast_sky
			_world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			_world_environment.ambient_light_sky_contribution = 1.0
			_world_environment.ambient_light_energy = 1.0
			_world_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			_world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			_world_environment.tonemap_exposure = 1.0
			_world_environment.tonemap_white = 1.5
			_world_environment.adjustment_enabled = true
			_world_environment.adjustment_brightness = 1.05
			_world_environment.adjustment_contrast = 1.0
			_world_environment.adjustment_saturation = 1.08
			_sun_light.rotation_degrees = Vector3(-68.0, -130.0, 0.0)
			_sun_light.light_color = Color("fff5e8")
			_sun_light.light_energy = 0.34
			_sun_light.light_specular = 0.35
			_shadow_light.light_color = Color("fff7eb")
			_shadow_light.light_energy = 0.72
			_shadow_light.light_specular = 0.25
			_shadow_light.shadow_opacity = 0.34
			_shadow_light.visible = true
		4:
			_world_environment.background_mode = Environment.BG_SKY
			_world_environment.sky = _sunlit_sky
			_world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			_world_environment.ambient_light_sky_contribution = 1.0
			_world_environment.ambient_light_energy = 0.95
			_world_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			_world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			_world_environment.tonemap_exposure = 0.94
			_world_environment.tonemap_white = 2.8
			_world_environment.adjustment_enabled = true
			_world_environment.adjustment_brightness = 0.98
			_world_environment.adjustment_contrast = 0.96
			_world_environment.adjustment_saturation = 0.90
			# Godot 4.7 Forward+ cannot compile its Vulkan compute pipelines on this
			# Intel Iris Plus. This live-driving preset therefore keeps the sunlit
			# procedural dome, Filmic grade, sky reflections, and MSAA while using
			# Car Fight's stable Compatibility spotlight for contact shadows.
			_sun_light.rotation_degrees = Vector3(-57.0, -34.0, 0.0)
			_sun_light.light_color = Color(1.0, 0.965, 0.90)
			_sun_light.light_energy = 1.65
			_sun_light.light_specular = 0.8
			_sun_light.shadow_enabled = false
			_sun_light.shadow_opacity = 0.88
			_sun_light.light_angular_distance = 0.65
			_sun_light.shadow_blur = 1.0
			_sun_light.shadow_bias = 0.035
			_sun_light.shadow_normal_bias = 1.1
			_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			_sun_light.directional_shadow_max_distance = 165.0
			_sun_light.directional_shadow_split_1 = 0.08
			_sun_light.directional_shadow_split_2 = 0.22
			_sun_light.directional_shadow_split_3 = 0.48
			_sun_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
			_shadow_light.light_color = Color(1.0, 0.93, 0.82)
			_shadow_light.light_energy = 1.45
			_shadow_light.light_specular = 0.5
			_shadow_light.shadow_opacity = 0.72
			_shadow_light.visible = true
		_:
			_world_environment.background_color = Color("10171d")
			_world_environment.ambient_light_color = Color("b6cad3")
			_world_environment.ambient_light_energy = 0.08
			_world_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
			_world_environment.tonemap_exposure = 0.82
			_sun_light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
			_sun_light.light_color = Color("fff1d4")
			_sun_light.light_energy = 0.28
			_shadow_light.visible = true
	if _city_presentation != null:
		_city_presentation.call("set_lighting_style", _lighting_style_index)
	if _lighting_editor != null:
		_lighting_editor.call("set_values", _current_lighting_editor_values(),
			LIGHTING_STYLE_NAMES[_lighting_style_index])


func _build_vehicle_model_menu() -> void:
	_vehicle_model_popup = PopupMenu.new()
	_vehicle_model_popup.name = "VehicleModel"
	_vehicle_model_popup.title = "Vehicle Model"
	_system_menu_bar.add_child(_vehicle_model_popup)
	_vehicle_model_popup.add_item("Current vehicle: Jeep", VEHICLE_MODEL_CURRENT_INFO_MENU_ID)
	_vehicle_model_popup.set_item_disabled(_vehicle_model_popup.get_item_index(
		VEHICLE_MODEL_CURRENT_INFO_MENU_ID), true)
	_vehicle_model_popup.add_separator()
	for index in range(VEHICLE_MODEL_SCALE_OPTIONS.size()):
		var scale_amount := float(VEHICLE_MODEL_SCALE_OPTIONS[index])
		_vehicle_model_popup.add_radio_check_item("%.0f%%" % (scale_amount * 100.0),
			VEHICLE_MODEL_SCALE_MENU_ID_BASE + index)
	_vehicle_model_popup.add_separator()
	_vehicle_model_popup.add_item("Reset to 100%", VEHICLE_MODEL_RESET_MENU_ID)
	_vehicle_model_popup.add_separator()
	_vehicle_model_popup.add_item("Visual only — collider unchanged",
		VEHICLE_MODEL_COLLIDER_INFO_MENU_ID)
	_vehicle_model_popup.set_item_disabled(_vehicle_model_popup.get_item_index(
		VEHICLE_MODEL_COLLIDER_INFO_MENU_ID), true)
	_vehicle_model_popup.add_item("Each vehicle saves its own size",
		VEHICLE_MODEL_AUTOSAVE_INFO_MENU_ID)
	_vehicle_model_popup.set_item_disabled(_vehicle_model_popup.get_item_index(
		VEHICLE_MODEL_AUTOSAVE_INFO_MENU_ID), true)
	_vehicle_model_popup.id_pressed.connect(_on_vehicle_model_menu_pressed)
	_refresh_vehicle_model_menu()


func _refresh_vehicle_model_menu() -> void:
	if _vehicle_model_popup == null:
		return
	var vehicle_name := _current_vehicle_model_name()
	var current_scale := _vehicle_model_scale_for(vehicle_name)
	_vehicle_model_popup.set_item_text(_vehicle_model_popup.get_item_index(
		VEHICLE_MODEL_CURRENT_INFO_MENU_ID), "Current vehicle: %s" % vehicle_name)
	for index in range(VEHICLE_MODEL_SCALE_OPTIONS.size()):
		_vehicle_model_popup.set_item_checked(_vehicle_model_popup.get_item_index(
			VEHICLE_MODEL_SCALE_MENU_ID_BASE + index), is_equal_approx(
			current_scale, float(VEHICLE_MODEL_SCALE_OPTIONS[index])))


func _on_vehicle_model_menu_pressed(id: int) -> void:
	if id == VEHICLE_MODEL_RESET_MENU_ID:
		_apply_vehicle_model_scale(1.0)
		return
	var index := id - VEHICLE_MODEL_SCALE_MENU_ID_BASE
	if index < 0 or index >= VEHICLE_MODEL_SCALE_OPTIONS.size():
		return
	_apply_vehicle_model_scale(VEHICLE_MODEL_SCALE_OPTIONS[index])


func _apply_vehicle_model_scale(value: Variant) -> void:
	var vehicle_name := _current_vehicle_model_name()
	var model_scale := HULL_SCRIPT.sanitized_model_scale(value)
	_vehicle_model_scales[vehicle_name] = model_scale
	var local: Node3D = local_player()
	if local != null:
		var hull: Node = local.get_node_or_null("GroundVehicleHull")
		if hull != null and hull.has_method("set_model_scale_multiplier"):
			hull.call("set_model_scale_multiplier", model_scale)
	_refresh_vehicle_model_menu()
	_save_persisted_vehicle_model_scale()


func _current_vehicle_model_name() -> String:
	var local: Node3D = local_player()
	if local != null:
		var hull: Node = local.get_node_or_null("GroundVehicleHull")
		if hull != null and hull.has_method("vehicle_name"):
			return str(hull.call("vehicle_name"))
	return "Jeep"


func _vehicle_model_scale_for(vehicle_name: String) -> float:
	return HULL_SCRIPT.sanitized_model_scale(_vehicle_model_scales.get(vehicle_name, 1.0))


func _persistence_available_for_vehicle_model_scale() -> bool:
	return _role in ["client", "offline"] and DisplayServer.get_name() != "headless" \
		and not OS.has_feature("web")


func _load_persisted_vehicle_model_scale() -> void:
	if not _persistence_available_for_vehicle_model_scale():
		return
	var config := ConfigFile.new()
	if config.load(VEHICLE_MODEL_SCALE_PATH) != OK:
		return
	if config.has_section_key(VEHICLE_MODEL_SCALE_SECTION, "scales"):
		var saved_scales: Variant = config.get_value(VEHICLE_MODEL_SCALE_SECTION, "scales")
		if saved_scales is Dictionary:
			for vehicle_name_variant in saved_scales:
				var vehicle_name := str(vehicle_name_variant)
				_vehicle_model_scales[vehicle_name] = HULL_SCRIPT.sanitized_model_scale(
					saved_scales[vehicle_name_variant])
	elif config.has_section_key(VEHICLE_MODEL_SCALE_SECTION, "scale"):
		var legacy_scale := HULL_SCRIPT.sanitized_model_scale(config.get_value(
			VEHICLE_MODEL_SCALE_SECTION, "scale"))
		for vehicle_variant in HULL_SCRIPT.VEHICLES:
			var vehicle: Dictionary = vehicle_variant
			_vehicle_model_scales[str(vehicle["name"])] = legacy_scale


func _save_persisted_vehicle_model_scale() -> void:
	if not _persistence_available_for_vehicle_model_scale():
		return
	var config := ConfigFile.new()
	config.set_value(VEHICLE_MODEL_SCALE_SECTION, "scales", _vehicle_model_scales)
	var error := config.save(VEHICLE_MODEL_SCALE_PATH)
	if error != OK:
		push_warning("Could not autosave vehicle model scale: %s" % error_string(error))


func _build_oil_tuning_menu() -> void:
	_oil_popup = PopupMenu.new()
	_oil_popup.name = "OilSlick"
	_oil_popup.title = "Oil Slick"
	_system_menu_bar.add_child(_oil_popup)
	_oil_popup.add_check_item("Instant entry", OIL_INSTANT_MENU_ID)
	_oil_popup.add_separator()
	for key_variant in OIL_MENU_ORDER:
		var key := str(key_variant)
		var option: Dictionary = OIL_MENU_OPTIONS[key]
		var submenu := PopupMenu.new()
		submenu.name = "Oil%s" % key.to_pascal_case()
		_oil_popup.add_child(submenu)
		_oil_popup.add_submenu_item(str(option["label"]), submenu.name)
		var values: Array = option["values"]
		for index in range(values.size()):
			submenu.add_radio_check_item(_oil_tuning_value_label(key,
				float(values[index])), index)
		submenu.id_pressed.connect(_on_oil_tuning_option_pressed.bind(key))
		_oil_submenus[key] = submenu
	_oil_popup.add_separator()
	_oil_popup.add_item("Reset extreme defaults", OIL_RESET_MENU_ID)
	_oil_popup.add_separator()
	_oil_popup.add_item("Changes autosave for next launch", OIL_AUTOSAVE_INFO_MENU_ID)
	_oil_popup.set_item_disabled(
		_oil_popup.get_item_index(OIL_AUTOSAVE_INFO_MENU_ID), true)
	_oil_popup.id_pressed.connect(_on_oil_tuning_menu_pressed)
	_refresh_oil_tuning_menu()


func _oil_tuning_value_label(key: String, value: float) -> String:
	match key:
		"duration":
			return "%.1f seconds" % value
		"min_grip_scale", "min_drift_assist_scale":
			return "%.0f%%" % (value * 100.0)
		"rear_lateral_grip", "rear_yaw_grip", "yaw_damping":
			return "%.2f / second" % value
		"front_steer_torque":
			return "%.1f rad/s²" % value
		"max_yaw_rate":
			return "%.1f rad/s" % value
	return "%.2f" % value


func _refresh_oil_tuning_menu() -> void:
	if _oil_popup == null:
		return
	var snapshot := OIL_SLICK.tuning_snapshot()
	_oil_popup.set_item_checked(_oil_popup.get_item_index(OIL_INSTANT_MENU_ID),
		bool(snapshot["instant_entry"]))
	for key_variant in OIL_MENU_ORDER:
		var key := str(key_variant)
		var submenu := _oil_submenus.get(key) as PopupMenu
		if submenu == null:
			continue
		var values: Array = OIL_MENU_OPTIONS[key]["values"]
		for index in range(values.size()):
			submenu.set_item_checked(submenu.get_item_index(index),
				is_equal_approx(float(snapshot[key]), float(values[index])))


func _persistence_available_for_oil_tuning() -> bool:
	return _role in ["client", "offline"] and DisplayServer.get_name() != "headless" \
		and not OS.has_feature("web")


func _load_persisted_oil_tuning() -> void:
	if not _persistence_available_for_oil_tuning():
		return
	var config := ConfigFile.new()
	if config.load(OIL_TUNING_PATH) != OK:
		return
	var snapshot := {}
	for key_variant in OIL_SLICK.tuning_snapshot():
		var key := str(key_variant)
		if config.has_section_key(OIL_TUNING_SECTION, key):
			snapshot[key] = config.get_value(OIL_TUNING_SECTION, key)
	OIL_SLICK.apply_tuning_snapshot(snapshot)
	_persisted_oil_tuning = OIL_SLICK.tuning_snapshot()
	_persisted_oil_tuning_pending = _role == "client"


func _save_persisted_oil_tuning() -> void:
	if not _persistence_available_for_oil_tuning():
		return
	var snapshot := OIL_SLICK.tuning_snapshot()
	var config := ConfigFile.new()
	for key_variant in snapshot:
		var key := str(key_variant)
		config.set_value(OIL_TUNING_SECTION, key, snapshot[key])
	var error := config.save(OIL_TUNING_PATH)
	if error != OK:
		push_warning("Could not autosave oil tuning: %s" % error_string(error))
		return
	_persisted_oil_tuning = snapshot


func _on_oil_tuning_menu_pressed(id: int) -> void:
	if id == OIL_INSTANT_MENU_ID:
		_submit_oil_tuning_change("instant_entry", not OIL_SLICK.instant_entry)
	elif id == OIL_RESET_MENU_ID:
		_submit_oil_tuning_change("reset", true)


func _on_oil_tuning_option_pressed(id: int, key: String) -> void:
	var values: Array = OIL_MENU_OPTIONS[key]["values"]
	if id < 0 or id >= values.size():
		return
	_submit_oil_tuning_change(key, values[id])


func _submit_oil_tuning_change(key: String, value: Variant) -> void:
	if _role == "offline" or multiplayer.multiplayer_peer == null \
			or (_role == "client" and local_player() == null):
		_apply_local_oil_tuning_change(key, value)
		_persisted_oil_tuning_pending = _role == "client"
	elif multiplayer.is_server():
		_accept_oil_tuning_change(key, value)
	else:
		_request_oil_tuning_change.rpc_id(1, key, value)


func _apply_local_oil_tuning_change(key: String, value: Variant) -> void:
	if key == "reset":
		OIL_SLICK.reset_tuning()
	else:
		OIL_SLICK.set_tuning_value(key, value)
	_refresh_oil_tuning_menu()
	_save_persisted_oil_tuning()


func _accept_oil_tuning_change(key: String, value: Variant) -> void:
	if key == "reset":
		OIL_SLICK.reset_tuning()
	elif not OIL_SLICK.set_tuning_value(key, value):
		return
	_apply_oil_tuning_snapshot.rpc(OIL_SLICK.tuning_snapshot())


@rpc("any_peer", "call_remote", "reliable")
func _request_oil_tuning_change(key: String, value: Variant) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or _players == null \
			or _players.get_node_or_null(str(sender)) == null:
		return
	_accept_oil_tuning_change(key, value)


@rpc("any_peer", "call_remote", "reliable")
func _request_oil_tuning_snapshot(snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or sender not in multiplayer.get_peers():
		return
	OIL_SLICK.apply_tuning_snapshot(snapshot)
	_apply_oil_tuning_snapshot.rpc(OIL_SLICK.tuning_snapshot())


@rpc("authority", "call_local", "reliable")
func _apply_oil_tuning_snapshot(snapshot: Dictionary) -> void:
	OIL_SLICK.apply_tuning_snapshot(snapshot)
	_refresh_oil_tuning_menu()
	_log("OIL_TUNING %s" % JSON.stringify(OIL_SLICK.tuning_snapshot()))
	if _role == "client" and _persisted_oil_tuning_pending \
			and multiplayer.multiplayer_peer != null:
		_persisted_oil_tuning_pending = false
		_request_oil_tuning_snapshot.rpc_id(1, _persisted_oil_tuning)
	elif _role in ["client", "offline"]:
		_save_persisted_oil_tuning()


func _update_network_hud(delta: float) -> void:
	if not _network_hud_enabled:
		return
	var live_target_msec := RemotePositionTransport.presentation_delay_msec()
	var live_mode := RemotePositionTransport.presentation_mode()
	if _network_last_target_msec < 0.0:
		_show_network_tier_notice(-1.0, live_target_msec)
	elif live_mode != _network_last_mode:
		_show_network_mode_notice(_network_last_mode, live_mode, live_target_msec)
	elif not is_equal_approx(live_target_msec, _network_last_target_msec):
		_show_network_tier_notice(_network_last_target_msec, live_target_msec)
	_network_last_target_msec = live_target_msec
	_network_last_mode = live_mode
	if _network_tier_notice_remaining > 0.0:
		_network_tier_notice_remaining = maxf(0.0,
			_network_tier_notice_remaining - delta)
		if _network_tier_notice_remaining <= 0.0 and _network_tier_label != null:
			_network_tier_label.visible = false
	_network_hud_elapsed += delta
	_network_hud_frames += 1
	var frame_ms := delta * 1000.0
	_network_hud_frame_ms_sum += frame_ms
	_network_hud_frame_ms_max = maxf(_network_hud_frame_ms_max, frame_ms)
	_network_hud_rb_ms_max = maxf(_network_hud_rb_ms_max,
		NetworkPerformance.get_rollback_loop_duration_ms())
	_network_hud_rb_ticks_max = maxi(_network_hud_rb_ticks_max,
		NetworkPerformance.get_rollback_ticks())
	if _network_hud_elapsed < 1.0:
		return
	var elapsed := maxf(_network_hud_elapsed, 0.001)
	var fps := float(_network_hud_frames) / elapsed
	var frame_avg := _network_hud_frame_ms_sum / maxf(1.0, float(_network_hud_frames))
	var rtt_ms := NetworkTime.remote_rtt * 1000.0
	var jitter_ms := NetworkTimeSynchronizer.rtt_jitter * 1000.0
	var presentation: Dictionary = RemotePositionTransport.presentation_snapshot()
	var local_body: Node3D = local_player()
	if local_body != null and local_body.has_method("local_presentation_metrics"):
		presentation["local_visual"] = local_body.call("local_presentation_metrics")
	var target_ms := float(presentation.get("selected_msec", _remote_interp_ms))
	var headroom_ms := float(presentation.get("headroom_min_msec", 0.0))
	var interp_pct := int(round(float(presentation.get("interp_fraction", 0.0)) * 100.0))
	var extra_pct := int(round(float(presentation.get("extrapolate_fraction", 0.0)) * 100.0))
	var hold_pct := int(round(float(presentation.get("hold_fraction", 0.0)) * 100.0))
	var predictive_offset := float(presentation.get("predictive_offset_units", 0.0))
	var predictive_offset_max := float(presentation.get("predictive_offset_max_units", 0.0))
	var predictive_lead := float(presentation.get("predictive_lead_units", 0.0))
	var app: Dictionary = NetworkPerformance.get_app_telemetry_snapshot(NetworkTime.tick)
	var recoveries := int(app.get("fresh_key_requests_total", 0))
	var alignment_label := "rawΔ" if str(presentation.get("mode", "")) == "proxy" \
		else "offset"
	var hud_text := "FPS %.0f  |  frame %.1f / %.1f ms\n%s %s  |  RTT %.0f ms ±%.0f\nPRES %s %.0f ms  |  %s %.2f/%.2fu  |  lead %+.2fu\nRB %.1f ms / %dt  |  correction %.2fu  |  recovery %d\ncorr %d  stall %d  stale %d  impact %d  unknown %d" % [
		fps, frame_avg, _network_hud_frame_ms_max, _transport.to_upper(),
		_network_profile, rtt_ms, jitter_ms,
		str(presentation.get("mode", _remote_interp_mode)), target_ms,
		alignment_label, predictive_offset, predictive_offset_max, predictive_lead,
		_network_hud_rb_ms_max,
		_network_hud_rb_ticks_max, _worst_correction_error, recoveries,
		int(_correction_counts["corr"]), int(_correction_counts["stall"]),
		int(_correction_counts["stale"]), int(_correction_counts["impact"]),
		int(_correction_counts["unknown"])]
	var local_visual: Dictionary = presentation.get("local_visual", {})
	if bool(local_visual.get("enabled", false)):
		hud_text += "\nLOCAL VIS %.3f/%.3fu  |  snaps %d" % [
			float(local_visual.get("offset_units", 0.0)),
			float(local_visual.get("offset_max_units", 0.0)),
			int(local_visual.get("snaps", 0))]
	var unhealthy := fps < 30.0 or _network_hud_frame_ms_max >= 66.0 \
		or _network_hud_rb_ms_max >= 16.7 or _network_hud_rb_ticks_max > 24 \
		or hold_pct >= 10 or _worst_correction_error > 2.0
	var warning := fps < 50.0 or _network_hud_frame_ms_max >= 33.0 \
		or _network_hud_rb_ms_max >= 8.0 or extra_pct >= 20 or recoveries > 0
	if _network_hud_label != null:
		_network_hud_label.text = hud_text
		_network_hud_label.add_theme_color_override("font_color",
			Color("ff6b66") if unhealthy else (Color("ffd166") if warning else Color("b8efcc")))
	var snapshot := {
		"profile": _network_profile, "transport": _transport, "fps": fps,
		"frame_ms_avg": frame_avg, "frame_ms_max": _network_hud_frame_ms_max,
		"rtt_ms": rtt_ms, "jitter_ms": jitter_ms,
		"presentation": presentation,
		"rollback_ms_max": _network_hud_rb_ms_max,
		"rollback_ticks_max": _network_hud_rb_ticks_max,
		"worst_correction": _worst_correction_error, "recoveries": recoveries,
		"correction_counts": _correction_counts.duplicate(),
	}
	print("NETWORKHUD %s" % JSON.stringify(snapshot))
	if _crash_telemetry != null:
		_crash_telemetry.call("record_event", "network_hud", snapshot)
	_network_hud_elapsed = 0.0
	_network_hud_frames = 0
	_network_hud_frame_ms_sum = 0.0
	_network_hud_frame_ms_max = 0.0
	_network_hud_rb_ms_max = 0.0
	_network_hud_rb_ticks_max = 0


func _show_network_tier_notice(previous_msec: float, selected_msec: float) -> void:
	var mode := RemotePositionTransport.presentation_mode().to_upper()
	var message := "%s BUFFER START  %.0f MS" % [mode, selected_msec] \
		if previous_msec < 0.0 else "%s BUFFER  %.0f → %.0f MS" % [
			mode, previous_msec, selected_msec]
	_network_tier_notice_remaining = 3.0
	if _network_tier_label != null:
		_network_tier_label.text = message
		_network_tier_label.add_theme_color_override("font_color",
			Color("ffd166") if previous_msec < selected_msec else Color("b8efcc"))
		_network_tier_label.visible = true
	print("PRESENTATION_TIER_CHANGE mode=%s from_ms=%.0f to_ms=%.0f" % [
		mode.to_lower(), previous_msec, selected_msec])


func _show_network_mode_notice(previous_mode: String, selected_mode: String,
		selected_msec: float) -> void:
	var message := "%s → %s BUFFER  %.0f MS" % [previous_mode.to_upper(),
		selected_mode.to_upper(), selected_msec]
	_network_tier_notice_remaining = 3.0
	if _network_tier_label != null:
		_network_tier_label.text = message
		_network_tier_label.add_theme_color_override("font_color", Color("ffd166"))
		_network_tier_label.visible = true
	print("PRESENTATION_MODE_CHANGE from=%s to=%s selected_ms=%.0f" % [
		previous_mode, selected_mode, selected_msec])


func _poll_presentation_control(delta: float) -> void:
	var browser_control := OS.has_feature("web")
	if not browser_control and _presentation_control_path.is_empty():
		return
	_presentation_control_elapsed += delta
	if _presentation_control_elapsed < 0.25:
		return
	_presentation_control_elapsed = 0.0
	var command := ""
	if browser_control:
		command = str(JavaScriptBridge.eval(
			"window.localStorage.getItem('carFightPresentationMode') || ''"
		)).strip_edges().to_lower()
	else:
		if not FileAccess.file_exists(_presentation_control_path):
			return
		var file := FileAccess.open(_presentation_control_path, FileAccess.READ)
		if file == null:
			return
		command = file.get_as_text().strip_edges().to_lower()
		file.close()
	if command.is_empty() or command == _presentation_control_last_command:
		return
	_presentation_control_last_command = command
	if command not in ["fixed", "adaptive", "predictive", "proxy"]:
		push_warning("Ignoring presentation control command: %s" % command)
		return
	RemotePositionTransport.set_presentation_mode(command)

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
		if bool(visual_node.get_meta("world_presentation", false)):
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
	_editor_label.visible = _combat_editor_active and _hotkey_hints_visible \
		and _gameplay_text_visible
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

func _input(event: InputEvent) -> void:
	if _role not in ["client", "offline"] or not _scripted.is_empty():
		return
	if event is InputEventJoypadMotion:
		var joy_motion := event as InputEventJoypadMotion
		if joy_motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] \
				and absf(joy_motion.axis_value) > CONTROLLER_INPUT.STICK_DEADZONE:
			_controller_drive_active = true
			_active_controller_id = joy_motion.device
	elif event is InputEventJoypadButton:
		_active_controller_id = event.device
	elif event is InputEventMouseMotion and event.relative.length_squared() > 1.0:
		_controller_drive_active = false


func _unhandled_input(event: InputEvent) -> void:
	if _role not in ["client", "offline"] or not _scripted.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L and _motion_trace_enabled \
				and _motion_trace != null and not _combat_editor_active:
			_motion_trace.call("toggle")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P and _client_cruise_allowed and not _combat_editor_active:
			_client_cruise_active = not _client_cruise_active
			_log("CLIENT_CRUISE active=%s source=local-input" % _client_cruise_active)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and _combat_editor_active:
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
	elif event is InputEventJoypadButton and event.pressed \
			and not _combat_editor_active:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			_cycle_local_vehicle()
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


func client_cruise_active() -> bool:
	return _client_cruise_allowed and _client_cruise_active


func motion_trace_context() -> Dictionary:
	var presentation: Dictionary = RemotePositionTransport.presentation_snapshot()
	var app: Dictionary = NetworkPerformance.get_app_telemetry_snapshot(NetworkTime.tick)
	return {
		"run_id": _run_id,
		"local_peer": multiplayer.get_unique_id(),
		"transport": _transport,
		"tick": NetworkTime.tick,
		"fps": Engine.get_frames_per_second(),
		"rtt_ms": NetworkTime.remote_rtt * 1000.0,
		"presentation_ms": float(presentation.get("selected_msec", _remote_interp_ms)),
		"headroom_ms": float(presentation.get("headroom_min_msec", 0.0)),
		"interp": float(presentation.get("interp_fraction", 0.0)),
		"extrapolate": float(presentation.get("extrapolate_fraction", 0.0)),
		"hold": float(presentation.get("hold_fraction", 0.0)),
		"correction": _worst_correction_error,
		"recoveries": int(app.get("fresh_key_requests_total", 0)),
		"rollback_ms": NetworkPerformance.get_rollback_loop_duration_ms(),
		"rollback_ticks": NetworkPerformance.get_rollback_ticks(),
	}

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
		if hull.has_method("set_model_scale_multiplier") and hull.has_method("vehicle_name"):
			hull.call("set_model_scale_multiplier",
				_vehicle_model_scale_for(str(hull.call("vehicle_name"))))
		_refresh_vehicle_model_menu()

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


func controller_cursor_offset_for(raw_stick: Vector2) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	return CONTROLLER_INPUT.cursor_offset(raw_stick, _camera.global_basis.x,
		_camera.global_basis.y, FOLLOW.MAX_DISTANCE)


func controller_drive_active() -> bool:
	return _controller_drive_active


func active_controller_id() -> int:
	return _active_controller_id


func _drive_control_hint() -> String:
	if _controller_drive_active:
		return "Left stick: drive  |  Cross: burst  |  Circle: reverse  |  Square: homing  |  Triangle: RC orb  |  R2: primary/detonate  |  L1: shield  |  R1: cloak  |  L2: vacuum  |  D-pad: area/det/troops/vehicle"
	return "Mouse: drive  |  Stay in GREEN area to load troops  |  Hold F in RED area to deploy  |  V: vehicle  |  1: homing missile  |  2: RC orb  |  Click: detonate RC orb  |  3: area weapon  |  Cmd: det  |  Q: shield  |  R: cloak  |  Shift: vacuum  |  Space: burst  |  Tab: reverse  |  E: editor  |  C: cones"

func is_scripted_client() -> bool:
	return not _scripted.is_empty() \
		or (_server_driver_enabled and multiplayer.is_server())

func scripted_input_for(body: Node3D) -> Dictionary:
	if _server_driver_enabled and multiplayer.is_server() and int(body.name) == 1:
		return _server_driver_input(body)
	match _scripted:
		"idle":
			# Automated network soaks must not inherit a browser pointer position.
			# Explicit neutral intent keeps reconnect recovery separate from contact.
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": false}
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
				# Hold through the slower city startup window. The server still fires
				# and detonates once because both actions are rising-edge triggered.
				"rc_fire_held": elapsed >= 20 and elapsed < 60,
				"rc_detonate_held": elapsed >= 130 and elapsed < 200,
				"editing": false}
		"combat":
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": false}
		"combat-edit":
			return {"cursor_offset": Vector2.ZERO, "burst": false, "editing": true}
		_:
			return {"cursor_offset": Vector2.ZERO, "burst": false}

func _server_driver_input(body: Node3D) -> Dictionary:
	var route := SERVER_DRIVER_LANE_ROUTE if _server_driver_lane else SERVER_DRIVER_ROUTE
	var waypoint: Vector2 = route[_server_driver_waypoint]
	var delta := Vector2(waypoint.x - body.global_position.x,
		waypoint.y - body.global_position.z)
	var cursor_distance := SERVER_DRIVER_LANE_CURSOR_DISTANCE if _server_driver_lane \
		else FOLLOW.MAX_DISTANCE
	return {"cursor_offset": delta.limit_length(cursor_distance),
		"burst": false, "editing": false}

func _service_server_driver_route(tick: int) -> void:
	if not _server_driver_enabled:
		return
	var body := _players.get_node_or_null("1") as RigidBody3D
	if body == null:
		return
	var home_limit := _home_half + 4.0 if _network_test_world_enabled \
		else SERVER_DRIVER_HOME_LIMIT
	if int(body.get("map_id")) != MAP_LAYOUT.CITY \
			or absf(body.global_position.x) > home_limit \
			or absf(body.global_position.z) > home_limit:
		_recover_server_driver(body, tick)
	var position := Vector2(body.global_position.x, body.global_position.z)
	var route := SERVER_DRIVER_LANE_ROUTE if _server_driver_lane else SERVER_DRIVER_ROUTE
	var waypoint: Vector2 = route[_server_driver_waypoint]
	var waypoint_radius := 3.0 if _server_driver_lane else SERVER_DRIVER_WAYPOINT_RADIUS
	if position.distance_to(waypoint) <= waypoint_radius:
		_server_driver_waypoint = (_server_driver_waypoint + 1) % route.size()
		_server_driver_progress_tick = tick
		_server_driver_progress_position = position
		waypoint = route[_server_driver_waypoint]
	elif _server_driver_progress_tick < 0 \
			or position.distance_to(_server_driver_progress_position) \
			>= SERVER_DRIVER_PROGRESS_DISTANCE:
		_server_driver_progress_tick = tick
		_server_driver_progress_position = position
	elif not _server_driver_lane \
			and tick - _server_driver_progress_tick >= SERVER_DRIVER_STUCK_TICKS:
		_server_driver_waypoint = (_server_driver_waypoint + 1) % route.size()
		_server_driver_progress_tick = tick
		_server_driver_progress_position = position
		waypoint = route[_server_driver_waypoint]
		_log("SERVER_DRIVER escape tick=%d next=%d" % [tick, _server_driver_waypoint])
	if tick % 60 == 0:
		_log("SERVER_DRIVER tick=%d waypoint=%d pos=(%.1f,%.1f) target=(%.1f,%.1f) speed=%.1f" % [
			tick, _server_driver_waypoint, position.x, position.y,
			waypoint.x, waypoint.y, body.linear_velocity.length()])

func _recover_server_driver(body: RigidBody3D, tick: int) -> void:
	var recovery_position := SERVER_DRIVER_LANE_SPAWN if _server_driver_lane \
		else SERVER_DRIVER_SPAWN
	body.set("map_id", MAP_LAYOUT.CITY)
	body.set("gate_cooldown", 0.0)
	body.position = Vector3(recovery_position.x,
		GROUND_BODY_Y, recovery_position.y)
	body.rotation = Vector3(0.0, PI if _server_driver_lane else -PI * 0.5, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false
	body.reset_physics_interpolation()
	_server_driver_waypoint = 1
	_server_driver_progress_tick = tick
	_server_driver_progress_position = recovery_position
	_log("SERVER_DRIVER recovered tick=%d reason=left-city" % tick)

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
		_track_server_motion_extents()
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
			_log(SERVER_RESULT.format_line({
				"players": _players.get_child_count(), "minpair": _minimum_pair_distance,
				"contact": 1 if _contact_seen else 0, "escapes": _server_escape_count(),
				"bumps": _server_bump_count(), "ballmax": _maximum_ball_speed,
				"maxy": _maximum_player_y, "landed": 1 if _course_landed else 0,
				"grounded": 1 if _course_ground_landed else 0,
				"rebound": _course_rebound_speed, "tilt": _course_landing_tilt,
				"maxtilt": _maximum_player_tilt, "minx": _minimum_player_x,
				"cloaked": _server_cloaked_count(), "shields": _server_shield_count(),
				"boosting": _server_boosting_count(), "tractorgrabs": _server_tractor_grabs(),
				"tractorticks": _server_tractor_ticks(), "shots": _combat_shot_count,
				"hits": _combat_hit_count, "ballhits": _combat_ball_hit_count,
				"droneshots": _drone_shot_count, "dets": _det_nullification_count,
				"impacthits": _server_impact_hits(), "shieldhits": _server_shield_hits(),
				"impactmax": _maximum_impact_speed, "rcshots": _rc_shot_count,
				"rcdets": _rc_detonation_count, "rchits": _rc_hit_count,
				"coursemaps": _server_course_map_count(), "courseoff": _server_course_off_count(),
				"gatetransitions": _server_gate_transition_count(),
			}))
		get_tree().quit()


func _send_settled_authority_probes() -> void:
	if not multiplayer.is_server() or _start_tick < 0:
		return
	var tick := NetworkTime.tick
	if tick == _last_authority_probe_tick or (tick - _start_tick) % 30 != 0:
		return
	_last_authority_probe_tick = tick
	var samples := {}
	for child in _players.get_children():
		var body := child as Node3D
		var peer_id := 0 if body == null else int(body.name)
		# after_loop is the settled post-replay seam used by StateBundle. Sampling
		# in on_tick compared the client against a pre-rollback server pose and
		# produced false corrections as large as the world width under TURN latency.
		if body != null and multiplayer.get_peers().has(peer_id):
			samples[peer_id] = body.position
	if not samples.is_empty():
		_authority_probe_queue.append({"tick": tick, "samples": samples})

## RC orbs are an event-driven, server-authored object family: only a small
## position/velocity record exists on the server, and presentation receives
## spawn/end events plus lightweight snapshots. They deliberately are not
## rollback rigid bodies; a player may only have one, so the cost remains
## bounded as the city gains ordinary physics objects.
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
		# back toward it. Keep its full motor speed so it can cross the city and
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
			if _segment_player_entry(position, finish, candidate, RC_ORB_RADIUS) <= 1.0:
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
		var distance := _planar_player_distance(position, target)
		if distance > RC_ORB_BLAST_RADIUS:
			continue
		var strength := clampf(1.0 - distance / RC_ORB_BLAST_RADIUS, 0.25, 1.0)
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
		if body == null or int(body.get("map_id")) != MAP_LAYOUT.CITY:
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
		if _planar_player_distance(position, player) > radius:
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

func _segment_player_entry(from: Vector3, to: Vector3, player: RigidBody3D,
		sweep_radius: float = 0.0) -> float:
	var collision := player.get_node_or_null("Collision") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		return IMPACT_CONTROLLER.segment_capsule_entry(from, to, collision.global_position,
			collision.global_basis * Vector3.UP, capsule.radius + sweep_radius,
			capsule.height + sweep_radius * 2.0)
	var radius := PLAYER_RADIUS + sweep_radius
	if collision != null and collision.shape is SphereShape3D:
		radius = (collision.shape as SphereShape3D).radius + sweep_radius
	return IMPACT_CONTROLLER.segment_sphere_entry(from, to, player.global_position, radius)

func _planar_player_distance(point: Vector3, player: RigidBody3D) -> float:
	var collision := player.get_node_or_null("Collision") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		return IMPACT_CONTROLLER.planar_capsule_distance(point, collision.global_position,
			collision.global_basis * Vector3.UP, capsule.radius, capsule.height)
	var radius := PLAYER_RADIUS
	if collision != null and collision.shape is SphereShape3D:
		radius = (collision.shape as SphereShape3D).radius
	return maxf(_planar_distance(point, player.global_position) - radius, 0.0)

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
	if target.is_in_group("city_ball"):
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
		if body == null or int(body.get("map_id")) != MAP_LAYOUT.CITY \
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
				var fraction := _segment_player_entry(start, finish, player)
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
				if target_hit.is_in_group("city_ball"):
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
				if target_hit.is_in_group("city_ball"):
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
	return 0

func _server_course_off_count() -> int:
	return 0

func _server_gate_transition_count() -> int:
	return 0

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
	if owner_id != multiplayer.get_unique_id():
		return
	if not _prediction_history.has(tick):
		var history_ticks: Array = _prediction_history.keys()
		var oldest := -1 if history_ticks.is_empty() else int(history_ticks.min())
		var newest := -1 if history_ticks.is_empty() else int(history_ticks.max())
		_log("AUTHORITY_PROBE_MISS tick=%d local_tick=%d history=%d..%d" % [
			tick, int(NetworkTime.tick), oldest, newest])
		return
	var predicted_position: Vector3 = _prediction_history[tick]
	var error := predicted_position.distance_to(authoritative_position)
	_worst_correction_error = maxf(_worst_correction_error, error)
	_log("CORRECTION tick=%d error=%.3f worst=%.3f" % [tick, error, _worst_correction_error])
	if error < CORRECTION_REPORT_FLOOR:
		return
	var current_tick := NetworkTime.tick
	var app: Dictionary = NetworkPerformance.get_app_telemetry_snapshot(current_tick)
	var route_state: Dictionary = StateBundle.route_state_snapshot(owner_id, current_tick)
	var local: Node3D = local_player()
	var contact_age := -1
	var map_transition_age := -1
	var local_position := Vector3.ZERO
	if local != null:
		local_position = local.global_position
		if local.has_method("correction_contact_age"):
			contact_age = int(local.call("correction_contact_age", current_tick))
		if local.has_method("correction_map_transition_age"):
			map_transition_age = int(local.call("correction_map_transition_age", current_tick))
	var presentation: Dictionary = RemotePositionTransport.presentation_snapshot()
	var frame_max := maxf(_frame_ms_current, _network_hud_frame_ms_max)
	var sample := {
		"run_id": _run_id,
		"distance": error,
		"before_position": _vector3_values(predicted_position),
		"after_position": _vector3_values(authoritative_position),
		"local_position_now": _vector3_values(local_position),
		"current_tick": current_tick,
		"source_tick": tick,
		"source_age_ticks": maxi(0, current_tick - tick),
		"applied_state_tick": int(route_state.get("applied_tick",
			app.get("state_newest_applied_tick", -1))),
		"applied_state_age_ticks": int(route_state.get("applied_age_ticks",
			app.get("state_applied_age_ticks", -1))),
		"pending_age_ticks": int(app.get("pending_age_max", 0)),
		"fresh_key_age_ticks": int(app.get("fresh_key_age_ticks", -1)),
		"fast_forward_age_ticks": int(app.get("fast_forward_age_ticks", -1)),
		"fresh_key_requests_total": int(app.get("fresh_key_requests_total", 0)),
		"fast_forwards_total": int(app.get("fast_forwards_total", 0)),
		"rollback_depth_ticks": maxi(0, current_tick - tick),
		"rollback_ticks_last": NetworkPerformance.get_rollback_ticks(),
		"rollback_ms_last": NetworkPerformance.get_rollback_loop_duration_ms(),
		"resimulation_debt_ticks": NetworkRollback.last_resim_debt,
		"history_start": NetworkRollback.history_start,
		"frame_ms_current": _frame_ms_current,
		"frame_ms_max": frame_max,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"contact_age_ticks": contact_age,
		"proxy_authority_distance": float(presentation.get(
			"predictive_offset_units", 0.0)),
		"proxy_authority_distance_max": float(presentation.get(
			"predictive_offset_max_units", 0.0)),
		"proxy_authority_longitudinal_lead": float(presentation.get(
			"predictive_lead_units", 0.0)),
		"map_transition_age_ticks": map_transition_age,
	}
	var signals: Array[String] = CORRECTION_CLASSIFIER.signals(sample)
	sample["signals"] = signals
	_correction_counts["corr"] = int(_correction_counts["corr"]) + 1
	for signal_name in signals:
		if _correction_counts.has(signal_name):
			_correction_counts[signal_name] = int(_correction_counts[signal_name]) + 1
	_log("CORRECTION_CAUSE %s" % JSON.stringify(sample))
	if _crash_telemetry != null:
		_crash_telemetry.call("record_event", "correction_cause", sample)


func _vector3_values(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

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

func _track_server_motion_extents() -> void:
	for child in _players.get_children():
		var body := child as RigidBody3D
		if body == null:
			continue
		_minimum_player_x = minf(_minimum_player_x, body.position.x)
		_maximum_player_y = maxf(_maximum_player_y, body.position.y)
		var upright := clampf(body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)
		_maximum_player_tilt = maxf(_maximum_player_tilt, rad_to_deg(acos(upright)))

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
