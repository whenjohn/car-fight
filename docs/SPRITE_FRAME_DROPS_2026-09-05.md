# 256-attacker frame drops: rendered investigation

Baseline `79615ad`, Godot 4.7.1 Compatibility / Rapier 0.8.39, Intel Iris Plus
MacBookPro16,2, macOS 26.6.2. Profiling only: no gameplay optimization, engine,
renderer, physics-rate, power-setting or networking change is included.

## Findings

1. There is no configured 50-FPS cap: runtime `Engine.max_fps = 0`. VSync is
   enabled; macOS reports refresh rate as 0 (unavailable). No VSync/display
   policy experiment was performed. Workload varies with camera, live sprites
   and shots; the previous interactive log also had faster-than-50 intervals.
2. Ordinary 256-spawn attacker work exceeds the 16.7 ms budget for sustained
   60 FPS. The instrumented stationary phase averaged 7.56 ms of sprite
   simulation, 4.80 ms of sprite presentation scripts and 5.98 ms of viewport
   rendering-related CPU elapsed time. Other engine/game work remains outside
   those scopes. This is not proof of a purely CPU-limited GPU pipeline.
3. Large dips correlate strongly with macOS CPU performance limiting and are
   amplified by simulation catch-up. In the moving-car phase, roughly 22–25 ms
   frames became 53–57 ms as reported CPU speed limits fell from 100 toward
   51/41. Simulation rose from ~1.3–1.5 to ~3.2–3.4 services per frame. Each
   service also became more expensive (~4.7–5.2 → ~7.2–7.4 ms). This is not a
   single expensive route calculation.
4. A* route queries averaged just 0.190 ms/frame in the stationary phase,
   inside decisions. Their CPU cost is not the leading optimization target.
   Planning frequency/queueing might still affect feel; that is a different
   question from the frame bottleneck.

The OS speed-limit reading is a reported performance allowance, not a measured
clock frequency or temperature. It does not establish whether heat, power
delivery, another system policy or background work caused the limit. The
previous owner's dipping run `20260905-000717` ended with speed limit 24 and
scheduler limit 94; the earlier smoother run `20260904-232809` ended at 100/100.
Both monitors reported clean closure. No system process was killed or power
policy changed. A background snapshot during this investigation showed Godot
at ~100% CPU and `duetexpertd` at ~58%, so contention is another limitation.

## Controlled capture

Monitored inset decorated 1280×720 window, offline, 256 spawned survivor
attackers, size 1, batched drawing, debug off, random steering retained.
Car frozen at (0, 1, 0); moving phase drives its position along x=0,
z=65*sin(0.25*t). Car combat is suppressed with the existing fixture isolation
flag; sprite practice shots and run-over deaths remain active. Each phase
resets fixtures, warms for 10 seconds, then records 12 seconds (30 for moving).
All intervals are wall-clock `frame_post_draw` samples. File output happens
between phases, not per sampled frame. Per-frame rows retain nested inclusive
scope times, call counts, physics steps, render counters and other workload
indicators; nested scopes must not be added to their parent.

| Phase | Median / P95 frame, ms | Endpoint alive |
| --- | ---: | ---: |
| Control: detailed script timers off | 22.531 / 29.927 | 224 |
| Stationary attacker, timers on | 24.287 / 29.807 | 224 |
| Moving car | 25.197 / 55.076 | 208 |
| Freeze sprite simulation after warmup | 16.059 / 29.694 | 248 |
| Freeze sprite presentation after warmup | 18.919 / 26.944 | 224 |
| Hide batch drawing, retain scripts/simulation | 24.933 / 30.132 | 225 |
| City with sprite lab disabled | 14.423 / 28.020 | 0 |
| Stationary attacker repeat | 27.016 / 34.007 | 225 |

Hiding batch drawing alone did not materially improve frame time in this run.
Freezing presentation removed about 4.8 ms/frame of script work; disabling
simulation had a larger effect. These are diagnostic interventions, not
shippable changes or perfectly matched speedup measurements: limits changed
over the run, live counts differed, and holding presentation changes what is
drawn. Detailed timers also add overhead: control versus instrumented median
differs ~1.76 ms, with machine load/trajectory variation confounded.

### Stationary attacker CPU scopes

| Scope | Mean per rendered frame, ms |
| --- | ---: |
| Whole sprite simulation | 7.556 |
| Movement (inside simulation) | 2.930 |
| Decisions (inside simulation) | 1.892 |
| Route searches (inside decisions) | 0.190 |
| Spacing (inside decisions) | 0.325 |
| Practice shots/events (inside simulation) | 0.865 |
| Directional animation scripts | 2.095 |
| Batch upload script | 1.619 |
| Lab presentation script | 0.740 |
| Target presentation script | 0.344 |
| Viewport rendering CPU elapsed | 5.977 |

The remainder of simulation includes run-over contact, target position writes,
iteration and instrumentation. Physics is configured at 120 Hz, network/lab
simulation at 60 Hz; they are not interchangeable counters. Stationary frames
averaged 2.92 physics steps and 1.46 lab services. A worst moving frame was
75.28 ms, with four lab services costing 33.56 ms, seven physics steps, 8.11 ms
animation scripts and 13.34 ms rendering CPU elapsed. Its route searches cost
only 0.576 ms, included in the lab total.

### CPU-limit correlation

Time-aligned 3-second moving-phase bins (UTC); limit is the latest preceding
5-second `pmset -g therm` sample, not instantaneous per-frame measurement:

| UTC interval start | Reported speed limit | Mean frame ms | Mean lab services/frame | Lab ms/service |
| --- | ---: | ---: | ---: | ---: |
| 05:14:42 | 100 | 24.01 | 1.44 | 5.17 |
| 05:14:57 | 100 | 21.84 | 1.31 | 4.74 |
| 05:15:00 | 75 | 32.61 | 1.95 | 6.01 |
| 05:15:03 | 75 | 56.75 | 3.38 | 7.43 |
| 05:15:06 | 51 | 52.59 | 3.18 | 7.24 |

A five-second native stack sample started 05:14:49 UTC and can perturb that
interval; the later large-drop bins above are outside it. Most game symbols
are unavailable. There is driver submission work, but the stack sample cannot
separate GPU execution from driver/OS work reliably.

## Limits and next work

Viewport timing was explicitly enabled. Rendering CPU timing is nonzero, but
GPU timing is consistently zero: **GPU duration is unavailable**, not zero
cost. Godot documents these timers as distinct from whole-frame/script time:
[RenderingServer timing API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-cpu).
No renderer migration, risky display test, GPU-utilization attribution or
multiplayer/browser capacity claim follows from this capture.

Next authorized optimization should target remaining sprite presentation work
(hidden native animation scripts and per-instance batch updates), followed by
the larger movement/contact scopes. Do not start with route-cache redesign or
lower authoritative tick rates based on these measurements. Repeat the same
rendered workload while recording CPU limits, and separately investigate the
Mac's sustained performance allowance before promising stable 60 FPS.

Raw evidence: `.crash-runs/frame-cost-1788585220/` (per-frame JSON, configuration,
summary and preserved temporary instrumentation), monitored run
`.crash-runs/20260905-001325/` (client, telemetry, process and CPU-limit samples).
Native sample: `/private/tmp/car-fight-frame-55736.sample.txt`.
Temporary instrumented scripts passed two-pass import before capture. The
bounded run completed all eight phases with monitor state `clean` and no
engine/script errors. Timers and diagnostic interventions were removed;
all seven touched source files match baseline `79615ad` exactly. The temporary
helper and generated UID were removed after preserving the helper as text
alongside `instrumentation.patch` in the evidence directory. Only documentation
is committed, so validation is source-restoration verification and diff checks,
not a repeated gameplay or broad milestone suite.
