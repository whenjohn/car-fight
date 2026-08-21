# Network shaping findings

Status: active investigation on `feature/network-shaping`
Last updated: 2026-08-21

## Scope

Car Fight now has matching named impairment profiles for native ENet and browser
WebRTC. Native traffic uses the in-project UDP relay. Browser traffic is forced
through an isolated TURN allocation shaped with `netem`; browser HTTP throttling
is not treated as gameplay-network evidence.

The production macai2 service on UDP 10080/TCP 10181 was not changed during the
recovery experiments below. Patched server/client comparisons used temporary
local servers.

## Full G2-derived stack A/B

Car Fight now has an opt-in `CAR_FIGHT_G2_STACK=1` profile covering the G2
network mechanisms that apply to this project:

- per-route `StateBundle` queues with ordinary-state coalescing, byte bounds,
  pressure telemetry, and full-state recovery preservation;
- fixed-size packed input plus packed rollback state codecs;
- disabled redundant input broadcast;
- fixed or adaptive ordinary-state cadence division;
- application/network/rollback telemetry; and
- 30 Hz complete-set remote-position batching, same-map relevance, self
  exclusion, generation/tick validation, and delayed render-only interpolation.

The profile remains an A/B switch. Ordinary game launches retain the legacy
transport and cadence. The G2 replay-budget mechanism is available only through
an explicit lab value and remains rejected as described below.

### Car Fight-specific StateBundle correction

The first direct port coalesced the newest whole StateBundle envelope. Under
120 ms latency, server resimulation can emit newer sparse envelopes for
different bodies. A newer body B envelope therefore evicted body A's latest
authority, leaving a client seconds stale and producing 26-56 unit corrections.

Car Fight now coalesces the newest ordinary entry per route/body and regroups
entries by source tick when draining. Complete reliable-recovery keys remain
atomic. A focused regression covers this multi-body starvation case.

### Headless native measurements

| Profile | Cadence | Result | Worst correction |
| --- | --- | --- | ---: |
| `latency120` | fixed divisor 3 | pass | 1.379 units |
| `combined` | fixed divisor 3 | fail | 10.890 units |
| `combined` | fixed divisor 1 | pass | 0.388 units |
| `latency120`, long run | adaptive 3 -> 2 -> 1 | pass | 0.860 units |

The adaptive run changed at ticks 720 and 1080 with no backpressure or
full-key events and only one bounded missing-reference rejection. Fixed 20 Hz
ordinary state is therefore useful under pure lag but is not yet the robust
combined latency/jitter/loss default. Divisor 1 is the current full-stack
combined baseline.

The corrected native run also proved that batch presentation was carrying real
bodies rather than empty envelopes: each peer received one self-excluded remote
body, with 25 non-empty envelopes and 2,200 logical bytes per reporting window.

For human smoothness checks, `scripts/play_shaped_local.sh` adds peer 1 as a
server-authoritative Jeep on long straight perimeter runs joined by short
chamfered corners. Its input is generated on the server, it does not auto-fire,
and the shaped observer spawns beside it and receives the body through the full
profile. Ramps, the arena ball, shield-test drone, and orange peer markers are
disabled; the cursor line, interactive grass, and arena presentation remain.
The route stays clear of the driving-course gate, with an arena/map recovery
guard as a backstop. This is the Car Fight equivalent of G2's moving server
fixture: judge the remote hull mainly on the sustained straightaways.

## Native desynchronization under 120 ms one-way latency

The first two rendered `latency120` runs eventually appeared desynchronized even
though the relay reported zero loss and zero reordering. Client logs identified
two related failure modes:

1. `DiffHistoryEncoder` applied a diff after its acknowledged reference snapshot
   had already fallen out of history. Merging that diff against an empty state
   produced a plausible but invalid snapshot.
2. After a long frame, a locally owned body could retain an authority tick older
   than the 64-tick rollback window. D-040 correctly avoided an impossible
   replay, but waiting for an ordinary full snapshot did not guarantee recovery.

The accepted recovery fix:

- rejects a diff whose exact reference snapshot is unavailable;
- retains state-only diff references for two rollback windows without expanding
  the input or replay window;
- rate-limits missing-reference diagnostics;
- requests a reliable, authority-validated full snapshot when a diff base is
  missing or a locally owned authority state falls behind retained history;
- applies and acknowledges that full state through a separate reliable RPC; and
- staggers the second rendered client by three seconds, matching the G2 launcher.

`scripts/join_transient_test.sh` now requires bounded request/application of the
reliable recovery. Its deterministic 1.5-second post-sync stall passed with one
request, one applied recovery, and a healthy client through tick 500. The focused
`latency120` native gate also passed after the longer diff-reference retention.

## Rendered results

### Before longer diff-reference retention

Evidence: `.crash-runs/two-client-20260820-230342`

Two rendered clients ran for about five minutes through 120 ms one-way latency.
They did not remain permanently desynchronized: both views agreed at the end and
recent correction returned to zero. Recovery was too frequent and visibly
jittery, however:

| Client | Average FPS | Minimum FPS | Samples below 30 | Recovery applied |
| --- | ---: | ---: | ---: | ---: |
| alpha | 39.1 | 5 | 56/293 | 44 |
| bravo | 40.9 | 1 | 50/292 | 30 |

### After retaining diff references for two windows

Evidence: `.crash-runs/two-client-20260820-231435`

The next 120 ms run again stayed synchronized and recovery frequency fell from 74
to 16 total applications over a roughly comparable active interval. The user
reported that high-FPS play was smooth-ish, while movement became stuttery when
the clients fell to 10-15 FPS.

| Client | Average FPS | Minimum FPS | Samples below 30 | Recovery applied |
| --- | ---: | ---: | ---: | ---: |
| alpha | 42.3 | 3 | 25/155 | 12 |
| bravo | 42.5 | 1 | 23/150 | 4 |

At 10-15 FPS a frame is displayed only every 67-100 ms, so presentation stepping
is unavoidable. The remaining question was why the clients entered that band.

## Low-FPS cause

Crash telemetry now records the maximum forward-network loop duration, rollback
loop duration, forward ticks, and rollback ticks observed in each one-second
sample. A final two-client local **unshaped** baseline isolated the cause.

Evidence: `.crash-runs/two-client-20260820-232150`

| Client | Average FPS | Minimum FPS | Worst rollback loop | Most replayed ticks |
| --- | ---: | ---: | ---: | ---: |
| alpha | 71.1 | 10 | 84.5 ms | 62 |
| bravo | 76.5 | 3 | 81.1 ms | 63 |

Normal rollback loops cost about 2-4 ms. During a bad frame, netfox replayed
nearly the complete 64-tick history in one frame and spent about 81-84 ms in the
rollback loop. That missed the next frame deadline, allowed more late work to
accumulate, and created the observed starvation feedback loop. Physics monitor
time remained small because this replay work runs in the main/network process
path. Latency increases the frequency and depth of correction, but the unshaped
control proves shaping is not the sole initiator.

This evidence rejects an FPS cap as the primary fix.

## Rejected resimulation-budget experiment

The G2-style per-frame rollback replay budget was ported and tested as a 10 ms
rendered-client default, then removed from normal behavior. It is now exposed
only as an explicit lab flag with a zero/unlimited default. Car Fight cannot
safely discard an old replay origin: that origin may be the newest authoritative
snapshot needed to reconcile a predicted body.

The first 120 ms shaped A/B limited replay depth and mostly held 59-61 average
FPS, but both clients visibly desynchronized. They accumulated 49 recovery
requests with only nine applied full states, and their worst corrections reached
7.059 and 4.244 units.

Evidence: `.crash-runs/two-client-20260820-234722`

A follow-up kept at least 24 replay ticks and immediately requested a reliable
full state whenever the budget discarded a correction base. That eventually
reconciled state, but it made performance and visual stability worse:

Evidence: `.crash-runs/two-client-20260820-235600`

| Client | Average FPS | Minimum FPS | Samples below 30 | Worst rollback loop | Recovery requested/applied | Worst correction |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| alpha | 33.1 | 1 | 125/277 | 210.9 ms | 78/60 | 10.675 |
| bravo | 34.0 | 1 | 106/275 | 123.2 ms | 53/32 | 18.203 |

The relay recorded zero loss and zero reordering, so this was not an impairment
configuration error. The user observed the decisive symptom: FPS looked fine,
but the clients were desynchronized. A replay cap is therefore not an accepted
native or browser mitigation. The next performance fix must preserve every
authoritative correction, for example by reducing replay cost or continuing a
correction over frames without advancing presentation from an unreconciled
state.

A final full-stack headless retest reached the same conclusion. With packed
state/input, StateBundle recovery, divisor 1, combined impairment, and a 10 ms
budget, worst correction reached 34.176 units. Coordinated recovery did not make
the cap safe. Keep `CAR_FIGHT_RESIM_BUDGET_MS` unset outside explicit failure
reproduction.

## Browser status

The local exported browser/native smoke now exercises the real G2-stack batch
path and rejects an empty remote-position stream. After limiting render-only
world-space updates to the vehicle hull and allowing the reconnect warm-up to
settle, it passed at 59.2 steady FPS, 678 maximum queued bytes, 102 final bytes,
and zero browser errors. Physics remained authoritative on the rollback body;
the 75 ms delayed/50 ms capped extrapolation path moved presentation only.

This local result fixes the previously observed application-level queue growth,
but it does not supersede the remote forced-TURN failures. The clean forced-TURN
row peaked at 106,560 queued browser bytes. The combined row peaked at 125,197,
ended with 15,166 still queued, and grew the server ordered channel past 600
KiB. Keep the 64 KiB acceptance ceiling fixed.

The latest isolated G2-stack `latency120` TURN retry failed before gameplay: ICE
remained `connecting` until the browser join timed out, even though the native
ENet peer stayed healthy and TURN qdisc traffic existed. It supplied no
desynchronization evidence. Repair/retry that ICE path before running the full
browser shaping matrix and human soak. The rejected replay cap is not part of
that solution.

## Validation state

- Complete native shaping matrix: passed before the recovery changes.
- Complete project suite: passed after reliable recovery was added.
- After longer diff-reference retention: Godot import, crash telemetry test,
  join-transient recovery, and focused `latency120` network gate passed.
- Focused packed-input, packed-state, per-body StateBundle coalescing, and remote
  transport tests pass.
- The full G2-derived native `latency120` row passes with real non-empty remote
  batches. Combined impairment passes at divisor 1; divisor 3 is not accepted.
- The long adaptive-cadence run passed while stepping 3 -> 2 -> 1.
- The 10 ms replay budget, its 24-tick/reliable-rebase follow-up, and a final
  coordinated full-stack retest were all rejected by shaped native evidence.
- The exported local browser/native G2-stack smoke passes at 59.2 steady FPS,
  678 maximum/102 final buffered bytes, and zero errors. Remote forced-TURN
  shaping remains incomplete because the latest retry stopped at ICE setup.

## Next-session sequence

1. Run `./scripts/play_shaped_local.sh clean`, then `latency120`, then `jitter`.
   Use one rendered observer and the same straight perimeter route for every
   comparison. Record the printed evidence directory and the user's straight-line
   smoothness observation for each run.
2. Run combined latency/jitter/loss with the accepted full-rate baseline:
   `CAR_FIGHT_STATE_RATE_DIVISOR=1 ./scripts/play_shaped_local.sh combined`.
   Do not use divisor 3 as the combined control.
3. Separate symptoms by FPS. Healthy-FPS straight-line jitter points toward
   remote batch cadence/interpolation or correction timing. Stutter confined to
   10-15 FPS points back to the measured 62-63-tick rollback replay spikes.
4. Keep `CAR_FIGHT_RESIM_BUDGET_MS` unset. The budget preserved FPS by dropping
   required correction work and caused visible divergence in three experiments.
5. Once native behavior is characterized, mirror the straight fixture in the
   browser harness. Fix the forced-TURN ICE setup before running or accepting a
   remote browser impairment matrix; preserve the 64 KiB queue ceiling.
