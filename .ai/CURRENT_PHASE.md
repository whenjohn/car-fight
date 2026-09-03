# Current phase

## Canonical baseline

- Active repository: `/Users/johnnguyen/Projects/car-fight` on `master`.
- Code-health audit baseline: `d949ba7`; validated audit head: `02c4829`.
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

## Active experiment: always-forward camera

- Worktree: `/Users/johnnguyen/Projects/car-fight-always-forward-camera` on
  `codex/always-forward-camera`, based on `master@b6c2fa0`.
- The presentation-only camera experiment remains available but now starts
  disabled after the owner found the rotating-world orientation disorienting.
  When enabled it keeps the local vehicle nose returning to screen-up. The first owner pass found that its hard
  22-degree bound forced near-1:1 world rotation and felt disorienting. The
  comfort revision instead uses a 10-degree active-turn soft zone and caps
  camera rotation at 95 degrees/second, then settles fully after the turn.
- Speed-scaled travel look-ahead now has separate acceleration and braking ease
  responses. The existing isometric pitch, orthographic size, simulation,
  authority, rollback, and wire state are unchanged.
- The native Debug system menu contains an enable/disable comparison toggle and
  a `Camera tuning…` window. Turn catch-up, comfort zone,
  maximum camera turn speed, viewing angle, zoom, orthographic/perspective
  projection, look-ahead distance, acceleration ease, and braking ease update
  live and autosave locally. The comfort revision lowers
  the default pitch from the original 55 degrees to 48 degrees so building
  sides provide a stronger depth cue. Tool-window focus sends neutral controls.
- Validation passes: `./scripts/check.sh`, `tests/always_forward_camera_test.gd`,
  `tests/always_forward_camera_ui_test.gd`, `tests/sense_of_speed_test.gd`,
  `tests/asset_smoke_test.gd`, `tests/home_world_lighting_test.gd`, and
  `./scripts/offline_test.sh`.
- Next: owner feel-testing in an ordinary inset window using
  `./scripts/play_monitored.sh`; tune the five live values before deciding
  whether the experiment should be promoted. No deployment is authorized.

## Completed work: combined feature merge

- `master` now contains `codex/lighting-editor`, `codex/city-draw-order`, and
  `codex/ch-011-authority-probe` plus the accepted follow-up
  `codex/lighting-editor-input-focus`. Their four merged worktrees were removed
  after validation; the branches remain available as recovery references.
- Ignored monitor evidence from those worktrees is preserved under
  `.crash-runs/worktree-archive/` in the canonical repository.
- Combined validation passes: `./scripts/check.sh` and the complete
  `./scripts/test.sh`, including lighting/window policy, city presentation,
  authority-probe delivery, ENet, mixed transport, join, and reconnect gates.
- No deployment was performed. The macai2 production service remains separate.

## Completed work: Lighting Editor input focus

- Merged from `codex/lighting-editor-input-focus`, based on merged
  `master@9a1da6b`; its completed worktree has been removed.
- Owner testing showed that focusing the native editor, especially its look-name
  field, left vehicle keyboard state partially responsive while the game
  viewport's mouse position stopped updating. This was UI focus behavior, not
  the sustained rollback/network stall.
- Live vehicle input is now explicitly neutral whenever the Lighting Editor
  owns native-window focus. Clicking the game resumes normal mouse control; a
  visible `Return to game` button and submitting a look name also return native
  focus to the game window.
- Focused validation passes: `./scripts/check.sh`,
  `tests/home_world_lighting_test.gd`, `tests/asset_smoke_test.gd`, and
  `./scripts/offline_test.sh`.
- The owner verified the native macOS focus handoff in monitored run
  `.crash-runs/worktree-archive/lighting-input-focus/runs/20260902-225127`:
  after selecting the look-name field, returning to the game restored normal
  mouse steering. The result was accepted.

## Completed work: live lighting editor

- Merged from `codex/lighting-editor`, originally based on `master@353f824`;
  its completed worktree has been removed.
- The native `Scenery` system menu now opens a transient `Lighting Editor`
  window modeled on G2's live tuning UI. It starts from the selected lighting
  preset and updates the local presentation in real time.
- The editor is deliberately limited to nine high-impact choices: sun color,
  brightness, height, and direction; world fill; exposure; saturation; and
  positional contact-shadow visibility/darkness. It does not expose SSAO,
  directional shadows, renderer selection, or other unsafe/low-value knobs.
- `Reset to selected preset` discards experimental edits. Selecting another
  existing Scenery preset also refreshes the open editor to that preset.
- Each edit now autosaves a working look under `user://`; the look and its
  built-in base preset restore on the next launch. The same window can save,
  load, overwrite, and delete named look snapshots.
- The editor is a compact 470x540 native child window. It remains at native
  pixel size instead of growing with the game's fixed-viewport canvas stretch
  when the main window is resized.
- New Car Fight worktrees must run `./scripts/sync_local_assets.sh` immediately
  after creation. The tracked `AGENTS.md` rule and helper physically copy only
  the required ignored city and Collection tree families from a registered
  donor worktree; no symlinks, destructive sync, or retired audition packs.
- The Intel Mac window guard no longer imposes its former fixed 1280x720 cap.
  Ordinary decorated windows can be resized freely while they remain within
  the 48-pixel safe inset; fullscreen, maximized, borderless, and edge-to-edge
  presentation remain blocked.
- Validation passes: `./scripts/check.sh`,
  `tests/home_world_lighting_test.gd`, `tests/window_safety_policy_test.gd`, and
  `./scripts/offline_test.sh`. The local-asset bootstrap also passes its own
  `--check` plus the focused city-audition and tree-library tests from a
  previously empty feature worktree.
- Optional follow-up: one owner-approved monitored visual pass in an ordinary
  inset window to judge layout and whether the controls produce useful looks.

## Completed work: code health

- The owner approved and `master` was fast-forwarded from
  `codex/code-health-audit` through validated head `02c4829`.
- The cleanup worktree and branch remain available until a separately approved
  repository-housekeeping pass; do not delete them implicitly.
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
- Network/rollback layer: removed three uncalled, side-effect-free transport/
  cadence query getters while preserving MultiplayerPeer overrides, transport
  ownership, routing, internal cadence decisions, state, and wire behavior.
  Focused StateBundle/codec/remote-position checks pass; the owner confirmed
  normal ENet play, and the monitor ended cleanly. Dormant recovery/failure
  injection seams remain protected on CH-022 hold.
- Scripts/tooling layer: removed the historical sunlit-aerial launcher after
  tracing the lighting/map selections that once distinguished it, and removed
  two unconsumed no-ramp environment assignments. Distinct Networking 1,
  Networking 2 mixed, and shaped one/two-client direct-entry harnesses remain.
- Agent-scaffolding layer: corrected the shared `AGENTS.md` collider and scope
  language to match the accepted capsule, existing bounded weapons, and the
  opt-in G2 lab stack. `CLAUDE.md` remains its relative symlink so both agent
  clients receive one project policy.
- Documentation-routing layer: marked the completed engine, Web, and Networking
  1/2 plans as historical snapshots; current sessions now route through README
  and stable context. README reflects accepted forced-TURN reconnect/two-player
  evidence and the deployed ENet/WebRTC mux while retaining unfinished public
  browser hosting/TURN and opt-in experiment boundaries.

Validation for the import-verifier cleanup:

- `./scripts/check.sh` passes.
- `./scripts/server_daemon.sh import` passes.
- A bounded Web Offline debug export passes.
- The test-manifest positive check and omitted-test negative control pass.
- At that import-only checkpoint, the complete gameplay/network suite was not
  run because the change affected validation tooling only.

Accumulated cleanup-boundary validation:

- After the final layer audit, all 33 focused GDScript contracts pass once.
  The WebRTC harness lifecycle, offline smoke, late-join recovery, reconnect,
  ball, tractor, reverse, combat, RC-orb, shield, and det gates also pass once
  at the final milestone.
- `network_test.sh` and `mixed_transport_test.sh` fail because no queued
  authority probe reaches clients. Both failures reproduce on untouched
  `master@d949ba7`, so they are recorded as pre-existing CH-011 network-test
  debt rather than a cleanup regression and were not wastefully rerun at the
  final milestone.
- The first sandboxed WebRTC lifecycle attempt failed with loopback
  `listen EPERM`; its required unsandboxed rerun passed.

## Completed work: CH-011 authority-probe delivery

- Merged from `codex/ch-011-authority-probe`, originally based on
  `master@353f824`; its completed worktree has been removed.
- Historical tracing found the intended consumer in sibling city commit
  `b20bb6a`. Promotion commit `3ccd8fe` retained the 20-tick delay constant,
  queue producer, and client receiver but omitted the loop that dequeued mature
  samples and sent them to their owning peers.
- Restored that exact bounded delivery seam before new samples are scheduled.
  It rechecks the live peer list at delivery time, preserving the existing
  disconnect-race guard, unreliable RPC contract, cadence, and authority model.
- Added `tests/authority_probe_delivery_test.gd` to prevent another partial
  promotion from leaving the queue without its delayed consumer.
- Focused validation passes: authority-probe delivery contract, fast check,
  ENet `network_test.sh` (1.674-unit worst correction), mixed ENet/WebRTC
  `mixed_transport_test.sh` (0.300), late join, and reconnect.
- The required integration-boundary `./scripts/test.sh` passes completely. Its
  ENet run reported a 1.834-unit worst correction and mixed transport reported
  0.300; all lifecycle and gameplay gates passed. The initial sandboxed ENet
  attempt failed only because local UDP bind was denied, and the required
  unsandboxed run passed.
- A two-rendered-client check used this exact branch on a temporary isolated
  macai2 server at UDP 12680; production UDP 10080 was not modified. Probe
  delivery worked, but sustained play failed: Alpha and Bravo reached 91.671
  and 92.553-unit corrections, respectively, and each client's remote-player
  view froze. Evidence is preserved under
  `.crash-runs/worktree-archive/ch011/runs/two-client-20260902-221336/`.
- The live failure followed a shared performance/rollback stall around
  22:14:53. Bravo reported a 562 ms process interval and 232-tick rollback
  depth; Alpha then reported a 653 ms process interval with deep rollback.
  Both exceeded the retained 64-tick history, stale-authority recovery repeated,
  and fresh body state did not converge even though the server kept ticking.
  The temporary server was stopped and production UDP 10080 remained running.
- The identical control used matching `master@353f824` clients and a temporary
  isolated macai2 server at that exact commit. It reproduced the large shared
  freeze, stale-history recovery loop, and an even stronger failure: macai2
  timed out and removed both peers while their windows continued producing
  inactive-multiplayer errors. The user saw the major freeze but no persistent
  split because both clients had disconnected. Evidence is preserved under
  `/Users/johnnguyen/Projects/car-fight/.crash-runs/two-client-20260902-222423/`.
- This control establishes that the sustained rendered stall/recovery failure
  predates restored probe delivery. Keep that investigation separate from
  CH-011; the probes make divergence measurable but do not mutate simulation
  state. Both temporary macai2 servers were stopped, and production UDP 10080
  remained running throughout.

## Next

1. Open the pre-existing sustained rendered stall/recovery failure as a separate
   networking worktree/task, preserving both captured runs. Do not repeat
   rendered testing without explicit owner approval.
2. Decide separately whether tracked `.ai` state should move into the shared
   `claude-comms` symlink model; preserve history and account for concurrent
   worktrees before changing storage.
3. Apply the reviewed 33-file/two-directory macai2 cleanup only after explicit
   owner approval from clean `master`. Its old
   remote `gate_test.sh` still consumes the constant-zero course/gate `RESULT`
   fields, so retain that output contract until deployment state is resolved.
4. Review the branch-ledger candidates; delete no ref without separate owner
   approval and a fresh merged/ancestor check.
5. Treat the characterized result-report boundary as the limit of this cleanup;
   argument parsing and any further `Main.gd` extraction remain on hold.

The complete former phase log is preserved at
`docs/history/CURRENT_PHASE_THROUGH_2026-09-02.md`.
