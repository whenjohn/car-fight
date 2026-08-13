# WindowServer crash log

## Safety status

The rendered car-fight client is a probable reproducible trigger for a macOS/Intel graphics stack failure. Do not automatically run `./scripts/play.sh`, open the project in a rendered editor, or perform a rendered soak test while investigating this issue. Headless tests are still appropriate. Get the user's explicit approval before a rendered reproduction attempt because the failure can kill WindowServer and disrupt the whole login session.

No renderer, lighting, shader, gameplay, or launch-script change has been made in response. The user explicitly chose to log the evidence and continue development unchanged.

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

## Shared system signature

- Hardware: MacBookPro16,2, Intel Iris Plus Graphics, device `0x8a53`, up to 1536 MB.
- OS: macOS 26.6.1, build 25G76.
- Report type: WindowServer bug type 409, watchdog termination.
- Watchdog reason: `monitoring timed out for service` and WindowServer was not alive.
- Same affected display in all three reports: DisplayID `0x4280f40` / decimal 69734208.
- Same framebuffer registry ID in all three reports: 4294968498.
- IOKit associates framebuffer 4294968498 with `AppleBacklightDisplay`; it is the MacBook's built-in panel, not an external display.
- WindowServer reported the display as not ready, with on-glass surfaces active/waiting.
- All three reports recorded `displayState: OFF`.
- The user reports that all three failures occurred while the game was fullscreen. No known windowed play session has produced this failure. This makes fullscreen presentation/display-mode handling a narrower shared condition than gameplay state, although it does not yet prove that fullscreen alone is sufficient.
- Thermal pressure varied across the incidents: moderate on August 11, nominal at 03:24 on August 13, and heavy at 13:15 on August 13. Heat may have contributed to the third event, but it is not required by the shared failure signature.
- Unified logs around the August 13 failures show `AppleIntelICLLPGraphicsFramebuffer` repeatedly reading and setting the built-in display mode. The third incident additionally captured an explicit framebuffer VBlank timeout at the failure boundary.
- Neither Godot process showed runaway CPU use or an extreme memory footprint.

## Current assessment

The game cannot directly terminate WindowServer, and the reports do not identify a specific GDScript or draw call. However, three nearly identical watchdog failures with the same rendered Godot workload, same framebuffer, and same built-in display state make coincidence unlikely. The third run lasted about 156 seconds rather than 69, so a fixed time-to-failure is no longer part of the shared signature.

Treat the rendered client as the probable trigger for an operating-system/Intel graphics-driver deadlock. The likely shared path is Godot 4.7's Compatibility renderer using native macOS OpenGL, possibly involving real-time shadow rendering or window/display presentation. Recent driving logic and recent visual effects are not plausible common causes because the first incident occurred before they existed.

The user also recalls the same failure from the project's earliest prototype period. Combined with the first preserved incident predating the later driving, course, combat, and presentation work, this rules those additions out as the origin of the problem. Investigation should concentrate on the small original overlap: fullscreen presentation, Godot 4.7 Compatibility/native OpenGL, the Intel framebuffer, and the basic scene render path.

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

Relevant project settings across all three incidents:

- `renderer/rendering_method="gl_compatibility"`
- 1280 x 720 viewport/window override
- Godot 4.7 x86_64 official application

Godot 4.7 reports these available macOS rendering drivers on this machine: `vulkan`, `opengl3`, `opengl3_angle`, and `dummy`. Native Metal is not implemented for Intel Macs; RenderingDevice uses Vulkan through MoltenVK there. ANGLE is also available as an alternate Compatibility driver.

## Implemented monitoring for future rendered launches

`./scripts/play_monitored.sh` now creates a timestamped evidence bundle under the ignored `.crash-runs/` directory. It explicitly starts windowed unless `--fullscreen` is requested and preserves enough evidence to align game activity with a future display failure without trying to intentionally cause one:

1. Create a timestamped run directory and record the commit, exact launch command, start time, server/client PIDs, Godot version, renderer/driver, display inventory, and current thermal state.
2. Preserve separate server and client stdout/stderr logs alongside the timestamped, immediately flushed telemetry instead of relying on the interactive terminal buffer.
3. Sample each Godot process's CPU, resident memory, thread count, and state at a short interval. Also sample WindowServer and basic system/thermal pressure without requiring an invasive profiler for normal play.
4. Continuously stream a narrowly filtered unified log for `Godot`, `WindowServer`, `watchdogd`, `powerd`, `AppleIntelICLLPGraphicsFramebuffer`, and GPU/IOAccelerator timeout/reset messages.
5. On normal exit, mark the run clean and retain the bundle. After a login-session recovery, the collection command copies the newest WindowServer `.ips`/`.spin` metadata and the matching pre-crash logs into that run directory.
6. If client telemetry stops advancing for four seconds, take a short external Godot process sample so a main-thread stall can be captured before cleanup.
7. Only after this capture path works headlessly should another rendered run be requested, and it still requires the user's explicit approval.

`./scripts/collect_crash_run.sh` attaches any WindowServer/Godot `.ips` and `.spin` files created after the run began, recovers the matching historical unified log, snapshots the recovered display state, and writes short pre-failure tails. The monitor, collector, and flushed telemetry were validated with clean headless runs on 2026-08-13; the complete project test suite passes.

`./scripts/crash_monitor_test.sh` is the safe fault-injection test. It uses `--fake-stall`, which is rejected unless the client is headless, pauses only Godot's main thread for seven seconds, then verifies that telemetry resumes and that the external watcher captured a real process stack. Do not test the monitor by exhausting GPU buffers, repeatedly changing display modes, killing WindowServer, or manufacturing thermal pressure; those approaches risk reproducing the system disruption and make the evidence harder to interpret.

The first monitored isolation run should use the launcher's default windowed mode with the existing native OpenGL renderer. If that remains stable, fullscreen versus windowed is the first one-variable comparison because every known failure was fullscreen. ANGLE versus native OpenGL is the next comparison if fullscreen remains implicated. Do not combine window mode, renderer, gameplay, or shader changes, and do not deliberately run until failure.

## Evidence to collect after another spontaneous crash

Do not intentionally reproduce the crash solely to gather these items. After reboot/login:

1. Preserve the newest WindowServer `.ips` and matching `.spin` paths from `/Library/Logs/DiagnosticReports/`.
2. Record the exact wall-clock crash time, what was visible, whether the game had focus, whether the display dimmed/turned off, and approximately how long the client had been open.
3. Record the current commit with `git rev-parse HEAD` and whether the client was launched by `./scripts/play.sh`, the editor, or another command.
4. In the `.spin`, find all Godot process blocks and record PID, time since fork, footprint, CPU time, and main-thread stack.
5. Compare the report's DisplayID, framebuffer registry ID, `displayState`, thermal pressure, watchdog reason, and surface transaction state with the three incidents above.
6. Inspect the read-only unified log for roughly 90 seconds before and 30 seconds after the incident. Focus on `Godot`, `WindowServer`, `powerd`, `watchdogd`, and `AppleIntelICLLPGraphicsFramebuffer`. Preserve any GPU reset, display sleep/wake, mode-set, swap/present, or WindowServer-port-death events.
7. Check whether a new Godot crash report exists. Absence matters: in all three incidents WindowServer was killed while Godot remained a client of the failed display service.

Suggested read-only commands, with timestamps replaced by the new incident window:

```sh
ls -lt /Library/Logs/DiagnosticReports/WindowServer* | head
git rev-parse HEAD
/usr/bin/log show --style compact --start 'YYYY-MM-DD HH:MM:SS' --end 'YYYY-MM-DD HH:MM:SS' --predicate '(process == "WindowServer") OR (process == "Godot") OR (process == "powerd") OR (process == "watchdogd") OR (senderImagePath CONTAINS[c] "Intel")'
```

## Possible isolation plan, not yet authorized or applied

If the user later chooses to investigate experimentally, use one variable at a time and run headless tests before any rendered test:

1. Run the current build and native OpenGL renderer windowed through `play_monitored.sh`; do not enter fullscreen. This is the safest first comparison because every known failure was fullscreen.
2. Only with explicit approval, repeat the same build and renderer with `--fullscreen`. Do not change shaders, frame limits, or gameplay at the same time.
3. If fullscreen remains implicated, compare native OpenGL with `--driver opengl3_angle` while holding the window mode and scene constant.
4. Consider Vulkan/MoltenVK only after the window-mode and ANGLE comparisons. Change shadows, frame limits, and individual effects in later separate tests rather than bundling them with the renderer change.

Every rendered test requires explicit user approval because the workload has now coincided with three system-level WindowServer restarts/crashes, even though several intervening approved runs ended normally.
