# Car Fight quality gates

Car Fight uses risk-based validation. The goal is to prove the behavior touched
by a change without rerunning every gameplay and networking feature after each
small edit.

## Default workflow

1. Finish one coherent change and review its complete diff.
2. Run `./scripts/check.sh` for code, asset, project, or script changes.
3. Run the smallest focused unit and runtime gates that exercise the changed
   behavior.
4. Run a monitored human check only when feel or appearance is material.
5. Run `./scripts/test.sh` only at one of the broad-suite boundaries below.

Documentation-only changes need `git diff --check` and verification of the
links or commands they change. They do not require a Godot import or gameplay
test.

The fast check verifies that every standalone `tests/*_test.gd` appears exactly
once in the comprehensive runner. It checks the manifest without executing all
of those feature tests.

## Gate selection

| Change | Required validation | Add when integration changed |
| --- | --- | --- |
| Agent rules, documentation, or plans | `git diff --check`; verify affected links and commands | Nothing unless executable behavior also changed |
| Shell or Node harness | `./scripts/check.sh`; exercise the changed harness's bounded success/failure or lifecycle path | Its focused runtime gate |
| Pure gameplay math or input | `./scripts/check.sh`; the matching `tests/*_test.gd` | `scripts/offline_test.sh` when wiring into live play changed |
| Presentation, shader, model, or UI | `./scripts/check.sh`; the matching asset/presentation test | `scripts/offline_test.sh` when construction or scene wiring changed; one approved monitored visual pass for acceptance |
| Combat feature | `./scripts/check.sh`; its matching GDScript test | Only the matching `combat_test.sh`, `rc_orb_test.sh`, `shield_test.sh`, or `det_test.sh` |
| Ball, tractor, or reverse behavior | `./scripts/check.sh`; matching focused GDScript coverage where present | Only the matching shell gate |
| ENet lifecycle, rollback, or authority | `./scripts/check.sh`; matching codec/state/transport tests | One relevant `network_test.sh`, `join_transient_test.sh`, or `reconnect_test.sh` invocation |
| WebRTC or mux behavior | `./scripts/check.sh`; matching transport tests | `mixed_transport_test.sh` or the specific bounded Web gate |
| Shared state schema, RPC contract, vendored netfox, or broad authority flow | `./scripts/check.sh`; all directly affected focused gates | Complete suite once before merge |
| Deployment or release | Focused preflight for the changed subsystem | Complete suite once, then the deployment smoke |

Run a GDScript test directly with the pinned editor, for example:

```bash
/Applications/Godot47.app/Contents/MacOS/Godot \
  --headless --path . --script res://tests/follow_controller_test.gd
```

## Broad-suite boundaries

`./scripts/test.sh` is intentionally comprehensive and expensive. Run it for:

- high-risk integration before merging to `master`;
- a deployment or release checkpoint;
- an accumulated cleanup milestone;
- a change that crosses several gameplay/networking systems;
- an explicit owner request.

A localized presentation or gameplay change may merge with focused evidence
when it does not alter shared authority, state, transport, or project-wide
construction.

## Rerun policy

- Run validation after a coherent slice, not after every edit or constant
  adjustment.
- Do not rerun a passing gate unless relevant code changed afterward.
- When a timing-sensitive integration gate fails, inspect its evidence and
  rerun only that isolated gate once.
- Do not rerun the complete suite merely to clear an unrelated flake.
- Record a recurring failure as test debt with its command, evidence, and
  observed frequency.
- Successful checks should print short summaries. Preserve detailed logs for
  failures rather than feeding all successful output back into an agent
  session.

## Review record

The final handoff for a change should state:

- what behavior changed;
- which gates ran and their results;
- why broader gates were not needed, if omitted;
- what still requires human feel, appearance, or cross-client validation.
