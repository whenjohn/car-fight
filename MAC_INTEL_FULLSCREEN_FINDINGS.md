# Intel Mac fullscreen investigation

Updated: 2026-08-19

## Decision

Car Fight development has returned to Godot. On the affected Intel Mac, the
project accepts one platform limitation: rendered play must use an ordinary
decorated window that remains inside the usable desktop area.

Do not use native fullscreen, borderless fullscreen, an exact edge-to-edge
window, or edge-to-edge maximization on this machine. This is a compatibility
policy around a confirmed OS/Intel display-path failure, not a claim that the
underlying defect has been fixed.

The diagnostic branches remain preserved as evidence and should not be merged
into `master`:

- `diagnostics/render-isolation` at `64aafcb`
- `diagnostics/mac-intel-fullscreen` at `72afb20`
- `diagnostics/g2-render-bisect` at `07f9462`

## Affected system and failure signature

The confirmed system is a `MacBookPro16,2` running macOS 26.6.1 (25G76), with
Intel Iris Plus Graphics device `0x8a53` and the built-in display
`0x4280f40`. These results do not prove that every Intel Mac, external display,
Apple Silicon Mac, Windows system, or Linux system has the same behavior.

The severe incidents are WindowServer/Intel-display failures rather than
ordinary Godot crashes:

- WindowServer logs repeated `Invalid actual_host_time` messages for the
  built-in display, sometimes beginning seconds after edge-to-edge presentation.
- Escalated cases include an Intel framebuffer VBlank timeout, the display
  becoming unready, WindowServer's event port dying, and a WindowServer watchdog
  restart.
- Godot can remain responsive and visually playable while the precursor is
  active. Its CPU, memory, and telemetry can remain normal.
- Closing Godot after the precursor does not guarantee recovery. One minimal
  probe was followed by a WindowServer watchdog about 278 seconds after Godot
  had exited.
- The Vulkan/MoltenVK probe escalated further to a full Intel graphics kernel
  panic at `IGGuC.cpp:3127`: `Submission on work queue 40 failed due to
  insufficient space`.

Any `Invalid actual_host_time` burst for this built-in display is therefore a
failed test, even if the game looks normal and WindowServer does not restart.

## Controlled baseline

The strongest game-level comparison used the same project and monitored
launcher with window mode as the principal variable:

| Presentation | Result |
| --- | --- |
| Windowed, Godot 4.7 at `db43dec` | 423 seconds across both maps; no precursor or display failure |
| Windowed, second session | 534 seconds; no precursor or display failure |
| Windowed, Godot 4.7.1 | 587 seconds; no invalid timestamps, VBlank timeout, GPU reset, display-not-ready event, or WindowServer failure |
| Native OpenGL fullscreen at `ba96b6d` | 6,811 invalid timestamps beginning about four seconds into telemetry, then VBlank timeout and WindowServer watchdog after about 192 seconds |
| Native OpenGL fullscreen, Godot 4.7.1 at `03672ea` | 736 invalid timestamps in 20 seconds; stopped before escalation |
| ANGLE/Metal fullscreen, Godot 4.7.1 at `03672ea` | 235 invalid timestamps in about 18 seconds; stopped before escalation |
| Vulkan/MoltenVK fullscreen at `80a3b96` | Godot/WindowServer wedge followed by an Intel graphics kernel panic |

The clean windowed runs support the accepted policy, but they are not proof
that a windowed failure is impossible.

## What `render-isolation` established

The `diagnostics/render-isolation` branch rebuilt the runtime one
responsibility at a time: empty Compatibility window, viewport/stretch,
camera, primitive, lighting, shadows, animation, imported Jeep, Rapier
initialization, active Rapier physics, netfox autoloads, and local ENet.

Stages 0-10 were initially clean. Stage 11 first reproduced the precursor, but
that observation was confounded by sleep/wake state and test order. The exact
unchanged Stage 10 then reproduced 623 invalid timestamps with no ENet or input
and was followed by a delayed watchdog. In a restarted WindowServer session, a
clean-order Stage 10-first run reproduced 853 invalid timestamps before Stage
11 or any active networking test ran.

This rules active ENet, network traffic, spawning, replication, and player
input out as requirements for initiating the failure. It also showed no
required thermal warning, memory exhaustion, or GPU recovery event. The staged
ladder did not isolate a particular gameplay or networking system; the display
path is intermittent and stateful.

The reproducible Rapier editor-shutdown `EXC_BAD_ACCESS`/SIGABRT is a separate
extension-unload issue. It does not occur during ordinary game runtime and is
not the WindowServer failure.

## What `mac-intel-fullscreen` established

The `diagnostics/mac-intel-fullscreen` branch tested plausible renderer and
machine workarounds:

- Godot 4.7.1 did not remove the native OpenGL precursor.
- ANGLE confirmed its Metal renderer on the Intel Iris Plus GPU, but reproduced
  the same precursor immediately.
- Vulkan/MoltenVK did not provide a safe alternative. It wedged the display
  path and caused the confirmed Intel graphics kernel panic. Do not repeat it.
- A same-spec `macai2` run validated remote capture only. It was a 1280 x 720
  windowed run with the closed built-in panel powered off at 0 Hz, so it was not
  a fullscreen or active-panel control.

Native OpenGL, ANGLE, and Vulkan are therefore all ruled out as fullscreen
workarounds on the affected Mac.

## What `g2-render-bisect` established

The `diagnostics/g2-render-bisect` branch reduced the scene and presentation
path independently:

- A 14-primitive Stage 0 control ran true 2880 x 1800 native OpenGL fullscreen
  for 30 seconds with zero invalid timestamps.
- One raw Jeep mesh reproduced 680 invalid timestamps.
- Flat material and one-surface variants reproduced 629 and 654 respectively.
- A same-pack Pickup and unrelated Kenney GLB Garbage Truck reproduced 698 and
  631 respectively.
- A generated position/index-only `ArrayMesh` reproduced 207.

Specific imported assets, FBX/GLB format, exact geometry, materials, normals,
tangents, UVs, textures, multiple surfaces, shadows, LODs, and high draw count
are therefore not required.

The strongest matched presentation boundary used the same one-surface Jeep:

| Mode | Geometry | Result |
| --- | --- | --- |
| Native fullscreen | `[0,0]`, 2880 x 1800 | 654 invalid timestamps and delayed watchdog |
| Constrained borderless window | `[0,62]`, 2880 x 1800 | Zero invalid timestamps in the short run; no watchdog through 360 seconds |
| Edge-to-edge mode-0 window | `[0,0]`, 2880 x 1800 | 1,077 invalid timestamps and framebuffer-not-ready event |

Native fullscreen mode and a separate fullscreen Space are not required to
activate the problem. Exact edge-to-edge coverage of the built-in display is
the strongest observed activation boundary. The short constrained-borderless
result is not enough to certify borderless presentation, so the project uses a
more conservative decorated, inset window.

The minimal Stage 0 control was not rerun edge-to-edge in the same affected
display state, so edge coverage has not been proven sufficient for every
scene. The evidence supports a practical boundary, not a complete driver root
cause.

## What is ruled out—and what is not

Not required to initiate the known signature:

- gameplay logic, active networking, player input, spawning, or replication;
- Rapier physics activity;
- one particular vehicle, asset author, import format, material, texture,
  surface count, or high draw count;
- native fullscreen mode or a separate fullscreen Space;
- thermal pressure or memory exhaustion;
- continued execution of the Godot process after a precursor begins.

Not established:

- the exact Godot/WindowServer/Intel driver defect;
- that every windowed size and placement is safe;
- that external displays reproduce or avoid the issue;
- that fullscreen is unsafe on Apple Silicon, Windows, or Linux;
- that a visually successful short run is safe after the precursor appears.

The best current description is an interaction among Godot's presentation
path, WindowServer, and the Intel framebuffer/driver on this hardware. Unity's
Metal player was more resilient in a separate spike but still encountered the
same timestamp-warning/stall family, so this is not evidence of a simple
game-logic or single-engine crash.

## Development and shipping policy

For this affected Intel Mac:

1. Start rendered play in an ordinary decorated window inside the usable
   desktop area. Do not automatically maximize it.
2. Use `./scripts/play_monitored.sh` when an agent or investigation needs a
   rendered local run. Headless tests remain the default for routine checks.
3. Treat native fullscreen, borderless fullscreen, exact edge-to-edge windows,
   and edge-to-edge maximization as unsupported.
4. Do not try native OpenGL, ANGLE, or Vulkan as fullscreen workarounds.
5. Do not repeat known-risk probes merely to reconfirm the findings. Any new
   renderer or edge-coverage experiment requires an explicit new scope and
   acknowledgement that failure can continue after Godot exits.

For other platforms, do not infer a failure that was not measured. Test their
normal fullscreen modes before claiming support. Until the project has a
reliable hardware-level detector, a conservative macOS x86_64 release should
default to an inset decorated window and avoid offering edge-to-edge modes.

## Why returning to Godot is reasonable

Unity showed better recovery from this display failure family, but it did not
eliminate the underlying warnings and stalls. Its browser networking path was
not reproducible from tracked source, and the required CLI-first workflow made
small changes and builds too slow for sustainable development.

Godot already contains the accepted gameplay, fast iteration loop, native ENet
networking, and extensive regression coverage. The affected-Mac limitation is
bounded and can be enforced without changing the game's architecture: develop
and test in an inset window on this hardware, while qualifying fullscreen
normally on unaffected target platforms.

See [`MIGRATION_TO_UNITY.md`](MIGRATION_TO_UNITY.md) for the engine-decision
history and `~/Projects/car-fight-unity/docs/RETURN_TO_GODOT.md` for the Unity
investigation's conclusions.

## Preserved detailed evidence

- Main incident chronology: `.ai/CRASH_LOG.md`
- `diagnostics/render-isolation`: `ISOLATION_RESULTS.md` and
  `ISOLATION_PLAN.md`
- `diagnostics/mac-intel-fullscreen`: `FULLSCREEN_SPIKE.md`
- `diagnostics/g2-render-bisect`: `RENDER_BISECT.md`

Those branch documents and their raw run references remain the source for
probe-by-probe detail. This file is the canonical project policy and combined
conclusion.
