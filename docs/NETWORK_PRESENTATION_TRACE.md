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

## First rendered trace result, 2026-09-05

Run `.crash-runs/two-client-20260905-020617/`, runtime `6e47ca6`.
Both clients exited zero around 02:10:10 local; isolated server cleanup completed
and the non-restarting job was removed. Production remained PID 57599/UDP 10080.
No engine/script errors or Intel display precursor appeared in completed logs.
Startup clock-adjustment warnings remained; final applied states were current
with zero rejects in the final windows, not persistent stale-state lockout.

Alpha drove with P cruise while Bravo was the focused observer throughout the
post-warmup trace. The detailed traces cover approximately 02:06:27-02:08:27
and 02:06:30-02:08:30 America/Chicago, not the entire play session. Both have zero
dropped records (15,832 / 16,031 records). Owner reported completion but did not
mark a specific hitch time or give a new smoothness verdict for this run.

The following callback statistics exclude the first 30 seconds of each trace.
Unlike the older interval maxima, these are percentiles over recorded monotonic
callback gaps. They still are not GPU presentation timestamps.

| Measurement | Alpha | Bravo |
| --- | ---: | ---: |
| Recorded frame callbacks | 2,457 | 2,048 |
| Median wall gap | 28.5 ms | 33.0 ms |
| p95 / p99 wall gap | 59.6 / 185.3 ms | 67.4 / 237.5 ms |
| Largest wall gap | 6,134.5 ms | 6,252.3 ms |
| Gaps above 100 ms | 51 | 48 |
| Body samples: interp / extra / hold | 2,400 / 2 / 55 | 1,977 / 11 / 57 |

Around 02:07:47 both clients had six-second callback gaps; their corresponding
Godot deltas were only 69.1 / 65.1 ms. Later telemetry reports captured network
loop interval maxima of 5,883.7 / 6,046.5 ms. Alpha's rollback interval maximum
was 5,716.9 ms; Bravo's was 493.9 ms. These are elapsed durations (including
descheduling), not proof that scripts consumed that much CPU time. Interval
maxima need not refer to the exact same loop; do not add them together.

macOS CPU_Speed_Limit reached 24 at 02:07:36. Process sampling also has a gap
around the event, supporting shared host pressure rather than merely slow packet
delivery. The focused observer stalled too, so unfocused-client throttling alone
does not explain this run. There was no recorded thermal warning; the power
limit does not establish a specific thermal, CPU, GPU or scheduling root cause.
The long event precedes both trace flushes by about 40 seconds, so it was not
caused by final trace serialization. Collection overhead has not been isolated.

Before the severe event, seconds 30-60 of Bravo's trace had 930 body observations,
all interpolating (no hold/extrapolate), despite callback p95 46.6 ms. This is
evidence against constant snapshot starvation as the sole explanation for subtle
stutter, not proof that interpolation is perfect. Mode counts are sample-weighted,
not percentages of wall time. During recovery, effective presentation delay
temporarily exceeded the selected 75 ms (post-30-second maxima 494 / 537 ms).
This makes render-cursor recovery another measured lead, not permission to change
the delay or bypass clock/replay safeguards.

The monitor captured `client-stall-1788592066.sample.txt` in both client folders.
Bravo's sample starts at 02:07:48.105, during recovery rather than the initial
six-second gap; many Godot frames are unsymbolicated. It does not identify a
specific gameplay function as the root cause. Completed server/launcher evidence
is in `.network-runs/trace-6e47ca6-2026-09-05/`.

Next priority: break down expensive network/simulation iterations and their
recovery with targeted profiling, retaining the two-client scenario. Separately
characterize cursor recovery when Godot delta differs from elapsed wall time.
Do not simply increase the interpolation buffer: the focused observer had ample
samples during the earlier observation slice. No runtime tuning was applied
while analyzing this run.

## Later platform gate

The owner requested a macOS-native plus browser playtest later, not now. After
the next focused stutter investigation, qualify native ENet plus browser WebRTC
against the isolated macai2 mux, with matching builds and recorded settings.
Use P cruise in both directions to compare remote motion, then exercise contact,
join/disconnect/rejoin and browser background/resume. Record browser/version,
transport/relay path, frame gaps, state age and errors. No browser/TURN or
production deployment is authorized by this diagnostic change.
