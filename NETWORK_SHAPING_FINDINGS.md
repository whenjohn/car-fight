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
rendered-client default. It was then removed from both native and browser code.
Car Fight cannot safely discard an old replay origin: that origin may be the
newest authoritative snapshot needed to reconcile a predicted body.

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

## Browser status

The browser path remains blocked independently on WebRTC backpressure. The clean
forced-TURN row peaked at 106,560 queued browser bytes. The combined profile
peaked at 125,197 browser bytes, ended with 15,166 still queued, and grew the
server ordered channel past 600 KiB. Keep the 64 KiB acceptance ceiling fixed.
Backpressure still has to be corrected before the full browser profile matrix
and human soak can pass. The rejected replay cap is not part of that solution.

## Validation state

- Complete native shaping matrix: passed before the recovery changes.
- Complete project suite: passed after reliable recovery was added.
- After longer diff-reference retention: Godot import, crash telemetry test,
  join-transient recovery, and focused `latency120` network gate passed.
- The 10 ms rendered-client replay budget and its 24-tick/reliable-rebase
  follow-up were both rejected by shaped native A/B evidence and removed from
  native and browser code.
- After removing the rejected experiment, the complete `./scripts/test.sh` suite
  passed. The Web Network release export and local browser/native leave/rejoin
  smoke also passed at 60.0 steady FPS, 4,848 maximum/455 final buffered bytes,
  and zero browser errors.
