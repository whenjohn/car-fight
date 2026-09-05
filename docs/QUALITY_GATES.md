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

## Gameplay and networking contracts

Read [Network-safe gameplay](NETWORK_SAFE_GAMEPLAY.md) before gameplay, input,
lifecycle, or replicated-state work. Record the affected authority, replication
class, replay/lifecycle behavior, cost bounds, and chosen checks in the change
handoff. Keep the record proportional; an unchanged contract can be stated as
unchanged rather than redesigned.

- Changes to player input, its registration, or its encoding require the live
  `tests/input_codec_test.gd` regression, even when no file under `net/` changed.
  Do not substitute a fixture generated only from the codec's expected list.
- Other synchronized-state/schema changes require their corresponding real
  registration/round-trip/version tests. Add missing focused coverage before
  changing the contract; the input test does not validate every state codec.
- Movement, collision, or combat replay changes require outcome/replay checks,
  including duplicate-effect prevention where relevant, plus the affected runtime
  gate from the table below.
- New networked object families require representative and maximum-supported
  count tests with feature-off/on CPU and traffic evidence. Record missing
  instrumentation or untested platforms instead of claiming acceptance.
- For lifecycle changes, finish collecting process logs and reject unexpected
  engine/script errors. Existing network harnesses do not yet enforce this
  consistently (`network_test.sh` now does): inspect their logs and report known
  debt alongside their exit status. Do not broadly allowlist errors or relax
  correction limits to pass.

Run the live player input regression from the project root:

```bash
/Applications/Godot47.app/Contents/MacOS/Godot \
  --headless --path . --script res://tests/input_codec_test.gd -- --offline
```

This is currently an explicit focused gate and part of `scripts/test.sh`, not
an executed step in `scripts/check.sh`. Automatic fast-gate execution, complete
error collection across the other network harnesses, and standardized feature-cost
reports remain follow-up implementation work.

For connection/frame guards or the combined ENet harness, run the focused gates:

```bash
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/connection_lifecycle_test.gd -- --offline --presentation-test
./scripts/network_test_harness_test.sh
```

The first creates presentation nodes under the headless renderer to inspect real
callbacks; it does not open a rendered window. The second uses mock processes to
exercise the real `network_test.sh` success, late-error, bad-exit, and timeout
paths without sockets. Neither replaces live transport/reconnect tests.
`network_test.sh` waits for complete client logs before checking engine/script
errors and exit status; `CAR_FIGHT_NETWORK_SHUTDOWN_TIMEOUT` bounds each client
wait after the server exits (default 10 seconds), not the entire run. Exit 2 is
accepted only with the expected CLIENT_STOPPED marker; errors still fail the run.

## Gate selection

For payload accounting, replicated-state growth, or packet-budget work, run
`tests/network_payload_telemetry_test.gd` and
`tests/network_packet_size_test.gd -- --offline` with the pinned headless editor.
The [packet baseline](NETWORK_PACKET_BUDGETS_2026-09-04.md) has exact commands,
real-schema coverage and measurement limits. These gates measure serialization,
not supported object-count CPU capacity or actual transport fragmentation.
Telemetry changes also need a relevant live gate with `--net-telemetry` enabled.

For WebRTC bootstrap/lifecycle changes, also run:

```bash
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/webrtc_connection_test.gd
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/webrtc_server_lifecycle_test.gd
```

This focused test needs local loopback socket access. It covers refusal before
WebSocket OPEN, stalled handshake/ID/negotiation, invalid IDs, repeated failure,
explicit close, callback-safe cleanup, and actual DataChannel packet delivery
after signaling closes. Deadline boundaries use an injected monotonic timestamp;
the sockets and RTC peers are real. Native extension evidence does not establish
browser/TURN behavior or same-session recovery. Run the mixed gate for gameplay
integration and inspect its complete logs for unexpected engine errors.

The server regression additionally exercises pending TCP admission, deadlines
before/after SDP, real malformed SDP/ICE, callback cleanup and ID reuse, healthy
packet delivery during peer failures, and genuine listener startup failure.
Its malformed-input fixtures intentionally invoke the native parser and emit
four engine diagnostics (two each for invalid SDP and ICE); these must not emit
the transport's server-fatal signal or interrupt the survivor. Keep those logs
and distinguish them from unexpected errors. Do not add these diagnostics to a
general gameplay-harness allowlist. The existing mixed gate covers collision
and ordinary gameplay with limits still disabled; opt-in limits need their own
bounded integration smoke before promotion.

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
- for networked gameplay, the contract and before/after cost evidence described
  in [Network-safe gameplay](NETWORK_SAFE_GAMEPLAY.md), including known errors
  and missing measurements even if the selected harness printed PASS.
