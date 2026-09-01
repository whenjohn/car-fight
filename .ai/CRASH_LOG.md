# WindowServer crash log

## Safety status

The rendered car-fight client has two captured macOS/Intel graphics failure
classes: the older fullscreen/WindowServer watchdog and a current Forward+
Intel lighting-submission hang that makes Godot abort after device loss.
Do not automatically run `./scripts/play.sh`, open the project in a rendered
editor, or perform a rendered soak. Headless tests are appropriate. Every
rendered attempt requires the user's explicit approval and must use the ordinary
window monitored launcher so lighting phases and the kernel boundary are saved.
The kernel has successfully restarted the GPU after the recent Forward+ hangs;
do not prescribe a reboot as the routine diagnostic or recovery step.

## 2026-09-01 Forward+ lighting device loss

### Single directional-shadow probe prepared, not rendered

- Worktree `/Users/johnnguyen/Projects/car-fight-intel-single-shadow`, branch
  `codex/intel-single-shadow-test`, starts from accepted baseline `f672aec`.
- The Intel sunlit preset stages one orthogonal directional shadow map after
  the first presented frame and restores city meshes as casters. It does not
  enable SSAO or the four-cascade mode implicated by the 01:28 incident. The
  player-following spotlight is hidden for this preset so the probe isolates a
  single shadow source; the other lighting presets remain available.
- Clean import, focused lighting/city tests, forced-Intel headless presentation,
  and the complete permission-correct suite pass (`ALL_TESTS PASS`). No
  rendered launch has occurred, so this is not yet evidence that the Intel GPU
  accepts the new submission. The next attempt must be an explicitly approved
  ordinary-window monitored run.

### 02:13 simplified retained fix is clean

- Run `.crash-runs/20260901-021324`, cleanup commit `376c26b`, PID 90320.
- The ordinary complete Low Poly City build reported
  `mode=filtered_spotlight ssao=off cascades=off`, then reached both
  `RENDER_LIGHTING_READY` and `OFFLINE_READY`. It continued through server tick
  480 and the monitor reported `clean`; there was no Metal timeout, Vulkan
  device loss, GPU reset, or crash report.
- This run verifies the post-cleanup implementation without the abandoned cache,
  compiler telemetry, scene batching, settle delays, PCSS, prewarm staging, or
  blob-shadow fallback. The retained Intel behavior is the normal full-city
  build followed by a hidden-spotlight frame, a light-only frame, and the
  filtered spotlight-shadow frame. SSAO and four-cascade directional shadows
  remain disabled only on the affected Intel path.

### 01:59 corrected spotlight staging is clean

- Run `.crash-runs/20260901-015950`, commit `709013b`, PID 89277.
- `base`, `spotlight_light`, and `spotlight_shadows` each presented
  successfully. Directional cascades and SSAO were explicitly skipped on Intel.
- The diagnostic startup then completed all shader, vehicle, prop, and 51 city batches and
  emitted `OFFLINE_READY`. The monitor reported `clean`; no Vulkan device loss
  or Metal timeout appears in the evidence.

### 01:52 spotlight attempt did not reach its shadow toggle

- Run `.crash-runs/20260901-015158`, commit `4a40704`, PID 88441, exited 134.
- The log selected `mode=soft_spotlight` but recorded no completed `base`
  startup phase. The Metal timeout arrived around ten seconds after launch,
  with the same Vulkan device-lost abort in the chained frame/swap path.
- The spotlight shadow map was disabled during base, but the spotlight itself
  was visible and configured with PCSS `light_size=1.25`. This run therefore
  does not show that the positional shadow toggle failed. The corrected probe
  hides the spotlight during base, presents light-only on its own frame, then
  enables a normally filtered shadow on the following frame. PCSS is removed.

### 01:28 incident isolates cascaded shadows

- Incident `F302FC55-105C-45CD-BFC6-24A021C422F6`, PID 86070, run
  `.crash-runs/20260901-012757`, commit `bc60072`.
- The new startup telemetry completed `base` at 01:28:02 with 19 compilations:
  11 surface, 7 specialization, 1 canvas, and zero mesh/draw. Startup then
  enabled the four-cascade directional shadow before awaiting its next frame.
  That frame never completed; Metal reported the command-buffer timeout at
  01:28:07.
- Every Godot worker thread was idle in `WorkerThreadPool::_thread_function` at
  capture. The main thread was in `execute_chained_cmds` / `_execute_frame` /
  `swap_buffers`, unlike the prior capture with active pipeline-creation and
  transfer workers. This rules out ongoing compilation concurrency as the
  immediate trigger for this incident and isolates the realtime directional
  shadow submission.
- The incident proves this four-cascade directional submission is unsafe; it
  does not prove every shadow type is unsafe. SSAO remains prohibited. After the
  user confirmed shadowless run `.crash-runs/20260901-014020` stayed up, they
  clarified that the earlier player-following spotlight shadow worked on this
  machine. The successful configuration restores only that positional shadow
  after the base frame and keeps city buildings out of its caster set. Other
  adapters retain cascades and low SSAO.

- Prior incident: 2026-09-01 01:07:23 -0500, Godot incident
  `8BC7CC15-C22E-4A57-A609-BE718EA5400D`, PID 84825, Godot 4.6.3 x86_64.
- Evidence bundle: `.crash-runs/20260901-010710`, project commit `626ee8b`,
  ordinary 1280 x 720 window, Forward+ Vulkan/MoltenVK on Intel Iris Plus.
- The main thread received `VK_TIMEOUT` /
  `kIOAccelCommandBufferCallbackErrorTimeout`, reported device loss in
  `command_queue_execute_and_present`, and Godot deliberately called `abort()`.
  The SIGABRT is therefore the consequence, not the initiating fault.
- Worker threads 3 and 6 were concurrently in Forward+ pipeline creation:
  `SceneShaderForwardClustered::ShaderData::_create_pipeline` through
  `RenderingDevice::render_pipeline_create` and `update_pipeline_cache`.
- The dedicated cold 4.6 cache grew to 10,461,997 bytes by the crash. Process
  sampling peaked near 534 MB RSS; this does not support ordinary 16 GB system
  memory exhaustion. The report's repeated kernel VM allocation triage is most
  consistent with graphics/kernel allocation pressure at the hang boundary.
- Read-only unified logs identify Intel RCS hardware context 733 busy in a batch
  buffer, followed by `GPURestartSignaled`, queued/begin/end type-2 recovery on
  multiple channels. macOS recovered the GPU without a reboot, after which
  Godot exited because its rendering device was already lost.
- Earlier quality-2 and valid untouched-4.6 controls produced the same class on
  contexts 715 and 726. Quality 2 was an initial trigger, but the latest isolated
  quality-1 cold-cache incident proves shadow softness is not the only trigger.
- Diagnostic scene insertion and pipeline counters helped expose the lighting
  boundary but were not part of the final fix. They were removed after the
  clean 01:59 run. The retained runtime order is ordinary complete-scene build,
  one hidden-spotlight frame, one light-only frame, then filtered spotlight
  shadows; Intel SSAO and directional cascades remain disabled.

## Confirmed incidents

### 2026-08-11 03:10:05 -0500

- WindowServer report: `/Library/Logs/DiagnosticReports/WindowServer-2026-08-11-031005.ips`
- Stackshot: `/Library/Logs/DiagnosticReports/WindowServer_2026-08-11-031015_JBook2.userspace_watchdog_timeout.spin`
- Approximate project revision: `d0c2e51` (`Add collision escape steering`, committed at 03:08:23)
- Two Godot 4.7 processes were present, matching the headless server plus rendered client launched by the project play script.
- Headless Godot: PID 32116, about 70 seconds since fork, 50.05 MB footprint, 0.987 seconds CPU.
- Rendered Godot: PID 32122, about 69 seconds since fork, 316.99 MB footprint, 1.024 seconds CPU.
- The failure predates boost blur, cloak, shield, drone, arena expansion, brake-skid presentation, and the later moving spotlight.
- Shared render features already present were Godot 4.7, native OpenGL Compatibility, the grid shader, an orthographic camera, and a shadow-enabled directional light.

### 2026-08-13 03:24:04 -0500

- Incident ID: `8C7AF0DD-CE75-418B-9CC8-827049C68E1F`
- WindowServer report: `/Library/Logs/DiagnosticReports/WindowServer-2026-08-13-032404.ips`
- Stackshot: `/Library/Logs/DiagnosticReports/WindowServer_2026-08-13-032411_JBook2.userspace_watchdog_timeout.spin`
- Project revision: `d69aaf9` (`Exaggerate brake skid and chassis dive`)
- Headless Godot: PID 13663, 69 seconds since fork, 53.27 MB footprint, 2.150 seconds CPU.
- Rendered Godot: PID 13667, 68 seconds since fork, 342.52 MB falling to 322.52 MB, 1.979 seconds CPU.
- The rendered client resigned active at 03:23:35.733. At 03:24:04.564 it recorded the WindowServer event port dying. There was no preceding Godot rendering exception in the macOS unified log; subsequent Godot XPC errors were consequences of WindowServer termination.

### 2026-08-13 13:15:37 -0500

- Incident ID: `B70D5564-ABA3-43FB-9BCB-48134CBE61C4`
- WindowServer report: `/Library/Logs/DiagnosticReports/WindowServer-2026-08-13-131537.ips`
- Stackshot: `/Library/Logs/DiagnosticReports/WindowServer_2026-08-13-131545_JBook2.userspace_watchdog_timeout.spin`
- Project revision: `9f219c5` (`Add gated driving test course`), launched through the project play script for the first live driving-course test.
- Headless Godot: PID 19087, 156 seconds since fork, 54.93 MB footprint, 1.594 seconds sampled CPU time in the stackshot.
- Rendered Godot: PID 19091, 156 seconds since fork, 378.26 MB footprint, 3.257 seconds sampled CPU time in the stackshot.
- The rendered client's main-thread samples include native OpenGL `GLEngine`, `AppleIntelICLGraphicsGLDriver`, `IOAccelerator`, and `IOAcceleratorFamily2` frames. This confirms that it was actively using the implicated graphics stack but does not identify a particular game draw call.
- The report again says the built-in DisplayID `0x4280f40` was not ready, with framebuffer registry ID 4294968498 and on-glass surfaces active/waiting. It recorded `displayState: OFF` and heavy thermal pressure.
- At 13:15:37.922, immediately after the report capture time, `AppleIntelICLLPGraphicsFramebuffer` logged `FB0: VBlank Timeout Timer called in 51ms`. At 13:15:38.036, the rendered Godot client received notification that the WindowServer event port had died. A replacement WindowServer then repeatedly read/set and mode-set the built-in display while recovering the login session.
- There is no corresponding new Godot crash report. The latest user-level Godot reports predate this incident, again indicating that WindowServer/display service failed around a still-running client rather than Godot producing an ordinary application crash.

### 2026-08-13 14:04:37 -0500 — controlled fullscreen reproduction

- Incident ID: `BF2E0698-7D52-4976-B09F-A70E32E1D8DC`
- Captured run: `.crash-runs/20260813-140125`
- Copied WindowServer report: `.crash-runs/20260813-140125/reports/WindowServer-2026-08-13-140437.ips`
- Copied stackshot: `.crash-runs/20260813-140125/reports/WindowServer_2026-08-13-140446_JBook2.userspace_watchdog_timeout.spin`
- Project revision: `ba96b6d` (`Record clean monitored windowed baseline`), with a clean worktree. This was the explicitly approved one-variable fullscreen comparison after the monitored windowed baseline; both used native `opengl3`, the same build, same server/client arrangement, and the same game content.
- The run began at 14:01:25 and telemetry confirmed actual fullscreen mode (`window_mode=3`) at 2880 x 1800 for the entire run. WindowServer failed about 192 seconds after the monitor started. The stackshot measured 182 seconds since fork for the headless server and 181 seconds for the fullscreen client.
- Headless Godot: PID 25655, 54.68 MB footprint, 1.932 seconds sampled CPU time.
- Rendered Godot: PID 25658, 382.16 MB footprint, 3.071 seconds sampled CPU time.
- At 14:01:33.595, about four seconds after the fullscreen client began telemetry, WindowServer started reporting `Invalid actual_host_time` for DisplayID `0x4280f40`. The monitor captured 6,811 such errors—approximately one per refresh—from 14:01:33.595 through 14:03:46.299. The prior 423-second windowed run captured zero instances with the same log predicate.
- At 14:04:37.851 the Intel framebuffer logged `FB0: VBlank Timeout Timer called in 51ms`. The watchdog report again says DisplayID `0x4280f40` was not ready and identifies framebuffer registry ID 4294968498. Recovery then attempted four 2560 x 1600 to 2880 x 1800 display mode sets, and at 14:04:40.397 Godot received notification that the WindowServer event port had died.
- Game telemetry remained regular and memory remained stable through the watchdog boundary. The fullscreen client and headless server both survived the WindowServer replacement; the client continued writing telemetry through 14:08:53 without a multi-second runtime stall and was then stopped by exact PID along with the server. No Godot crash report was produced.
- The system report recorded heavy thermal pressure, but the pre-failure process sampler reported no macOS thermal or performance warning. Godot memory and CPU use did not run away before the failure.
- This controlled A/B result strongly isolates fullscreen presentation on the native Intel OpenGL/display path. It does not identify a game draw call and does not prove whether Godot, macOS 26.6.1, or the Intel driver owns the underlying defect, but it makes current gameplay logic, course content, and ordinary process memory/CPU exhaustion implausible causes.

### 2026-08-14 01:37:06 -0500 — minimal Stage 10 reproduction in an affected display session

- Incident ID: `AFEF1DCD-F77C-4EE2-BB15-CD64A924D9D2`
- Captured run: `/private/tmp/car-fight-stage10-recheck/.crash-runs/20260814-013607`
- WindowServer report: `/Library/Logs/DiagnosticReports/WindowServer-2026-08-14-013706.ips`
- Stackshot: `/Library/Logs/DiagnosticReports/WindowServer_2026-08-14-013712_JBook2.userspace_watchdog_timeout.spin`
- Isolation revision: `7131f14`, the exact Stage 10 build that had completed a clean 26-second fullscreen probe earlier in the same WindowServer session. This minimal project has one imported Jeep, simple lighting/shadows, one active Rapier body, and initialized netfox autoloads, but no ENet peers, player input, spawning, replication, combat, course, or car-fight gameplay.
- macOS power history confirms sleep at 01:28:43 and wake from deep idle at 01:32:29 due to lid-open/user activity. About four minutes after that wake, the same build immediately produced 623 `Invalid actual_host_time` errors for DisplayID `0x4280f40`, from 01:36:11.280 through 01:36:21.904.
- Client telemetry remained regular at 115-117 FPS through 01:36:35. Both exact Godot PIDs, 50302 and 50305, were stopped before the watchdog report and neither appears in the 01:37:12 stackshot.
- At 01:37:06.377 the Intel framebuffer logged `FB0: VBlank Timeout Timer called in 51ms`. The watchdog report says the same display and framebuffer were not ready with active/waiting surface transactions; WindowServer PID 27448 was replaced by PID 50563.
- The report recorded `displayState: OFF` and nominal thermal pressure. This incident rules out heat as a required condition and shows that WindowServer can cross the watchdog boundary after the triggering fullscreen client has already exited.
- A Stage 11 probe about one minute after the confirmed wake had shown the same precursor without player input. Stage 10 then proved that ENet/time synchronization is not required once the display session is affected. A later clean-order Stage 10-first probe, documented below, removed the remaining Stage 11 ordering concern and reproduced without ENet peers or traffic.

## Shared system signature

- Hardware: MacBookPro16,2, Intel Iris Plus Graphics, device `0x8a53`, up to 1536 MB.
- OS: macOS 26.6.1, build 25G76.
- Report type: WindowServer bug type 409, watchdog termination.
- Watchdog reason: `monitoring timed out for service` and WindowServer was not alive.
- Same affected display in all five reports: DisplayID `0x4280f40` / decimal 69734208.
- Same framebuffer registry ID in all five reports: 4294968498.
- IOKit associates framebuffer 4294968498 with `AppleBacklightDisplay`; it is the MacBook's built-in panel, not an external display.
- WindowServer reported the display as not ready, with on-glass surfaces active/waiting.
- All five reports recorded `displayState: OFF`.
- All five failures followed a fullscreen game session. The controlled comparison at `ba96b6d` kept build, renderer, scene, and launch arrangement constant: windowed remained clean for 423 seconds, while fullscreen immediately produced thousands of invalid display timestamps and reproduced the watchdog after 192 seconds. In the fifth incident both Godot processes had exited before the delayed WindowServer watchdog. No known windowed play session has produced this failure.
- Thermal pressure varied across the incidents: moderate on August 11, nominal at 03:24 on August 13, and heavy for both later August 13 reports. Heat may have contributed to the later events, but it is not required by the shared failure signature.
- Unified logs around the failures show `AppleIntelICLLPGraphicsFramebuffer` repeatedly reading and setting the built-in display mode. The third, fourth, and fifth incidents additionally captured an explicit framebuffer VBlank timeout at the failure boundary.
- Neither Godot process showed runaway CPU use or an extreme memory footprint.

## Current assessment

The game cannot directly terminate WindowServer, and the reports do not identify a specific GDScript or draw call. However, five nearly identical watchdog failures with the same fullscreen presentation path, framebuffer, and built-in display state make coincidence unlikely. Time to failure varies, so a fixed countdown is not part of the shared signature.

Treat fullscreen native-OpenGL presentation on this Intel Mac as the reproducible trigger condition for an operating-system/graphics-driver deadlock. The evidence does not yet distinguish a Godot fullscreen integration defect from a macOS 26.6.1 or Intel driver defect, and Godot 4.7.1 reproduces the exact early display-timestamp signature. Recent driving logic and visual effects are not plausible common causes because the first incident occurred before they existed, and the game loop remained alive through the controlled failure.

The user also recalls the same failure from the project's earliest prototype period. Combined with the first preserved incident predating the later driving, course, combat, and presentation work, this rules those additions out as the origin of the problem. The staged reconstruction strengthens the state-dependent diagnosis: stages 0-10 were initially clean, then the unchanged Stage 10 reproduced both after Stage 11 and, later, before Stage 11 in a restarted WindowServer session. Active ENet, network traffic, and input are therefore not required. Power history confirms a wake before one failing pair, but it is not a universal prerequisite: the 03:24 incident has no immediate preceding wake, and the 14:04 incident occurred without another sleep after the 13:15 WindowServer restart. Investigation should concentrate on intermittent/stateful fullscreen presentation through the Intel framebuffer rather than assuming a particular game building block, network event, or wake event.

### Later non-incident observation

After commit `85c7285`, an explicitly approved rendered OpenGL play-test reached at least tick 11460 (roughly 191 seconds at 60 Hz) and was then stopped normally to make the next gameplay change. WindowServer did not fail during that run. This does not clear the rendering path—the two earlier incidents remain unexplained—but it shows the failure is not guaranteed at 69 seconds on every launch.

After commit `2fe2cc8`, another explicitly approved rendered test reached at least tick 7980 (roughly 133 seconds at 60 Hz) and was stopped normally for drift tuning, again without a WindowServer failure.

After commit `52891e3`, a third approved rendered test also reached at least tick 7980 (roughly 133 seconds at 60 Hz) and was stopped normally for the next drift-assist revision, without a WindowServer failure.

After commit `e9ea5d9`, a fourth approved rendered test reached at least tick 35040 (roughly 584 seconds at 60 Hz) and was stopped normally to improve drift-assist activation feedback, without a WindowServer failure.

After commit `20005eb`, a fifth approved rendered test reached at least tick 3240 (roughly 54 seconds at 60 Hz) and was stopped normally after identifying that braking speed loss canceled drift-assist arming, without a WindowServer failure.

After commit `48c77be`, a sixth approved rendered test reached at least tick 31020 (roughly 517 seconds at 60 Hz) and was stopped normally to separate ordinary close-cursor turning from successful drift cornering, without a WindowServer failure.

After commit `ef69f73`, a seventh approved rendered test reached at least tick 8220 (roughly 137 seconds at 60 Hz) and was stopped normally because ordinary close-cursor powerslides still turned too tightly, without a WindowServer failure.

After commit `eac8bce`, an eighth approved rendered test reached at least tick 23700 (roughly 395 seconds at 60 Hz) and was stopped normally to add a max-speed cursor reference, without a WindowServer failure.

After commit `e349f88`, a ninth approved rendered test reached at least tick 16260 (roughly 271 seconds at 60 Hz) and was stopped normally to build the separate driving course, without a WindowServer failure.

After commit `db43dec`, the first controlled monitored windowed test ran for 423 seconds (about 7 minutes) and closed normally. Telemetry confirmed `windowed` for the entire run with no mode transitions; the player used both the arena and driving course, reached 27.98 units/s, and latched drift assist. WindowServer remained PID 19110, no telemetry gap reached the four-second stall threshold, and the filtered log contained no VBlank timeout, GPU reset, display-not-ready, invalid-display-time, display-mode-set, or WindowServer event-port-death message. Repeated thermal snapshots reported no thermal or performance warning and full CPU scheduler/speed limits. This is meaningful evidence for the fullscreen-only hypothesis, but one successful windowed run does not prove windowed mode can never trigger the issue.

After commit `ee562b4`, a second monitored windowed course test ran for 534 seconds (about 9 minutes) before the wrapper was stopped normally after the user finished. Telemetry stayed windowed, covered both maps, reached 17.99 units/s, and latched drift assist. The filtered log contained no invalid-display-time, VBlank-timeout, WindowServer-event-port-death, or actual GPU-reset event. Together, the two monitored windowed sessions total nearly 16 minutes without the fullscreen failure signature.

On 2026-08-13, the active engine at `/Applications/Godot47.app` was updated from 4.7 stable (`5b4e0cb0f`) to the official 4.7.1 maintenance release (`a13da4feb`). The downloaded universal macOS archive matched its published SHA-256 and passed strict code-signature verification. The previous engine remains at `/Applications/Godot470.app` for rollback. The complete headless project suite and the seven-second crash-monitor fault test pass under 4.7.1. No rendered fullscreen test has yet been performed with 4.7.1, so the update must not be treated as a fullscreen-crash fix.

The first monitored Godot 4.7.1 windowed baseline ran for 587 seconds (9 minutes 47 seconds) at commit `0a9171c`. Telemetry remained windowed, covered both maps, reached 27.98 units/s, latched drift assist, and had no gap longer than 2.46 seconds. The filtered display log contained zero invalid-display-time, VBlank-timeout, GPU-reset, display-not-ready, or WindowServer-event-port-death events. Both Godot processes stopped with the monitor after the user finished. This establishes normal windowed operation under 4.7.1 but does not test or clear fullscreen.

At commit `03672ea`, an explicitly approved monitored fullscreen comparison tested Godot 4.7.1 with the same native `opengl3` path. The run was stopped proactively after 20 seconds rather than waiting for another system crash. Fullscreen telemetry began at 17:19:58; from 17:20:01.062 through 17:20:18.585, WindowServer emitted 736 `Invalid actual_host_time` errors for the same DisplayID `0x4280f40`. There were no corresponding VBlank timeout, GPU reset, or event-port-death events because the client was stopped as soon as the known precursor was confirmed. WindowServer remained PID 27448 and both exact Godot processes ended. Godot 4.7.1 therefore does not fix the native-OpenGL fullscreen defect on this machine.

Later at commit `03672ea`, an explicitly approved one-variable fullscreen comparison used Godot 4.7.1's `opengl3_angle` driver. Runtime output confirmed OpenGL ES 3.0 through ANGLE 2.1.1 and the ANGLE Metal Renderer on the Intel Iris Plus GPU; telemetry confirmed true 2880 x 1800 fullscreen. WindowServer emitted the first `Invalid actual_host_time` for the same DisplayID `0x4280f40` in the same second telemetry began and recorded 235 instances from 17:36:22.419 through 17:36:40.408. The run was stopped after about 18 seconds, before any VBlank timeout, GPU reset, event-port death, or watchdog. WindowServer stayed alive and both exact Godot processes stopped. ANGLE therefore does not remove the known fullscreen failure precursor and should not be adopted as a macOS workaround for this machine.

On 2026-08-14, the enhanced monitor ran isolation Stage 10 first in WindowServer PID 50563, before Stage 11 or any other rendered Godot probe in that WindowServer session. The minimal build had netfox autoloads but no ENet peers, traffic, player input, spawning, or replication. True native-OpenGL fullscreen telemetry began at 02:07:28; WindowServer emitted 853 `Invalid actual_host_time` errors from 02:07:30.044 through 02:07:47.439. This cleanly establishes that active networking and input are not required to initiate the precursor. Both Godot processes were stopped and WindowServer was watched for 120 seconds; it remained PID 50563 with no VBlank timeout, display-not-ready event, GPU reset, event-port death, or new crash report. Synchronized snapshots found no thermal warning, memory exhaustion, or GPU recovery (`recoveryCount=0`). The Godot sample showed ordinary Intel OpenGL/IOAccelerator rendering work; a routine `CheckOOM` frame is not evidence of an out-of-memory condition. Evidence: `/private/tmp/car-fight-stage10-recheck/.crash-runs/20260814-020722`.

Relevant project settings across the five incidents:

- `renderer/rendering_method="gl_compatibility"`
- 1280 x 720 viewport/window override
- Godot 4.7 x86_64 official application (`5b4e0cb0f`; all five preserved incidents used 4.7.0, while 4.7.1 separately reproduced the precursor)

Godot 4.7 reports these available macOS rendering drivers on this machine: `vulkan`, `opengl3`, `opengl3_angle`, and `dummy`. Native Metal is not implemented for Intel Macs; RenderingDevice uses Vulkan through MoltenVK there. ANGLE is also available as an alternate Compatibility driver.

## Implemented monitoring for future rendered launches

`./scripts/play_monitored.sh` now creates a timestamped evidence bundle under the ignored `.crash-runs/` directory. It explicitly starts windowed unless `--fullscreen` is requested and preserves enough evidence to align game activity with a future display failure without trying to intentionally cause one:

1. Create a timestamped run directory and record the commit, exact launch command, start time, server/client PIDs, Godot version, renderer/driver, display inventory, and current thermal state.
2. Preserve separate server and client stdout/stderr logs alongside the timestamped, immediately flushed telemetry instead of relying on the interactive terminal buffer.
3. Sample each Godot process's CPU, resident memory, thread count, and state at a short interval. Also sample WindowServer and basic system/thermal pressure without requiring an invasive profiler for normal play.
4. Continuously stream a narrowly filtered unified log for `Godot`, `WindowServer`, `watchdogd`, `powerd`, `AppleIntelICLLPGraphicsFramebuffer`, and GPU/IOAccelerator timeout/reset messages.
5. On normal exit, mark the run clean and retain the bundle. After a login-session recovery, the collection command copies the newest WindowServer `.ips`/`.spin` metadata and the matching pre-crash logs into that run directory.
6. If client telemetry stops advancing for four seconds, take a short external Godot process sample so a main-thread stall can be captured before cleanup.
7. `--deep-capture` preserves recent sleep/wake history plus synchronized display, framebuffer, accelerator, memory, process-thread, and Godot stack snapshots at start, at the first invalid display timestamp, at client exit, and after observation. A fullscreen deep run defaults to watching WindowServer for 90 seconds after Godot exits; this can be overridden with `--post-exit-seconds`.
8. Only after this capture path works headlessly should another rendered run be requested, and it still requires the user's explicit approval.

`./scripts/collect_crash_run.sh` attaches WindowServer/Godot `.ips` and `.spin` files whose embedded capture time follows the run start, recovers the matching historical unified log, snapshots the recovered display state, writes short pre-failure tails, records whether either exact Godot PID survived, and classifies a changed WindowServer PID as `windowserver-restarted`. Embedded-time filtering matters because macOS can later add submission metadata to an old report and change its file modification time without creating a new incident. The launcher also honors the recovered WindowServer PID when its own final process lookup is unavailable after session recovery. The normal and deep paths pass the safe headless simulated-stall test; the complete project suite passes.

`./scripts/crash_monitor_test.sh` is the safe fault-injection test. It uses `--fake-stall`, which is rejected unless the client is headless, pauses only Godot's main thread for seven seconds, then verifies that telemetry resumes and that the external watcher captured a real process stack. Do not test the monitor by exhausting GPU buffers, repeatedly changing display modes, killing WindowServer, or manufacturing thermal pressure; those approaches risk reproducing the system disruption and make the evidence harder to interpret.

The native-OpenGL windowed/fullscreen comparison is complete: windowed ran cleanly for 423 seconds and fullscreen reproduced the failure after 192 seconds. The follow-up ANGLE fullscreen comparison produced the same invalid-display-timestamp precursor immediately, so changing the Compatibility backend does not make fullscreen safe. Use windowed mode for ordinary development on this machine. Do not repeat either fullscreen comparison merely to reconfirm the result, and do not deliberately run until failure.

## Evidence to collect after another spontaneous crash

Do not intentionally reproduce the crash solely to gather these items. After reboot/login:

1. Preserve the newest WindowServer `.ips` and matching `.spin` paths from `/Library/Logs/DiagnosticReports/`.
2. Record the exact wall-clock crash time, what was visible, whether the game had focus, whether the display dimmed/turned off, and approximately how long the client had been open.
3. Record the current commit with `git rev-parse HEAD` and whether the client was launched by `./scripts/play.sh`, the editor, or another command.
4. In the `.spin`, find all Godot process blocks and record PID, time since fork, footprint, CPU time, and main-thread stack.
5. Compare the report's DisplayID, framebuffer registry ID, `displayState`, thermal pressure, watchdog reason, and surface transaction state with the five incidents above.
6. Inspect the read-only unified log for roughly 90 seconds before and 30 seconds after the incident. Focus on `Godot`, `WindowServer`, `powerd`, `watchdogd`, and `AppleIntelICLLPGraphicsFramebuffer`. Preserve any GPU reset, display sleep/wake, mode-set, swap/present, or WindowServer-port-death events.
7. Check whether a new Godot crash report exists. Absence matters: in the first four incidents WindowServer was killed while Godot remained a client of the failed display service; in the fifth, both Godot processes had already exited and were absent from the watchdog stackshot.

Suggested read-only commands, with timestamps replaced by the new incident window:

```sh
ls -lt /Library/Logs/DiagnosticReports/WindowServer* | head
git rev-parse HEAD
/usr/bin/log show --style compact --start 'YYYY-MM-DD HH:MM:SS' --end 'YYYY-MM-DD HH:MM:SS' --predicate '(process == "WindowServer") OR (process == "Godot") OR (process == "powerd") OR (process == "watchdogd") OR (senderImagePath CONTAINS[c] "Intel")'
```

## Possible isolation plan, not yet authorized or applied

If the user later chooses to investigate experimentally, use one variable at a time and run headless tests before any rendered test:

1. Keep ordinary development tests windowed through `play_monitored.sh`; do not enter fullscreen. This mode completed the controlled baseline without the display-error signature.
2. Do not repeat native-OpenGL fullscreen merely to reconfirm it. The controlled run already reproduced the failure and captured sufficient evidence.
3. Do not repeat the ANGLE fullscreen comparison. It produced the same invalid-display-timestamp precursor within the first telemetry second.
4. Consider Vulkan/MoltenVK only as a separately approved future diagnostic. Change shadows, frame limits, and individual effects in later separate tests rather than bundling them with the renderer change.

Every rendered test requires explicit user approval because fullscreen native OpenGL has now coincided with five system-level WindowServer restarts/crashes, including controlled minimal reproductions, even though several intervening approved runs ended normally. A probe must not be treated as safe merely because Godot was stopped after the precursor; the fifth watchdog occurred afterward.
