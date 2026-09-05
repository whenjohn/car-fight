# Two-client clock-fix playtest

## Result

Owner feedback: no desync, but intermittent stutter/jumpiness, perceived worse
than an earlier optimized session. Treat this as **improved synchronization,
not smoothness acceptance**. No settings or gameplay code were changed while
collecting this feedback. Both clients exited zero; the temporary server stopped
and the non-restarting user job was removed. Production PID 57599 remained on
UDP 10080 throughout.

Run: `.crash-runs/two-client-20260905-010252/`, approximately 01:02:58-01:08:52
America/Chicago. Both 1280x720 decorated clients ran on this Intel Mac. The
isolated macai2 mux used UDP 12780 / TCP 12781, runtime `e2a3121` (prior isolated
snapshot plus its sole changed runtime file, `addons/netfox/network-time.gd`).

Configuration: legacy remote poses at 60 Hz, fixed 75 ms remote interpolation,
state bundles off, input/state packing off, local visual smoothing off,
telemetry/HUD on. No artificial impairment. This was the default reference,
not a re-creation of an earlier tuned preset. That earlier session's exact
settings, hardware load and input sequence have not been matched, so this is
not evidence that the optimizations themselves caused a regression.

## Measurements

Telemetry and process statistics below exclude the first 60 seconds of each
client. A frame-interval maximum is the largest Godot delta recorded during a
telemetry reporting interval, not a percentile over every rendered frame.

| Measurement | Alpha | Bravo |
| --- | ---: | ---: |
| Telemetry sample intervals | 284 | 282 |
| Median reported FPS | 32 | 33 |
| p95 interval-maximum frame delta | 70.1 ms | 68.0 ms |
| Intervals with a frame delta above 50 ms | 78 | 76 |
| p95 interval-maximum network loop | 38.7 ms | 35.0 ms |
| p95 interval-maximum rollback loop | 17.1 ms | 19.0 ms |
| Median process CPU, percent of one core | 86.6% | 87.1% |
| Median / p95 reported RTT | 24.5 / 47.6 ms | 24.2 / 57.0 ms |
| Largest post-warmup prediction mismatch | 0.557 units | 1.014 units |

The p95 prediction discrepancy among emitted reports was 0.467 units on both
clients. These reports are authority-probe comparisons against historical
predictions; they are **not measurements of how far a displayed car snapped**.
No post-warmup discrepancy report was tagged stale. Many were tagged unknown,
so frame stalls do not explain every small mismatch.

At 01:04:49 Bravo reported a 1.014-unit mismatch with a 621.6 ms process-time
monitor value, 68.7 ms frame delta and 20.4 ms last rollback loop. Alpha's
0.557-unit mismatch at 01:05:03 coincided with a 130.8 ms process monitor value
and 32.8 ms last rollback loop. The existing classifier marked these as stalls.
The earlier 3.215-unit Bravo mismatch at 01:03:35 falls inside the excluded
first minute and remains a real startup issue, not an erased failure.

macOS `CPU_Speed_Limit` fell from 100 to 56 at 01:04:52, 34 at 01:04:58 and
24 at 01:05:04; it then fluctuated below 100 for the rest of the run. This is a
reported power-management limit, not measured clock frequency or proof of a
specific thermal root cause. It overlaps slow processing and supports local
performance pressure as a contributor. It does not invalidate the owner's
two-client workflow or identify which subsystem consumes the time.

The newest received state age stayed small rather than running hundreds of
ticks ahead: after excluding the first 60 NETAPP reports, p95 was zero and
maxima were 5/4 ticks. These are report-window extrema with a clamped age value,
not a per-packet latency distribution. Final applied state was current and
final report windows had zero rejected states. No engine/script errors or
`Invalid actual_host_time` display precursors occurred in completed client or
server logs. Startup missing-reference/clock-adjustment and stale-origin
warnings remain visible; monitor `clean` means clean shutdown, not smooth play.

## Interpretation

1. The previous persistent clock desync did not recur in this session, matching
   the owner's observation. Longer/platform acceptance is still open.
2. Local frame pacing and expensive simulation/rollback intervals are the
   strongest current lead for intermittent stutters. CPU limits reinforce that
   lead, but do not isolate rendering versus scripts, physics, or network work.
3. Startup stack samples show OpenGL shader compilation. They explain a startup
   stall candidate, not the later intermittent jumps: no steady-state stack
   capture was taken at an owner-marked jump.
4. RTT/jitter spikes could also affect remote interpolation. The current fixed
   legacy path does not populate the adaptive batch hold/extrapolation counters;
   zero values and `warmup` there are not proof that remote interpolation is
   healthy or absent. Remote playback needs its own trace before tuning delay.

There is an instrumentation limitation: frame records use Godot's `_process`
delta, while process-time monitors and loop maxima have different sampling
semantics. Do not add those numbers or claim the 75 ms observed delta maximum
bounds actual wall-clock stalls. A monotonic per-frame gap and a targeted CPU
profile would make the next diagnosis more precise.

Next bounded comparison: retain two clients and the remote server; first match
the earlier good session's actual flags, then compare the same driving/contact
route while recording host speed limits and runtime settings. Profile a marked
steady-state hitch with per-stage/monotonic timing. Change one factor at a time;
do not enable the entire experimental stack, widen history, or increase smoothing
merely to conceal the symptom. No further runtime edit is justified by these
logs alone.

## Evidence

Completed raw client logs, process samples, telemetry and startup stacks remain
in the run directory above. `.network-runs/clock-retest-2026-09-05/` contains
`server.log`, `stutter-server-snapshot.log`, `stutter-capture/` (bounded live
snapshot), and `stutter-analysis.json` (derived final summary). The live snapshot
precedes the final shutdown and must not be mistaken for complete-run evidence.
Full milestone clearance remains blocked by the previously recorded default
network and vehicle-respawn harness failures; this human run does not clear them.
