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
