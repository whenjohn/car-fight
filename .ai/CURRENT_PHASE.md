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

Validation for the import-verifier cleanup:

- `./scripts/check.sh` passes.
- `./scripts/server_daemon.sh import` passes.
- A bounded Web Offline debug export passes.
- The complete gameplay/network suite was not run because the change affects
  validation tooling only.

## Next

1. Decide separately whether tracked `.ai` state should move into the shared
   `claude-comms` symlink model; preserve history and account for concurrent
   worktrees before changing storage.
2. Reconcile the 31 stale files retained by macai2 deployment only after an
   exact deletion manifest and separate owner approval. Its old `gate_test.sh`
   still consumes the constant-zero course/gate `RESULT` fields, so retain that
   output contract until deployment state is resolved.
3. Produce a keep/delete ledger for merged and diagnostic branches; delete no
   branch without separate owner approval.
4. Characterize one low-coupling `Main.gd` boundary before considering any
   structural extraction.

The complete former phase log is preserved at
`docs/history/CURRENT_PHASE_THROUGH_2026-09-02.md`.
