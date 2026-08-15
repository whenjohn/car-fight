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

The launcher itself never requests fullscreen. Evidence is kept under
`.render-bisect-runs/`. Test one stage per boot because an Intel display-driver
failure can outlive the Godot process.

## Planned additions

Each later stage changes one car-fight-owned variable and keeps everything else
fixed:

1. Add only the car-fight Jeep presentation mesh.
2. Add the car-fight 1280×720 window/viewport override.
3. Add the car-fight canvas-items stretch setting.
4. Add car-fight lighting and shadow settings.
5. Add car-fight arena geometry and visual effects.
6. Load the complete car-fight scene without networking.
7. Add car-fight spawning and networking last.

No comparison-project content is permitted at any stage. Later assets and code
must come from this car-fight repository and be introduced explicitly.

## Pass and fail criteria

An `Invalid actual_host_time` warning is recorded but is not by itself a failure;
the comparison project has emitted that warning without a visible problem. A
stage passes only when the window remains visibly responsive, exits normally,
WindowServer keeps the same PID, and no watchdog or kernel crash report appears.
