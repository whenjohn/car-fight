extends "res://addons/netfox.extras/physics/network-rigid-body-3d.gd"
## Server-owned Rapier body with client-owned input and local prediction.

const FOLLOW := preload("res://player/follow_controller.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const TRACTOR := preload("res://player/tractor_controller.gd")
const IMPACT := preload("res://player/impact_controller.gd")
const MAP_LAYOUT := preload("res://world/map_layout.gd")
const OIL_SLICK := preload("res://world/oil_slick.gd")
const REMOTE_POSITION_VALIDATION := preload("res://net/remote_position_validation.gd")
const REMOTE_SNAPSHOT_INTERPOLATION := preload("res://net/remote_snapshot_interpolation.gd")
const SERVER_DRIVER_COLLISION := preload("res://player/server_driver_collision.gd")
const REMOTE_COLLISION_PHASE := preload("res://player/remote_collision_phase.gd")
const LOCAL_PRESENTATION := preload("res://player/local_presentation.gd")

const DET_ZONE_RADIUS := 3.6
const DET_GROW_TIME := 0.08

var owner_id := 0
var input_authority_id := 0
var spawn_slot := 0
var is_ramming_drone := false
var vehicle_visual_index := 0
var vehicle_model_scale := 1.0
var vehicle_collider_scale := 1.0
var vehicle_mass := VEHICLE_CONFIG.MASS
var aim := Vector3(0.0, 0.0, -1.0)
var burst_turn_sign := 0.0
var boost_active := false
var brake_skid_amount := 0.0
var drift_assist_amount := 0.0
var drift_assist_charge := 0.0
var drift_assist_side := 0.0
var drift_assist_hold := 0.0
var drift_assist_latched := false
var drift_assist_rearm_ready := true
var oil_slick_amount := 0.0
var is_cloaked := false
var cloak_held_prev := false
var shield_up := false
var shield_held_prev := false
var det_t := 0.0
var impact_recovery_time := 0.0
var impact_hit_count := 0
var shield_hit_count := 0
var tractor_ball_held := false
var tractor_grab_count := 0
var tractor_reel_ticks := 0
var collision_stall_time := 0.0
var collision_escape_time := 0.0
var collision_escape_sign := 0.0
var collision_escape_count := 0
var wall_bump_cooldown := 0.0
var wall_bump_count := 0
var was_supported := false
var landing_fall_speed := 0.0
var landing_jostle_cooldown := 0.0
var map_id := MAP_LAYOUT.CITY
var remote_state_generation := 0
var gate_cooldown := 0.0
var gate_transition_count := 0
var area_weapon_armed := false
var area_arm_held_prev := false
var area_gesture_active := false
var area_gesture_start := Vector3.ZERO
var area_gesture_end := Vector3.ZERO
var area_strike_serial := 0
var rc_pilot_active := false
var disable_collision_escape := false
var local_presentation_smoothing := false

@onready var _input := get_node("Input")
@onready var _sync := get_node_or_null("RollbackSynchronizer")
@onready var _interpolator := get_node_or_null("TickInterpolator")
var _cursor_marker: Node3D
var _max_speed_marker: Node3D
var _cursor_line: Node3D
var _cursor_line_material: StandardMaterial3D
var _cursor_line_color := Color.WHITE
var _tractor_ring: Node3D
var _tractor_rope: Node3D
var _pending_linear_impulse := Vector3.ZERO
var _pending_torque_impulse := Vector3.ZERO
var _pending_recovery_time := 0.0
var _pending_impact_hits := 0
var _pending_shield_hits := 0
var _is_local := false
var _remote_position_relevant := true
var _remote_position_presented := true
var _remote_state_last_tick := -1
var _remote_state_min_tick := -1
var _remote_samples := {}
var _remote_rotation_samples := {}
var _remote_latest_linear_velocity := Vector3.ZERO
var _remote_latest_angular_velocity := Vector3.ZERO
var _remote_render_tick := 0.0
var _remote_render_tick_initialized := false
var _remote_interp_last_desired_tick := 0.0
var _remote_interp_clock_backsteps := 0
var _remote_interp_warmup_samples := 0
var _remote_visual_root: Node3D
var _remote_visual_local_transform := Transform3D.IDENTITY
var _remote_peer_marker: Node3D
var _remote_peer_marker_local_transform := Transform3D.IDENTITY
var _remote_peer_marker_allowed_visible := true
var _remote_collision_proxy: AnimatableBody3D
var _remote_collision_proxy_shape: CollisionShape3D
var _remote_collision_debug: MeshInstance3D
var _gameplay_collision_debug: MeshInstance3D
var _remote_source_collision: CollisionShape3D
var _remote_collision_proxy_enabled := false
var _remote_collision_proxy_in_rollback := false
var _remote_collision_rollback_signals_connected := false
var _last_server_driver_contact_tick := -1
var _last_map_transition_tick := -1
var _remote_predictive_pose := Transform3D.IDENTITY
var _remote_predictive_pose_initialized := false
var _local_presented_pose := Transform3D.IDENTITY
var _local_presented_pose_initialized := false
var _local_presentation_offset := 0.0
var _local_presentation_offset_max := 0.0
var _local_presentation_snaps := 0
const REMOTE_INTERP_MS := 75.0
const REMOTE_EXTRAPOLATE_MS := 50.0
const REMOTE_INTERP_CLOCK_RESET_TICKS := 30.0
const REMOTE_PREDICTION_TELEPORT_DISTANCE := 30.0

func set_gameplay_collision_debug_visible(enabled: bool) -> void:
	if enabled and not is_instance_valid(_gameplay_collision_debug):
		var source := get_node_or_null("Collision") as CollisionShape3D
		if source == null or source.shape == null:
			return
		_gameplay_collision_debug = MeshInstance3D.new()
		_gameplay_collision_debug.name = "GameplayCollisionDebug"
		_gameplay_collision_debug.transform = source.transform
		if source.shape is CapsuleShape3D:
			_gameplay_collision_debug.mesh = SERVER_DRIVER_COLLISION.debug_mesh(
				source.shape as CapsuleShape3D)
		elif source.shape is SphereShape3D:
			var sphere := SphereMesh.new()
			var shape := source.shape as SphereShape3D
			sphere.radius = shape.radius
			sphere.height = shape.radius * 2.0
			sphere.radial_segments = 24
			sphere.rings = 12
			_gameplay_collision_debug.mesh = sphere
		else:
			_gameplay_collision_debug = null
			return
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.10, 0.95, 1.0, 0.24)
		material.emission_enabled = true
		material.emission = Color(0.05, 0.65, 0.78)
		material.emission_energy_multiplier = 0.55
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_gameplay_collision_debug.material_override = material
		_gameplay_collision_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_gameplay_collision_debug)
	if is_instance_valid(_gameplay_collision_debug):
		_gameplay_collision_debug.visible = enabled

func _ready() -> void:
	add_to_group("pilotable")
	owner_id = int(name)
	set_multiplayer_authority(1)
	if input_authority_id == 0:
		input_authority_id = owner_id
	_input.set_multiplayer_authority(input_authority_id)
	if _sync != null:
		_sync.root = self
		_sync.enable_prediction = true
		var state_bundle := get_node_or_null("/root/StateBundle")
		_sync.enable_input_broadcast = true if state_bundle == null \
			else bool(state_bundle.get("input_broadcast"))
		_sync.add_state(self, "physics_state")
		_sync.add_state(self, "burst_turn_sign")
		_sync.add_state(self, "boost_active")
		_sync.add_state(self, "brake_skid_amount")
		_sync.add_state(self, "drift_assist_amount")
		_sync.add_state(self, "drift_assist_charge")
		_sync.add_state(self, "drift_assist_side")
		_sync.add_state(self, "drift_assist_hold")
		_sync.add_state(self, "drift_assist_latched")
		_sync.add_state(self, "drift_assist_rearm_ready")
		_sync.add_state(self, "oil_slick_amount")
		_sync.add_state(self, "is_cloaked")
		_sync.add_state(self, "cloak_held_prev")
		_sync.add_state(self, "shield_up")
		_sync.add_state(self, "shield_held_prev")
		_sync.add_state(self, "det_t")
		_sync.add_state(self, "impact_recovery_time")
		_sync.add_state(self, "impact_hit_count")
		_sync.add_state(self, "shield_hit_count")
		_sync.add_state(self, "tractor_ball_held")
		_sync.add_state(self, "tractor_grab_count")
		_sync.add_state(self, "tractor_reel_ticks")
		_sync.add_state(self, "collision_stall_time")
		_sync.add_state(self, "collision_escape_time")
		_sync.add_state(self, "collision_escape_sign")
		_sync.add_state(self, "collision_escape_count")
		_sync.add_state(self, "wall_bump_cooldown")
		_sync.add_state(self, "wall_bump_count")
		_sync.add_state(self, "was_supported")
		_sync.add_state(self, "landing_fall_speed")
		_sync.add_state(self, "landing_jostle_cooldown")
		_sync.add_state(self, "map_id")
		_sync.add_state(self, "gate_cooldown")
		_sync.add_state(self, "gate_transition_count")
		_sync.add_input(_input, "cursor_offset")
		_sync.add_input(_input, "burst")
		_sync.add_input(_input, "reverse")
		_sync.add_input(_input, "cloak_held")
		_sync.add_input(_input, "shield_held")
		_sync.add_input(_input, "det")
		_sync.add_input(_input, "area_arm_held")
		_sync.add_input(_input, "area_fire")
		_sync.add_input(_input, "homing_held")
		_sync.add_input(_input, "rc_fire_held")
		_sync.add_input(_input, "rc_detonate_held")
		_sync.add_input(_input, "drop_troops")
		_sync.add_input(_input, "tractor")
		_sync.add_input(_input, "editing")
		_sync.process_settings()

	_is_local = owner_id == multiplayer.get_unique_id()
	if _is_local and local_presentation_smoothing:
		# Presentation must run before Main samples the local camera anchor.
		process_priority = -10
		_ensure_remote_visual_roots()
	if _interpolator != null and not multiplayer.is_server() and not _is_local:
		_interpolator.root = self
		_interpolator.add_property(self, "global_transform")
	elif _interpolator != null:
		_interpolator.enabled = false
	if _is_local:
		_cursor_marker = get_node_or_null("CursorMarker")
		_max_speed_marker = get_node_or_null("MaxSpeedMarker")
		_cursor_line = get_node_or_null("CursorLine")
		_tractor_ring = get_node_or_null("TractorCatchRing")
		if _cursor_line != null:
			_cursor_line_material = _cursor_line.get("material_override") as StandardMaterial3D
			if _cursor_line_material != null:
				_cursor_line_color = _cursor_line_material.albedo_color
	_tractor_rope = get_node_or_null("TractorRope")
	var remote_transport := get_node_or_null("/root/RemotePositionTransport")
	if remote_position_transport_controlled() and remote_transport != null \
			and not bool(remote_transport.call("body_starts_remote_position_relevant")):
		_remote_position_relevant = false
		_remote_position_presented = false
		_ensure_remote_visual_roots()
		_apply_remote_position_visibility()

func _physics_rollback_tick(delta: float, tick: int) -> void:
	if direct_state == null:
		return
	var queued_linear_impulse := Vector3.ZERO
	var queued_torque_impulse := Vector3.ZERO
	_service_cloak_toggle(bool(_input.cloak_held))
	_service_shield_toggle(bool(_input.shield_held))
	_service_det(delta)
	_service_area_weapon()
	var rollback := get_node_or_null("/root/NetworkRollback")
	if rollback != null and bool(rollback.call("is_rollback")):
		impact_recovery_time = maxf(impact_recovery_time - delta, 0.0)
		if not _pending_linear_impulse.is_zero_approx() \
				or not _pending_torque_impulse.is_zero_approx():
			queued_linear_impulse = _pending_linear_impulse
			queued_torque_impulse = _pending_torque_impulse
			_pending_linear_impulse = Vector3.ZERO
			_pending_torque_impulse = Vector3.ZERO
			impact_recovery_time = maxf(impact_recovery_time, _pending_recovery_time)
			_pending_recovery_time = 0.0
			impact_hit_count += _pending_impact_hits
			shield_hit_count += _pending_shield_hits
			_pending_impact_hits = 0
			_pending_shield_hits = 0
	# The vacuum is independent of navigation: Shift never changes the mouse's
	# normal FOLLOW direction or speed command.
	var offset: Vector2 = Vector2.ZERO if _input.editing or rc_pilot_active else _input.cursor_offset
	var velocity: Vector3 = direct_state.linear_velocity
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	landing_jostle_cooldown = maxf(landing_jostle_cooldown - delta, 0.0)
	var support_normal := _static_support_normal()
	var touching_support := not support_normal.is_zero_approx()
	var oil_footprint := OIL_SLICK.footprint_strength(map_id,
		direct_state.transform.origin)
	oil_slick_amount = OIL_SLICK.next_amount(oil_slick_amount, oil_footprint,
		touching_support, planar_speed, delta)
	var landing_torque_impulse := Vector3.ZERO
	if touching_support:
		if not was_supported and landing_jostle_cooldown <= 0.0:
			landing_torque_impulse = FOLLOW.landing_torque_impulse(
				velocity, support_normal, landing_fall_speed, mass)
			if not landing_torque_impulse.is_zero_approx():
				landing_jostle_cooldown = FOLLOW.LANDING_JOSTLE_COOLDOWN
		landing_fall_speed = 0.0
	else:
		landing_fall_speed = maxf(landing_fall_speed, maxf(-velocity.y, 0.0))
	was_supported = touching_support
	var current_yaw := FOLLOW.heading_yaw(direct_state.transform.basis)
	var burst_requested: bool = _input.burst and not _input.editing and not is_cloaked and not rc_pilot_active
	var reverse_requested: bool = _input.reverse and not _input.editing and not rc_pilot_active
	var probe := FOLLOW.command(offset, current_yaw, burst_requested, burst_turn_sign,
		planar_speed, reverse_requested, touching_support, drift_assist_charge)
	var assist_sustain := FOLLOW.automatic_drift_assist_sustain(
		float(probe["brake_skid_amount"]), float(probe["heading_error"]))
	var assist_state := FOLLOW.next_drift_assist_state(drift_assist_hold,
		drift_assist_latched, drift_assist_side, drift_assist_rearm_ready,
		float(probe["drift_assist_amount"]) * 4.0, float(probe["heading_error"]),
		float(probe["throttle"]), burst_requested, reverse_requested,
		touching_support, planar_speed, assist_sustain, delta)
	drift_assist_hold = float(assist_state["hold"])
	drift_assist_latched = bool(assist_state["latched"])
	drift_assist_side = float(assist_state["side"])
	drift_assist_rearm_ready = bool(assist_state["rearm_ready"])
	var command := FOLLOW.command(offset, current_yaw, burst_requested, burst_turn_sign,
		planar_speed, reverse_requested, touching_support, drift_assist_charge,
		drift_assist_latched, drift_assist_side)
	burst_turn_sign = command["burst_turn_sign"]
	boost_active = bool(command["boost_active"])
	brake_skid_amount = float(command["brake_skid_amount"])
	drift_assist_amount = float(command["drift_assist_amount"])
	drift_assist_charge = FOLLOW.next_drift_assist_charge(drift_assist_charge,
		drift_assist_amount if drift_assist_latched else 0.0, delta)
	if drift_assist_charge <= 0.001:
		drift_assist_side = 0.0
	var fallback_sign := 1.0 if owner_id % 2 == 0 else -1.0
	var forward: Vector3 = -direct_state.transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	wall_bump_cooldown = maxf(wall_bump_cooldown - delta, 0.0)
	var bump_started := false
	var bump_linear_impulse := Vector3.ZERO
	var bump_yaw_impulse := 0.0
	var wall_normal := _static_contact_normal()
	var touching_static := not wall_normal.is_zero_approx()
	var touching_player := _touching_player_body()
	if _touching_server_driver_collision():
		_last_server_driver_contact_tick = tick
	if wall_bump_cooldown <= 0.0 and touching_static:
		var preferred_sign := signf(float(command["heading_error"])) \
			if absf(float(command["heading_error"])) >= FOLLOW.ESCAPE_STEER_EPSILON \
			else fallback_sign
		var bump := FOLLOW.wall_bump(forward, velocity, wall_normal, preferred_sign, mass)
		if bool(bump["active"]):
			wall_bump_cooldown = FOLLOW.WALL_BUMP_COOLDOWN
			bump_linear_impulse = bump["linear_impulse"]
			bump_yaw_impulse = bump["yaw_impulse"]
			wall_bump_count += 1
			bump_started = true
	var escape: Dictionary
	if disable_collision_escape or touching_static or not touching_player \
			or (_input.reverse and not _input.editing):
		# Static contacts use Rapier plus the one-shot impulses above. The timed
		# escape assist is reserved for cars wedged against other moving cars.
		escape = {"stall_time": 0.0, "escape_time": 0.0, "escape_sign": 0.0,
			"active": false, "started": false}
	else:
		# World speed can remain high when one car pushes another. Measure motion
		# along this driver's requested direction so the losing car still peels
		# away, without mistaking a free powerslide for a collision stall.
		var requested_direction := forward * float(command["drive_sign"])
		var requested_progress := maxf(Vector3(velocity.x, 0.0, velocity.z).dot(
			requested_direction), 0.0)
		escape = FOLLOW.collision_escape(float(command["speed"]), requested_progress,
			float(command["heading_error"]), collision_stall_time, collision_escape_time,
			collision_escape_sign, delta, fallback_sign)
	collision_stall_time = escape["stall_time"]
	collision_escape_time = escape["escape_time"]
	collision_escape_sign = escape["escape_sign"]
	if bool(escape["started"]):
		collision_escape_count += 1
	if offset.length_squared() > 0.0001:
		aim = Vector3(offset.x, 0.0, offset.y).normalized()
	var drive_direction := FOLLOW.escape_drive_direction(forward, collision_escape_sign) \
		if bool(escape["active"]) else forward
	var target_velocity: Vector3 = drive_direction * float(command["speed"]) \
		* float(command["drive_sign"])
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var impact_acceleration_scale := IMPACT.acceleration_scale(impact_recovery_time)
	horizontal = horizontal.move_toward(target_velocity,
		float(command["acceleration"]) * impact_acceleration_scale \
		* OIL_SLICK.grip_scale(oil_slick_amount) * delta)
	horizontal = FOLLOW.drift_carve_velocity(horizontal, drift_assist_side,
		drift_assist_amount * OIL_SLICK.drift_assist_scale(oil_slick_amount),
		drift_assist_charge, delta)
	if bool(escape["started"]):
		horizontal += drive_direction * FOLLOW.ESCAPE_SIDE_KICK
	var current_yaw_rate: float = direct_state.angular_velocity.y
	var target_yaw_rate := collision_escape_sign * FOLLOW.ESCAPE_YAW_RATE \
		if bool(escape["active"]) else float(command["yaw_rate"])
	var yaw_acceleration := FOLLOW.ESCAPE_YAW_ACCEL \
		if bool(escape["active"]) else float(command["yaw_acceleration"])
	var yaw_rate: float
	if not bool(escape["active"]):
		var oil_axle := OIL_SLICK.axle_response(horizontal, forward,
			target_yaw_rate, current_yaw_rate, yaw_acceleration, planar_speed,
			oil_slick_amount, delta)
		horizontal = oil_axle["planar_velocity"]
		yaw_rate = float(oil_axle["yaw_rate"])
	else:
		yaw_rate = move_toward(current_yaw_rate, target_yaw_rate,
			yaw_acceleration * delta)
	direct_state.linear_velocity = FOLLOW.compose_drive_velocity(horizontal, velocity.y)
	direct_state.angular_velocity = FOLLOW.compose_drive_angular_velocity(
		direct_state.angular_velocity, yaw_rate)
	direct_state.apply_torque(FOLLOW.upright_torque(direct_state.transform.basis,
		direct_state.angular_velocity, mass) * IMPACT.upright_scale(impact_recovery_time))
	if bump_started:
		direct_state.apply_central_impulse(bump_linear_impulse)
		direct_state.apply_torque_impulse(Vector3.UP * bump_yaw_impulse)
	if not landing_torque_impulse.is_zero_approx():
		direct_state.apply_torque_impulse(landing_torque_impulse)
	_service_tractor(delta)
	# Navigation writes explicit planar velocity above. Apply external hits last
	# so that write cannot erase Rapier's queued impulse before the space step.
	if not queued_linear_impulse.is_zero_approx():
		direct_state.apply_central_impulse(queued_linear_impulse)
	if not queued_torque_impulse.is_zero_approx():
		direct_state.apply_torque_impulse(queued_torque_impulse)


func _static_contact_normal() -> Vector3:
	for index in range(direct_state.get_contact_count()):
		var collider := direct_state.get_contact_collider_object(index)
		if collider is StaticBody3D:
			var normal: Vector3 = direct_state.get_contact_local_normal(index)
			# Ground and upward-facing city geometry support the car vertically; only
			# near-vertical faces should produce a horizontal wall bump.
			if absf(normal.y) > 0.45:
				continue
			normal.y = 0.0
			if not normal.is_zero_approx():
				return normal.normalized()
	return Vector3.ZERO

func _touching_player_body() -> bool:
	for index in range(direct_state.get_contact_count()):
		var collider := direct_state.get_contact_collider_object(index) as RigidBody3D
		if collider != null and collider.get_parent() == get_parent():
			return true
	return false


func _touching_server_driver_collision() -> bool:
	for index in range(direct_state.get_contact_count()):
		var collider := direct_state.get_contact_collider_object(index)
		if collider is AnimatableBody3D and str(collider.name) == "RemoteCollisionProxy":
			return true
		if collider is RigidBody3D and collider.get_parent() == get_parent() \
				and int(collider.get("owner_id")) == 1:
			return true
	return false


func correction_contact_age(current_tick: int) -> int:
	return -1 if _last_server_driver_contact_tick < 0 else maxi(0,
		current_tick - _last_server_driver_contact_tick)


func correction_map_transition_age(current_tick: int) -> int:
	return -1 if _last_map_transition_tick < 0 else maxi(0,
		current_tick - _last_map_transition_tick)


func _service_cloak_toggle(held: bool) -> void:
	# The wire carries a held level. Only real input transitions write the
	# rollback edge detector, so holding R produces exactly one toggle.
	if held == cloak_held_prev:
		return
	cloak_held_prev = held
	if held:
		is_cloaked = not is_cloaked
		if is_cloaked:
			shield_up = false
			det_t = 0.0

func _service_shield_toggle(held: bool) -> void:
	if held == shield_held_prev:
		return
	shield_held_prev = held
	if held:
		if shield_up:
			shield_up = false
		elif not is_cloaked:
			shield_up = true

func _service_det(delta: float) -> void:
	# Unlike the shield's toggle, det is a held defensive field. Keep its grow
	# timer rollback state so every peer evaluates the same projectile boundary.
	if bool(_input.det) and not bool(_input.editing) and not is_cloaked:
		det_t = minf(det_t + delta, DET_GROW_TIME)
	else:
		det_t = 0.0

func det_radius() -> float:
	return DET_ZONE_RADIUS * clampf(det_t / DET_GROW_TIME, 0.0, 1.0)

func _service_area_weapon() -> void:
	# Explicit slot-3 edge, stored as rollback state: a held key toggles once on
	# every participant's identical input timeline.
	if bool(_input.area_arm_held) != area_arm_held_prev:
		area_arm_held_prev = bool(_input.area_arm_held)
		if area_arm_held_prev:
			area_weapon_armed = not area_weapon_armed
			area_gesture_active = false
	if not area_weapon_armed or bool(_input.editing):
		area_gesture_active = false
		return
	var cursor := Vector3(global_position.x + _input.cursor_offset.x, 0.0,
		global_position.z + _input.cursor_offset.y)
	if bool(_input.area_fire):
		if not area_gesture_active:
			area_gesture_active = true
			area_gesture_start = cursor
		area_gesture_end = cursor
		return
	if area_gesture_active:
		area_gesture_active = false
		area_gesture_end = cursor
		area_strike_serial += 1
		# Splash is a one-shot call-in. Stow it on release so the regular
		# coverage/auto-fire weapon resumes while the aircraft is still inbound.
		area_weapon_armed = false

## Cross-body hit commands arrive after this body's current tick. Queue them
## until its own rollback simulation owns a live direct_state, as the tractor
## already does for the city ball.
func apply_external_impact(linear_impulse: Vector3, torque_impulse: Vector3,
		recovery_time: float, shielded: bool) -> void:
	_pending_linear_impulse += linear_impulse
	_pending_torque_impulse += torque_impulse
	_pending_recovery_time = maxf(_pending_recovery_time, recovery_time)
	_pending_impact_hits += 1
	if shielded:
		_pending_shield_hits += 1

func _service_tractor(delta: float) -> void:
	if not bool(_input.tractor) or bool(_input.editing) or is_cloaked or rc_pilot_active:
		tractor_ball_held = false
		return
	var origin: Vector3 = direct_state.transform.origin
	var pulled_any := false
	for target_node in get_tree().get_nodes_in_group("tractorable"):
		var target := target_node as RigidBody3D
		if target == null or not target.has_method("apply_external_impulse") \
				or not target.has_method("tractor_radius"):
			continue
		var target_radius := float(target.call("tractor_radius"))
		if not TRACTOR.can_pull(origin, target.global_position, target_radius):
			continue
		if not tractor_ball_held and not pulled_any:
			tractor_grab_count += 1
		var target_velocity: Vector3 = target.linear_velocity
		var pull := TRACTOR.reel(origin, direct_state.linear_velocity, mass,
			target.global_position, target_velocity, target.mass,
			VEHICLE_CONFIG.COLLISION_RADIUS, target_radius, delta)
		target.call("apply_external_impulse", pull["target_impulse"])
		direct_state.apply_central_impulse(pull["origin_impulse"])
		tractor_reel_ticks += 1
		pulled_any = true
	tractor_ball_held = pulled_any

func set_rc_pilot_active(active: bool) -> void:
	rc_pilot_active = active
	if active:
		tractor_ball_held = false

func _city_ball() -> Node:
	var balls := get_node_or_null("/root/Main/Balls")
	if balls == null or balls.get_child_count() == 0:
		return null
	return balls.get_child(0) as RigidBody3D

func _static_support_normal() -> Vector3:
	for index in range(direct_state.get_contact_count()):
		var collider := direct_state.get_contact_collider_object(index)
		if collider is StaticBody3D:
			var normal: Vector3 = direct_state.get_contact_local_normal(index)
			if absf(normal.y) > 0.45:
				if normal.y < 0.0:
					normal = -normal
				return normal.normalized()
	return Vector3.ZERO


func remote_position_transport_controlled() -> bool:
	return not multiplayer.is_server() and not _is_local


func _remote_collision_proxy_candidate() -> bool:
	# Networking-1 uses the server-owned peer-1 Jeep as its controlled visual
	# indicator. Do not generalize this experimental collision model to actual
	# remote players: independently predicted player proxies changed collision
	# timing and produced double-digit local corrections in the two-peer gate.
	return remote_position_transport_controlled() and owner_id == 1


func is_remote_position_relevant() -> bool:
	return true if not remote_position_transport_controlled() else _remote_position_relevant


func set_remote_position_relevant(relevant: bool, tick: int) -> void:
	if not remote_position_transport_controlled() or relevant == _remote_position_relevant:
		return
	_remote_position_relevant = relevant
	_remote_position_presented = false
	_remote_samples.clear()
	_remote_rotation_samples.clear()
	_remote_latest_linear_velocity = Vector3.ZERO
	_remote_latest_angular_velocity = Vector3.ZERO
	_remote_render_tick_initialized = false
	_remote_predictive_pose_initialized = false
	_remote_interp_last_desired_tick = 0.0
	_remote_interp_warmup_samples = 0
	_remote_state_min_tick = maxi(_remote_state_min_tick, tick if not relevant else tick - 1)
	_ensure_remote_visual_roots()
	_apply_remote_position_visibility()


func receive_remote_position(generation: int, tick: int, position: Vector3,
		rotation: Quaternion = Quaternion.IDENTITY,
		linear_velocity: Vector3 = Vector3.ZERO,
		angular_velocity: Vector3 = Vector3.ZERO) -> bool:
	if not REMOTE_POSITION_VALIDATION.accepts_body_sample(multiplayer.is_server(), _is_local,
			remote_state_generation, _remote_state_last_tick, _remote_state_min_tick,
			generation, tick):
		return false
	_remote_state_last_tick = tick
	_remote_latest_linear_velocity = linear_velocity
	_remote_latest_angular_velocity = angular_velocity
	_remote_interp_warmup_samples += 1
	var network_time := get_node_or_null("/root/NetworkTime")
	var current_tick := tick if network_time == null else int(network_time.get("tick"))
	REMOTE_SNAPSHOT_INTERPOLATION.insert_bounded(
		_remote_samples, tick, position, maxi(current_tick, tick), 64)
	REMOTE_SNAPSHOT_INTERPOLATION.insert_bounded(
		_remote_rotation_samples, tick, rotation.normalized(), maxi(current_tick, tick), 64)
	if not _remote_position_presented:
		_remote_position_presented = true
		_apply_remote_position_visibility()
	return true


func _ensure_remote_visual_roots() -> void:
	if _remote_visual_root != null or _is_headless_presentation() \
			or not is_inside_tree():
		return
	_remote_visual_root = get_node_or_null("GroundVehicleHull") as Node3D
	if _remote_visual_root == null:
		return
	if not _remote_visual_root.is_inside_tree():
		_remote_visual_root = null
		return
	_remote_visual_local_transform = _remote_visual_root.transform
	var world_transform := _remote_visual_root.global_transform
	_remote_visual_root.top_level = true
	_remote_visual_root.global_transform = world_transform


func _apply_remote_position_visibility() -> void:
	if is_instance_valid(_remote_visual_root):
		_remote_visual_root.visible = _remote_position_presented
	if is_instance_valid(_remote_peer_marker):
		_remote_peer_marker.visible = _remote_position_presented \
			and _remote_peer_marker_allowed_visible
	if is_instance_valid(_remote_collision_debug):
		_remote_collision_debug.visible = _remote_position_presented
	_apply_remote_collision_phase(_remote_collision_proxy_in_rollback, true)


func _connect_remote_collision_rollback_signals() -> void:
	if _remote_collision_rollback_signals_connected:
		return
	var rollback := get_node_or_null("/root/NetworkRollback")
	if rollback == null:
		return
	rollback.before_loop.connect(_before_remote_collision_rollback)
	rollback.after_loop.connect(_after_remote_collision_rollback)
	_remote_collision_rollback_signals_connected = true


func _before_remote_collision_rollback() -> void:
	if not _remote_collision_proxy_enabled:
		return
	_remote_collision_proxy_in_rollback = true
	# before_loop runs outside the physics step, so direct shape changes are safe
	# and take effect before Rapier advances the first replay tick.
	_apply_remote_collision_phase(true, false)


func _after_remote_collision_rollback() -> void:
	if not _remote_collision_proxy_enabled:
		return
	_remote_collision_proxy_in_rollback = false
	_apply_remote_collision_phase(false, false)


func _apply_remote_collision_phase(in_rollback: bool, deferred: bool) -> void:
	var disabled := REMOTE_COLLISION_PHASE.disabled_states(
		_remote_collision_proxy_enabled, in_rollback, _remote_position_presented)
	if is_instance_valid(_remote_source_collision):
		if deferred:
			_remote_source_collision.set_deferred("disabled", bool(disabled["source"]))
		else:
			_remote_source_collision.disabled = bool(disabled["source"])
	if is_instance_valid(_remote_collision_proxy_shape):
		if deferred:
			_remote_collision_proxy_shape.set_deferred("disabled", bool(disabled["proxy"]))
		else:
			_remote_collision_proxy_shape.disabled = bool(disabled["proxy"])


func _set_remote_collision_proxy_enabled(enabled: bool) -> void:
	if not remote_position_transport_controlled():
		return
	if enabled == _remote_collision_proxy_enabled:
		return
	_remote_collision_proxy_enabled = enabled
	if _remote_source_collision == null:
		_remote_source_collision = get_node_or_null("Collision") as CollisionShape3D
	if enabled and _remote_collision_proxy == null:
		_remote_collision_proxy = AnimatableBody3D.new()
		_remote_collision_proxy.name = "RemoteCollisionProxy"
		_remote_collision_proxy.sync_to_physics = true
		_remote_collision_proxy.collision_layer = collision_layer
		_remote_collision_proxy.collision_mask = collision_mask
		add_child(_remote_collision_proxy)
		_remote_collision_proxy.top_level = true
		_remote_collision_proxy.global_transform = global_transform
		_remote_collision_proxy_shape = CollisionShape3D.new()
		_remote_collision_proxy_shape.name = "Collision"
		if _remote_source_collision != null and _remote_source_collision.shape != null:
			_remote_collision_proxy_shape.shape = _remote_source_collision.shape.duplicate()
			_remote_collision_proxy_shape.transform = _remote_source_collision.transform
		else:
			SERVER_DRIVER_COLLISION.configure(_remote_collision_proxy_shape)
		_remote_collision_proxy.add_child(_remote_collision_proxy_shape)
		if _remote_collision_proxy_shape.shape is CapsuleShape3D:
			_remote_collision_debug = MeshInstance3D.new()
			_remote_collision_debug.name = "ServerDriverCollisionDebug"
			_remote_collision_debug.mesh = SERVER_DRIVER_COLLISION.debug_mesh(
				_remote_collision_proxy_shape.shape as CapsuleShape3D)
			_remote_collision_debug.transform = _remote_collision_proxy_shape.transform
			var debug_material := StandardMaterial3D.new()
			debug_material.albedo_color = Color(0.10, 0.95, 1.0, 0.24)
			debug_material.emission_enabled = true
			debug_material.emission = Color(0.05, 0.65, 0.78)
			debug_material.emission_energy_multiplier = 0.55
			debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_remote_collision_debug.material_override = debug_material
			_remote_collision_debug.cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_remote_collision_proxy.add_child(_remote_collision_debug)
		print("[remote-collision-proxy] enabled body=%d shape=%s source=disabled server_authority=preserved" % [
			owner_id, _remote_collision_proxy_shape.shape.get_class()])
	_connect_remote_collision_rollback_signals()
	_apply_remote_collision_phase(false, true)
	if enabled:
		if _remote_peer_marker == null:
			_remote_peer_marker = get_node_or_null("PeerMarker") as Node3D
			if _remote_peer_marker != null:
				_remote_peer_marker_allowed_visible = _remote_peer_marker.visible
				_remote_peer_marker_local_transform = _remote_peer_marker.transform
				var marker_world := _remote_peer_marker.global_transform
				_remote_peer_marker.top_level = true
				_remote_peer_marker.global_transform = marker_world
	elif _remote_peer_marker != null and _remote_peer_marker.top_level:
		_remote_peer_marker.top_level = false
		_remote_peer_marker.transform = _remote_peer_marker_local_transform


func _process_remote_position(delta: float) -> void:
	if not is_inside_tree() or not remote_position_transport_controlled():
		return
	var remote_transport := get_node_or_null("/root/RemotePositionTransport")
	var presentation_mode := "fixed" if remote_transport == null \
		else str(remote_transport.call("presentation_mode"))
	var proxy_active := presentation_mode == "proxy" \
		and _remote_collision_proxy_candidate()
	_set_remote_collision_proxy_enabled(proxy_active)
	if not _remote_position_relevant or _remote_samples.is_empty():
		return
	_ensure_remote_visual_roots()
	var network_time := get_node_or_null("/root/NetworkTime")
	if network_time == null:
		return
	var rate := float(network_time.get("tickrate"))
	var selected_delay_msec := REMOTE_INTERP_MS
	if remote_transport != null:
		selected_delay_msec = float(remote_transport.call("presentation_delay_msec"))
	var current_tick := float(network_time.get("tick")) \
		+ float(network_time.get("tick_factor"))
	if presentation_mode == "proxy":
		if proxy_active:
			_process_proxy_presentation(delta, current_tick, rate, remote_transport)
		else:
			_process_predictive_presentation(delta, current_tick, rate)
		return
	if presentation_mode == "predictive":
		_process_predictive_presentation(delta, current_tick, rate)
		return
	var desired_tick := current_tick \
		- selected_delay_msec / 1000.0 * rate
	var rebased_this_frame := false
	if not _remote_render_tick_initialized:
		_remote_render_tick = desired_tick
		_remote_interp_last_desired_tick = desired_tick
		_remote_render_tick_initialized = true
	else:
		if desired_tick < _remote_interp_last_desired_tick:
			_remote_interp_clock_backsteps += 1
		_remote_interp_last_desired_tick = desired_tick
		if absf(desired_tick - _remote_render_tick) > REMOTE_INTERP_CLOCK_RESET_TICKS:
			# A resumed browser can resynchronize outside the retained history. Rebase once and
			# require fresh publications before this body contributes adaptive pressure again.
			_remote_render_tick = desired_tick
			_remote_interp_warmup_samples = 0
			rebased_this_frame = true
		else:
			_remote_render_tick = REMOTE_SNAPSHOT_INTERPOLATION.advance_cursor(
				_remote_render_tick, desired_tick, delta, rate)
	var sampled := REMOTE_SNAPSHOT_INTERPOLATION.sample(_remote_samples,
		_remote_render_tick, REMOTE_EXTRAPOLATE_MS / 1000.0 * rate)
	if sampled.is_empty():
		return
	if remote_transport != null \
			and (str(remote_transport.call("presentation_mode")) == "adaptive" \
			or bool(remote_transport.call("presentation_trace_enabled"))):
		var ticks: Array = _remote_samples.keys()
		var oldest_tick := int(ticks.min())
		var newest_tick := int(ticks.max())
		var required_span := float(remote_transport.call("presentation_maximum_msec")) \
			/ 1000.0 * rate
		var established := not rebased_this_frame \
			and _remote_interp_warmup_samples >= 6 \
			and float(newest_tick - oldest_tick) >= required_span
		remote_transport.call("observe_presentation_body", name, established,
			not established, float(newest_tick - _remote_render_tick) * 1000.0 / rate,
			(current_tick - _remote_render_tick) * 1000.0 / rate,
			_remote_render_tick, str(sampled["mode"]))
	if is_instance_valid(_remote_visual_root) and _remote_visual_root.is_inside_tree():
		var sampled_rotation := REMOTE_SNAPSHOT_INTERPOLATION.sample_rotation(
			_remote_rotation_samples, sampled, _remote_render_tick)
		var presentation_transform := Transform3D(Basis(sampled_rotation), sampled["position"])
		_remote_visual_root.global_transform = \
			presentation_transform * _remote_visual_local_transform


func _process_predictive_presentation(delta: float, _current_tick: float, _rate: float) -> void:
	if not is_instance_valid(_remote_visual_root) or not _remote_visual_root.is_inside_tree():
		return
	# The rollback body is the actual gameplay collider and the center-point
	# marker follows it. Anchor reconciliation there so smoothing cannot silently
	# redefine where a hit should occur on this client.
	var target := Transform3D(global_basis.orthonormalized(), global_position)
	if not _remote_predictive_pose_initialized \
			or _remote_predictive_pose.origin.distance_to(target.origin) \
			> REMOTE_PREDICTION_TELEPORT_DISTANCE:
		_remote_predictive_pose = target
		_remote_predictive_pose_initialized = true
	else:
		# Carry the visual pose continuously with the authoritative velocity. If we
		# only low-pass a moving target, each 30 Hz publication produces a visible
		# chase/correct pulse and adds steady speed-proportional lag. Feed-forward
		# leaves the smoother responsible only for accumulated prediction error.
		_remote_predictive_pose = REMOTE_SNAPSHOT_INTERPOLATION.predict_pose(
			_remote_predictive_pose.origin,
			_remote_predictive_pose.basis.get_rotation_quaternion(),
			_remote_latest_linear_velocity, _remote_latest_angular_velocity, delta)
		_remote_predictive_pose = REMOTE_SNAPSHOT_INTERPOLATION.smooth_pose(
			_remote_predictive_pose, target, delta, 0.080, 0.100)
	var offset := _remote_predictive_pose.origin - target.origin
	var lead := 0.0
	if _remote_latest_linear_velocity.length_squared() > 0.0001:
		lead = offset.dot(_remote_latest_linear_velocity.normalized())
	var remote_transport := get_node_or_null("/root/RemotePositionTransport")
	if remote_transport != null:
		remote_transport.call("observe_predictive_alignment", offset.length(), lead)
	_remote_visual_root.global_transform = \
		_remote_predictive_pose * _remote_visual_local_transform


func _process_proxy_presentation(delta: float, current_tick: float, rate: float,
		remote_transport: Node) -> void:
	if not is_instance_valid(_remote_visual_root) or not _remote_visual_root.is_inside_tree() \
			or not is_instance_valid(_remote_collision_proxy):
		return
	var newest_tick := int(_remote_samples.keys().max())
	var newest_position: Vector3 = _remote_samples[newest_tick]
	var newest_rotation: Quaternion = _remote_rotation_samples.get(newest_tick,
		Quaternion.IDENTITY)
	var lead_seconds := clampf((current_tick - float(newest_tick)) / maxf(rate, 1.0),
		0.0, 0.250)
	var target := REMOTE_SNAPSHOT_INTERPOLATION.predict_pose(newest_position,
		newest_rotation, _remote_latest_linear_velocity, _remote_latest_angular_velocity,
		lead_seconds)
	if not _remote_predictive_pose_initialized \
			or _remote_predictive_pose.origin.distance_to(target.origin) \
			> REMOTE_PREDICTION_TELEPORT_DISTANCE:
		_remote_predictive_pose = target
		_remote_predictive_pose_initialized = true
	else:
		_remote_predictive_pose = REMOTE_SNAPSHOT_INTERPOLATION.predict_pose(
			_remote_predictive_pose.origin,
			_remote_predictive_pose.basis.get_rotation_quaternion(),
			_remote_latest_linear_velocity, _remote_latest_angular_velocity, delta)
		_remote_predictive_pose = REMOTE_SNAPSHOT_INTERPOLATION.smooth_pose(
			_remote_predictive_pose, target, delta, 0.080, 0.100)
	_remote_collision_proxy.global_transform = _remote_predictive_pose
	_remote_visual_root.global_transform = \
		_remote_predictive_pose * _remote_visual_local_transform
	if is_instance_valid(_remote_peer_marker):
		_remote_peer_marker.global_transform = \
			_remote_predictive_pose * _remote_peer_marker_local_transform
	var authority_offset := _remote_predictive_pose.origin - global_position
	var authority_lead := 0.0
	if _remote_latest_linear_velocity.length_squared() > 0.0001:
		authority_lead = authority_offset.dot(_remote_latest_linear_velocity.normalized())
	if remote_transport != null:
		remote_transport.call("observe_predictive_alignment", authority_offset.length(),
			authority_lead)


func _is_headless_presentation() -> bool:
	return DisplayServer.get_name() == "headless"

func _process(_delta: float) -> void:
	_process_local_presentation(_delta)
	_process_remote_position(_delta)
	_update_tractor_rope()
	if _cursor_marker == null or _cursor_line == null:
		return
	if _input.editing or is_cloaked or rc_pilot_active:
		_cursor_marker.visible = false
		if _max_speed_marker != null:
			_max_speed_marker.visible = false
		_cursor_line.visible = false
		if _tractor_ring != null:
			_tractor_ring.visible = false
		return
	_cursor_marker.visible = true
	var offset: Vector2 = _input.cursor_offset
	var road_plane_y := global_position.y - VEHICLE_CONFIG.COLLISION_RADIUS
	var target := Vector3(global_position.x + offset.x, road_plane_y + 0.04,
		global_position.z + offset.y)
	_cursor_marker.global_position = target
	var start := Vector3(global_position.x, road_plane_y + 0.08, global_position.z)
	var distance := start.distance_to(target)
	var planar_distance := offset.length()
	if _max_speed_marker != null:
		_max_speed_marker.visible = planar_distance > 0.05
		if _max_speed_marker.visible:
			var max_offset := offset.normalized() * FOLLOW.MAX_DISTANCE
			_max_speed_marker.global_position = Vector3(
				global_position.x + max_offset.x, road_plane_y + 0.075,
				global_position.z + max_offset.y)
	_cursor_line.global_position = (start + target) * 0.5
	_cursor_line.visible = planar_distance > 0.05
	if planar_distance > 0.05:
		_cursor_line.look_at(target, Vector3.UP)
	_cursor_line.scale = Vector3(1.0, 1.0, distance)
	if _cursor_line_material != null:
		_cursor_line_material.albedo_color = _cursor_line_color
		_cursor_line_material.emission = _cursor_line_color
	if _tractor_ring != null:
		_tractor_ring.visible = bool(_input.tractor)
		_tractor_ring.global_position = Vector3(global_position.x,
			road_plane_y + 0.06, global_position.z)

func _update_tractor_rope() -> void:
	if _tractor_rope == null:
		return
	var ball := _city_ball()
	_tractor_rope.visible = tractor_ball_held and not is_cloaked and ball != null
	if not _tractor_rope.visible:
		return
	var start := global_position + Vector3.UP * 0.15
	var finish: Vector3 = ball.global_position
	var distance := start.distance_to(finish)
	_tractor_rope.global_position = (start + finish) * 0.5
	_tractor_rope.look_at(finish, Vector3.UP)
	_tractor_rope.scale = Vector3(1.0, 1.0, distance)

func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()


func presented_position() -> Vector3:
	# Diagnostics must sample the final client-local pose seen by the renderer,
	# not the rollback collider that proxy/interpolated presentation follows.
	if is_instance_valid(_remote_visual_root) and _remote_visual_root.is_inside_tree():
		return (_remote_visual_root.global_transform \
			* _remote_visual_local_transform.affine_inverse()).origin
	return global_position


func local_presentation_metrics() -> Dictionary:
	return {
		"enabled": _is_local and local_presentation_smoothing,
		"offset_units": _local_presentation_offset,
		"offset_max_units": _local_presentation_offset_max,
		"snaps": _local_presentation_snaps,
	}


func _process_local_presentation(delta: float) -> void:
	if not _is_local or not local_presentation_smoothing:
		return
	_ensure_remote_visual_roots()
	if not is_instance_valid(_remote_visual_root) \
			or not _remote_visual_root.is_inside_tree():
		return
	var target := Transform3D(global_basis.orthonormalized(), global_position)
	if not _local_presented_pose_initialized:
		_local_presented_pose = target
		_local_presented_pose_initialized = true
	else:
		var result: Dictionary = LOCAL_PRESENTATION.advance(_local_presented_pose,
			target, linear_velocity, angular_velocity, delta)
		_local_presented_pose = result["pose"]
		if bool(result["snapped"]):
			_local_presentation_snaps += 1
	_local_presentation_offset = _local_presented_pose.origin.distance_to(target.origin)
	_local_presentation_offset_max = maxf(_local_presentation_offset_max,
		_local_presentation_offset)
	_remote_visual_root.global_transform = \
		_local_presented_pose * _remote_visual_local_transform
