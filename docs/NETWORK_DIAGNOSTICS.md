# Connection versus processing diagnostics

Opt-in native diagnostics for the question: did traffic stop arriving, or did
the game stop processing it? Keep the same two-client scenario and networking
settings. This does not change simulation, rollback limits, packets, or buffers.
Browser instrumentation/validation remains a later task.

## What is recorded

- `diagnostics/network_stage_trace.gd`: per-network-loop forward, rollback
  preparation, simulation and history-recording elapsed spans; frame callback
  gaps; focus; native ENet local UDP port; repeated monotonic/system-clock anchors.
  Server records also identify per-recipient presentation publication queueing.
- Existing presentation trace: accepted/rejected legacy deliveries, playback
  modes, headroom and cursor timing. Existing monitored telemetry/process samples
  retain CPU limits, process load and crash evidence.
- `scripts/network_packet_capture.mjs`: independent, non-promiscuous tcpdump
  capture restricted to one explicit IP and UDP port. It saves a private PCAP,
  stderr/drop statistics and `capture.json`; it refuses an existing output folder.
- `scripts/network_diagnostics_report.mjs`: separates sibling clients by local
  UDP port and aligns the largest callback gaps with captured incoming packets,
  loop timing and presentation observations. An optional server trace adds server
  phase and per-recipient publication-spacing summaries.

The observer is registered before StateBundle and gameplay nodes. Forward spans
end at the observer's `after_tick` callback, before later subscribers; rollback
phase boundaries run before gameplay subscribers to the next phase. Rollback
total ends before later `after_loop` callbacks. The outer network span includes
the rollback call but ends before subsequent publication subscribers. These are
documented signal boundaries, not a complete partition of every engine task.
Nested durations overlap; never add forward/rollback/phase totals together.
They include waiting/descheduling and are **not CPU execution times**. No vendored
clock or rollback implementation was edited to obtain them.

## Startup snapback investigation, 2026-09-05

Owner reports roughly three move/return-to-start cycles on joining, followed by
normal play; this predates the latest presentation experiment. Treat startup
readiness/reconciliation as a networking issue to investigate, not as harmless
FX or proof of a sustained client/server speed difference.

Owner subsequently clarified that this has happened since networking was first
introduced, months ago, and reported four resets in the latest rendered trial.
Treat onset as a longstanding baseline defect, not a regression introduced by
this review or the elapsed-cursor change. This history is owner-reported, not a
commit bisect; it does not rule out recent changes affecting severity/duration.

Read-only evidence from `.crash-runs/two-client-20260905-035412/`:

- Alpha `alpha/20260905-035412/client.log`: `CLIENT_READY` at line 17, initial
  timestamp at line 22, clock panic offset 6.109638 seconds at tick 899, then
  repeated stale-authority recovery (first full-state application tick 1309).
- Bravo `bravo/20260905-035415/client.log`: same connection-before-initial-sync
  ordering, clock panic offset 4.548247 seconds at tick 1078, then repeated
  recovery (first full-state application tick 1374). Warning output is duplicated
  by logging; duplicate lines must not be counted as separate clock resets.
- Early periodic local positions remain at the spawn points. They cannot prove
  or exclude short move/reset cycles between samples. No per-frame local pose
  timeline ties these recoveries to the owner's observation.

`Main._connect_network_events()` labels `on_client_start` as `CLIENT_READY`;
that is not a settled-gameplay guarantee. `NetworkTime.start()` already waits
for initial synchronization before activating tick processing, and
`RollbackSynchronizer` defers its callbacks until `after_sync`. Local input is
gathered on `before_tick_loop`. A simple initial-sync boolean guard is therefore
not an established fix for later clock changes or stale authority recovery.

Next bounded characterization: moving input from initial join, a no-stall
control and the existing opt-in post-sync `JOINSTALL` hook. Correlate bounded
local simulation/presented pose samples with input ticks, authoritative state
application, time-sync/panic events, frame gaps and spawn generation. Reuse
existing diagnostic infrastructure; the manual motion trace currently targets
the remote player and does not fill the startup local-pose gap. Distinguish
reconciliation, respawn and camera/interpolator movement before changing code.

Do not mask the issue with an arbitrary startup delay or weaken stale-state
guards. Preserve the coupled pause-timeline reset and rejected half-RTT seed
decision. Any clock/recovery fix needs focused characterization plus pause,
join-transient and reconnect gates; rendered confirmation still requires an
approved monitored run. No runtime changes or new runs were made for this review.

### Instrumentation follow-up

The existing stage recorder now accepts `CAR_FIGHT_STARTUP_TRACE_SECONDS` (off
by default, at most 60 seconds and never beyond the parent trace duration).
It records at most 6,000 local-body frame samples, under the shared 30,000-record
cap. `startup_samples`/`startup_dropped` in the completion footer expose the
additional sample limit. Shared-cap losses still appear in `dropped`.

Each sample includes monotonic time, connection epoch, node instance/spawn
generation, tick/reference clock, direct physics pose/velocity, Node3D pose and
presented position, latest state/input ticks, consumed authority/prediction
frontier, exact history at the latest state tick, and recorded cursor/editing.
Missing history/input is null, not zero or an older fallback. Samples read the
local body afresh through the connected-peer guard; no retiring nodes are cached.
Sync and panic signals are observed only when explicitly enabled and all
observers disconnect when the parent recorder stops.

Sampling occurs at the existing stage recorder's process callback, not at every
state application or after every presentation callback. Node, physics and visual
poses can therefore represent different update phases. The state history is
mutable simulation history, not a preserved authoritative packet; its latest
tick can initially be a seeded sentinel. Do not equate these fields with exact
server-state receipt or application timestamps. The trace adds no RPCs, replicated
objects, simulation writes, readiness gates or clock changes. Cost is bounded to
one local body and retained input history per sampled frame; no matched rendered
overhead measurement has been made.

Run the bounded, local headless characterization:

```bash
zsh scripts/startup_trace_test.sh
node scripts/network_startup_report.mjs /absolute/run/startup.jsonl
```

The harness uses the pinned Godot, local ENet port 11980 (override with
`CAR_FIGHT_STARTUP_TEST_PORT`), one client with existing `--script right`, and
separate no-stall/six-second-post-sync-stall cases. It checks readiness, bounded
client completion, engine errors, complete traces and actual movement. PASS is
evidence capture, not a correction ceiling or a smooth-play verdict. The report
flags returns within 0.1 units of the first sampled pose after moving at least
0.25 units away, and backward steps above 0.1 units under similar recorded intent.
These thresholds select candidates, not bugs; collisions/turns can qualify.
Identity changes are never joined into a motion delta. CLI exit 2 denotes
incomplete/missing evidence; exit 0 does not establish acceptable networking.

First headless results: `car-fight-startup.Rw96DP` under the local temporary
directory recorded 578/235 samples, no drops/errors, and no return-to-first-pose
candidates. The control's largest early backward physics step was 1.371 units;
the stall case's early step was 0.275 units. A later 0.102-unit backward step
occurred while travelling sideways, illustrating why candidates are not proof.
The six-second pause used one reliable state recovery and did not cause the
multi-second clock panic seen in rendered startup. Some fast import/check work
overlapped the control: do not use these runs as matched performance evidence.

Separate socket-free characterization, using the actual unchanged NetworkTime
loop and injected test clocks, stepped only the reference clock by +6.109638
seconds while callbacks advanced normally at 60 Hz. With existing maximum
stretch 1.25, reference-minus-tick lag was 5.860 seconds after one second, 3.610
after ten, 1.110 after twenty, and about -0.007 after twenty-five. The zero-offset
control stayed within one tick. Retained script:
`.network-runs/startup-clock-characterization.gd`. This establishes slow catchup
after a reference jump without a pause, not its upstream cause or the owner's
exact three-reset sequence. `_set_timestamp()` seeds from the received timestamp;
a delayed initial timestamp remains a hypothesis to reproduce with moving input.

Validation: stage/startup fixture (real synchronizer/history, separate pose
sources, missing history, replacement, deadline/cap/flush), Node report fixtures,
presentation trace, remote-position transport, and existing pause-clock regression
passed; fast check passed. The new harness also rejected a failed server command
as expected. Initial compile/fixture errors were fixed before clean reruns.
Diagnostic integration exposed an unused vendored getter bug:
`RollbackSynchronizer.get_last_known_input()` calls nonexistent history `keys()`.
No vendored repair was made; the trace uses guarded `get_latest_tick()` instead.
No new rendered, browser, macai2 or deployment run; shared-clock changes still
require the larger gates described above before promotion.

### Completed rendered startup trial

Owner approved two monitored macOS clients at runtime `b84a5a4`, with the elapsed
cursor opt-in retained and startup trace enabled for 60 seconds. Both clients
used the isolated macai2 mux/ENet endpoint UDP 12780, three-second launch stagger,
ordinary inset windows and P cruise support. No injected stall or packet capture.
Owner saw four early move/return-to-origin resets and confirms this behavior
dates back to the introduction of networking months ago.

Alpha's recorded physics and presented positions confirm four large returns to
its spawn near planar (-3, 0), without an instance or generation change:

| Process monotonic seconds | Return distance (units) | Latest state tick | Reference minus client tick (seconds) |
| --- | --- | --- | --- |
| 26.245 | 5.571 | 1627 | 3.743 |
| 30.434 | 7.810 | 1896 | 2.604 |
| 33.942 | 6.359 | 2091 | 1.710 |
| 36.011 | 5.568 | 2244 | 1.230 |

There are also smaller 0.573/1.612-unit return candidates at process seconds
20.611/36.386. The table isolates the four large returns matching the owner's
description, not four total threshold crossings. Alpha initially synchronized
at process second 17.298, then corrected its reference clock by +4.723 seconds;
Bravo corrected by +4.299 seconds and had no return-to-first-pose candidates.

For each large return, sampled history at the latest state tick holds the
stationary spawn pose. Those ticks match reliable recovery sends in the server
log and accepted recovery entries in the client log. Importantly, each key was
first observed in client history 1.1-1.7 seconds before its large return: these
are not measured immediate-on-receipt teleports. Display/state history selection
while the client's timeline trails authority needs to be covered by the fix.

Server NETAPP windows from ticks 1263 through 2106 show incoming input traffic
but no input-driven rollback origins; those origins start later, first for
Bravo, then Alpha. The input encoder silently skips timestamps older than
`NetworkRollback.history_start` (current server tick minus 64). Combined with
the multi-second lag and stationary recovery poses, this strongly supports
inputs aging out while local motion continues and recovery restores the spawn.
It is not a per-packet rejection trace: input receipt timestamps/content and
exact state-application callbacks were not recorded, nor are host clocks assumed
aligned. Do not call this proof of packet loss or blame the recent cursor change.

The normal authority-probe maxima were only 0.642 units for Alpha and 0.618 for
Bravo. They do not represent the 5.6-7.8-unit startup returns: startup history
coverage/measurement timing leaves a diagnostic blind spot. Acceptance of the
repair must include the actual physics/presented-position timeline, not only a
passing correction-probe limit or `CLIENT_READY` marker.

Evidence: `.crash-runs/two-client-20260905-193712/`, Alpha subrun
`20260905-193712`, Bravo `20260905-193715`; server log/trace and generated
`alpha.startup-report.json` / `bravo.startup-report.json` are under
`.network-runs/startup-20260905-193556/`. Client stage footers have 13,338/13,261
records, 2,418/2,390 startup samples and zero drops; server trace is complete,
zero drops, 4,934 network loops. Both clients closed before the requested
120-second trace deadline and flushed normally, not by truncation. No client or
server engine/script errors were found. Server elapsed loop maximum 153.229 ms
is a separate timing observation, not an explanation for the startup returns.

Both clients exited zero at 19:39:08/09 CDT; isolated PID 9955 stopped and its
logs were collected. The completed non-restarting launch job was removed.
Production PID 57599/UDP 10080 was unchanged. No runtime changes were made during
analysis. Next is a bounded startup timeline-recovery fix with an automated
server-ahead/moving-input reproduction, existing pause/join/reconnect gates,
and a separately approved human retest. Preserve the coupled rebase and stale
history guards; do not increase rollback history or hide the defect with delay.

### Browser clock recovery follow-up, 2026-09-06

The first native/browser admission trial (`mixed-20260906-022852`) connected
WebRTC peer 2 but failed gameplay readiness. Browser logs recorded 367 receive
buffer overflows, incoming state roughly 280 ticks ahead of local simulation,
and sample FPS as low as 6. The native client activated successfully. The
upstream [Godot WebRTC receive path](https://github.com/godotengine/godot/blob/master/modules/webrtc/webrtc_data_channel_js.cpp)
emits this error when its inbound ring buffer cannot fit a received message.
This is evidence of receive-buffer exhaustion, not proof of network packet loss
or the exact CPU/GPU cause of the preceding stalls.

Two bounded recovery gaps are addressed, still opt-in:

- `forwardClockRecovery=1` in a Web Network URL now selects the same recovery
  path as native `CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1`. Omitted/other query values
  select false on each scene start. `[network-clock] forward_recovery=...`
  reports the actual selection. Offline export is unchanged.
- An aligned simulation clock can coexist with old scheduled ticks after
  repeated slow frames hit the eight-tick cap. The previous recovery checked
  only clock offset, so this case was missed. Recovery now also checks work
  left over from the prior loop against the existing panic threshold, then
  rebases clock/tick/schedule together. The current frame's ordinary pending
  tick does not change the threshold boundary. Clients only, active and synced,
  connected, never rewinding an already-ahead tick label; no buffer, traffic,
  history, input schema, authority, admission timeout or default changes.

The new unit first failed for aligned-clock/four-second tick backlog; final
coverage includes sustained five-FPS frames, unchanged work cap, default-off,
thresholds, ahead-tick protection, server/offline/connection states and Web
configuration. Startup/retry `car-fight-startup.l2z9ex` passes five returns to
zero, neutral pre-ready intent and two admissions. Stall `dhbtbb` and reconnect
`26Ch0F` pass with admission and both client flags. Pause/readiness units pass.

Final Web release export `car-fight-web-export.C6ESlu` passes. Bounded localhost
headless Chrome evidence is in `.network-runs/browser-recovery-check/final/`:
actual absent-query and opt-in selections both joined and drove, with fresh
peer identities across page navigation and two server admissions. Zero engine
errors; one opt-in missing-diff-reference warning recovered via a full snapshot.
Neither case reproduced the original overload or needed a forward rebase; this
proves Web wiring and basic lifecycle, not the original fix under rendered load.
The first local check incorrectly classified Godot warnings on console.error as
engine errors; retained evidence at the parent directory shows that harness
failure. Final checks still reject engine errors/uncaught exceptions.

Next approved human trial must explicitly select `startupReady=1` and
`forwardClockRecovery=1` for the browser. Elapsed remote cursor remains
native-only. Receive overflow prevention, rendered performance and the reported
native movement at the visible joining transition remain unresolved. Do not
declare the full browser failure fixed from these bounded checks.

### Rendered mixed retest, 2026-09-06

Owner-approved runtime `fb20961` trial `mixed-20260906-024954` admitted both
native ENet and Chrome WebRTC clients. Owner reported smooth observation in
both directions. Browser explicitly selected recovery, but neither client
logged a forward rebase; this is successful joining/observed smoothness, not
causal proof that the recovery fixed the earlier overload. No buffer overflows
or engine/script errors appeared; browser logged three stale-rollback warnings.
Native and server stage traces are complete with zero drops; native startup
has 983 samples and zero return-to-first-pose candidates. Browser stage/startup
coverage is still unavailable. Trial and isolated server shut down; production
unchanged. No human reconnect/background-resume test was performed.

Do not accept all diagnostics: browser authority-probe error reached 15.800
units at tick 2130, about 4.3 seconds after browser readiness and before native
activation. Adjacent evidence contains an FPS=1 sample, stale rollback and a
full-state recovery. The probe compares historical client/server poses; it does
not directly measure an applied visual jump. Next-largest browser probe error
was 1.500 units; native worst 1.866. Preserve the startup outlier above the usual
two-unit ceiling and investigate the stall/recovery/history sequence separately
from the owner's sustained smoothness report. Native movement at the visible
joining transition also remains unresolved, not implicitly accepted here.

### Readiness moving-target fix, 2026-09-06

The last native trial first sampled a synchronized body at process 20.473 s
and became playable at 42.726 s. Its late waiting samples repeatedly show
latest authority ticks a few ticks ahead of local simulation, even while the
simulation/reference tick offset is small. Those old traces do not record the
remaining remote-clock offset or full-sample-window condition, so they cannot
quantify how much of the wait this particular condition caused.

The policy had a reproducible starvation case: it required the newest received
snapshot to be consumed and not future on the same observation. With a steady
five-tick-ahead stream it never admitted, although previously received state
had reached the local timeline. The gate now retains one actually received,
consumed state tick from after clock validation. It releases only when that
tick is nonfuture, inside retained history, and the consumed watermark still
covers it. Newer packets do not move the target. Clock instability, history
expiry, replacement and retry invalidate it. Timeouts, clock requirements,
neutral input, server admission and all networking defaults remain unchanged.
The witness is one scalar per gate; no new traffic or replay state.

The focused unit failed before the fix and passes afterward, including future
and unconsumed rejection and all witness invalidations. Real startup/retry
with admission `car-fight-startup.TK8mT8` passes six returns to zero and neutral
waiting input. Native mux/WebRTC admission `MWQC4Z` passes hidden/physics
isolation, late join and normal post-ready movement. Fast check, stage unit and
Web release export `z58giA` pass. No whole-suite rerun or rendered launch.

Actual headless browser check `browser-recovery-check/readiness-witness` joined
and moved with recovery absent and enabled, but failed the strict server-log
scan during page disconnect: SCTP send errno 54, data-channel errno 102/FAILED
from state transmission immediately before peer 2 departure. Both browser
sessions had one recovered missing-diff-reference warning and no engine errors.
The server error remains a failed lifecycle result; do not hide it behind the
two successful joins or relax the log filter. This does not establish whether
the disconnect race predates the readiness change.
One isolated rerun `readiness-witness-retry` passed both admissions and movement
with zero server/browser engine errors (one recovered enabled-case warning).
Keep the first failure as intermittent lifecycle debt. All local test services
exited; no human test or production service was launched or changed.

Startup stage records now also expose `clock_offset_seconds`,
`remote_offset_seconds`, and `fresh_clock_samples`, so a future capture can
separate both clock requirements from the authority-state wait. Before initial
sync the two offsets are null, not zero. No claim yet of a measured rendered
startup-time reduction; loading and shader preparation are not changed.

### Forward clock recovery experiment, 2026-09-05

`CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1` opts native clients into a forward-only
whole-timeline rebase when the reference clock leads the simulation clock by
more than the synchronizer's panic threshold (currently two seconds). The
default remains off. This is a **partial fix, not startup acceptance**.

The existing 1.25x clock stretch took many seconds to consume a multi-second
correction. During that interval the server could reject old input timestamps
while the client continued to predict movement. The experiment reuses the
existing pause recovery: clock, tick label, next scheduled tick and stretch
reset together before emitting more input ticks on the old timeline. Small or
negative reference corrections retain ordinary clock discipline; existing
pause handling is unchanged. Only connected, initially synchronized, active
clients qualify. Server, offline and disconnected behavior is unchanged.

Contract: owning clients still supply intent and peer 1 still owns bodies;
wire schemas, replication classes, physics and stale-history guards are
unchanged. No new RPCs, queues or retained history. Selection adds a constant
guard per network loop, with a log only on recovery, and does not replay skipped
ticks. Actual pause recovery remains capable of rebasing in either direction;
the new reference-gap trigger itself never rewinds. CPU/traffic savings have
not been benchmarked; this is correctness evidence, not a performance claim.

Run the focused reproduction without rendered windows or macai2:

```bash
zsh scripts/startup_trace_test.sh --clock-recovery
```

The test-only SceneTree entry point registers before initial sync and makes the
initial timestamp 4.7234838 seconds stale. Real ENet traffic and normal ping
samples must discover the error. A six-second **server-only fixture warmup**
keeps injected timestamps positive; no production/client startup delay was
added. The harness runs recovery off/on sequentially, drives a real player,
captures history/physics samples and rejects incomplete traces or runtime
errors. It requires a repeated-return positive control, stable corrected time,
exactly one rebase, and **zero** return-to-first-pose candidates with recovery.
This opt-in acceptance gate currently fails its zero-return requirement; do
not weaken it to accept one return. It is not part of the broad default runner.

Evidence: local temporary directory `car-fight-startup.LpvW67`, `recovery-0/`
and `recovery-1/`, each containing server/client logs, `startup.jsonl` and
`report.json`. Control reproduced five returns, with roughly 14-unit largest
backward steps and a 4.90-second maximum reference-minus-tick lag. Recovery
produced one rebase and one remaining 14.040-unit return at process second
4.078, about 21 ms after the panic. The sampled latest authority history still
held spawn. In 1,342 samples more than 500 ms after panic, absolute tick/reference
offset stayed below 27.414 ms. Both traces completed with zero drops and no
engine/script errors. An earlier fixture run `car-fight-startup.xZLIbk` failed
on a GDScript type annotation; fixed before the measured A/B.

Interpretation: correcting the timeline removes prolonged catchup and repeated
returns, but cannot preserve earlier predicted movement whose timestamps the
server could not accept. Initial timeline acquisition/readiness remains the
next focus. Investigate why prediction can begin on an untrustworthy initial
timeline, with an evidence-based readiness condition rather than an arbitrary
delay. Do not relabel client movement as authoritative, enlarge history, or
restore the rejected half-handshake-RTT seed to hide the first reset.

The injected-clock unit regression failed before the runtime change and passed
afterward, including default-off, small/negative offsets, threshold boundary,
server/offline/disconnected/sync-pending guards and 900 subsequent frames.
Existing pause regression passed. Live join/reconnect results and final checks
are recorded in `.ai/CURRENT_PHASE.md`. Shared-clock milestone validation is
still required before merge; native rendered and browser acceptance remain
pending. No deployment, networking-default change or new human launch occurred.

### Server admission extension, 2026-09-05

Owner approved keeping a joining vehicle out of everyone else's game, not
just hiding its owner's screen. Select `CAR_FIGHT_SERVER_ADMISSION=1` on a
matching-build test server. It is off by default. A required-admission spawn
automatically enables the owner's joining gate, including clients without
`CAR_FIGHT_STARTUP_READY=1`. Explicitly select that client flag for the next
rendered trial so its overlay is present before connection. Keep
`CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1` for the tested native startup path.
No old-binary interoperability or browser acceptance is claimed.

Contract and reasoning:

- Server peer 1 still owns physics/state; the client reports readiness, never
  a position or an activation time. The request uses its actual RPC sender,
  current body generation and a received state tick within server history.
  Unknown/replaced bodies, stale generations, future/stale ticks and repeated
  activation requests cannot activate a different body or move its activation.
- A pending body stays in the existing spawner/rollback/remote-state paths so
  the owner can validate real authority state. Its root is hidden, physics is
  frozen with zero collision layer/mask, and its gameplay tick returns before
  movement/weapons/tractor. Gameplay query filters also exclude it from combat,
  troop recruitment/deployment, dot collection, grass and offscreen markers.
  Editing visibility cannot reveal it. This is not a traffic-saving change.
- Once client timing/state readiness is established, a reliable request asks
  for admission. The server broadcasts a reliable generation/activation-tick
  event for its next tick. Input and the joining overlay wait for that event
  and tick. Physics participation is derived from the actual rollback tick,
  not a mutable presentation boolean; replay before activation stays inert.
  Late joiners receive existing activation events after replicated spawns.
- Each body generation activates once. Replacement/retry requires fresh
  readiness and admission. Existing independent joining times are intentional:
  a slow client does not hold every player at a barrier. Event delivery can
  differ by network latency; this does not promise simultaneous screen reveal.
- Client requests are paced to at most one per second, with a 30-second
  admission-response timeout; normal readiness already has its own 30-second
  timeout. The server removes unadmitted peers after 45 seconds from body
  creation. The opt-in admission path caps waiting plus active humans at 16
  across transports (the existing ENet cap alone does not limit WebRTC), with no
  extra pending event queue or new object family. Events/spawn metadata add
  small fixed payloads, with at most one broadcast activation per generation
  and one existing-player event per late joiner/body. Input/state field lists,
  packed codec version, history size and networking defaults are unchanged.
- Before activation, the server checks clearance from active/scheduled cars
  using their conservative footprint radii plus a two-tick velocity margin,
  and queries the physics space for overlapping dynamic props/balls. Existing
  static spawn sites are unchanged. An occupied site remains hidden/inert and
  is retried within the same deadline, not relocated or activated inside a
  moving car. A persistently blocked site can time out; alternate-site
  selection is not implemented. Costly checks are server-paced to at most
  two per second per pending body, with a 64-hit physics query cap.

Evidence before rendered acceptance:

- The new unit test first failed on visibility, collision, firing, hits,
  pickups and the missing activation contract, then passed. It also covers
  generation rejection, duplicate activation, backward replay, troop actions,
  awareness markers and editor visibility. The broad suite exposed an early
  autoload dependency in standalone body preloads; the body now uses its
  existing root-node lookup pattern, and the impact regression passes again.
- `zsh scripts/player_admission_test.sh`: `car-fight-admission.YpLDK3` passed
  actual server/client collision queries, a five-second held-readiness client,
  rejected invalid requests, automatic gate selection, post-ready movement
  and a third late joiner. Native mux ENet/WebRTC passed the same checks in
  `car-fight-admission.bKiUPr`. These are headless tests, not browser/rendered
  or maximum-load acceptance. Processes are intentionally stopped and reaped
  by the bounded harness after assertions; complete logs are scanned first.
- Admission-enabled same-process startup/retry A/B `car-fight-startup.dqaYD3`
  passed six return candidates in the ungated control versus zero when enabled,
  two fresh connections/generations, neutral pre-ready input and sustained
  motion after readiness. Server/client activation ticks matched: 871/1264.
  Traces complete with zero drops; no unexpected runtime errors.
- Startup samples include `admission_required` and `activation_tick`; logs
  distinguish `PLAYER_ACTIVATED` from transport `CLIENT_READY` and local
  `STARTUP_PLAYABLE`. CPU savings and reduced traffic are not measured/claimed.

Final validation and limits:

- Broad milestone tests completed across a passing prefix and resumed tails
  after correcting the development failures above. Logs:
  `.network-runs/admission-full-suite-{initial,fixed,tail,final-tail}.log`.
  This was not one uninterrupted clean `test.sh` invocation. The initial
  activation-presentation call also needed Main's body argument; an explicit
  activated-vehicle/editor regression now covers it. Final ENet admission
  gate `Z7QYhN`, default latency120 1.403 units, mixed 0.300, respawn, mass
  collision, ball/tractor, reverse, combat/RC/shield/det gates passed.
- Final clearance-aware selection is in
  `.network-runs/admission-clearance-checks.log`: admission/stage units,
  native mux `ZTzfAN`, stalled join `c4U6RN`, reconnect `KyjjFQ`, fast check
  and same-process startup/retry A/B `83BFzN` passed (five returns to zero).
  The short reconnect peers still end before readiness; survivor admission
  and pending departure are covered there, while the A/B proves full retry.
- The original admission-enabled eight-second head-on run `ofgRDd` failed its
  escape assertion: independently admitted cars could pass into a waiting
  spawn, then overlap at activation (minimum center separation 0.070 units).
  Added occupied/scheduled-spawn regressions before the clearance fix. The
  scripted `converge` fixture now starts only when partners are admitted, with
  a regression before that change too. This is test choreography, not a
  player-wide startup barrier. With 900 server/1000 client ticks to leave a
  post-join collision window, the unchanged latency120 contact/escape and
  two-unit correction assertions passed in `car-fight-network.7NpmUo`:
  worst correction 0.300, minimum center separation 2.500, contact/escape 1.
  See `.network-runs/admission-latency120{-final,}.log` for both outcomes.
- Complete positive-path logs were checked. The broad suite's malformed
  SDP/ICE, truncated packed-state, peer-ID collision and harness late-error
  negative controls produce their expected errors; no broad allowlist or
  acceptance-threshold relaxation was added. New admission positive paths
  contain no unexpected engine/script errors. Actual browser/rendered and
  representative maximum-load/CPU validation remain unmeasured.

The previous rendered client-only trial `.crash-runs/two-client-20260905-205852`
closed cleanly (both exit 0). Its isolated server stopped; production PID 57599
remained on UDP 10080 and test ports were free. Completed launchd job removed.
Client startup traces are complete/zero-drop: Alpha 3,491 samples/zero returns;
Bravo 3,614 samples/one 0.362-unit return at process 25.934 s, still behind its
joining screen (first playable 30.274 s). Subsequent backward-step candidates
are not automatically network corrections during human/cruise movement. Owner
accepted the joining-screen experience, not overall performance. Server log
was collected, but the requested server stage file was absent remotely and
could not be collected. Preserve that evidence gap; verify trace output during
the next approved launch rather than claiming server-stage coverage.

No production deployment, default enablement or new rendered launch accompanies
this implementation. Next visual trial must refresh only the isolated test
runtime, select server admission and both client startup flags, then verify
that the first ready client sees no waiting vehicle. Later macOS/browser
validation remains separate.

### Joining readiness gate, 2026-09-05

This section describes the original client-only gate. The separately selected
server-admission extension below adds world participation control; its RPC and
spawn-data costs are additional to the original gate's local-only cost.

The owner requested withholding gameplay until the network is ready instead
of showing predicted movement and undoing it. Native opt-in:
`CAR_FIGHT_STARTUP_READY=1`, alongside `CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1` for
the tested combined path. Both remain off by default. The browser can select
the joining gate with `startupReady=1` and, as of the September 6 follow-up,
the same opt-in recovery with `forwardClockRecovery=1`. Bounded headless browser
wiring passes; rendered mixed-platform acceptance remains pending.

The client shows an opaque "Joining game..." overlay and gathers neutral
intent (`editing=true`) until all of these hold:

- Initial time sync completed, a full window of normal ping samples exists
  after any panic, and the latest completed sample is recent (one second with
  the current 250 ms interval). Samples and pending sync attempts reset across
  disconnect/retry; old timer continuations cannot start another ping loop.
- Simulation/reference offset and estimated remaining remote-clock offset
  are each within two ticks. This is an admission condition, not a change to
  the existing clock discipline or tick rate.
- This local body has received authority state after timing validation, its
  source tick is within retained history and not in the future, and rollback
  has consumed that state. Accepted full/diff receptions carry two local scalar
  markers; seeded history and artificially rebased old recovery keys do not
  qualify as fresh received state.

The whole server/world continues running during the wait. Only this client's
intent and view are gated, including scripted input, cruise and gameplay hotkeys.
The wire schema, server authority, physics and replay of recorded inputs are
unchanged. Body replacement cannot inherit permission even between frames.
Ordinary clock jitter after admission does not reopen the startup screen.
Disconnect revokes permission. A 30-second monotonic timeout, starting with the
connection attempt rather than asset/shader loading, shows failure and
Retry/Quit controls; Retry closes the old connection and reloads the scene with
fresh bodies and readiness. A disconnect is notified only once. The timeout
bounds waiting; it is not a fixed delay before admission.

Cost: constant local readiness work, two scalar markers per transmitter, no
new RPCs, payload fields, retained history windows or entity families. Startup
traces now include `startup_ready`; normal logs distinguish `STARTUP_WAITING`,
`STARTUP_PLAYABLE` and `STARTUP_FAILED`. Existing `CLIENT_READY` still describes
transport connection, not permission to drive. No CPU/traffic savings claimed.

Validation commands:

```bash
zsh scripts/startup_trace_test.sh --startup-ready
CAR_FIGHT_STARTUP_TEST_RETRY=1 zsh scripts/startup_trace_test.sh --startup-ready
```

The zero-return requirement was not relaxed. Initial combined A/B
`car-fight-startup.1W4KNz` reproduced six returns in the control and zero with
readiness. About 6.324 seconds elapsed from first body sample to playable in
that deliberately stale-clock case. Same-process retry A/B `rNBXv8` passed
five-to-zero; final body-permission/disconnect-cleanup A/B `A0YRx6` passed
six-to-zero with two connections and two body identities. All startup traces
complete, zero drops or unexpected runtime errors. Runs live under the local
temporary directory; no rendered clients or macai2 changes were involved.

Focused readiness/input, cancelled sync, timeout, retry action and logical UI
layout at 1280x720/320x568 passed, as did the real-schema input codec, pause,
forward-clock, stage, connection-lifecycle and bundle-coalescing regressions.
The input regression failed before gathering was gated. A layout test initially
compared physical window dimensions against the project's 1280x720 logical
canvas; it now explicitly tests both logical viewport sizes. This is layout
coverage, not a screenshot/browser acceptance claim.

With both opt-ins, join-transient passed (`whhVgG`, one reliable recovery and
playable at tick 421), reconnect passed (`DEbF0v`, three joins/leaves), and mixed
native ENet/WebRTC passed (`car-fight-mixed.87l5pi`, worst correction 0.300).
The short reconnect replacement and mixed ENet client ended before admission;
the long-lived ENet survivor and mixed WebRTC client did become playable. These
gates prove lifecycle/shared-world behavior, not a full two-ready-client feel
test. The mixed collision negative control intentionally rejected signaling
with `ERROR: WebRTC signaling closed before gameplay connected`; positive
mixed paths had no engine/script errors. No global error allowlist was changed.

Next: a separately approved monitored two-macOS-client trial with both opt-ins,
then macOS/browser acceptance. Shared-clock milestone suite remains required
before merge/promotion; this branch experiment has not changed defaults or
been deployed. Startup wait length under real rendering remains to be measured.

## Next approved capture

Use the isolated macai2 server, not production. Refresh its project/autoload and
diagnostic source files before enabling the server trace; copying only the
remote-position script is no longer sufficient. The monitored launcher supplies
unique client stage-trace paths; diagnostics remain off unless seconds are set.

```bash
CAR_FIGHT_PORT=12780 CAR_FIGHT_NETWORK_HUD=1 \
CAR_FIGHT_NETWORK_DIAGNOSTICS_SECONDS=120 \
CAR_FIGHT_PRESENTATION_TRACE_SECONDS=120 ./scripts/play_macai2_two.sh
```

The server is started separately through the approved isolated launcher. Give its
process `CAR_FIGHT_NETWORK_DIAGNOSTICS_SECONDS=120` and
`CAR_FIGHT_NETWORK_STAGE_TRACE_PATH=/absolute/isolated-run/server.network-stages.jsonl`.
Its parent output directory must exist. Nothing here deploys or starts a server.

Before the clients, identify the routed Tailscale interface with
`/sbin/route -n get 100.113.2.60`. Run the following in the owner's terminal,
replacing `utunN` with that interface and using a fresh output directory:

```bash
sudo /usr/local/bin/node scripts/network_packet_capture.mjs \
  --interface utunN --host 100.113.2.60 --port 12780 \
  --seconds 150 --out .network-runs/NEW-RUN/packets
```

macOS requires administrator authentication to open BPF on this machine. Enter
the password only in the local terminal, never in chat. The helper does not run
sudo itself, modify device permissions, or change network configuration. Start
the clients while capture is active. Ctrl-C stops only this capture. Do not run
the game as root. Traffic is limited to the selected test endpoint, but the PCAP
can contain short gameplay payload prefixes; do not publish it indiscriminately.
On the server, an optional separate capture should filter the client's Tailscale
IP and the same test port. Keep each host's capture/metadata separate.

After both captures and the clients finish, point the report at a single client's
monitor directory (set `CLIENT_RUN` to that directory):

```bash
node scripts/network_diagnostics_report.mjs \
  --stages "$CLIENT_RUN/network-stages.jsonl" \
  --presentation "$CLIENT_RUN/presentation-trace.jsonl" \
  --pcap .network-runs/NEW-RUN/packets/packets.pcap \
  --capture-meta .network-runs/NEW-RUN/packets/capture.json \
  --host 100.113.2.60 --port 12780
```

Repeat for the other client; add `--server-stages FILE` for server summaries.
Multiple recorded endpoints after reconnect require an explicit `--client-port`.
Exit 1 means invalid input/decoding failed; exit 2 means quality warnings; exit 0
only means the report was produced without global quality warnings, not that
networking passed acceptance. Individual gaps can still lack capture coverage.

## Bounds and interpretation

Stage tracing retains at most 30,000 records and at most 300 seconds of requested
capture, then disconnects observers and stops frame processing. A stalled process
can only finish when it resumes. Records flush on completion/normal exit, not
every tick; a crash can lose the buffered stage trace. The completion footer gives
drop counts and flush start/end timing. Existing low-rate crash telemetry remains
the crash-resilient fallback. No new networked object family or wire traffic was
added; opt-in overhead still needs a matched rendered comparison.

Packet capture limits duration to 300 seconds, packet count to 200,000 and snaplen
to 96 bytes (roughly 22.4 MB maximum classic-PCAP packet data including record
headers). It sends SIGINT at the deadline and SIGKILL after a three-second grace
period if necessary, retaining failure status. The reporter uses the installed
tcpdump decoder, flags unsupported summaries, and processes at most 20 largest
game gaps. Unknown capture drop statistics, record drops, clock shifts, unmatched
endpoints or incomplete files must not become reassuring zeros.

Packets present during a callback stall support local processing delay, but they
may include acknowledgments/control traffic. This is **not exact datagram-to-RPC
matching**, and does not measure exact receive-queue delay, one-way transit time
or network loss. Missing packets in a capture do not establish connection loss.
Client and server clocks are not presumed synchronized. Captured timestamps are
approximate OS observations, not guaranteed physical wire-arrival times; see the
[libpcap timestamp documentation](https://github.com/the-tcpdump-group/libpcap/blob/master/pcap-tstamp.manmisc.in).
Capture drop counters describe the capture mechanism, not game packet loss; see
the [tcpdump manual source](https://github.com/the-tcpdump-group/tcpdump/blob/master/tcpdump.1.in).

## Validation, 2026-09-05

- `scripts/check.sh`, presentation-trace, remote-position and adaptive-delay
  regressions: PASS; no final focused-run engine/script errors. Full suite not
  rerun for opt-in diagnostics; this does not clear earlier milestone failures.
- Node regressions: numeric IPv4/IPv6 UDP decoding, a binary PCAP fixture decoded
  by the actual tcpdump binary and report CLI, endpoint isolation, packet-present
  stall evidence, clock shifts, missing/drop/cap warnings, invalid capture options,
  mock bounded capture, spawn failure, no-overwrite and interrupt cleanup.
- `tests/network_stage_trace_test.gd`: deterministic nested spans and stage
  attribution, independent wall gaps, publication timing, disconnect reset,
  deadline/early-exit flush, record cap and disabled observer behavior.
- Existing clean headless two-client network gate with five-second stage traces,
  presentation traces and a 350 ms injected Bravo pause: PASS, worst authority
  probe discrepancy 0.300 units, zero missing-reference rejections and no engine
  errors. Server/Alpha/Bravo recorded 280/269/256 loops with separate phases;
  Bravo's maximum callback gap was 386.9 ms. Both client endpoints and server
  publications to both peers were present, with no trace record drops.
- Live OS packet capture was attempted only for localhost UDP 10381 but **did not
  start**: `sudo -n` required a password. Real privileged capture, real packet/game
  correlation, paired macai2 evidence and rendered overhead remain unvalidated.
- An initial standalone test failed compilation on an autoload identifier and
  triggered a headless engine crash. The observer now resolves dependencies from
  the scene tree; the corrected focused test and live gate ran without those
  errors. No rendered process was started in this implementation turn.

Runtime evidence: `.network-runs/network-diagnostics-2026-09-05/`; gate logs:
`/var/folders/nt/tp7j7qtx2cgc39ftxymn6kfw0000gn/T/car-fight-network.ZJtJBp/`.
Previous milestone failures and later macOS/browser acceptance remain open.

## First real packet-correlated run, 2026-09-05

Follow-up: the owner kept priority on warmed-up remote movement. Read the
"Warmed-up network playback analysis" in `NETWORK_PRESENTATION_TRACE.md` for
the separated cursor-pacing and shared delivery-gap findings. This supersedes
the startup-graphics-first priority at the end of this initial analysis.

Owner completed the two-native-client run against isolated macai2 UDP 12780.
Both clients exited zero, the temporary server stopped, and the completed
non-restarting launchd job was removed. Production PID 57599 remained on UDP
10080. No networking defaults or rendering settings changed. Owner said done
without a new subjective smoothness verdict or a marked hitch time.

Evidence (ignored, retained locally; do not publish raw packet payloads):

- Clients: `.crash-runs/two-client-20260905-032049/`; Alpha subrun
  `20260905-032049`, Bravo `20260905-032052`.
- Capture: `.network-runs/capture-1788596366046/`.
- Server and generated `alpha-report.json` / `bravo-report.json`:
  `.network-runs/diagnostic-1788596366046/`.
- Runtime diagnostics from `a7e5256`; branch at launch `8384ea6`, whose later
  changes were handoff documentation only. Both clients had P cruise enabled;
  Bravo logged actual cruise activation. Legacy 60 Hz/fixed 75 ms remained.

### Evidence quality

The privileged capture completed normally: 91,572 packets, zero kernel capture
drops, no packet-cap hit. This is not proof of zero game-network loss. Client
flows were isolated using recorded local ports 55033 (Alpha) and 59922 (Bravo),
with 32,330 and 29,967 incoming datagrams respectively. Clock-anchor offset
variation was below 0.83 ms; all decoded packet summaries were supported.

Capture ran about 03:19:26-03:22:26 local time. Clients started later, so coverage
does not include the last approximately 29/32 seconds of their 120-second stage
traces. Gaps before each endpoint's first packet or after its last packet remain
unclassified, not evidence of absent traffic. Both client stage and presentation
traces completed without record drops.

The server hit its 30,000-record bound and dropped 3,918 later records, with its
last retained event about 03:22:37 on its own clock. Its retained summaries are
partial, not whole-run clearance. Reporter debt: the optional server summary
exposes `dropped` but does not propagate that into top-level `quality_warnings`
or the CLI exit status. Both reports exited zero; that does not clear this debt.

### What the capture distinguished

| Client callback gap | Incoming datagrams inside gap | Largest overlapping measured network loop |
| --- | ---: | ---: |
| Alpha 4,677 ms, ending 03:21:06.912 | 1,491 | 45.8 ms |
| Bravo 5,203 ms, ending 03:21:13.656 | 409 | None recorded |
| Alpha 831 ms, ending 03:21:37.938 | 272 | 39.3 ms |
| Bravo 687 ms, ending 03:21:47.707 | 191 | 47.9 ms |

These covered gaps provide direct evidence of local callback stalls while the
OS still observed incoming traffic. They are not explained simply by a complete
connection outage. Packet types are not matched to RPCs, so this does not prove
every expected state update arrived. The 5.6/6.5-second initial pre-endpoint
gaps are not used for this packet-based conclusion.

The early process samples in both clients contain main-thread OpenGL shader
compilation (`glCompileShaderIncludeARB_Exec`, `ShCompile`, `glpCompileShader`).
In particular, Bravo's `client-stall-1788596472.sample.txt` begins at
03:21:12.984, inside its 5.2-second callback gap; Alpha's
`client-stall-1788596466.sample.txt` begins inside its 4.7-second gap. This is
concrete rendering/startup-work evidence for part of those stalls, not proof that
shader compilation accounts for every millisecond or the later small hitches.
Many Godot frames remain unsymbolicated. Samples can extend into recovery.

All 27 sampled CPU speed limits per client were 100, with no recorded thermal
warning. Unlike the earlier throttled run, this run does not require thermal
throttling to explain its startup stalls. These coarse samples do not rule out
brief scheduling pressure or establish GPU utilization.

### Remaining costs and limits

Client measured network-loop median/p95 was 11.6/26.5 ms (Alpha) and 10.8/24.6 ms
(Bravo). Maxima were 107/283 ms, including rollback maxima 102/267 ms. These are
elapsed spans, not CPU execution time; they overlap and are not additive. The
large callback gaps are mostly outside these measured loop spans. Rendering,
loading, multiplayer polling outside the observer, and OS scheduling are not
fully partitioned by this instrument.

After the first 30 seconds, callback-gap median/p95 was 33.1/52.3 ms and
31.2/48.8 ms; maxima were still 831/687 ms. Presentation body observations after
that cutoff were 2690 interp / 7 extra / 11 hold and 2935 / 14 / 6. These are
sample counts, not wall-time percentages or proof of perceptual smoothness.
Final applied state was current with zero rejects in the final telemetry
interval; maximum observed probe discrepancy was 0.467/0.900 units. Startup had
45/14 probe misses and four guarded stale-rollback warnings on Bravo. No client
or server SCRIPT ERROR/ERROR matches or captured display precursor were found.

Next work: characterize startup shader/asset work and separately profile the
remaining post-warmup callback gaps, preserving the accepted Compatibility and
safe-window policy. Repair server trace quality reporting and shorten or reduce
server sampling within the existing bound. For another authorized comparison,
prepare everything before owner authentication and use a short Terminal command
so capture covers the full game trace. Measure diagnostic overhead before
claiming a performance improvement. Do not tune network buffers to mask these
local stalls, and do not treat this run as macOS/browser acceptance.
