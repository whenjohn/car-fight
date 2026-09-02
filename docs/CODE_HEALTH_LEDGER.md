# Car Fight code-health evidence ledger

Status: completed audit, validated through `02c4829` and fast-forwarded into
`master` from the original `d949ba7` baseline. A finding remains separate from
permission to change protected gameplay, networking, rollback, transport,
synchronized state, physics, or rendering behavior.

## Status meanings

- **Approved**: owner approved a bounded cleanup implementation.
- **Resolved**: implemented and validated on the cleanup branch.
- **Hold**: evidence is incomplete or the change belongs behind safer work.
- **Retain**: complicated or historical material with an identified purpose.

## Findings

### CH-001 — Per-commit full-suite policy

- Classification: excessive process cost.
- Evidence: `AGENTS.md` required `./scripts/test.sh` before every commit. That
  runner starts 32 GDScript checks and 13 runtime/network/lifecycle gates after
  import, including systems unrelated to most localized changes.
- History: the runner began in `a503d8c`; focused tests and runtime gates were
  appended as features accumulated.
- Decision: use risk-based focused gates and reserve the complete suite for
  high-risk integration, deployment/release, accumulated cleanup boundaries,
  or explicit owner requests.
- Validation: fast structural check, symlink verification, and diff review.
- Status: **Resolved** by `ece1668`.

### CH-002 — Duplicated and inconsistent Godot import verification

- Classification: duplicate implementation and quality-gate defect.
- Evidence:
  - `scripts/test.sh` performs one editor pass and rejects errors from that
    pass.
  - `scripts/server_daemon.sh import`, `scripts/web_build.sh`, and the new
    `scripts/check.sh` perform two passes because a fresh netfox checkout can
    register plugin globals during the first pass.
  - On a genuinely fresh cleanup worktree, the first pass returned exit zero
    while printing 11 parse/compile/load-error matches; the second pass had
    none.
- History: the one-pass runner dates to `a503d8c`; deployment gained its
  two-pass guard in `12ac367`; Web build added a separate copy in `578ab7a`.
- Change: one quiet `scripts/godot_import_check.sh` is used by the fast,
  full-suite, deployment, and Web-build paths. Keep caller-specific export and
  runtime behavior outside the helper.
- Validation: `scripts/check.sh`, `scripts/server_daemon.sh import`, a bounded
  Web debug export, shell syntax, and diff checks. Do not run gameplay/network
  gates because no game behavior changes.
- Risk/rollback: low; failure reporting and the known two-pass requirement must
  remain visible. Revert the single cleanup commit if any caller loses its
  import failure signal.
- Result: `scripts/check.sh`, `scripts/server_daemon.sh import`, and a bounded
  Web Offline debug export all pass. The broad gameplay/network suite was not
  run because no game behavior or runtime gate changed.
- Status: **Resolved** on this branch; validation is recorded in the commit.

### CH-003 — Orphan Godot UID sidecars

- Classification: definitely dead metadata.
- Evidence: `tests/arena_layout_test.gd.uid`, `tests/arena_ball_test.gd.uid`, and
  `tests/overcast_world_test.gd.uid` had no corresponding resource. Their base
  tests were removed by the city-only resurrection in `7027700`/`3ccd8fe`.
  No current scene, resource, script, or test runner referenced the sidecars.
- Validation: repository-wide UID/base check and two-pass import.
- Status: **Resolved** by `ece1668`.

### CH-004 — Obsolete course/gate result metrics

- Classification: obsolete diagnostic output, pending external-contract check.
- Evidence: `Main.gd` still emits `coursemaps`, `courseoff`, and
  `gatetransitions`. Their three helper functions always return zero after the
  city-only resurrection removed the course and gates. Current tracked scripts
  do not read these fields.
- History: the helpers came from `9f219c5`; `3ccd8fe` replaced their behavior
  with constant zero to preserve the established result line while removing
  the old worlds.
- Proposed change: remove the three output fields and helpers only after
  confirming no external automation parses the complete `RESULT` schema.
- Validation: fast check plus the smallest server result-producing gate and
  its parser assertions.
- Risk/rollback: low internally, but unknown external log consumers may depend
  on the stable field names.
- Result: local source and automation contain no consumer, but the deployed
  macai2 checkout still contains a historical `scripts/gate_test.sh` that
  parses all three fields. The same checkout's current city-only `Main.gd`
  always reports them as zero, so that historical gate is already incompatible
  with the accepted world; it must not be silently treated as a live gate.
- Status: **Retain** until stale deployed files are reconciled and the external
  result-line contract is deliberately retired.

### CH-005 — Oversized application coordinator

- Classification: excessive complexity, but intentional integration behavior.
- Evidence: `Main.gd` is 4,072 lines. It combines CLI parsing, process modes,
  ENet/WebRTC startup, world and lighting construction, HUD/menu persistence,
  test fixtures, combat services, RPCs, and telemetry. `_parse_args()` alone is
  344 lines.
- Proposed change: first characterize argument parsing and one low-coupling
  boundary. Extract one responsibility per commit without changing node paths,
  RPC names, authority, state, or runtime ordering.
- Characterization: the focused offline smoke now locks the server `RESULT`
  report's exact 32-field names and order before its formatting is separated
  from the coordinator.
- Change: the stable field order and numeric formatting now live in
  `diagnostics/server_result.gd`; `Main.gd` still owns when the report is
  emitted and how every metric is collected.
- Validation: depends on the extracted boundary; shared authority or RPC work
  requires the relevant network gate and the complete suite once before merge.
- Risk/rollback: high. File size alone is not deletion or rewrite evidence.
- Result: the pure formatter test and focused offline smoke pass with the exact
  prior result schema. This completes one low-coupling boundary without moving
  gameplay, authority, RPC, or transport behavior.
- Status: result-report boundary **Resolved** on this branch; argument parsing
  and any broader coordinator extraction remain **Hold** for separate
  characterization and review.

### CH-006 — Volatile agent state contains archived workstreams

- Classification: obsolete instructions and documentation complexity.
- Evidence: `.ai/CURRENT_PHASE.md` is 875 lines. Current canonical state ends
  near its first 50 lines; the remainder is explicitly marked archived but
  contains old “Next” directions for removed arena/course worlds and historical
  feature worktrees.
- Change: retain only canonical state, active work, and immediate next
  actions in `CURRENT_PHASE.md`; move the existing archive intact to a history
  document so no evidence is lost.
- Validation: link/reference review and `git diff --check` only.
- Risk/rollback: low if history is moved rather than deleted.
- Status: **Resolved** on this branch. The former file is preserved at
  `docs/history/CURRENT_PHASE_THROUGH_2026-09-02.md`.

### CH-007 — Missing active-project registry/context wiring

- Classification: agent scaffolding defect.
- Evidence: `cc-projects info car-fight` fails. `projects.json` contains only
  the archived `car-fight-unity` entry, and active Car Fight lacks the required
  `.ai/CONTEXT.md`. Its `.ai` is a tracked directory rather than the usual
  `claude-comms` symlink.
- Change: add a short stable context index and register the active Godot
  repository, then decide separately whether to migrate `.ai` into
  `claude-comms`. Preserve all tracked history during any migration.
- Validation: project resolution, symlink/status checks, and clean Git state in
  both repositories.
- Risk/rollback: medium because changing `.ai` storage affects multiple agent
  clients and concurrent worktrees.
- Result: `.ai/CONTEXT.md` provides the stable architecture/index. The command
  `cc-projects info car-fight` resolves the active Godot repository and its
  cleanup worktree, and `car-fight-unity` is marked archived. The registry
  change is recorded in `claude-comms` commit `234335f`.
- Status: **Resolved** for context and registry repair; **Hold** for converting
  `.ai` to a shared symlink.

### CH-008 — Historical branch clutter

- Classification: repository housekeeping.
- Evidence: more than twenty local feature branches are already merged into
  `master`; six unmerged diagnostic branches preserve abandoned Intel-renderer
  investigations. `GODOT_46_TO_47_HISTORY.md` explicitly names several refs as
  recovery evidence, and the private `car-fight-archives` repository preserves
  worktree bundles.
- Change: `docs/BRANCH_LEDGER.md` records every keep class, 20 merged local
  cleanup candidates, 20 merged remote candidates, both active worktrees, and
  the boundary of the verified private cleanroom archives. No ref was deleted.
- Validation: compare merged status, tags, remote refs, and documented commit
  IDs before and after cleanup.
- Risk/rollback: branch deletion can remove convenient recovery names even when
  commits remain reachable elsewhere.
- Status: inventory **Resolved** on this branch; deletion **Hold** pending a
  separate destructive-action approval and a fresh ancestor check.

### CH-009 — Deployment retains removed project files

- Classification: stale deployment content and operational correctness risk.
- Evidence: the former `scripts/deploy_macai2.sh` used rsync without `--delete`.
  A read-only comparison found 33 files under
  `/Users/macai2/Projects/car-fight` that no
  longer exist in the canonical repository, including removed arena, driving
  course, elevated course, jump-gate, overcast-world, and occlusion-hint code,
  tests, and launchers. `scripts/gate_test.sh` is one of those leftovers.
- History: the city-only resurrection in `7027700`/`3ccd8fe` intentionally
  removed these worlds and tests; later deployment copied current files without
  reconciling removed paths.
- Change: the deployment helper now defaults to a dry-run deletion preview,
  requires an explicit `apply`, preserves
  explicit runtime/cache/local-asset exclusions, previews deletions, and removes
  only files absent from the canonical deployment source. The read-only preview
  verified the exact 33-file inventory plus two empty directories on
  macai2; applying it remains a separate owner-approved operation.
- Validation: rsync dry-run/deletion manifest, remote service status before and
  after, current file-list comparison, native connection smoke, and browser
  connection smoke. Deployment remains a separate explicit operation.
- Risk/rollback: high operational impact. A broad `--delete` can remove remote
  state or locally supplied assets unless exclusions and targets are exact.
- Status: deployment guard **Resolved** on this branch; remote cleanup **Hold**
  pending review of the generated manifest and explicit approval to apply it.

### CH-010 — Full-suite GDScript manifest is manually maintained

- Classification: quality-gate drift risk.
- Evidence: `scripts/test.sh` lists every focused GDScript test manually. All
  current `tests/*_test.gd` files are listed, but adding a new test file does not
  mechanically require adding it to the comprehensive suite.
- Proposed change: make the fast structural check compare the test files with
  the full-suite manifest without executing them. Continue selecting only
  focused tests during ordinary work.
- Validation: fast check, plus a bounded negative control proving an omitted
  test name is reported.
- Risk/rollback: low; the rule must exclude helper/replay scripts that are not
  standalone `*_test.gd` programs.
- Status: **Resolved** on this branch. The structural check covers all 33
  current standalone GDScript tests without executing them.

### CH-011 — Authority-probe gates cannot receive queued samples

- Classification: pre-existing network-test correctness defect.
- Evidence: the pre-merge suite and two focused reruns of
  `scripts/network_test.sh` produced no client `CORRECTION` lines. The matching
  `scripts/mixed_transport_test.sh` assertion also reported a missing sample.
  Both focused gates fail identically on untouched `master@d949ba7`.
  `_send_settled_authority_probes()` appends samples to
  `_authority_probe_queue`, but the current repository contains no consumer of
  that queue and therefore no call that delivers those samples to
  `_receive_authority_probe()`.
- History: determine when the queue consumer was removed or stopped running
  before changing delivery timing or RPC behavior.
- Proposed change: handle as a separate networking bugfix. Restore or replace
  the intended delayed delivery seam, then prove same-tick coverage under ENet
  and mixed ENet/WebRTC transport without changing simulation authority.
- Validation: focused `network_test.sh` and `mixed_transport_test.sh`, followed
  by late-join and reconnect gates; run the complete suite once at that
  bugfix's integration boundary.
- Risk/rollback: high. Authority-probe delivery is diagnostic, but its timing
  crosses rollback and transport behavior.
- Status: **Hold** for a separate characterized networking fix; not caused or
  changed by this cleanup branch.

### CH-012 — Redundant city-only world-build wrapper

- Classification: definitely dead indirection in the world/spawn layer.
- Evidence: `_build_home_world()` was introduced by the city-only resurrection
  in `3ccd8fe`. It contains only `_build_city_space()`, has one direct caller in
  `_build_world()`, has no signal, callable, string, scene, or dynamic entry
  point, and cannot select another world.
- Change: call `_build_city_space()` directly and make the focused world test
  preserve that direct city-only contract rather than the obsolete wrapper.
- Validation: fast structural/import check, `home_world_lighting_test.gd`, then
  owner play through monitored local server/client world startup before commit.
- Risk/rollback: very low; call order and city construction are unchanged.
- Result: focused world/import checks passed. The first offline visual run
  correctly exposed missing ignored local art in the cleanup worktree; after an
  independent local-art copy and import, the owner confirmed the complete city
  and server-generated dots in a monitored local server/client run. The monitor
  ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-013 — Offline mode does not seed dots

- Classification: pre-existing gameplay-mode wiring defect discovered during
  the world/spawn play check.
- Evidence: the monitored offline run loaded the city scene but displayed no
  dots, and its log contained no `DOTS gen` event. `_start_server()` calls
  `_dots.generate()`, while `_start_offline()` does not. The focused dots test
  invokes `generate()` directly, so it does not cover offline startup wiring.
- Proposed change: handle as a separate gameplay bugfix after the current
  behavior-neutral cleanup slice. Add startup characterization, seed the same
  deterministic 72-dot set in offline mode, and confirm collection/rendering.
- Validation: focused dots test, offline startup test, and owner offline play
  through dot visibility and collection.
- Risk/rollback: medium; dot authority, score state, and RPC behavior must remain
  unchanged for server/client play.
- Status: **Hold** for a separate owner-approved gameplay bugfix; not caused by
  the current cleanup change.

### CH-014 — Removed-landmark code leaves a no-op tree selector

- Classification: definitely dead world presentation and UI code.
- Evidence: `_add_proximity_landmark()` has no caller after the city-only
  resurrection. It is the only function that can populate `_tree_landmarks`,
  so `_rebuild_tree_visuals()` always iterates an empty array and the Scenery
  menu's Tree model choices cannot change anything. The accepted city street
  trees are built independently by `world/city_audition.gd` with fixed
  Collection 121–130 art.
- Change: remove the unreachable proximity landmark/tree builders, their dead
  state and environment option, and the no-op Tree model menu section. Retain
  `tree_visual_library.gd` because the live city presentation uses it.
- Validation: city audition, tree visual library, home-world lighting, fast
  structural/import checks, then owner play verification that city trees remain
  visible and the Scenery menu contains only working lighting controls.
- Risk/rollback: low; no live node can reach the removed path. Revert this slice
  if the city lining or lighting menu changes unexpectedly.
- Result: all three focused world/presentation tests and the fast check pass.
  The owner confirmed the city street trees remain visible, the dead Tree model
  section is gone, and the retained lighting controls work in monitored local
  server/client play. The monitor ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-015 — Off-map local prop audition still loads at runtime

- Classification: obsolete presentation experiment and avoidable startup work.
- Evidence: the 2026-08-30 prop audition has one caller and no gameplay,
  collision, network, menu, or dynamic entry point. It builds optional local
  meshes at `(100, 0, -210)`, beyond the accepted city wall at `z=-165`; the
  player cannot reach or normally see them. Its only other consumer is its own
  implementation test. The city-only resurrection retained it but did not move
  it into the accepted district.
- Change: remove the Main loader/call, audition implementation and self-test,
  and stale foliage README claims. Retain ignored source art and the unrelated
  city/tree assets.
- Validation: city audition and home-world lighting tests, fast manifest/import
  checks, then owner local play verification that the accepted city is visually
  unchanged.
- Risk/rollback: low; the removed nodes are presentation-only and off-map.
- Result: focused city, lighting, import/manifest, UID, and diff checks pass.
  The owner confirmed the accepted city, street trees, dots, driving, and
  lighting remain normal in monitored local server/client play. The monitor
  ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-016 — Retired tree selector leaves unused art families and tracked source

- Classification: obsolete presentation experiment, code complexity, and
  repository/import weight.
- Evidence: the accepted city calls only Collection 121–130 from the optional
  owner-supplied local pack. After CH-014 removed the no-op Tree model selector,
  no runtime caller can select the five other collection families or the three
  Shapespark families; only the general-purpose library's self-test exercises
  them. The unreachable Shapespark package contains 47 tracked files, including
  23 Git LFS payloads, and occupies 37 MB in a checkout. `Main.gd` also retains
  a second tree-library preload with no caller.
- History: Shapespark was added in `2f6fc30` as an optional audition selectable
  through the former Scenery menu. The city-only resurrection fixed the live
  street lining to Collection 121–130, and CH-014 removed the last selector.
- Change: reduce the tree library and its test to the accepted Collection
  121–130 contract, remove the unused Main preload, retire the tracked
  Shapespark source/import metadata/license and now-empty LFS attributes, and
  update the foliage note. The removed CC0 source remains recoverable from Git
  history.
- Validation: all ten accepted collection variants, city presentation, home
  lighting, two-pass import/manifest/UID checks, and owner local play through
  the complete street-tree lining.
- Risk/rollback: low but visually significant; the city still uses the same
  source meshes, normalization, placement, rotation, and shadow policy. Revert
  this slice if any accepted street tree changes or disappears.
- Result: focused tree, city, lighting, import/manifest, UID, and diff checks
  pass. The owner confirmed the complete street-tree lining remains present and
  unchanged alongside normal city, dots, driving, and lighting in monitored
  local server/client play. The monitor ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-017 — Removed elevated course leaves arbitrary-rotation box wrapper

- Classification: definitely dead world-construction indirection.
- Evidence: `_add_static_oriented_box()` was introduced in `58f6f9c` for the
  former launch ramp and upper roads. Those were removed by the city-only
  resurrection. Its only remaining caller is `_add_static_box()`, which merely
  converts its yaw to `Vector3(0, yaw, 0)` and forwards every argument.
- Change: keep the live yaw-only helper and move the unchanged static-body,
  collision, and optional presentation construction into it.
- Validation: city presentation/lighting and fast import checks, the focused
  reverse/wall collision gate, then owner driving verification against city
  buildings and walls.
- Risk/rollback: very low; node construction and order are unchanged, and the
  same yaw vector is assigned directly.
- Result: city presentation, lighting, fast import/manifest/UID, diff, and the
  focused reverse/wall collision gate pass. The first reverse-gate attempt was
  sandbox-blocked from opening ENet; its required unrestricted rerun passed.
  The owner confirmed normal collision against a city building and outer wall,
  and the monitored local server/client run ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-018 — Removed gates leave rollback and correction-schema state

- Classification: obsolete state with protected compatibility implications.
- Evidence: `gate_cooldown` and `gate_transition_count` remain registered
  rollback state after the sole-city resurrection removed jump gates. The
  associated `_last_map_transition_tick` is never written, so
  `correction_map_transition_age()` always returns `-1`; nevertheless Main's
  correction samples and `CorrectionClassifier` still carry and classify the
  map-transition field. Main also resets `gate_cooldown` during its surviving
  city recovery path.
- Proposed change: retire this only with explicit rollback-state and diagnostic
  schema review, alongside CH-004's obsolete result fields and the stale
  deployed gate consumer. Do not mix it into behavior-neutral cleanup.
- Validation: state-schema characterization, focused correction-classifier and
  recovery tests, native/mixed transport gates, and a full integration boundary.
- Risk/rollback: high; removing apparently dormant variables changes registered
  synchronized state and potentially external diagnostic contracts.
- Status: **Hold** for a separately characterized state/schema cleanup.

### CH-019 — Uncalled player helper methods

- Classification: definitely dead code and stale architecture comment.
- Evidence: repository-wide symbol and string-call searches find no caller for
  `GroundVehicleHull.model_scale_multiplier()`,
  `PlayerBody.area_gesture_preview()`, or `PlayerBody._current_network_tick()`.
  Their live state is consumed through the scale setter/backing value, direct
  gesture fields, and Main's correction sampler respectively. The hull header
  also describes the former sphere rather than the accepted capsule collider.
- Change: remove only the three orphan methods and correct the comment. Preserve
  all fields, setters, rollback registration, gesture behavior, input, movement,
  and diagnostic sampling.
- Validation: vehicle animation/assets, area weapon, correction classifier,
  fast import/manifest/UID checks, then owner play through normal driving and
  one vehicle-cycle/area-target smoke.
- Risk/rollback: very low; no executable path references the removed methods.
- Result: focused vehicle animation/assets, area weapon, correction classifier,
  fast import/manifest/UID, and diff checks pass. The owner confirmed normal
  driving, vehicle cycling, and the area-target gesture in monitored local
  server/client play. The monitor ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-020 — Uncalled shield-drone aiming method

- Classification: definitely dead combat-presentation code.
- Evidence: repository-wide symbol and string-call searches find no caller for
  `ShieldDrone.aim_at()`. Main owns drone target selection and projectile
  authority and calls only `muzzle_position()`; the fixture has never rotated
  through this method in the current runtime path.
- Change: remove the orphan method only. Preserve targeting, fire cadence,
  muzzle position, bolt state, shield interactions, and current presentation.
- Validation: shield-drone asset/contract check, focused shield runtime gate,
  fast import/manifest/UID checks, then owner play through one drone shot and
  shield interaction.
- Risk/rollback: very low; no executable path references the method.
- Result: shield-drone presentation/assets, focused shield runtime behavior,
  fast import/manifest/UID, and diff checks pass. The owner confirmed the
  west-clearing drone shot and shield interaction remain normal in monitored
  local server/client play. The monitor ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-021 — Accepted-state documentation describes removed systems

- Classification: stale user and maintainer documentation.
- Evidence: README still advertised the retired tree selector and off-map prop
  audition, described the former 168-unit arena and sphere collider, claimed
  the suite tested removed ramps, and described shaped play as removing those
  ramps. Nearby UI, player, WebRTC-harness, and tree-test comments also used
  arena/audition/map-gate/upper-road terminology for current city-only paths.
- Change: update wording to the accepted 330-unit city, fixed optional tree
  lining, five lighting presets, capsule collider, current suite, and flat
  expanded-city shaping route. No command, assertion, constant, or runtime code
  changes.
- Validation: stale-term search, shell syntax through the fast check, and diff
  review. Rendered play is unnecessary for comments/documentation only.
- Risk/rollback: minimal; preserve historical terms in the evidence documents
  that intentionally describe old incidents.
- Result: fast import/syntax/manifest/UID and diff checks pass, and an exact
  search finds none of the replaced stale claims.
- Status: **Resolved** on this branch; no rendered check required for prose and
  comments only.

### CH-022 — Dormant network fault-injection and failure-log seams

- Classification: apparently obsolete test code at a protected boundary.
- Evidence: the StateBundle stale-key, delayed-envelope, and key-suppression
  setters have no current repository caller, as does WebRTC's expected-failure
  logging setter. Their backing fields and branches remain embedded in recovery,
  coalescing, delayed release, and failure handling from the G2 stack port.
- Proposed change: trace the original G2 gates and confirm no external/manual
  harness contract before removing the complete seams. Do not leave permanently
  false branches by deleting only their setters.
- Validation: focused StateBundle recovery/coalescing and WebRTC lifecycle
  characterization, reconnect/join gates, and the complete integration boundary.
- Risk/rollback: high relative to ordinary cleanup because the branches sit in
  protected stale-history recovery and transport failure paths.
- Status: **Hold** for separate historical characterization.

### CH-023 — Uncalled network telemetry/query getters

- Classification: definitely dead API surface.
- Evidence: repository-wide symbol and string-call searches find no caller for
  `MuxMultiplayerPeer.peer_uses_webrtc()`, `has_webrtc_peer()`, or
  `StateBundle.peer_divisor()`. They are not MultiplayerPeer virtual overrides.
  The live `has_enet_peer()` send guard, generic transport ownership query,
  first-peer lookup, internal `_divisor_for()`, and cadence telemetry remain.
- Change: remove only the three side-effect-free getters. Preserve transport
  ownership/lifecycle, routing, cadence decisions, fields, and wire behavior.
- Validation: focused mux and StateBundle cadence tests, fast import/manifest/
  UID checks, then owner normal ENet play verification.
- Risk/rollback: low; no executable path references the removed methods, but
  this remains inside the protected network layer.
- Result: focused StateBundle coalescing, state codec, remote-position transport,
  fast import/manifest/UID, and diff checks pass. The owner confirmed normal
  ENet join, driving, city objects, and networked interactions in monitored
  local server/client play. The monitor ended cleanly.
- Status: **Resolved** on this branch with owner play approval.

### CH-024 — Obsolete world-study launcher configuration

- Classification: redundant script and no-op harness configuration.
- Evidence: `play_sunlit_aerial.sh` originally selected lighting style 4 and
  the city study map, but the city-only resurrection removed both selections;
  the remaining wrapper merely launched ordinary monitored offline play under
  a historical name. `CAR_FIGHT_NO_RAMPS` also remained in two shaped-network
  client environments after ramp construction and its environment parser were
  removed. Repository-wide searches find no remaining reader or caller.
- Change: remove the redundant study wrapper and the two no-op environment
  assignments. Retain the Networking 1, Networking 2 mixed, and shaped local
  one/two-client harnesses because each remains a distinct direct-entry manual
  diagnostic even when no other tracked script calls it.
- Validation: shell syntax for every retained script, two-pass import,
  test-manifest/UID/diff checks, and an exact stale-token search. No gameplay,
  network argument, process topology, or runtime behavior changes.
- Risk/rollback: very low; generic offline play remains available through
  `play_monitored.sh --offline`, while the deleted wrapper no longer supplied
  either feature named by it.
- Status: **Resolved** on this branch; rendered play is unnecessary for a
  redundant wrapper deletion and removal of unconsumed environment values.

### CH-025 — Shared agent policy describes superseded gameplay state

- Classification: stale project scaffolding and test wording.
- Evidence: `AGENTS.md` still called the gameplay collider a sphere and framed
  weapons and the G2 transport/bundle stack as things not yet added. Ordinary
  play now defaults to the accepted horizontal equal-mass capsule, while
  bounded weapons and an opt-in G2-derived lab profile already exist. Because
  `CLAUDE.md` is a relative symlink to `AGENTS.md`, the stale statements reached
  both Claude and Codex. One FOLLOW assertion failure also retained the old
  sphere wording even though its numeric yaw bound is collider-independent.
- Change: correct the shared policy to the accepted capsule and make its scope
  guard apply to new weapons/systems and expansion of the existing lab stack;
  correct only the assertion message. Preserve the relative `CLAUDE.md` symlink
  so the two clients cannot silently drift.
- Validation: verify the symlink target/content, run the unchanged FOLLOW
  assertions, the fast import/manifest/UID checks, and diff review.
- Risk/rollback: minimal; instructions and one failure string change, with no
  assertion, constant, parser, scene, or runtime behavior modified.
- Status: **Resolved** on this branch; no rendered play is required.

### CH-026 — Completed plans presented as current session direction

- Classification: stale agent routing and project documentation.
- Evidence: the Forward+ merge plan still said it was approved and unapplied;
  the Web roadmap said remote/TURN and production work had not started; the
  Networking 1/2 plans still called the capsule harness-only and directed later
  sessions to integrate it. Active README/context links described those dated
  plans as the next roadmap despite the accepted capsule, completed forced-TURN
  soak/two-player work, and deployed ENet/WebRTC mux baseline.
- Change: preserve every investigation document and its dated details, but add
  explicit historical/superseded banners; route current sessions through the
  README and stable context; replace obsolete README failure status with the
  recorded accepted soak/two-player results. Public browser hosting/TURN and
  opt-in combined/adaptive experiments remain clearly unfinished.
- Validation: link/command review, exact current-status searches, and
  `git diff --check`. No scripts, assertions, scenes, or runtime code change.
- Risk/rollback: minimal; historical results stay intact and only their active
  interpretation/routing changes.
- Status: **Resolved** on this branch; no runtime validation is required.

### CH-027 — Final tests, tools, and tracked-asset reachability audit

- Classification: retained live coverage and project support material.
- Evidence: all 32 `tests/*_test.gd` files exercise a current production
  contract or the deliberately retained CH-004/CH-018 compatibility seams;
  `net/state_codec_selftest.gd` covers the wire codec. The city extractor and
  vehicle-animation lab both have documented direct entry points, and the lab
  also has contract coverage. Every tracked runtime asset outside metadata and
  license files has a direct `res://` consumer. The large monitored-play
  harness remains cohesive crash-safety tooling with a documented collector
  and focused lifecycle test.
- Decision: retain these tests, tools, assets, and safety harnesses. Do not add
  splits or wrappers merely to reduce file length; no duplicate executable
  contract or unreachable tracked asset was found.
- Validation: all 33 focused GDScript contracts (the 32 test files plus the
  state codec self-test) pass. All 11 currently green runtime/lifecycle gates
  pass once: WebRTC harness lifecycle, offline, late join, reconnect, ball,
  tractor, reverse, combat, RC orb, shield, and det.
- Known debt: `network_test.sh` and `mixed_transport_test.sh` were deliberately
  not rerun at this boundary. Their missing authority-probe delivery is CH-011
  and was already reproduced identically on untouched `master@d949ba7`; hiding
  or weakening their assertions is not part of cleanup.
- Status: **Retain**; the layer-by-layer code-health audit is complete.
