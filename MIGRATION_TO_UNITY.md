# Car Fight: Unity handoff history (superseded)

Updated: 2026-08-19

## Current decision

The 2026-08-17 Unity handoff is superseded. Active Car Fight development has
returned to this Godot repository. The Unity investigation proved a meaningful
native FishNet multiplayer foundation, but its mixed native/browser WebRTC path
was not reproducible from tracked source, depended on an old project-owned
compatibility stack, and imposed unsustainable rebuild/iteration time under the
required CLI-first, no-persistent-Editor workflow.

Unity's rendering advantage on the affected Intel Mac was also narrower than a
general engine advantage: Unity recovered from the timestamp-warning/stall
family more safely, but did not eliminate it. Godot's failure has a bounded
compatibility policy acceptable to this project. On affected macOS Intel
systems, use an ordinary decorated window inside the usable desktop area; do
not use native fullscreen, borderless fullscreen, exact edge-to-edge windows,
or edge-to-edge maximization. Do not repeat the known-risk renderer/fullscreen
experiments merely to reconfirm this boundary.

The combined Godot evidence and current operational policy are now canonical
in [`MAC_INTEL_FULLSCREEN_FINDINGS.md`](MAC_INTEL_FULLSCREEN_FINDINGS.md).

Preserve `~/Projects/car-fight-unity` at revision `e312c42` as an investigation
and carry its useful authority, prediction, lifecycle, impairment, telemetry,
and launch-isolation requirements back into Godot tests. The complete rationale
is in `car-fight-unity/docs/RETURN_TO_GODOT.md`.

## Prior decision — 2026-08-17

Active Car Fight development is moving from Godot to a fresh Unity project.
This repository's `master` branch remains the canonical reference for completed
gameplay behavior, tuning, assets, licenses, and regression scenarios. It is not
the starting point for additional Godot rendering experiments.

The prior engine decision was based on the complete Godot investigation plus
the separate `unity-mac-fullscreen-spike` project. Unity did not eliminate the
underlying Intel/macOS display-timestamp problem, but its Metal player repeatedly
recovered from presentation stalls and did not reproduce Godot's WindowServer
watchdog failures or Vulkan kernel panic. For the Unity game, use
`MaximizedWindow` as the default no-border presentation, retain ordinary
`Windowed` as the safest fallback, and avoid `FullScreenWindow` on affected
Intel Macs when possible.

Unity's measured evidence and platform policy from spike revision `c7d0819`
are consolidated in
`~/Projects/car-fight-unity/docs/UNITY_MAC_FULLSCREEN_CONCLUSIONS.md`. The
original spike remains available in its GitHub repository, but its local
checkout has been retired.

The Unity result is greater resilience, not proof that the operating-system or
Intel display defect is gone.

## Preserved Godot investigation branches

The diagnostic implementations should remain separate. They are clean, pushed,
and do not need to be merged into `master`.

### `diagnostics/render-isolation` at `64aafcb`

- Rebuilt the project one responsibility at a time: empty fullscreen window,
  fixed viewport, camera, primitive, lighting, shadows, animation, imported
  Jeep, Rapier initialization, active physics, netfox, and local ENet.
- Stages 0-10 were initially clean, but the unchanged Stage 10 later reproduced
  the known `Invalid actual_host_time` precursor before Stage 11 ran in the new
  WindowServer session.
- Active ENet, network traffic, spawning, replication, and player input are not
  required to initiate the failure signature.
- The Rapier editor-shutdown `EXC_BAD_ACCESS` is a separate extension-unload
  problem and is not the WindowServer failure.

### `diagnostics/mac-intel-fullscreen` at `72afb20`

- Godot 4.7.1 native OpenGL and ANGLE both produced the same fullscreen display
  precursor immediately.
- A same-spec `macai2` closed-lid windowed run validated remote capture only; its
  powered-off 0 Hz panel was not a valid fullscreen comparison.
- The local Vulkan/MoltenVK fullscreen probe wedged Godot and WindowServer, then
  caused a full Intel graphics kernel panic at `IGGuC.cpp:3127` with
  `Submission on work queue 40 failed due to insufficient space`.
- Vulkan, ANGLE, and native OpenGL fullscreen are ruled out as Godot workarounds
  on this Intel Mac.

### `diagnostics/g2-render-bisect` at `07f9462`

- A clean-room primitive control could run fullscreen without invalid display
  timestamps, while later minimal render stages reproduced the precursor.
- The precursor reproduced with the Car Fight Jeep, a same-pack Pickup, an
  unrelated Kenney GLB Garbage Truck, and a generated position/index-only mesh.
- Imported assets, FBX/GLB format, exact vehicle geometry, materials, normals,
  tangents, UVs, textures, multiple surfaces, shadows, and high draw count are
  not required.
- A one-surface Jeep probe led to a WindowServer watchdog about 278 seconds
  after Godot had exited, proving that closing the client after the precursor is
  not a safe boundary.
- The strongest matched boundary was exact built-in-display coverage. A
  constrained borderless window with a 62-pixel menu-bar margin emitted zero
  invalid timestamps in its short run, while an otherwise matched edge-to-edge
  mode-0 window emitted 1,077 and a framebuffer-not-ready event.
- Native fullscreen and a separate fullscreen Space are therefore not required;
  edge-to-edge Godot presentation itself can activate the unsafe Intel/macOS
  path.

The stale detached `/private/tmp` worktree registrations were short-lived
historical controls. Their evidence is already reflected in the committed
branches and crash log; they are not development branches and should not be
merged.

## What was to be carried into Unity

Port behavior and tests, not Godot's engine structure.

Reuse:

- FOLLOW movement formulas, tuning constants, and deterministic expectations.
- Braking, powerslide, drift-assist, collision escape, boost, reverse, shield,
  cloak, drone-impact, targeting, and course-transition rules.
- Network authority decisions, synchronized state definitions, and the existing
  latency, late-join, reconciliation, and determinism scenarios.
- Arena/course measurements, presentation intent, CC0 assets, and licenses.
- The Godot test suite as a catalog of observable behavior to reproduce with
  Unity tests.

Rebuild in Unity-native form:

- GDScript, nodes, autoloads, RPCs, spawning, and lifecycle management.
- Netfox/Rapier integration, prediction/reconciliation plumbing, presentation,
  input, UI, shaders, and build configuration.
- Scene and prefab content through the Unity Editor/Pipeline rather than by
  copying Godot scenes or hand-authoring Unity YAML.

## Historical Unity reconstruction order

1. Create a clean, lean `car-fight-unity` repository with Unity CLI,
   `com.unity.pipeline`, project-local AI instructions, tests, and automated
   builds.
2. Port FOLLOW movement as pure testable C# without networking or presentation.
3. Add the Jeep, camera, ground, and basic local input.
4. Prove the multiplayer foundation with an authoritative native server and at
   least two clients, including prediction, reconciliation, latency, late join,
   and reconnect behavior.
5. Add collision, braking, powerslides, drift assist, boost, and reverse in
   focused tested slices.
6. Add arena/course transitions, then combat coverage, drone projectiles,
   shield/cloak, and presentation effects.
7. Re-run the equivalent Godot behavioral gates at every milestone.

Car Fight should establish the reusable Unity architecture before beginning a
G2 migration.

## Safety and archive policy

- Do not repeat the known Godot native OpenGL, ANGLE, Vulkan, native-fullscreen,
  or edge-to-edge probes merely to reconfirm them.
- Keep rendered development in an ordinary decorated, inset window on the
  affected Intel Mac.
- Do not merge the diagnostic branches into `master`; consult them by branch and
  revision when detailed evidence is needed.
- Treat `MAC_INTEL_FULLSCREEN_FINDINGS.md` as the canonical safety policy; the
  sections above preserve the historical Unity handoff context.
