extends Node
## Opt-in authoritative-state envelope bundler.
##
## RollbackSynchronizers keep their existing full/diff encoders, visibility decisions, state histories, and
## acknowledgement RPCs. This node replaces N per-body state RPC dispatches with one per-recipient RPC after
## every synchronizer has finished recording the server tick, and supplies coordinated recovery keys.

const FULL := 0
const DIFF := 1
const KEY_INTERVAL := 24

## Per-recipient transport send-queue bytes above which replaceable ordinary envelopes are dropped at
## dispatch. The 2026-07-19 combined-low run proved the SCTP send queue is otherwise unbounded (5.7MB,
## ~90s of staleness) — maxPacketLifetime only limits retransmission, never local queueing. Healthy
## two-client baselines sample 0–3KB, so this threshold only engages under real congestion.
const BACKPRESSURE_BYTES := 65536

var _enabled := false
var _state_rate_divisor := 1
## Netfox's enable_input_broadcast, project-wide (default true = netfox default = today's wire behavior).
## Every body's synchronizer setup copies this onto itself BEFORE process_settings() — sync_settings()
## latches the value into the history transmitter at initialization, so a later write silently never
## propagates. Coordinated per-run, not per-peer: the harness passes the same value to every peer.
var input_broadcast := true
## Packed input wire codec (net/input_codec.gd), default OFF = today's Variant wire exactly. The SEND side
## is gated on this flag; the RECEIVE side is type-driven (a packed payload is [PackedByteArray] with a
## magic byte) and accepts both formats regardless, so mixed peers interop — the flag is still passed to
## every peer for A/B hygiene and so _gather() quantizes at the source on the owner.
const INPUT_CODEC := preload("res://net/input_codec.gd")
var input_packing := false
## Packed STATE wire codec (net/state_codec.gd), default OFF = today's Variant wire exactly. Send-side
## gated on this flag; receive is type-driven (magic-tagged payloads) and accepts both formats, so mixed
## peers interop — the harness still passes the flag to every peer for A/B hygiene. WIRE-ONLY per plan
## correction C1: the server's sim and history never round; only the transmitted copy is quantized.
const STATE_CODEC := preload("res://net/state_codec.gd")
var state_packing := false
var _codec_report_tick := 0
var _routes: Dictionary = {}          # signed stable body id -> that body's rollback history transmitter
var _pending_by_tick: Dictionary = {} # tick -> peer -> packed route/kind/reference columns + payload Array
var _pending_key: Dictionary = {}
## Ordinary envelopes are sparse while the server replays late inputs. Keep the
## newest entry per body: replacing one whole envelope with another can starve
## a body that was present only in the older envelope.
var _pending_delta: Dictionary = {} # route -> single-entry bundle
var _newest_applied_source_tick := -1
var _newest_applied_by_route: Dictionary = {}
var _waiting_for_fresh_key := false
var _force_next_key := false
var _send_pressure_provider := Callable()
## Harness lever (--bundle-pressure-test). 0 = inert, and inert is the default everywhere, so no
## existing row's dispatch changes by a single byte. See set_pressure_test_bytes.
var _pressure_test_bytes := 0
## Fire the synthetic pressure 1 tick in this many. NOT tunable by flag on purpose: the value is a
## test contract, not a knob — see set_pressure_test_bytes for why a permanent stall mis-attributes.
const PRESSURE_TEST_PERIOD := 8
## ⚠ Pressure stays OFF until this tick, and that is what makes the lever prove anything. Peers START
## at base, so pressure from tick 0 simply pins them there — back-off becomes a no-op, no edge is
## logged, and the run cannot distinguish "bpdrop held it" from "the controller ignored it" (exactly
## the blind spot the impaired bdelay peer showed). Letting a peer settle at divisor 1 FIRST means the
## pressure produces a real observable transition: a 1→base edge stamped reason=bpdrop. ~30s at 60Hz,
## comfortably past grace (5 windows) plus two recoveries (measured: settled by tick ~1400).
const PRESSURE_TEST_WARMUP_TICKS := 1800
## Integrated-server routing. On the mux server this callable resolves a recipient to
## "enet" or "webrtc". Clients retain their own process-scoped product configuration and
## additionally receive this small map for the input-broadcast filter.
var _peer_transport_provider := Callable()
var _peer_transports: Dictionary = {}
var _input_filter_logged: Dictionary = {}
var _fresh_key_request_tick := -KEY_INTERVAL
var _stale_test_ticks := 0
var _stale_test_held: Dictionary = {}
var _stale_test_release_tick := -1
var _stale_test_done := false
var _delay_test_ticks := 0
var _delay_test_queue: Array = []
var _key_suppress_test := false

# --- ADAPTIVE STATE CADENCE (queue item 1) — receiver-feedback sampling, server side ---
#
# The signal is a peer's ACK LAG: how far behind us the newest tick is that the peer has
# acknowledged APPLYING. netfox's history transmitter already tracks exactly that, per peer, in its
# `_ackd_state` map — and the acks ride the unreliable_ordered channel, so they never head-of-line
# block. That transmitter's own comment (rollback-history-transmitter.gd, the no-usable-reference
# fallback) states the tell outright: "Acknowledgements stop exactly when a peer's link congests."
# So the receiver feedback is ALREADY on the wire. No new RPC, no new uplink bytes — which matters,
# because uplink input fatness is the one wire problem the WebRTC sprint left open.
#
# ⚠ NEVER promote `get_buffered_amount()` / _peer_send_pressure to the primary signal. It is BLIND
# to the SCTP in-flight queue — measured 0B while a client sat 4 SECONDS behind (2026-07-19). It
# stays what it is today: a crude reactive backstop.
#
# ⚠ Acks arrive only from FULL states: `diff_ack_interval` is 0, so the diff-ack branch never runs.
# Under bundling that means the ack cadence is anchored to the COORDINATED KEY interval — which is
# itself cadence-independent (keys always send, whatever the divisor). That anchor is what stops the
# controller running away: back off -> fewer ordinary envelopes -> but the ack rate does NOT fall
# with it, so ack lag cannot feed its own back-off.
#
# Sampled from NetworkTime.on_tick — the out-of-loop server seam world/health.gd, ring.gd and
# maze.gd all use, so tick stamps are honest (D-029) and nothing here can re-fire during resim.
# CONSTANTS BELOW ARE DERIVED FROM MEASUREMENT (scripts/cadence_probe.sh, 2026-07-24), not guessed.
# Healthy band, min-per-window statistic, 12 windows x 2 peers per leg:
#   loopback  div=1/2/3 -> min 0, med 0, p90 0-1      (the three bands OVERLAP: divisor-independent)
#   240ms bar div=3     -> min 14, med 14-15, p90 15  (= RTT in ticks; 240/16.67 = 14.4)
#   impaired (bundle-delay 90) -> NO ack reading in any of 12 windows, beside a clean peer at flat 0
# Read that middle row twice: a healthy 240ms peer sits at 14-15 where a healthy LAN peer sits at 0.
# A global constant tuned on the LAN band would call every far player congested and park exactly the
# population this feature exists for at the slow divisor forever. Hence floor-relative, per peer.
const CADENCE_WINDOW_TICKS := 60
## Ticks above a peer's OWN floor that count as distress. The measured healthy spread around the
## floor is <= 2 ticks at both 0ms and 240ms, and the moderate-distress ramp passed 25 by its second
## window — so 20 is ~10x the healthy noise and still catches the ramp early.
const CADENCE_MARGIN_TICKS := 20
## Trailing windows the per-peer floor is the MIN over. Rolling min is self-cleaning: distressed
## windows are high so they cannot pull the floor down, and a peer that arrives already congested
## sheds its inflated floor as soon as good windows appear.
const CADENCE_FLOOR_WINDOWS := 10
## Windows before a fresh peer is eligible for control at all. A joiner looks maximally distressed BY
## DESIGN — the join transient, the macOS shader-compile stall, catch-up fresh-key requests — so
## judging it would knock clean-link joiners to the slow divisor for their own arrival.
const CADENCE_GRACE_WINDOWS := 5
## Consecutive clean windows before stepping DOWN. Back off fast, recover slow.
const CADENCE_RECOVER_WINDOWS := 6
## ⚠ LEVEL hysteresis, and it is not optional — recovering requires a CLEARLY good window, not merely
## a not-bad one. The first cut tested the SAME threshold in both directions and sawed across it:
## flown on a real 300ms/1% link (John, 2026-07-24) it oscillated six times in 45s, and TWO of the
## three back-offs cleared the bar by exactly 2 ticks. He felt it as "slow down and go, slow down and
## go". Timing asymmetry alone (N clean windows) is NOT hysteresis; the levels must differ too.
const CADENCE_RECOVER_MARGIN_TICKS := 10
## A back-off landing within this many windows of a recovery means the step down was unsustainable.
const CADENCE_RELAPSE_WINDOWS := 12
## Each relapse DOUBLES the hold at base (3 << n windows), so a link that cannot carry the faster
## cadence stops being re-probed every few seconds. Capped so recovery is never abandoned forever.
const CADENCE_RELAPSE_CAP := 4
## Windows of stability after which a peer's relapse penalty is forgiven — a link that has been fine
## for a minute deserves a fresh probe at full speed.
const CADENCE_RELAPSE_FORGET_WINDOWS := 60
## Windows held at base after a back-off before recovery can start counting, so a flapping link
## cannot oscillate.
const CADENCE_COOLDOWN_WINDOWS := 3
## Floor entries required before the ack-lag comparison may fire. Without it the first readable
## window is its own floor and nothing can ever exceed it.
const CADENCE_MIN_FLOOR_SAMPLES := 2
## Windows between per-peer report lines while adapting. The edge log alone cannot answer "what is
## this peer being served RIGHT NOW" (a peer held at base by distress emits no edge, correctly), and
## the flap count is what lets the LAN A/B assert "it rarely changed" as a NUMBER rather than a vibe.
const CADENCE_REPORT_WINDOWS := 5
## Per-peer smallest ack lag seen in the current window. MIN, not max or mean: the ack cadence makes
## lag sawtooth 0..KEY_INTERVAL, so the max just measures ack pacing. The min is "how fresh did the
## newest ack actually get" — the true behind-ness, and the only statistic that stays comparable
## across divisors.
var _cad_lag_min: Dictionary = {}
## Per-peer count of ticks this window with NO ack reading at all. See the sampler for why this is a
## first-class signal and not an absence of one: sustained distress ERASES the ack state.
var _cad_noack: Dictionary = {}
var _cad_window_start := 0
var _cad_window_idx := 0
## Adaptation on/off. OFF is the default everywhere, which is what keeps every existing gate,
## harness row and control leg on exactly today's behavior — see set_adaptive_state_rate for why
## that, and not an explicit-divisor "pin", is the mechanism.
var _cad_adaptive := false
## peer -> currently served divisor. Absent = the base. Bounds are ALWAYS [1, base]: adaptation can
## only make a peer better than the pinned behavior, never worse. That is the load-bearing safety
## property of this feature — adapting ABOVE base under pressure is a separate design conversation,
## not a tuning change. Corollary: with base == 1 (ENet/native) the whole controller is inert.
var _peer_divisor: Dictionary = {}
var _cad_floor_hist: Dictionary = {}   # peer -> Array[int], trailing readable window stats
var _cad_clean_run: Dictionary = {}    # peer -> consecutive clean windows
var _cad_cooldown: Dictionary = {}     # peer -> windows left holding at base after a back-off
var _cad_join_window: Dictionary = {}  # peer -> window index it was first seen
var _cad_flaps: Dictionary = {}        # peer -> divisor changes this session (telemetry)
var _cad_key_requests: Dictionary = {} # peer -> fresh-key requests THIS window
var _cad_bp_drops: Dictionary = {}     # peer -> backpressure drops THIS window
var _cad_recovered_window: Dictionary = {} # peer -> window index of its last step DOWN
var _cad_relapses: Dictionary = {}     # peer -> consecutive unsustainable recoveries (cooldown shift)
## G2_CADENCE_DBG=1 — per-window per-peer band report. Env-gated like G2_PRES_DBG so it never
## reaches a normal log and no gate contract can see it.
var _cad_debug := false

func _ready() -> void:
	# Recorders populate per-tick columns during rollback, including historical
	# replay ticks. Publish only after the loop has reached its final settled tick;
	# emitting from after_record_tick turns resimulation work into stale wire load.
	NetworkRollback.after_loop.connect(_flush_settled_tick)
	NetworkTime.before_tick_loop.connect(_drain_incoming)
	# ⚠ CONNECTED UNCONDITIONALLY; the role is decided INSIDE _cadence_tick. Gating on is_server()
	# here is the documented trap — with no peer assigned yet Godot's is_server() answers TRUE
	# (dots.gd / health.gd / ring.gd all name it).
	NetworkTime.on_tick.connect(_cadence_tick)
	NetworkEvents.on_peer_leave.connect(_cadence_forget_peer)
	_cad_debug = OS.get_environment("G2_CADENCE_DBG") == "1"

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_pending_by_tick.clear()
	_pending_key.clear()
	_pending_delta.clear()
	_newest_applied_source_tick = -1
	_newest_applied_by_route.clear()
	_waiting_for_fresh_key = false
	_force_next_key = false
	_fresh_key_request_tick = -KEY_INTERVAL
	_stale_test_held.clear()
	_stale_test_release_tick = -1
	_stale_test_done = false
	_delay_test_queue.clear()
	if _enabled:
		print("[state-bundle] enabled=1")

func set_input_broadcast(enabled: bool) -> void:
	input_broadcast = enabled
	echo_input_broadcast()

## Prints UNCONDITIONALLY on every peer, both values: the TURN harness asserts this echo in the server,
## browser, and native-bot logs before a run counts, and a missing echo doubles as the stale-build
## detector (a stale browser PCK silently ignores new query params — this line is how that surfaces).
## Separate from the setter so a client can RE-print after connect: the browser console capture attaches
## while the WASM is still booting, so the _ready echo can race the collector.
func echo_input_broadcast() -> void:
	print("[input-broadcast] enabled=%d" % (1 if input_broadcast else 0))


func set_peer_transport_provider(provider: Callable) -> void:
	_peer_transport_provider = provider


func set_peer_transport_map(transports: Dictionary) -> void:
	_peer_transports = transports.duplicate()


func forget_peer_transport(peer: int) -> void:
	_peer_transports.erase(peer)
	_input_filter_logged.erase(peer)


func _transport_for_peer(peer: int) -> String:
	if _peer_transport_provider.is_valid():
		return str(_peer_transport_provider.call(peer))
	return str(_peer_transports.get(peer, ""))


## Option B: an input-owning ENet client keeps broadcasting to ENet recipients but skips
## WebRTC recipients. WebRTC clients already default input_broadcast OFF. Unknown peers
## retain legacy behavior until the authoritative map arrives.
func should_broadcast_input_to(peer: int) -> bool:
	var allowed := _transport_for_peer(peer) != "webrtc"
	if not allowed and not _input_filter_logged.has(peer):
		_input_filter_logged[peer] = true
		print("[input-broadcast] filtered peer=%d transport=webrtc" % peer)
	return allowed


func needs_input_target_expansion() -> bool:
	if _peer_transport_provider.is_valid():
		# Provider existence means this is the mux server. Concrete targets are needed
		# even before the first WebRTC join so its behavior never changes mid-body.
		return true
	for transport_variant in _peer_transports.values():
		if str(transport_variant) == "webrtc":
			return true
	return false


func _peer_uses_product_wire(peer: int) -> bool:
	# Only the mux server has a provider. Ordinary clients and one-transport servers keep
	# their existing process-scoped flags exactly.
	return _transport_for_peer(peer) == "webrtc" if _peer_transport_provider.is_valid() else true


func peer_uses_packed_input(peer: int) -> bool:
	return input_packing and _peer_uses_product_wire(peer)


func peer_uses_packed_state(peer: int) -> bool:
	return state_packing and _peer_uses_product_wire(peer)


func peer_uses_bundles(peer: int) -> bool:
	return _enabled and _peer_uses_product_wire(peer)

func set_input_packing(enabled: bool) -> void:
	input_packing = enabled
	echo_input_packing()

## Same unconditional-echo contract as [input-broadcast]: asserted by the TURN harness in all three logs,
## doubles as the stale-build detector, and is ALLOWLISTED in webrtc_stats.mjs (a tag missing from that
## regex silently never reaches browser.log — the Phase 0 lesson).
func echo_input_packing() -> void:
	print("[packed-input] enabled=%d" % (1 if input_packing else 0))

func set_state_packing(enabled: bool) -> void:
	state_packing = enabled
	echo_state_packing()

## Same unconditional-echo + allowlist contract as [packed-input] above.
func echo_state_packing() -> void:
	print("[packed-state] enabled=%d" % (1 if state_packing else 0))

## Send seams for the rollback history transmitter: passthrough when packing is off.
func pack_state_full(data: Array, peer: int = 0) -> Array:
	if not peer_uses_packed_state(peer):
		return data
	return STATE_CODEC.pack_full(data)

## `ref_block`: the packed reference-tick physics block for the diff deadband (empty disables it).
func pack_state_diff(data: PackedByteArray, ref_block: PackedByteArray,
		peer: int = 0) -> PackedByteArray:
	if not peer_uses_packed_state(peer):
		return data
	return STATE_CODEC.pack_diff(data, ref_block)

func pack_physics_block(state: Variant) -> PackedByteArray:
	return STATE_CODEC.pack_physics(state)

## Receive seams: type-driven, flag-independent. unpack_state_full returns [] and unpack_state_diff
## returns null on a malformed packed payload — loud, the caller then applies nothing for that message.
func unpack_state_full(data: Array) -> Array:
	var out: Array = STATE_CODEC.unpack_full(data)
	if out.is_empty() and not data.is_empty():
		print("[packed-state] reject: malformed full payload")
	return out

func unpack_state_diff(data: PackedByteArray) -> Variant:
	var out: Variant = STATE_CODEC.unpack_diff(data)
	if out == null:
		print("[packed-state] reject: malformed diff payload")
	return out

## Periodic codec diagnostics (~every 5s at 60Hz), only while packing and only when something moved.
## Deadband/clamps/fallbacks count on the sender, rejects on the receiver; the [packed-state] tag is
## allowlisted in webrtc_stats.mjs so the browser's counts reach browser.log.
func _report_codec_counters() -> void:
	if not state_packing or NetworkTime.tick - _codec_report_tick < 300:
		return
	_codec_report_tick = NetworkTime.tick
	if STATE_CODEC.deadband_dropped + STATE_CODEC.clamped + STATE_CODEC.pack_fallbacks \
			+ STATE_CODEC.rejects > 0:
		print("[packed-state] deadband_dropped=%d clamped=%d fallbacks=%d rejects=%d" % [
			STATE_CODEC.deadband_dropped, STATE_CODEC.clamped, STATE_CODEC.pack_fallbacks,
			STATE_CODEC.rejects])

## Send seam for the rollback history transmitter: passthrough when packing is off or the property
## surface isn't the PlayerBody input schema.
func pack_input(data: Array, props: Array, peer: int = 0) -> Array:
	if not peer_uses_packed_input(peer):
		return data
	return INPUT_CODEC.pack(data, props)

## Receive seam: type-driven, flag-independent. Returns [] on a malformed/mismatched packed payload —
## loud, and the transmitter then applies nothing for that message.
func unpack_input(data: Array) -> Array:
	if not INPUT_CODEC.is_packed(data):
		return data
	var out: Array = INPUT_CODEC.unpack(data)
	if out.is_empty():
		print("[packed-input] reject: malformed or version-mismatched payload")
	return out

## Server-side: a callable taking a peer id and returning that peer's current transport send-queue bytes.
## Wired only for transports that expose one (WebRTC); absent, backpressure never engages and dispatch is
## byte-identical to the pre-backpressure behavior.
func set_send_pressure_provider(provider: Callable) -> void:
	_send_pressure_provider = provider

## HARNESS ONLY — synthetic send-queue pressure, the fourth of the --bundle-*-test levers and the
## exact counterpart of --bundle-delay-test (bdelay). bdelay injects a client-side APPLY delay to
## drive the ack path; this injects server-side QUEUE PRESSURE to drive the backpressure path.
##
## WHY IT EXISTS: `bpdrop` is the ONLY back-off reason with zero coverage anywhere. ENet wires no
## send-pressure provider at all (Main.gd:3032-3034 says so outright), so every ENet row scores it a
## structural 0 — and the webrtc rows that could exercise it need a genuinely congested link, which
## needs the LAN-bound TURN harness. A lever removes the network from the question entirely, the same
## way bdelay did for leg C, and makes the path testable in a gate instead of in a weather report.
##
## ⚠ DUTY-CYCLED, AND THAT IS LOAD-BEARING. Pinning pressure permanently above BACKPRESSURE_BYTES
## drops EVERY ordinary envelope, which starves the peer into the fresh-key loop — and _evaluate_peer
## tests `freshkey` BEFORE `bpdrop` in its elif chain, so a starved peer attributes as freshkey and
## the lever would prove nothing about the signal it was built for. Firing 1 tick in
## PRESSURE_TEST_PERIOD leaves the peer healthy (~88% of ordinary envelopes still flow) while still
## putting bp_drops > 0 in every window, which is all the controller's threshold asks for.
func set_pressure_test_bytes(bytes: int) -> void:
	_pressure_test_bytes = maxi(0, bytes)
	if _pressure_test_bytes > 0:
		print("[state-bundle] pressure_test=%d duty=1/%d threshold=%d warmup=%d" % [
			_pressure_test_bytes, PRESSURE_TEST_PERIOD, BACKPRESSURE_BYTES,
			PRESSURE_TEST_WARMUP_TICKS])

## Send ordinary envelopes to each peer only every Nth tick (keys and recovery unchanged, simulation stays
## 60Hz). PROACTIVE load reduction: usrsctp accepts sends into an internal queue BELOW the channel-level
## buffered-bytes API, so on a collapsed congestion window the server piles up seconds of state that no
## reactive backpressure can see (2026-07-19: HUD ~4000ms while the server's channel API read 0B).
func set_state_rate_divisor(divisor: int) -> void:
	_state_rate_divisor = maxi(1, divisor)
	if _state_rate_divisor > 1:
		print("[state-bundle] state_rate_divisor=%d" % _state_rate_divisor)

## ⚠ PINNING IS THE DEFAULT, NOT A SEPARATE LEVER. The design review specified "an explicit
## --state-rate-divisor is the pin, and a pin disables adaptation". That reading had to be dropped:
## the divisor is the only way to set a base, and on the ENet path the base is 1 — so under those
## semantics adaptation was inert unless you set a base, and setting a base turned it off. The
## feature would have been structurally untestable in the gate suite, which is where all seven legs
## live. `--state-rate-divisor N` is therefore the BASE (the ceiling), and today's behavior is
## preserved by adaptation being OFF by default: no existing row passes --adaptive-state-rate, so no
## existing row can adapt. Anyone wanting a forced fixed cadence gets it by NOT enabling adaptation.
## Echoes unconditionally on every peer like the other bundle levers, so a stale build is detectable;
## the controller itself is server-only.
func set_adaptive_state_rate(enabled: bool) -> void:
	_cad_adaptive = enabled
	echo_adaptive_state_rate()

func echo_adaptive_state_rate() -> void:
	print("[state-cadence] adaptive=%d base=%d" % [
		1 if _cad_adaptive else 0, _state_rate_divisor])

## The divisor to serve THIS peer at. With adaptation off this is byte-for-byte the old global
## expression, which is why every pre-existing row is unaffected.
func _divisor_for(peer: int) -> int:
	var base := _base_divisor_for(peer)
	if not _is_adapting_peer(peer):
		return base
	return int(_peer_divisor.get(peer, base))


func _base_divisor_for(peer: int) -> int:
	return _state_rate_divisor if _peer_uses_product_wire(peer) else 1


func _is_adapting_peer(peer: int) -> bool:
	# base == 1 means there is nothing to back off TO, so ENet is structurally inert.
	return _cad_adaptive and _base_divisor_for(peer) > 1

## Public: the divisor this peer is currently served at (telemetry/gates).
func peer_divisor(peer: int) -> int:
	return _divisor_for(peer)

## Public: divisor changes this peer has seen — the "did it flap?" number, so a noisy trigger can be
## demoted later with data instead of vibes.
func peer_cadence_flaps(peer: int) -> int:
	return int(_cad_flaps.get(peer, 0))

## Newest tick this peer has acknowledged applying, across every body. -1 until its first ack.
## Reads the transmitters this node already holds in _routes, so there is no netfox edit and no new
## wire: `_ackd_state` is written by the transmitter's own _ack_full_state RPC handler.
func _peer_ackd_tick(peer: int) -> int:
	var newest := -1
	for transmitter in _routes.values():
		if transmitter == null or not is_instance_valid(transmitter):
			continue
		newest = maxi(newest, int(transmitter._ackd_state.get(peer, -1)))
	return newest

## Ticks behind us this peer's newest ack is, or -1 while it has never acked (a fresh joiner, or a
## peer whose bodies have not sent a full state yet). Callers must treat -1 as "no reading", NEVER
## as zero — a joiner reading 0 would look perfectly healthy at exactly the moment it is not.
func peer_ack_lag(peer: int) -> int:
	var ackd := _peer_ackd_tick(peer)
	if ackd < 0:
		return -1
	return maxi(0, NetworkTime.tick - ackd)

## Per-tick sampler + per-window report. Server only, out of the rollback loop.
func _cadence_tick(_delta: float, tick: int) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if not _enabled:
		return
	for peer in multiplayer.get_peers():
		var lag := peer_ack_lag(peer)
		if lag < 0:
			# ⚠ NOT "no data — skip". MEASURED 2026-07-24: a peer in sustained distress enters the
			# fresh-key loop, and every _request_fresh_key makes the server call
			# reset_peer_state_reference() on every transmitter, which ERASES _ackd_state[peer]. So
			# the most distressed peers report NO ack lag at all, not a large one. A sampler that
			# skips this case is blind to exactly the peers that need backing off — the impaired bot
			# in the step-3 distress run read 8 -> 25 -> 85 and then went silent for 600 ticks while
			# still connected and still 96 ticks behind (its own applied_age_ticks said so).
			# Count it; the controller treats a no-ack window outside join grace as distress.
			_cad_noack[peer] = int(_cad_noack.get(peer, 0)) + 1
			continue
		var seen: int = _cad_lag_min.get(peer, -1)
		_cad_lag_min[peer] = lag if seen < 0 else mini(seen, lag)
	if tick - _cad_window_start < CADENCE_WINDOW_TICKS:
		return
	_cad_window_start = tick
	_cad_window_idx += 1
	if _cad_debug:
		for peer in multiplayer.get_peers():
			print("[state-cadence-probe] tick=%d peer=%d lagmin=%d noack=%d div=%d" % [
				tick, int(peer), int(_cad_lag_min.get(peer, -1)),
				int(_cad_noack.get(peer, 0)), _divisor_for(int(peer))])
	for peer in multiplayer.get_peers():
		var pid := int(peer)
		if _is_adapting_peer(pid):
			_evaluate_peer(pid, tick)
			if _cad_window_idx % CADENCE_REPORT_WINDOWS == 0:
				# bp= carries the window's backpressure drops even when NOTHING tripped — the edge log
				# cannot show a signal that stayed under the bar, and "bpdrop fires constantly but
				# never quite trips" is a distinct (and likelier) failure shape from "bpdrop flaps".
				print("[state-cadence] report tick=%d peer=%d div=%d floor=%d bp=%d fk=%d flaps=%d" % [
					tick, pid, _divisor_for(pid), _peer_floor(pid),
					int(_cad_bp_drops.get(pid, 0)), int(_cad_key_requests.get(pid, 0)),
					peer_cadence_flaps(pid)])
	_cad_lag_min.clear()
	_cad_noack.clear()
	_cad_key_requests.clear()
	_cad_bp_drops.clear()

## One window's verdict for one peer. Back off FAST (any signal -> straight to base, because the
## cost of being late is a resim storm), recover SLOW (N clean windows -> step to 1). The step down
## IS the probe: if the faster cadence is not sustainable, the next window bounces it back.
func _evaluate_peer(peer: int, tick: int) -> void:
	var base := _base_divisor_for(peer)
	if not _cad_join_window.has(peer):
		# First sighting. Peers start AT BASE, so a joiner is never served a cadence it has not
		# earned, and its own arrival storm cannot be read as a verdict.
		_cad_join_window[peer] = _cad_window_idx
		_peer_divisor[peer] = base
		return
	var stat := int(_cad_lag_min.get(peer, -1))
	var in_grace: bool = _cad_window_idx - int(_cad_join_window[peer]) < CADENCE_GRACE_WINDOWS
	if stat >= 0:
		_note_floor(peer, stat)
	if in_grace:
		return
	var reason := ""
	if stat < 0:
		# ⚠ NOT an absence of data — under sustained distress this IS the reading. Every fresh-key
		# request makes the server reset_peer_state_reference() on every transmitter, erasing
		# _ackd_state[peer], so the worst-off peers report no ack lag rather than a large one.
		# Measured: the impaired bot read no ack in 12/12 windows while 96 ticks behind. A healthy
		# 240ms peer still got a reading EVERY window (it had occasional no-ack ticks, never a
		# no-ack window) — which is why this keys on the whole window, not on any single tick.
		reason = "noack"
	elif int(_cad_key_requests.get(peer, 0)) > 0:
		reason = "freshkey"
	elif int(_cad_bp_drops.get(peer, 0)) > 0:
		reason = "bpdrop"
	elif _floor_ready(peer) and stat > _peer_floor(peer) + CADENCE_MARGIN_TICKS:
		reason = "acklag"
	if reason != "":
		_cad_clean_run[peer] = 0
		# RELAPSE ESCALATION. A back-off landing right after a recovery means the step down was
		# unsustainable, so re-probing at the same interval just reproduces the sawtooth. Each
		# relapse doubles the hold; a long stable stretch forgives it so a link that genuinely
		# improves is not punished forever.
		var since_recovery: int = _cad_window_idx - int(_cad_recovered_window.get(peer, -9999))
		if since_recovery <= CADENCE_RELAPSE_WINDOWS:
			_cad_relapses[peer] = mini(int(_cad_relapses.get(peer, 0)) + 1, CADENCE_RELAPSE_CAP)
		elif since_recovery > CADENCE_RELAPSE_FORGET_WINDOWS:
			_cad_relapses[peer] = 0
		_cad_cooldown[peer] = CADENCE_COOLDOWN_WINDOWS << int(_cad_relapses.get(peer, 0))
		_set_peer_divisor(peer, base, reason, stat, tick)
		return
	if int(_cad_cooldown.get(peer, 0)) > 0:
		_cad_cooldown[peer] = int(_cad_cooldown[peer]) - 1
		return
	# ⚠ LEVEL hysteresis. Recovering demands a CLEARLY good window (floor + RECOVER margin), not
	# merely one that failed to trip the back-off bar (floor + MARGIN). Testing one threshold in both
	# directions is what made this saw across the boundary on a real 300ms/1% link.
	if not _floor_ready(peer) or stat > _peer_floor(peer) + CADENCE_RECOVER_MARGIN_TICKS:
		_cad_clean_run[peer] = 0
		return
	var run := int(_cad_clean_run.get(peer, 0)) + 1
	_cad_clean_run[peer] = run
	if run >= CADENCE_RECOVER_WINDOWS:
		_cad_clean_run[peer] = 0
		_cad_recovered_window[peer] = _cad_window_idx
		# STEP DOWN ONE RUNG, never jump straight to 1. Going base->1 tripled the offered state load
		# in a single move, which is what pushed ack lag back over the bar and produced the cycle.
		# Rung 2 therefore exists as a DESTINATION, not just as transit — a link that can carry 30Hz
		# but not 60Hz now settles there instead of oscillating between the extremes.
		_set_peer_divisor(peer, _divisor_for(peer) - 1, "clean", stat, tick)

func _set_peer_divisor(peer: int, divisor: int, reason: String, stat: int, tick: int) -> void:
	var base := _base_divisor_for(peer)
	var want := clampi(divisor, 1, base)
	var have := int(_peer_divisor.get(peer, base))
	if want == have:
		return
	_peer_divisor[peer] = want
	_cad_flaps[peer] = int(_cad_flaps.get(peer, 0)) + 1
	# EDGE-logged, never per tick. Every change carries WHICH signal fired, so the LAN A/B can
	# attribute a flap instead of guessing at it.
	# ⚠ lag=/floor= alone are ACKLAG-CENTRIC — they say nothing about the other three reasons, so a
	# reason=bpdrop or reason=freshkey edge used to be categorical only ("something tripped") with no
	# magnitude. That gap matters most on the WEBRTC path, where bpdrop is the one back-off signal
	# that has never fired in any calibrated row (ENet wires no send-pressure provider at all, so
	# every ENet row scored it structurally 0). bp=/fk=/noack= are this window's raw counts, read
	# BEFORE _cadence_tick clears them.
	print("[state-cadence] tick=%d peer=%d div=%d→%d reason=%s lag=%d floor=%d bp=%d fk=%d noack=%d flaps=%d" % [
		tick, peer, have, want, reason, stat, _peer_floor(peer),
		int(_cad_bp_drops.get(peer, 0)), int(_cad_key_requests.get(peer, 0)),
		int(_cad_noack.get(peer, 0)), int(_cad_flaps[peer])])

func _note_floor(peer: int, stat: int) -> void:
	var hist: Array = _cad_floor_hist.get(peer, [])
	hist.append(stat)
	while hist.size() > CADENCE_FLOOR_WINDOWS:
		hist.pop_front()
	_cad_floor_hist[peer] = hist

func _floor_ready(peer: int) -> bool:
	return (_cad_floor_hist.get(peer, []) as Array).size() >= CADENCE_MIN_FLOOR_SAMPLES

## This peer's own healthy baseline: the min over its trailing readable windows. It absorbs RTT,
## which is the whole point — a stable 240ms peer floors at ~14 ticks and must not be called
## congested for it.
func _peer_floor(peer: int) -> int:
	var hist: Array = _cad_floor_hist.get(peer, [])
	if hist.is_empty():
		return 0
	var lowest: int = int(hist[0])
	for value in hist:
		lowest = mini(lowest, int(value))
	return lowest

func _cadence_forget_peer(id: int) -> void:
	for book in [_peer_divisor, _cad_floor_hist, _cad_clean_run, _cad_cooldown,
			_cad_join_window, _cad_flaps, _cad_key_requests, _cad_bp_drops,
			_cad_lag_min, _cad_noack, _cad_recovered_window, _cad_relapses]:
		(book as Dictionary).erase(id)

## HARNESS ONLY: hold one settled complete key and suppress later envelopes long enough to force the bounded
## recovery path. Production callers leave this at zero.
func set_stale_test_ticks(ticks: int) -> void:
	_stale_test_ticks = maxi(0, ticks)

## HARNESS ONLY: delay every received envelope by N local ticks before it reaches the coalescer. With N above
## NetworkRollback.history_limit this reproduces the 2026-07-19 congestion signature — every bundle is already
## stale on arrival, forever — which a one-shot held key cannot model. Do not combine with the stale test.
func set_delay_test_ticks(ticks: int) -> void:
	_delay_test_ticks = maxi(0, ticks)
	if _delay_test_ticks > 0:
		print("[state-bundle-test] delay=%d" % _delay_test_ticks)

## HARNESS ONLY: discard every incoming coordinated KEY envelope — the reliable key channel modelled as fully
## head-of-line blocked. Recovery must then survive on promoted complete ordinary envelopes alone.
func set_key_suppress_test(enabled: bool) -> void:
	_key_suppress_test = enabled
	if _key_suppress_test:
		print("[state-bundle-test] key_suppress=1")

func is_enabled() -> bool:
	return _enabled

func is_key_tick(tick: int) -> bool:
	return _enabled and (_force_next_key or tick % KEY_INTERVAL == 0)

## Register by a compact signed body id. MultiplayerSpawner gives every body a numeric name on every peer;
## players are positive and props are negated, so the namespaces cannot collide. There is exactly one
## RollbackSynchronizer per body in g2.
func register_synchronizer(sync_root: Node, transmitter: Node) -> void:
	if sync_root == null or not sync_root.is_inside_tree():
		return
	var route := _route_for(sync_root)
	if route != 0:
		_routes[route] = transmitter

func unregister_synchronizer(_sync_root: Node, transmitter: Node) -> void:
	# PREDELETE can run after the body has left the tree, when get_path() is no longer the registered path.
	# Remove by transmitter identity so stale routes never retain a freed body.
	for path in _routes.keys():
		if _routes[path] == transmitter:
			_routes.erase(path)
			_pending_delta.erase(path)
			_newest_applied_by_route.erase(path)

## Returns true when this state update was accepted into the bundle path. The caller uses false to retain the
## original direct-RPC behavior, making the feature an exact runtime A/B rather than a code-edit comparison.
func queue_state(peer: int, tick: int, sync_root: Node, kind: int, data: Variant,
		reference_tick: int = -1) -> bool:
	if not peer_uses_bundles(peer) or peer <= 0 or sync_root == null:
		return false
	if not _pending_by_tick.has(tick):
		_pending_by_tick[tick] = {}
	var by_peer: Dictionary = _pending_by_tick[tick]
	if not by_peer.has(peer):
		by_peer[peer] = [PackedInt64Array(), PackedByteArray(), PackedInt32Array(), []]
	var columns: Array = by_peer[peer]
	var route := _route_for(sync_root)
	if route == 0:
		return false
	# Packed arrays use copy-on-write when pulled out of a Variant Array. Assign each mutated column back; mutating
	# only the cast temporary leaves an empty route/kind/reference column and makes the receiver reject the bundle.
	var routes: PackedInt64Array = columns[0]
	var kinds: PackedByteArray = columns[1]
	var references: PackedInt32Array = columns[2]
	routes.append(route)
	kinds.append(kind)
	references.append(reference_tick)
	columns[0] = routes
	columns[1] = kinds
	columns[2] = references
	(columns[3] as Array).append(data)
	return true

## Publish only the final state produced by this rollback loop. All earlier
## `_pending_by_tick` entries are replay intermediates and must never hit the
## network. One peer can see a different entry set from another because existing
## visibility is preserved.
func _flush_settled_tick() -> void:
	if not _enabled or _pending_by_tick.is_empty():
		return
	var settled_tick := NetworkTime.tick
	if _pending_by_tick.has(settled_tick):
		_flush_tick(settled_tick)
	_pending_by_tick.clear()

func _flush_tick(tick: int) -> void:
	if not _enabled or not _pending_by_tick.has(tick):
		return
	var by_peer: Dictionary = _pending_by_tick[tick]
	var is_key := is_key_tick(tick)
	for peer_variant in by_peer:
		var peer := int(peer_variant)
		var columns: Array = by_peer[peer_variant]
		var routes: PackedInt64Array = columns[0]
		var kinds: PackedByteArray = columns[1]
		var references: PackedInt32Array = columns[2]
		var payloads: Array = columns[3]
		var divisor := _divisor_for(peer)
		if not is_key and divisor > 1 and (tick + peer) % divisor != 0:
			# Rate-capped ordinary envelope; the next one covers it. Staggered by peer id so recipients
			# don't burst on the same tick.
			continue
		if not is_key and _peer_send_pressure(peer) > BACKPRESSURE_BYTES:
			_cad_bp_drops[peer] = int(_cad_bp_drops.get(peer, 0)) + 1
			# An ordinary envelope is replaceable — the next tick's envelope or coordinated key repairs this
			# peer. Dropping at dispatch keeps the transport send queue bounded; blindly queueing is what let
			# the 2026-07-19 run stack ~90 seconds of staleness invisible to ICE RTT. Keys always send.
			NetworkPerformance.note_app_bundle_backpressure_dropped(1)
			continue
		if is_key:
			_submit_key_bundle.rpc_id(peer, tick, routes, kinds, references, payloads)
			# Mirror every key onto the unreliable-ordered channel as an ordinary envelope. Key ticks are
			# complete by construction (the transmitter's is_coordinated_key escape includes idle bodies),
			# so the mirror is exactly the promotable complete envelope the receiver's HOL escape needs —
			# ordinary envelopes alone are chronically ~9/11 routes (idle bodies skip) and never promote.
			# Reliable copy = the guarantee; mirror = the latency path. The receiver dedupes by source tick.
			_submit_state_bundle.rpc_id(peer, tick, routes, kinds, references, payloads)
			NetworkPerformance.record_app_state_bundle("out", [tick, false, routes, kinds, references, payloads],
				payloads.size())
		else:
			_submit_state_bundle.rpc_id(peer, tick, routes, kinds, references, payloads)
		NetworkPerformance.record_app_state_bundle("out", [tick, is_key, routes, kinds, references, payloads],
			payloads.size())
	_pending_by_tick.erase(tick)
	if _force_next_key:
		_force_next_key = false

# --- resim-asymmetry probe (2026-07-21) --- per-arrival depth + clock-lead accumulators, read and
# cleared once per client-health window via probe_take(). Sampled at RPC dispatch time, which is
# OUTSIDE the rollback loop (D-029: never tick-stamp from inside resim). Bundle path only — every
# probe row runs `--state-bundles 1` (the product config), so this sees every state arrival there.
# Gated on set_probe_enabled (client-health telemetry): a client with telemetry off must not grow
# the depth array forever.
var _probe_enabled := false
var _probe_arrivals := 0
var _probe_depths: Array[int] = []
var _probe_lead_sum := 0
var _probe_lead_max := 0

func set_probe_enabled(enabled: bool) -> void:
	_probe_enabled = enabled

func probe_take() -> Dictionary:
	var out := {
		"arrivals": _probe_arrivals,
		"depths": _probe_depths,
		"lead_sum": _probe_lead_sum,
		"lead_max": _probe_lead_max,
	}
	_probe_arrivals = 0
	_probe_depths = []
	_probe_lead_sum = 0
	_probe_lead_max = 0
	return out

@rpc("authority", "unreliable_ordered", "call_remote")
func _submit_state_bundle(tick: int, routes: PackedInt64Array, kinds: PackedByteArray,
		references: PackedInt32Array, payloads: Array) -> void:
	_receive_state_bundle(tick, false, routes, kinds, references, payloads,
		multiplayer.get_remote_sender_id())

@rpc("authority", "reliable", "call_remote")
func _submit_key_bundle(tick: int, routes: PackedInt64Array, kinds: PackedByteArray,
		references: PackedInt32Array, payloads: Array) -> void:
	_receive_state_bundle(tick, true, routes, kinds, references, payloads,
		multiplayer.get_remote_sender_id())

## The sender id travels as an argument because the delay test replays this outside the RPC context, where
## multiplayer.get_remote_sender_id() no longer answers for the original message.
func _receive_state_bundle(tick: int, is_key: bool, routes: PackedInt64Array, kinds: PackedByteArray,
		references: PackedInt32Array, payloads: Array, sender: int) -> void:
	if _probe_enabled:
		# Depth = how far in our predicted past this state lands = the resim this arrival implies.
		# Lead = how far our predicted clock runs ahead of the server clock estimate — the
		# jitter-inflated-lead hypothesis says THIS is what differs native-vs-browser.
		_probe_arrivals += 1
		_probe_depths.append(NetworkTime.tick - tick)
		var lead := NetworkTime.tick - NetworkTime.remote_tick
		_probe_lead_sum += lead
		_probe_lead_max = maxi(_probe_lead_max, lead)
	NetworkPerformance.record_app_state_bundle("in", [tick, is_key, routes, kinds, references, payloads], payloads.size())
	if routes.size() != payloads.size() or kinds.size() != payloads.size() or references.size() != payloads.size():
		NetworkPerformance.note_app_state_rejected()
		return
	if _key_suppress_test and is_key:
		NetworkPerformance.note_app_bundle_skipped(1)
		return
	if _delay_test_ticks > 0:
		_delay_test_queue.append({"release": NetworkTime.tick + _delay_test_ticks, "tick": tick,
			"key": is_key, "routes": routes, "kinds": kinds, "references": references,
			"payloads": payloads, "sender": sender})
		return
	_coalesce_bundle(tick, is_key, routes, kinds, references, payloads, sender)

func _coalesce_bundle(tick: int, is_key: bool, routes: PackedInt64Array, kinds: PackedByteArray,
		references: PackedInt32Array, payloads: Array, sender: int) -> void:
	var bundle := {
		"tick": tick, "key": is_key, "routes": routes, "kinds": kinds,
		"references": references, "payloads": payloads, "sender": sender,
	}
	if not _stale_test_held.is_empty():
		NetworkPerformance.note_app_bundle_skipped(1)
		return
	if is_key:
		if not _bundle_has_newer_route(bundle):
			NetworkPerformance.note_app_bundle_skipped(1)
			return
		if not _all_full(bundle):
			NetworkPerformance.note_app_state_rejected()
			return
		if _stale_test_ticks > 0 and not _stale_test_done and NetworkTime.tick >= 180 \
				and _is_complete_key(bundle):
			_stale_test_held = bundle
			_stale_test_release_tick = NetworkTime.tick + _stale_test_ticks
			print("[state-bundle-test] holding key source=%d release_local=%d" % [
				tick, _stale_test_release_tick])
			return
		if _pending_key.is_empty() or tick > int(_pending_key["tick"]):
			if not _pending_key.is_empty():
				NetworkPerformance.note_app_bundle_skipped(1)
			_pending_key = bundle
		for route_variant in _pending_delta.keys():
			if int(_pending_delta[route_variant]["tick"]) <= tick:
				_pending_delta.erase(route_variant)
				NetworkPerformance.note_app_bundle_skipped(1)
	else:
		for index in payloads.size():
			var route := int(routes[index])
			if tick <= int(_newest_applied_by_route.get(route, -1)):
				NetworkPerformance.note_app_bundle_skipped(1)
				continue
			var previous: Dictionary = _pending_delta.get(route, {})
			if not previous.is_empty() and tick <= int(previous["tick"]):
				NetworkPerformance.note_app_bundle_skipped(1)
				continue
			if not previous.is_empty():
				NetworkPerformance.note_app_bundle_skipped(1)
			_pending_delta[route] = _single_entry_bundle(tick, route, int(kinds[index]),
				int(references[index]), payloads[index], sender)
	_update_pending_age()


func _single_entry_bundle(tick: int, route: int, kind: int, reference: int,
		payload: Variant, sender: int) -> Dictionary:
	return {
		"tick": tick,
		"key": false,
		"routes": PackedInt64Array([route]),
		"kinds": PackedByteArray([kind]),
		"references": PackedInt32Array([reference]),
		"payloads": [payload],
		"sender": sender,
	}

## Apply at most the newest complete key and newest dependent state available when this frame begins. Intermediate
## bundles are coalesced in the RPC handler and never become another history queue.
func _drain_incoming() -> void:
	_report_codec_counters()
	if not _enabled:
		return
	_release_delayed_bundles()
	if not _stale_test_held.is_empty():
		if NetworkTime.tick < _stale_test_release_tick:
			NetworkPerformance.note_app_pending_age(_bundle_age(_stale_test_held))
			return
		_pending_key = _stale_test_held
		_stale_test_held = {}
		_stale_test_done = true
		print("[state-bundle-test] releasing stale key source=%d local=%d" % [
			int(_pending_key["tick"]), NetworkTime.tick])
	var key := _pending_key
	var deltas := _group_pending_deltas(_pending_delta)
	_pending_key = {}
	_pending_delta = {}
	if not key.is_empty() and not _is_complete_key(key):
		# A startup key can beat MultiplayerSpawner registration on the receiver. It is well-formed but not yet a
		# complete local-world key, so coalesce it away and wait for the next coordinated key.
		NetworkPerformance.note_app_bundle_skipped(1)
		key = {}
	if key.is_empty():
		# A complete all-full envelope is a world key no matter which channel carried it. Coordinated keys
		# ride the reliable ORDERED channel, which head-of-line-blocks for seconds under loss (17–20s
		# no-apply stalls in the 2026-07-19 acceptance run) while the unreliable-ordered channel keeps
		# delivering. After a fresh-key request the server's aligned fallback emits exactly such an
		# envelope, so promoting it here exits the wait without depending on the blocked channel.
		for index in range(deltas.size() - 1, -1, -1):
			if _is_complete_key(deltas[index]):
				key = deltas[index]
				deltas.remove_at(index)
				break
	if _waiting_for_fresh_key:
		var handled := false
		if not key.is_empty():
			if _bundle_age(key) <= NetworkRollback.history_limit:
				if _apply_bundle(key):
					_waiting_for_fresh_key = false
					handled = true
			elif _apply_recovery_key(key):
				# A congested link ages even the requested fresh key past the history limit in transit. A
				# complete key is still the entire authoritative world: rebase on it and ask again, instead of
				# holding out for a freshness a growing queue can never deliver. Waiting-forever here is the
				# 2026-07-19 two-client deadlock (applied frozen, fast_forwards=0 for the whole run).
				handled = true
		if not handled:
			_send_fresh_key_request()
			NetworkPerformance.note_app_bundle_skipped(int(not key.is_empty()) + deltas.size())
			return
		if _waiting_for_fresh_key:
			# Recovered from a stale key but still waiting: the coalesced delta is necessarily stale too.
			_send_fresh_key_request()
			NetworkPerformance.note_app_bundle_skipped(deltas.size())
			return
	if not key.is_empty() and _bundle_has_newer_route(key):
		if _bundle_age(key) > NetworkRollback.history_limit:
			if _apply_recovery_key(key):
				_waiting_for_fresh_key = true
			# Request even when the recovery key was unusable (e.g. incomplete during a spawner race): the
			# server then forces a fresh coordinated key instead of this client waiting a full interval.
			_send_fresh_key_request()
			NetworkPerformance.note_app_bundle_skipped(deltas.size())
			return
		_apply_bundle(key)
	var stale_route := false
	for delta in deltas:
		if _bundle_age(delta) > NetworkRollback.history_limit:
			NetworkPerformance.note_app_bundle_skipped(1)
			stale_route = true
			continue
		_apply_bundle(delta)
	if stale_route:
		_waiting_for_fresh_key = true
		_send_fresh_key_request()
	_update_pending_age()


func _group_pending_deltas(pending: Dictionary) -> Array:
	var by_tick := {}
	for entry_variant in pending.values():
		var entry: Dictionary = entry_variant
		var tick := int(entry["tick"])
		if not by_tick.has(tick):
			by_tick[tick] = {
				"tick": tick, "key": false, "routes": PackedInt64Array(),
				"kinds": PackedByteArray(), "references": PackedInt32Array(),
				"payloads": [], "sender": int(entry["sender"]),
			}
		var bundle: Dictionary = by_tick[tick]
		var routes: PackedInt64Array = bundle["routes"]
		var kinds: PackedByteArray = bundle["kinds"]
		var references: PackedInt32Array = bundle["references"]
		routes.append(int(entry["routes"][0]))
		kinds.append(int(entry["kinds"][0]))
		references.append(int(entry["references"][0]))
		bundle["routes"] = routes
		bundle["kinds"] = kinds
		bundle["references"] = references
		(bundle["payloads"] as Array).append(entry["payloads"][0])
	var ticks := by_tick.keys()
	ticks.sort()
	var bundles := []
	for tick_variant in ticks:
		bundles.append(by_tick[tick_variant])
	return bundles

func _release_delayed_bundles() -> void:
	if _delay_test_queue.is_empty():
		return
	while not _delay_test_queue.is_empty() and int(_delay_test_queue[0]["release"]) <= NetworkTime.tick:
		var held: Dictionary = _delay_test_queue.pop_front()
		_coalesce_bundle(int(held["tick"]), bool(held["key"]), held["routes"], held["kinds"],
			held["references"], held["payloads"], int(held["sender"]))

## Reliable transport is not enough on a congested association — pace re-asks so one lost or queue-stalled
## request cannot leave this client waiting forever, without spamming a request per frame.
func _send_fresh_key_request() -> void:
	if NetworkTime.tick - _fresh_key_request_tick < KEY_INTERVAL:
		return
	_fresh_key_request_tick = NetworkTime.tick
	_request_fresh_key.rpc_id(1)
	NetworkPerformance.note_app_fresh_key_request()

## Public: transport send-queue bytes toward a peer, 0 when no provider is wired. Clients use this to gate
## their own input sends — the 2026-07-19 one-Chrome run measured the browser's unreliable send buffer
## ramping to 461KB (~6s of queue) because inputs kept being stuffed into a collapsed congestion window.
func peer_send_pressure(peer: int) -> int:
	# HARNESS LEVER, checked before the real provider. See set_pressure_test_bytes.
	if _pressure_test_bytes > 0 \
			and NetworkTime.tick >= PRESSURE_TEST_WARMUP_TICKS \
			and NetworkTime.tick % PRESSURE_TEST_PERIOD == 0:
		return _pressure_test_bytes
	if _send_pressure_provider.is_valid():
		return int(_send_pressure_provider.call(peer))
	return 0

func _peer_send_pressure(peer: int) -> int:
	return peer_send_pressure(peer)

func _apply_bundle(bundle: Dictionary) -> bool:
	if not _routes_exist(bundle):
		NetworkPerformance.note_app_state_rejected()
		return false
	var ok := true
	var tick := int(bundle["tick"])
	var sender := int(bundle["sender"])
	var routes: PackedInt64Array = bundle["routes"]
	var kinds: PackedByteArray = bundle["kinds"]
	var references: PackedInt32Array = bundle["references"]
	var payloads: Array = bundle["payloads"]
	var ack_routes := PackedInt64Array()
	for i in payloads.size():
		var route := int(routes[i])
		if tick <= int(_newest_applied_by_route.get(route, -1)):
			continue
		var transmitter: Node = _routes[route]
		var entry_ok := false
		if int(kinds[i]) == FULL:
			entry_ok = transmitter.receive_bundled_full_state(payloads[i], tick, sender)
		elif int(kinds[i]) == DIFF:
			entry_ok = transmitter.receive_bundled_diff_state(payloads[i], tick, references[i], sender)
		else:
			NetworkPerformance.note_app_state_rejected()
		if entry_ok:
			_newest_applied_by_route[route] = tick
			_newest_applied_source_tick = maxi(_newest_applied_source_tick, tick)
			if int(kinds[i]) == FULL:
				ack_routes.append(route)
		else:
			ok = false
	if NetworkRollback.enable_diff_states and not ack_routes.is_empty() and sender > 0:
		_ack_full_routes.rpc_id(sender, tick, ack_routes)
		NetworkPerformance.record_app_message("out", "state_full_ack_bundle", [tick, ack_routes])
	return ok

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _ack_full_routes(tick: int, routes: PackedInt64Array) -> void:
	if not multiplayer.is_server() or tick < 0 or routes.is_empty() \
			or routes.size() > _routes.size():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0 or not multiplayer.get_peers().has(sender):
		return
	var seen := {}
	for route_variant in routes:
		var route := int(route_variant)
		if seen.has(route):
			continue
		seen[route] = true
		var transmitter: Node = _routes.get(route)
		if transmitter == null or not is_instance_valid(transmitter) \
				or not transmitter.is_inside_tree():
			continue
		transmitter.receive_bundled_full_ack(tick, sender)
	NetworkPerformance.record_app_message("in", "state_full_ack_bundle", [tick, routes])

func _apply_recovery_key(bundle: Dictionary) -> bool:
	if not _is_complete_key(bundle):
		return false
	var source_tick := int(bundle["tick"])
	var target_tick := NetworkTime.tick
	var sender := int(bundle["sender"])
	var routes: PackedInt64Array = bundle["routes"]
	var payloads: Array = bundle["payloads"]
	var ok := true
	for i in payloads.size():
		var route := int(routes[i])
		var transmitter: Node = _routes[route]
		var entry_ok: bool = transmitter.apply_recovery_full_state(payloads[i], target_tick, sender)
		if entry_ok:
			_newest_applied_by_route[route] = source_tick
		else:
			ok = false
	if ok:
		_newest_applied_source_tick = maxi(_newest_applied_source_tick, source_tick)
		# A recovery rebase IS a state application. Without this, a client surviving on repeated recoveries
		# reports applied_tick=n/a — indistinguishable from the frozen deadlock it just escaped.
		NetworkPerformance.note_app_state_applied(source_tick)
		NetworkPerformance.note_app_fast_forward(maxi(0, target_tick - source_tick))
	return ok

func _is_complete_key(bundle: Dictionary) -> bool:
	if not _routes_exist(bundle):
		return false
	var routes: PackedInt64Array = bundle["routes"]
	if routes.size() != _routes.size():
		return false
	var unique_routes := {}
	for route in routes:
		unique_routes[int(route)] = true
	if unique_routes.size() != _routes.size():
		return false
	return _all_full(bundle)


func _bundle_has_newer_route(bundle: Dictionary) -> bool:
	var tick := int(bundle["tick"])
	for route in bundle["routes"]:
		if tick > int(_newest_applied_by_route.get(int(route), -1)):
			return true
	return false

func _all_full(bundle: Dictionary) -> bool:
	var kinds: PackedByteArray = bundle["kinds"]
	for kind in kinds:
		if int(kind) != FULL:
			return false
	return true

func _routes_exist(bundle: Dictionary) -> bool:
	var routes: PackedInt64Array = bundle["routes"]
	for route in routes:
		var transmitter: Node = _routes.get(route)
		# queue_free removes a body from the tree before its transmitter object is
		# necessarily destroyed/unregistered. A bundle already coalesced for that
		# departing peer must be rejected during this gap, not applied through a
		# valid-but-detached node (which makes its ack RPC fail ERR_UNCONFIGURED).
		if transmitter == null or not is_instance_valid(transmitter) \
				or not transmitter.is_inside_tree():
			return false
	return true

func _bundle_age(bundle: Dictionary) -> int:
	return maxi(0, NetworkTime.tick - int(bundle["tick"]))

func _update_pending_age() -> void:
	var oldest := NetworkTime.tick
	var has_pending := false
	if not _pending_key.is_empty():
		oldest = mini(oldest, int(_pending_key["tick"]))
		has_pending = true
	for bundle_variant in _pending_delta.values():
		var bundle: Dictionary = bundle_variant
		oldest = mini(oldest, int(bundle["tick"]))
		has_pending = true
	NetworkPerformance.note_app_pending_age(maxi(0, NetworkTime.tick - oldest) if has_pending else 0)

@rpc("any_peer", "reliable", "call_remote")
func _request_fresh_key() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	# Cadence signal: this peer fell past the rollback history limit. ⚠ Counted HERE and not derived
	# from ack lag, because this same loop erases _ackd_state[peer] below — the request is the reason
	# the ack reading disappears, so it has to be booked before that happens.
	_cad_key_requests[peer] = int(_cad_key_requests.get(peer, 0)) + 1
	for transmitter in _routes.values():
		if transmitter != null and is_instance_valid(transmitter):
			transmitter.reset_peer_state_reference(peer)
	_force_next_key = true

func _route_for(sync_root: Node) -> int:
	if sync_root == null or sync_root.get_parent() == null:
		return 0
	if sync_root.get_parent().name == &"Players":
		var body_id := str(sync_root.name).to_int()
		if body_id <= 0:
			push_error("State bundle player root does not have a positive numeric id: %s" % sync_root.get_path())
			return 0
		return body_id
	# Car Fight has one authoritative arena ball. Keep its route in the negative
	# namespace so it cannot collide with a multiplayer peer id.
	if sync_root.get_parent().name == &"Balls" and sync_root.name == &"ArenaBall":
		return -1
	push_error("State bundle root is outside Players/Balls: %s" % sync_root.get_path())
	return 0
