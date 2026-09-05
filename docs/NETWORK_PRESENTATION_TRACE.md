# Remote presentation diagnosis

Use this to separate subtle remote-vehicle motion stutter from whole-window
frame stalls. Current human baseline: two macOS clients against macai2 are
playable and back to the owner's previous feel; subtle observed-vehicle stutter
remains. This is not cross-platform or full milestone acceptance.

## Capture

For the next explicitly approved two-client playtest, keep the same isolated
server and legacy/fixed settings and add only the existing trace opt-in:

```bash
CAR_FIGHT_PORT=12780 CAR_FIGHT_NETWORK_HUD=1 \
CAR_FIGHT_PRESENTATION_TRACE_SECONDS=120 ./scripts/play_macai2_two.sh
```

The isolated server must already be running with the matching runtime. This
command does not start or deploy it. Both clients retain the P cruise toggle;
observe the driving client from the other window and mark hitch times. Each
monitor directory receives `presentation-trace.jsonl`. Keep its adjacent
telemetry and process samples for CPU limits, focus and simulation costs.

Tracing starts at the first connected client frame or presentation arrival,
including legacy mode, and flushes after the requested duration or on normal
exit. It stops gathering after completion. Storage retains at most 30,000
records; check header `dropped` before interpreting coverage. This is a record
count cap, not a measured byte/CPU budget. Trace collection and final file or
console serialization have overhead; do not treat flushing as a gameplay hitch.

## Interpretation

Trace version 2 adds these observations without changing interpolation:

- `legacy`: callback arrival time, publication/tick, body/generation and whether
  that body's receiver accepted delivery. Local-player, stale or unavailable
  bodies can legitimately have `delivered=false`; this is not packet loss.
- `frame.wall_delta_msec`: monotonic time between transport process callbacks,
  independent of Godot's supplied `delta_msec`. The first frame and first frame
  after an epoch reset use -1 (unavailable). This is neither GPU presentation
  timing nor CPU execution time.
- `frame.wall_hitch` and `window_focused`: distinguish a wall gap above 50 ms
  from the existing engine-delta `hitch`. These diagnostic thresholds do not
  change adaptive-delay decisions or establish a smoothness acceptance limit.
- `frame.bodies`: existing `interp`, `extra`, or `hold` observations with
  headroom, effective delay and render tick. Each now has its own `at_msec`:
  body callbacks and transport callbacks need not run in the same order/frame.

Compare large wall gaps against process/network-loop costs and CPU limits.
For remote-only stutter during otherwise steady frames, inspect per-body mode,
headroom, render-cursor progression and arrival spacing. Do not label gaps in
legacy global publication numbers as recipient packet loss. The batch-specific
adaptive replay tool is not a legacy arrival-loss estimator. Fixed-mode HUD
adaptive counters remain unavailable; their zero/warmup values are not evidence
of healthy remote playback. This trace also does not measure displayed snap
distance or isolate rendering versus scripts/physics costs.

## Regression evidence, 2026-09-05

The old recorder started only from `_push_batch`; the new focused regression
failed on missing legacy records before the fix. It now covers legacy delivery,
packet-free connected frames, batch compatibility, a real 260 ms thread pause
with a small supplied frame delta, epoch resets, inactive/server guards, timed
and early-exit flushing, the record cap, and stopping collection afterward.

- `scripts/check.sh`: PASS.
- `tests/presentation_trace_test.gd`: PASS.
- `tests/remote_position_transport_test.gd`: PASS.
- `tests/adaptive_presentation_delay_test.gd`: PASS.
- Existing `scripts/network_test.sh clean`, with an ignored Godot wrapper adding
  `--net-telemetry --presentation-trace ... --presentation-trace-seconds 3` to
  each client: PASS, worst authority-probe discrepancy 0.900 units, one guarded
  missing-reference rejection, no engine/script errors. Both traces parsed with
  no dropped records. Alpha: 371 frames, 207 legacy arrivals, 342 body samples;
  Bravo: 381 frames, 44 legacy arrivals, 378 body samples. Startup/loopback-only
  measurements prove collection, not a remote smoothness improvement.

Evidence: `.network-runs/presentation-trace-fix-2026-09-05/` and
`/var/folders/nt/tp7j7qtx2cgc39ftxymn6kfw0000gn/T/car-fight-network.mYXJDt/`.
The first sandboxed pre-fix run also emitted the macOS certificate-store error;
unsandboxed final runs did not. An initial `unshaped` profile invocation was
rejected before launch; this harness calls that profile `clean`.

Authority, input/state schemas, RPC signatures, publication rates, replay,
movement, and presentation delays are unchanged. No new networked objects or
traffic are introduced. The full suite was not rerun for opt-in diagnostics;
previously recorded milestone failures remain open.

## Later platform gate

The owner requested a macOS-native plus browser playtest later, not now. After
the next focused stutter investigation, qualify native ENet plus browser WebRTC
against the isolated macai2 mux, with matching builds and recorded settings.
Use P cruise in both directions to compare remote motion, then exercise contact,
join/disconnect/rejoin and browser background/resume. Record browser/version,
transport/relay path, frame gaps, state age and errors. No browser/TURN or
production deployment is authorized by this diagnostic change.
