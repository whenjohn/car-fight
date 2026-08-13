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

## Shared system signature

- Hardware: MacBookPro16,2, Intel Iris Plus Graphics, device `0x8a53`, up to 1536 MB.
- OS: macOS 26.6.1, build 25G76.
- Report type: WindowServer bug type 409, watchdog termination.
- Watchdog reason: `monitoring timed out for service` and WindowServer was not alive.
- Same affected display in both reports: DisplayID `0x4280f40` / decimal 69734208.
- Same framebuffer registry ID in both reports: 4294968498.
- IOKit associates framebuffer 4294968498 with `AppleBacklightDisplay`; it is the MacBook's built-in panel, not an external display.
- WindowServer reported the display as not ready, with on-glass surfaces active/waiting.
- Both reports recorded `displayState: OFF`.
- The August 13 event had nominal thermal pressure; the August 11 event had moderate pressure. Thermal overload is therefore not a shared explanation.
- Unified logs around the August 13 failure show `AppleIntelICLLPGraphicsFramebuffer` repeatedly reading and setting the built-in display mode in a tight loop.
- Neither Godot process showed runaway CPU use or an extreme memory footprint.

## Current assessment

The game cannot directly terminate WindowServer, and the reports do not identify a specific GDScript or draw call. However, two nearly identical failures with the same rendered Godot workload, same framebuffer, and almost identical time-to-failure make coincidence unlikely.

Treat the rendered client as the probable trigger for an operating-system/Intel graphics-driver deadlock. The likely shared path is Godot 4.7's Compatibility renderer using native macOS OpenGL, possibly involving real-time shadow rendering or window/display presentation. Recent driving logic and recent visual effects are not plausible common causes because the first incident occurred before they existed.

### Later non-incident observation

After commit `85c7285`, an explicitly approved rendered OpenGL play-test reached at least tick 11460 (roughly 191 seconds at 60 Hz) and was then stopped normally to make the next gameplay change. WindowServer did not fail during that run. This does not clear the rendering path—the two earlier incidents remain unexplained—but it shows the failure is not guaranteed at 69 seconds on every launch.

After commit `2fe2cc8`, another explicitly approved rendered test reached at least tick 7980 (roughly 133 seconds at 60 Hz) and was stopped normally for drift tuning, again without a WindowServer failure.

After commit `52891e3`, a third approved rendered test also reached at least tick 7980 (roughly 133 seconds at 60 Hz) and was stopped normally for the next drift-assist revision, without a WindowServer failure.

After commit `e9ea5d9`, a fourth approved rendered test reached at least tick 35040 (roughly 584 seconds at 60 Hz) and was stopped normally to improve drift-assist activation feedback, without a WindowServer failure.

After commit `20005eb`, a fifth approved rendered test reached at least tick 3240 (roughly 54 seconds at 60 Hz) and was stopped normally after identifying that braking speed loss canceled drift-assist arming, without a WindowServer failure.

Relevant project settings at both incidents:

- `renderer/rendering_method="gl_compatibility"`
- 1280 x 720 viewport/window override
- Godot 4.7 x86_64 official application

Godot 4.7 reports these available macOS rendering drivers on this machine: `vulkan`, `opengl3`, `opengl3_angle`, and `dummy`. Native Metal is not implemented for Intel Macs; RenderingDevice uses Vulkan through MoltenVK there. ANGLE is also available as an alternate Compatibility driver.

## Evidence to collect after another spontaneous crash

Do not intentionally reproduce the crash solely to gather these items. After reboot/login:

1. Preserve the newest WindowServer `.ips` and matching `.spin` paths from `/Library/Logs/DiagnosticReports/`.
2. Record the exact wall-clock crash time, what was visible, whether the game had focus, whether the display dimmed/turned off, and approximately how long the client had been open.
3. Record the current commit with `git rev-parse HEAD` and whether the client was launched by `./scripts/play.sh`, the editor, or another command.
4. In the `.spin`, find all Godot process blocks and record PID, time since fork, footprint, CPU time, and main-thread stack.
5. Compare the report's DisplayID, framebuffer registry ID, `displayState`, thermal pressure, watchdog reason, and surface transaction state with the two incidents above.
6. Inspect the read-only unified log for roughly 90 seconds before and 30 seconds after the incident. Focus on `Godot`, `WindowServer`, `powerd`, `watchdogd`, and `AppleIntelICLLPGraphicsFramebuffer`. Preserve any GPU reset, display sleep/wake, mode-set, swap/present, or WindowServer-port-death events.
7. Check whether a new Godot crash report exists. Absence matters: in the first two incidents WindowServer was killed while Godot remained a client of the failed display service.

Suggested read-only commands, with timestamps replaced by the new incident window:

```sh
ls -lt /Library/Logs/DiagnosticReports/WindowServer* | head
git rev-parse HEAD
/usr/bin/log show --style compact --start 'YYYY-MM-DD HH:MM:SS' --end 'YYYY-MM-DD HH:MM:SS' --predicate '(process == "WindowServer") OR (process == "Godot") OR (process == "powerd") OR (process == "watchdogd") OR (senderImagePath CONTAINS[c] "Intel")'
```

## Possible isolation plan, not yet authorized or applied

If the user later chooses to investigate experimentally, use one variable at a time and run headless tests before any rendered test:

1. Try the Mobile renderer with Vulkan/MoltenVK, all real-time shadows disabled, and a 60 FPS cap.
2. If stable, restore shadows before restoring other screen-reading effects.
3. Alternatively test Compatibility through `opengl3_angle` to bypass native OpenGL while retaining the Compatibility renderer.
4. Only after establishing a stable alternate rendering path should individual shaders/effects be reintroduced or blamed.

Every rendered test requires explicit user approval because both known attempts ended in a system-level WindowServer restart/crash.
