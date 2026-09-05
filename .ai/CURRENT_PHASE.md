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

## Accepted: targeting optimization merged into canonical master

- Owner authorized merging `codex/targeting-optimization` into canonical
  `master`, preserving the newer modern-sprite and baked-shadow changes.
  Source worktree `/Users/johnnguyen/Projects/car-fight-targeting` was removed
  at owner request after verifying its clean state and ancestry in `master`.
  Profiling evidence was copied and hash-verified under ignored
  `.crash-runs/worktree-archive/targeting-optimization/runs/`. Local art matched
  canonical assets. The merged local/remote branch is retained.
- Acquisition applies the existing triangular coverage before visibility,
  skips candidates that cannot beat the nearest visible selection, and shares
  one candidate traversal/inverse transform/lazy ray setup across ready zones.
  Overlapping zones share each candidate's ray result within this call only.
  No cross-tick cache, scan throttling, cooldown, authority or wire changes.
- The first pass was committed/pushed as `3403e4a`. Follow-up matched headless
  256-fixture results: eager 12.233 ms, first pass 1.411 ms, shared pass 0.589 ms
  median per four zones. Shared scanning saves a further 58.3% in that run.
  This is acquisition CPU evidence, not rendered FPS or multiplayer capacity.
- Targeting tests cover 360 seeded comparisons, blocked fallback, ties, reversed
  tips, triangle corners, dead sprites, balls, shared overlap, cooldown masks,
  exact 15-tick firing and immediate empty-zone reacquisition. Real sprite
  combat exercises wall occlusion and matches all three selectors at 256.
- Follow-up validation passed targeting regressions, real sprite combat/CPU
  comparison, the focused server/client combat gate and `scripts/check.sh`.
  No broader state/network changes.
- Rendered profile completed after owner approval, monitor run
  `20260904-174243` clean: 256 fixtures with combat measured 20.727 ms median /
  27.135 ms P95, versus 19.827 / 23.189 ms without combat. Acquisition was
  1.560 ms per rendered frame. The historical unoptimized median was 148.97 ms;
  exact car pose and machine load are not controlled across those runs.
- Temporary instrumentation was removed after the run and retained as ignored
  diagnostic artifacts. See `docs/SPRITE_PROFILE.md` for raw evidence and limits.
- Merge validation passed `scripts/check.sh`, targeting regressions, sprite
  lab contracts (including modern samples), and live offline sprite combat.
  Focused gates cover the combined acquisition/presentation changes; no shared
  authority or transport changes warrant the broad networking suite.
- Optimization merged into `master`. No production deployment performed.

## Accepted: interactive sprite test in canonical master

- Active follow-up worktree: `/Users/johnnguyen/Projects/car-fight-more-sprites`
  on `codex/more-sprites`, based on `master@9a25b09`. Added SmallScaleInt's
  explicitly free HD knight as another local-only audition option; the other
  eight characters in its pack remain paid and were not downloaded. The knight
  uses native 128px, 15-frame, eight-direction Idle/Walk/Melee/Die sheets with
  baked shadows, a measured knight-specific scale/ground anchor, and existing
  presentation-only selection. No collision, damage, movement, targeting,
  authority, RPC or transport changes. Source remains ignored under
  `assets/local/smallscale-knight/`; setup/license notes are in
  `docs/SPRITE_KNIGHT_SAMPLE.md`. Fast check, expanded sprite contracts and
  live offline sprite combat pass. Interactive monitored run
  `20260904-185655` is open with 16 knights for owner visual evaluation.
  Owner asked to see melee without selecting the manual Attack preview.
  Automatic preview now inserts complete, staggered pseudo-random attack clips
  between idle/walk intervals. Timing follows playback speed and is derived
  locally from fixture IDs, so no network state or synchronized gameplay was
  added. Manual Attack preview remains available. Expanded sequence contracts
  and fast check pass. Monitored run `20260904-190244` was opened with 16
  knights for owner evaluation of the automatic melee timing.
  Added per-character local visual size and playback speed,
  plus autosave of selected character, per-character values, preview, facing
  and ghoul resolution. Shared target count/body scale/movement and session
  pause deliberately remain unsaved. Visual size does not alter collision.
  Serialization/clamping and independent-value contracts plus fast check pass.
  Monitored run `20260904-190957` is open for owner evaluation of the controls
  and cross-launch behavior.
  UI follow-up: owner reported dropdowns flashing and being difficult to select.
  Removed unchanged per-frame dropdown/spin rewrites, explicitly kept the tool
  window non-exclusive, widened controls, and treats an open option popup as
  tool focus so driving remains neutral. Focused dropdown/spin contracts and
  fast check pass. Monitored run `20260904-191711` is open for owner validation;
  acceptance remains pending.
- Baked-shadow trial for modern samples: confirmed translucent shadows in the
  downloaded PNGs. Changed modern-only alpha discard to opaque-prepass blending
  and ground registration from row 88 to 91 to retain soft pixels and avoid
  clipping the idle shadow's bottom rows. Depth testing and ghoul policy remain
  unchanged; no realtime shadows, physics, or networking changes. Fast check
  and expanded sprite contracts pass. Interactive run `20260904-174127` opens
  16 survivors for owner evaluation. Still a billboard shadow, not a ground
  projection. In repeat run `20260904-174641`, the owner confirmed shadows help
  ground the sprites and accepted keeping the adjustment. Added contact-shadow
  evaluation to the future-pack observations. Prone-pose alignment remains open.
- Added a local-only comparison for SmallScaleInt's two free modern exports:
  HD survivor (128px, 14 frames/clip) and outlined thug (64px, 8 frames/clip).
  `CAR_FIGHT_SPRITE_SAMPLE=survivor` or `thug` selects one at launch;
  Debug → Sprite test… → Character (local) switches live. Ghoul stays default.
  Source PNGs/archives remain ignored under `assets/local/smallscale-modern/`;
  setup/license notes are in `docs/SPRITE_MODERN_SAMPLE.md`. No paid creator,
  gameplay, collision, RPC, or targeting changes. These are sample art only.
  Fast check, expanded sprite contracts (including both local packs), and live
  offline sprite combat passed. Captures show both samples in-world; survivor
  death has ground clipping in some directions that still needs alignment work.
  Monitored capture runs `20260904-170858` and `20260904-171027` were stopped
  explicitly after their screenshot helpers waited on further rendered frames;
  neither completed the full perspective/UI capture sequence. Owner subsequently
  preferred the modern samples and found them smoother than the ghoul. Logged
  selection criteria in `docs/SPRITE_MODERN_SAMPLE.md`: prioritize gameplay-scale
  readability, pose spacing, loops and stable registration over raw frame counts.
  All samples have eight directions and default to 12 animation FPS; the exact
  comparison settings were not recorded and proposed causes remain hypotheses.
  Death alignment still needs work. No default change or purchase authorized.
  Start with 16, not a new performance stress test.
- Owner confirmed the spread-out 256-fixture slowdown on a repeat run; 128
  felt better. CPU profiling now identifies automatic target acquisition as
  the dominant cause, not a demonstrated sprite rendering limit. The matched
  256 test measured 148.97 ms median with combat versus 16.38 ms without it;
  acquisition used about 98% of combat CPU and performed about 57,000 visibility
  checks/second before range/angle filtering. See `docs/SPRITE_PROFILE.md`.
  Temporary instrumentation was removed; no optimization or deployment made.
  Next: filter range/angle before visibility queries, preserve targeting rules,
  then rerun 256 with full combat and owner driving/shooting validation.
- Research handoff saved in `docs/SPRITE_PROFILE.md` under "Next-session
  handoff": filter existing triangular coverage first, skip visibility checks
  that cannot change nearest-visible selection, and reuse per-tick setup.
  Preserve ties, blocked-nearest fallback, reversed-tip geometry and firing
  cadence. Defer scan throttling/spatial grids until reprofiled. Owner requested
  documentation only at this checkpoint; no targeting optimization implemented.
- Follow-up requested: raise the practical test ceiling and spread fixtures
  out. Added 128/256 count options and a street layout with at least four-unit
  initial separation, building clearance and a six-unit clear zone around the
  observer. Half the mixed fixture walks with staggered phases. Start with
  `CAR_FIGHT_SPRITE_COUNT=256 ./scripts/play_monitored.sh --offline --sprite-test`.
  Earlier performance samples below describe the original compact layout.
- Spread-layout validation passed: fast check, 256-position spacing/bounds
  checks at 100% and 200% scale, live sprite combat through all count options,
  and the 256-target two-client replication/late-join/MTU gate. Interactive
  monitored run `20260904-162251` was opened for owner evaluation.

- Session scope: evaluate sprites in Car Fight using the CC0 ghoul pack as
  sample art. This is not a zombie gameplay direction.
- Launch `./scripts/play_monitored.sh --offline --sprite-test`, or use
  `--local --sprite-test` for a local dedicated server/client. The ordinary
  launch stays unchanged; controls are under Debug → Sprite test….
- Eight-direction idle/walk/attack/death sprites support shared, on-demand
  128px/512px atlases, stable foot registration, camera-relative facing, local
  previews, and 1/16/64 server-controlled fixtures.
- Upright capsule hitboxes take three confirmed weapon/area hits to die.
  Swept contact with the actual scaled vehicle capsule kills immediately and
  never changes vehicle velocity. Death removes collision/target eligibility;
  reset restores health. Moving targets use lightweight updates, not rollback
  bodies. Reliable generation-fenced state handles hits, death and late joining.
- `docs/SPRITE_TEST.md` records commands, architecture, focused verification,
  measurements and limits. Source/CC0 metadata and the reproducible packer are
  included with the imported sample.
- Monitored visual runs `20260904-145702` and `20260904-150019` exited cleanly.
  At 16 fixtures, the 128px sample measured 16.68 ms median / 18.82 ms P95 and
  about 11 MiB additional texture memory; 512px used about 91 MiB additional.
  Keep 128px as default. At 64 fixtures, frame cost increased; some fixtures
  were outside the viewport, so this is not an all-visible crowd limit.
- Both runs showed an approximately 6.9-second initial rendering stall before
  warmed sampling. No claim is made about cold-start/network rendering latency.
- Owner accepted the sprite test after single-client runs `20260904-160642`
  and `20260904-161030`; both exited cleanly. Implementation is committed as
  `4a1324b` on canonical `master`. No production deployment occurred.
- Owner visual feedback: the sprites look okay as a proof of concept; more
  directional views and a higher animation frame rate could make them look
  good. Keep these as follow-up evaluation priorities, not completed changes.
- Verification: fast check; sprite asset/animation/capsule tests; live offline
  sprite combat; baseline offline and combat gates; and the 64-target server /
  two-client gate for hit/death replication, late joining and owner controls.
  Movement snapshots are batched to stay below the unreliable packet MTU.

## Accepted checkpoint: ramming lab, vehicle tuning, and scatter props

- Active feature worktree: `/Users/johnnguyen/Projects/car-fight-ramming-gameplay`
  on `codex/ramming-gameplay`, based on `master@cea2a3b`.
- The opt-in `--ramming-lab` starts three server-controlled, ordinary-physics
  vehicle drones on fixed opposing lanes at about six units/second. The Humvee,
  Apocalypse Bus, and LP Car cover separated-wheel, bounded-wheel, and
  body-baked-wheel presentation paths. Recovery occurs only after a bounded
  stall, overturn, off-course interval, or leaving the city.
- The lab isolates vehicle contact by disabling its existing server driver,
  ball, shield drone, and automatic combat. Server contact telemetry records
  the unchanged pre-enhancement collision baseline. The owner accepted the
  lab's traffic and general feel in monitored local runs.
- Vehicle size and mass are independent authoritative spawn properties. The
  compact `Vehicle Tuning…` popup exposes local draft and server-approved
  values, per-model mass defaults/weight classes, reset, collision visibility,
  and explicit `Apply & Respawn`. The reliable prepare/ack/drain replacement
  preserves the same player ID with a fresh generation and avoids stale input
  reaching the replacement path.
- The three lab drones use authoritative 150% model/collider sizing and
  representative masses: Humvee `3.2`, Apocalypse Bus `4.5`, LP Car `1.6`.
  The equal-speed collision gate proves the lighter car receives the larger
  velocity change. Debug collision capsules can be shown for every replicated
  vehicle at once and remain enabled through respawns.
- Twelve server-owned city-pack scatter props now occupy the ramming lanes:
  four barrels, four crates, two tires, and two mailboxes. Their masses range
  from `0.08` to `0.18`, use ordinary rigid-body response and CCD, and replicate
  through stable reserved negative StateBundle routes. Missing local art falls
  back to simple procedural meshes; the city extractor emits the selected
  visual library when the ignored source pack is present.
- Owner acceptance: vehicle tuning/respawn, all-vehicle capsule display, and
  the scatter-prop visual pass were tested interactively and accepted for
  commit.
- Validation passes: `./scripts/check.sh`, focused vehicle tuning, sizing,
  animation, ramming-lab, scatter-prop, city-audition, and StateBundle tests;
  `./scripts/vehicle_size_respawn_test.sh`;
  `./scripts/vehicle_mass_collision_test.sh`; and
  `./scripts/ramming_lab_test.sh`. The last gate replicated all 12 props and
  measured a `7.40` peak scatter speed. Monitored runs through
  `20260903-185440` ended cleanly or were owner-closed after evaluation.
- No deployment was performed or authorized.

Next checkpoint: tune explicit arcade ram response in small accepted steps—head
on first, then side swipe, drift slam, boost ram, and finally bounded airborne
knock-up—while preserving server authority, rollback determinism, mass ratios,
and the chassis/wheel presentation response.

## Completed work: camera tuning and opt-in always-forward experiment

- Merged to `master` from `codex/always-forward-camera` at `48732a2`, originally
  based on `master@b6c2fa0`. The completed worktree was removed after its three
  monitored runs were preserved under
  `.crash-runs/worktree-archive/always-forward-camera/runs/`; the merged branch
  remains as a recovery reference.
- The presentation-only camera experiment remains available but now starts
  disabled after the owner found the rotating-world orientation disorienting.
  Its toggle is deliberately session-only, so saved tuning can never make the
  experimental orientation replace the standard camera on a later launch.
  When enabled it keeps the local vehicle nose returning to screen-up. The first owner pass found that its hard
  22-degree bound forced near-1:1 world rotation and felt disorienting. The
  comfort revision instead uses a 10-degree active-turn soft zone and caps
  camera rotation at 95 degrees/second, then settles fully after the turn.
- Speed-scaled travel look-ahead now has separate acceleration and braking ease
  responses. Simulation, authority, rollback, and wire state are unchanged.
- The native Debug system menu contains an enable/disable comparison toggle and
  a `Camera tuning…` window. Turn catch-up, comfort zone,
  maximum camera turn speed, viewing angle, zoom, orthographic/perspective
  projection, look-ahead distance, acceleration ease, and braking ease update
  live and autosave locally. The comfort revision lowers
  the default pitch from the original 55 degrees to 48 degrees so building
  sides provide a stronger depth cue. Tool-window focus sends neutral controls.
- Gameplay status text and control hints now both start hidden. Separate Debug
  menu checks can restore either during development; browser hints require the
  explicit `hotkeyHints=1` query value.
- Validation passes: `./scripts/check.sh`, `tests/always_forward_camera_test.gd`,
  `tests/always_forward_camera_ui_test.gd`, `tests/sense_of_speed_test.gd`,
  `tests/asset_smoke_test.gd`, `tests/home_world_lighting_test.gd`, and
  `./scripts/offline_test.sh`.
- The owner rejected always-forward world rotation as the default but accepted
  merging it as an opt-in comparison alongside the general camera controls.
  No deployment was performed or authorized.

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
