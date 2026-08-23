# Network shaping findings

Status: Networking-1 120 ms forced-TURN jump/teleport fix accepted on `feature/networking-1`
Last updated: 2026-08-22

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

## Networking 1 presentation experiment

The unmerged G2 adaptive-presentation work is now ported as an opt-in,
client-local controller rather than a transport or authority change. Fixed
75 ms presentation remains the product default. In adaptive mode the receiver
combines batch-arrival variation/gaps with actual remote-body buffer headroom
and interpolation/extrapolation/hold outcomes. It raises only after both sides
of that evidence agree, uses bounded 75/100/125/150 ms tiers, ignores arrival
samples contaminated by a local frame hitch, and waits 20 healthy seconds
before releasing one tier. Epoch changes reset its history.

The estimator is pure and every input can be captured as bounded JSONL and
replayed deterministically. The single-observer harness is
`scripts/play_networking1_enet.sh`: a server-driven Jeep runs on a temporary
macai2 server at the isolated networking-1 checkout/port while this Mac renders
only the observer and hosts the shaped relay. The production daemon is not
touched. A four-line HUD and matching `NETWORKHUD` JSON report frame pacing,
RTT/jitter, presentation target/headroom/mode shares, rollback depth/cost,
correction, and recovery count.

Two short clean macai2/Tailscale captures on 2026-08-21 stayed at the 75 ms
floor. The latter run reached 144-145 headless FPS after startup, reported 100%
interpolation with zero extrapolation/holds, and replayed to the same unchanged
target. Per-stage rollback profiling showed a startup worst loop of 11.0 ms and
then 3.1-3.8 ms loops; simulation was the largest accumulated stage. This did
not establish a safe 5% replay optimization, so no rollback behavior was
changed and the rejected replay budget remains disabled.

The first controlled human `clean / fixed 75 ms` comparison found the remote
Jeep smooth while the observer was stationary, but visibly jerky/stuttery when
the observer drove side-by-side with it. No pullback was noticed. Telemetry
supports a presentation-relative symptom rather than a reconciliation snap:
worst correction stayed at 0.008 units with zero recovery requests. FPS was
usually 85-120, although isolated frames reached 66.7 ms; RTT was normally
14-25 ms with brief 49-76 ms spikes, and the unreliable 30 Hz presentation
stream continued to accumulate occasional sequence gaps. The matched adaptive
phase uses the same live session so server route and impairment remain fixed.

In that matched `clean / adaptive` phase, the estimator selected 100 ms. The
side-by-side vibration became smaller and movement looked smoother to the human
observer, again with no noticeable pullback. Telemetry remained at 100%
interpolation with zero extrapolation, holds, or recovery requests. Presentation
headroom was generally 80-135 ms. Worst reported correction reached 0.299 units
after the live mode transition but remained well below the 2-unit recovery
threshold and did not correspond to a perceived pullback. This comparison
supports 100 ms as a useful clean-path buffer when relative camera motion makes
75 ms jitter visible.

The human `latency120 / fixed 75 ms` phase alternated between smooth stretches
and small-to-moderate stutters, with an occasional pause that was difficult to
classify visually as network lag or an FPS pause. The log shows evidence of
both pressures: FPS was commonly about 44-55 with frame maxima up to 73.2 ms,
while RTT was generally 260-280 ms with brief rises near 300-310 ms and jitter
spikes around 44-49 ms. Sequence gaps increased during the run. Correction
remained 0.299 units with zero recovery requests, so the pauses were not large
reconciliation pullbacks. This phase also exposed that the HUD reported zero
eligible presentation bodies despite the visible remote Jeep; presentation
mode-share fields from this capture therefore cannot be used as proof of the
Jeep's interpolation state and need separate instrumentation follow-up.

In the matched `latency120 / adaptive` phase, the estimator selected 100 ms.
The human observer described it as smooth overall, with only small, softened
stutters. Telemetry reported one eligible Jeep, 100% interpolation, no holds or
extrapolation, zero recovery requests, and the same 0.299-unit worst correction.
The remaining visible disturbances overlapped client performance and network
spikes: FPS briefly fell to about 36-41 with 48-52 ms frames while RTT/jitter
rose to roughly 316-317/56-59 ms. The adaptive buffer preserved continuous
interpolation through those spikes, explaining why the residual stutters felt
smooth instead of presenting as pullbacks.

The human `jitter / fixed 75 ms` phase was a clear visual failure: the remote
Jeep had strong jerky stutters, and nearby grass appeared spatially separated
ahead of the Jeep visual. Presentation packet variation p95 was commonly
35-50 ms, sequence gaps accumulated rapidly (over 500 during the observed
window), and RTT jitter reached 79 ms. FPS was often 60-90, so the persistent
Jeep-specific jerk was not explained by frame pacing alone, although one 66.6 ms
frame occurred. Worst correction reached 1.196 units with zero recovery
requests, below the 2-unit recovery threshold. The grass/Jeep mismatch is
consistent with the locally simulated world/camera advancing while the remote
Jeep's 75 ms presentation history repeatedly lacks enough margin under shaped
arrival variation; the matched adaptive phase tests that interpretation.

The first two attempts to enter `jitter / adaptive` exposed a presentation
clock-epoch bug and were discarded before evaluation. A multi-second network
clock correction could leave the monotonic render cursor outside its retained
history, producing an indefinite endpoint hold. The cursor now rebases only
when clock error exceeds the retained one-second history; ordinary corrections
remain damped. Focused tests cover large forward/backward rebases and normal
small corrections. The corrected run initialized directly into valid history.

In the corrected `jitter / adaptive` phase, the estimator ultimately selected
125 ms. The human observer still saw moderate stutters and occasional
vibration, but described the stutters as smooth rather than jerky; the earlier
grass/Jeep separation was not reported again. The steady portion remained at
100% interpolation with zero holds, extrapolation, or recovery requests and a
0.005-unit worst correction. Arrival variation p95 remained roughly 33-45 ms
and sequence gaps continued to accumulate. Some larger disturbances coincided
with simultaneous client/network spikes, including a roughly 47 FPS/61 ms
frame interval and an RTT-jitter rise to 144 ms. Adaptive presentation therefore
softened jitter failure into continuous motion but did not eliminate visible
cadence changes.

The restarted `combined / fixed 75 ms` phase was unexpectedly human-playable:
mostly smooth, with occasional small smooth stutters and vibration. The log was
not objectively gentler than the jitter profile: presentation arrival variation
p95 was often 40-65 ms and briefly exceeded 70 ms, sequence gaps exceeded 700,
RTT was generally 240-280 ms, and jitter briefly reached 82 ms. Client FPS was
commonly 40-52 with one dip near 37 FPS. Despite those pressures, worst
correction stayed at 0.505 units and there were zero recovery requests. This is
valid human evidence that fixed 75 ms can remain playable in some adverse
windows, but it does not overturn the clear `jitter / fixed` failure; feel is
sensitive to the timing pattern, camera-relative motion, and simultaneous frame
pacing rather than profile labels alone.

The matched `combined / adaptive` phase selected 100 ms and was human-rated
very playable and smooth. It occasionally produced a drawn-out but smoothly
blended stutter that did not disrupt motion. Presentation stayed at 100%
interpolation with zero holds, extrapolation, or recovery requests, and worst
correction remained 0.505 units. The longer disturbances coincided with local
slowdown windows around 35-39 FPS, 40-51 ms maximum frames, and rollback loops
around 25-33 ms while the presentation stream itself remained interpolated.
This indicates that adaptive buffering handled the network discontinuity, while
the residual drawn-out slowdown was primarily client frame/rollback pacing.

### Car Fight-specific StateBundle correction

The first direct port coalesced the newest whole StateBundle envelope. Under
120 ms latency, server resimulation can emit newer sparse envelopes for
different bodies. A newer body B envelope therefore evicted body A's latest
authority, leaving a client seconds stale and producing 26-56 unit corrections.

The 2026-08-22 forced-TURN follow-up found a second part of the same starvation
mechanism. A remote-input body is predicted at the server's current tick, so
netfox queues its newest settled authoritative state while replaying the newly
arrived historical input. StateBundle was flushing only the current tick after
rollback and discarding those replay-tick entries. The server-owned lane Jeep
and ball continued updating, which made aggregate state telemetry look healthy
while the browser player's own route could freeze and later teleport. A failed
bundle apply could also be ignored instead of entering coordinated fresh-key
recovery.

Car Fight now retains the newest post-replay entry for every recipient/route,
regroups those sparse entries by their original source tick, and drains them in
ascending order. This preserves bounded coalescing without a replay-envelope
storm. A coordinated recovery key is allowed through even when the current
remote input remains predicted, and a rejected key or delta now enters the
fresh-key wait/request path rather than silently freezing. Complete reliable
recovery keys remain atomic. Focused regressions cover multi-route starvation,
including settled replay entries from different source ticks. The focused
120 ms network gate also exercises bounded missing-reference rejection/recovery.

### Forced-TURN jump/teleport diagnosis and acceptance

The interactive harness now preflights its local and remote ports, assigns one
run ID to the browser, logs, server, TURN resources, and evidence directory,
requires matching identity plus WebRTC/state/RTT readiness, and cleans up exact
owned resources on normal exit, `INT`, and `TERM`. A lifecycle regression proves
both local ports can be rebound after each interrupt path.

Every correction at or above 0.10 units now records its before/after positions,
source/current/applied/pending ages, rollback/history/debt, recovery and
fast-forward recency/totals, frame/process timing, recent server-driver contact,
proxy-to-raw-authority distance/lead, map-transition recency, run ID, and all
matching `stall`, `stale`, `impact`, or `unknown` signals. The HUD exposes the
corresponding lifetime counters. Authority probing runs after the rollback loop
has settled instead of comparing against a pre-replay pose.

Human run `20260822T185708Z-56142-16179` used forced TURN, 120 ms one-way,
G2 divisor 1, proxy presentation 75-150 ms, the slow lane fixture, and the
accepted 1.05-radius/3.40-length capsule. With no contact the user reported no
jumps, teleports, stutter, or drone vibration. Applied route age stayed mostly
6-11 ticks, with zero stale recovery, rejected state, or fast-forward events.
Rear, head-on, repeated side impacts were then accepted in the same unchanged
session. Attributed impact corrections were bounded (about 0.176-0.561 units),
so collision prediction disagreement was not the visible teleport source.

Run `20260822T191625Z-58196-23649` repeated the exact configuration from a clear
spawn and injected one deliberate 695 ms browser-main-thread stall at tick 2839.
The user saw temporary low FPS/slow world motion but no network jump or teleport.
Telemetry confirmed a local frame stall (briefly 4 FPS), zero stale recoveries,
zero key requests, zero rejected states, and no accumulating fast-forwards. The
route caught up without a teleport-sized correction. The lane observer now
spawns at `(32, 0)`, clear of the fixture route, so this control no longer begins
with an accidental collision; ordinary gameplay spawn/handling is unchanged.

The evidence therefore identifies stale per-route publication as the teleport
cause. Controlled impacts are healthy in the accepted harness, and local frame
stalls remain visibly slow rather than masquerading as state-recovery jumps.
The accepted capsule remains harness-only; adaptive cadence and combined
impairment were not resumed.

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

The first human forced-TURN `clean / fixed 75 ms` phase was rated very playable,
with movement vibration and occasional small stutters. After browser startup,
frame pacing settled at 60 FPS/16.7 ms. RTT was normally about 20-30 ms, jitter
usually 8-17 ms with brief samples near 24 ms, and only two presentation
sequence gaps accumulated during the observed interval. Worst correction was
0.599 units with zero recovery requests. As with native fixed mode, per-body
interpolation/extrapolation/hold shares were not collected in this phase.

The matching human forced-TURN `clean / adaptive` phase was rated very smooth,
with no apparent issues and fully playable motion. Adaptive settled on the
75 ms tier. The observed steady state held 60 FPS, roughly 20 ms RTT, roughly
8-9 ms jitter, 100% interpolation, zero holds/extrapolation/recoveries, and a
0.342-unit worst correction.

In the human forced-TURN `latency120 / fixed 75 ms` phase, the Jeep visibly
stuttered while moving. RTT was commonly about 260-300 ms and worst correction
reached 1.502 units. Frame pacing was also unstable: it often recovered to
55-60 FPS, but one observed burst fell through 38.8 to 21.0 FPS with 52-70 ms
maximum frames while measured jitter rose above 116 ms. The visible result can
therefore include both remote-presentation stutter and whole-frame stalls.

The matching `latency120 / adaptive` phase was visibly unacceptable: general
choppiness and FPS drops accompanied jittery motion, pauses, jerks, pulling, and
noticeable lag. Telemetry corroborated the report. Adaptive saturated at its
150 ms tier, but snapshot headroom still went negative. Individual samples
recorded full-frame presentation holds of about 60-184 ms and occasional full
extrapolation. FPS fell near 29-31 during pressure bursts, application jitter
reached roughly 133 ms, sequence gaps reached 11, and worst correction reached
1.068 units. This is not a case where the current adaptive ceiling successfully
hides the impairment; presentation starvation and frame stalls coincide.

In the human forced-TURN `jitter / fixed 75 ms` phase, movement followed a
recognizable normal -> jerky -> jerky -> normal pattern. Unlike the latency120
case, the sampled interval held essentially constant 60 FPS/16.7 ms frames.
Measured jitter cycled roughly 24-73 ms and presentation sequence gaps climbed
rapidly (796 to 889 across the final sampled window). This phase isolates the
visible rhythm primarily to irregular remote delivery rather than render-frame
stalls.

The matching `jitter / adaptive` phase looked very smooth with no noticeable
stutter. Adaptive eventually selected its 150 ms tier while the client remained
near 60 FPS. The user also identified a correctness cue that the smoothness
metric does not capture: a small marker and the grass wake can run ahead of the
rendered Jeep, and collision occurs at that leading position. Code inspection
confirmed the mechanism. `player_body.gd` makes only `GroundVehicleHull` a
top-level delayed presentation root; `PeerMarker`, the `RigidBody3D` collision
shape, and `interactive_grass.gd` remain attached to or sample the current
authoritative body transform. The peer/server state is not itself divergent,
but gameplay collision and environmental reactions can visibly lead the delayed
hull by the active presentation buffer. Treat this as presentation correctness,
not merely cosmetic telemetry.

The human forced-TURN `combined / fixed 75 ms` phase was a hard failure. The
user observed a world pullback, repeated teleportation, the Jeep hull
disappearing while its authoritative marker moved far ahead, and the hull later
returning while still offset. Initial FPS fell as low as roughly 19-24, but the
later failure persisted even after rendering returned to 60 FPS. RTT grew past
4 seconds, application jitter exceeded 500 ms, sequence gaps exceeded 600,
recovery requests repeated, and worst correction reached 380 units. A 75-150 ms
presentation buffer cannot address this transport/backlog collapse. Browser
channel telemetry identifies the immediate failure: the nominally unreliable
channel repeatedly queued roughly 109-196 KiB, well beyond the 64 KiB acceptance
ceiling, while its requested 1 ms packet lifetime was reported as 0. Rollback
then repeatedly rejected correction origins that had become older than retained
history. This is queue/backpressure and stale-state recovery failure before it
is an interpolation-tuning problem.

A follow-up combined run enabled both adaptive presentation and the G2-derived
adaptive state cadence with a divisor-3 base. It was stopped before human
evaluation because telemetry had already failed acceptance: client unreliable
queueing reached 149 KiB, RTT exceeded 2.2 seconds, and presentation recorded an
837 ms hold with adaptive saturated at 150 ms. State cadence reduces server
state-envelope load, but this failure is dominated by the browser client's
unreliable uplink queue. Reject adaptive cadence as the solution to this case.

Removing the packed state-owner input exemption from the existing backpressure
valve fixed its narrow target in an automated full-rate combined retry: browser
queue maximum fell to 4,389 bytes and drained to 1,461 bytes, versus 109-196 KiB
in the failed human run. It did not make the row acceptable by itself. Steady
FPS averaged 18.2 because browser process time repeatedly reached 70-192 ms,
despite sub-1 ms physics and no measured rollback-loop time. Server telemetry
showed burst windows with hundreds of outgoing state entries per second. Test
the input valve together with lower/adaptive state cadence; neither protection
has passed combined impairment independently.

With the input valve plus divisor-3 adaptive cadence, an automated combined run
improved steady FPS to 33.4 but still failed acceptance; the browser queue stayed
bounded at 4,389 bytes. Server telemetry exposed recovery bursts with roughly
500 full-state acknowledgements per second. A follow-up coalesced successful
bundled-full acknowledgements into one route envelope per received bundle. The
new bundled ack path appeared in server telemetry and browser queueing remained
bounded, but steady FPS still failed at 25.0 with browser process spikes up to
748 ms and 20 stale-rollback warnings. Ack coalescing removes one amplification
path but does not solve the combined row. Do not resume human combined testing
until incoming stale/recovery burst work is bounded.

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

That ICE result is historical. Later Networking-1 work repaired the isolated
forced-TURN path and completed the fixed 120 ms jump/teleport gate described
above. It does not retroactively accept combined impairment or the earlier
over-64-KiB queue rows.

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
  678 maximum/102 final buffered bytes, and zero errors.
- The fixed 120 ms forced-TURN Networking-1 gate passes after per-route settled
  publication recovery: no-contact driving, controlled impacts, and a 695 ms
  client stall were human-accepted, focused checks pass, and the complete suite
  ends in `ALL_TESTS PASS`. Combined shaping remains unaccepted and deferred.

## Historical next-session sequence (completed)

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

## 2026-08-21 latest-G2 WebRTC presentation parity pass

Car Fight now uses G2's current adaptive timings (1 s epoch warmup and 750 ms
upward dwell), fractional `tick + tick_factor` presentation time, monotonic
damped cursor, and body-owned 30-tick clock-discontinuity rebase with fresh
warmup evidence. The rejected 0.35-unit visual/authority leash was removed.
Car Fight retains its rotation samples and the newer settled-publication,
per-route state coalescing, ACK bundling, and browser queue controls.

The first forced-TURN human A/B used the full-rate G2 stack against macai2 on a
clean network. Adaptive 75-150 ms was rated "not bad," with a repeating normal
then stutter cadence. It rapidly selected 150 ms and stayed there. During the
observed interval the browser was usually 60 FPS, accepted about 30 drone pose
batches/s, had essentially no sequence loss, replayed only 1-2 rollback ticks,
and continuously reported interpolation. Occasional 25-50 ms browser frames
exist, but packet starvation and deep rollback do not explain the repeating
motion symptom.

The matched fixed 75 ms run was worse: the user saw many forward pulls and
vibrations. It likewise held roughly 60 FPS, about 30 accepted pose batches/s,
shallow rollback, no recovery, and only a handful of sequence gaps over several
minutes. Clean adaptive is therefore the accepted side of this A/B, but neither
mode is yet clean enough to call the presentation path solved.

The next forced-TURN row used 60 ms fixed one-way latency and adaptive
presentation. The user rated it pretty good: smooth movement, occasional
whole-world hiccups, and only small/brief authoritative-center lead ahead of the
hull. The controller eventually held 125 ms. The measured steady interval was
normally 60 FPS, continuously interpolating, with about 30 pose batches/s, one
total sequence gap, no recovery, and one-tick rollback in most windows. The
small center lead is the expected consequence of buffering only the hull while
the collision body and environment remain current; it was materially less
objectionable here than in the earlier high-buffer runs.

The 60 +/- 30 ms jitter row remained visually smooth, but the authoritative
center led the hull more noticeably during forward acceleration and converged
again when the drone slowed or stopped. Adaptive held around 125 ms while the
browser remained near 60 FPS and continuously interpolated. The transport was
genuinely adverse: accepted receiver windows often contained only 19-27 of the
nominal 30 publications, with repeated stale/reordered batches and more than
1,500 cumulative sequence gaps during the long run. No recovery was required
and rollback stayed shallow. This demonstrates that G2 adaptive presentation
successfully hides irregular delivery, but its smoothness is purchased with a
speed-proportional visual/collision offset. Predictive presentation is the
planned follow-up after the shaping matrix.

The 60 ms + 0.5% loss row was again smooth, with occasional modest center lead.
Adaptive saturated at 150 ms, the browser was normally 60 FPS, and it required
no recovery. The user's collision-direction test made the correctness failure
unambiguous: a head-on ram appears plausible because the player meets the
leading authoritative collider, while a ram from behind can pass through the
visible delayed hull because that hull's collider has already moved forward.
Motion smoothness passes this row; collision readability fails it.

At 120 ms fixed one-way latency, the hull was generally smooth but the user saw
several whole-world teleports/hiccups and cases where the authoritative center
stopped while the hull continued moving. Telemetry corroborates both failure
classes. Adaptive saturated at 150 ms and repeatedly crossed between
interpolation, extrapolation, and holds up to about 83 ms as headroom fell as
low as roughly -130 ms. Separate bursts dropped FPS into the mid-40s/low-50s,
raised RTT near 370 ms, replayed 21-22 ticks, and recorded a 32.99-unit worst
local correction. The moving hull after the center stops is buffered or
extrapolated stale motion; the whole-world teleports are local correction/frame
bursts that remote-hull interpolation cannot hide.

The final 120 +/- 40 ms plus 1% loss row was a clear failure. The user saw
jerky motion, stuttering, and whole-world hiccups. Adaptive presentation was
already saturated at 150 ms while delivery variation ranged roughly 100-166
ms and accumulated more than 1,200 sequence gaps. Presentation holds ranged
from about 100 to 527 ms, headroom fell below -200 ms, FPS fell as low as 33,
RTT ranged roughly 340-590 ms, rollback bursts reached 40-46 ticks, and input
backpressure discarded as many as 50 inputs in a one-second window. A delayed
interpolation buffer cannot absorb this combined path; both remote delivery
and local correction/frame work are failing at once.

The completed matrix therefore selects adaptive buffering as the better
delayed-presentation baseline, especially at 60 ms latency or jitter, but does
not accept it as collision-readable. A separate `predictive` experiment keeps
the server-authoritative sphere current and predicts only the Jeep hull from a
correlated authoritative position, rotation, linear velocity, and angular
velocity sample. New sample error is reconciled with frame-rate-independent
visual smoothing; ordinary corrections are not hard-leashed, and true large
teleports reset the visual pose.

The first clean predictive human run was smooth overall but showed intermittent
vibration while the drone was moving. The corresponding interval remained at
about 60 FPS with 29-31 accepted pose batches/s, no recovery, no continuing
sequence gaps, and usually one rollback tick. That isolates the vibration to
the visual predictor's 30 Hz target correction rather than packet starvation,
deep rollback, or a whole-world frame hitch. The next revision advances the
visual pose continuously using the latest authoritative velocity and smooths
only accumulated prediction error, instead of low-pass chasing the entire
moving target.

That feed-forward revision produced smooth movement, but the user could still
see the center point behind the mesh at times. It therefore passed smoothness
but overshot the gameplay collider, reversing rather than solving the
collision-readability error. The next revision retains feed-forward motion but
uses the live rollback collider/center-point transform as its reconciliation
anchor. HUD telemetry now reports current/maximum visual offset and signed lead
(positive means mesh ahead along travel, negative means behind).

The clean collider-anchored run was rated "not bad": slight vibration remained
during movement, but the center point stayed synchronized with the mesh. During
settled portions the measured visual offset was about 0.03 units; during active
changes the one-second peak samples seen in telemetry were roughly 0.2-0.5
units and crossed both lead signs. This is the first predictive variant to pass
the user's collision-alignment check, so it advances unchanged to shaped-path
testing rather than being tuned further on clean traffic.

At 60 ms fixed latency in each direction, the collider-anchored predictive
version was rated "pretty good" and smooth, with the center point and mesh
aligned and very few noticeable issues. The browser stayed near 60 FPS and
accepted about 30 pose batches/s without recovery. Current visual offset was
usually below roughly 0.15 units; brief one-second peaks reached about 0.4-0.6
units around timing/correction changes and then settled. Unlike the matched
adaptive row, the user did not see a persistent speed-dependent collider lead.

Under 60 +/- 30 ms jitter, the collider-anchored predictive version was rated
smooth and "not bad," with only occasional slight vibration. The browser held
about 60 FPS while accepted pose windows varied around 22-28/s with repeated
stale/reordered publications. Current visual offset was commonly about
0.03-0.13 units with brief peaks around 0.35 units. No speed-dependent
center/mesh separation was reported, making this stronger than the matched
adaptive jitter result for collision readability.

At 60 ms each direction plus 0.5% loss, the collider-anchored predictive run
was rated "pretty good," with smooth movement and accurate collision. This is
the decisive improvement over the matched adaptive row: rear and head-on
interaction now agree with the visible Jeep because the hull reconciles to the
same live sphere used by gameplay instead of a delayed presentation timeline.

At 120 ms each direction, collider-anchored predictive presentation clearly
failed: the user saw stop-and-go movement and teleporting. This reproduced
after a restart. The browser still held about 60 FPS and the dedicated drone
stream delivered about 30 clean batches/s, so remote packet starvation was not
the cause. The state path repeatedly applied snapshots about 6-12 ticks old and
replayed roughly 8-14 ticks in correction bursts; visual/collider offset spikes
reached about 8-15 units before reconciliation. At this latency the live remote
RigidBody collider itself is discontinuous. Following it exposes the teleport;
buffering the hull hides the teleport only by making collision false. Further
presentation-only tuning cannot satisfy both requirements. The next experiment
must change the remote collision proxy/state model rather than add more visual
delay, and a combined-impairment playtest is deferred until that source motion
is improved.

The first broad client-side proxy implementation was rejected before human
playtesting. In the 120 ms two-client gate, independently predicted collision
proxies changed player/player contact timing and caused 10.96-18.62 unit local
corrections. The experiment is therefore restricted to the server-owned peer-1
Jeep used by the Networking-1 fixture. Actual remote players retain the
rollback collider; expanding proxy collision beyond the fixture requires a
separate collision-authority design and acceptance gate.

The fixture-only proxy at 120 ms made the server-driven Jeep smooth and kept
its center marker aligned, but the original sphere left the long nose outside
the readable contact volume. A drone-only horizontal capsule (1.05-unit radius,
3.30-unit total length) fixed that geometry. The user rated front, rear, and
Jeep-into-player contacts correct, and the translucent collider visualization
confirmed the capsule's longitudinal orientation. Normal player colliders are
still the original equal-mass spheres.

That collision-shape success did not make the 120 ms proxy acceptable. During
the same capsule run, the user repeatedly saw their own Jeep teleport. The
transport remained healthy after startup (about 260-270 ms RTT, roughly 30
remote pose batches/s, near-60 FPS, and only two cumulative pose-sequence gaps),
but the client recorded a 206.88-unit worst local correction. The local proxy
is an AnimatableBody driven by predicted server samples, while the server
resolves contact against its delayed dynamic drone. Their contact outcomes
therefore diverge and the eventual authoritative correction moves the local
player. Conclusion: the capsule is accepted as the drone fixture's collision
geometry, but predictive client collision at 120 ms is rejected; solving it
requires collision prediction/reconciliation shared with the server, not
another remote-presentation adjustment.

A rollback-aware fixture proxy reduced but did not eliminate 120 ms local
corrections. Human repeats rated capsule contact good and reported only a few
short jumps, while recorded worst corrections varied from roughly 29-32 units;
an earlier long run reached 102.73 units versus 206.88 for the first proxy.
The revision switches from the predicted AnimatableBody to the rollback-restored
server body only during replay, then restores the predicted proxy for live
frames. This improves contact replay but remains experimental rather than an
accepted 120 ms solution.

The drone capsule was lengthened from 3.30 to 3.40 units after an all-vertex
footprint check found the Jeep's extreme front corners exceeded the original
rounded cap by 0.03 units. The revised capsule contains the complete measured
Jeep footprint and the user reported improved nose contact.

An opt-in synchronized player-capsule experiment felt better to the user, but
the automated delayed-contact gate remained inconclusive and variable: the
capsule passed clean at 0.005 units but produced 35.42 units at 60 ms and
62.22-67.74 at 120 ms; a subsequent sphere control also failed once at 15.10
units at 60 ms. A later 120 ms forced-TURN human repeat used capsules for both
Jeeps and a slow, non-evasive server driver. The user rated collision good and
accepted the shape for the Networking-1 harness. A global-default attempt was
not retained: the longer footprint made elevated-road landing response
intermittent, overlapped the sphere-era reverse fixture spawn, and changed
projectile/shield pitch response through its greater rotational inertia.
Speculative global handling compensations were removed. Ordinary gameplay
therefore keeps its proven sphere while the WebRTC harness explicitly passes
`--player-capsule` for both Jeeps. Full gameplay capsule integration is a
separate follow-up with course, reverse, impact/shield, and complete-suite gates;
the accepted capsule dimensions must not be retuned to make those gates pass.

The first slow-lane run was discarded as a degraded network session rather
than a collision result: RTT spiked to 572 ms, jitter to 312 ms, a browser
processing pause reached 695 ms, applied state fell roughly 300 ticks behind,
and local correction reached 28.9 units. After stale test tunnels and the old
web server were cleared, the accepted repeat connected at about 263-271 ms RTT,
60 FPS, 3-11 ms jitter, no state fast-forwards, and 7-8 ticks of applied-state
age. This confirms the collision judgment came from the clean repeat.

During the first all-capsule human run, the drone mesh disappeared while its
cyan debug capsule appeared frozen. Telemetry showed the local player changed
from map 0 to map 1 and same-map relevance correctly emitted one leave with
zero active remote bodies. The actual proxy collider was disabled; only its
debug MeshInstance failed to follow presentation visibility. The debug visual
now hides and reappears with the hull.

The detailed handoff for harness hardening, correction attribution, controlled
reproduction, evidence-directed fixes, and the 120 ms acceptance gate is in
`NETWORKING_1_NEXT_STEPS.md`. Treat it as the next-session execution order.

## Networking 2 forced-TURN reconnect soak

The first 600-second reconnect diagnostic (`20260822T220221Z-64340-8982`) was
not a valid no-contact run. The browser monitor deliberately moved the mouse far
right after both joins and left it there, so the replacement drove until it
reached arena geometry. It stayed connected and emitted no browser error, but a
local 9 FPS interval, one stale recovery, and contact/geometry produced a
4.845-unit correction. This is local-frame/contact evidence, not TURN loss:
179,106 shaped packets crossed the relay with zero drops.

Moving the pointer to canvas center was also insufficient because the isometric
camera projects that point ahead of the car. The stationary-speed diagnostic
then exposed a 3.833-unit startup rebase from `(32.00,24.00)` to
`(35.82,23.69)`. Long soaks now request the harness-only `script=idle` mode,
which supplies explicit zero input every simulation tick. Short movement smokes
and ordinary interactive browser input retain their previous behavior.

The corrected 60-second proof (`20260822T222127Z-65824-28020`) passed with zero
recoveries, 0.001-unit worst correction, zero measured movement, 49.1 steady
average FPS, and 20,363 TURN packets. The final 600-second run
(`20260822T222345Z-66042-30123`) stayed joined for 607 shared-world samples with
zero recoveries, 0.000887-unit worst correction, 0.00013-unit maximum planar
displacement, zero browser errors, a 3,558-byte peak browser queue, and 194,333
TURN packets with zero drops. Its final renderer window held 30 FPS minimum and
41.67 average. Long unattended durability therefore uses a 30/40 FPS floor;
the short playable smoke keeps its established 30/45 floor. The network result
is accepted, and two real player peers are the next isolated Networking-2 step.

## Networking 2 two-player moving-observer result

The mixed harness now launches one native direct-ENet player and one Chrome
forced-TURN WebRTC player against the same macai2 mux server. It retains the
120 ms one-way profile, divisor 1, fixed proxy presentation at 75-150 ms, and
the harness-only 1.05-radius/3.40-length capsule. A 480 x 480 harness arena gives
both players long straightaways. Pressing `P` supplies full-speed, non-burst
cruise through the client-local input path; pressing `L` starts/stops a bounded
presented-motion trace whose samples carry monotonic/unix time, frame cadence,
network presentation, correction, recovery, and rollback context.

The diagnostic also closed a harness race. Interrupted run
`20260823T192219Z-78896-3138` overlapped a retry before either launch owned its
ports. Chrome ran about 109 ticks ahead and repeatedly performed 6-22-unit stale
recoveries even though WebRTC remained open. An atomic per-port run lock now
precedes build, sync, port checks, and remote mutation; the lifecycle test
requires a concurrent launch to be rejected.

Clean run `20260823T193206Z-79977-10265` contained no stale recovery. With native
moving while observing Chrome cruise, the 21.2-second trace held 59 median FPS,
0.0384-unit p95 residual, and four frame stalls. With Chrome moving while
observing native cruise, the 21.6-second trace ran at 32 median FPS, measured a
0.0578-unit p95 residual, and had three frame stalls. Lateral residual was tiny
in both cases; variation was predominantly longitudinal and correlated with
frame excess. This identifies local render cadence, not stale-state recovery or
collision prediction disagreement, as the subtle moving-observer tug.

The accepted fix is opt-in and presentation-only. The local rendered hull and
camera anchor are detached from the raw rollback body, advanced by current raw
linear/angular velocity, then reconciled with frame-rate-independent 50/60 ms
position/rotation half-lives. A pose difference above 2 units snaps so a genuine
teleport is not concealed. Input, physics, rollback, and collision continue to
use the raw body. Ordinary gameplay does not enable this path.

Human acceptance run `20260823T202607Z-81872-13577` kept that exact network
configuration and enabled local presentation on both clients. Chrome driving
beside the cruising native Jeep was smooth with no visual issues; after swapping
roles, native driving beside the cruising Chrome Jeep was also smooth with no
issues. Both clients recorded zero stale recoveries. Native median FPS was 85
and Chrome median FPS was 42. Chrome continued to receive expected small,
mostly 0.3-unit rollback corrections, but they no longer appeared as visual
tugging. The result improves client-local presentation without promoting or
retuning the capsule, enabling adaptive cadence, or testing combined impairment.
Focused checks, Web export, harness lifecycle, and the complete
`./scripts/test.sh` suite pass (`ALL_TESTS PASS`).
The accepted launcher retains `P` cruise for repeatable driving comparisons but
leaves `L` motion tracing disabled. Ordinary play enables neither control.
