extends "res://addons/netfox.extras/physics/network-rigid-body-3d.gd"
## Server-owned Rapier body with client-owned input and local prediction.

const FOLLOW := preload("res://player/follow_controller.gd")
const VEHICLE_CONFIG := preload("res://player/vehicle_config.gd")

var owner_id := 0
var spawn_slot := 0
var aim := Vector3(0.0, 0.0, -1.0)
var burst_turn_sign := 0.0
var boost_active := false
var collision_stall_time := 0.0
var collision_escape_time := 0.0
var collision_escape_sign := 0.0
var collision_escape_count := 0
var wall_bump_cooldown := 0.0
var wall_bump_count := 0
var was_supported := false
var landing_fall_speed := 0.0
var landing_jostle_cooldown := 0.0

@onready var _input := get_node("Input")
@onready var _sync := get_node("RollbackSynchronizer")
@onready var _interpolator := get_node("TickInterpolator")
var _cursor_marker: Node3D
var _cursor_line: Node3D

func _ready() -> void:
	owner_id = int(name)
	set_multiplayer_authority(1)
	_input.set_multiplayer_authority(owner_id)
	_sync.root = self
	_sync.enable_prediction = true
	_sync.enable_input_broadcast = false
	_sync.add_state(self, "physics_state")
	_sync.add_state(self, "burst_turn_sign")
	_sync.add_state(self, "boost_active")
	_sync.add_state(self, "collision_stall_time")
	_sync.add_state(self, "collision_escape_time")
	_sync.add_state(self, "collision_escape_sign")
	_sync.add_state(self, "collision_escape_count")
	_sync.add_state(self, "wall_bump_cooldown")
	_sync.add_state(self, "wall_bump_count")
	_sync.add_state(self, "was_supported")
	_sync.add_state(self, "landing_fall_speed")
	_sync.add_state(self, "landing_jostle_cooldown")
	_sync.add_input(_input, "cursor_offset")
	_sync.add_input(_input, "burst")
	_sync.add_input(_input, "reverse")
	_sync.process_settings()

	var local_player := owner_id == multiplayer.get_unique_id()
	if not multiplayer.is_server() and not local_player:
		_interpolator.root = self
		_interpolator.add_property(self, "global_transform")
	else:
		_interpolator.enabled = false
	if local_player:
		_cursor_marker = get_node_or_null("CursorMarker")
		_cursor_line = get_node_or_null("CursorLine")

func _physics_rollback_tick(delta: float, _tick: int) -> void:
	if direct_state == null:
		return
	var offset: Vector2 = _input.cursor_offset
	var velocity: Vector3 = direct_state.linear_velocity
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var command := FOLLOW.command(offset, FOLLOW.heading_yaw(direct_state.transform.basis),
		_input.burst, burst_turn_sign, planar_speed, _input.reverse)
	burst_turn_sign = command["burst_turn_sign"]
	boost_active = bool(command["boost_active"])
	var fallback_sign := 1.0 if owner_id % 2 == 0 else -1.0
	var forward: Vector3 = -direct_state.transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	wall_bump_cooldown = maxf(wall_bump_cooldown - delta, 0.0)
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
	var bump_started := false
	var bump_linear_impulse := Vector3.ZERO
	var bump_yaw_impulse := 0.0
	var wall_normal := _static_contact_normal()
	var touching_static := not wall_normal.is_zero_approx()
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
	if touching_static or _input.reverse:
		# Static contacts use Rapier plus the one-shot impulses above. The timed
		# escape assist is reserved for cars wedged against other moving cars.
		escape = {"stall_time": 0.0, "escape_time": 0.0, "escape_sign": 0.0,
			"active": false, "started": false}
	else:
		escape = FOLLOW.collision_escape(float(command["speed"]), planar_speed,
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
	horizontal = horizontal.move_toward(target_velocity, float(command["acceleration"]) * delta)
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
		direct_state.angular_velocity, mass))
	if bump_started:
		direct_state.apply_central_impulse(bump_linear_impulse)
		direct_state.apply_torque_impulse(Vector3.UP * bump_yaw_impulse)
	if not landing_torque_impulse.is_zero_approx():
		direct_state.apply_torque_impulse(landing_torque_impulse)

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

func _process(_delta: float) -> void:
	if _cursor_marker == null or _cursor_line == null:
		return
	var offset: Vector2 = _input.cursor_offset
	var road_plane_y := global_position.y - VEHICLE_CONFIG.COLLISION_RADIUS
	var target := Vector3(global_position.x + offset.x, road_plane_y + 0.04,
		global_position.z + offset.y)
	_cursor_marker.global_position = target
	var start := Vector3(global_position.x, road_plane_y + 0.08, global_position.z)
	var distance := start.distance_to(target)
	var planar_distance := offset.length()
	_cursor_line.global_position = (start + target) * 0.5
	_cursor_line.visible = planar_distance > 0.05
	if planar_distance > 0.05:
		_cursor_line.look_at(target, Vector3.UP)
	_cursor_line.scale = Vector3(1.0, 1.0, distance)

func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()
