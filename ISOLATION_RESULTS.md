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
