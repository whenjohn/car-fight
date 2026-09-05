extends Node

## Stable, server-authoritative transport seam for remote presentation samples.
##
## Scheduling and body sampling happen once after rollback. Legacy preserves the
## all-body RPC rollback path. Batch builds one complete presentation-membership
## envelope per recipient from that same settled registry.

const Schedule := preload("res://net/remote_position_schedule.gd")
const Validation := preload("res://net/remote_position_validation.gd")
const Relevance := preload("res://net/remote_position_relevance.gd")
const MapLayout := preload("res://world/map_layout.gd")
const AdaptivePresentationDelay := preload("res://net/adaptive_presentation_delay.gd")
const MODE_LEGACY := "legacy"
const MODE_BATCH := "batch"
const MAX_BODIES := Validation.MAX_BODIES
const RPC_CHANNEL := 0

var _enabled := true
var _mode := MODE_LEGACY
var _rate_hz := 60
var _relevance := Relevance.MODE_ALL
var _include_self := true
var _configured := false
var _telemetry := false
var _schedule: Dictionary = {}

## Global publication identity proves scheduler cadence/catch-up. Envelope
## identity is per recipient so intentional recipient-specific delivery can
## never manufacture sequence-gap telemetry.
var _publication_sequence := 0
var _peer_sequences := {}
var _peer_stats := {}

var _window_started_msec := 0
var _sampled := 0
var _legacy_calls := 0
var _batch_envelopes := 0
var _serialized_entries := 0
var _logical_bytes := 0
var _filter_usec := 0
var _serialize_usec := 0
var _skipped_intervals := 0
var _catchup_collapses := 0
var _last_emitted_tick := -1
var _body_cap_exceeded := 0
var _nonempty_batch_proof_printed := false

var _last_batch_sequence := -1
var _last_batch_publication := -1
var _last_batch_tick := -1
var _last_recipient_map := Relevance.UNKNOWN_MAP
var _server_enabled := true
var _server_mode := MODE_LEGACY
var _server_rate_hz := 60
var _server_relevance := Relevance.MODE_ALL
var _server_include_self := true
var _server_config_received := false
var _active_membership := {}
var _rx_window_started_msec := 0
var _rx_batches := 0
var _rx_entries := 0
var _batch_sequence_gaps := 0
var _batch_stale := 0
var _batch_malformed := 0
var _unknown_bodies := 0
var _membership_enters := 0
var _membership_leaves := 0
var _presentation_mode := "fixed"
var _presentation_cursor_clock := "engine"
var _presentation_min_msec := 75.0
var _presentation_max_msec := 150.0
var _presentation_state: Dictionary = {}
var _presentation_pending_batches: Array = []
var _presentation_body_samples := {}
var _presentation_hitch_settle_until_msec := 0
var _presentation_sequence_gaps_total := 0
var _presentation_report_msec := 0
var _predictive_offset_units := 0.0
var _predictive_offset_max_units := 0.0
var _predictive_lead_units := 0.0
const PRESENTATION_TRACE_RECORD_CAP := 30000
const PRESENTATION_TRACE_CHUNK_BYTES := 24000
var _presentation_trace_path := ""
var _presentation_trace_duration_msec := 0
var _presentation_trace_started_msec := -1
var _presentation_frame_usec := -1
var _presentation_trace_records: Array = []
var _presentation_trace_dropped := 0
var _presentation_trace_flushed := false

func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	NetworkEvents.on_peer_join.connect(_on_peer_join)
	NetworkEvents.on_peer_leave.connect(_on_peer_leave)
	NetworkEvents.on_client_start.connect(func(_id): _reset_receiver_epoch())
	NetworkEvents.on_client_stop.connect(_reset_receiver_epoch)


func _exit_tree() -> void:
	if _trace_enabled() and not _presentation_trace_flushed \
			and not _presentation_trace_records.is_empty():
		_flush_presentation_trace()


func _process(delta: float) -> void:
	if _presentation_mode != "adaptive" and not _trace_enabled():
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	_start_presentation_trace(now)
	var now_usec := Time.get_ticks_usec()
	var wall_delta_msec := float(now_usec - _presentation_frame_usec) / 1000.0 \
		if _presentation_frame_usec >= 0 else -1.0
	_presentation_frame_usec = now_usec
	var frame_msec := delta * 1000.0
	if frame_msec > 50.0:
		_presentation_hitch_settle_until_msec = now + 100
	var contaminated := now <= _presentation_hitch_settle_until_msec
	for observation in _presentation_pending_batches:
		observation["hitch_contaminated"] = contaminated
		if _presentation_mode == "adaptive":
			AdaptivePresentationDelay.observe_batch(_presentation_state,
				int(observation["sequence"]), int(observation["tick"]),
				int(observation["arrival_msec"]), contaminated)
		_trace_record(observation)
	_presentation_pending_batches.clear()
	var bodies: Array = _presentation_body_samples.values()
	if _presentation_mode == "adaptive":
		AdaptivePresentationDelay.observe_frame(_presentation_state, now, frame_msec, bodies)
	_trace_record({
		"type": "frame", "at_msec": now, "delta_msec": frame_msec,
		"wall_delta_msec": wall_delta_msec, "wall_hitch": wall_delta_msec > 50.0,
		"window_focused": DisplayServer.window_is_focused(),
		"hitch": frame_msec > 50.0, "network_tick": NetworkTime.tick,
		"tick_factor": NetworkTime.tick_factor,
		"target_msec": presentation_delay_msec(),
		"controller_state": str(_presentation_state.get("controller_state", "fixed")),
		"bodies": bodies,
	})
	_presentation_body_samples.clear()
	if _presentation_mode == "adaptive" and _telemetry \
			and now - _presentation_report_msec >= 1000:
		_report_presentation()
		_presentation_report_msec = now
	if _trace_enabled() and _presentation_trace_started_msec >= 0 \
			and not _presentation_trace_flushed \
			and now - _presentation_trace_started_msec >= _presentation_trace_duration_msec:
		_flush_presentation_trace()

func configure(enabled: bool, mode: String, rate_hz: int, telemetry: bool,
		relevance: String = Relevance.MODE_ALL, include_self: bool = true) -> void:
	_enabled = enabled
	_mode = mode if mode in [MODE_LEGACY, MODE_BATCH] else MODE_LEGACY
	_rate_hz = rate_hz if rate_hz in Schedule.VALID_RATES else 60
	_relevance = relevance if Relevance.valid_mode(relevance) else Relevance.MODE_ALL
	_include_self = include_self
	_telemetry = telemetry
	Schedule.configure(_schedule, _rate_hz, NetworkTime.tickrate)
	_publication_sequence = 0
	_nonempty_batch_proof_printed = false
	_peer_sequences.clear()
	_peer_stats.clear()
	_configured = true
	_reset_window()
	_print_config("local", _enabled, _mode, _rate_hz, _relevance, _include_self,
		RPC_CHANNEL)


func configure_presentation(mode: String, minimum_msec: float,
		maximum_msec: float, trace_path := "", trace_seconds := 0.0) -> void:
	_presentation_mode = mode if mode in ["fixed", "adaptive", "predictive", "proxy"] else "fixed"
	_presentation_cursor_clock = "elapsed" \
		if OS.get_environment("CAR_FIGHT_REMOTE_CURSOR_CLOCK") == "elapsed" else "engine"
	_presentation_min_msec = maxf(0.0, minimum_msec)
	_presentation_max_msec = maxf(_presentation_min_msec, maximum_msec)
	_presentation_pending_batches.clear()
	_presentation_body_samples.clear()
	_presentation_hitch_settle_until_msec = 0
	_presentation_report_msec = Time.get_ticks_msec()
	_presentation_sequence_gaps_total = 0
	_predictive_offset_units = 0.0
	_predictive_offset_max_units = 0.0
	_predictive_lead_units = 0.0
	_presentation_trace_path = trace_path
	_presentation_trace_duration_msec = int(maxf(0.0, trace_seconds) * 1000.0)
	_presentation_trace_started_msec = -1
	_presentation_frame_usec = -1
	_presentation_trace_records.clear()
	_presentation_trace_dropped = 0
	_presentation_trace_flushed = false
	AdaptivePresentationDelay.configure(_presentation_state,
		_presentation_min_msec, _presentation_max_msec, NetworkTime.tickrate)
	print("[presentation-buffer] mode=%s min_ms=%.0f max_ms=%.0f profile=%s" % [
		_presentation_mode, _presentation_min_msec, _presentation_max_msec,
		AdaptivePresentationDelay.PROFILE_VERSION])
	print("[presentation-cursor] clock=%s" % _presentation_cursor_clock)


func presentation_mode() -> String:
	return _presentation_mode


func presentation_cursor_clock() -> String:
	return _presentation_cursor_clock


func set_presentation_mode(mode: String) -> bool:
	if mode not in ["fixed", "adaptive", "predictive", "proxy"] or mode == _presentation_mode:
		return false
	_presentation_mode = mode
	_presentation_frame_usec = -1
	_presentation_pending_batches.clear()
	_presentation_body_samples.clear()
	AdaptivePresentationDelay.reset_epoch(_presentation_state, Time.get_ticks_msec())
	print("[presentation-buffer-live] mode=%s min_ms=%.0f max_ms=%.0f" % [
		_presentation_mode, _presentation_min_msec, _presentation_max_msec])
	return true


func presentation_delay_msec() -> float:
	if _presentation_mode in ["predictive", "proxy"]:
		return 0.0
	return AdaptivePresentationDelay.target_msec(_presentation_state) \
		if _presentation_mode == "adaptive" else _presentation_min_msec


func presentation_maximum_msec() -> float:
	return _presentation_max_msec


func presentation_trace_enabled() -> bool:
	return _trace_enabled()


func observe_presentation_body(body_id: String, eligible: bool, warming: bool,
		headroom_msec: float, effective_msec: float, render_tick: float,
		mode: String) -> void:
	if (_presentation_mode != "adaptive" and not _trace_enabled()) \
			or multiplayer.is_server():
		return
	_presentation_body_samples[body_id] = {
		"id": body_id, "eligible": eligible, "warming": warming,
		"at_msec": Time.get_ticks_msec(),
		"headroom_msec": headroom_msec, "effective_msec": effective_msec,
		"render_tick": render_tick, "mode": mode,
	}


func observe_predictive_alignment(offset_units: float, lead_units: float) -> void:
	if _presentation_mode not in ["predictive", "proxy"] or multiplayer.is_server():
		return
	_predictive_offset_units = maxf(0.0, offset_units)
	_predictive_offset_max_units = maxf(_predictive_offset_max_units,
		_predictive_offset_units)
	_predictive_lead_units = lead_units


func presentation_snapshot() -> Dictionary:
	var snapshot := {
		"mode": _presentation_mode,
		"selected_msec": presentation_delay_msec(),
		"controller_state": str(_presentation_state.get("controller_state", "warmup")),
		"pressure_reason": str(_presentation_state.get("pressure_reason", "warmup")),
		"effective_msec": float(_presentation_state.get("effective_msec", 0.0)),
		"headroom_min_msec": float(_presentation_state.get("headroom_min_msec", 0.0)),
		"headroom_p10_msec": float(_presentation_state.get("headroom_p10_msec", 0.0)),
		"variation_p95_msec": float(_presentation_state.get("variation_p95_msec", 0.0)),
		"interp_fraction": float(_presentation_state.get("interp_fraction", 0.0)),
		"extrapolate_fraction": float(_presentation_state.get("extrapolate_fraction", 0.0)),
		"hold_fraction": float(_presentation_state.get("hold_fraction", 0.0)),
		"max_consecutive_hold_msec": float(_presentation_state.get(
			"max_consecutive_hold_msec", 0.0)),
		"eligible_bodies": int(_presentation_state.get("eligible_bodies", 0)),
		"warming_bodies": int(_presentation_state.get("warming_bodies", 0)),
		"sequence_gaps_total": _presentation_sequence_gaps_total,
		"last_batch_tick": _last_batch_tick,
		"predictive_offset_units": _predictive_offset_units,
		"predictive_offset_max_units": _predictive_offset_max_units,
		"predictive_lead_units": _predictive_lead_units,
	}
	_predictive_offset_max_units = _predictive_offset_units
	return snapshot


func _report_presentation() -> void:
	var state := AdaptivePresentationDelay.snapshot(_presentation_state)
	print("[presentation-buffer] mode=adaptive state=%s min_ms=%.0f target_ms=%.0f effective_ms=%.1f headroom_ms=min:%.1f,p10:%.1f,median:%.1f variation_ms=p50:%.1f,p95:%.1f,max:%.1f seq_gaps=%d/%d bodies=%d/%d modes=%.2f/%.2f/%.2f hold_run_ms=%.1f pressure=%s age_ms=%.0f healthy_ms=%.0f hitch_samples=%d cursor_spread_ticks=%.3f profile=%s" % [
		str(state["controller_state"]), float(state["minimum_msec"]),
		float(state["target_msec"]), float(state["effective_msec"]),
		float(state["headroom_min_msec"]), float(state["headroom_p10_msec"]),
		float(state["headroom_median_msec"]), float(state["variation_p50_msec"]),
		float(state["variation_p95_msec"]), float(state["variation_max_msec"]),
		int(state["sequence_gaps"]), int(state["recent_sequence_gaps"]),
		int(state["eligible_bodies"]), int(state["warming_bodies"]),
		float(state["interp_fraction"]), float(state["extrapolate_fraction"]),
		float(state["hold_fraction"]), float(state["max_consecutive_hold_msec"]),
		str(state["pressure_reason"]), float(state["pressure_age_msec"]),
		float(state["healthy_age_msec"]), int(state["hitch_contaminated_samples"]),
		float(state["cursor_spread_ticks"]), AdaptivePresentationDelay.PROFILE_VERSION])


func _trace_enabled() -> bool:
	return not _presentation_trace_path.is_empty() and _presentation_trace_duration_msec > 0 \
		and not _presentation_trace_flushed


func _start_presentation_trace(now_msec: int) -> void:
	if _trace_enabled() and _presentation_trace_started_msec < 0:
		_presentation_trace_started_msec = now_msec


func _trace_record(record: Dictionary) -> void:
	if not _trace_enabled() or _presentation_trace_started_msec < 0 \
			or _presentation_trace_flushed:
		return
	if _presentation_trace_records.size() >= PRESENTATION_TRACE_RECORD_CAP:
		_presentation_trace_dropped += 1
		return
	_presentation_trace_records.append(record.duplicate(true))


func _flush_presentation_trace() -> void:
	if _presentation_trace_flushed:
		return
	_presentation_trace_flushed = true
	var header := {"type": "config",
		"trace_version": 2,
		"profile": AdaptivePresentationDelay.PROFILE_VERSION,
		"presentation_mode": _presentation_mode,
		"cursor_clock": _presentation_cursor_clock,
		"minimum_msec": _presentation_min_msec,
		"maximum_msec": _presentation_max_msec,
		"transport": _server_mode, "transport_rate_hz": _server_rate_hz,
		"tickrate": NetworkTime.tickrate,
		"record_count": _presentation_trace_records.size(),
		"dropped": _presentation_trace_dropped}
	if _presentation_trace_path == "console":
		var encoded := Marshalls.utf8_to_base64(
			JSON.stringify([header] + _presentation_trace_records))
		var chunks := maxi(1, int(ceil(float(encoded.length()) \
			/ float(PRESENTATION_TRACE_CHUNK_BYTES))))
		for index in chunks:
			print("[presentation-trace-data] chunk=%d/%d data=%s" % [index + 1,
				chunks, encoded.substr(index * PRESENTATION_TRACE_CHUNK_BYTES,
				PRESENTATION_TRACE_CHUNK_BYTES)])
		print("[presentation-trace-complete] records=%d dropped=%d chunks=%d" % [
			_presentation_trace_records.size(), _presentation_trace_dropped, chunks])
		return
	var file := FileAccess.open(_presentation_trace_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write presentation trace: %s" % _presentation_trace_path)
		return
	file.store_line(JSON.stringify(header))
	for record in _presentation_trace_records:
		file.store_line(JSON.stringify(record))
	file.close()
	print("[presentation-trace-complete] path=%s records=%d dropped=%d" % [
		_presentation_trace_path, _presentation_trace_records.size(),
		_presentation_trace_dropped])

func echo() -> void:
	_print_config("local", _enabled, _mode, _rate_hz, _relevance, _include_self,
		RPC_CHANNEL)

func _print_config(source: String, enabled: bool, mode: String, rate_hz: int,
		relevance: String, include_self: bool, channel: int) -> void:
	print("[remote-state-transport] source=%s enabled=%d mode=%s rate=%d relevance=%s include_self=%d channel=%d" % [
		source, 1 if enabled else 0, mode, rate_hz, relevance,
		1 if include_self else 0, channel])

func _on_peer_join(peer: int) -> void:
	if multiplayer.is_server() and _configured:
		_peer_sequences[peer] = 0
		_peer_stats.erase(peer)
		_push_config.rpc_id(peer, _enabled, _mode, _rate_hz, _relevance,
			_include_self, RPC_CHANNEL)

func _on_peer_leave(peer: int) -> void:
	_peer_sequences.erase(peer)
	_peer_stats.erase(peer)

@rpc("authority", "reliable", "call_remote")
func _push_config(enabled: bool, mode: String, rate_hz: int, relevance: String,
		include_self: bool, channel: int) -> void:
	_server_enabled = enabled
	_server_mode = mode
	_server_rate_hz = rate_hz
	_server_relevance = relevance if Relevance.valid_mode(relevance) else Relevance.MODE_ALL
	_server_include_self = include_self
	_server_config_received = true
	_reset_receiver_epoch(true)
	_print_config("server", enabled, mode, rate_hz, _server_relevance,
		_server_include_self, channel)

## PlayerBody asks during spawn. Batch remotes stay hidden until an accepted
## complete set admits their exact (id, generation) incarnation. This also
## prevents an old-generation packet racing a replicated spawn from flashing it.
func body_starts_remote_position_relevant() -> bool:
	return not (_server_config_received and _server_enabled \
		and _server_mode == MODE_BATCH)

func _after_tick_loop() -> void:
	if not _configured or not _enabled or not multiplayer.is_server():
		return
	var decision := Schedule.advance(_schedule, NetworkTime.tick)
	if not bool(decision["due"]):
		return
	var skipped := int(decision["skipped"])
	_skipped_intervals += skipped
	if skipped > 0:
		_catchup_collapses += 1

	var samples := _sample_bodies()
	var buckets := {}
	var samples_by_id := {}
	for sample in samples:
		var map_id := int(sample["map"])
		if not buckets.has(map_id):
			buckets[map_id] = []
		(buckets[map_id] as Array).append(sample)
		samples_by_id[int(sample["id"])] = sample
	var tick := int(decision["tick"])
	_last_emitted_tick = tick
	_publication_sequence += 1
	if _telemetry:
		print("[remote-state-tick] publication=%d tick=%d mode=%s rate=%d relevance=%s include_self=%d skipped=%d bodies=%d" % [
			_publication_sequence, tick, _mode, _rate_hz, _relevance,
			1 if _include_self else 0, skipped, samples.size()])

	for peer_variant in multiplayer.get_peers():
		var peer := int(peer_variant)
		if _mode == MODE_BATCH:
			_send_relevant_batch(peer, _publication_sequence, tick, samples,
				buckets, samples_by_id)
		else:
			# Legacy/60 is the rollback: all bodies, including self.
			_send_legacy(peer, _publication_sequence, tick, samples)
	_report_if_due()

func _sample_bodies() -> Array:
	var players := get_node_or_null("/root/Main/Players")
	if players == null:
		return []
	var bodies := players.get_children()
	bodies.sort_custom(func(a: Node, b: Node): return int(a.name) < int(b.name))
	var samples: Array = []
	for body in bodies:
		if not body.is_in_group("pilotable"):
			continue
		var state: Variant = body.get("physics_state")
		if not state is Array or state.size() < 1 or not state[0] is Vector3:
			continue
		samples.append({
			"id": int(body.name),
			"generation": int(body.get("remote_state_generation")),
			"map": int(body.get("map_id")),
			"position": state[0] as Vector3,
			"rotation": state[1] as Quaternion if state.size() > 1 and state[1] is Quaternion \
				else body.global_basis.get_rotation_quaternion(),
			"linear_velocity": state[2] as Vector3 if state.size() > 2 and state[2] is Vector3 \
				else body.linear_velocity,
			"angular_velocity": state[3] as Vector3 if state.size() > 3 and state[3] is Vector3 \
				else body.angular_velocity,
		})
	_sampled += samples.size()
	return samples

func _send_legacy(peer: int, publication: int, tick: int, samples: Array) -> void:
	var diagnostic_start := NetworkStageTrace.publication_started()
	for sample in samples:
		var payload := [publication, tick, int(sample["id"]), int(sample["generation"]),
			sample["position"] as Vector3, sample["rotation"] as Quaternion,
			sample["linear_velocity"] as Vector3, sample["angular_velocity"] as Vector3]
		_logical_bytes += var_to_bytes(payload).size()
		_legacy_calls += 1
		_serialized_entries += 1
		NetworkPerformance.record_app_message("out", "remote_state_legacy", payload)
		_push_legacy.rpc_id(peer, publication, tick, int(sample["id"]),
			int(sample["generation"]), sample["position"], sample["rotation"],
			sample["linear_velocity"], sample["angular_velocity"])
	NetworkStageTrace.record_publication(diagnostic_start, MODE_LEGACY, publication,
		tick, peer, samples.size())

func _send_relevant_batch(peer: int, publication: int, tick: int,
		samples: Array, buckets: Dictionary, samples_by_id: Dictionary) -> void:
	var recipient_map := Relevance.UNKNOWN_MAP
	if samples_by_id.has(peer):
		recipient_map = int((samples_by_id[peer] as Dictionary)["map"])

	var filter_started := Time.get_ticks_usec() if _telemetry else 0
	var map_relevant: Array = samples
	if _relevance == Relevance.MODE_SAME_MAP:
		map_relevant = buckets.get(recipient_map, []) as Array
	var selected: Array = []
	for sample in map_relevant:
		if _include_self or int(sample["id"]) != peer:
			selected.append(sample)
	if _telemetry:
		_filter_usec += Time.get_ticks_usec() - filter_started
		var stats := _stats_for_peer(peer)
		stats["sampled"] = int(stats["sampled"]) + samples.size()
		stats["relevant"] = int(stats["relevant"]) + map_relevant.size()
		stats["excluded"] = int(stats["excluded"]) + samples.size() - selected.size()
		stats["self_excluded"] = int(stats["self_excluded"]) \
			+ map_relevant.size() - selected.size()
		stats["recipient_map"] = recipient_map

	if selected.size() > MAX_BODIES:
		_body_cap_exceeded += 1
		push_error("Remote position relevant-set cap exceeded for peer %d: selected %d bodies, maximum is %d; preserving its previous complete membership" % [
			peer, selected.size(), MAX_BODIES])
		return

	var sequence := int(_peer_sequences.get(peer, 0)) + 1
	_peer_sequences[peer] = sequence
	_send_batch(peer, sequence, publication, tick, recipient_map, selected)

func _send_batch(peer: int, sequence: int, publication: int, tick: int,
		recipient_map: int, samples: Array) -> void:
	var diagnostic_start := NetworkStageTrace.publication_started()
	var ids := PackedInt64Array()
	var generations := PackedInt32Array()
	var positions := PackedVector3Array()
	var rotations := PackedVector4Array()
	var linear_velocities := PackedVector3Array()
	var angular_velocities := PackedVector3Array()
	for sample in samples:
		ids.append(int(sample["id"]))
		generations.append(int(sample["generation"]))
		positions.append(sample["position"] as Vector3)
		var rotation: Quaternion = sample["rotation"]
		rotations.append(Vector4(rotation.x, rotation.y, rotation.z, rotation.w))
		linear_velocities.append(sample["linear_velocity"] as Vector3)
		angular_velocities.append(sample["angular_velocity"] as Vector3)
	var payload := [sequence, publication, tick, recipient_map, ids, generations, positions,
		rotations, linear_velocities, angular_velocities]
	var serialize_started := Time.get_ticks_usec() if _telemetry else 0
	var payload_size := var_to_bytes(payload).size()
	var serialize_elapsed := Time.get_ticks_usec() - serialize_started if _telemetry else 0
	_logical_bytes += payload_size
	_serialize_usec += serialize_elapsed
	_batch_envelopes += 1
	_serialized_entries += samples.size()
	if not samples.is_empty() and not _nonempty_batch_proof_printed:
		_nonempty_batch_proof_printed = true
		print("[remote-state-batch-proof] peer=%d tick=%d bodies=%d bytes=%d" % [
			peer, tick, samples.size(), payload_size])
	if _telemetry:
		var stats := _stats_for_peer(peer)
		stats["transmitted"] = int(stats["transmitted"]) + samples.size()
		stats["envelopes"] = int(stats["envelopes"]) + 1
		stats["empty"] = int(stats["empty"]) + (1 if samples.is_empty() else 0)
		stats["logical_bytes"] = int(stats["logical_bytes"]) + payload_size
		stats["serialize_usec"] = int(stats["serialize_usec"]) + serialize_elapsed
	NetworkPerformance.record_app_message("out", "remote_state_batch", payload)
	_push_batch.rpc_id(peer, sequence, publication, tick, recipient_map,
		ids, generations, positions, rotations, linear_velocities, angular_velocities)
	NetworkStageTrace.record_publication(diagnostic_start, MODE_BATCH, publication,
		tick, peer, samples.size())

@rpc("authority", "unreliable", "call_remote", RPC_CHANNEL)
func _push_legacy(publication: int, tick: int, body_id: int, generation: int,
		position: Vector3, rotation: Quaternion, linear_velocity: Vector3,
		angular_velocity: Vector3) -> void:
	var payload := [publication, tick, body_id, generation, position, rotation,
		linear_velocity, angular_velocity]
	NetworkPerformance.record_app_message("in", "remote_state_legacy", payload)
	var arrival_msec := Time.get_ticks_msec() if _trace_enabled() else 0
	_prepare_legacy_body(body_id, generation, tick)
	var delivered := _deliver(body_id, generation, tick, position, rotation,
		linear_velocity, angular_velocity)
	if _trace_enabled():
		_start_presentation_trace(arrival_msec)
		_trace_record({"type": "legacy", "arrival_msec": arrival_msec,
			"publication": publication, "tick": tick, "body_id": body_id,
			"generation": generation, "delivered": delivered,
			"network_tick": NetworkTime.tick, "tick_factor": NetworkTime.tick_factor})

@rpc("authority", "unreliable", "call_remote", RPC_CHANNEL)
func _push_batch(sequence: int, publication: int, tick: int, recipient_map: int,
		ids: PackedInt64Array, generations: PackedInt32Array,
		positions: PackedVector3Array, rotations: PackedVector4Array,
		linear_velocities: PackedVector3Array,
		angular_velocities: PackedVector3Array) -> void:
	var payload := [sequence, publication, tick, recipient_map, ids, generations, positions,
		rotations, linear_velocities, angular_velocities]
	NetworkPerformance.record_app_message("in", "remote_state_batch", payload)
	var disposition := Validation.classify_batch(_last_batch_sequence,
		_last_batch_publication, _last_batch_tick, sequence, publication, tick,
		recipient_map, ids.size(), generations.size(), positions.size(), rotations.size(),
		linear_velocities.size(), angular_velocities.size())
	if disposition == "accept" and not Validation.valid_recipient_map(recipient_map,
			1):
		disposition = "malformed"
	if disposition == "accept" \
			and not Validation.has_valid_unique_membership(ids, generations):
		disposition = "malformed"
	if disposition == "malformed":
		_batch_malformed += 1
		_report_receiver_if_due()
		return
	if disposition == "stale":
		_batch_stale += 1
		_report_receiver_if_due()
		return
	if _last_batch_sequence >= 0 and sequence > _last_batch_sequence + 1:
		var gap_count := sequence - _last_batch_sequence - 1
		_batch_sequence_gaps += gap_count
		_presentation_sequence_gaps_total += gap_count
	_last_batch_sequence = sequence
	_last_batch_publication = publication
	_last_batch_tick = tick
	_last_recipient_map = recipient_map
	_rx_batches += 1
	_rx_entries += ids.size()
	var presentation_arrival_msec := Time.get_ticks_msec()
	if _presentation_mode == "adaptive" or _trace_enabled():
		_start_presentation_trace(presentation_arrival_msec)
		_presentation_pending_batches.append({
			"type": "batch",
			"sequence": sequence,
			"publication": publication,
			"tick": tick,
			"arrival_msec": presentation_arrival_msec,
			"network_tick": NetworkTime.tick,
			"tick_factor": NetworkTime.tick_factor,
			"recipient_map": recipient_map,
			"entries": ids.size(),
		})

	# The complete set becomes presentation membership only after the entire
	# envelope has passed structural and temporal validation.
	var desired := {}
	for i in ids.size():
		var body_id := int(ids[i])
		var generation := int(generations[i])
		var body := _body_for_delivery(body_id)
		if body == null:
			_unknown_bodies += 1
			continue
		if not body.remote_position_transport_controlled():
			continue
		if int(body.get("remote_state_generation")) != generation:
			_unknown_bodies += 1
			continue
		desired[Relevance.membership_key(body_id, generation)] = {
			"id": body_id,
			"generation": generation,
		}

	var membership_delta := Relevance.membership_delta(_active_membership, desired)
	var left: Dictionary = membership_delta["left"]
	var entered: Dictionary = membership_delta["entered"]
	for key in left:
		var previous: Dictionary = left[key]
		var leaving := _body_for_delivery(int(previous["id"]))
		if leaving != null and leaving.remote_position_transport_controlled() \
				and int(leaving.get("remote_state_generation")) == int(previous["generation"]):
			leaving.set_remote_position_relevant(false, tick)

	for key in entered:
		var entering: Dictionary = entered[key]
		var body := _body_for_delivery(int(entering["id"]))
		if body != null:
			body.set_remote_position_relevant(true, tick)

	_membership_enters += entered.size()
	_membership_leaves += left.size()
	if _telemetry and (not entered.is_empty() or not left.is_empty()):
		print("[remote-state-membership] tick=%d map=%d entered=%d left=%d active=%d" % [
			tick, recipient_map, entered.size(), left.size(), desired.size()])
	_active_membership = desired
	for i in ids.size():
		var body_id := int(ids[i])
		var generation := int(generations[i])
		if desired.has(Relevance.membership_key(body_id, generation)):
			var packed_rotation := rotations[i]
			_deliver(body_id, generation, tick, positions[i], Quaternion(packed_rotation.x,
				packed_rotation.y, packed_rotation.z, packed_rotation.w).normalized(),
				linear_velocities[i], angular_velocities[i])
	_report_receiver_if_due()

func _body_for_delivery(body_id: int) -> Node:
	var body := get_node_or_null("/root/Main/Players/%s" % body_id)
	if not Validation.is_deliverable_body(body):
		return null
	return body

func _deliver(body_id: int, generation: int, tick: int,
		position: Vector3, rotation: Quaternion, linear_velocity: Vector3,
		angular_velocity: Vector3) -> bool:
	var body := _body_for_delivery(body_id)
	if body == null:
		_unknown_bodies += 1
		return false
	return bool(body.receive_remote_position(generation, tick, position, rotation,
		linear_velocity, angular_velocity))

func _prepare_legacy_body(body_id: int, generation: int, tick: int) -> void:
	var body := _body_for_delivery(body_id)
	if body == null or not body.remote_position_transport_controlled():
		return
	if int(body.get("remote_state_generation")) == generation \
			and not body.is_remote_position_relevant():
		body.set_remote_position_relevant(true, tick)

func _stats_for_peer(peer: int) -> Dictionary:
	if not _peer_stats.has(peer):
		_peer_stats[peer] = {
			"sampled": 0,
			"relevant": 0,
			"excluded": 0,
			"self_excluded": 0,
			"transmitted": 0,
			"envelopes": 0,
			"empty": 0,
			"logical_bytes": 0,
			"serialize_usec": 0,
			"recipient_map": Relevance.UNKNOWN_MAP,
		}
	return _peer_stats[peer]

func _report_if_due() -> void:
	if not _telemetry:
		return
	var now := Time.get_ticks_msec()
	if now - _window_started_msec < 1000:
		return
	print("[remote-state-wire] mode=%s rate=%d relevance=%s include_self=%d publication=%d last_tick=%d sampled=%d legacy_calls=%d batches=%d entries=%d logical_bytes=%d filter_us=%d serialize_us=%d skipped=%d collapses=%d cap_exceeded=%d rx_batch_gaps=%d stale=%d malformed=%d unknown=%d" % [
		_mode, _rate_hz, _relevance, 1 if _include_self else 0,
		_publication_sequence, _last_emitted_tick, _sampled, _legacy_calls,
		_batch_envelopes, _serialized_entries, _logical_bytes, _filter_usec,
		_serialize_usec, _skipped_intervals, _catchup_collapses,
		_body_cap_exceeded, _batch_sequence_gaps, _batch_stale,
		_batch_malformed, _unknown_bodies])
	for peer_variant in _peer_stats:
		var peer := int(peer_variant)
		var stats: Dictionary = _peer_stats[peer]
		print("[remote-state-peer] peer=%d map=%d sampled=%d relevant=%d excluded=%d self_excluded=%d transmitted=%d envelopes=%d empty=%d logical_bytes=%d serialize_us=%d" % [
			peer, int(stats["recipient_map"]), int(stats["sampled"]),
			int(stats["relevant"]), int(stats["excluded"]),
			int(stats["self_excluded"]), int(stats["transmitted"]),
			int(stats["envelopes"]), int(stats["empty"]),
			int(stats["logical_bytes"]), int(stats["serialize_usec"])])
	_reset_window()

func _reset_window() -> void:
	_window_started_msec = Time.get_ticks_msec()
	_sampled = 0
	_legacy_calls = 0
	_batch_envelopes = 0
	_serialized_entries = 0
	_logical_bytes = 0
	_filter_usec = 0
	_serialize_usec = 0
	_skipped_intervals = 0
	_catchup_collapses = 0
	_body_cap_exceeded = 0
	_batch_sequence_gaps = 0
	_batch_stale = 0
	_batch_malformed = 0
	_unknown_bodies = 0
	_peer_stats.clear()

func _reset_receiver_epoch(transition_presentation := false) -> void:
	_presentation_frame_usec = -1
	_last_batch_sequence = -1
	_last_batch_publication = -1
	_last_batch_tick = -1
	_last_recipient_map = Relevance.UNKNOWN_MAP
	_active_membership.clear()
	if transition_presentation:
		var players := get_node_or_null("/root/Main/Players")
		if players != null:
			for body in players.get_children():
				if body.has_method("remote_position_transport_controlled") \
						and body.remote_position_transport_controlled():
					if _server_enabled and _server_mode == MODE_BATCH:
						# A fresh batch epoch owns a fresh complete set. Even
						# all-mode bodies must not retain a pre-reconnect sample.
						body.set_remote_position_relevant(false, NetworkTime.tick)
						if _server_relevance == Relevance.MODE_ALL:
							body.set_remote_position_relevant(true, NetworkTime.tick)
					else:
						body.set_remote_position_relevant(true, NetworkTime.tick)
	_rx_window_started_msec = Time.get_ticks_msec()
	_rx_batches = 0
	_rx_entries = 0
	_batch_sequence_gaps = 0
	_batch_stale = 0
	_batch_malformed = 0
	_unknown_bodies = 0
	_membership_enters = 0
	_membership_leaves = 0
	_presentation_pending_batches.clear()
	_presentation_body_samples.clear()
	_presentation_sequence_gaps_total = 0
	if not _presentation_state.is_empty():
		AdaptivePresentationDelay.reset_epoch(_presentation_state, Time.get_ticks_msec())
	_trace_record({"type": "epoch", "at_msec": Time.get_ticks_msec()})

func _report_receiver_if_due() -> void:
	if not _telemetry:
		return
	var now := Time.get_ticks_msec()
	if now - _rx_window_started_msec < 1000:
		return
	print("[remote-state-rx] mode=%s rate=%d relevance=%s include_self=%d map=%d batches=%d entries=%d enters=%d leaves=%d active=%d last_seq=%d publication=%d last_tick=%d gaps=%d stale=%d malformed=%d unknown=%d" % [
		_server_mode, _server_rate_hz, _server_relevance,
		1 if _server_include_self else 0, _last_recipient_map, _rx_batches,
		_rx_entries, _membership_enters, _membership_leaves,
		_active_membership.size(), _last_batch_sequence, _last_batch_publication,
		_last_batch_tick, _batch_sequence_gaps, _batch_stale,
		_batch_malformed, _unknown_bodies])
	_rx_window_started_msec = now
	_rx_batches = 0
	_rx_entries = 0
	_batch_sequence_gaps = 0
	_batch_stale = 0
	_batch_malformed = 0
	_unknown_bodies = 0
	_membership_enters = 0
	_membership_leaves = 0
