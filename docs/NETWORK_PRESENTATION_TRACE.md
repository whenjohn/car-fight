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

## Warmed-up network playback analysis, 2026-09-05

Owner explicitly kept the next investigation on networked remote movement, not
a rendering optimization project. Startup shader work is separate debt. This
analysis reuses `.crash-runs/two-client-20260905-032049/`, the successful packet
capture and isolated server trace described in `NETWORK_DIAGNOSTICS.md`. No
runtime, renderer, networking default, production service or browser change.

### Method and limits

Discard the first 30 seconds after each presentation trace's first connected
frame, then stop at that client's last captured incoming packet. Windows are
approximately 03:21:31.437-03:22:25.715 (Alpha) and
03:21:34.370-03:22:25.715 (Bravo), America/Chicago. This is a deliberately bounded
54.3/51.3-second slice, not a whole-session performance rating.

Use body observation timestamps, not the containing transport record's time:
body samples can be collected on the following transport callback. Break cursor
comparisons at recorded epochs or observed generation changes. Classify a body
interval as stalled if it exceeds 50 ms or overlaps a stage callback gap above
50 ms; separately label intervals within one second after such a gap. Remaining
intervals are called regular, not guaranteed perceptually smooth. Thresholds
are analysis filters, not acceptance criteria. The one-second exclusion alone
does not clear prolonged cursor recovery, so also isolate pairs where both
effective delays are 60-90 ms, both modes are interp, the body is established,
and final snapshot headroom is positive.

Both client traces have zero drops and clock-anchor offset variation below
0.83 ms. Body timestamps have millisecond resolution. Packet classification is
per local endpoint, and packet contents are not matched to RPCs. The server
trace has a dropped tail; only retained, exact recipient/publication/tick matches
are used below. Comparing spacing between matching publications does not require
synchronized client/server clocks and is not a one-way latency measurement.

Local reproducible artifacts are under
`.network-runs/diagnostic-1788596366046/`: `analyze-warm.mjs`,
`warm-analysis.json`, `cursor-characterization.gd` and its `.log`.
Run the Node script from the worktree root. It reads existing evidence only.
An initial slow analysis process was stopped and its redundant per-packet clock
conversion removed; the completed reruns and assertions succeeded. No game
process was running during analysis.

### Lead 1: interpolation timeline pacing

In the packet-covered slice all 3,094/2,926 received remote-body legacy records
were accepted. Local-body deliveries are excluded, not counted as rejects/loss.
Ordinary callback intervals were almost entirely interpolating: 1009/1012 and
1078/1082 observations. This does not exclude occasional starvation, below.

Even the stricter near-target, positive-headroom subset has varying playback
speed. Speed here means render-cursor tick advance divided by nominal tickrate
and elapsed body-callback time, not measured vehicle/world/screen velocity.

| Near-target regular intervals | Alpha | Bravo |
| --- | ---: | ---: |
| Interval count | 846 | 755 |
| Summed interval time | 26.0 s | 23.0 s |
| Cursor speed p05 / median / p95 | 0.817 / 1.002 / 1.265 | 0.822 / 0.999 / 1.285 |
| Steps outside 0.8-1.2 times nominal | 115 | 106 |
| Headroom median | 74.3 ms | 64.2 ms |
| Latest accepted callback age median | 13 ms | 11 ms |

For example, focused Alpha at 03:22:19.326 advanced its cursor by 30.95 ms over
a 21 ms body interval, while retaining 75.1 ms snapshot headroom. Its supplied
engine delta was 31.06 ms. No stage callback gap above 50 ms occurred in the
preceding second. The mismatch is much larger than timestamp quantization.

`PlayerBody._process_remote_position()` passes its supplied process delta into
`RemoteSnapshotInterpolation.advance_cursor()`. That helper advances nominally
by delta * tickrate and adds bounded clock correction. Reconstructing the helper
from the aligned engine delta and recorded desired timeline matches all 1,601
near-target pairs to within 1e-10 ticks. Cursor speed closely follows supplied
delta divided by elapsed time, even with snapshots available. This identifies a
specific network-presentation timing mechanism; it does not measure screen-space
jerk, prove constant authoritative vehicle speed, or prove every visible hitch
has this cause. The trace lacks poses and GPU presentation timestamps.

The headless characterization executes the actual existing helper and sampler
with a full linear snapshot history. Alternating 20/46.667 ms callbacks with
a constant 33.333 ms supplied delta gives cursor speeds 0.715-1.655 times
nominal; every sample is interp. An elapsed-delta control gives 1.000 throughout.
It passed without engine/script errors. This is a controlled reproduction of
the mechanism, not a tested PlayerBody fix or rendered improvement.

Next bounded experiment: characterize and then compare a presentation-only
monotonic elapsed-time cursor behind an opt-in, retaining bounded clock following,
history/generation resets and the existing large-discontinuity policy. Cover
ordinary jitter, a long pause, clock backsteps, rebase, relevance transitions,
and reconnect before any rendered A/B. Do not change simulation time, authority,
rollback, the 75 ms target or shipping defaults to perform that experiment.

### Lead 2: shared delivery gaps and rare starvation

Both local endpoint captures contain the same three incoming-traffic gaps:

| Gap start, local time | Alpha | Bravo |
| --- | ---: | ---: |
| 03:22:00.233 | 133.742 ms | 133.742 ms |
| 03:22:06.236 | 115.170 ms | 115.167 ms |
| 03:22:12.234 | 129.182 ms | 129.172 ms |

The approximately six-second spacing is an observation of three events, not an
established periodic root cause. Regular client callbacks continued. Bravo
briefly extrapolated during these intervals; Alpha also extrapolated and reached
one regular-callback hold around 03:22:12.375. This is a distinct delivery-related
symptom, unlike continuous cursor-speed variation with ample headroom.

Consecutive accepted remote ticks straddling these events were 4247->4248,
4607->4608 and 4967->4968. Matching server publication queueing spans were
approximately 15.6, 20.9 and 13.8 ms for each recipient; corresponding client
callback gaps were 100-141 ms. That argues against those specific state updates
being generated 100+ ms apart. It does not identify where delivery waited:
ENet flushing/server polling after queueing, host scheduling, Tailscale or the
network path remain possible. Client PCAP timestamps are OS observations, not
physical wire timestamps; no server-side packet capture was collected.

Future targeted delivery capture should compare server packet egress and client
ingress alongside these publication identities. Keep captures endpoint-filtered
and bounded, and do not assume host clocks are synchronized. No packet-loss rate
or Tailscale fault has been established. Do not increase the buffer to cover
these events until their source and the added input/visual delay are evaluated.

Validation here is parsed real-trace assertions plus the offline helper
characterization and documentation diff checks. No production code changed, so
the full gameplay suite was not rerun. Earlier milestone and browser acceptance
gaps remain open; no new human smoothness verdict was supplied for this run.

## Opt-in elapsed cursor trial, 2026-09-05

`CAR_FIGHT_REMOTE_CURSOR_CLOCK=elapsed` selects the native trial at startup.
Unset/unknown values retain `engine`; startup prints the selected clock and
presentation trace headers include `cursor_clock`. No live toggle or browser
query parameter is added. Use the existing monitored two-client launcher.

Only fixed/adaptive remote visual cursor advancement uses elapsed microseconds
between eligible callbacks. First use and gaps above 250 ms fall back to the
original engine delta; this deliberately leaves long-pause recovery to the
existing 30-tick discontinuity rebase rather than jumping by seconds of elapsed
time. The cutoff is a conservative experiment boundary, not a tuned optimum.
Disconnect/inactive frames, missing history, relevance transitions and entry
into predictive/proxy presentation clear the measurement. New body instances
start with no timestamp. The existing damped monotonic follower, 75 ms target,
history bound and rebase warmup invalidation remain unchanged.

Authority, input/state/RPC schema, simulation and rollback clocks, collision,
transport cadence, defaults and production remain unchanged. Cost is one stored
timestamp per body and one monotonic read per active opt-in visual callback;
no new replicated objects, history entries or network messages are introduced.

Focused cursor test covers opt-in/default, actual PlayerBody selection, jitter,
duplicate/backward timestamps, long-pause fallback, inactive/history/relevance
resets and rebase. Existing transport, adaptive and trace regressions PASS.
Opt-in clean headless two-client gate PASS: worst probe 0.300 units, zero missing
reference rejects, no engine/script errors. Logs:
`/var/folders/nt/tp7j7qtx2cgc39ftxymn6kfw0000gn/T/car-fight-network.a54ELd/`.
The first new fixture lacked the body's Input child and emitted an engine error;
that fixture was corrected and its rerun was clean. Full milestone/browser gates
are not cleared. Human testing compares against the retained engine-clock run;
it is not yet a matched randomized A/B or a proven perceptual improvement.

## Elapsed trial result, 2026-09-05

Owner's motion verdict: "yes smooth very little stutter". They separately saw
straight-path skid marks under the other vehicle in the observing client, but
none in that vehicle's own client. Neither symptom is inferred from FPS alone.

Both clients exited zero after about 9.3 minutes. Temporary macai2 server stopped,
completed job removed, production PID 57599/UDP 10080 unchanged. Runtime `856e081`;
both trace headers confirm `cursor_clock=elapsed`, fixed 75 ms and legacy 60 Hz.
Client stage/presentation traces completed with zero drops; shortened 90-second
server trace has 24,119 records and zero drops. Client detailed traces cover only
the first two minutes, not the full observation period. No packet capture was
collected, so this run cannot clear the earlier shared packet-delivery gaps.

Evidence: `.crash-runs/two-client-20260905-035412/`, Alpha subrun
`20260905-035412`, Bravo `20260905-035415`. Server and repeatable offline
`compare-cursors.mjs` / `cursor-comparison.json` are under
`.network-runs/elapsed-20260905-0351/`.

### Timing comparison

Compare seconds 30-80 after each first connected presentation frame against
the retained engine-clock run `two-client-20260905-032049`. Use the same
established-body, interp/positive-headroom, effective-delay 60-90 ms filter and
exclude callback gaps above 50 ms plus their following second. Epoch/generation
changes break comparisons. These remain selected regular intervals, not a
whole-session jitter score or wall-time interpolation percentage.

This run had many 1-4 ms body intervals, unlike the prior run's approximately
31 ms median in this subset. Millisecond timestamps are too coarse for reliable
per-step ratios at that scale; the raw per-step p95 was about 1.44-1.45 and must
not be treated as proof of a regression or silently discarded. As a resolution
check, combine consecutive qualifying intervals into non-overlapping blocks of
at least 100 ms, resetting at every exclusion/discontinuity. This retains short
intervals and reduces timestamp quantization without spanning stalled periods.

| Cursor rate over qualifying blocks | Engine Alpha | Engine Bravo | Elapsed Alpha | Elapsed Bravo |
| --- | ---: | ---: | ---: | ---: |
| Blocks | 196 | 182 | 153 | 231 |
| Summed duration | 22.5 s | 21.1 s | 16.6 s | 24.8 s |
| p05 | 0.918 | 0.921 | 0.991 | 0.993 |
| Median | 1.000 | 1.001 | 1.001 | 1.001 |
| p95 | 1.079 | 1.099 | 1.010 | 1.007 |

A second diagnostic restricted to 17-50 ms intervals, the baseline's observed
range, found elapsed cursor p05/p95 about 0.97/1.03 versus engine 0.82/1.28.
It retained only 374/556 elapsed intervals and is not an independent matched
experiment. Focus, driving, callback rates and host conditions differed; almost
none of the trial's selected near-target intervals were continuously focused
over the preceding second. This is evidence that the targeted cursor mechanism
improved, consistent with owner feedback, not quantified GPU/screen-space
smoothness, an FPS gain attributable to the code, or cross-platform acceptance.

### Remaining issues

Alpha/Bravo maximum observed probe errors were 0.469/2.800 units. Bravo's tick
5940 discrepancy was classified `stall`, with `process_ms=572.609`, source age
9 ticks and rollback duration about 19 ms in the cause record. A 1.4-unit sample
followed, then smaller corrections. The process metric is diagnostic elapsed
time, not proof of a specific CPU function or that the clock change caused the
event. The 2.8-unit outlier exceeds the two-unit reference used by network gates;
this trial does not qualify the branch for promotion on smoothness alone.
Final applied state was current with zero rejects in each final interval.
Startup probe misses were retained (60/49 total), with two guarded stale-origin
warnings on Bravo. No client/server SCRIPT ERROR/ERROR or display precursor was
found. CPU speed-limit samples reached 73 later in the long run, unlike the
previous short run's all-100 samples. Long startup/frame stalls remain.

The skid discrepancy is a separate network-presentation contract issue to
characterize. `GroundVehicleHull._animation_inputs()` reads current simulated
rigid velocity/basis and brake state, while the remote hull is positioned from
delayed snapshots. Skid emission also reads reverse, drift assist, oil and boost
transitions. No effect-trigger inputs were traced, so the exact trigger remains
unknown; speed variation alone is not a skid trigger. These FX paths predate the
trial. Do not hide the issue by disabling remote marks or add replicated fields
without first reproducing and measuring the state/time mismatch.

Next: retain the opt-in, investigate the remote FX inputs and stall/correction
outlier, then perform a controlled comparison and later native/browser gate.
No defaults or production services changed during analysis. Validation here was
saved-evidence parsing/assertions and documentation diff checks, not a new live
gate or repeated broad suite.

## Later platform gate

The owner requested a macOS-native plus browser playtest later, not now. After
the next focused stutter investigation, qualify native ENet plus browser WebRTC
against the isolated macai2 mux, with matching builds and recorded settings.
Use P cruise in both directions to compare remote motion, then exercise contact,
join/disconnect/rejoin and browser background/resume. Record browser/version,
transport/relay path, frame gaps, state age and errors. No browser/TURN or
production deployment is authorized by this diagnostic change.
