# Web and platform plan

Status: **historical rollout plan**. Local Web export/cross-play, remote
forced-TURN testing, reconnect soak, and two-player acceptance were completed
after this plan was written. The deployed service now keeps native ENet and
adds WebRTC through the server mux. Public browser HTTPS/WSS hosting and TURN
remain separate future work. Do not use the phase checklists below as current
session authorization; use `README.md` and `.ai/CONTEXT.md` for current state.

## Decision

Bring up the Web platform next, while Car Fight still has a small replicated
world. Start with export/render/physics viability, then evaluate WebRTC in an
isolated test world. Do not replace or disturb the native ENet service on
macai2 UDP 10080 until browser acceptance is complete.

Before opening another broad rendered test cycle on the affected Intel Mac,
add the small window-safety guard described below. This is platform hardening,
not a renderer investigation.

## Baseline already accepted

- Native desktop uses ENet, server-authoritative Rapier physics, client-owned
  input, prediction, rollback reconciliation, and remote interpolation.
- The full suite covers 120 ms one-way latency, shared-world replication,
  late-join recovery, and disconnect/reconnect.
- macai2 runs the isolated native service on UDP 10080. G2's services remain
  separate and must not be changed by Car Fight work.
- Native peer lifecycle is complete for current scope. Keep D-040 and the
  detached-input guard; do not restore the rejected half-handshake-RTT seed.
- Do not assume that a smooth two-player world proves object-count scale.

## Latest rendered evidence

The two-window macai2 run at commit `710cf5b`, preserved under
`.crash-runs/two-client-20260820-013633`, completed cleanly and felt good to
the user:

- both peers remained in one replicated world;
- worst measured corrections were 0.587 and 0.933 units;
- there were no impossible-history floods, script errors, or desynchronization;
- the final 20-sample averages were about 132 and 135 FPS.

The brief 6-8 FPS interval was not networking or gameplay physics. Bravo had
been enlarged from 1280 x 720 to 2800 x 1518, increasing its pixel area by
about 4.6 times while Alpha was still rendering. Physics stayed below about
one millisecond. Reducing the window restored performance.

The same run also recorded 306 `Invalid actual_host_time` lines during its
first 21 seconds. They stopped before the resize/FPS dip and produced no
VBlank timeout, GPU reset, watchdog, thermal warning, or WindowServer restart.
WindowServer remained the same PID. This is still the known precursor family,
so a clean exit does not authorize maximizing or moving either window to an
edge-to-edge layout.

## Phase 0: Intel Mac window safety

Add a small, tested runtime policy for affected Intel Macs:

- require ordinary decorated windowed mode;
- clamp the window to a safe inset size and position;
- prevent or immediately undo native, borderless, and near-edge maximization;
- keep the policy scoped to the affected platform instead of changing other
  desktop targets;
- record every enforcement action in crash telemetry.

Acceptance: an attempted maximize/oversize returns to the safe inset without
changing gameplay state, and the existing windowed monitor remains clean.
Do not repeat fullscreen, ANGLE, Vulkan, or edge-coverage experiments.

## Phase 1: offline Web export smoke

Create a fresh feature worktree and branch from `master` (suggested
`~/Projects/car-fight-web`, `feat/web`). The first checkpoint has no network
transport changes.

1. Add a Web export preset using the Compatibility renderer.
2. Start with the default single-threaded Web export for compatibility and
   simpler hosting.
3. Enable Web GDExtension support. The vendored Rapier package already contains
   both `bin/godot_rapier.wasm` and
   `bin/wasm-nothreads/godot_rapier.wasm`.
4. Add a reproducible CLI export-and-serve helper. Use localhost initially;
   use HTTPS when deployed outside localhost.
5. Prove in Chromium that the project loads, Rapier initializes, a Jeep can be
   controlled, the arena renders, and telemetry is captured.
6. Record load time, steady FPS, frame hitches, nodes, draw calls, memory, and
   browser console errors. Do not use continuous DevTools collection if it
   changes performance.

Only consider a threaded export if the measured single-threaded build cannot
hold the simulation cadence. A threaded build requires correct COOP/COEP
headers and must be a measured decision rather than a default.

### Phase 0-1 result — 2026-08-20

- Added an affected-platform-only runtime policy for rendered Intel macOS. It
  restores decorated windowed mode, clamps to 1280 x 720 inside a 48-pixel
  usable-screen inset, preserves minimization, and records enforcement through
  crash telemetry. Pure policy regressions cover maximized, borderless,
  oversized, and near-edge inputs without repeating a risky native display
  experiment.
- Added an offline role that directly spawns one local Jeep and ball without
  rollback synchronizers or an ENet bind/connect. Its deterministic headless
  gate proves normal boost input and rejects stale rollback or transport logs.
- Added the `Web Offline` export, localhost isolation-header server, and bounded
  Chrome smoke. The Web build uses Compatibility, Rapier's Web GDExtension,
  single-threading, and a fixed 1280 x 720 render surface scaled to the browser
  viewport with aspect preservation.
- The retained Chrome 151 release smoke reached offline-ready in 2.42 seconds,
  loaded Rapier 0.8.39, moved the Jeep at 17.99 units/s through normal mouse
  input, and produced ten telemetry samples with no console/script errors. The
  final five samples averaged 59.6 FPS (58 minimum); the latest sample had 409
  nodes, 61 draw calls, 187 render objects, and 22,166 render primitives.
- A same-machine threaded A/B was clean but did not materially improve the
  earlier single-thread measurement. The final single-thread confirmation was
  faster, so the compatible single-thread preset remains accepted for this
  offline checkpoint. Revisit threads only if a repeatable browser workload
  falls into sustained simulation catch-up.
- Native ENet and macai2 UDP 10080 were not changed or redeployed. Phase 2
  remains an explicit future WebRTC scope decision.

## Phase 2: isolated WebRTC network proof

Browsers cannot use the current ENet/UDP peer. Use WebRTC DataChannels for the
browser gameplay candidate. WebSocket/WSS may be used for signaling, but do
not use WebSocket as the gameplay transport: G2 established that its TCP queue
has a lower ceiling than WebRTC under latency plus loss.

Keep production ENet unchanged during this phase:

- run signaling and the WebRTC game service on new isolated ports;
- start with one browser and one native WebRTC client in a fresh test world;
- reuse G2's proven signaling, TURN test concepts, and telemetry selectively;
- do not bulk-port G2's StateBundle, packing, batching, rate division,
  relevance, or browser product defaults before Car Fight measurements require
  them;
- keep Car Fight's existing authority model and input-broadcast-off behavior.

The native WebRTC server/client path will require the compatible native
WebRTC extension. TURN is required for a real relay/loss acceptance test, but
must remain isolated from the native ENet service.

### Phase 2 localhost result — 2026-08-20

- The pre-network same-machine control ran one offline browser beside one
  monitored rendered native ENet client. The browser's final five samples
  averaged 58.4 FPS (55 minimum); native telemetry averaged 77.7 FPS and its
  physics maximum was 1.03 ms. This established that the machine can host both
  renderers before transport cost is introduced. `browser_native_baseline.sh`
  reproduces that control.
- Chose the mixed-transport candidate: native clients remain on ENet, browsers
  use WebRTC DataChannels, and one server-side `MultiplayerPeer` mux presents
  both transports to the unchanged authoritative game world. WebSocket is used
  only for WebRTC signaling.
- Added separate `Web Offline` and `Web Network` exports. The offline preset is
  still transport-free; the network preset opts into WebRTC through the
  `web_network` custom feature and accepts a `signal` query parameter.
- Ported the smallest G2 transport subset: signaling/WebRTC lifecycle, the
  mux, send-queue telemetry, and the macOS universal native WebRTC extension.
  The extension declares Godot 4.3 compatibility and loads under 4.7.1. Its
  debug/release dylib SHA-256 values are `e7dafd2d345b8e8591734f7bdd243f43fc859dc711f73639d9348bbda190f382`
  and `e477dbdcce56adeb024e34e56abb023f3eeee6b412097977d693858e560408a1`.
- Automated localhost coverage proves distinct ENet/WebRTC peer IDs in one
  world, reciprocal authoritative movement/contact, ordinary leave and browser
  refresh/replacement, a retained RPC tombstone while cross-transport packets
  drain, peer-ID collision rejection, and survival when either transport leg
  closes.
- Repeated exported Chrome 151 runs admitted browser peers 2 then 3 alongside
  a surviving native ENet peer, produced changing shared-world snapshots, and
  drained the WebRTC buffer after peaks no larger than 5,080 bytes. There were
  no script/browser errors. The slow repeated final window ranged from 31 to
  60 FPS and averaged 47.6 FPS; the final accepted run averaged 57.2 FPS with a
  49 FPS minimum. The localhost capacity smoke therefore gates 30 FPS minimum
  / 45 average. This is sufficient for same-machine cross-play testing, but it
  does not meet the stricter Phase 3 remote-product cadence criterion.
- The first human rendered localhost cross-play session used the safe monitored
  native ENet client beside the Chrome WebRTC client in the same mux world.
  Both players remained present and responsive for more than five minutes at
  documentation time, and the user reported that it played well. Native
  telemetry averaged 58.3 FPS across the active run and 74.4 FPS over its
  latest 20 samples. The user attributed the slower earlier automation samples
  to unusually heavy unrelated load on this machine. Keep the conservative
  automated floor as a regression guard; human acceptance establishes that
  browser and macOS clients can be tested together on this machine.
- A three-sample server CPU A/B with the same two ENet clients measured median
  CPU time of 3.37 seconds for pure ENet and 3.76 seconds for the mux over an
  eight-second run: 0.39 added CPU-seconds, or 4.88% of one core. The relative
  increase is 11.57% because the control server is deliberately tiny.
- No StateBundle, packing, batching, rate division, TURN service, WAN shaping,
  or macai2 deployment was added. UDP 10080 remains untouched.

## Phase 3: acceptance matrix

Every row must retain the current native ENet control. Use measured shaping,
not configured-delay assumptions.

Before this matrix, port G2's shaping harness in the smallest form that can
exercise Car Fight's mux topology. It must apply real latency, jitter, loss,
reordering, and reconnect disruption to the relevant transport leg, then record
rollback recovery and WebRTC queue behavior. Do not accept a setting that merely
claims a delay without changing packet delivery.

Run, in order:

1. localhost clean link;
2. remote clean link through the isolated service;
3. 60 ms one-way latency;
4. 120 ms one-way latency;
5. latency plus 0.5% loss;
6. latency plus 1% loss;
7. browser refresh/reconnect while a native peer remains connected;
8. a 5-10 minute human soak after automated gates pass.

Require:

- both peer IDs in one world and reciprocal movement;
- server authority and local prediction unchanged;
- clean late join, disconnect, refresh, and replacement;
- no impossible rollback, stale-packet flood, missing-node RPC flood, or script
  error;
- steady corrections within the existing two-unit ceiling;
- browser frame rate that stays above the 60 Hz simulation cadence without a
  sustained catch-up loop;
- bounded WebRTC send queues and rollback debt that recover after impairment;
- application-message and byte-rate telemetry by class;
- no acceptance threshold weakened merely to make Web pass.

## Windows native checkpoint

Add a Windows export/build smoke before treating the native side as
cross-platform complete. Reuse G2's packaging pattern: a Windows export preset,
a Windows player smoke, and the matching Windows `webrtc-native` extension
binary for the optional WebRTC path. ENet remains the normal Windows-native
transport; the extension must be present so a Windows client can join the mux
when that scenario is explicitly tested. Keep platform integration code at the
transport/export boundary, not in gameplay scripts.

## Phase 4: production cross-play decision

The localhost proof selected how browser and native players should share a
test world; production still waits for the full Phase 3 matrix:

- Preferred candidate: retain ENet for native clients and add the smallest
  proven mixed-peer/mux layer needed for WebRTC browsers.
- Alternative: move every platform to WebRTC only if measured results justify
  giving up ENet's stronger native behavior.

Do not introduce a mixed transport directly into UDP 10080. First add lifecycle,
peer-ID collision, join-order, reconnect, and transport-isolation regressions,
then deploy it beside production for a soak. Cut over only through an explicit
scope decision.

## Object-count gate before more world content

Browser work and object-scale work must meet before the next gameplay-object
family. Establish representative counts and classify each family as:

- static/seeded;
- event-driven;
- lightweight replicated;
- full rollback state.

Measure native and browser frame time, rollback work, wire fan-out, queue depth,
nodes, draw calls, and memory. Add StateBundle, packing, batching, relevance,
or a lightweight body class only when this gate identifies the pressure.

## iOS position

iOS is not required for the first Web proof. After the browser transport
decision, add an iOS device client as a separate native-platform checkpoint.
It can initially use ENet; whether it later uses WebRTC depends on the accepted
cross-play architecture. Preserve the earlier lesson that two native Mac
clients are a valid local test, while browser plus another local renderer can
confound CPU/GPU readings.

## Explicit non-goals

- No Unity scene or browser-transport reconstruction.
- No production ENet replacement during the experiment.
- No WSS gameplay path carried forward merely because it is simpler to start.
- No full G2 transport/optimization-stack port without a measured need.
- No adaptive cadence or unmerged adaptive-presentation experiment folded
  into Web bring-up.
- No fullscreen or near-edge Intel Mac presentation testing.

## Future-session start checklist

1. Pull `master` and read `AGENTS.md`, `.ai/CURRENT_PHASE.md`, and this file.
2. Confirm the native suite is green and macai2 UDP 10080 is healthy.
3. Keep the Phase 0 safety policy active before any broad rendered Mac test.
4. Keep Web work isolated from the production checkout and macai2 UDP 10080.
5. Keep Phase 2 work on isolated ports; do not infer macai2 or production
   authorization from the accepted localhost mux proof.
6. Finish and record each phase's acceptance result before starting the next.
7. Update this plan and `.ai/CURRENT_PHASE.md`, then commit and push.

## References

- `MAC_INTEL_FULLSCREEN_FINDINGS.md`
- `~/Projects/g2/WEB_PLAN.md`
- `~/Projects/g2/docs/webrtc-network-verdict.md`
- `~/Projects/g2/docs/webrtc-optimization-plan.md`
- Godot 4.7 Web export documentation:
  <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html>
- Godot 4.7 WebRTC documentation:
  <https://docs.godotengine.org/en/4.7/tutorials/networking/webrtc.html>
- Godot 4.7 high-level multiplayer documentation:
  <https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html>
