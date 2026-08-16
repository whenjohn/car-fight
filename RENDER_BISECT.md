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

The approved flat-material fullscreen probe ran for 30 seconds at commit
`491af25`. Telemetry confirmed the intended `flat_override`, true focused
2880 x 1800 fullscreen, nine draw calls, 708 primitives, and 120 FPS after
startup. WindowServer emitted 629 `Invalid actual_host_time` warnings for the
same DisplayID plus one framebuffer-not-ready event. The client exited normally,
WindowServer remained PID 213 through the 120-second watch, and no watchdog or
crash report appeared. Evidence:
`.render-bisect-runs/20260815-232133-stage1-jeep-flat`.

The embedded materials are therefore not required to activate the warning. The
flat override retained all eight source surfaces and the same nine total draw
calls, so the next Jeep-only split is to rebuild the same geometry as one
surface with one material. That will isolate surface/draw submission count from
the Jeep's vertex/index geometry.

### Jeep one-surface isolation

`stage1-jeep-one-surface` loads the same byte-identical FBX and uses Godot's
engine mesh builder to append all eight triangle surfaces into one `ArrayMesh`
surface. Headless telemetry verifies that the source and rendered mesh both
contain exactly 1,323 vertices and 2,118 indices while the surface count changes
from eight to one. It uses the same plain material, transform, camera, light,
ground, and disabled shadows as `stage1-jeep-flat`.

Inspect the prepared command without rendering:

```sh
./scripts/render_bisect.sh run stage1-jeep-one-surface --dry-run \
  --startup-fullscreen --seconds 30
```

The approved one-surface fullscreen probe ran for 30 seconds at commit
`ce9aa1d`. Telemetry confirmed true focused 2880 x 1800 fullscreen, one rendered
Jeep surface, two total draw calls, 708 primitives, and 120 FPS. It still
produced 654 `Invalid actual_host_time` warnings for the same DisplayID plus one
framebuffer-not-ready event. The client exited normally at 23:38:05 and the
original 120-second watch ended at 23:40:09, but the failure continued to build:
additional framebuffer-not-ready events appeared at 23:40:45 and 23:41:59,
followed by an Intel framebuffer VBlank timeout and WindowServer watchdog at
23:42:44. WindowServer PID 213 was replaced by PID 52286. Incident
`E166F533-99C6-4883-AF8D-A53879455C28` records the same DisplayID not ready,
active/waiting on-glass transactions, `displayState: OFF`, and nominal thermal
pressure. Godot had been gone for about 278 seconds and does not appear in the
stackshot; no kernel panic occurred. Evidence:
`.render-bisect-runs/20260815-233727-stage1-jeep-one-surface`.

Surface/material subdivision and draw-call count are therefore not required to
activate the warning: the Stage 0 control and this stage both use two total draw
calls, but only the Jeep stage reproduced it. The controlled remaining render
difference is mesh geometry/workload: 708 total primitives here versus 14 in
Stage 0. The next split should replace the Jeep with a newly generated,
non-imported engine mesh matching its 1,323 vertices, 2,118 indices, 706
triangles, one surface, and one plain material.

Because this watchdog landed after the original post-exit monitor finished, the
render-isolation launcher now watches WindowServer for 360 seconds after a
fullscreen/precursor run. A clean client exit is not a safe boundary once the
invalid-timestamp signature has appeared.

### Same-pack Pickup isolation

`stage1-pickup-one-surface` replaces the Jeep with `Pickup.fbx` from the exact
same Daniel Quevedo CC0 Low Poly Vehicles Pack and official FBX archive. The
repository copy has SHA-256
`21eba6952659dc20916e28aacf8cac98150a7f617a58f4e1acc5b7be56fc4550`.
No G2 asset or code is involved.

The stage keeps the one plain material, identical transform, camera, light,
ground, and disabled shadows. Godot's engine mesh builder merges the Pickup's
seven source surfaces into one rendered surface while preserving its 1,038
vertices and 1,680 indices (560 triangles). Headless validation finds zero
NaN/infinite vertex, normal, or tangent values and zero out-of-range indices in
both the Pickup and Jeep sources.

Inspect the prepared command without rendering:

```sh
./scripts/render_bisect.sh run stage1-pickup-one-surface --dry-run \
  --startup-fullscreen --seconds 30
```

The explicitly approved fullscreen probe ran for 30 seconds at commit
`dceb711`. Telemetry confirmed true focused 2880 x 1800 native OpenGL, one
rendered Pickup surface, two total draw calls, 562 primitives, 115-120 FPS, and
a normal client exit. It produced 698 `Invalid actual_host_time` warnings for
DisplayID `0x4280f40` from 00:11:32.291 through 00:11:44.043, followed by one
framebuffer-not-ready event at 00:11:46.080. WindowServer remained PID 52286
through the full 360-second post-exit watch, with no VBlank timeout, GPU reset,
event-port death, watchdog, panic, or crash report. Evidence:
`.render-bisect-runs/20260816-001123-stage1-pickup-one-surface`.

This same-author, same-pack, same-date, same-FBX-pipeline control rules the
Jeep's exact geometry out as a requirement for the precursor. It does not yet
separate the shared FBX/export pipeline from the broader fact that both probes
render imported vehicle meshes. The next control should use a static vehicle
from a different creator and pack in a different format; Kenney's CC0 Car Kit
`sedan.glb` is the selected candidate. A rendered probe still requires explicit
crash-risk approval and the 360-second post-exit watch.

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
