# Car Fight context

This is the stable read-first index for active Car Fight development. Volatile
status and immediate next work belong in `.ai/CURRENT_PHASE.md`; completed and
superseded work belongs in `docs/history/` or the named investigation document.

## Project identity

- Canonical repository: `/Users/johnnguyen/Projects/car-fight`.
- Engine baseline: Godot 4.7.1, Compatibility renderer, Rapier 0.8.39.
- Product baseline: server-authoritative multiplayer vehicle combat in Low Poly
  City, the sole authoritative world and map ID `0`.
- Native clients use ENet. Browser clients use WebRTC through the server-side
  mux. macai2 hosts the isolated production service.

`AGENTS.md` contains mandatory safety and workflow rules. This file explains
where responsibilities and deeper evidence live; it does not override those
rules.

## Architecture map

- `Main.gd`: application coordinator, command-line process modes, networking
  lifecycle, world construction, server services, UI/HUD, RPCs, and test
  telemetry. Its size is known debt; do not split it without characterization
  coverage and a bounded extraction plan.
- `player/follow_controller.gd`: deterministic FOLLOW steering and handling
  math. Add a focused regression before changing movement behavior.
- `player/player_body.gd`: authoritative/predicted rigid-body integration and
  rollback state. The gameplay collider is the accepted horizontal capsule;
  vehicle meshes and animation are presentation only.
- `player/ground_vehicle_hull.gd`, `fx/`, and `ui/`: client presentation. Never
  feed presentation state back into deterministic simulation.
- `net/`: codec, StateBundle, remote-position, WebRTC, and mux behavior.
  Network/rollback/transport changes require their historical evidence and
  focused multi-path tests.
- `world/` and `combat/`: city/world services and bounded gameplay object
  families. Classify every new family by replication cost before adding it.
- `addons/netfox*`: vendored netfox with Car Fight/G2 lifecycle and stale-history
  patches. Preserve the patches and their reconnect/join gates during updates.
- `scripts/`: local, remote, browser, deployment, and test harnesses.
- `tests/`: fast GDScript behavior/contract checks. Larger runtime gates remain
  as named shell scripts under `scripts/`.

## Validation

- `./scripts/check.sh`: quiet two-pass import, shell/Node syntax, complete-suite
  test-manifest coverage, orphan UID, and staged/unstaged diff checks.
- `docs/QUALITY_GATES.md`: choose the smallest tests that cover a change.
- `docs/NETWORK_SAFE_GAMEPLAY.md`: required before gameplay/input/lifecycle or
  replicated-state work. Covers authority, replay safety, bounded cost, real
  schema tests, and distinguishing connection problems from processing stalls.
- `./scripts/test.sh`: expensive comprehensive milestone gate; do not run it
  after every localized change.
- Rendered validation must use the monitored safe-window wrappers and requires
  explicit approval.

## Documentation routing

- `README.md`: supported play, build, networking, and deployment commands.
- `CODE_HEALTH_CLEANUP_PLAYBOOK.md`: cleanup authorization boundaries and
  evidence workflow.
- `docs/CODE_HEALTH_LEDGER.md`: active cleanup findings and disposition.
- `GODOT_46_TO_47_HISTORY.md`: required history for engine, renderer, lighting,
  Rapier, cache, or world-architecture work.
- `MAC_INTEL_FULLSCREEN_FINDINGS.md`: affected Intel Mac display/GPU evidence
  and the ordinary-window safety policy.
- `MIGRATION_TO_UNITY.md`: superseded Unity migration decision.
- `NETWORK_SHAPING_FINDINGS.md`: transport, rollback, presentation, impairment,
  reconnect-soak, and two-player acceptance evidence.
- `docs/NETWORKING_REVIEW_2026-09-04.md`: current networking audit and packed-input
  implementation evidence; known lifecycle and cross-platform validation gaps.
- `NETWORKING_1_NEXT_STEPS.md`, `NETWORKING_2_PLAN.md`, and
  `WEB_PLATFORM_PLAN.md`: historical execution plans; never treat their old
  baselines or “next” sections as current authorization.
- `VEHICLE_ANIMATION_LAB.md`: presentation-only vehicle animation workflow.
- `docs/history/CURRENT_PHASE_THROUGH_2026-09-02.md`: archived session history;
  never treat its old “Next” sections as current authorization.

## Stable constraints

- Preserve server authority, input ownership, rollback behavior, RPC/state
  schema, netfox patches, and native/Web transport separation unless a scoped
  task explicitly authorizes changing them.
- Keep Godot 4.7.1 Compatibility, Rapier 0.8.39, SSAO off, and directional
  shadows off on this Intel machine.
- Use an ordinary decorated inset window; never launch native fullscreen,
  borderless fullscreen, or edge-to-edge presentation.
- Keep licensed local audition assets under ignored `assets/local/`; tracked
  source assets must retain license/source metadata and clean-checkout fallback
  behavior.
- Cleanup, optimization, gameplay, and visual tuning are separate workstreams.
  A shorter implementation is not a measured performance improvement.
- Treat networking quality as a gameplay integration constraint, not only a
  transport concern. Measure actual encoding, simulation cost, and state age;
  enabled flags or a harness PASS are not proof of correct or smooth play.
