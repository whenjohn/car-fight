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

func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	NetworkEvents.on_peer_join.connect(_on_peer_join)
	NetworkEvents.on_peer_leave.connect(_on_peer_leave)
	NetworkEvents.on_client_start.connect(func(_id): _reset_receiver_epoch())
	NetworkEvents.on_client_stop.connect(_reset_receiver_epoch)

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
		})
	_sampled += samples.size()
	return samples

func _send_legacy(peer: int, publication: int, tick: int, samples: Array) -> void:
	for sample in samples:
		var payload := [publication, tick, int(sample["id"]), int(sample["generation"]),
			sample["position"] as Vector3]
		_logical_bytes += var_to_bytes(payload).size()
		_legacy_calls += 1
		_serialized_entries += 1
		NetworkPerformance.record_app_message("out", "remote_state_legacy", payload)
		_push_legacy.rpc_id(peer, publication, tick, int(sample["id"]),
			int(sample["generation"]), sample["position"])

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
	var ids := PackedInt64Array()
	var generations := PackedInt32Array()
	var positions := PackedVector3Array()
	for sample in samples:
		ids.append(int(sample["id"]))
		generations.append(int(sample["generation"]))
		positions.append(sample["position"] as Vector3)
	var payload := [sequence, publication, tick, recipient_map, ids, generations, positions]
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
		ids, generations, positions)

@rpc("authority", "unreliable", "call_remote", RPC_CHANNEL)
func _push_legacy(publication: int, tick: int, body_id: int, generation: int,
		position: Vector3) -> void:
	var payload := [publication, tick, body_id, generation, position]
	NetworkPerformance.record_app_message("in", "remote_state_legacy", payload)
	_prepare_legacy_body(body_id, generation, tick)
	_deliver(body_id, generation, tick, position)

@rpc("authority", "unreliable", "call_remote", RPC_CHANNEL)
func _push_batch(sequence: int, publication: int, tick: int, recipient_map: int,
		ids: PackedInt64Array, generations: PackedInt32Array,
		positions: PackedVector3Array) -> void:
	var payload := [sequence, publication, tick, recipient_map, ids, generations, positions]
	NetworkPerformance.record_app_message("in", "remote_state_batch", payload)
	var disposition := Validation.classify_batch(_last_batch_sequence,
		_last_batch_publication, _last_batch_tick, sequence, publication, tick,
		recipient_map, ids.size(), generations.size(), positions.size())
	if disposition == "accept" and not _valid_recipient_map(recipient_map):
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
		_batch_sequence_gaps += sequence - _last_batch_sequence - 1
	_last_batch_sequence = sequence
	_last_batch_publication = publication
	_last_batch_tick = tick
	_last_recipient_map = recipient_map
	_rx_batches += 1
	_rx_entries += ids.size()

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
			_deliver(body_id, generation, tick, positions[i])
	_report_receiver_if_due()

func _body_for_delivery(body_id: int) -> Node:
	var body := get_node_or_null("/root/Main/Players/%s" % body_id)
	if not Validation.is_deliverable_body(body):
		return null
	return body

func _valid_recipient_map(recipient_map: int) -> bool:
	return recipient_map == Relevance.UNKNOWN_MAP \
		or recipient_map in [MapLayout.ARENA, MapLayout.DRIVING_COURSE]

func _deliver(body_id: int, generation: int, tick: int,
		position: Vector3) -> bool:
	var body := _body_for_delivery(body_id)
	if body == null:
		_unknown_bodies += 1
		return false
	return bool(body.receive_remote_position(generation, tick, position))

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
