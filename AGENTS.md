# Car Fight project notes

This is the canonical Godot 4.7.1 Compatibility + Rapier 0.8.39 project. The
completed Godot 4.6.3 Forward+ experiment is historical, not the next migration.
Read `GODOT_46_TO_47_HISTORY.md` before changing the engine, renderer, shadows,
SSAO, caches, world architecture, or Rapier version. Keep changes small and
auditable.

Before any broad code cleanup, dead-code removal, simplification campaign, or
agent-led refactor, read `CODE_HEALTH_CLEANUP_PLAYBOOK.md`. Begin with its
read-only evidence ledger; cleanup is not authorization to rewrite gameplay,
networking, rollback, transports, or synchronized state.

- Run with `/Applications/Godot47.app/Contents/MacOS/Godot`.
- On this Intel Mac, keep Compatibility rendering, SSAO off, and directional
  shadow maps off. The default sunlit grade uses the stable positional shadow.
- Server authority and ENet lifecycle live in `Main.gd`.
- Deterministic FOLLOW math lives in `player/follow_controller.gd`; presentation must not affect it.
- Player input authority belongs to its owning client; body/state authority stays with server peer 1.
- Vendored netfox carries the four-file G2 D-040 stale-history patch plus the
  detached-input lifecycle guard in `BaseNetInput`. Preserve/reapply both when
  updating netfox; `scripts/join_transient_test.sh` and
  `scripts/reconnect_test.sh` gate them. Never accept a client that retries
  rollback older than `history_start` or queries authority from a detached
  input node.
- Do not port G2's half-handshake-RTT initial time seed. In Car Fight's 120 ms
  two-client A/B it caused 3.16-3.46 unit startup corrections in two of three
  runs; the unseeded control passed three of three at 1.178 units or less.
- The Jeep and turret are presentation only. The equal-mass sphere is the gameplay collider.
- Do not add weapons, damage, resources, bots, maps, or g2's custom transport/bundle stack without a new explicit scope decision.
- Do not make every new gameplay object a rollback-synchronized body by
  default. Before adding an object family, classify it as static/seeded,
  event-driven, lightweight replicated, or full rollback state, then add a
  representative object-count load gate. G2 proved that per-body history,
  wire fan-out, scripting, and presentation costs can make a larger world
  chug even when a small peer-only test is smooth.
- Add a focused regression before changing movement or collision behavior.
- Before committing code or script changes, run `./scripts/check.sh` plus the
  smallest focused tests that cover the changed behavior. Use
  `docs/QUALITY_GATES.md` to select them and report why they are sufficient.
- Do not run `./scripts/test.sh` after every small change. It is the broad
  milestone gate: reserve it for high-risk integration, deployment/release
  checkpoints, accumulated cleanup boundaries, or an explicit owner request.
  Do not rerun a passing gate unless relevant code changed. If a
  timing-sensitive gate fails, rerun that isolated gate once and record a
  recurring failure as test debt instead of restarting the complete suite.
- Use Tailscale (`ssh macai2-ts`) for macai2. This server owns UDP 10080 and launchd label `com.whenjohn.car-fight-server`.
- On the affected Intel Mac, never launch Godot in native fullscreen,
  borderless fullscreen, an exact edge-to-edge window, or edge-to-edge
  maximization. Use an ordinary decorated window inside the usable desktop;
  use `./scripts/play_monitored.sh` for any approved agent-initiated rendered
  run. `./scripts/play_macai2_two.sh` is the approved two-native-client wrapper
  around that monitor, but its first trial saturated both client cores and was
  not valid networking-feel evidence. An unfocused live client must emit
  neutral controls. Do not repeat OpenGL, ANGLE, Vulkan, or edge-coverage
  diagnostics merely to reconfirm them. Read
  `MAC_INTEL_FULLSCREEN_FINDINGS.md` before changing display policy.
