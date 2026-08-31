# Godot 4.6.3 Forward+ merge plan

Status: merged into the protected `integration/godot-46-rapier-0835`
candidate; not yet applied to `master`. The pre-migration head is preserved by
the pushed tag `pre-godot-46-2026-08-31`.

This document is the handoff for moving the canonical Car Fight project from
Godot 4.7 + Rapier 0.8.39 to the Intel-Mac-tested Godot 4.6.3 + Rapier 0.8.35
Forward+ baseline while retaining all current gameplay and networking work.

## Decision

Use Godot 4.6.3 with the real Vulkan Forward+ renderer and the official Rapier
0.8.35 3D enhanced-determinism/API 4.6 addon as the next `master` baseline.

This is an intentional project compatibility downgrade, not a gameplay or
networking rollback. It changes tracked project metadata, renderer settings,
the bundled Rapier binaries, and small version-compatibility code paths. It does
not uninstall Godot 4.7 or change other projects on the machine.

Do not wait for Godot 4.8. As of 2026-08-31 it is at dev4, and the Godot 4.7
Intel-Mac Forward+/Mobile black-screen regression is merely assigned to the
4.8 milestone; it is not confirmed fixed. Godot 4.6.3 already works on this
machine.

Rapier 0.8.39 is not required by current Car Fight physics. Its headline
changes are an upstream Rapier/Parry update, 3D joint consistency fixes, and a
back-face collision fix. Car Fight uses no physics joints and uses primitive
sphere, capsule, box, and cylinder gameplay colliders rather than
back-face-sensitive concave mesh collision. Networking does not require Godot
4.7 or Rapier 0.8.39.

## Canonical source branch

Use the following branch as the single integration source:

- Branch: `codex/forwardplus-46-rendering`
- Worktree: `/Users/johnnguyen/Projects/car-fight-forwardplus-46`
- Approved head: `6f9e6aa` (`Record Forward+ visual approval`)
- Remote: `origin/codex/forwardplus-46-rendering`

That branch already contains all three sunlit/scenery commits from
`codex/sunlit-aerial-rendering`:

- `a32131e` — Add sunlit aerial city driving study
- `8e09f86` — Reuse overcast city lighting as scenery preset
- `9c29ea9` — Line low poly city with collection trees

It then adds:

- `027ddff` — Add Godot 4.6 Forward+ Intel rendering test
- `6f9e6aa` — Record Forward+ visual approval

Do not merge both experiment branches independently; that duplicates the
sunlit history and makes conflict resolution harder.

Current `master` when this plan was written:

- Worktree: `/Users/johnnguyen/Projects/car-fight`
- Head: `5c173ce` (`Record rendering and scenery merge validation`)
- State: clean and synchronized with `origin/master`

Both experiment worktrees were clean and synchronized with their remotes when
this handoff was written.

## What the approved branch changes

The branch adds the fifth `Scenery > Lighting` preset, `Sunlit aerial
(Intel-safe)`, reuses the accepted overcast-city HDRI lighting as another
scenery preset, lines the Low Poly City streets with deterministic owner-local
Collection 121-130 trees, and supplies focused launch/test coverage.

The Godot/Rapier compatibility commit:

- Changes `project.godot` from feature version 4.7 to 4.6.
- Selects `forward_plus` for desktop and mobile project renderer settings.
- Installs official Rapier 0.8.35 enhanced-determinism/API 4.6 binaries and
  matching extension metadata in `addons/godot-rapier3d/`.
- Keeps the custom Rapier physics driver using explicit `space_step()` and
  `space_flush_queries()`.
- Sets `rollback_physics_space=false`; rollback restores each
  `NetworkRigidBody3D.physics_state` (transform, linear/angular velocity, and
  sleeping state) through the existing synchronizer instead of importing a
  whole serialized Rapier space.
- Removes Godot 4.7-only importer metadata from tracked `.import` sidecars.
- Adds `scripts/play_forwardplus_46.sh` for the safe monitored experiment.

Rapier archive provenance recorded by the experiment:

- Official Rapier version: 0.8.35
- Flavor: 3D enhanced determinism, Godot API 4.6
- Verified published archive SHA-256:
  `f6477144bccf8002c71647193444bd540ed648204d84e6e69919f4affafbf414`

## Measured evidence

The monitored human run reported `Vulkan 1.2.283 - Forward+` on the Intel Iris
Plus and exited cleanly. It did not reproduce Godot 4.7's compute-pipeline
compile/null-dispatch failures.

There was one 20.2-second first-cache shader stall and a non-fatal MoltenVK
pipeline-cache write warning. After warm-up, ten focused driving samples ranged
from 16 to 145 FPS and averaged 58.8 FPS, with 94-101 draw calls, at most 44.6k
visible primitives, and about 216 MB reported video memory. Human visual review
accepted the lean Forward+ city baseline as looking good.

The approved lean baseline intentionally uses:

- Clustered Forward+
- 2048 directional/cascaded sun shadows
- Low SSAO
- 2x MSAA
- 1280x720
- SSIL off
- SSR off
- SDFGI off
- TAA off

Preserve this baseline during the merge. Add expensive effects only in later,
separately measured experiments.

Presentation, city, deterministic physics, WebRTC lifecycle, offline, latency,
mixed-transport, and join-transient gates passed under Godot 4.6.3. The full
suite stopped at reconnect only because short-lived Godot 4.6 clients emit the
shutdown-only line `ERROR: 1 resources still in use at exit`, which the strict
log scanner treats as a failure. No reconnect gameplay/network failure was
observed. Resolve or narrowly classify that known 4.6 shutdown warning; do not
weaken general error scanning.

## Integration procedure

1. Fetch all remotes and confirm the three worktrees above remain clean.
2. Update `master` and create a safety tag or backup branch at its pre-merge
   head.
3. Inspect `git diff master...codex/forwardplus-46-rendering`. Pay particular
   attention to `Main.gd`, `project.godot`, Rapier binaries/metadata, import
   sidecars, scripts, tests, and `.ai/CURRENT_PHASE.md`.
4. Integrate `codex/forwardplus-46-rendering` once. A normal merge is preferred
   if `master` has not diverged. If it has, cherry-pick the five commits above
   in order and resolve against newer gameplay/networking code rather than
   replacing that code wholesale.
5. Preserve all vendored netfox networking patches and the current
   server-authoritative ENet/WebRTC mux. The renderer/Rapier migration does not
   authorize removing or redesigning networking.
6. Reconcile documentation and launchers so the canonical engine becomes
   `/Applications/Godot.app/Contents/MacOS/Godot`, currently verified as
   `4.6.3.stable.official.7d41c59c4`. Search for stale `Godot47.app`, `4.7`, Rapier
   `0.8.39`, and 4.7.1 export-template assumptions rather than changing only
   `AGENTS.md` and `README.md`.
7. Allow Godot 4.6.3 to rebuild local `.godot` imports and shader caches. Do not
   commit generated `.godot` cache contents.
8. Validate in the order below. Fix migration regressions before adding any
   new rendering effects.
9. Commit the resolved integration on `master`, push it, and only then update
   macai2/build artifacts through the repository's normal deployment workflow.

Do not use a destructive reset to make `master` equal to the experiment
worktree. Current `master` owns the canonical gameplay/networking history and
must remain auditable.

## Required acceptance gates

Run at least:

1. Godot 4.6.3 headless editor import/parse and quit.
2. Focused presentation, city, foliage, and scenery tests.
3. Deterministic movement/physics and collision gates.
4. Offline game gate.
5. Native ENet latency/network gate.
6. WebRTC lifecycle and mixed ENet/WebRTC transport gates.
7. Join-transient and reconnect gates, with explicit handling of only the known
   Godot 4.6 shutdown resource warning.
8. Remaining gameplay gates covered by `./scripts/test.sh`.
9. A monitored ordinary-window Forward+ drive using the existing Intel-Mac
   display safety policy—never fullscreen or edge-to-edge.

The merge is accepted only when gameplay/network behavior is unchanged, true
Forward+ is reported at runtime, the city/scenery options remain selectable,
and the monitored drive remains visually and thermally stable after shader
warm-up.

## Follow-up, not part of this merge

- Retest Godot 4.8 only after the Intel-Mac issue has a confirmed fix or a
  stable 4.8 release is available.
- Do not upgrade Rapier merely for version parity. Consider a newer
  Godot-4.6-compatible custom build only for a concrete Car Fight physics bug.
- Add SSIL, SSR, SDFGI, TAA, higher SSAO, or higher shadow settings one at a
  time with before/after performance evidence.
- Revalidate Web exports and matching templates separately; do not assume the
  native engine downgrade automatically preserves the existing 4.7.1 browser
  export checkpoint.
