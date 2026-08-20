# Web and platform plan

Status: planned, not yet implemented. Native ENet remains the accepted production baseline.

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

## Phase 3: acceptance matrix

Every row must retain the current native ENet control. Use measured shaping,
not configured-delay assumptions.

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

## Phase 4: production cross-play decision

Only after the isolated WebRTC world passes should the project choose how
browser and native players share production:

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
3. Complete Phase 0 before another broad rendered Mac test.
4. Create the isolated Web worktree; do not develop the Web experiment in the
   production checkout.
5. Finish and record each phase's acceptance result before starting the next.
6. Update this plan and `.ai/CURRENT_PHASE.md`, then commit and push.

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
