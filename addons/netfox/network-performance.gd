extends Node
class_name _NetworkPerformance

const NETWORK_LOOP_DURATION_MONITOR: StringName = &"netfox/Network loop duration (ms)"
const ROLLBACK_LOOP_DURATION_MONITOR: StringName = &"netfox/Rollback loop duration (ms)"
const NETWORK_TICKS_MONITOR: StringName = &"netfox/Network ticks simulated"
const ROLLBACK_TICKS_MONITOR: StringName = &"netfox/Rollback ticks simulated"
const ROLLBACK_TICK_DURATION_MONITOR: StringName = &"netfox/Rollback tick duration (ms)"
const ROLLBACK_NODES_SIMULATED_MONITOR: StringName = &"netfox/Rollback nodes simulated"
const ROLLBACK_NODES_SIMULATED_PER_TICK_MONITOR: StringName = &"netfox/Rollback nodes simulated per tick (avg)"

const FULL_STATE_PROPERTIES_COUNT: StringName = &"netfox/Full state properties count"
const SENT_STATE_PROPERTIES_COUNT: StringName = &"netfox/Sent state properties count"
const SENT_STATE_PROPERTIES_RATIO: StringName = &"netfox/Sent state properties ratio"

var _network_loop_start: float = 0
var _network_loop_duration: float = 0

var _network_ticks: int = 0
var _network_ticks_accum: int = 0

var _rollback_loop_start: float = 0
var _rollback_loop_duration: float = 0

var _rollback_ticks: int = 0
var _rollback_ticks_accum: int = 0

var _rollback_nodes_simulated: int = 0
var _rollback_nodes_simulated_accum: int = 0

var _full_state_props: int = 0
var _full_state_props_accum: int = 0

var _sent_state_props: int = 0
var _sent_state_props_accum: int = 0

# g2 application-wire telemetry. This is deliberately opt-in: serializing RPC payloads to estimate their wire
# size adds work, and browser console collection must stay off during ordinary play. The counters aggregate here
# so individual RPC seams only pay one method call when enabled and never print from inside the rollback loop.
var _app_telemetry_enabled := false
var _app_message_counts: Dictionary = {}
var _app_payload_bytes: Dictionary = {}
var _app_bundle_counts: Dictionary = {}
var _app_bundle_entries: Dictionary = {}
var _app_bundle_bytes: Dictionary = {}
var _app_bundles_skipped := 0
var _app_bundles_backpressure_dropped := 0
var _app_inputs_backpressure_dropped := 0
var _app_fast_forwards := 0
var _app_fast_forward_ticks := 0
var _app_fresh_key_requests := 0
var _app_pending_age_max := 0
var _app_state_oldest_received_tick := -1
var _app_state_newest_received_tick := -1
var _app_state_newest_applied_tick := -1
var _app_state_rejected := 0
var _app_rollback_ticks_sum := 0
var _app_rollback_ticks_max := 0
var _app_rollback_ticks_current := 0
var _app_last_report_msec := 0

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("NetworkPerformance")

## Check if performance monitoring is enabled.
## [br][br]
## By default, monitoring is only enabled in debug builds 
## ( see [method OS.is_debug_build] ). [br]
## Can be forced on with the [code]netfox_perf[/code] feature tag. [br]
## Can be forced off with the [code]netfox_noperf[/code] feature tag.
func is_enabled() -> bool:
	if OS.has_feature("netfox_noperf"):
		return false
	
	if OS.has_feature("netfox_perf"):
		return true

	# This returns true in the editor too
	return OS.is_debug_build()

## Get time spent in the last network tick loop, in millisec.
## [br]
## Note that this also includes time spent in the rollback tick loop.
func get_network_loop_duration_ms() -> float:
	return _network_loop_duration * 1000

## Get the number of ticks simulated in the last network tick loop.
func get_network_ticks() -> int:
	return _network_ticks

## Get time spent in the last rollback tick loop, in millisec.
func get_rollback_loop_duration_ms() -> float:
	return _rollback_loop_duration * 1000

## Get the number of ticks resimulated in the last rollback tick loop.
func get_rollback_ticks() -> int:
	return _rollback_ticks

## Get the average amount of time spent in a rollback tick during the last
## rollback loop, in millisec.
func get_rollback_tick_duration_ms() -> float:
	return _rollback_loop_duration * 1000 / maxi(_rollback_ticks, 1)

## Get the number of nodes simulated during the last rollback loop.
func get_rollback_nodes_simulated() -> int:
	return _rollback_nodes_simulated

## Get the number of nodes simulated per tick on average during the last
## rollback loop.
func get_rollback_nodes_simulated_per_tick() -> float:
	return _rollback_nodes_simulated / maxf(1., _rollback_ticks)

func push_rollback_nodes_simulated(count: int):
	_rollback_nodes_simulated_accum += count

## Get the number of properties in the full state recorded during the last tick
## loop.
func get_full_state_props_count() -> int:
	return _full_state_props

## Get the number of properties actually sent during the last tick loop.
func get_sent_state_props_count() -> int:
	return _sent_state_props

## Get the ratio of sent properties count to full state properties count.
##
## See [member get_full_state_props_count][br]
## See [member get_sent_state_props_count]
func get_sent_state_props_ratio() -> float:
	return _sent_state_props / maxf(1., _full_state_props)

func push_full_state(state: Dictionary) -> void:
	_full_state_props_accum += state.size()

func push_full_state_broadcast(state: Dictionary) -> void:
	_full_state_props_accum += state.size() * (multiplayer.get_peers().size() - 1)

func push_sent_state(state: Dictionary) -> void:
	_sent_state_props_accum += state.size()

func push_sent_state_broadcast(state: Dictionary) -> void:
	_sent_state_props_accum += state.size() * (multiplayer.get_peers().size() - 1)

## Enable the lightweight, once-per-second g2 application-wire report.
##
## Payload bytes are serialized argument sizes, not transport bytes: MultiplayerAPI's RPC/path/channel envelope
## is intentionally excluded. The number is still directly comparable between message categories and runs.
func set_app_telemetry_enabled(enabled: bool) -> void:
	_app_telemetry_enabled = enabled
	_reset_app_telemetry_window()
	_app_last_report_msec = Time.get_ticks_msec()
	if enabled and not NetworkTime.on_tick.is_connected(_on_app_telemetry_tick):
		NetworkTime.on_tick.connect(_on_app_telemetry_tick)
	if enabled and not NetworkRollback.before_loop.is_connected(_before_app_rollback_loop):
		NetworkRollback.before_loop.connect(_before_app_rollback_loop)
	if enabled and not NetworkRollback.on_process_tick.is_connected(_on_app_rollback_tick):
		NetworkRollback.on_process_tick.connect(_on_app_rollback_tick)
	if enabled and not NetworkRollback.after_loop.is_connected(_after_app_rollback_loop):
		NetworkRollback.after_loop.connect(_after_app_rollback_loop)

func is_app_telemetry_enabled() -> bool:
	return _app_telemetry_enabled

## Count one application RPC category. `copies` is the number of remote recipients for a broadcast.
func record_app_message(direction: String, category: String, payload: Variant, copies: int = 1) -> void:
	if not _app_telemetry_enabled or copies <= 0:
		return
	var key := "%s:%s" % [direction, category]
	_app_message_counts[key] = int(_app_message_counts.get(key, 0)) + copies
	_app_payload_bytes[key] = int(_app_payload_bytes.get(key, 0)) + var_to_bytes(payload).size() * copies

## Count actual state-envelope RPCs separately from the logical entries they carry.
func record_app_state_bundle(direction: String, payload: Variant, entry_count: int) -> void:
	if not _app_telemetry_enabled:
		return
	_app_bundle_counts[direction] = int(_app_bundle_counts.get(direction, 0)) + 1
	_app_bundle_entries[direction] = int(_app_bundle_entries.get(direction, 0)) + entry_count
	_app_bundle_bytes[direction] = int(_app_bundle_bytes.get(direction, 0)) + var_to_bytes(payload).size()

func note_app_bundle_skipped(count: int) -> void:
	if _app_telemetry_enabled:
		_app_bundles_skipped += maxi(0, count)

## Count a replaceable outbound envelope dropped because the recipient's transport send queue is over the
## backpressure threshold. Dropping there is the fix for unbounded SCTP queue growth; count it honestly.
func note_app_bundle_backpressure_dropped(count: int) -> void:
	if _app_telemetry_enabled:
		_app_bundles_backpressure_dropped += maxi(0, count)

## Count an input send skipped because the local transport send queue is over the backpressure threshold.
## Input packets carry a redundancy window, so a skip is covered by the next send that goes out.
func note_app_input_backpressure_dropped(count: int) -> void:
	if _app_telemetry_enabled:
		_app_inputs_backpressure_dropped += maxi(0, count)

func note_app_fast_forward(skipped_ticks: int) -> void:
	if _app_telemetry_enabled:
		_app_fast_forwards += 1
		_app_fast_forward_ticks += maxi(0, skipped_ticks)

func note_app_fresh_key_request() -> void:
	if _app_telemetry_enabled:
		_app_fresh_key_requests += 1

func note_app_pending_age(age_ticks: int) -> void:
	if _app_telemetry_enabled:
		_app_pending_age_max = maxi(_app_pending_age_max, age_ticks)

## Record a state tick as it enters the RPC handler, before decoding/applying it.
func note_app_state_received(tick: int) -> void:
	if not _app_telemetry_enabled:
		return
	if _app_state_oldest_received_tick < 0:
		_app_state_oldest_received_tick = tick
	else:
		_app_state_oldest_received_tick = mini(_app_state_oldest_received_tick, tick)
	_app_state_newest_received_tick = maxi(_app_state_newest_received_tick, tick)

func note_app_state_applied(tick: int) -> void:
	if _app_telemetry_enabled:
		_app_state_newest_applied_tick = maxi(_app_state_newest_applied_tick, tick)

func note_app_state_rejected() -> void:
	if _app_telemetry_enabled:
		_app_state_rejected += 1

func get_broadcast_recipient_count() -> int:
	return multiplayer.get_peers().size()

## Return the current raw application-telemetry window. Tick spans here describe everything observed during
## this reporting window; they are not queue depth. Queue/pending-age telemetry belongs to the later bounded
## bundle receiver, where an application queue actually exists and can be measured honestly.
func get_app_telemetry_snapshot(now_tick: int) -> Dictionary:
	if not _app_telemetry_enabled:
		return {}
	return {
		"message_counts": _app_message_counts.duplicate(),
		"payload_bytes": _app_payload_bytes.duplicate(),
		"bundle_counts": _app_bundle_counts.duplicate(),
		"bundle_entries": _app_bundle_entries.duplicate(),
		"bundle_bytes": _app_bundle_bytes.duplicate(),
		"bundles_skipped": _app_bundles_skipped,
		"bundles_backpressure_dropped": _app_bundles_backpressure_dropped,
		"inputs_backpressure_dropped": _app_inputs_backpressure_dropped,
		"fast_forwards": _app_fast_forwards,
		"fast_forward_ticks": _app_fast_forward_ticks,
		"fresh_key_requests": _app_fresh_key_requests,
		"pending_age_max": _app_pending_age_max,
		"state_oldest_received_tick": _app_state_oldest_received_tick,
		"state_newest_received_tick": _app_state_newest_received_tick,
		"state_newest_applied_tick": _app_state_newest_applied_tick,
		"state_oldest_age_ticks": -1 if _app_state_oldest_received_tick < 0 else maxi(0, now_tick - _app_state_oldest_received_tick),
		"state_newest_age_ticks": -1 if _app_state_newest_received_tick < 0 else maxi(0, now_tick - _app_state_newest_received_tick),
		"state_applied_age_ticks": -1 if _app_state_newest_applied_tick < 0 else maxi(0, now_tick - _app_state_newest_applied_tick),
		"state_rejected": _app_state_rejected,
		"rollback_ticks_sum": _app_rollback_ticks_sum,
		"rollback_ticks_max": _app_rollback_ticks_max,
	}

## Format the once-per-second line without mutating/resetting the current window. An empty string is the strict
## disabled contract, which lets the automated gate prove disabled telemetry cannot emit NETAPP output.
func build_app_telemetry_report(tick: int) -> String:
	if not _app_telemetry_enabled:
		return ""
	var snapshot := get_app_telemetry_snapshot(tick)
	return "NETAPP tick=%d rates=%s bundles=%s skipped=%d bp_dropped=%d input_bp_dropped=%d fast_forwards=%d/%dt key_requests=%d pending_age_max=%d state_rx_ticks=%s..%s state_age_ticks=%s/%s applied_tick=%s applied_age_ticks=%s rejected=%d rollback_ticks_sum=%d rollback_ticks_max=%d" % [
		tick, _format_app_rates(), _format_app_bundles(),
		int(snapshot["bundles_skipped"]), int(snapshot["bundles_backpressure_dropped"]),
		int(snapshot["inputs_backpressure_dropped"]),
		int(snapshot["fast_forwards"]),
		int(snapshot["fast_forward_ticks"]), int(snapshot["fresh_key_requests"]),
		int(snapshot["pending_age_max"]),
		_tick_or_na(int(snapshot["state_oldest_received_tick"])),
		_tick_or_na(int(snapshot["state_newest_received_tick"])),
		_age_or_na(int(snapshot["state_oldest_age_ticks"])),
		_age_or_na(int(snapshot["state_newest_age_ticks"])),
		_tick_or_na(int(snapshot["state_newest_applied_tick"])),
		_age_or_na(int(snapshot["state_applied_age_ticks"])), int(snapshot["state_rejected"]),
		int(snapshot["rollback_ticks_sum"]), int(snapshot["rollback_ticks_max"])]

func _on_app_telemetry_tick(_dt: float, tick: int) -> void:
	if not _app_telemetry_enabled:
		return
	var now := Time.get_ticks_msec()
	if now - _app_last_report_msec < 1000:
		return
	print(build_app_telemetry_report(tick))
	_reset_app_telemetry_window()
	_app_last_report_msec = now

func _before_app_rollback_loop() -> void:
	_app_rollback_ticks_current = 0

func _on_app_rollback_tick(_tick: int) -> void:
	_app_rollback_ticks_current += 1

func _after_app_rollback_loop() -> void:
	_app_rollback_ticks_sum += _app_rollback_ticks_current
	_app_rollback_ticks_max = maxi(_app_rollback_ticks_max, _app_rollback_ticks_current)

func _format_app_rates() -> String:
	var keys := _app_message_counts.keys()
	keys.sort()
	if keys.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for key in keys:
		parts.append("%s=%d/%dB" % [key, int(_app_message_counts[key]), int(_app_payload_bytes[key])])
	return ",".join(parts)

func _format_app_bundles() -> String:
	var directions := _app_bundle_counts.keys()
	directions.sort()
	if directions.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for direction in directions:
		parts.append("%s=%d/%de/%dB" % [direction, int(_app_bundle_counts[direction]),
			int(_app_bundle_entries[direction]), int(_app_bundle_bytes[direction])])
	return ",".join(parts)

func _tick_or_na(tick: int) -> String:
	return "n/a" if tick < 0 else str(tick)

func _age_or_na(age: int) -> String:
	return "n/a" if age < 0 else str(age)

func _reset_app_telemetry_window() -> void:
	_app_message_counts.clear()
	_app_payload_bytes.clear()
	_app_bundle_counts.clear()
	_app_bundle_entries.clear()
	_app_bundle_bytes.clear()
	_app_bundles_skipped = 0
	_app_bundles_backpressure_dropped = 0
	_app_inputs_backpressure_dropped = 0
	_app_fast_forwards = 0
	_app_fast_forward_ticks = 0
	_app_fresh_key_requests = 0
	_app_pending_age_max = 0
	_app_state_oldest_received_tick = -1
	_app_state_newest_received_tick = -1
	_app_state_newest_applied_tick = -1
	_app_state_rejected = 0
	_app_rollback_ticks_sum = 0
	_app_rollback_ticks_max = 0
	_app_rollback_ticks_current = 0

func _ready() -> void:
	if not is_enabled():
		_logger.debug("Network performance disabled")
		return

	_logger.debug("Network performance enabled, registering performance monitors")
	Performance.add_custom_monitor(NETWORK_LOOP_DURATION_MONITOR, get_network_loop_duration_ms)
	Performance.add_custom_monitor(ROLLBACK_LOOP_DURATION_MONITOR, get_rollback_loop_duration_ms)
	Performance.add_custom_monitor(NETWORK_TICKS_MONITOR, get_network_ticks)
	Performance.add_custom_monitor(ROLLBACK_TICKS_MONITOR, get_rollback_ticks)
	Performance.add_custom_monitor(ROLLBACK_TICK_DURATION_MONITOR, get_rollback_tick_duration_ms)
	Performance.add_custom_monitor(ROLLBACK_NODES_SIMULATED_MONITOR, get_rollback_nodes_simulated)
	Performance.add_custom_monitor(ROLLBACK_NODES_SIMULATED_PER_TICK_MONITOR, get_rollback_nodes_simulated_per_tick)
	
	Performance.add_custom_monitor(FULL_STATE_PROPERTIES_COUNT, get_full_state_props_count)
	Performance.add_custom_monitor(SENT_STATE_PROPERTIES_COUNT, get_sent_state_props_count)
	Performance.add_custom_monitor(SENT_STATE_PROPERTIES_RATIO, get_sent_state_props_ratio)
	
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.on_tick.connect(_on_network_tick)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	
	NetworkRollback.before_loop.connect(_before_rollback_loop)
	NetworkRollback.on_process_tick.connect(_on_rollback_tick)
	NetworkRollback.after_loop.connect(_after_rollback_loop)

func _before_tick_loop() -> void:
	_network_loop_start = _time()
	_network_ticks_accum = 0

func _on_network_tick(_dt, _t) -> void:
	_network_ticks_accum += 1

func _after_tick_loop() -> void:
	_network_loop_duration = _time() - _network_loop_start
	_network_ticks = _network_ticks_accum
	
	_full_state_props = _full_state_props_accum
	_full_state_props_accum = 0
	
	_sent_state_props = _sent_state_props_accum
	_sent_state_props_accum = 0

func _before_rollback_loop() -> void:
	_rollback_loop_start = _time()
	_rollback_ticks_accum = 0
	_rollback_nodes_simulated_accum = 0

func _on_rollback_tick(_t: int) -> void:
	_rollback_ticks_accum += 1

func _after_rollback_loop() -> void:
	_rollback_loop_duration = _time() - _rollback_loop_start
	_rollback_ticks = _rollback_ticks_accum
	_rollback_nodes_simulated = _rollback_nodes_simulated_accum

func _time() -> float:
	return Time.get_unix_time_from_system()
