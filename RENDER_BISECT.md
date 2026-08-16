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

### Different-pack Kenney Garbage Truck isolation

`stage1-kenney-garbage-truck-one-surface` uses `garbage-truck.glb` from
Kenney's CC0 Car Kit 3.1. The master archive remains in
`~/Downloads/kenney_car-kit.zip`; only the named GLB, its required colormap, and
the CC0 notice are copied into the clean control project. No G2 asset, code,
control, gameplay, or logic is involved.

The GLB was generated by UnityGLTF and has no animation. Its body and six wheels
arrive as seven mesh nodes, so the control bakes their local transforms and all
seven triangle surfaces into one `ArrayMesh` surface with one plain material.
Headless validation preserves 4,912 vertices and 9,372 indices (3,124
triangles), reports zero NaN/infinite vertex, normal, or tangent values, and
finds zero out-of-range indices. The camera, light, ground, disabled shadows,
and all project/render settings remain unchanged; only presentation scale is
adjusted to frame the differently scaled source model.

Inspect the prepared command without rendering:

```sh
./scripts/render_bisect.sh run \
  stage1-kenney-garbage-truck-one-surface --dry-run \
  --startup-fullscreen --seconds 30
```

This is the first different-creator, different-pack, different-format control.
If it reproduces the precursor, the Daniel Quevedo FBX/export pipeline is not
required. If it remains clean, the same Kenney geometry is available as FBX for
a controlled format split. The user's approval covers one bounded rendered
Garbage Truck probe with the 360-second post-exit watch.

The approved probe ran at commit `d88aaf3`. The client entered true 2880 x 1800
native-OpenGL fullscreen, gained focus, rendered the single merged truck surface
with two total draw calls and 3,126 total primitives, and exited normally after
30 seconds. WindowServer emitted 631 `Invalid actual_host_time` warnings for
DisplayID `0x4280f40` from 10:20:27.614 through 10:20:38.116. The client lost
focus about 0.56 seconds later. No framebuffer-not-ready event, real VBlank
timeout, GPU reset, event-port death, watchdog, panic, or crash report appeared,
and WindowServer remained PID 52286 through the full 360-second post-exit watch.
Evidence:
`.render-bisect-runs/20260816-102017-stage1-kenney-garbage-truck-one-surface`.

This reproduces the precursor with an unrelated creator, pack, GLB format, and
UnityGLTF export. The Jeep, Daniel Quevedo asset pack, FBX pipeline, embedded
materials, surface subdivision, and high draw count are therefore not required.
The next useful control is a non-imported procedural mesh at roughly the same
3,124-triangle workload, still collapsed to one surface and one plain material.

### Procedural matched-buffer isolation

`stage1-procedural-minimal` never loads an imported mesh. It constructs one
`ArrayMesh` directly from finite position and index arrays, with exactly the
Garbage Truck's 4,912 vertex slots, 9,372 indices, and 3,124 triangles. A
71-by-22-cell generated surface uses 1,656 of those vertices; the remaining
3,256 valid but unreferenced positions preserve the vertex-buffer size without
adding another attribute. The mesh has no normals, tangents, UVs, colors,
bones, blend shapes, imported materials, LOD, shadow mesh, texture, hidden
source nodes, or source-resource residency. It uses one unshaded flat material,
one mesh instance, one surface, and disabled shadows.

Headless validation confirms the exact counts, position/index-only attribute
mode, and zero invalid attributes or indices. This control differs from the
warning-producing Garbage Truck in vertex contents and imported resources, but
matches its vertex/index buffer sizes, triangle count, surface count, draw
count, project, camera, ground, and fullscreen launch path.

```sh
./scripts/render_bisect.sh run stage1-procedural-minimal --dry-run \
  --startup-fullscreen --seconds 30
```

The user explicitly approved this first procedural rendered probe. If it
reproduces, binary-search generated triangle count and screen coverage next. If
it remains clean, rebuild the exact Garbage Truck positions and indices without
any other imported attributes or retained source resources.

The approved probe ran at commit `e0b2969`. True 2880 x 1800 native OpenGL
rendered the generated mesh with two total draw calls and 3,126 total primitives
and exited normally after 30 seconds. WindowServer emitted 207
`Invalid actual_host_time` warnings for DisplayID `0x4280f40` from
12:31:01.102 through 12:31:04.589. No framebuffer-not-ready event, real VBlank
timeout, GPU reset, event-port death, watchdog, panic, or crash report appeared,
and WindowServer remained PID 52286 through the full 360-second post-exit watch.
Evidence: `.render-bisect-runs/20260816-123051-stage1-procedural-minimal`.

Imported mesh files, FBX/GLB importers, imported positions, normals, tangents,
UVs, textures, materials, LODs, shadow meshes, hidden source nodes, and retained
source resources are therefore not required for the precursor. This run used a
WindowServer PID that had already experienced earlier precursor tests, so it
does not yet separate generic geometry workload/screen coverage from persistent
fullscreen display state. The next controlled split is to rerun the existing
14-primitive Stage 0 box in this same PID before changing mesh count again.

## Borderless windowed presentation control

The exact warning- and watchdog-producing `stage1-jeep-one-surface` stage can
also be presented as a borderless screen-sized mode-0 window. This deliberately
does not call Godot fullscreen modes 3 or 4 and does not enter the native macOS
fullscreen path. Telemetry requires window mode 0, the borderless flag, display
origin, and a window size equal to the full display size before the run counts.

```sh
./scripts/render_bisect.sh run stage1-jeep-one-surface --dry-run \
  --borderless-windowed --seconds 30
```

The rendered probe still requires `--accept-crash-risk` and retains the full
360-second post-exit WindowServer watch. A clean result requires zero invalid
host-time warnings as well as no display precursor, watchdog, or panic.

The first approved mode-0 probe ran at commit `47c1b82` with the exact
one-surface Jeep that previously produced 654 invalid timestamps and a delayed
WindowServer watchdog in native fullscreen. The client rendered 708 primitives
for 30 seconds and exited normally. All 30 display records confirmed mode 0,
the borderless flag, a 2880 x 1800 render window, and no modes 3 or 4. It emitted
zero `Invalid actual_host_time` warnings. WindowServer remained PID 52286
through the 360-second post-exit watch with no VBlank timeout, GPU reset,
watchdog, panic, or crash report. One framebuffer-not-ready event occurred at
startup, so the render path was not completely clean.

This was not yet a valid visual fullscreen-windowed result: macOS constrained
the window to `[0,62]`, reserving the menu-bar area, and the user visibly saw
the uncovered border. Evidence:
`.render-bisect-runs/20260816-142214-stage1-jeep-one-surface`.

Godot's macOS backend promotes a borderless window above the menu-bar level
when a resize makes it cover the display. The first probe positioned the small
startup window before resizing it, allowing AppKit to constrain that position.
The correction reversed only those calls: resize to the full display first,
then position at the display origin.

The second explicitly approved probe ran at commit `75d398d`. It was a valid
visual fullscreen-windowed test: all 30 display records confirmed mode 0,
borderless, `[0,0]`, 2880 x 1800, and no modes 3 or 4. The same one-surface
Jeep rendered 708 primitives in two draw calls and the client exited normally
after 30 seconds.

This edge-to-edge mode emitted 1,077 `Invalid actual_host_time` warnings for
DisplayID `0x4280f40`, from 14:32:46.372 through 14:33:10.296, followed by one
Intel framebuffer-not-ready event at 14:33:12.335. WindowServer remained PID
52286 through the full 360-second post-exit watch; there was no VBlank timeout,
GPU reset, event-port death, watchdog, panic, or crash report. The run still
fails because the warning storm is the established precursor to the prior
delayed WindowServer watchdog and kernel panic. Evidence:
`.render-bisect-runs/20260816-143233-stage1-jeep-one-surface`.

### Matched presentation comparison

| Presentation | Window telemetry | Invalid timestamps | Other display result |
| --- | --- | ---: | --- |
| Native Godot fullscreen | mode 3, `[0,0]`, 2880 x 1800 | 654 | framebuffer-not-ready events, then delayed WindowServer watchdog/restart |
| Constrained borderless window | mode 0, `[0,62]`, 2880 x 1800 | 0 | one framebuffer-not-ready event; no watchdog in 360 seconds |
| Edge-to-edge borderless window | mode 0, `[0,0]`, 2880 x 1800 | 1,077 | one framebuffer-not-ready event; no watchdog in 360 seconds |

All three rows use the same one-surface Jeep, flat material, camera, ground,
lighting, disabled shadows, OpenGL renderer, 30-second duration, and 360-second
watch. The two mode-0 rows differ only in the ordering that determined whether
macOS left a 62-pixel menu-bar margin or allowed exact full-display coverage.

### Current conclusion

- Native macOS fullscreen and a separate fullscreen Space are **not required**
  to reproduce the warning. A mode-0 borderless window reproduces it when the
  window actually covers the complete built-in display.
- The exact Jeep is **not the root cause**. The same precursor also reproduced
  with the same-pack Pickup, an unrelated Kenney GLB Garbage Truck, and a newly
  generated position/index-only mesh. Imports, FBX/GLB format, embedded
  materials, normals, tangents, UVs, textures, multiple surfaces, shadows, and
  high draw count are not required.
- The strongest matched evidence identifies exact full-display coverage as a
  key activation boundary in Godot's Intel/macOS presentation path. It does not
  yet prove coverage alone is sufficient for every scene: the 14-primitive
  Stage 0 control has not been rerun edge-to-edge in the current WindowServer
  session.
- A visually acceptable fullscreen-windowed mode is therefore **not a safe
  workaround in Godot on this Intel Mac**. A constrained/maximized window may
  avoid the warning, but the one 30-second zero-warning result is not enough to
  certify it for shipping and its visible margin does not meet the requested
  fullscreen presentation.
- This is best treated as a Godot/OpenGL plus macOS Intel display-driver
  interaction. The logs originate in WindowServer and
  `AppleIntelICLLPGraphicsFramebuffer`, so another engine is not guaranteed to
  avoid it; another engine must be tested on this exact machine.

## Next-session handoff (2026-08-16)

### Recommended path: minimal Unity feasibility spike

Do not port Car Fight yet. First build the smallest possible Unity 6 macOS
experiment using Unity's Metal renderer and **Fullscreen Window** presentation.
Unity documents Fullscreen Window as a borderless native-resolution window on
macOS, while exclusive fullscreen is not the normal macOS path:

- [Unity macOS Player settings](https://docs.unity3d.com/Manual/PlayerSettings-macOS.html)
- [Unity 6 system requirements](https://docs.unity3d.com/6000.0/Documentation/Manual/system-requirements.html)

Use the same evidence contract as this Godot branch:

1. `unity-stage0`: one camera, one light, one plane, and one box. No gameplay,
   physics, input, networking, effects, imported assets, or shadows. Run for 30
   seconds in Fullscreen Window, then watch WindowServer for 360 seconds.
2. Only if Stage 0 is clean, run `unity-stage1-jeep`: replace the box with the
   same repository Jeep presentation and keep everything else fixed. Prefer
   one flat material and one merged surface for the closest comparison.
3. A pass requires zero `Invalid actual_host_time` warnings, no
   framebuffer-not-ready event, VBlank timeout, GPU reset, WindowServer
   replacement, watchdog, panic, or crash report.
4. Inspect each launch before rendering and get fresh explicit approval for
   each rendered probe. Save and push work before every risky run.
5. If both Unity stages pass, make a separate decision about a narrow Car Fight
   movement/camera migration prototype. Do not carry G2 assets, gameplay,
   controls, logic, or networking into it.
6. If Unity reproduces the warning, treat this as an OS/Intel-hardware boundary:
   ship Intel macOS windowed/maximized with a margin, omit Intel fullscreen, or
   drop Intel support rather than continuing unsafe fullscreen experiments.

Unity is a promising test because its macOS renderer and window/presentation
implementation differ from Godot's OpenGL path. It is not yet evidence of a
fix. The warning is below the engine in WindowServer/the Intel framebuffer, so
only a monitored run can answer the question.

### Architecture and packaging

Do not create separate gameplay projects for Intel and Apple Silicon. Keep one
Mac product and one asset/code base. Prefer a universal macOS application when
the chosen engine/export pipeline supports it; otherwise architecture-specific
binaries can still come from the same project. Runtime presentation policy may
differ by architecture:

- Intel (`x86_64`): no edge-to-edge Godot presentation unless a future tested
  configuration produces zero warnings.
- Apple Silicon (`arm64`): fullscreen is unproven, not known-bad. Test the same
  minimal stage independently before enabling it.

Using the same borderless policy on both architectures would be simplest, but
only after both pass. Do not infer Apple Silicon behavior from this Intel Iris
Plus failure.

### Optional Godot diagnostics

These are useful only if more root-cause evidence is worth the crash risk; they
are not prerequisites for the recommended Unity spike:

1. Run the existing Stage 0 primitive scene with the corrected edge-to-edge
   mode-0 presentation. This tests whether coverage alone is sufficient in the
   current WindowServer session.
2. If a precise boundary matters, test one inset dimension/position at a time
   between `[0,62]` and `[0,0]`. A tiny inset may identify Godot/macOS's
   full-coverage promotion threshold, but a visible inset is not the requested
   product experience.
3. Repeat a constrained/maximized window for substantially longer before ever
   calling it safe. One clean 30-second run is only preliminary evidence.
4. Package the evidence and incident IDs for Godot and Apple bug reports.

Do **not** repeat the Vulkan/MoltenVK experiment on this Intel Mac. It wedged
Godot and WindowServer and produced the `IGGuC.cpp:3127` kernel panic. Do not
repeat native fullscreen or edge-to-edge Jeep probes merely to reconfirm the
already established warning.

### Resume checklist

1. Pull `diagnostics/g2-render-bisect` and read this handoff before changing or
   launching anything.
2. If the Mac crashed or WindowServer restarted after the last recorded run,
   collect the crash report before opening another rendered client.
3. Choose one next experiment: the recommended Unity Stage 0, or the optional
   Godot Stage 0 edge-to-edge control. Do not mix both in one run.
4. Keep every rendered run bounded to 30 seconds plus the 360-second post-exit
   watch until a new safety decision is documented.

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
