extends "res://addons/netfox.extras/physics/network-rigid-body-3d.gd"
## Server-owned Rapier body with client-owned input and local prediction.

const FOLLOW := preload("res://player/follow_controller.gd")

var owner_id := 0
var spawn_slot := 0
var aim := Vector3(0.0, 0.0, -1.0)
var burst_turn_sign := 0.0
var collision_stall_time := 0.0
var collision_escape_time := 0.0
var collision_escape_sign := 0.0
var collision_escape_count := 0
var wall_deflection_time := 0.0
var wall_deflection_cooldown := 0.0
var wall_deflection_direction := Vector3.ZERO
var wall_deflection_turn_sign := 0.0
var wall_deflection_count := 0

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
	_sync.add_state(self, "collision_stall_time")
	_sync.add_state(self, "collision_escape_time")
	_sync.add_state(self, "collision_escape_sign")
	_sync.add_state(self, "collision_escape_count")
	_sync.add_state(self, "wall_deflection_time")
	_sync.add_state(self, "wall_deflection_cooldown")
	_sync.add_state(self, "wall_deflection_direction")
	_sync.add_state(self, "wall_deflection_turn_sign")
	_sync.add_state(self, "wall_deflection_count")
	_sync.add_input(_input, "cursor_offset")
	_sync.add_input(_input, "burst")
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
	var command := FOLLOW.command(offset, direct_state.transform.basis.get_euler().y,
		_input.burst, burst_turn_sign, planar_speed)
	burst_turn_sign = command["burst_turn_sign"]
	var fallback_sign := 1.0 if owner_id % 2 == 0 else -1.0
	var forward: Vector3 = -direct_state.transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	wall_deflection_time = maxf(wall_deflection_time - delta, 0.0)
	wall_deflection_cooldown = maxf(wall_deflection_cooldown - delta, 0.0)
	var deflection_started := false
	var deflection_velocity := Vector3.ZERO
	if wall_deflection_cooldown <= 0.0:
		var wall_normal := _static_contact_normal()
		if not wall_normal.is_zero_approx():
			var preferred_sign := signf(float(command["heading_error"])) \
				if absf(float(command["heading_error"])) >= FOLLOW.ESCAPE_STEER_EPSILON \
				else fallback_sign
			var deflection := FOLLOW.wall_deflection(forward, velocity, wall_normal, preferred_sign)
			if bool(deflection["active"]):
				wall_deflection_time = FOLLOW.WALL_DEFLECTION_DURATION
				wall_deflection_cooldown = FOLLOW.WALL_DEFLECTION_COOLDOWN
				wall_deflection_direction = deflection["direction"]
				wall_deflection_turn_sign = deflection["turn_sign"]
				deflection_velocity = deflection["velocity"]
				wall_deflection_count += 1
				deflection_started = true
	var deflecting := wall_deflection_time > 0.0
	var escape: Dictionary
	if deflecting:
		collision_stall_time = 0.0
		collision_escape_time = 0.0
		collision_escape_sign = 0.0
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
	var drive_direction := wall_deflection_direction if deflecting \
		else (FOLLOW.escape_drive_direction(forward, collision_escape_sign) \
		if bool(escape["active"]) else forward)
	var target_velocity: Vector3 = drive_direction * float(command["speed"])
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if deflection_started:
		horizontal = deflection_velocity
	else:
		horizontal = horizontal.move_toward(target_velocity, float(command["acceleration"]) * delta)
	if bool(escape["started"]) and not deflecting:
		horizontal += drive_direction * FOLLOW.ESCAPE_SIDE_KICK
	direct_state.linear_velocity = Vector3(horizontal.x, 0.0, horizontal.z)
	var current_yaw_rate: float = direct_state.angular_velocity.y
	var target_yaw_rate := wall_deflection_turn_sign * FOLLOW.WALL_DEFLECTION_YAW_RATE \
		if deflecting else (collision_escape_sign * FOLLOW.ESCAPE_YAW_RATE \
		if bool(escape["active"]) else float(command["yaw_rate"]))
	var yaw_acceleration := FOLLOW.WALL_DEFLECTION_YAW_ACCEL if deflecting \
		else (FOLLOW.ESCAPE_YAW_ACCEL if bool(escape["active"]) \
		else float(command["yaw_acceleration"]))
	var yaw_rate := move_toward(current_yaw_rate, target_yaw_rate, yaw_acceleration * delta)
	direct_state.angular_velocity = Vector3(0.0, yaw_rate, 0.0)

func _static_contact_normal() -> Vector3:
	for index in range(direct_state.get_contact_count()):
		var collider := direct_state.get_contact_collider_object(index)
		if collider is StaticBody3D:
			var normal: Vector3 = direct_state.get_contact_local_normal(index)
			normal.y = 0.0
			if not normal.is_zero_approx():
				return normal.normalized()
	return Vector3.ZERO

func _process(_delta: float) -> void:
	if _cursor_marker == null or _cursor_line == null:
		return
	var offset: Vector2 = _input.cursor_offset
	var target := global_position + Vector3(offset.x, 0.04, offset.y)
	_cursor_marker.global_position = target
	var start := global_position + Vector3.UP * 0.08
	var distance := start.distance_to(target)
	var planar_distance := offset.length()
	_cursor_line.global_position = (start + target) * 0.5
	_cursor_line.visible = planar_distance > 0.05
	if planar_distance > 0.05:
		_cursor_line.look_at(target, Vector3.UP)
	_cursor_line.scale = Vector3(1.0, 1.0, distance)

func speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()
