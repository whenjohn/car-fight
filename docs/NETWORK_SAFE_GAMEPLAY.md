# Network-safe gameplay development

Standing development guidance for Car Fight. Read this before implementing or
reviewing gameplay, player input, object lifecycle, or replicated state. Follow
[AGENTS.md](../AGENTS.md) for scope and safety, and
[Quality gates](QUALITY_GATES.md) for test selection. This guide does not
authorize new features, engine/transport changes, broad cleanup, or deployment.

## Approach and reasoning

Networking quality is a property of the whole gameplay path: gather input,
simulate, encode, transmit, receive, reconcile, and present. A visible hitch
does not identify which step failed. Gameplay can increase traffic, stall the
processing of already-arrived packets, or create prediction disagreement even
when the connection itself is healthy. Conversely, not every hitch is a gameplay
bug; distinguish evidence from hypotheses before choosing a fix.

Use three layers: explicit feature contracts, executable regression checks,
and measurements under representative load. Rules without tests drift; tests
without realistic scenarios miss scaling; aggregate FPS or bandwidth alone
cannot explain the cause of a disturbance.

The general engineering principles also apply outside games:

- Give shared state one clear owner; validate requests at the authority boundary.
- Design operations for retries/replay and object/session lifetime changes.
- Bound work, retained history, queues, and message sizes before load increases.
- Verify the behavior actually selected, not just requested configuration.
- Compare against controlled baselines and retain failures and uncertainty.
- Fix the measured cause with the smallest change; do not compensate for a
  processing bottleneck by blindly increasing buffers, retries, or smoothing.

Car Fight provides concrete reasons for this policy. Adding `drop_troops`
without updating the packed schema disabled compression for all player inputs;
the old self-referential test still passed. Gameplay/UI queries after disconnect
produce inactive-peer errors that an existing network gate misses. Earlier
presentation experiments made motion smoother while moving the visible vehicle
away from its effective collision position. See the
[networking review and codec follow-up](NETWORKING_REVIEW_2026-09-04.md) and
[shaping findings](../NETWORK_SHAPING_FINDINGS.md) for evidence and limitations.

## Feature contract

Before a feature changes networked behavior, answer these questions briefly in
its implementation notes or change description. Reuse existing answers when
the contract is unchanged; do not invent a new subsystem for every feature.

| Concern | Required decision | Reason |
| --- | --- | --- |
| Authority | Who supplies intent, who validates it, and who decides the outcome? | Avoid competing movement, damage, and spawning decisions. |
| Replication | Static/seeded, event-driven, lightweight snapshots, or full rollback state? | History, replay, physics, and recipient fan-out all have costs. |
| Replay | What is restored or reproducibly derived, and what must happen only once? | Resimulation must not duplicate projectiles, damage, spending, sounds, or effects. |
| Lifecycle | What happens before readiness, at late join, during despawn, disconnect, and rejoin? | Queued events and references can outlive their node or session. |
| Budget | Supported object/peer counts, work per tick, publication rate, payload size, and queue bound? | One-object tests do not establish capacity. |
| Evidence | Which regression, load comparison, and affected transport/platform checks prove this change? | Make acceptance observable rather than inferred. |

Client owners supply player intent; server peer 1 owns resulting bodies/state.
Do not weaken that boundary for convenience. Keep authoritative validation even
when prediction makes the same local decision for responsiveness.

## Implementation heuristics

### Simulation and replay

- Keep animation, camera motion, smoothing, and other presentation state out of
  steering, physics, targeting, and collision decisions.
- Anything that affects the next predicted result must be rollback-restored or
  reproducibly derived. Include cooldowns, held/toggled flags, and random state,
  not just transforms. Use simulation ticks and controlled randomness rather
  than wall-clock timing or unrelated frame callbacks for replayed decisions.
- Preserve stable iteration/tie-breaking where order affects results. Do not
  assume identical input guarantees cross-platform physics agreement; test it.
- Reversible gameplay changes must be restored/replayed correctly. Irreversible
  events need confirmation or deduplication appropriate to the existing design.
  Simply skipping every effect during replay can also lose legitimate outcomes.
- Preserve existing netfox mutation/history/lifecycle contracts. Add a regression
  before changing movement or collision behavior; do not enlarge rollback history
  or revive rejected timing experiments as an incidental feature fix.

### Replication and bounded work

- Use the cheapest representation that preserves gameplay correctness. A visual
  effect is not automatically a replicated body; a troop is not automatically a
  full rollback rigid body. Classify first, then measure representative counts.
- Check scaling across both objects and recipients. Watch per-object broadcasts,
  all-pairs scans, per-frame allocation, and repeated work during resimulation.
  Optimize only after preserving outcomes and establishing where time is spent.
- Schema changes include adding/removing/reordering input and state properties.
  Test the real registered surface, all fields, version policy, malformed data,
  and actual encoded size. Unexpected player-codec fallback must fail its gate.
- Bound queues and payload bytes, not just array length. Under congestion, replace
  stale replaceable snapshots rather than accumulate them indefinitely. Preserve
  reliable event/recovery semantics and complete-set membership when batching;
  splitting an array is not automatically a valid packet-fragmentation protocol.

### Lifecycle

- Transport connected is not gameplay ready. Keep intent neutral and present a
  joining state until current timing evidence and an actually received/applied
  authoritative state agree. A locally initialized history tick is not proof
  of server state. Bound the wait, offer retry, and invalidate readiness across
  disconnects and body replacement; do not use an arbitrary sleep as readiness.
  Do not chase the newest snapshot indefinitely: retain one post-clock-validation
  consumed snapshot as the readiness target, wait until its tick is no longer
  future, and discard it if clock stability or retained history is lost.
  Local input/UI gating alone does not remove a player from the world. When
  server admission is selected, use `net/player_participation.gd` for gameplay
  queries, including targets, pickups and awareness markers. Pending bodies
  still synchronize, but cannot collide, fire, receive hits or collect items.
  Activation is a server-authored generation/tick event; replay before that
  tick must remain inert. Do not use visual visibility as gameplay authority.
  Check dynamic spawn occupancy before activation, including other scheduled
  admissions: an active player can drive into an invisible waiting position.

- Only gather/send/apply network-dependent gameplay in valid connection and
  readiness states. A non-null peer reference alone does not prove it is active.
  Reuse `net/connection_state.gd` for the connected-peer prerequisite; it accepts
  offline play but does not replace feature-specific readiness or authority checks.
- Stop callbacks and clear or invalidate pending work as nodes/sessions retire.
  Reject stale events using the existing identity/generation/tick contracts;
  reused IDs must not route an old event into a replacement object.
- Exercise late join and removal while the feature is active, plus disconnect
  and rejoin. For browsers, separately validate background/resume and connectivity
  changes. Relaunching a test process does not prove same-session recovery.

## Measure before accepting

Extend the existing `NetworkPerformance`, `NETAPP`, codec, correction, and frame
diagnostics. Do not create a second monitoring stack without a demonstrated gap.
Collect samples over the same time window so correlations can be investigated.

| Measurement | What to look for |
| --- | --- |
| Frame, simulation, and rollback duration | Slow intervals and replay CPU, not just average FPS. |
| Corrections, frequency and magnitude | Divergence that appears when an interaction activates. |
| Input/state age, queue size and drops | Increasing delay between creation, receipt, and application. |
| Messages/bytes by category, maximum payload | New fan-out, codec fallback, or packet-size growth. |
| Object/rollback-body counts and feature CPU | Whether cost grows with the intended supported workload. |
| RTT/transport path and lifecycle errors | Separate connection changes from local processing problems. |

Some signals already exist, but a unified percentile/feature-budget report and
complete platform coverage do not. Mark unavailable measurements as unavailable,
not zero. Codec encoding attempts are not necessarily sent messages; serialized
application bytes are not encrypted transport bytes; receipt is not application.
`NETAPP` now includes per-window `payload_max` and `bundle_max` logical byte
counts. The [packet-size fixture](NETWORK_PACKET_BUDGETS_2026-09-04.md) separately
measures real RPC encoding from player/ball/prop schemas. Use it when those
schemas grow, but do not substitute its template projections for live-load tests.

Compare feature-off/on or before/after builds on the same hardware, resolved
configuration, input scenario, and supported counts. Keep warmup separate, retain
slow-tail results and errors, and record machine contention. A fixed random seed
does not make operating-system scheduling or network delivery identical.

Use existing acceptance limits, including the current two-unit correction ceiling
in the relevant contact gates. Set additional budgets from a recorded baseline
and the supported device/scenario, not arbitrary universal numbers. Keep CPU
headroom for replay and stalls; do not spend the entire tick budget at idle.
Do not relax a limit merely because a feature fails it.

Validate pure ENet, native through mux, and WebRTC through mux when the changed
contract crosses those paths. A native WebRTC extension run is not a browser
test. Real browser/device, TURN, and rendered acceptance remain separately scoped
milestone checks with the project's existing approval and safe-window rules.

## Handoff checklist

- State the changed feature contract and preserved boundaries.
- List real-schema, replay/outcome, and lifecycle checks relevant to the change.
- For new networked object families, record feature-off/on costs at representative
  and maximum-supported counts, including CPU and traffic; explain missing data.
- Record build/configuration, hardware, scenario, log locations, results, and
  known failures. A harness PASS with unexpected engine errors is not clean play.
- Identify remaining transport/platform coverage and the next required gate.

## Enforcement status

The following distinction is important for future sessions:

- **Implemented:** live player input-schema and codec regression; explicit focused
  test selection; existing network/performance counters; opt-in mixed-transport
  packing assertions; instrumented real-scene connection regression; complete
  client logs/error checks and bounded post-server client waits in `network_test.sh`,
  covered by process-only harness tests. Run codec/lifecycle tests explicitly for
  their affected changes.
- **Not yet automated:** running that codec test inside the fast `check.sh` gate;
  complete process-log collection and unexpected-engine-error failure in the other
  network harnesses; standardized per-feature cost/percentile reports and budgets.
- **Required now:** follow the contracts, choose and run affected focused checks,
  inspect logs, and disclose missing evidence. `check.sh` checks the test manifest
  but does not execute the codec test. Follow [Quality gates](QUALITY_GATES.md)
  for exact commands and when the full suite is required.

Remaining automation priorities are fast live-schema coverage, auditing log/error
gating in the other harnesses, and repeatable feature-cost reports. They are
follow-up tasks, not permission for a broad rewrite.
