# Godot 4.6 experiment and return to Godot 4.7

Status: historical record. The canonical project is now Godot 4.7.1,
Compatibility renderer, with Rapier 0.8.39.

This document records why Car Fight moved from Godot 4.7 to 4.6.3, what was
learned while making Forward+ work on the Intel MacBook Pro, why the apparently
successful 4.6 baseline later proved unsafe, and how the project returned to
4.7 without discarding gameplay or networking work.

The short conclusion is:

- Godot 4.6.3 made real Forward+ render on this Intel Iris Plus when Godot 4.7
  Forward+/Mobile did not.
- The 4.6 migration itself was technically sound and passed extensive gameplay,
  networking, native, and Web regression testing.
- Repeated cold-start Forward+ lighting submissions later caused Intel
  Metal/Vulkan command-buffer timeouts and Godot device-loss aborts.
- Cache removal, staged shader compilation, and scene reconstruction helped
  isolate the boundary but did not make directional Forward+ shadows reliable.
- The project therefore returned to Godot 4.7 Compatibility and recreated the
  accepted sunlit appearance without Vulkan Forward+, SSAO, or directional
  shadow maps.
- Gameplay and networking were preserved from the established code. They were
  not replaced with newly invented one-pass implementations.

## Hardware and constraints

The affected development machine is a MacBookPro16,2 with an Intel Iris Plus
Graphics GPU and 16 GB of system memory. The relevant engine versions were:

| Baseline | Renderer | Rapier |
| --- | --- | --- |
| Original/current | Godot 4.7.1 Compatibility | 0.8.39, API 4.7 |
| Downgrade experiment | Godot 4.6.3 Forward+ | 0.8.35 enhanced determinism, API 4.6 |

Two separate graphics problems were investigated. They must remain separate in
future diagnosis:

1. **Fullscreen WindowServer watchdog:** fullscreen or edge-to-edge native
   presentation can deadlock the Intel framebuffer and restart WindowServer.
   This predates the 4.6 experiment and was reproduced under Godot 4.7
   Compatibility. The retained mitigation is an ordinary decorated window
   inside the usable desktop, launched through `scripts/play_monitored.sh`.
2. **Godot 4.6 Forward+ device loss:** ordinary-window Vulkan/Metal rendering
   could time out during early lighting/shadow submissions. Godot then aborted
   because its Vulkan rendering device had been lost. This was the failure that
   ultimately ended the 4.6 Forward+ direction.

Returning to Godot 4.7 does not make fullscreen safe. The ordinary-window
policy still applies.

## Why the project downgraded to 4.6

Godot 4.7 Forward+ and Mobile could not compile/use their Vulkan compute path
reliably on this Intel Mac. Compatibility worked, but the desired city lighting
was easier to achieve with real Forward+ shadows, sky lighting, and low SSAO.
Godot 4.6.3 was tested and did render Forward+ on the same hardware.

The approved experiment branch was `codex/forwardplus-46-rendering` at
`6f9e6aa`. It combined the sunlit city study, overcast HDRI grade, Collection
trees, and an Intel-specific Forward+ test. The migration plan was frozen at
`2c8a710`, with tag `pre-godot-46-2026-08-31` preserving the prior 4.7 head.

The intended 4.6 baseline was deliberately lean:

- clustered Forward+;
- 2048-pixel cascaded directional shadows;
- low SSAO;
- 2x MSAA at 1280 x 720;
- SSIL, SSR, SDFGI, and TAA disabled.

The first approved run had one 20.2-second cold shader stall, then averaged
58.8 FPS across focused samples and was visually accepted.

## The 4.6 integration was real, not a shortcut

The candidate was integrated in stages:

- `a46f36d` — Godot 4.6.3 and official Rapier 0.8.35 candidate;
- `8455024` — engine/API and project compatibility work completed;
- `7463b5f` — slower-starting 4.6 regression harnesses stabilized;
- `e1923ab` — complete regression acceptance;
- `762cce7` — production promotion recorded.

The migration changed project feature metadata, renderer settings, all Rapier
platform binaries, importer sidecars, and a small number of type/API
compatibility points. It retained:

- server authority and the existing ownership model;
- ENet, WebRTC, and mux transports;
- the vendored netfox rollback and stale-history fixes;
- mouse, controller, vehicle, collision, combat, ball, tractor, defenses,
  pickups, effects, and presentation behavior.

Clean imports initially exposed inferred numeric types that one engine accepted
and the other did not. Explicit annotations/casts fixed parsing without changing
values or behavior. Godot 4.6 also emitted an exact shutdown-only
`ERROR: 1 resources still in use at exit` warning. The harness classified only
that exact line after successful process exit; it did not weaken general error
scanning.

The accepted 4.6 candidate passed:

- the complete test suite;
- seven native ENet profiles;
- reconnect, late join, leave/rejoin, mixed ENet/WebRTC, and forced-TURN tests;
- native offline and Web exports;
- native plus browser play;
- ball, tractor, course, reverse, gates, weapons, drone, shield, cloak, and det;
- a 27-minute ordinary-window Forward+ drive averaging 59.73 FPS;
- production macai2 deployment and connection/reconnect smoke.

One actual network presentation bug was found during this work: live batch map
validation knew only the old Arena and Driving Course IDs, so it rejected Low
Poly City state as malformed and hid the other Jeep. The receiver was moved to
the shared bounded validator and gained regression coverage. This was a normal
map-integration defect, not a renderer crash.

## What began failing after promotion

After Low Poly City and Forward+ lighting became the defaults (`b20bb6a`), the
first monitored run displayed the remembered jagged shadows and stayed alive
for 8 minutes 53 seconds at filter quality 1. Raising global directional and
positional shadow filtering for softer shadows was followed by a crash roughly
twelve seconds after launch.

The recurring crash reports had a consistent signature:

- macOS reported an Intel Metal command-buffer timeout;
- Vulkan returned `VK_TIMEOUT` or device loss;
- Godot failed in `command_queue_execute_and_present`, frame execution, or
  swap/present and deliberately called `abort()`;
- some captures showed Forward+ pipeline creation workers, while a later
  isolated capture showed all compiler workers idle;
- macOS logs recorded an Intel RCS hardware context stuck in a batch buffer and
  a successful type-2 GPU restart;
- process memory peaked around 534 MB, so this was not ordinary exhaustion of
  the laptop's 16 GB RAM.

The repeated `mach_vm_allocate_kernel failed` lines in Apple crash reports were
treated as graphics/kernel allocation pressure at the hang boundary, not proof
that game code leaked all system memory.

Godot's SIGABRT was the consequence of device loss. It was not evidence that
Rapier, vehicle input, networking, or a gameplay assertion called `abort()`.

## Isolation work and what each experiment proved

### Cache isolation

Commit `626ee8b` separated the 4.6 pipeline cache and added startup phase
telemetry. The initially empty cache still produced the same timeout after
about twelve seconds. Later controls moved, rather than destroyed:

- the project Forward+ pipeline cache;
- the Godot shader cache;
- the shared macOS Metal cache.

A fully cold run delayed one failure to about 55 seconds but did not prevent it.
Therefore stale caches could influence timing and had to be isolated, but they
were not the root cause.

All worktrees used the same Godot application name, so they could share
`user://` data and the bundle-level Metal cache. That was a legitimate
contamination concern and is why later resurrection work used independent
physical assets and a fresh project-local `.godot` cache. It still did not
explain the 4.6 command-buffer failures.

### Server and network controls

The crash controls used `--offline`; authority and presentation ran in one
process and did not connect to macai2. The same Vulkan/Metal failure occurred.
The common server was therefore ruled out as a cause.

Network tests sometimes felt stuck when two complete local renderers pushed the
Intel laptop down near 15 FPS. Equivalent 4.7 controls showed the same
same-machine load limit. That was a local rendering/CPU saturation problem, not
proof that the established transport was broken. Remote macai2 hosting and
separated rendered tests remained the correct way to validate cross-play.

### Staged scene and pipeline compilation

Commit `bc60072` stopped networking during startup and staged environment,
lighting, shaders, Jeep, city mesh families, trees, props, course fixtures, and
effects across presented frames. It also recorded pipeline compilation counts.

This experiment was diagnostically valuable. The base frame completed with 19
compilations and all worker threads idle. Enabling four-cascade directional
shadows on the next frame then produced the Metal timeout. That isolated the
failure to realtime directional-shadow submission rather than city size or
ongoing compiler concurrency.

The elaborate staging machinery was not a durable product fix and was later
removed in `376c26b`.

### SSAO

SSAO was already known to collapse performance on this Intel Compatibility
machine from roughly the 50-FPS range into approximately 10–13 FPS. During the
4.6 crash investigation it was disabled in controls so it could not confound
directional-shadow results.

SSAO remains prohibited in the current 4.7 project. It is not an available
visual-quality tradeoff on this machine.

### Directional versus positional shadows

The experiments progressively narrowed the unsafe path:

- quality-2 soft filtering was an early trigger, but quality-1 cold-cache runs
  also failed, so softness alone was not the cause;
- four-cascade directional shadows failed immediately after a clean base frame;
- one post-frame directional shadow map also failed;
- clearing caches and precompiling/staging the complete scene did not make the
  directional path reliable;
- a corrected player-following spotlight sequence—hidden base frame, light-only
  frame, then normal filtered positional shadow—completed cleanly;
- SSAO and directional cascades remained off in the accepted Intel fallback.

Commits `4a40704`, `709013b`, `5165304`, and `f672aec` record the spotlight
experiments and clean simplified result. `dea4c3f`/`fda2453` record the failed
single-directional probe.

The spotlight result proved that not every kind of shadow was inherently
unsafe. It did not prove that 4.6 Forward+ as a whole would remain reliable
across all cold starts and system states.

### Fake/blob shadows and other temporary workarounds

`1f17883` introduced an Intel fallback and temporary soft blob-shadow assets.
Those assets, the phase telemetry, compilation counters, and much of the staged
startup code were useful experiments but were not the desired architecture.
They were explicitly removed by `376c26b` once the positional-light boundary
was understood.

Do not restore those abandoned workarounds merely because their commits still
exist in history.

### Clean-room reconstruction

Because crashes seemed to follow multiple worktrees, the project was also
rebuilt layer by layer in isolated clean-room worktrees. Each layer was launched
and visually checked: base world, city, floor, trees/lamps, Jeep and controls,
ball and tractor physics, defenses, drone fire and hit jostle, weapons, oil,
skids, indicators, and networking.

This process found ordinary presentation defects—missing floor presentation,
missing city models, draw-order issues, and omitted landmarks—but those did not
match the Vulkan device-loss signature. It also established an important
process rule: rebuild work must port and compare the proven gameplay/network
layers from the original project. It must not replace months of tuned netcode
with a fresh one-pass implementation.

The clean-room work was valuable as an integration audit, but rebuilding every
system again was not the answer to an engine/driver command-buffer failure.

## Why the project returned to 4.7

The decision was not that the 4.6 port or its tests were fraudulent. The 4.6
baseline genuinely worked for long runs and passed production regression.
The problem was that real Forward+ directional lighting was not consistently
safe across cold starts and system states on this Intel/MoltenVK path. A game
baseline that can abort the renderer—or in adjacent fullscreen cases destabilize
the display session—is not acceptable merely because some long runs pass.

Godot 4.7 was already the version under which the gameplay and cross-platform
network code had been developed. Returning to it allowed the project to:

- restore Rapier 0.8.39 and the API 4.7 binaries;
- keep all proven gameplay and networking behavior;
- avoid the 4.6 Forward+ cold-start failure family;
- retain the visually accepted city using Compatibility-safe lighting;
- simplify the world instead of carrying obsolete maps and diagnostic code.

The return was staged on `codex/godot47-resurrection` and then promoted by
`3ccd8fe`. The resurrection restored the original 4.7 sunlit/overcast/tree
commits, made Low Poly City the sole authoritative map, and physically removed
the Arena, standalone Overcast world, Driving Course, elevated path, teleport
pads/jump gates, and their presentation/test launchers.

The licensed local city and Collection tree sources were copied as independent
physical files, not symlinked to another worktree. Canonical promotion also
moved the old 179 MB 4.6 `.godot` directory intact to a named `/private/tmp`
quarantine and performed a genuine fresh 4.7 import.

That fresh import exposed five stale-cache-hidden Variant inference errors in
preserved netfox/state files. Commit `c030d20` added explicit types only; it did
not change packets, calculations, control flow, or ownership.

## Current 4.7 visual replacement for Forward+

The current default is `Sunlit aerial (Intel-safe)` under Godot 4.7
Compatibility. It keeps the intended look with:

- a procedural sunlit sky;
- Filmic grading and sky reflections;
- 2x MSAA;
- a 2048 positional-shadow atlas;
- the stable player-following spotlight for contact shadows;
- the overcast HDRI retained as an alternate grade on the same city.

It deliberately keeps these off:

- Vulkan Forward+;
- SSAO, SSIL, SSR, and SDFGI;
- directional shadow maps/cascades.

This is a conscious stability tradeoff, not an accidental renderer downgrade.

## Final validation and preserved history

The final 4.7 city-only project passed fresh import, focused city/lighting/map
tests, offline driving, native ENet, browser WebRTC, and simultaneous native +
browser play against the macai2 mux server. Cross-play acceptance is recorded
at `4ed12fc`. Production macai2 runs Godot 4.7.1 and Rapier 0.8.39 on UDP 10080
and TCP 10181.

Useful recovery points remain:

- `pre-godot-46-2026-08-31` — pre-migration Godot 4.7 head;
- `integration/godot-46-rapier-0835` / `e1923ab` — accepted 4.6 integration;
- `codex/forwardplus-46-rendering` / `6f9e6aa` — approved initial 4.6 rendering study;
- `origin/codex/godot47-resurrection` / `7027700` — approved resurrection checkpoint;
- private repository `whenjohn/car-fight-archives` — archived worktree bundles.

The old commits are evidence and recovery material. They are not instructions
to switch engines, restore removed maps, or re-enable unsafe effects.

## Rules for future sessions

1. Run the canonical project with Godot 4.7.1 and Rapier 0.8.39.
2. Keep Compatibility as the renderer on this Intel Mac.
3. Keep SSAO and directional shadow maps disabled.
4. Use ordinary decorated windows and the monitored launcher; never use native
   fullscreen, borderless fullscreen, or edge-to-edge maximization.
5. Do not diagnose a Vulkan crash by rewriting gameplay or networking.
6. Do not assume a common server or shared asset caused a rendered crash without
   reproducing it in an offline, independent-cache control.
7. Treat cache clearing as an isolation technique, not a guaranteed fix. Move
   caches to named quarantine locations when evidence may be needed.
8. Port established gameplay/netcode layer by layer. Never replace it with a
   new one-pass implementation without explicit authorization.
9. Prefer remote macai2 hosting for multi-client tests; this laptop can be
   saturated by multiple full local renderers even when the network is healthy.
10. If Forward+ is reconsidered, use a separate worktree and a separately
    measured engine/GPU experiment. Do not alter canonical gameplay or
    production merely to retest old failures.

