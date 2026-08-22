# Networking 1: Jump and Teleport Follow-up

## Accepted checkpoint

- The forced-TURN WebRTC comparison remains at 120 ms one-way latency, G2 stack,
  state-rate divisor 1, proxy presentation, and the on-screen network HUD.
- The Networking-1 harness uses a horizontal capsule with 1.05-unit radius and
  3.40-unit total length for both Jeeps. It covers the complete measured Jeep
  footprint. Ordinary gameplay still defaults to its proven sphere; the harness
  explicitly passes `--player-capsule`.
- The server-driven fixture can use `--server-driver-lane`: it drives at about
  6 units/s between two points on the left side and disables its collision
  escape behavior. Physical impacts may displace it, after which it steers back.
- The user accepted capsule contact in a clean 120 ms run. Do not retune the
  capsule while diagnosing corrections.

## Deferred work: integrate the capsule into gameplay

This is a real follow-up workstream, not part of the next jump/teleport fix.
Promoting the capsule globally must preserve its accepted dimensions and solve
the physics consequences rather than changing the shape to satisfy old gates:

- elevated-road edge support, both landings, rebound, jostle, and self-righting;
- wall-facing reverse clearance and backing behavior;
- projectile hull jostle and shielded 15% response under the new inertia;
- ramps, gates, ball/tractor contact, player/player contact, and map transitions;
- the complete `./scripts/test.sh` suite plus a focused human handling pass.

Keep `--player-capsule` and `--no-player-capsule` as synchronized A/B controls.
Do not make the capsule the ordinary default until this matrix is green and the
user accepts the broader handling, independently of networking presentation.

## Keep the two failure classes separate

1. **Session-wide recovery failure.** Skipping and difficult steering affected
   the local Jeep after a 695 ms browser processing pause. RTT reached 572 ms,
   jitter 312 ms, applied state fell about 300 ticks behind, fresh-key recovery
   repeated, and the worst correction reached 28.9 units. That run was also
   contaminated by stale harness processes and is not collision evidence.
2. **Impact correction.** In otherwise healthy 120 ms sessions, collision with
   an independently predicted drone proxy can disagree with the server's
   delayed dynamic drone. Rollback later corrects the local Jeep. The first
   proxy reached 206.88 units; rollback-aware proxy repeats reduced but did not
   eliminate corrections, commonly recording roughly 29-32 units.

Do not hide either failure by smoothing the local gameplay body or by moving
the hull away from its collision shape.

## Relevant G2 lessons already present

- D-040 rejects rollback origins older than retained history and rate-limits
  the owned warning instead of creating an impossible replay/logging spiral.
- StateBundle coalesces queued authority, requests coordinated fresh keys, and
  rebases on a complete stale key when a congested queue cannot deliver a fresh
  one. Car Fight additionally coalesces ordinary state per route and publishes
  only the settled post-rollback tick.
- The optional per-frame rollback work budget and telemetry exist, but prior
  Car Fight shaped trials rejected enabling that budget because dropping replay
  origins preserved FPS while visibly diverging.
- G2 proved that renderer/main-thread stalls can masquerade as networking
  failures. Frame/process timing must accompany every correction conclusion.

This means the next step is not another broad G2 port.

## Step 1: harden the interactive harness

Before changing replication behavior, make interrupted runs unambiguous:

- Preflight signaling port 12581 and web port 18189 before building or touching
  remote resources. If occupied, print the owning PID/command and stop; never
  silently load an old web server or attach to an old tunnel.
- Record a unique run ID in the browser query, browser log, remote server log,
  and evidence directory. Refuse readiness unless all identities agree.
- Verify the web server, signaling tunnel, TURN relay, remote game server,
  WebRTC connection, first state batch, and nonzero RTT before opening the run
  for human judgment.
- Ensure every owned child is stopped by normal exit and both interrupt paths.
  Add a focused lifecycle test that intentionally interrupts startup, then
  proves both ports can be rebound.

## Step 2: attribute corrections at the instant they happen

Extend the existing correction event rather than adding a second clock. For
every local correction above a small reporting floor, log and expose a compact
cause record containing:

- correction distance and before/after local positions;
- current tick, authoritative source tick, applied-state age, pending age, and
  whether a fresh-key recovery or clock fast-forward occurred recently;
- rollback depth, resimulation debt, and retained history start;
- current/maximum frame time and browser process time;
- whether the player contacted the drone during the recent window;
- predicted proxy-to-raw-authority distance and longitudinal lead;
- map/relevance transition recency.

Add counts to the HUD for `corr`, `stall`, `stale`, `impact`, and `unknown`, but
keep detailed records in the evidence log. A correction can have multiple
signals; preserve the raw values rather than forcing a false single cause.

## Step 3: reproduce one variable at a time

Use the slow lane fixture and the same current build:

```sh
CAR_FIGHT_INTERACTIVE_BROWSER=1 \
CAR_FIGHT_SHAPE_FAILSAFE_SECONDS=900 \
CAR_FIGHT_SERVER_DRIVER_LANE=1 \
CAR_FIGHT_PLAYER_CAPSULE=1 \
CAR_FIGHT_G2_STACK=1 \
CAR_FIGHT_STATE_RATE_DIVISOR=1 \
CAR_FIGHT_REMOTE_INTERP_MODE=proxy \
CAR_FIGHT_REMOTE_INTERP_MS=75 \
CAR_FIGHT_REMOTE_INTERP_MAX_MS=150 \
CAR_FIGHT_NETWORK_HUD=1 \
scripts/webrtc_turn_shape_test.sh latency120
```

Run these observations independently:

1. Drive without touching the drone for at least 60 seconds.
2. Park and observe the drone for at least two complete lane reversals.
3. Rear impact, head-on impact, and side impact, resetting between cases.
4. Repeat the impact that produced the largest attributed correction.
5. Use the existing deterministic stall hook only after the clean collision
   cases, to validate session-wide recovery separately.

Discard runs with mismatched run identity, zero RTT, stale harness resources,
or unrelated sustained low FPS.

## Step 4: choose the fix from the evidence

- If a correction follows stale-state/clock recovery without contact, repair
  the recovery transition. The target is one bounded rebase to the newest
  complete authority, not replaying or repeatedly fast-forwarding an obsolete
  timeline. Preserve D-040 and do not enlarge history as a substitute.
- If a correction follows contact while state age and frame time are healthy,
  the proxy and server resolved different collisions. Replace the independently
  animated collision proxy with a rollback-participating predicted drone state
  that uses the same inputs/state at each replay tick. Keep any residual visual
  smoothing presentation-only and attached to that predicted collider.
- If the correction follows a main-thread stall, remove or amortize the measured
  local work first. Do not tune network delay around a renderer/CPU hitch.
- If map relevance changes, verify leave/enter lifecycle and suppress collision
  while absent; do not classify the intentional map relocation as network drift.

For a general multiplayer solution, validate the same collision model with two
real player peers. A fixture-only deterministic drone solution is useful for
diagnosis but cannot silently become the remote-player authority model.

## Acceptance gate

At 120 ms forced TURN:

- Harness identity and readiness checks pass with no stale process reuse.
- A 60-second no-contact drive has no visible local teleport and no alarming
  unexplained correction.
- Each controlled impact keeps hull, center marker, and collision aligned.
- No correction exceeds the existing automated ceiling without an explicitly
  classified server-only event; do not raise a ceiling to accept a regression.
- FPS remains near 60 after warmup, no recovery loop persists, applied-state age
  returns to its healthy band, and state fast-forwards do not accumulate.
- The user accepts steering and contact feel in a fresh run.

Only after this gate should combined jitter/loss or adaptive cadence resume.
