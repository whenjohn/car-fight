# Car Fight code-health evidence ledger

Status: active audit on `codex/code-health-audit`, based on canonical
`master@d949ba7`. A finding is not permission to change protected gameplay,
networking, rollback, transport, synchronized state, physics, or rendering
behavior.

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
- Validation: depends on the extracted boundary; shared authority or RPC work
  requires the relevant network gate and the complete suite once before merge.
- Risk/rollback: high. File size alone is not deletion or rewrite evidence.
- Status: **Hold** until lower-risk cleanup and characterization coverage are
  complete.

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
- Proposed change: produce a branch-by-branch keep/delete list. Preserve every
  documented recovery ref and verify the archive before deleting anything.
- Validation: compare merged status, tags, remote refs, and documented commit
  IDs before and after cleanup.
- Risk/rollback: branch deletion can remove convenient recovery names even when
  commits remain reachable elsewhere.
- Status: **Hold** pending a separate destructive-action approval.

### CH-009 — Deployment retains removed project files

- Classification: stale deployment content and operational correctness risk.
- Evidence: `scripts/deploy_macai2.sh` uses rsync without `--delete`. A read-only
  comparison found 31 files under `/Users/macai2/Projects/car-fight` that no
  longer exist in the canonical repository, including removed arena, driving
  course, elevated course, jump-gate, overcast-world, and occlusion-hint code,
  tests, and launchers. `scripts/gate_test.sh` is one of those leftovers.
- History: the city-only resurrection in `7027700`/`3ccd8fe` intentionally
  removed these worlds and tests; later deployment copied current files without
  reconciling removed paths.
- Proposed change: design a deployment reconciliation step that preserves
  explicit runtime/cache/local-asset exclusions, previews deletions, and removes
  only files absent from the canonical deployment source. Verify the exact
  31-file inventory before applying it to macai2.
- Validation: rsync dry-run/deletion manifest, remote service status before and
  after, current file-list comparison, native connection smoke, and browser
  connection smoke. Deployment remains a separate explicit operation.
- Risk/rollback: high operational impact. A broad `--delete` can remove remote
  state or locally supplied assets unless exclusions and targets are exact.
- Status: **Hold** pending owner approval of the deletion manifest and deploy
  behavior.

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
- Status: **Approved**.
