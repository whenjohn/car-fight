# Networking 2: Durability and Adverse-Path Validation

## Baseline

Networking 2 starts at accepted Networking-1 commit `a535364`. Preserve the
fixed forced-TURN 120 ms configuration while testing one new variable at a time:

- G2 stack with state-rate divisor 1;
- proxy presentation at the existing 75-150 ms bounds;
- slow left-lane server fixture;
- harness-only capsule radius 1.05, total length 3.40; and
- ordinary gameplay, adaptive cadence, and capsule defaults unchanged.

## Step 1: long soak and reconnect

Run `scripts/webrtc_turn_soak_test.sh`. It performs one browser leave/rejoin,
keeps a native ENet survivor in the mux world, then observes the replacement
browser for 600 seconds by default. The gate retains the existing limits:

- forced-TURN and qdisc traffic must be proven;
- the survivor must observe shared world, leave, then replacement rejoin;
- browser and server WebRTC queues remain at or below 64 KiB and drain;
- steady browser FPS remains at least 30 minimum / 40 average during the long
  unattended soak (the short playable smoke retains 30 / 45);
- no runtime/browser errors;
- at most four bounded recovery/stale-warning events; and
- worst correction remains at or below the existing 2-unit ceiling.

Override only duration when a shorter diagnostic is needed:

```sh
CAR_FIGHT_WEBRTC_SOAK_SECONDS=120 scripts/webrtc_turn_soak_test.sh
```

Do not run rendered acceptance while unrelated CPU/GPU-heavy applications are
active. This external gate is deliberately not part of `scripts/test.sh`.

### Accepted result

Run `20260822T222345Z-66042-30123` observed the replacement for all 600 seconds:
zero recovery, 0.000887-unit worst correction, 0.00013-unit planar displacement,
zero browser errors, a 3,558-byte peak browser queue, and 194,333 forced-TURN
qdisc packets with zero drops. A harness-only explicit idle input was required;
screen center is not neutral in the isometric camera and the previous automation
silently drove into arena geometry. Step 1 is accepted.

Focused regressions and the complete permission-correct `./scripts/test.sh`
suite pass (`ALL_TESTS PASS`).

## Step 2: two real players and local presentation

Completed with one direct native ENet player and one Chrome WebRTC player forced
through TURN at the unchanged 120 ms one-way condition. A large harness arena,
client-local cruise input, and timestamped presented-motion traces made moving
observer comparisons repeatable without server-authored movement masquerading
as human input.

The traces found no stale recovery in clean runs. Residual tug was predominantly
longitudinal and increased when observer frame cadence fell, especially in
Chrome. An opt-in harness-only local hull/camera reconciler now feeds forward
raw physics velocity and smooths only small render-pose corrections; physics,
rollback, collision, and input are unchanged, and changes over 2 units snap.

Human run `20260823T202607Z-81872-13577` passed in both directions: Chrome drove
beside a cruising native Jeep, then native drove beside a cruising Chrome Jeep.
Both were rated smooth with no visual issues. Recoveries remained zero; median
FPS was 85 native and 42 Chrome. The accepted capsule remained radius 1.05 and
total length 3.40 in the harness only.

Focused checks, clean Web export, the hardened lifecycle gate, and the complete
permission-correct `./scripts/test.sh` suite pass (`ALL_TESTS PASS`).
After acceptance, the normal mixed launcher leaves diagnostic `P` cruise and
`L` motion tracing disabled. They remain available only through explicit
`CAR_FIGHT_CLIENT_CRUISE=1` and `CAR_FIGHT_MOTION_TRACE=1` opt-ins.

## Later steps

Gameplay capsule integration is next in a separate branch/worktree and must not
be combined with networking presentation work. Combined latency/jitter/loss and
adaptive cadence remain separate unaccepted experiments; neither was used to
accept Networking 2.
