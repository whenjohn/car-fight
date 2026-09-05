extends Node
class_name _RollbackHistoryTransmitter

var root: Node
var enable_input_broadcast: bool = true
var full_state_interval: int
var diff_ack_interval: int

# Provided externally by RBS
var _state_history: _PropertyHistoryBuffer
var _input_history: _PropertyHistoryBuffer
var _visibility_filter: PeerVisibilityFilter

var _state_property_config: _PropertyConfig
var _input_property_config: _PropertyConfig

var _property_cache: PropertyCache
var _skipset: _Set

# Collaborators
var _input_encoder: _RedundantHistoryEncoder
var _full_state_encoder: _SnapshotHistoryEncoder
var _diff_state_encoder: _DiffHistoryEncoder

# State
var _ackd_state: Dictionary = {}
# Per-peer pacing for the no-usable-reference full-state fallback; only consulted while StateBundle is enabled.
var _fallback_full_state_ticks: Dictionary = {}
# The body's physics_state property path (":physics_state"), cached at reset for the packed-state diff
# deadband; empty when this body has none registered (the deadband then simply never engages).
var _physics_prop := ""
var _next_full_state_tick: int
var _next_diff_ack_tick: int

var _earliest_input_tick: int
var _latest_state_tick: int
var _recovery_request_after_msec := 0

var _is_predicted_tick: bool
var _is_initialized: bool

# Signals
signal _on_transmit_state(state: Dictionary, tick: int)

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("RollbackHistoryTransmitter")

func get_earliest_input_tick() -> int:
	return _earliest_input_tick

func get_latest_state_tick() -> int:
	return _latest_state_tick

func set_predicted_tick(p_is_predicted_tick) -> void:
	_is_predicted_tick = p_is_predicted_tick

## Legacy-path recovery used when StateBundle is disabled. Bundled peers recover
## through coordinated complete keys instead of one body at a time.
func request_full_state(reason: String) -> void:
	if StateBundle.is_enabled() or not _is_initialized \
			or multiplayer.multiplayer_peer == null:
		return
	var state_owner := root.get_multiplayer_authority()
	if state_owner == multiplayer.get_unique_id():
		return
	var now := Time.get_ticks_msec()
	if now < _recovery_request_after_msec:
		return
	_recovery_request_after_msec = now + 1000
	print("[netfox-recovery] request root=%s owner=%d latest=%d history_start=%d reason=%s" % [
		root.get_path(), state_owner, _latest_state_tick, NetworkRollback.history_start, reason,
	])
	_request_full_state.rpc_id(state_owner)

func sync_settings(p_root: Node, p_enable_input_broadcast: bool, p_full_state_interval: int, p_diff_ack_interval: int) -> void:
	root = p_root
	enable_input_broadcast = p_enable_input_broadcast
	full_state_interval = p_full_state_interval
	diff_ack_interval = p_diff_ack_interval

func configure(
		p_state_history: _PropertyHistoryBuffer, p_input_history: _PropertyHistoryBuffer,
		p_state_property_config: _PropertyConfig, p_input_property_config: _PropertyConfig,
		p_visibility_filter: PeerVisibilityFilter,
		p_property_cache: PropertyCache,
		p_skipset: _Set
	) -> void:
	_state_history = p_state_history
	_input_history = p_input_history
	_state_property_config = p_state_property_config
	_input_property_config = p_input_property_config
	_visibility_filter = p_visibility_filter
	_property_cache = p_property_cache
	_skipset = p_skipset

	_input_encoder = _RedundantHistoryEncoder.new(_input_history, _property_cache)
	_full_state_encoder = _SnapshotHistoryEncoder.new(_state_history, _property_cache)
	_diff_state_encoder = _DiffHistoryEncoder.new(_state_history, _property_cache)

	_is_initialized = true

	reset()

func reset() -> void:
	_ackd_state.clear()
	_fallback_full_state_ticks.clear()
	_latest_state_tick = NetworkTime.tick - 1
	_earliest_input_tick = NetworkTime.tick
	_next_full_state_tick = NetworkTime.tick
	_next_diff_ack_tick = NetworkTime.tick

	# Scatter full state sends, so not all nodes send at the same tick
	if is_inside_tree():
		_next_full_state_tick += hash(root.get_path()) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(root.get_path()) % maxi(1, diff_ack_interval)
	else:
		_next_full_state_tick += hash(root.name) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(root.name) % maxi(1, diff_ack_interval)

	_diff_state_encoder.add_properties(_state_property_config.get_properties())
	_full_state_encoder.set_properties(_get_owned_state_props())
	_input_encoder.set_properties(_get_owned_input_props())
	_physics_prop = ""
	for property in _get_recorded_state_props():
		if property.to_string().ends_with(":physics_state"):
			_physics_prop = property.to_string()
			break
	StateBundle.register_synchronizer(root, self)

func conclude_tick_loop() -> void:
	_earliest_input_tick = NetworkTime.tick

# A few input packets' worth. Input packets carry a redundancy window of recent inputs, so a skipped send
# is covered by the next one that goes out. Queueing beyond this is stale poison: the 2026-07-19 one-Chrome
# run measured the browser's unreliable send buffer ramping to 461KB (~6 seconds of queued inputs) while
# netfox catch-up bursts RAISED the send rate into the collapsed congestion window. Healthy play samples
# 1-9KB, so this threshold only engages under real congestion.
const INPUT_BACKPRESSURE_BYTES := 16384
# The 16KB threshold above was calibrated against 512B Variant messages (~32 queued ≈ 0.5s). Packed input
# messages are ~35B, so 16KB would hide ~7s of queue while input_bp_dropped read 0. 4KB sits above the
# healthy 0-3KB transport-queue band and equals ~2s of packed input — verify input_bp_dropped stays 0 in
# the unshaped window of the next TURN acceptance run.
const INPUT_BACKPRESSURE_BYTES_PACKED := 4096

func _input_backpressure_bytes(wire_data: Array) -> int:
	return (INPUT_BACKPRESSURE_BYTES_PACKED if StateBundle.INPUT_CODEC.is_packed(wire_data)
		else INPUT_BACKPRESSURE_BYTES)

func transmit_input(tick: int) -> void:
	if not _get_owned_input_props().is_empty():
		var input_tick: int = tick + NetworkRollback.input_delay
		var input_data := _input_encoder.encode(input_tick, _get_owned_input_props())
		var state_owning_peer := root.get_multiplayer_authority()
		NetworkRollback.register_input_submission(root, tick)

		if enable_input_broadcast:
			var input_targets := _visibility_filter.get_rpc_target_peers()
			if StateBundle.needs_input_target_expansion():
				# PeerVisibilityFilter normally compresses "everyone" to target 0 (and
				# "everyone except X" to -X). Option B needs concrete recipients so the
				# WebRTC subset can be removed without changing ENet→ENet delivery.
				input_targets = _visibility_filter.get_visible_peers().duplicate()
				input_targets.erase(multiplayer.get_unique_id())
			for peer in input_targets:
				if not StateBundle.should_broadcast_input_to(peer):
					continue
				var wire_data := StateBundle.pack_input(
					input_data, _get_owned_input_props(), peer)
				# Input packets carry recent history, so a congested send is replaceable by the next
				# fresh packet after the queue drains. Never exempt the state-owner copy: the forced-TURN
				# combined run proved that even 35B packed inputs can accumulate behind SCTP congestion,
				# delivering seconds-old control and causing large authoritative corrections.
				if StateBundle.peer_send_pressure(peer) > _input_backpressure_bytes(wire_data):
					NetworkPerformance.note_app_input_backpressure_dropped(1)
					continue
				_submit_input.rpc_id(peer, input_tick, wire_data)
				NetworkPerformance.record_app_message("out", "input", [input_tick, wire_data])
		elif state_owning_peer != multiplayer.get_unique_id():
			var wire_data := StateBundle.pack_input(
				input_data, _get_owned_input_props(), state_owning_peer)
			if StateBundle.peer_send_pressure(state_owning_peer) \
					> _input_backpressure_bytes(wire_data):
				NetworkPerformance.note_app_input_backpressure_dropped(1)
				return
			_submit_input.rpc_id(state_owning_peer, input_tick, wire_data)
			NetworkPerformance.record_app_message("out", "input", [input_tick, wire_data])

func transmit_state(tick: int) -> void:
	if _get_owned_state_props().is_empty():
		# We don't own state, don't transmit anything
		return

	var is_coordinated_key := StateBundle.is_key_tick(tick)
	if _is_predicted_tick and not _input_property_config.get_properties().is_empty() \
			and not is_coordinated_key:
		# Don't transmit anything if we're predicting
		# EXCEPT when we're running inputless. Bundled coordinated keys are the
		# other exception: at real network latency the server's current tick is
		# normally predicted for a remote-owned input stream, but the settled
		# post-loop best authority still has to participate in a complete world
		# key. Later arrived input corrects it through the ordinary history path.
		return

	# Include properties we own
	var full_state := _PropertySnapshot.new()

	for property in _get_owned_state_props():
		if _should_broadcast(property, tick):
			full_state.set_value(property.to_string(), property.get_value())

	_on_transmit_state.emit(full_state, tick)

	# No properties to send?
	if full_state.is_empty() and not is_coordinated_key:
		return

	_latest_state_tick = max(_latest_state_tick, tick)

	var is_sending_diffs := NetworkRollback.enable_diff_states
	var is_full_state_tick := (is_coordinated_key or not is_sending_diffs
		or (full_state_interval > 0 and tick > _next_full_state_tick))

	if is_full_state_tick:
		# Broadcast new full state
		# Direct RPCs can use Godot's 0/-peer broadcast shortcuts. Bundles must use concrete recipients so each
		# peer gets exactly one envelope containing only the state visible to it.
		var full_state_peers := (_visibility_filter.get_visible_peers() if StateBundle.is_enabled()
			else _visibility_filter.get_rpc_target_peers())
		for peer in full_state_peers:
			_send_full_state(tick, peer)

		# Adjust next full state if sending diffs
		if is_sending_diffs:
			_next_full_state_tick = tick + full_state_interval
	else:
		# Send diffs to each peer
		for peer in _visibility_filter.get_visible_peers():
			var reference_tick := _ackd_state.get(peer, -1) as int
			if reference_tick < 0 or not _state_history.has(reference_tick):
				# Peer hasn't ack'd any tick, or we don't have the ack'd tick
				# Send full state
				if StateBundle.is_enabled() and tick < int(_fallback_full_state_ticks.get(peer, 0)):
					# Pace this fallback under bundling. Acknowledgements stop exactly when a peer's link
					# congests, and streaming 60Hz full states at that moment nearly tripled the offered
					# load in the 2026-07-19 collapse (52→137KB/s) — pushing hardest when the link can
					# least afford it. The coordinated key already repairs a bundled peer.
					continue
				_fallback_full_state_ticks[peer] = tick + StateBundle.KEY_INTERVAL
				_send_full_state(tick, peer)
				continue

			# Prepare diff
			var diff_state_data := _diff_state_encoder.encode(tick, reference_tick, _get_owned_state_props())

			if _diff_state_encoder.get_full_snapshot().size() == _diff_state_encoder.get_encoded_snapshot().size():
				# State is completely different, send full state
				_send_full_state(tick, peer)
			else:
				# Pack the WIRE copy only (the encoder's history stays exact — C1). The reference block
				# arms the deadband: a physics entry landing on the same grid point as the peer's ack'd
				# reference is dropped, which is what turns can_sleep=false float-jitter into empty diffs.
				var wire_diff := StateBundle.pack_state_diff(diff_state_data,
					_packed_reference_block(reference_tick, peer), peer)
				# Send only diff
				if not StateBundle.queue_state(peer, tick, root, StateBundle.DIFF, wire_diff, reference_tick):
					_submit_diff_state.rpc_id(peer, wire_diff, tick, reference_tick)
					NetworkPerformance.record_app_message("out", "state_diff", [wire_diff, tick, reference_tick])

				# Push metrics
				NetworkPerformance.push_full_state(_diff_state_encoder.get_full_snapshot())
				NetworkPerformance.push_sent_state(_diff_state_encoder.get_encoded_snapshot())

## The peer's ack'd reference physics_state, packed — the deadband comparand. get_history (closest-at-or-
## before fallback) matches what _DiffHistoryEncoder's make_patch compared against, which is exactly the
## value the receiving peer applied and will keep on a merge() miss. Empty (deadband off) when packing is
## off, the body has no physics_state, or the reference value is missing/mis-shaped.
func _packed_reference_block(reference_tick: int, peer: int) -> PackedByteArray:
	if not StateBundle.peer_uses_packed_state(peer) or _physics_prop == "":
		return PackedByteArray()
	return StateBundle.pack_physics_block(
		_state_history.get_history(reference_tick).get_value(_physics_prop))

func _should_broadcast(property: PropertyEntry, tick: int) -> bool:
	# Only broadcast if we've simulated the node
	# NOTE: _can_simulate checks mutations, but to override _skipset
	# we check first
	if NetworkRollback.is_mutated(property.node, tick - 1):
		return true
	if _skipset.has(property.node):
		return false
	if NetworkRollback.is_rollback_aware(property.node):
		return NetworkRollback.is_simulated(property.node)

	# Node is not rollback-aware, broadcast updates only if we own it
	return property.node.is_multiplayer_authority()

func _send_full_state(tick: int, peer: int = 0) -> void:
	var full_state_snapshot := _state_history.get_snapshot(tick).as_dictionary()
	var full_state_data := _full_state_encoder.encode(tick, _get_owned_state_props())
	# Wire copy only (C1): the snapshot/history above stay exact; keys and recovery fulls all route
	# through here, so they shrink by the same physics_state fraction.
	var wire_full := StateBundle.pack_state_full(full_state_data, peer)

	if not StateBundle.queue_state(peer, tick, root, StateBundle.FULL, wire_full):
		_submit_full_state.rpc_id(peer, wire_full, tick)
		NetworkPerformance.record_app_message("out", "state_full", [wire_full, tick])

	if peer <= 0:
		NetworkPerformance.push_full_state_broadcast(full_state_snapshot)
		NetworkPerformance.push_sent_state_broadcast(full_state_snapshot)
	else:
		NetworkPerformance.push_full_state(full_state_snapshot)
		NetworkPerformance.push_sent_state(full_state_snapshot)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		NetworkRollback.free_input_submission_data_for(root)
		StateBundle.unregister_synchronizer(root, self)

@rpc("any_peer", "unreliable", "call_remote")
func _submit_input(tick: int, data: Array) -> void:
	NetworkPerformance.record_app_message("in", "input", [tick, data])
	if not _is_initialized:
		# Settings not processed yet
		return

	# Type-driven unwrap of the opt-in packed wire format ([PackedByteArray] with a magic byte); legacy
	# flat Variant arrays pass through untouched. A malformed packed payload unpacks to [] and decode()
	# then applies nothing — loud in the log, never garbage into the sim.
	var sender := multiplayer.get_remote_sender_id()
	var properties := _input_property_config.get_properties_owned_by(sender)
	data = StateBundle.unpack_input(data, properties)
	var snapshots := _input_encoder.decode(data, properties)
	var earliest_received_input = _input_encoder.apply(tick, snapshots, sender)
	if earliest_received_input >= 0:
		_earliest_input_tick = mini(_earliest_input_tick, earliest_received_input)
		NetworkRollback.register_input_submission(root, tick)

# `serialized_state` is a serialized _PropertySnapshot
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_full_state(data: Array, tick: int) -> void:
	_receive_full_state(data, tick, multiplayer.get_remote_sender_id(), true)

func receive_bundled_full_state(data: Array, tick: int, sender: int) -> bool:
	# StateBundle acknowledges every successfully applied full route in one RPC.
	# Sending an RPC here would undo downlink coalescing with an uplink ack storm.
	return _receive_full_state(data, tick, sender, false, false)

func _receive_full_state(data: Array, tick: int, sender: int, count_wire_message: bool,
		send_ack: bool = true) -> bool:
	if count_wire_message:
		NetworkPerformance.record_app_message("in", "state_full", [data, tick])
	NetworkPerformance.note_app_state_received(tick)
	if not _is_initialized:
		# Settings not processed yet
		return false

	# Type-driven unwrap of the opt-in packed state format (magic-tagged physics values); legacy arrays
	# pass through untouched. A malformed packed value unpacks to [] — loud reject, nothing applied.
	data = StateBundle.unpack_state_full(data)
	if data.is_empty():
		NetworkPerformance.note_app_state_rejected()
		return false

	var snapshot := _full_state_encoder.decode(data, _state_property_config.get_properties_owned_by(sender))
	if not _full_state_encoder.apply(tick, snapshot, sender):
		# Invalid data
		NetworkPerformance.note_app_state_rejected()
		return false

	_latest_state_tick = tick
	NetworkPerformance.note_app_state_applied(tick)
	if NetworkRollback.enable_diff_states and send_ack:
		_ack_full_state.rpc_id(sender, tick)
		NetworkPerformance.record_app_message("out", "state_full_ack", [tick])
	return true

func receive_bundled_full_ack(tick: int, sender_id: int) -> void:
	_ackd_state[sender_id] = tick
	_logger.trace("Peer %d ack'd bundled full state for tick %d", [sender_id, tick])

# State is a serialized _PropertySnapshot (Dictionary[String, Variant])
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_diff_state(data: PackedByteArray, tick: int, reference_tick: int) -> void:
	_receive_diff_state(data, tick, reference_tick, multiplayer.get_remote_sender_id(), true)

func receive_bundled_diff_state(data: PackedByteArray, tick: int, reference_tick: int, sender: int) -> bool:
	return _receive_diff_state(data, tick, reference_tick, sender, false)

func _receive_diff_state(data: PackedByteArray, tick: int, reference_tick: int, sender: int,
		count_wire_message: bool) -> bool:
	if count_wire_message:
		NetworkPerformance.record_app_message("in", "state_diff", [data, tick, reference_tick])
	NetworkPerformance.note_app_state_received(tick)
	if not _is_initialized:
		# Settings not processed yet
		return false

	# Type-driven unwrap of the opt-in packed diff format (magic 0xB8); legacy buffers pass through.
	# null = malformed packed payload — loud reject, nothing applied.
	var unpacked: Variant = StateBundle.unpack_state_diff(data)
	if unpacked == null:
		NetworkPerformance.note_app_state_rejected()
		return false
	data = unpacked

	var diff_snapshot := _diff_state_encoder.decode(data, _state_property_config.get_properties_owned_by(sender))
	if not _diff_state_encoder.apply(tick, diff_snapshot, reference_tick, sender):
		# Invalid data
		NetworkPerformance.note_app_state_rejected()
		if not _state_history.has(reference_tick):
			request_full_state("missing_diff_reference")
		return false

	_latest_state_tick = tick
	NetworkPerformance.note_app_state_applied(tick)

	if NetworkRollback.enable_diff_states:
		if diff_ack_interval > 0 and tick > _next_diff_ack_tick:
			_ack_diff_state.rpc_id(sender, tick)
			NetworkPerformance.record_app_message("out", "state_diff_ack", [tick])
			_next_diff_ack_tick = tick + diff_ack_interval
	return true

## Apply a complete coordinated key whose source tick is too old for retained rollback history. Rebase the
## authoritative snapshot at the client's current tick and apply it immediately as one visible correction.
## The bundle coordinator then resets server diff references and waits for a fresh coordinated key.
func apply_recovery_full_state(data: Array, target_tick: int, sender: int) -> bool:
	if not _is_initialized:
		return false
	# Recovery keys are _send_full_state payloads that aged in the coalescer — same packed format,
	# same type-driven unwrap. (The coalescer never inspects payloads, so they arrive here still packed.)
	data = StateBundle.unpack_state_full(data)
	if data.is_empty():
		NetworkPerformance.note_app_state_rejected()
		return false
	var snapshot := _full_state_encoder.decode(data, _state_property_config.get_properties_owned_by(sender))
	if sender > 0:
		snapshot.sanitize(sender, _property_cache)
	if snapshot.is_empty():
		NetworkPerformance.note_app_state_rejected()
		return false
	_state_history.clear()
	_state_history.set_snapshot(target_tick, snapshot)
	snapshot.apply(_property_cache)
	_latest_state_tick = target_tick
	return true

func reset_peer_state_reference(peer: int) -> void:
	_ackd_state.erase(peer)
	# Clear the fallback pacing too: every transmitter is reset on the same request, so every fallback
	# fires on the same next diff tick — one complete all-full ORDINARY envelope the recovering client can
	# promote to a key even while the reliable key channel is head-of-line blocked. Mid-pace leftovers
	# would stagger the fulls across ticks and no single envelope would ever be complete.
	_fallback_full_state_ticks.erase(peer)
	_next_full_state_tick = NetworkTime.tick

@rpc("any_peer", "reliable", "call_remote")
func _request_full_state() -> void:
	if StateBundle.is_enabled() or not _is_initialized \
			or root.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	var requester := multiplayer.get_remote_sender_id()
	if requester <= 0 or not multiplayer.get_peers().has(requester) \
			or not _visibility_filter.get_visibility_for(requester) or _state_history.is_empty():
		return
	var recovery_tick := _state_history.get_latest_tick()
	var full_state_data := _full_state_encoder.encode(recovery_tick, _get_owned_state_props())
	print("[netfox-recovery] send root=%s peer=%d tick=%d" % [
		root.get_path(), requester, recovery_tick,
	])
	_submit_recovery_full_state.rpc_id(requester, full_state_data, recovery_tick)

@rpc("authority", "reliable", "call_remote")
func _submit_recovery_full_state(data: Array, tick: int) -> void:
	if StateBundle.is_enabled() or not _is_initialized:
		return
	var sender := multiplayer.get_remote_sender_id()
	if _receive_full_state(data, tick, sender, false):
		print("[netfox-recovery] applied root=%s sender=%d tick=%d" % [
			root.get_path(), sender, tick,
		])

@rpc("any_peer", "reliable", "call_remote")
func _ack_full_state(tick: int) -> void:
	NetworkPerformance.record_app_message("in", "state_full_ack", [tick])
	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd full state for tick %d", [sender_id, tick])

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _ack_diff_state(tick: int) -> void:
	NetworkPerformance.record_app_message("in", "state_diff_ack", [tick])
	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd diff state for tick %d", [sender_id, tick])

# =============================================================================
# Shared utils, extract later

func _get_recorded_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_properties()

func _get_owned_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_owned_properties()

func _get_recorded_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()

func _get_owned_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()
