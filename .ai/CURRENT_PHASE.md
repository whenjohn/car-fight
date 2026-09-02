# Current phase

## Canonical baseline

- Active repository: `/Users/johnnguyen/Projects/car-fight` on `master`.
- Current accepted revision when the code-health branch began: `d949ba7`.
- Engine: Godot 4.7.1 with Rapier 0.8.39.
- Renderer: Compatibility. Keep SSAO, directional shadows, native fullscreen,
  borderless fullscreen, and edge-to-edge windows disabled on this Intel Mac.
- Low Poly City is the sole authoritative world and map ID `0`.
- The deployed macai2 service uses native ENet on UDP 10080 and WebRTC
  signaling on TCP 10181. Use `ssh macai2-ts` and do not deploy as an implicit
  part of local work.

Read `AGENTS.md` for mandatory project rules and `.ai/CONTEXT.md` for the stable
architecture index. Read `GODOT_46_TO_47_HISTORY.md` before changing the engine,
renderer, lighting safety policy, Rapier, caches, or world architecture.

## Active work: code health

- Worktree: `/Users/johnnguyen/Projects/car-fight-code-health`.
- Branch: `codex/code-health-audit`.
- Evidence ledger: `docs/CODE_HEALTH_LEDGER.md`.
- Stable architecture/index context now lives in `.ai/CONTEXT.md`. The shared
  project registry resolves `car-fight` to the active Godot repository and
  marks `car-fight-unity` archived. `.ai` intentionally remains tracked locally
  until its separate shared-storage decision.
- Cleanup must remain separate from gameplay, visual tuning, bug fixes, engine
  changes, and optimization.
- Networking, rollback, transports, RPC/state schema, physics feel, rendering
  behavior, and vendored netfox patches remain protected and are audited last.

Completed branch commits:

- `ece1668` — shared Claude/Codex project rules, risk-based quality gates, quiet
  fast check, and removal of three orphan UID sidecars.
- `6cb93cd` — code-health evidence ledger.
- `37ff6eb` — one shared two-pass Godot import verifier used by the fast check,
  complete suite, deployment import, and Web build.
- `177e7f2` — reduced the auto-read phase handoff to current information and
  preserved the former 890-line phase history under `docs/history/`.
- `668dc96` — added stable project architecture/context; the matching
  `claude-comms` registry repair is commit `234335f`.
- `2268137` — recorded the stale files retained on macai2 by non-deleting
  deployment sync; its original manual count of 31 was later corrected to 33.
  No remote file was changed.
- `f73ff79` — added a structural manifest guard; it now covers all 33 standalone
  GDScript tests without executing them during the fast check.
- `bcf13d9` — the macai2 deployment helper now defaults to a read-only preview,
  requires an explicit `apply` from a clean `master`, and preserves
  generated/local state.
  Its preview matched the exact 33 stale files plus two empty directories;
  nothing has been deleted remotely.
- `17b2068` — recorded protected recovery refs, both active worktrees, and 20
  merged local plus 20 merged remote cleanup candidates. No ref was deleted.
- `a38b91c` / `ba2b903` — characterized the server `RESULT` schema and moved
  its pure 32-field formatter outside `Main.gd`. Metric collection, report
  timing, gameplay, authority, RPCs, and transport behavior are unchanged.
- World/spawn layer: removed the city-only `_build_home_world()` forwarding
  wrapper. Focused checks pass, and the owner confirmed the complete city and
  dots during monitored local server/client play; the monitor ended cleanly.
- CH-013 records that offline startup does not seed dots. This predates the
  cleanup and remains separate gameplay bug debt.
- World/presentation layer: removed the unreachable proximity-landmark tree
  builders and their no-op Tree model menu. The owner confirmed city trees and
  retained lighting controls in monitored local play; the monitor ended cleanly.
- World/presentation layer: removed the obsolete local prop audition, which
  spawned visual-only props beyond the accepted north city wall. Focused city,
  lighting, and fast checks pass; the owner confirmed normal city, street-tree,
  dot, driving, and lighting behavior in monitored local play, and the monitor
  ended cleanly.
- World/presentation layer: reduced the tree visual library to the sole accepted
  Collection 121–130 family and removed the unreachable 37 MB Shapespark
  audition package. Focused tree, city, lighting, and fast checks pass; the
  owner confirmed the complete street-tree lining and normal play, and the
  monitor ended cleanly.
- World/construction layer: folded the obsolete arbitrary-rotation static-box
  helper into the live yaw-only city builder after tracing its removed ramp and
  upper-road callers. Focused city and reverse/wall checks pass; the owner
  confirmed building and outer-wall collision, and the monitor ended cleanly.
- Player layer: removed three uncalled helper methods while preserving their
  live backing state, setters, gesture fields, rollback schema, and correction
  sampling; corrected the stale sphere-collider comment to the accepted capsule.
  Focused vehicle, area-weapon, correction, and fast checks pass; the owner
  confirmed driving, vehicle cycling, and area targeting, and the monitor ended
  cleanly. CH-018 records removed-gate state that remains protected on hold.
- Combat layer: removed the uncalled shield-drone aiming method while preserving
  Main-owned targeting, projectile authority, timing, muzzle position, and
  current fixture orientation. Focused asset and shield runtime checks pass;
  the owner confirmed the drone shot and shield interaction, and the monitor
  ended cleanly.
- Documentation checkpoint: updated README and nearby comments that still
  described the retired tree/prop auditions, old arena size, sphere collider,
  ramps/map gates, and an outdated vehicle-mesh contract. Fast structural and
  exact stale-phrase checks pass; no runtime files changed.

Validation for the import-verifier cleanup:

- `./scripts/check.sh` passes.
- `./scripts/server_daemon.sh import` passes.
- A bounded Web Offline debug export passes.
- The test-manifest positive check and omitted-test negative control pass.
- At that import-only checkpoint, the complete gameplay/network suite was not
  run because the change affected validation tooling only.

Accumulated cleanup-boundary validation:

- All 33 focused GDScript tests, the WebRTC harness lifecycle, offline smoke,
  late-join recovery, reconnect, ball, tractor, reverse, combat, RC-orb,
  shield, and det gates pass.
- `network_test.sh` and `mixed_transport_test.sh` fail because no queued
  authority probe reaches clients. Both failures reproduce on untouched
  `master@d949ba7`, so they are recorded as pre-existing CH-011 network-test
  debt rather than a cleanup regression.
- The first sandboxed WebRTC lifecycle attempt failed with loopback
  `listen EPERM`; its required unsandboxed rerun passed.

## Next

1. Decide separately whether tracked `.ai` state should move into the shared
   `claude-comms` symlink model; preserve history and account for concurrent
   worktrees before changing storage.
2. Apply the reviewed 33-file/two-directory macai2 cleanup only after explicit
   owner approval and after this branch is merged to clean `master`. Its old
   remote `gate_test.sh` still consumes the constant-zero course/gate `RESULT`
   fields, so retain that output contract until deployment state is resolved.
3. Review the branch-ledger candidates; delete no ref without separate owner
   approval and a fresh merged/ancestor check.
4. Treat the characterized result-report boundary as the limit of this cleanup;
   argument parsing and any further `Main.gd` extraction remain on hold.
5. Fix CH-011 authority-probe delivery only as a separate networking task with
   focused ENet and mixed-transport characterization.

The complete former phase log is preserved at
`docs/history/CURRENT_PHASE_THROUGH_2026-09-02.md`.
