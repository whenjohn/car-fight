# Networking review: 2026-09-04

Review baseline: `master` at `9a25b09`. Worktree:
`/Users/johnnguyen/Projects/car-fight-networking`, branch
`codex/networking-review`. This is an audit and research handoff, not an
implementation or deployment. Godot 4.7.1 / Rapier 0.8.39 remain pinned.

## Findings, ordered by priority

### 1. Packed input silently falls back for every current player

**Confirmed, high priority.** `player/player_body.gd:210` registers 14 input
properties, including `Input:drop_troops` at line 221. The codec's
`EXPECTED_ORDER` in `net/input_codec.gd:19` has only 13, omitting that property.
`can_pack()` requires an exact count and order; `pack()` returns the original
Variant array on mismatch. Therefore `--packed-input` does not compress the
current player input stream, even though startup prints `enabled=1`.

Today's opt-in runtime corroborates this: the server reports 129 input messages
occupying 63,984 logical bytes in one interval, exactly 496 bytes/message.
The client reports 61 messages / 30,256 bytes. These are application serializer
measurements, not UDP or SCTP wire sizes. State packing is working in that run:
its counters show 21 deadband drops with zero fallbacks or rejects.

`tests/input_codec_test.gd:16` builds its fixture from the codec's own expected
list. It passes today while missing the production schema mismatch. Also,
`_input_backpressure_bytes()` in the history transmitter chooses the smaller
packed threshold from the flag, even when the actual payload falls back.

**First implementation:** support the actual registered schema, preserve every
control bit, explicitly version compatibility, and test against a real spawned
player's properties. Log packed/fallback counts and actual bytes. Thirteen
booleans still fit in the existing 16-bit mask, but inserting one changes bit
and decoded-array meanings: do not silently reinterpret version 1. Verify the
send-pressure threshold against the actual encoding. Add live native and mixed
transport evidence, including troop drop and malformed/versioned input.

### 2. Gate PASS currently allows real lifecycle errors

**Confirmed, medium priority.** Both passing runtime logs contain
`ERROR: The multiplayer instance isn't currently active` after `CLIENT_STOPPED`.
Backtraces include `Main.gd:483`, `Main.gd:3774`, `world/dots.gd:170`, and
`world/oil_slicks.gd:29`. The first failed legacy run also contains a CityBall
RPC arriving before its target node can be resolved.

`scripts/network_test.sh:117` only scans a short list such as `SCRIPT ERROR`
and `Invalid call`; these engine errors are outside its filter. It waits for
the server, reads client logs, and kills remaining clients during cleanup,
so a PASS is not proof of clean client shutdown. The first legacy correction
failure (2.852 units) passed on its one permitted repeat (1.587 units).

**Next implementation:** use explicit connection/teardown state before peer-ID
queries; diagnose spawn/RPC ordering separately. Finish collecting client logs
before asserting results. Fail unexpected engine errors, with narrow documented
allowlists only where justified. Keep the existing 2-unit ceiling. Record the
intermittent failure rather than rerunning until the baseline appears clean.

### 3. Normal play does not use the whole previously accepted lab stack

**Confirmed configuration gap, not a reason to flip every switch.**
`Main.gd:143` defaults to bundles/packed input/packed state off, 60 Hz legacy
remote poses, all recipients, self included, fixed 75 ms presentation, no local
presentation smoothing, and no adaptive cadence. Input broadcast is already
off. The normal serve/join scripts do not enable the lab profile.

The running macai2 process was inspected read-only. It uses
`--server --transport mux --port 10080 --signal-port 10181`, with no lab flags.
Its deployed directory has no Git metadata, so its exact revision was not
established; local-source defaults must not be mistaken for a verified remote
binary/configuration manifest.

There is a second distinction: `StateBundle._peer_uses_product_wire()` at
`net/state_bundle.gd:263` only selects WebRTC recipients on a mux server.
Even with the flags enabled, native recipients of that server retain the
older state path. A pure-ENet G2 test enables bundles for native recipients,
so it does not characterize normal native-through-mux behavior.

**Next experiment:** record one resolved configuration per server and client,
with revision/schema identifiers, and compare pure ENet, ENet through mux,
and WebRTC through mux explicitly. Promote proven pieces individually after
current gameplay and mixed-peer tests. Preserve the opt-in control.

### 4. Browser connection failures are not consistently bounded

**Code-confirmed failure path; not reproduced in a browser this session.**
In `net/webrtc_transport.gd:268`, a closed signaling socket reports failure
only when `_client_signal_open` is already true. An asynchronous connection
failure before OPEN can leave the UI connecting indefinitely. An open socket
with no ID/answer or an ICE negotiation that never completes also has no
application deadline. On the server, pending signaling peers have no overall
admission cap or negotiation deadline (`_poll_server_signaling`, line 229).

`Main.gd:985` logs client stop but has no normal-play retry/rejoin flow.
The existing reconnect gate starts replacement processes; the Web soak reloads
the page. Those are useful server-lifecycle tests, not automatic same-client
recovery from sleep or a changed network.

**Next implementation:** bounded connect/ID/ICE deadlines, pending-peer cleanup,
clear retry state, and fresh session generations on rejoin. Test refused and
silent endpoints, blocked UDP, interrupted signaling, tab suspension, and
Wi-Fi changes. Keep an established DataChannel alive when only signaling is
lost, as the existing implementation intends.

### 5. Batching has no packet-byte budget at larger counts

**Confirmed structural risk; high-count failure not measured today.**
`net/remote_position_transport.gd:494` puts the entire selected set into one
unreliable RPC. The cap is 64 bodies, not a byte limit. Its array elements
consume 64 bytes/body before envelope and protocol overhead; 64 bodies alone
therefore occupy 4 KiB. At today's 16-native-client limit the pose message is
much smaller, but still needs an actual transport-size check.

`net/state_bundle.gd:766` also sends all routes in one envelope. Every 24 ticks
it sends a reliable full key plus an unreliable-ordered mirror. The 64 KiB
backpressure guard only suppresses ordinary bundles; keys/mirrors and the
separate remote-position stream continue. This bounds neither all offered
traffic nor packet size during sustained congestion.

**Next experiment:** measure packet bytes and fragmentation at 2/4/8/16 active
players with representative balls, props, and combat. Establish a conservative
application payload budget from the smallest supported path, reserving RPC,
transport, encryption, and tunnel overhead. Then pace/chunk replaceable state
and account for recovery traffic. Complete-set pose membership is meaningful:
never split the array and feed each fragment to the old complete-set receiver,
which would incorrectly remove bodies absent from that fragment. Preserve
generation, completeness, recovery, and per-route starvation guarantees.

## Current architecture

| Layer | Current implementation | Implication |
| --- | --- | --- |
| Authority | Server owns bodies/state; owning client owns input | Preserve validation and collision authority |
| Simulation | 60 Hz netfox ticks; project physics 120 Hz | Two clocks/settings with different responsibilities |
| Input lead | Eight network ticks, about 133 ms; redundancy default 3 | Measure local response and replay cost before tuning |
| History | 64 rollback ticks; two-window diff-base retention | History retention is not permission to replay indefinitely |
| Native | ENet; production server uses a mux | Pure ENet tests alone miss mux recipient policy |
| Browser | WebRTC DataChannels; WebSocket signaling only | HTTP throttling does not shape gameplay packets |
| Presentation | Fixed/adaptive delayed sampling, predictive/proxy alternatives | Defaults and accepted lab modes differ |
| Replication | Rollback vehicles/balls; lightweight sprite motion/events | Scale each object family according to its cost |
| Platform baseline | Mac native and Chrome have historical acceptance | No equivalent complete matrix for other platforms |

Rapier metadata identifies the installed flavor as
`godot-rapier-3d-single-enhanced-determinism`. This is already the deterministic
build; proposing to simply enable that feature would miss the actual setup.
Rapier's documentation distinguishes deterministic physics from scene-tree,
input, and script state. Cross-platform replay still requires measuring the
whole game's state, particularly contacts and lifecycle ordering.
[Godot Rapier determinism](https://godot.rapier.rs/docs/documentation/determinism/).

## Measurements from this review

All runtime comparisons used the same baseline and existing headless
two-client `converge` harness, 480 server ticks, profile `combined`:
120 ms added one-way delay, +/-40 ms jitter, and 1% loss in each direction.
No rendering or live service changes occurred.

| Run | Gate result | Worst correction | Missing-reference warnings | Proxy received C->S / S->C |
| --- | --- | ---: | ---: | ---: |
| Legacy A | FAIL | 2.852 units | 2 | 1,362 / 6,241 |
| Legacy repeat | PASS with lifecycle errors | 1.587 units | 6 | 1,511 / 6,520 |
| G2 opt-in, divisor 1 | PASS with lifecycle errors | 0.586 units | 0 | 1,281 / 1,731 |

The opt-in run sent substantially fewer downstream datagrams in this sample,
but the counts are not normalized throughput, the script/physics schedules are
not identical, and input packing fell back. This comparison identifies a
candidate; it does not isolate which optimization helped or establish a stable
percentage improvement. A fixed random seed does not fix packet scheduling or
random peer IDs. These short contact tests do not establish visual smoothness,
long-session stability, mobile performance, or 16-player capacity.

`scripts/check.sh` passed. The existing input codec test passed, illustrating
the schema coverage gap. Its sandboxed invocation also emitted a macOS system
certificate-access error, separate from its assertions. An initial sandboxed
network run could not bind UDP; it was excluded, and the three measurements
above ran with local socket access.

Read-only `tailscale ping` reached macai2 directly over IPv6 in one 87 ms sample.
This does not establish typical RTT or imply a relay problem. Tailscale's own
diagnostics distinguish direct, peer-relay, and DERP paths; record that type
alongside game measurements instead of attributing all latency to netcode.
[Tailscale connection types](https://tailscale.com/docs/reference/connection-types).

Raw logs are retained locally under ignored
`.network-runs/review-2026-09-04/`. Original run directory suffixes:
`ZwAF3b` (legacy A), `PILrKr` (repeat), `Cw0hbs` (G2). The checked-in findings
above remain available without those local artifacts.

## Research-backed improvement candidates

### Input responsiveness and replay cost

Netfox records and sends current input at `tick + input_delay`; eight ticks is
about 133 ms of configured scheduling lead, not a measured end-to-end response
number. Local prediction does not by itself prove this delay is imperceptible.
The upstream explanation explicitly trades delayed input for fewer resimulated
frames. [Netfox rollback settings](https://foxssake.github.io/netfox/latest/class-reference/_NetworkRollback/).

Measure input sample -> first predicted steering -> authoritative application
-> presentation. Sweep fixed 8/6/4/2-tick settings in matched runs, first on a
clean path and then under impairment. Collect replay depth/cost, corrections,
and contact outcomes. Lower delay is a hypothesis, not a default recommendation:
it can increase late inputs and CPU load. Keep input delay, state cadence, and
presentation buffering as separate experiments. Do not revive the rejected
half-handshake-RTT seed or resimulation budget.

### Remote motion and frame pacing

The fixed/adaptive sampler currently uses linear positions plus quaternion
slerp (`net/remote_snapshot_interpolation.gd:92`). It already receives linear
velocities, although the delayed position sampler does not use them. A bounded
Hermite interpolation trial could improve velocity continuity without raising
the send rate. Glenn Fiedler demonstrates this tradeoff and explains why loss
requires buffer margin and why rigid-body collisions make extrapolation hard.
[Snapshot interpolation](https://gafferongames.com/post/snapshot_interpolation/).

Compare fixed 75/100/125 ms against the existing adaptive estimator using
matched driving traces. A 75 ms buffer at 30 Hz spans only 2.25 publication
intervals before accounting for clock alignment and jitter. More delay may hide
loss but increases the age of visible opponents. Hermite must fall back or
clamp at teleports, impacts, missing history, and overshoot; never use a smooth
visual path as authoritative collision evidence.

Historical Networking 2 accepted local visual smoothing in the harness, with
remaining disturbances linked to frame/rollback cost. Measure server tick and
client frame P50/P95/P99 together with state age. An interpolated stream can
still look poor when the browser misses frames. Keep rendering and physics
policy fixed during the first networking comparisons.

### Congestion, channels, and relevance

WebRTC's three default channels already separate transfer modes; lifetime 1
is already configured. Godot passes that value into `maxPacketLifetime` for
the unreliable channels. Changing channel count or shortening lifetime is not
an established fix for local queuing.
[Godot WebRTCMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html).

SCTP data channels in one association share a congestion window. Separate
channels may separate ordering dependencies but cannot create bandwidth or
independent congestion control. Audit reliable recovery and gameplay events,
reserve recovery capacity, and prioritize fresh input/state before adding
channels. [RFC 8831, section 6.1](https://www.rfc-editor.org/rfc/rfc8831.html#section-6.1).

Existing adaptive state cadence is off and inert with a base divisor of 1.
It can move between 1 and its configured base, not reduce traffic beyond that
base. Test it only after actual uplink/downlink byte and applied-age measurements.
Channel buffered bytes are a backstop, not complete congestion evidence.

Same-map relevance filters nothing spatially in the current one-map city.
For larger player/object counts, measure distance/interaction relevance with
hysteresis and a safety margin for fast vehicles and projectiles. Do not remove
colliding neighbors from prediction or turn every object into a rollback body.
Consider compact encoding for frequently changed scalar state only after a
per-message breakdown identifies it as material.

### Connectivity and observability

Keep native ENet and browser WebRTC. Godot Web cannot use native UDP directly;
switching all clients to another transport is a separate architecture project.
The browser can suspend background tabs, so resume/rejoin needs real-device
validation. [Godot Web limitations](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#limitations).

Add selected ICE candidate type/protocol, connection setup stages, bytes,
application state age, input age, and queue/drain counters to existing reports.
W3C defines candidate-pair RTT, traffic, and candidate identifiers. ICE RTT
measures connectivity checks, not input-to-game latency; RTP jitter/loss fields
must not be substituted for DataChannel metrics. Treat unsupported browser
stats as unavailable rather than zero.
[WebRTC statistics](https://www.w3.org/TR/webrtc-stats/).

For public browser access, validate HTTPS/WSS and actual direct ICE plus TURN
fallback from outside the tailnet. The current TURN harness is a LAN macvlan
fixture, not proof of public/mobile reachability. TURN exists for paths where
direct sockets cannot connect; compare nearby relay placement and UDP versus
restricted-network TCP/TLS fallback, documenting the latency tradeoff.
[WebRTC TURN guidance](https://webrtc.org/getting-started/turn-server).

## Platform and impairment matrix

"All platforms" is treated as desktop native plus desktop/mobile browsers,
with native Android/iOS as future export targets. Only Web export presets are
checked in today; native mobile and packaged desktop readiness is not implied
by the extension's platform library mappings.

| Target | Required next evidence |
| --- | --- |
| macOS Intel and Apple Silicon | ENet through mux, input response, contact correction, safe-window frame pacing |
| Windows x64 and Linux x64 | Same input trace against Mac server; actual packaged build and Rapier load; join/leave |
| Chrome/Edge and Firefox desktop | WebRTC direct + TURN, applied age, queue behavior, background/resume |
| Safari macOS | Real Safari export compatibility, timing, DataChannels, resume; not only a WebKit automation substitute |
| iPhone/iPad Safari and Android Chrome | Real devices, Wi-Fi/cellular change, lock/resume, memory/thermal/frame cost |
| Native Android/iOS, when pursued | Export setup, extension availability, Android INTERNET permission, app lifecycle, ENet path |

Godot explicitly requires Android INTERNET permission for networking.
[Godot ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

Begin with existing clean/latency60/latency120/jitter/loss05/loss1/combined
profiles. Then add burst loss, asymmetric uplink/downlink capacity, bandwidth
steps, background/resume, and handover. The current UDP proxy models independent
delay/jitter/loss; it does not model a bandwidth ceiling or correlated outages.
Use isolated netem/TURN infrastructure for browser packet shaping, never HTTP
download throttling as a proxy for game traffic.

Run player counts 2/4/8/16, then representative object counts, increasing one
dimension at a time. Separate cold join, warm steady movement, combat/contact,
and recovery metrics. Pair one impaired peer with a healthy observer to verify
that adaptation does not degrade the whole room. Rendered acceptance must use
the project's monitored safe-window workflow and be scheduled separately.

## Recommended execution order

1. Repair input codec/schema coverage and actual-encoding telemetry. Verify
   version handling, every input bit, and live native/mixed paths.
2. Repair connection/teardown errors and gate collection/classification, keeping
   existing quality ceilings. Add bounded failed-connect behavior.
3. Establish a repeatable current-gameplay baseline for pure ENet, native mux,
   and browser mux. Include configuration/revision proof and source-age metrics.
4. Trial current optimized pieces on those paths, then input delay and visual
   interpolation separately. Compare each against its own unchanged control.
5. Use load evidence to choose packet budgets, pacing, relevance, and recovery
   scheduling. Expand real-platform and public-connectivity coverage.

Before any future shared schema/netfox/authority merge, run the directly
affected focused gates plus the full milestone suite as required by
[quality gates](QUALITY_GATES.md). This review changed documentation only;
no networking optimization has yet been implemented or deployed.

## Implementation follow-up: packed input, 2026-09-04

The audit above describes the pre-fix baseline. The owner subsequently approved
the first codec/schema fix in the same worktree, without deployment or default
changes. The following evidence supersedes finding 1's implementation status,
not the other findings or platform acceptance gaps.

### Changes and compatibility

- Format 2 registers `drop_troops` at mask bit 10, `tractor` at 11, and `editing`
  at 12. Cursor and the first ten control bits retain their previous encoding.
  Each snapshot remains six payload bytes, plus a four-byte history header.
- Format 1 and unknown versions are explicitly rejected. There is no protocol
  negotiation or automatic downgrade to old executables: update both ends before
  opting into packing. Matching builds still accept legacy Variant arrays with
  packing disabled, and receive behavior does not depend on the send flag.
- Packed receive validates the sender-owned registered schema, header, exact
  length/count, and reserved mask bits before netfox decodes it. Bad packed
  envelopes cannot fall through into the flat Variant decoder. Unsupported send
  schemas/values fall back unchanged, without silently coercing control types.
- The input queue threshold selects 4 KiB for actual packed output and 16 KiB
  for Variant output, rather than using the requested packing flag.
- `[packed-input]` diagnostics identify version 2 and cumulative `packed`,
  `fallbacks`, `encoded_bytes`, `received`, and `rejects`. Encoding counters include
  attempts later dropped by queue pressure; bytes measure the serialized input
  array only. `NETAPP` still counts actual submitted RPC argument bytes. Neither
  measures UDP/SCTP/encryption overhead or confirms authoritative application.
- `scripts/mixed_transport_test.sh` accepts `CAR_FIGHT_PACKED_INPUT=1` for its
  shared-world case and requires packing/receive evidence with no fallbacks or
  rejects. Its default and the subsequent lifecycle controls remain unchanged.

### Focused verification

The replacement `input_codec_test.gd` spawns through `Main._spawn_player()` and
executes the player's real `_ready()` registration under an offline SceneTree.
It failed against the original codec on the live schema assertion. After the
fix it passes all 8,192 control combinations, pinned changed-bit assignments,
cursor boundaries, three-snapshot netfox encode/decode/apply with input-owner
sanitization, malformed/version/schema cases, the 255-snapshot limit, actual
encoding counters/thresholds, disabled packing, and mux recipient policy.
The troop-drop round-trip is through netfox history, not a live troop-spawn
combat scenario.

Commands and results:

```bash
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/input_codec_test.gd -- --offline
# INPUT_CODEC_TEST PASS
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/state_bundle_coalescing_test.gd
# STATE_BUNDLE_COALESCING_TEST PASS
./scripts/check.sh
# FAST_CHECK PASS
CAR_FIGHT_PACKED_INPUT=1 ./scripts/network_test.sh combined
# PASS: worst correction 1.375, reference rejections 2
CAR_FIGHT_PACKED_INPUT=1 ./scripts/mixed_transport_test.sh
# PASS: worst correction 0.385
```

The native run enabled only packed input/telemetry, leaving the ordinary state
path and its defaults intact. Steady `NETAPP` input intervals measured 60 logical
bytes/message (for example 128 messages / 7,680 bytes), versus 496 in the audit.
Both native senders reported zero fallbacks, and the server reported 326 valid
packed receives / zero rejects at its first codec window. The mixed mux run
reported 245 ENet-client and 207 WebRTC-client packed attempts at their first
windows, zero fallbacks/rejects, and 551 server receives by its second window.
These are different reporting windows, not synchronized packet-loss counts.

Local evidence is retained under ignored
`.network-runs/packed-input-2026-09-04/`: `car-fight-network.vkW6kV` and
`car-fight-mixed.redMYf`. ENet still emits the previously recorded inactive-peer
shutdown errors despite gate PASS. Mixed shared-gameplay and transport-door
control logs contain no engine/script errors; its intentional peer-ID collision
reports the expected signaling closure. Sandboxed unit checks emitted a macOS
certificate-store permission error; the final codec run with that permission
passed without engine errors (its intentional malformed-packet reject is logged).

The final malformed-envelope hardening was rechecked by the codec regression;
it does not change valid packets exercised by the live runs. No broad suite,
real browser, TURN, packaged-platform, mobile, or rendered test was run. The
native WebRTC extension gate does not substitute for browser acceptance. Run
the full milestone suite before any shared-schema/netfox merge, and retain the
review's lifecycle and platform work before promoting networking defaults.

## Implementation follow-up: connection guards and gate, 2026-09-04

The next bounded implementation addresses the inactive-peer frame errors in
finding 2 and the incomplete logs in `scripts/network_test.sh`. It does not
implement reconnect/rejoin, browser negotiation deadlines, or the separate
sporadic CityBall spawn/RPC ordering issue.

### Contract and changes

Server authority, input/state schemas, replication classes/rates, collision math,
and netfox's history/lifecycle patches are unchanged. A small shared predicate
requires a connected peer before the affected gameplay identity/authority queries;
offline play remains valid. No disconnected network peer is replaced with an
OfflineMultiplayerPeer as a workaround, which would incorrectly imply authority.

Main frame/tick/input/probe entry points and local-player lookup are guarded, as
are pickup prediction, vehicle presentation, city/oil visuals, and boost blur.
Client stop records DISCONNECTED and clears automatic cruise. This stops the
observed unsafe callbacks; it does not clear/rebuild the entire world or constitute
a complete same-session recovery workflow. The extra guards are constant-time
status checks and add no replicated objects or messages.

The ENet gate now waits for both clients before evaluating logs, keeps the proxy
alive until they finish, checks exit codes, and fails engine errors as well as
script errors. Each post-server client wait is bounded by
`CAR_FIGHT_NETWORK_SHUTDOWN_TIMEOUT` (default 10 seconds). A hung client is killed
and reaped, and the gate fails. The existing server-first test intentionally causes
client exit 2; only that code with CLIENT_STOPPED is accepted in addition to zero.
There is no engine-error allowlist in this gate, and the two-unit correction ceiling
is unchanged. This is not an overall server-run timeout or a rewrite of all harnesses.

### Verification and limits

- `tests/connection_lifecycle_test.gd -- --offline --presentation-test` first
  reproduced unsafe identity queries and missing disconnect status. With the fix,
  its instrumented peer passes connected/offline, connecting/disconnected frames,
  stop-event, Main tick/probe/leave callbacks, local lookup, gameplay input, and
  cruise checks. Presentation nodes are exercised headlessly, without a window.
- `scripts/network_test_harness_test.sh` passes a clean server-first shutdown,
  rejects an engine error emitted after the server has exited, rejects exit 3,
  bounds a hung client, and verifies all fixture child processes are reaped.
  This is orchestration coverage, not gameplay or transport evidence.
- `CAR_FIGHT_PACKED_INPUT=1 ./scripts/network_test.sh combined` passed at 0.805
  units, three reference rejections, and no engine/script errors in complete logs.
  Both clients recorded CLIENT_STOPPED. Codec fallbacks/rejects remained zero.
- `CAR_FIGHT_PACKED_INPUT=1 ./scripts/mixed_transport_test.sh` passed at 0.300
  units. Shared gameplay and transport-door logs were clean; the deliberate
  peer-ID collision retained its expected signaling-closure error.
- `./scripts/reconnect_test.sh` passed with three joins, three leaves, and six
  two-player survivor samples, using unchanged native networking defaults.
- `./scripts/check.sh` and the live input codec regression passed. The final
  lifecycle regression with certificate-store access emitted no engine errors;
  sandboxed development invocations of GDScript tests emitted the known macOS
  certificate permission diagnostic, separate from assertions.

Evidence is retained under ignored `.network-runs/lifecycle-2026-09-04/`:
`car-fight-network.8jLXaR`, `car-fight-mixed.GPURu8`,
`car-fight-reconnect.dPAL4M`, and `car-fight-network-harness.XZaYGB`.
The ENet run preceded the final connecting-state blur guard, which is covered by
the lifecycle regression and subsequent mixed/reconnect runs. No new throughput
or visual-feel claim follows from these short correction samples. No production
deployment, default change, rendered/browser/mobile/TURN run, or master merge.
The full milestone suite remains a pre-merge requirement for this branch.
