extends Node
## Opt-in signal-boundary timings. Durations include OS scheduling/waits, not just CPU work.

const RECORD_CAP := 30000
const STARTUP_SAMPLE_CAP := 6000
var _path := ""
var _deadline_usec := 0
var _records: Array[Dictionary] = []
var _dropped := 0
var _connections: Array = []
var _running := false
var _last_frame_usec := -1
var _last_anchor_usec := 0
var _loop: Dictionary = {}
var _forward_start := -1
var _rollback_start := -1
var _stage_start := -1
var _stage := ""
var _endpoint_recorded := false
var _network_time: Node
var _startup_deadline_usec := 0
var _startup_samples := 0
var _startup_dropped := 0
var _epoch := 0


func _ready() -> void:
	set_process(false)
	_network_time = get_node("/root/NetworkTime")
	var path := OS.get_environment("CAR_FIGHT_NETWORK_STAGE_TRACE_PATH")
	var seconds := float(OS.get_environment("CAR_FIGHT_NETWORK_DIAGNOSTICS_SECONDS"))
	if not path.is_empty() and seconds > 0.0:
		start(path, seconds, float(OS.get_environment("CAR_FIGHT_STARTUP_TRACE_SECONDS")))


func start(path: String, seconds: float, startup_seconds: float = 0.0) -> void:
	if _running or path.is_empty() or seconds <= 0.0:
		return
	_path = path
	_deadline_usec = _now_usec() + int(minf(seconds, 300.0) * 1000000.0)
	_startup_deadline_usec = mini(_deadline_usec,
		_now_usec() + int(minf(startup_seconds, 60.0) * 1000000.0)) if startup_seconds > 0.0 else 0
	_startup_samples = 0
	_startup_dropped = 0
	_epoch = 0
	_records.clear()
	_dropped = 0
	_running = true
	_last_frame_usec = -1
	_endpoint_recorded = false
	_reset_loop()
	_record({"event": "config", "version": 1, "pid": OS.get_process_id(),
		"user_args": OS.get_cmdline_user_args(), "record_cap": RECORD_CAP,
		"duration_seconds": minf(seconds, 300.0),
		"startup_seconds": maxf(0.0, minf(startup_seconds, minf(seconds, 60.0))),
		"startup_sample_cap": STARTUP_SAMPLE_CAP,
		"timing": "elapsed signal boundaries; not CPU time; nested spans overlap"})
	_anchor()
	var rollback := get_node("/root/NetworkRollback")
	_connect(Signal(_network_time, "before_tick_loop"), _begin_loop)
	_connect(Signal(_network_time, "before_tick"), _begin_forward)
	_connect(Signal(_network_time, "after_tick"), _end_forward)
	_connect(Signal(_network_time, "after_tick_loop"), _end_loop)
	_connect(Signal(rollback, "before_loop"), _begin_rollback)
	_connect(Signal(rollback, "on_prepare_tick"), _prepare)
	_connect(Signal(rollback, "on_process_tick"), _simulate)
	_connect(Signal(rollback, "on_record_tick"), _record_state)
	_connect(Signal(rollback, "after_loop"), _end_rollback)
	_connect(Signal(get_node("/root/NetworkEvents"), "on_client_stop"), _reset_epoch)
	if _startup_deadline_usec > 0:
		_connect(Signal(_network_time, "after_sync"), _startup_synced)
		_connect(Signal(get_node("/root/NetworkTimeSynchronizer"), "on_panic"), _startup_panic)
	set_process(true)


func _connect(source: Signal, callback: Callable) -> void:
	source.connect(callback)
	_connections.append([source, callback])


func _now_usec() -> int:
	return Time.get_ticks_usec()


func _anchor() -> void:
	var before := _now_usec()
	var unix_usec := int(Time.get_unix_time_from_system() * 1000000.0)
	var after := _now_usec()
	_record({"event": "clock_anchor", "mono_usec": before,
		"unix_usec": unix_usec, "read_span_usec": after - before})
	_last_anchor_usec = after


func _record(data: Dictionary) -> void:
	if not _running:
		return
	if _records.size() >= RECORD_CAP:
		_dropped += 1
		return
	_records.append(data)


func _process(delta: float) -> void:
	if not _running:
		return
	var now := _now_usec()
	if not _endpoint_recorded:
		var peer := multiplayer.multiplayer_peer
		if peer is ENetMultiplayerPeer \
				and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			var host := (peer as ENetMultiplayerPeer).get_host()
			if host != null:
				_record({"event": "endpoint", "mono_usec": now,
					"local_port": host.get_local_port(), "transport": "enet"})
				_endpoint_recorded = true
	_record({"event": "frame", "mono_usec": now,
		"wall_gap_usec": now - _last_frame_usec if _last_frame_usec >= 0 else -1,
		"engine_delta_usec": delta * 1000000.0,
		"focused": DisplayServer.window_is_focused()})
	_last_frame_usec = now
	_sample_startup(now)
	if now - _last_anchor_usec >= 1000000:
		_anchor()
	if now >= _deadline_usec:
		finish()


func _startup_clock() -> Dictionary:
	var synced := bool(_network_time.call("is_initial_sync_done"))
	return {"mono_usec": _now_usec(), "epoch": _epoch,
		"tick": int(_network_time.get("tick")), "initial_sync_done": synced,
		"reference_seconds": get_node("/root/NetworkTimeSynchronizer").call("get_time") if synced else null,
		"tickrate": int(_network_time.get("tickrate"))}


func _startup_event(event: String, extra: Dictionary = {}) -> void:
	if not _running or _startup_deadline_usec <= 0 or _now_usec() >= _startup_deadline_usec:
		return
	var record := _startup_clock()
	record["event"] = event
	record.merge(extra)
	_record(record)


func _startup_synced() -> void:
	_startup_event("startup_sync")


func _startup_panic(offset: float) -> void:
	_startup_event("startup_panic", {"offset_seconds": offset})


func _sample_startup(now: int) -> void:
	if not _running or _startup_deadline_usec <= 0 or now >= _startup_deadline_usec:
		return
	if _startup_samples >= STARTUP_SAMPLE_CAP:
		_startup_dropped += 1
		return
	var main := get_tree().current_scene
	if main == null or not main.has_method("local_player"):
		return
	var body := main.call("local_player") as RigidBody3D
	# local_player already checks connected-peer state; never retain bodies across frames.
	if body == null or not body.is_node_ready():
		return
	var record := _startup_clock()
	record["event"] = "startup_sample"
	record["startup_ready"] = main.network_startup_ready() if main.has_method("network_startup_ready") else null
	if body.has_method("gameplay_active"):
		record["admission_required"] = bool(body.get("admission_required"))
		record["activation_tick"] = int(body.get("activation_tick"))
	record["history_start"] = get_node("/root/NetworkRollback").get("history_start")
	record["display_tick"] = get_node("/root/NetworkRollback").get("display_tick")
	record.merge(_startup_body_snapshot(body))
	_record(record)
	_startup_samples += 1


static func _vec3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _physics_snapshot(value: Variant) -> Variant:
	if not value is Array or value.size() < 3 \
			or not value[0] is Vector3 or not value[2] is Vector3:
		return null
	return {"position": _vec3(value[0]), "velocity": _vec3(value[2])}


static func _startup_body_snapshot(body: RigidBody3D) -> Dictionary:
	var record := {"body_id": str(body.name), "instance_id": body.get_instance_id(),
		"generation": body.get("remote_state_generation"),
		"node_position": _vec3(body.global_position),
		"presented_position": _vec3(body.call("presented_position")),
		"physics": _physics_snapshot(body.get("physics_state"))}
	var sync := body.get_node_or_null("RollbackSynchronizer")
	if sync == null:
		return record
	var latest := int(sync.call("get_last_known_state"))
	var input_tick := -1 if sync._inputs.is_empty() else int(sync._inputs.get_latest_tick())
	record.merge({"latest_state_tick": latest, "latest_input_tick": input_tick,
		"consumed_authority_tick": sync._consumed_authority_tick,
		"prediction_frontier_tick": sync._prediction_frontier_tick})
	# Exact history entries, not fallback get_history(). This is sampled mutable
	# simulation history, not a packet-receipt/application event or pristine wire state.
	record["history_at_latest_state"] = _physics_snapshot(
		sync._states.get_snapshot(latest).get_value(":physics_state"))
	var input: Variant = sync._inputs.get_snapshot(input_tick)
	var cursor: Variant = input.get_value("Input:cursor_offset")
	record["recorded_cursor"] = [cursor.x, cursor.y] if cursor is Vector2 else null
	record["recorded_editing"] = input.get_value("Input:editing")
	return record


func _begin_loop() -> void:
	_reset_loop()
	_loop = {"event": "network_loop", "start_usec": _now_usec(),
		"start_tick": int(_network_time.get("tick")), "forward_usec": 0, "forward_ticks": 0,
		"rollback_usec": 0, "rollback_ticks": 0,
		"prepare_usec": 0, "simulate_usec": 0, "record_usec": 0}


func _begin_forward(_delta: float, _tick: int) -> void:
	_forward_start = _now_usec()


func _end_forward(_delta: float, _tick: int) -> void:
	if not _loop.is_empty() and _forward_start >= 0:
		_loop["forward_usec"] += _now_usec() - _forward_start
		_loop["forward_ticks"] += 1
	_forward_start = -1


func _begin_rollback() -> void:
	_rollback_start = _now_usec()


func _prepare(_tick: int) -> void:
	_change_stage("prepare_usec")


func _simulate(_tick: int) -> void:
	_change_stage("simulate_usec")
	if not _loop.is_empty():
		_loop["rollback_ticks"] += 1


func _record_state(_tick: int) -> void:
	_change_stage("record_usec")


func _change_stage(next: String) -> void:
	var now := _now_usec()
	if not _loop.is_empty() and _stage_start >= 0:
		_loop[_stage] += now - _stage_start
	_stage = next
	_stage_start = now if not next.is_empty() else -1


func _end_rollback() -> void:
	_change_stage("")
	if not _loop.is_empty() and _rollback_start >= 0:
		_loop["rollback_usec"] += _now_usec() - _rollback_start
	_rollback_start = -1


func _end_loop() -> void:
	if _loop.is_empty():
		return
	_loop["end_usec"] = _now_usec()
	_loop["end_tick"] = int(_network_time.get("tick"))
	_record(_loop)
	_reset_loop()


func _reset_loop() -> void:
	_loop = {}
	_forward_start = -1
	_rollback_start = -1
	_stage_start = -1
	_stage = ""


func _reset_epoch() -> void:
	_epoch += 1
	_reset_loop()
	_last_frame_usec = -1
	_endpoint_recorded = false
	_record({"event": "connection_epoch", "mono_usec": _now_usec(), "epoch": _epoch})


func publication_started() -> int:
	return _now_usec() if _running else -1


func record_publication(start_usec: int, mode: String, publication: int,
		tick: int, recipient: int, bodies: int) -> void:
	if start_usec < 0 or not _running:
		return
	_record({"event": "publication_queued", "start_usec": start_usec,
		"end_usec": _now_usec(), "mode": mode, "publication": publication,
		"tick": tick, "recipient": recipient, "bodies": bodies})


func finish() -> void:
	if not _running:
		return
	_anchor()
	_running = false
	set_process(false)
	for pair in _connections:
		var source: Signal = pair[0]
		if source.is_connected(pair[1]):
			source.disconnect(pair[1])
	_connections.clear()
	var flush_started := _now_usec()
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write network stage trace: %s" % _path)
		return
	for data in _records:
		file.store_line(JSON.stringify(data))
	file.store_line(JSON.stringify({"event": "complete", "records": _records.size(),
		"dropped": _dropped, "startup_samples": _startup_samples,
		"startup_dropped": _startup_dropped,
		"mono_usec": _now_usec(), "flush_started_usec": flush_started}))
	file.close()
	_records.clear()
	print("[network-stage-trace-complete] path=%s dropped=%d" % [_path, _dropped])


func _exit_tree() -> void:
	finish()
