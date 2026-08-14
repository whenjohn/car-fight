# Fullscreen isolation results

## Stage 0 — empty Compatibility window

- Revision: `de9e2d0`
- Engine: Godot 4.7.0 stable (`5b4e0cb0f`)
- Driver: native `opengl3`, Intel Iris Plus OpenGL 4.1
- Window: true fullscreen, 2880 x 1800
- Duration: approximately 30 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: an empty Godot Compatibility window in true fullscreen does not
produce the known precursor. Godot fullscreen and native OpenGL alone are not
sufficient; a later project/display/rendering building block is required.

## Stage 1 — fixed viewport and stretch contract

- Revision: `edee78b`
- Engine/driver/window: same as Stage 0
- Added: 1280 x 720 viewport and window overrides with `canvas_items` stretch
- Duration: approximately 27 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: car-fight's fixed viewport and stretch contract does not produce
the precursor without additional rendered content.

## Stage 2 — empty 3D world and camera

- Revision: `fdbc0ef`
- Engine/driver/window/display contract: same as Stage 1
- Added: WorldEnvironment clear color and one current Camera3D
- Duration: approximately 26 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: creating and continuously presenting an empty 3D viewport through
a Camera3D does not produce the precursor.

## Stage 3 — static unshaded primitive

- Revision: `e61497d`
- Engine/driver/window/display contract: same as Stage 2
- Added: one static BoxMesh and one unshaded StandardMaterial3D
- Duration: approximately 26 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: visible primitive geometry and a StandardMaterial3D do not produce
the precursor without lighting, shadows, or animation.

## Stage 4 — directional lighting without shadows

- Revision: `90440d4`
- Engine/driver/window/display contract: same as Stage 3
- Added: normal material shading and one DirectionalLight3D
- Shadows: explicitly disabled
- Duration: approximately 26 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: basic shaded geometry and directional lighting do not produce the
precursor without shadow rendering or animation.

## Stage 5 — static directional shadows

- Revision: `64c59b2`
- Engine/driver/window/display contract: same as Stage 4
- Added: receiving PlaneMesh and enabled directional shadows
- Scene motion: none
- Duration: approximately 23 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: a static shadow caster, receiving floor, and directional shadow
pass do not produce the precursor without per-frame scene motion.

## Stage 6 — animated caster and moving shadow

- Revision: `607cbaf`
- Engine/driver/window/display contract: same as Stage 5
- Added: continuous per-frame rotation of the primitive and its shadow
- Duration: approximately 27 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: continuous transform updates and a moving dynamic shadow do not
produce the precursor with primitive geometry.

## Stage 7 — imported Jeep hierarchy

- Revision: `c1e9895`
- Engine/driver/window/display contract: same as Stage 6
- Changed: replaced BoxMesh with freshly imported Jeep FBX scene hierarchy
- Motion/shadows: same continuous rotation and moving shadow as Stage 6
- Duration: approximately 24 seconds of telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: car-fight's imported Jeep hierarchy, its materials, and its moving
shadow do not produce the precursor without physics or networking systems.

## Stage 8 preparation — Rapier initialization

- Enabled only the Rapier3D extension and selected it as the 3D physics engine.
- No physics body or collider has been added yet.
- The initial headless editor scan completed, then Godot crashed while quitting.
- macOS displayed the reported "Godot quit unexpectedly" prompt.
- Matching crash reports: `Godot-2026-08-13-175007.ips` from the initial
  inherited-addon scan and `Godot-2026-08-13-181809.ips` from Stage 8, both in
  `~/Library/Logs/DiagnosticReports/`.
- Report signature: `EXC_BAD_ACCESS`, `SIGABRT`, faulting main thread, with
  `libgodot_rapier.macos.dylib` loaded.
- A subsequent ordinary headless game runtime initialized Rapier, ran Stage 8,
  and exited normally.

This reproducible signature is a distinct Godot/Rapier editor-shutdown or
extension-unload fault. It is
not the fullscreen WindowServer failure and produced no display watchdog. Keep
it recorded separately while continuing the runtime fullscreen isolation.

## Stage 8 — Rapier initialized without physics bodies

- Revision: `7c51bc4`
- Engine/driver/window/display contract and rendered scene: same as Stage 7
- Added: Rapier3D extension loaded and selected as the 3D physics engine
- Physics bodies: none
- Duration: approximately 25 seconds of fullscreen telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: loading Rapier during an ordinary fullscreen runtime does not
produce the WindowServer precursor. The separate editor-shutdown crash does not
occur on this runtime path.

## Stage 9 — active Rapier simulation

- Revision: `6125a60`
- Engine/driver/window/display contract and presentation: same as Stage 8
- Added: 120 Hz physics, one active rigid body/collider, gravity, angular
  velocity, and a static collidable floor
- Networking/netfox: absent
- Duration: approximately 27 seconds of fullscreen telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: active Rapier rigid-body simulation and collision do not produce
the WindowServer precursor without netfox or networking.

## Stage 10 — netfox initialized without ENet peers

- Revision: `b0c20c4`
- Engine/driver/window/display, rendering, and physics: same as Stage 9
- Added: NetworkTime, time synchronizer, rollback, events, and performance
  autoloads at a 60 Hz netfox tick rate
- ENet peers/traffic: none
- Duration: approximately 26 seconds of fullscreen telemetry
- Result: clean
- `Invalid actual_host_time`: 0
- VBlank timeout, GPU reset, display-not-ready, event-port death: 0
- Both Godot processes stopped after the probe.

Conclusion: netfox initialization, timing, and rollback infrastructure do not
produce the WindowServer precursor without an active multiplayer connection.

## Stage 11 — local ENet connection and netfox time synchronization

- Revision: `9064d76`
- Added: localhost ENet server/client lifecycle, tick-rate handshake, timestamp
  exchange, and active netfox time synchronization
- Multiplayer spawning, replication, rollback nodes, and player input: absent
- Result: known fullscreen precursor reproduced
- `Invalid actual_host_time`: 275 from 01:33:37.439 through 01:33:47.773
- The first error occurred in the same second fullscreen telemetry began.
- The run was stopped before a VBlank timeout, display-not-ready condition,
  event-port death, or WindowServer watchdog.
- Both Godot processes stopped after the probe.

Stage 11 is the first isolation stage to reproduce the precursor, and it did so
without any player input system. However, it ran roughly seven hours after the
clean Stage 10 probe. The macOS power log confirms sleep at 01:28:43 and wake
from deep idle at 01:32:29 due to lid-open/user activity, roughly one minute
before Stage 11 reproduced the precursor. ENet/time synchronization was the
project change, but the display wake was an important uncontrolled variable.

## Stage 10 recheck — same build after the overnight display-state change

- Revision: `7131f14` (the recorded clean Stage 10 result, detached in a fresh
  recheck worktree)
- Engine/driver/window/content: identical to the earlier clean Stage 10 probe
- ENet peers/traffic and player input: absent
- Start: 2026-08-14 01:36:07 -0500
- Result: known fullscreen precursor reproduced, followed by a delayed
  WindowServer watchdog
- `Invalid actual_host_time`: 623 from 01:36:11.280 through 01:36:21.904
- The fullscreen client continued producing regular 115-117 FPS telemetry
  through 01:36:35 and was then stopped along with the headless server.
- Neither Godot process appears in the 01:37:12 watchdog stackshot.
- At 01:37:06 the Intel framebuffer logged a VBlank timeout; WindowServer was
  terminated with DisplayID `0x4280f40` not ready and restarted as a new PID.
- Incident: `AFEF1DCD-F77C-4EE2-BB15-CD64A924D9D2`
- Report: `WindowServer-2026-08-14-013706.ips`
- Thermal pressure: nominal; report display state: off
- Collected bundle:
  `/private/tmp/car-fight-stage10-recheck/.crash-runs/20260814-013607`

Conclusion: the exact Stage 10 build that had completed cleanly earlier can
reproduce the precursor without ENet or input once the WindowServer/display
session is affected. This rules out those systems as requirements for sustaining
the failure, but it does not prove what first put the session into that state:
Stage 11 ran first after wake, then Stage 10 ran after Stage 11's precursor.
ENet, the confirmed wake, accumulated fullscreen transitions, and other
long-lived display state are therefore still order-confounded. Historical
incidents also occurred after long active development periods, so wake is not a
required trigger. Once the invalid-timestamp loop begins, closing Godot does not
guarantee recovery: the framebuffer and WindowServer can fail after both game
processes have exited.

The staged experiment therefore does not identify a game building block as the
trigger. Stages 0-10 were all clean in the earlier display session, while Stage
11 and then Stage 10 both failed in the later, already affected session. A valid
next comparison would require a fresh WindowServer session and Stage 10 first,
before Stage 11 or a series of fullscreen transitions. It still requires
explicit approval because even a short stopped probe can lead to a delayed
system-level crash.
