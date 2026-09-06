extends SceneTree

var _main: Node
var _started := 0
var _hold_until := 0
var _checked_bad_request := false
var _waiting_samples := 0
var _active_samples := 0
var _reported := false
var _mode := ""
var _ready_position := Vector3.INF

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_started = Time.get_ticks_msec()
	_mode = OS.get_environment("ADMISSION_TEST_MODE")
	_main = load("res://Main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main

func _process(_delta: float) -> bool:
	if _main == null or _main.get("_players") == null:
		return false
	var now := Time.get_ticks_msec()
	if now - _started > 60000:
		push_error("ADMISSION_PEER timeout mode=%s" % _mode)
		quit(1)
		return false
	var local: Node = _main.local_player()
	if _mode == "hold" and local != null:
		if _hold_until == 0:
			_hold_until = now + 5000
		if now < _hold_until and _main._startup_gate != null:
			# Withhold readiness evidence, not transport polling or simulation.
			_main._startup_gate.begin(now)
			if local.activation_tick >= 0:
				push_error("ADMISSION_PEER activated before valid readiness request")
				quit(1)
			if not _checked_bad_request:
				_checked_bad_request = true
				_main._request_player_activation.rpc_id(1, local.remote_state_generation + 1,
					root.get_node("NetworkTime").tick)
				_main._request_player_activation.rpc_id(1, local.remote_state_generation, 2147483647)
	var active := 0
	for body in _main._players.get_children():
		if not body.admission_required:
			continue
		if body.activation_tick < 0:
			_waiting_samples += 1
			if body.visible or not body.freeze or body.collision_layer != 0 or body.collision_mask != 0:
				push_error("ADMISSION_PEER waiting body participates id=%s" % body.name)
				quit(1)
			var shape: CollisionShape3D = body.get_node("Collision")
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape.shape
			query.transform = shape.global_transform
			for hit in body.get_world_3d().direct_space_state.intersect_shape(query):
				if hit["rid"] == body.get_rid():
					push_error("ADMISSION_PEER waiting body exists in collision queries")
					quit(1)
		elif body.gameplay_active():
			active += 1
	if _main.network_startup_ready() and local != null and not _reported:
		if _ready_position == Vector3.INF:
			_ready_position = local.global_position
		if active >= (3 if _mode == "late" else 2):
			_active_samples += 1
		if _active_samples >= 60:
			if local.global_position.distance_to(_ready_position) < 1.0:
				return false
			if _mode != "late" and _waiting_samples < 60:
				push_error("ADMISSION_PEER missing waiting observation")
				quit(1)
			_reported = true
			print("ADMISSION_PEER PASS mode=%s waiting=%d active=%d" % [
				_mode, _waiting_samples, _active_samples])
	return false
