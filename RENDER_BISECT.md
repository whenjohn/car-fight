# Car Fight render-isolation ladder

This branch rebuilds the rendering path from a clean control so each car-fight
addition can be tested separately. The control project was written from scratch
inside this repository. It does not copy or load any assets, scripts, controls,
gameplay, networking, input, scene structure, or other logic from the comparison
project.

## Stage 0: clean engine control

`render_bisect/` is a standalone Godot project with:

- OpenGL Compatibility rendering.
- No project display or window-size overrides.
- No autoloads, input map, networking, or physics.
- One camera, one light, one plane, and one box, all created from engine
  primitives.
- Low-rate telemetry that immediately flushes window mode, display, renderer,
  FPS, draw-call, and memory data.

Run a non-rendered verification at any time:

```sh
./scripts/render_bisect_test.sh
```

Inspect the rendered command without opening a window:

```sh
./scripts/render_bisect.sh run stage0-control --dry-run --seconds 30
```

When ready for the crash-risk test, save work first, launch the windowed control,
and enter fullscreen manually from its window:

```sh
./scripts/render_bisect.sh run stage0-control --accept-crash-risk --seconds 30
```

If a manual transition is impractical, the same clean project can explicitly
request startup fullscreen through Godot's command line:

```sh
./scripts/render_bisect.sh run stage0-control --accept-crash-risk \
  --startup-fullscreen --seconds 30
```

The project itself has no display override in either case. Evidence is kept
under `.render-bisect-runs/`. Test one stage per boot because an Intel
display-driver failure can outlive the Godot process.

## Stage 1: car-fight Jeep presentation

`stage1-jeep` replaces the Stage 0 box with a byte-identical copy of the raw
car-fight `assets/ground_vehicle/Jeep.fbx` source. The FBX contributes one mesh
instance and its eight embedded color-material surfaces. Stage 1 does not load
the vehicle hull or mesh-splitting scripts and adds no collision, physics,
controls, wheel animation, weapons, effects, networking, or gameplay. Both the
directional light and the Jeep mesh have shadow casting disabled.

The launcher performs a headless asset-import preflight before any future
rendered Stage 1 run. Inspect its command without opening a window:

```sh
./scripts/render_bisect.sh run stage1-jeep --dry-run \
  --startup-fullscreen --seconds 30
```

The approved Stage 1 fullscreen probe ran for 30 seconds in the same
WindowServer session as Stage 0. It remained smooth and exited normally, but
produced 680 `Invalid actual_host_time` warnings and one framebuffer-not-ready
event; Stage 0 had produced zero invalid timestamps. WindowServer retained its
PID through the 120-second watch and no watchdog or crash report appeared.
The user's prior crashes include failures after a reboot, so reboot/session
state does not explain the repeated association between the Jeep test and the
known warning. Treat this as a Jeep rendering-path regression and isolate the
Jeep before adding Stage 2.

### Jeep material isolation

`stage1-jeep-flat` keeps the exact same Jeep FBX geometry, transform, one mesh
instance, eight surfaces, camera, light, ground, and disabled shadows as
`stage1-jeep`. It changes only material selection: one plain engine material is
assigned as the mesh-wide override, bypassing all eight embedded FBX materials.
No comparison-project content or gameplay code is involved.

Inspect the prepared command without rendering:

```sh
./scripts/render_bisect.sh run stage1-jeep-flat --dry-run \
  --startup-fullscreen --seconds 30
```

This variant has passed headless import and telemetry tests but has not yet been
run rendered. If its fullscreen run still produces invalid timestamps, the
embedded materials are not the activator and the next Jeep-only split should
merge the same geometry into one surface/draw. If the warnings disappear, the
next split should inspect the embedded materials individually.

## Remaining additions

Each later stage changes one car-fight-owned variable and keeps everything else
fixed:

2. Add the car-fight 1280×720 window/viewport override.
3. Add the car-fight canvas-items stretch setting.
4. Add car-fight lighting and shadow settings.
5. Add car-fight arena geometry and visual effects.
6. Load the complete car-fight scene without networking.
7. Add car-fight spawning and networking last.

No comparison-project content is permitted at any stage. Later assets and code
must come from this car-fight repository and be introduced explicitly.

## Pass and fail criteria

An `Invalid actual_host_time` warning is not by itself a visible crash, but it is
a meaningful diagnostic regression when a controlled stage changes from zero
to hundreds: it is the same precursor repeatedly observed before the Intel
display-path failures. A framebuffer-not-ready event, VBlank timeout, GPU reset,
dead WindowServer event port, abnormal client exit, or WindowServer replacement
fails the stage outright. A stage otherwise passes only when fullscreen is
confirmed, the window remains visibly responsive, the client exits normally,
the WindowServer PID remains unchanged, and no watchdog or kernel crash report
appears.
