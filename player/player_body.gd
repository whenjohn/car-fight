extends "res://addons/netfox.extras/physics/network-rigid-body-3d.gd"
## Server-owned Rapier body with client-owned input and local prediction.

const FOLLOW := preload("res://player/follow_controller.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")
const TRACTOR := preload("res://player/tractor_controller.gd")
const IMPACT := preload("res://player/impact_controller.gd")
const MAP_LAYOUT := preload("res://world/map_layout.gd")
const REMOTE_POSITION_VALIDATION := preload("res://net/remote_position_validation.gd")
const REMOTE_SNAPSHOT_INTERPOLATION := preload("res://net/remote_snapshot_interpolation.gd")

const DET_ZONE_RADIUS := 3.6
const DET_GROW_TIME := 0.08

var owner_id := 0
var spawn_slot := 0
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
var map_id := MAP_LAYOUT.ARENA
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
var _remote_render_tick := 0.0
var _remote_render_tick_initialized := false
var _remote_visual_root: Node3D
var _remote_visual_local_transform := Transform3D.IDENTITY
const REMOTE_INTERP_MS := 75.0
const REMOTE_EXTRAPOLATE_MS := 50.0

func _ready() -> void:
	add_to_group("pilotable")
	owner_id = int(name)
	set_multiplayer_authority(1)
	_input.set_multiplayer_authority(owner_id)
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

func _physics_rollback_tick(delta: float, _tick: int) -> void:
	if direct_state == null:
		return
	if _service_jump_gate(delta):
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
	if touching_static or not touching_player or (_input.reverse and not _input.editing):
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
		float(command["acceleration"]) * impact_acceleration_scale * delta)
	horizontal = FOLLOW.drift_carve_velocity(horizontal, drift_assist_side,
		drift_assist_amount, drift_assist_charge, delta)
	if bool(escape["started"]):
		horizontal += drive_direction * FOLLOW.ESCAPE_SIDE_KICK
	direct_state.linear_velocity = FOLLOW.compose_drive_velocity(horizontal, velocity.y)
	var current_yaw_rate: float = direct_state.angular_velocity.y
	var target_yaw_rate := collision_escape_sign * FOLLOW.ESCAPE_YAW_RATE \
		if bool(escape["active"]) else float(command["yaw_rate"])
	var yaw_acceleration := FOLLOW.ESCAPE_YAW_ACCEL \
		if bool(escape["active"]) else float(command["yaw_acceleration"])
	var yaw_rate := move_toward(current_yaw_rate, target_yaw_rate, yaw_acceleration * delta)
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


func _service_jump_gate(delta: float) -> bool:
	gate_cooldown = maxf(gate_cooldown - delta, 0.0)
	if gate_cooldown > 0.0:
		return false
	var transition := MAP_LAYOUT.transition(map_id,
		direct_state.transform.origin, direct_state.transform.origin.y)
	if transition.is_empty():
		return false
	var transform: Transform3D = direct_state.transform
	transform.origin = transition["position"]
	transform.basis = Basis(Vector3.UP, float(transition["yaw"]))
	direct_state.transform = transform
	direct_state.linear_velocity = Vector3.ZERO
	direct_state.angular_velocity = Vector3.ZERO
	map_id = int(transition["map_id"])
	gate_cooldown = MAP_LAYOUT.GATE_COOLDOWN
	gate_transition_count += 1
	burst_turn_sign = 0.0
	boost_active = false
	brake_skid_amount = 0.0
	drift_assist_amount = 0.0
	drift_assist_charge = 0.0
	drift_assist_side = 0.0
	drift_assist_hold = 0.0
	drift_assist_latched = false
	drift_assist_rearm_ready = true
	collision_stall_time = 0.0
	collision_escape_time = 0.0
	wall_bump_cooldown = 0.0
	return true

func _static_contact_normal() -> Vector3:
	for index in range(direct_state.get_contact_count()):
		var collider := direct_state.get_contact_collider_object(index)
		if collider is StaticBody3D:
			var normal: Vector3 = direct_state.get_contact_local_normal(index)
			# Floor, ramp, and upper-road contacts support the car vertically; only
			# near-vertical faces are walls that should produce a horizontal bump.
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

func area_gesture_preview() -> Dictionary:
	return {"start": area_gesture_start, "end": area_gesture_end} if area_gesture_active else {}

## Cross-body hit commands arrive after this body's current tick. Queue them
## until its own rollback simulation owns a live direct_state, as the tractor
## already does for the arena ball.
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

func _arena_ball() -> Node:
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


func is_remote_position_relevant() -> bool:
	return true if not remote_position_transport_controlled() else _remote_position_relevant


func set_remote_position_relevant(relevant: bool, tick: int) -> void:
	if not remote_position_transport_controlled() or relevant == _remote_position_relevant:
		return
	_remote_position_relevant = relevant
	_remote_position_presented = false
	_remote_samples.clear()
	_remote_render_tick_initialized = false
	_remote_state_min_tick = maxi(_remote_state_min_tick, tick if not relevant else tick - 1)
	_ensure_remote_visual_roots()
	_apply_remote_position_visibility()


func receive_remote_position(generation: int, tick: int, position: Vector3) -> bool:
	if not REMOTE_POSITION_VALIDATION.accepts_body_sample(multiplayer.is_server(), _is_local,
			remote_state_generation, _remote_state_last_tick, _remote_state_min_tick,
			generation, tick):
		return false
	_remote_state_last_tick = tick
	var network_time := get_node_or_null("/root/NetworkTime")
	var current_tick := tick if network_time == null else int(network_time.get("tick"))
	REMOTE_SNAPSHOT_INTERPOLATION.insert_bounded(
		_remote_samples, tick, position, maxi(current_tick, tick), 64)
	if not _remote_position_presented:
		_remote_position_presented = true
		_apply_remote_position_visibility()
	return true


func _ensure_remote_visual_roots() -> void:
	if _remote_visual_root != null or _is_headless_presentation():
		return
	_remote_visual_root = get_node_or_null("GroundVehicleHull") as Node3D
	if _remote_visual_root == null:
		return
	_remote_visual_local_transform = _remote_visual_root.transform
	var world_transform := _remote_visual_root.global_transform
	_remote_visual_root.top_level = true
	_remote_visual_root.global_transform = world_transform


func _apply_remote_position_visibility() -> void:
	if is_instance_valid(_remote_visual_root):
		_remote_visual_root.visible = _remote_position_presented


func _process_remote_position(delta: float) -> void:
	if not remote_position_transport_controlled() or not _remote_position_relevant \
			or _remote_samples.is_empty():
		return
	_ensure_remote_visual_roots()
	var network_time := get_node_or_null("/root/NetworkTime")
	if network_time == null:
		return
	var rate := float(network_time.get("tickrate"))
	var desired_tick := float(network_time.get("tick")) \
		- REMOTE_INTERP_MS / 1000.0 * rate
	if not _remote_render_tick_initialized:
		_remote_render_tick = desired_tick
		_remote_render_tick_initialized = true
	else:
		_remote_render_tick = REMOTE_SNAPSHOT_INTERPOLATION.advance_cursor(
			_remote_render_tick, desired_tick, delta, rate)
	var sampled := REMOTE_SNAPSHOT_INTERPOLATION.sample(_remote_samples,
		_remote_render_tick, REMOTE_EXTRAPOLATE_MS / 1000.0 * rate)
	if sampled.is_empty():
		return
	if is_instance_valid(_remote_visual_root):
		var presentation_transform := Transform3D(global_basis, sampled["position"])
		_remote_visual_root.global_transform = \
			presentation_transform * _remote_visual_local_transform


func _is_headless_presentation() -> bool:
	return DisplayServer.get_name() == "headless"

func _process(_delta: float) -> void:
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
	var ball := _arena_ball()
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
