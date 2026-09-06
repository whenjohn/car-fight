# Current phase

## Native admission trial completed; mixed browser trial next, 2026-09-06

- Owner reported joining works, then said "done whats next". Both monitors
  exited cleanly/status 0. Isolated server 19177 stopped; test UDP 12780/TCP
  12781 free, production 57599/UDP 10080 unchanged. Completed launchd job
  `com.whenjohn.car-fight-admission-20260905-224635` removed. No trial running.
- Evidence paths in the handoff below. Client and server stage traces complete
  with zero drops; server trace successfully collected this time. Clients
  closed around process 44-45 seconds, so their requested 120-second captures
  ended cleanly at shutdown, not at the full configured duration.
- Startup reports: Alpha 1,000 samples, Bravo 816; zero return-to-first-pose
  candidates and no quality warnings. First playable samples at process
  29.192/15.608 seconds respectively. This is bounded sampled evidence, not
  proof against every intra-frame correction. Client logs have zero errors;
  largest HUD corrections 0.218/0.525 units, zero reported recoveries.
- Performance remains separate debt: initial frame gaps 5.272/5.174 seconds;
  post-ready frame-gap maxima 639/1,693 ms, medians 34.465/32.627 ms. Client
  network-loop p95 26.846/40.116 ms; server p95 6.688 ms, max 160.813 ms.
  Phase timings include descheduling, not just CPU execution. No packet
  capture in this trial, so do not claim precise CPU/GPU or wire attribution.
- Next proposed networking checkpoint: owner-approved native macOS + actual
  browser/WebRTC against the isolated matching runtime. Check admission and
  pending visibility, bidirectional movement/P observation, disconnect/rejoin
  and errors. Native mux automation is not browser acceptance. Review browser
  flag support before launch; do not silently equate native-only clock recovery
  with browser behavior. No browser launch, deployment or default enablement
  authorized yet. Joining accepted; broader smoothness/performance not cleared.

## Rendered server-admission trial: owner reports working, 2026-09-05

- Owner approved "ok lets test", then reported "ok looks like it works".
  Two monitored native clients launched from runtime `095608c`; both reached
  STARTUP_PLAYABLE and both received the same activation events. No client
  engine/script errors at the launch check. This is visual joining acceptance,
  not completed diagnostics or browser/performance acceptance.
- Trial remains running pending owner completion. Run:
  `.crash-runs/two-client-20260905-225043/`; Alpha subrun 225043, PID 58704,
  peer 1660602140; Bravo subrun 225046, PID 58764, peer 632207941.
  Bravo activated at tick 1186/playable 1189; Alpha at 1862/playable 1863.
  Independent readiness still permits different join times.
- Isolated macai2 copied runtime refreshed, server PID 19177 on UDP 12780 /
  TCP 12781. Production PID 57599 remains on UDP 10080 unchanged. Server
  admission, client startup readiness and forward clock recovery enabled only
  for this trial; elapsed remote cursor, P cruise, decorated windows at 80,100
  and 1520,100 with the existing three-second stagger. Defaults unchanged.
- Launcher/evidence: `.network-runs/admission-20260905-224635/`, launchd label
  `com.whenjohn.car-fight-admission-20260905-224635` (non-restarting).
  Client startup trace 60 seconds; stage/presentation traces 120 seconds.
  Server stage trace 90 seconds. After both clients close, cleanup waits for
  server trace completion (bounded 95 seconds), stops only its isolated server
  and collects its log/trace. No packet capture was started.
- On "done": verify monitor exits, server cleanup and trace completeness;
  collect/analyze startup and stage evidence, record remaining issues and
  remove the completed launchd job. No further launch, production deployment,
  default enablement or browser trial is authorized by this acceptance.

## Server admission implemented; ready for visual trial, 2026-09-05

- Owner's "ok do it" authorizes server-visible joining/active admission.
  Added default-off `CAR_FIGHT_SERVER_ADMISSION=1`; no deployment, default
  enablement or new rendered launch. Matching clients automatically select
  the joining gate when their spawn requires admission. Next native trial
  should explicitly select both client startup flags as before.
- Waiting bodies remain replicated for owner timing/state validation, but are
  hidden, frozen, collision-layer/mask zero and excluded from gameplay ticks,
  weapons/hits, pickups/troops, grass and offscreen markers. Server checks the
  sender's body generation and recent state tick, then sends a reliable,
  immutable next-tick activation. Local input/UI wait for that acknowledgement.
  Replay before activation stays inert; late joiners receive existing events.
  Duplicate/replaced-generation events do not change admission. Server expiry
  45 seconds, client response deadline 30 seconds, requests at most 1/sec.
  Opt-in cap 16 waiting plus active humans across transports; no new queue,
  input/state schema growth, transport expansion or CPU/traffic savings claim.
- New regression first failed on the original waiting-player defect. Focused
  tests cover physics, combat, pickups, troop actions, editor/marker visibility,
  activation/replay, same-ID replacement, expiry and cap. Initial network gates
  passed ENet `car-fight-admission.YpLDK3` and native mux/WebRTC `bKiUPr`, with
  server/client collision queries, five-second readiness withholding, invalid
  requests, automatic owner gate, post-ready movement and a third late joiner.
- Admission-enabled stale-clock/retry A/B `car-fight-startup.dqaYD3` passed
  six return candidates to zero, two fresh identities/activations, neutral
  waiting input and sustained motion. Complete traces/zero drops/errors.
  Final clearance-aware A/B `83BFzN` also passed five-to-zero with retry.
- Broad validation exposed and fixed a standalone body preload/autoload
  dependency, an expanded unit fixture's MeshInstance type mismatch, and an
  activation-presentation call missing Main's body argument. Preserved failed
  logs under `.network-runs/admission-full-suite-{initial,fixed,tail}.log`.
  Passing prefix was not repeatedly restarted; remaining integration gates
  finished in `admission-full-suite-final-tail.log`. Default latency120 gate
  passed at 1.403 units, mixed native at 0.300, join/reconnect passed. Expected
  malformed SDP/ICE and truncated codec negative controls emit engine errors;
  these are distinct from the corrected implementation/fixture failures.
- Broad remaining gates completed, including default admission-off respawn,
  mass collision, ball/tractor, reverse, combat/RC/shield/det. Full milestone
  coverage is a passing prefix plus corrected unit and resumed tails, not one
  uninterrupted clean suite invocation. Final ENet admission `Z7QYhN` passed.
- Final selected checks in `.network-runs/admission-clearance-checks.log`:
  admission/stage regressions, native mux `ZTzfAN`, stall `c4U6RN`, reconnect
  `KyjjFQ`, startup/retry `83BFzN`, fast check all passed. Short reconnect peers
  end before readiness; the survivor and separate full same-process retry
  provide active admission coverage. No unexpected positive-path errors.
- Admission latency trial `ofgRDd` exposed activation into a waiting spawn
  occupied by an already-moving player. Added server clearance checks for
  active/scheduled cars and dynamic props/balls; blocked sites stay pending
  until clear or timeout (no alternate-site selection). Costly checks are
  limited to two per second per body. Regression covers occupancy/reservation.
  Test-only scripted `converge` now waits for admitted partners; normal human
  controls remain independent. With 900/1000 server/client ticks for a real
  post-ready collision window, latency120 passed unchanged contact/escape and
  two-unit limits: worst 0.300, minpair 2.500 (`car-fight-network.7NpmUo`).
  Both failed and passing shaped logs retained under `.network-runs/`.
- Standing contract and commands updated in AGENTS.md, NETWORK_SAFE_GAMEPLAY,
  QUALITY_GATES and NETWORK_DIAGNOSTICS. Startup samples expose admission flag
  and activation tick. Production PID 57599/UDP 10080 untouched. Browser and
  rendered admission acceptance remain pending; do not launch without approval.
- Next: owner-approved two monitored native clients against the isolated
  macai2 runtime, server admission plus both client startup flags and elapsed
  cursor/P cruise. First ready player must not see/interact with the waiting
  vehicle, and both must drive normally afterward. Preserve server trace:
  previous server was stopped around tick 5288 (88.1 s), before the requested
  90-second flush; wait for trace completion or graceful exit before stopping.
  Final fast check passed; 19 clearance/latency positive-path log files scanned
  with zero engine/script errors. All local test processes exited; no new
  human trial is running.

## Previous rendered joining-gate trial completed, 2026-09-05

- Both monitored clients exited cleanly (0). Isolated server 13860 stopped;
  UDP 12780/TCP 12781 free, production still 57599/UDP 10080. Removed completed
  launchd job `com.whenjohn.car-fight-readiness-20260905-205744`. Server log
  collected, but requested server stage file was absent remotely. Client
  traces complete/zero drops: Alpha 3,491 samples/zero return candidates;
  Bravo 3,614/one 0.362-unit return at 25.934 s while its joining screen was
  still up (playable 30.274 s). Owner accepted screen experience, not CPU/FPS
  performance. Do not claim a zero-reset simulation from hidden presentation.
  No human test remains active. The notes below preserve the original trial.

## Rendered joining-gate trial handoff (superseded), 2026-09-05

- Owner says the joining experience is fine, but asks why clients become ready
  at different times and why the ready player can see the waiting vehicle.
  Alpha first playable sample at process 25.064 s; Bravo at 30.274 s, plus the
  existing three-second launch stagger. First body-to-ready waits 10.783/16.732 s.
  Bravo logged local 4.661 s and 1.315 s stalls during joining; exact CPU/GPU
  attribution not established. Each gate independently waits for live evidence.
- Confirmed remaining design gap: `_on_peer_join()` immediately spawns the
  server body. The new gate withholds only local view/input; other peers still
  see the waiting vehicle and it remains in the simulation. Proposed follow-up
  is server-visible joining/active admission, keeping joining bodies out of
  visibility/collisions/combat until readiness is confirmed. No implementation
  of that follow-up or additional deployment is authorized by the question.
  Owner has not said done; keep this trial running pending feedback/completion.
- Owner approved "let me see it". Launched two monitored decorated macOS
  clients from runtime `ab64080`; both reached `STARTUP_PLAYABLE` without
  engine/script errors at the launch check. Alpha tick 1687/state 1678; Bravo
  tick 2116/state 2113. User feedback and completed startup traces still pending.
  Do not claim rendered zero-reset or smoothness acceptance from READY logs.
- `CAR_FIGHT_STARTUP_READY=1`, `CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1`, elapsed
  presentation cursor, legacy networking defaults otherwise. P cruise enabled
  after readiness. Positions 80,100 and 1520,100, ordinary monitored windows.
  Startup traces 60 seconds; stage/presentation traces 120 seconds.
- Run `.crash-runs/two-client-20260905-205852/`: Alpha subrun 205852 PID 42544,
  peer 1872130622; Bravo subrun 205855 PID 42597, peer 1462349423. Initial HUD
  readings include low rendered FPS; evaluate completed timing evidence before
  attributing later stutter to transport or accepting performance.
- Refreshed only the isolated macai2 copied runtime. Test server PID 13860 owns
  UDP 12780/TCP 12781; production PID 57599 remains on UDP 10080, unchanged.
  Launcher/evidence `.network-runs/readiness-20260905-205744/`, non-restarting
  launchd job `com.whenjohn.car-fight-readiness-20260905-205744` (PID 42507).
- Trial is intentionally still running. On owner completion, verify both
  monitor exits, isolated-server cleanup and collected server logs/stage trace;
  remove the completed launchd job, analyze startup reports and record feedback.
  The launcher stops only its isolated server after both windows close. No new
  production deployment, default enablement or browser trial authorized.

## Joining gate implemented; zero-reset automated acceptance, 2026-09-05

- Owner explicitly requested withholding the game until networking is ready.
  Added opt-in `CAR_FIGHT_STARTUP_READY=1` (browser gate query `startupReady=1`):
  opaque Joining game screen, neutral input before readiness, 30-second failure
  timeout, Retry/Quit. No deployment/default changes. Test the native gate with
  `CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1`; clock recovery alone remains partial.
- Admission requires a fresh full clock-sample window, simulation/reference and
  estimated remote offsets within two ticks, and fresh authority state received
  after clock validation and consumed by rollback. Local seeded history and
  old rebased recovery keys cannot qualify. Owning-client intent/server-state
  authority and all 14 input fields unchanged; no new wire traffic/history.
- Disconnect and body replacement revoke readiness. Input checks body identity
  even before the next Main frame. Retry reloads fresh scene/bodies; cancelled
  initial-sync coroutines and old ping timers are generation-guarded. Cleanup
  does not duplicate natural disconnect events. Regular post-ready clock jitter
  does not reopen startup. World/server simulation keeps running while joining.
- `zsh scripts/startup_trace_test.sh --startup-ready`: six resets to zero in
  `car-fight-startup.1W4KNz`. With `CAR_FIGHT_STARTUP_TEST_RETRY=1`, same-process
  reconnect passed five-to-zero (`rNBXv8`); final cleanup A/B passed six-to-zero
  (`A0YRx6`), two connections/two identities, neutral pre-ready intent and
  sustained movement after readiness. All startup traces complete, zero drops
  and no unexpected runtime errors. Evidence in local temporary directories.
- Focused readiness/input, timeout/cancelled sync, UI action/logical bounds,
  live input codec, pause/forward clock, stage, connection lifecycle and bundle
  coalescing passed. Both opt-ins: join-transient `whhVgG` passed, reconnect
  `DEbF0v` passed, mixed native ENet/WebRTC `87l5pi` passed (worst 0.300 units).
  Short replacement/ENet mixed clients did not reach playable before their
  existing tick limit; the long-lived ENet survivor and WebRTC client did.
  Mixed ID-collision negative control emitted its expected signaling-closed
  ERROR; positive paths clean. Do not call this a browser or two-ready feel test.
- See "Joining readiness gate" in `docs/NETWORK_DIAGNOSTICS.md` for exact
  admission contract, evidence, limits and commands. The first stale-seed run
  waited about 6.324 seconds from first body sample to playable, not a configured
  delay. Real rendered wait length remains unknown. UI bounds tested headless,
  not screenshots. Full milestone suite still required before merge/promotion.
- Fast import/syntax/manifest/UID/diff check passed; engine-failure harness
  control failed promptly as expected (`BA1I2T`). Final unit coverage also pins
  that slow asset/shader loading does not consume the network deadline; it
  starts only at connection attempt. All local test processes have exited.
- Next: separately approve and launch the two
  monitored macOS clients with both flags, elapsed presentation cursor retained
  and P cruise available after readiness. No new human launch this turn. Later
  macOS/browser trial remains pending. Production/macai2 untouched.

## Forward clock recovery implemented; first reset unresolved, 2026-09-05

- Owner approved the targeted startup fix. Added default-off
  `CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1`: an active, initially synced connected
  client rebases clock/tick/next scheduled tick together when reference time
  leads simulation by more than the existing panic threshold. No backwards
  reference-gap rebase, new RPC/schema, prediction-authority change, history
  enlargement, or networking-default change. Existing pause reset preserved.
- **Partial improvement, not startup acceptance.** Real moving ENet stale-seed
  A/B reproduced five returns with recovery off and one remaining 14.040-unit
  return with recovery on, immediately after the reference panic. Correcting
  time cannot restore previously rejected movement. The prolonged catchup is
  removed: 1,342 later samples stayed within 27.414 ms of reference time and
  exactly one forward rebase occurred. Both traces complete, zero drops/errors.
- Reproduction: `zsh scripts/startup_trace_test.sh --clock-recovery`.
  This deliberately fails until the enabled case has **zero** return-to-first-
  pose candidates. Do not relax that assertion to accept one. Test-only seed
  offset -4.7234838 seconds; real ping discipline repairs reference time. No
  fixed production/client startup delay. Evidence under local temporary
  `car-fight-startup.LpvW67/recovery-{0,1}/`; detailed record and reasoning in
  `docs/NETWORK_DIAGNOSTICS.md`, "Forward clock recovery experiment".
- Focused clock regression failed before runtime fix and passed afterward;
  guards/default-off/negative offsets and 900 post-rebase frames covered.
  Existing pause regression passed. With recovery enabled, join-transient
  passed (one recovery/request/application; `car-fight-join-transient.nYtFHB`),
  reconnect passed (three joins/three leaves; `car-fight-reconnect.tCisv6`), and
  original moving/no-stall plus six-second-stall trace modes passed
  (`car-fight-startup.KZq4pe`). Complete logs scanned: no unexpected errors.
  Harness engine-failure control exited promptly as expected (`UPNRlb`). Fast
  import/syntax/manifest/UID/diff check passed. Earlier fixture annotation error
  was corrected before the measured A/B; no ignored passing-gate engine errors.
- No rendered clients, macai2 changes or deployment this turn. All local test
  processes exited. Full suite not rerun for this unaccepted, off-by-default
  branch experiment; shared-clock milestone suite remains required before
  merge/promotion, alongside rendered and later macOS/browser acceptance.
- **Next:** investigate initial time acquisition/readiness so local prediction
  does not begin on an untrustworthy timeline. Keep the positive-control
  reproduction and zero-reset requirement. Do not mask it with arbitrary wait,
  weaken stale-input guards, or revive the rejected half-handshake-RTT seed.
  Do not launch another human trial merely to confirm this known remaining
  reset; first get automated startup acceptance, then request a monitored test.

## Startup trial completed and analyzed, 2026-09-05

- Owner said done. Both monitored clients exited zero at 19:39:08/09 CDT;
  isolated server PID 9955 stopped, logs collected, completed launchd job removed.
  Production PID 57599 remains on UDP 10080; test ports 12780/12781 free.
  No trial processes remain and no new launch is authorized by this completion.
- Four large Alpha physics/presented-position returns to spawn measured 5.571,
  7.810, 6.359 and 5.568 units. Same instance/generation. Reference-minus-client
  tick lag at those resets was 3.743, 2.604, 1.710 and 1.230 seconds. The sampled
  latest-state snapshots match spawn, and their ticks match server reliable
  recovery sends. See completed rendered trial in `docs/NETWORK_DIAGNOSTICS.md`.
- Server received input traffic throughout much of the stalled startup but
  telemetry reports no input-driven rollback origins until later catchup.
  `_RedundantHistoryEncoder.apply()` silently skips inputs older than the
  64-tick history window. This strongly supports stale-timestamped intent plus
  repeated recovery to stationary authority; exact per-input rejection events
  were not recorded. Fresh keys were visible in client history 1.1-1.7 seconds
  before the four large resets, so do not equate reset time with packet arrival.
- Existing authority probes maxed at only 0.642/0.618 units despite the visible
  5.6-7.8-unit resets. Startup acceptance must check real movement, not only the
  correction-probe ceiling. No engine/script errors; all three stage traces
  complete with zero drops (client samples 2,418/2,390; server 4,934 loops).
  Clients closed before the requested 120-second trace deadline and flushed
  normally; this is not missing/incomplete output. No packet-loss conclusion.
- Evidence `.crash-runs/two-client-20260905-193712/` and
  `.network-runs/startup-20260905-193556/`, including both startup reports and
  server trace/log. No runtime/default changes this analysis turn.
- Next implementation focus: characterize and repair startup timeline recovery
  after a large reference-clock correction, preserving coupled clock/tick/next
  tick rebasing and stale-input guards. Cover server-ahead states and movement
  in a focused automated reproduction, then clock/join/reconnect gates and a
  separately approved human retest. Do not repeat the current human test just
  to reconfirm the resets or mask them with a fixed startup delay.

## Rendered startup resets captured; trial awaiting completion, 2026-09-05

- Owner explicitly confirms this startup move/reset behavior has existed since
  networking was first introduced, months ago. Treat it as a longstanding
  baseline startup defect, not a symptom introduced by this networking review
  or the elapsed-cursor experiment. Historical onset is owner-reported, not
  bisected; recent work could still affect its severity or duration.
- Owner approved launching both clients and reports four move/return-to-origin
  resets right at startup. Position trace now confirms four large Alpha physics
  returns to approximately (-3, 0), at process monotonic seconds 26.245, 30.434,
  33.942 and 36.011, plus smaller return candidates at 20.611 and 36.386.
  Same body instance/generation throughout, not a respawn or camera-only effect.
- Each large return matches the sampled history position at latest state tick
  1627, 1896, 2091 or 2244, respectively. Alpha clock panic +4.723 seconds,
  Bravo +4.299 seconds; repeated reliable state recovery during startup.
  Exact application callbacks and server input acceptance still need tracing;
  do not claim the complete causal chain from sampled history alone.
- Both stage traces complete, zero shared/startup drops: Alpha 2,418 startup
  samples, Bravo 2,390. Run `.crash-runs/two-client-20260905-193712/`, Alpha
  subrun 20260905-193712 PID 30760 peer 909707526, Bravo subrun 20260905-193715
  PID 30813 peer 2010561370. No further reproduction needed before analysis.
- Runtime b84a5a4, elapsed cursor retained, legacy defaults unchanged, startup
  samples 60 seconds, stage/presentation 120 seconds, P cruise enabled in both.
  Ordinary monitored windows at 80,100 and 1520,100; no packet capture step.
- Isolated macai2 server PID 9955, UDP 12780/TCP 12781; only its diagnostic file
  updated. Production PID 57599/UDP 10080 untouched. Non-restarting launchd job
  `com.whenjohn.car-fight-startup-20260905-193556`; launcher/evidence directory
  `.network-runs/startup-20260905-193556/`. Owner has not said done. On completion,
  verify client exits and isolated cleanup, collect server trace and remove job.

## Startup trace implemented and characterized, 2026-09-05

- Added opt-in local startup samples and sync/panic events to the existing
  network stage trace. Enable `CAR_FIGHT_STARTUP_TRACE_SECONDS=25` alongside
  the existing stage path/duration. No gameplay, clock, transport, input/schema,
  presentation defaults or server deployment changes. Read the instrumentation
  follow-up in `docs/NETWORK_DIAGNOSTICS.md` before the next trial.
- `zsh scripts/startup_trace_test.sh` captures a moving headless client on local
  ENet, once clean and once with the existing six-second post-sync JOINSTALL.
  Both evidence checks passed, zero record drops/errors; all child processes
  stopped. Logs `/var/folders/nt/tp7j7qtx2cgc39ftxymn6kfw0000gn/T/car-fight-startup.Rw96DP/`.
  No three-return reproduction: control had a 1.371-unit early backward physics
  step, stalled case a 0.275-unit early step. The six-second pause caused one
  reliable state recovery but no clock panic. These are characterizations, not
  network/visual acceptance; fast import/check overlapped part of the control.
- Separate injected-clock characterization using actual unchanged NetworkTime
  loop: a +6.109638-second reference correction without a long frame remains
  5.860 seconds behind after one second, 3.610 after ten, and settles around
  25 seconds (max clock stretch 1.25). This is a concrete slow-catchup mechanism,
  not a reproduction of the entire startup snapback. Script retained ignored at
  `.network-runs/startup-clock-characterization.gd`.
- Focused startup/stage, Node diagnostics, presentation trace, remote transport
  and existing pause-clock tests passed; fast check passed. Harness failed
  promptly as expected with `GODOT_BIN=/usr/bin/false`. Initial development runs
  had compile/fixture errors; fixed before clean reruns. Found unused netfox
  `get_last_known_input()` calls nonexistent history `keys()`; left vendored code
  unchanged and use guarded `get_latest_tick()` for diagnostic reads.
- Next: reproduce moving join with a delayed initial timestamp/large reference
  correction, rather than treating a post-sync pause as equivalent. Then scope
  startup time/readiness recovery with focused clock/join/reconnect coverage.
  Human confirmation still needs an approved monitored run with this trace;
  no rendered clients or macai2 test service launched this turn. Skid FX remains
  deferred, elapsed cursor opt-in unchanged, 2.800-unit later stall outlier open.

## Startup snapback reported by owner, 2026-09-05

- Owner reports a longstanding sequence of roughly three move/return-to-start
  cycles before normal networked play. Prioritize startup synchronization
  diagnosis alongside the unresolved 2.800-unit stall/probe outlier; skid FX
  remains deferred. This is not established as an elapsed-cursor regression.
- Read-only review found startup clock panics of 6.110 seconds (Alpha) and
  4.548 seconds (Bravo), followed by repeated stale-authority full-state recovery
  in the completed elapsed trial. These are relevant evidence, not a confirmed
  match to the reported visible resets. See `docs/NETWORK_DIAGNOSTICS.md`,
  "Startup snapback investigation" for paths, code boundaries and next checks.
- `CLIENT_READY` currently means connection notification, not settled gameplay.
  Netfox already waits for initial time sync before running its tick loop and
  attaching rollback callbacks; do not diagnose this as simply missing that check.
- Next: characterize moving input during join and post-sync stalls, recording
  local pose/input, applied authority tick/pose, clock changes and generation.
  Distinguish actual rollback movement from camera/visual resets before changing
  readiness or clock recovery. Existing traces cannot count the visible resets.
- No runtime edits, tests, launches, deployment or default changes in this
  investigation. All completed trial processes remain stopped.

## Priority update: skid discrepancy deferred by owner, 2026-09-05

- Owner considers observer-only skid marks minor and requested logging them for
  later unless they indicate speed disagreement/network stutter. Defer the FX
  investigation; do not treat it as the next required implementation task.
- Qualification from code: `FollowController.automatic_brake_skid()` depends on
  current speed minus requested speed. A prediction/correction/input mismatch
  could therefore affect brake state, although marks are not directly generated
  from render-cursor speed changes. The elapsed cursor only changes presentation,
  not simulated velocity. Current evidence does not identify the triggering
  signal or establish sustained client/server speed disagreement.
- Retain the mismatch as a diagnostic clue, not confirmed harmless cosmetics.
  Reopen if marks coincide with measured tick-aligned speed/braking disagreement,
  repeated corrections or remote-only movement hitches. Existing traces lack
  those effect inputs; final current-state status does not rule out transients.
- Next networking priority is the measured 2.800-unit stall/probe outlier, then
  controlled cursor comparison and later native/browser validation. Keep the
  improvement opt-in and production/defaults unchanged.

## Elapsed-cursor trial completed and analyzed, 2026-09-05

- Owner finished after reporting "smooth very little stutter", separately from
  observer-only straight-path skid marks. Both clients exited zero after about
  9.3 minutes; isolated server stopped, job removed, production PID 57599 remains
  on UDP 10080. Read the elapsed trial result in `docs/NETWORK_PRESENTATION_TRACE.md`.
- All client traces completed with zero drops; 90-second server trace also zero
  drops (24,119 records). Detailed client coverage is first 120 seconds only.
  No packet capture in this trial; no new delivery-gap/loss conclusion.
- Equal seconds-30-to-80 windows and regular/near-target playback filters support
  improved cursor pacing. Non-overlapping >=100 ms blocks reduce the current
  trace's 1 ms timestamp quantization: rate p05/p95 narrowed from about 0.92/1.08-1.10
  to 0.99/1.01. Documented raw short-interval ambiguity, different focus/frame
  rates and limited selected coverage; this is not a matched A/B or FPS claim.
- Bravo had a 2.800-unit probe at tick 5940 classified with a stall and a
  572.609 ms process metric; Alpha maximum 0.469. Final state current, zero final
  rejects. No engine/script/display precursor errors found. The outlier exceeds
  the two-unit gate reference and remains unresolved, not blamed on the opt-in
  without evidence. CPU limits reached 73 during this longer run.
- Evidence: `.crash-runs/two-client-20260905-035412/`, plus server logs and
  `compare-cursors.mjs` / `cursor-comparison.json` in
  `.network-runs/elapsed-20260905-0351/`. No trial processes remain.
- Next (updated by owner above): keep clock opt-in/default unchanged; defer skid
  effects and investigate the stall/probe outlier, then
  controlled comparison and later native/browser validation. Do not equate the
  positive motion verdict with approval to promote or deploy.

## Owner observation during elapsed trial: remote-only skid marks

- Owner's follow-up motion verdict: "yes smooth very little stutter" when asked
  whether the observed remote vehicle is smoother aside from the skid marks.
  This is positive subjective trial evidence, not a matched A/B or permission
  to enable the experiment by default. Owner has not yet said done; retain the
  running trial and inspect saved traces after completion.
- Owner sees straight-path skid marks under the other player in the observer
  window, but no marks in that player's own window. Treat the effect discrepancy
  separately from the positive motion verdict above.
- Read-only trace: `GroundVehicleHull._animation_inputs()` reads current rigid
  velocity/basis and `brake_skid_amount`, while the remote visual root follows
  delayed snapshots. `_update_tire_skid_trails()` additionally reads reverse,
  drift-assist/oil and boost transitions. `skid_strength()` gates on braking,
  slide or boost, with speed scaling, not acceleration alone. These FX paths
  predate the cursor trial and were not changed during it.
- State-time mismatch is a hypothesis, not the identified trigger for these
  marks: existing traces do not record the per-tire trigger inputs. Keep this
  separate from proof of movement desync or proof the new clock caused it.
  After the run, characterize remote effect inputs and their presentation time;
  add focused coverage before changing skid rules or replicated state. Do not
  hide the discrepancy by disabling all remote skid effects.

## Elapsed-cursor human trial active, 2026-09-05

- Owner said ready to test. Implemented opt-in at `856e081` before launching;
  read the opt-in trial section in `docs/NETWORK_PRESENTATION_TRACE.md`.
  `CAR_FIGHT_REMOTE_CURSOR_CLOCK=elapsed` affects fixed/adaptive remote visual
  cursor delta only. Shipping default engine delta, simulation/rollback, schemas,
  authority, collision, 75 ms delay and renderer remain unchanged. Gaps above
  250 ms deliberately retain original engine-delta/rebase recovery behavior.
- Focused actual-body cursor test, existing transport, adaptive and presentation
  trace tests PASS; final fast check PASS. Opt-in clean headless two-client gate
  PASS: 0.300-unit worst probe, zero reference rejects, no runtime errors. Initial
  new test fixture emitted missing Input-node error; corrected rerun was clean.
  Broad milestone/browser tests not rerun and remain unaccepted.
- Both monitored clients connected with `clock=elapsed` verified in startup logs:
  `.crash-runs/two-client-20260905-035412/`; Alpha subrun 20260905-035412,
  PID 12552, peer 1401744304; Bravo subrun 20260905-035415, PID 12609,
  peer 1120983699. P cruise available in both, 120-second presentation/stage
  traces enabled, unchanged legacy settings. No startup SCRIPT ERROR/ERROR
  matches at readiness check. Await actual post-warmup feel and saved traces.
- Isolated macai2 runtime received only the matching player and two presentation
  helpers. Temporary server PID 65544 on UDP 12780/TCP 12781; production PID
  57599 remains on UDP 10080. Server stage trace shortened to 90 seconds to reduce
  the prior cap pressure; inspect actual drops, do not assume zero.
- Launcher/server evidence: `.network-runs/elapsed-20260905-0351/`.
  Non-restarting job `com.whenjohn.car-fight-elapsed-20260905-0351` in gui/501.
  No packet capture required/launched for this cursor trial; shared delivery-gap
  investigation remains separate. No Terminal authentication step for owner.
- On done: verify both exits and isolated server cleanup, remove completed job,
  compare warmed-up cursor speed/headroom/modes to retained engine-clock run.
  This is a sequential trial, not a matched randomized A/B; do not infer reduced
  network loss or full smoothness from the offline proof. Defaults stay off.

## Warmed-up remote playback analyzed, 2026-09-05

- Owner explicitly kept this work on networking quality. Startup shader work is
  separate debt, not the next rendering project. Read the warmed-up analysis in
  `docs/NETWORK_PRESENTATION_TRACE.md`; it supersedes the prior shader-first next.
- Reused the completed packet-correlated run, excluding first 30 presentation
  seconds and all uncovered packet tail. No new rendered run or runtime changes.
- Found a reproducible presentation pacing mechanism: even regular callback
  intervals with positive snapshot headroom and effective delay 60-90 ms show
  cursor-speed p05/p95 about 0.82/1.27-1.28 of nominal. All 1,601 selected pairs
  match the existing helper driven by supplied engine delta rather than elapsed
  body-callback time. Focused Alpha advanced 30.95 ms over a 21 ms interval with
  75 ms headroom. No screen-space motion/pose or perceptual proof is claimed.
- Actual helper/sampler headless characterization PASS: full history, jittered
  callbacks and constant supplied delta reproduce speed 0.715-1.655; elapsed-time
  control stays 1.000, all samples interpolating. No engine/script errors.
- Separately, both client captures have shared 115-134 ms incoming gaps around
  03:22:00, :06, :12 with regular client callbacks and rare extra/hold samples.
  Matching consecutive server publications were queued only 14-21 ms apart.
  This points to delivery after queueing, not proof of loss or a Tailscale fault;
  server packet egress is still missing. Keep this distinct from cursor pacing.
- Evidence and offline analysis: `.network-runs/diagnostic-1788596366046/`
  `analyze-warm.mjs`, `warm-analysis.json`, `cursor-characterization.gd` and log.
  Client/server/capture paths remain in the preceding completed-run entry.
- Next bounded experiment: presentation-only elapsed cursor opt-in with focused
  jitter/pause/backstep/rebase/lifecycle regressions, then separately approved A/B.
  Preserve simulation/rollback time, authority, fixed delay, networking defaults
  and display policy. Separately pair server egress/client ingress to localize
  shared delivery gaps. Server trace quality debt and browser gates remain open.

## First packet-correlated playtest analyzed, 2026-09-05

- Both clients exited zero; isolated server stopped and completed job removed.
  Production PID 57599 remains on UDP 10080. Read the first-real-run section of
  `docs/NETWORK_DIAGNOSTICS.md` for evidence and interpretation limits.
- Capture succeeded: 91,572 packets, zero capture drops, bounded completion.
  Packet arrivals continued during Alpha/Bravo 4.7/5.2-second callback gaps;
  measured network loops did not account for those gaps. Both process samples
  show main-thread OpenGL shader compilation inside the early stalled intervals.
  This identifies local rendering/startup work as a concrete contributor, not
  a complete connection outage or proof of the cause of all subsequent hitches.
- All sampled CPU speed limits were 100 this time, no thermal warning. Later
  callback stalls still reached 831/687 ms with traffic arriving. Network-loop
  median/p95 remained about 11/25 ms; no tuning or rendering changes applied.
- Client traces have zero drops; capture ends before the last 29/32 seconds of
  stage tracing. Server trace dropped 3,918 records after its 30,000-record cap.
  Optional server drops are visible in reports but not escalated to top-level
  warnings/exit status: diagnostic debt to fix before relying on that status.
- Evidence: `.crash-runs/two-client-20260905-032049/`, packet folder
  `.network-runs/capture-1788596366046/`, server and generated per-client reports
  `.network-runs/diagnostic-1788596366046/`. Owner said done without a new feel
  verdict. Final applied state current; worst observed probes 0.467/0.900 units;
  startup probe misses and guarded stale warnings retained, not hidden.
- Next: characterize startup shader/asset work and remaining post-warmup gaps,
  fix server diagnostic quality propagation/bounded coverage, then a separately
  authorized comparison. Keep renderer/display policy and networking defaults;
  mixed macOS/browser acceptance and earlier milestone failures remain open.

## Packet-correlated diagnostic playtest active, 2026-09-05

- Owner successfully started the short ignored `.network-runs/capture.mjs`
  helper in Terminal. Verified live tcpdump PID 4732 on utun6, filtered only to
  UDP host 100.113.2.60 port 12780, before launching clients. Capture output:
  `.network-runs/capture-1788596366046/`; bounded 180 seconds from about 03:19:26.
  Startup delay means packet coverage will end before the 120-second game traces;
  correlate only the overlap, do not claim full coverage or capture success yet.
- Fresh launcher/server evidence: `.network-runs/diagnostic-1788596366046/`.
  Non-restarting job `com.whenjohn.car-fight-diagnostic-1788596366046` in gui/501.
  Isolated server PID 63920, UDP 12780/TCP 12781; production unchanged.
- Both clients reported CLIENT_READY. Run:
  `.crash-runs/two-client-20260905-032049/`; Alpha subrun 20260905-032049,
  PID 4806, peer 2104429417; Bravo subrun 20260905-032052, PID 4869,
  peer 730769446. Both startup args contain P cruise and presentation tracing;
  stage tracing enabled for clients/server, unchanged fixed legacy settings.
- Early Bravo log includes guarded stale rollback and authority-probe misses;
  no SCRIPT ERROR/ERROR matches at readiness check. Do not equate connected
  status with a clean test. Await owner feedback and analyze complete logs.
- After both windows close, verify server cleanup, remove completed job, read
  capture.json/drop stats and generate separate client reports with server stages.
  Preserve the earlier premature run; these new output prefixes do not overwrite it.

## Premature diagnostic launch stopped, 2026-09-05

- Owner clarified that "started" meant opening Terminal, not running capture.
  The interrupted tool invocation nevertheless bootstrapped the prepared job.
  No tcpdump/capture process was present; this is not packet-correlated evidence.
- Stopped exact client PIDs 3812/3870 with SIGTERM (exit 143), allowed monitor
  cleanup, verified isolated UDP 12780/TCP 12781 free and production PID 57599
  still on UDP 10080, then removed the completed launchd job.
  Partial evidence: `.crash-runs/two-client-20260905-031540/` and the prepared
  `.network-runs/diagnostic-a7e5256-20260905-0305/` launcher directory.
- Next: owner must execute the actual sudo capture command and authenticate in
  Terminal. Verify a live endpoint-filtered tcpdump before any new launch; never
  unconditionally chain verification with bootstrap. Use a fresh launcher/server
  evidence prefix for the retry so this partial run is preserved.

## Diagnostic playtest prepared, awaiting capture authentication, 2026-09-05

- Owner approved the next two-native-client diagnostic playtest. Refreshed only
  the isolated macai2 runtime's project configuration, stage observer/source UID
  and publication markers. Production PID 57599 remains on UDP 10080/TCP 10181;
  isolated UDP 12780/TCP 12781 were free. No clients/server launched yet.
- Prepared ignored launcher/plist in
  `.network-runs/diagnostic-a7e5256-20260905-0305/`. It enables 120-second server
  and client stage traces plus client presentation traces, unchanged legacy
  settings, monitored decorated windows and P cruise in both clients. The
  non-restarting job is `com.whenjohn.car-fight-diagnostic-a7e5256-20260905-0305`.
- Routed capture interface is `utun6`. Owner must run the bounded 180-second
  capture helper in their Terminal with sudo, endpoint 100.113.2.60:12780,
  output `diagnostic-a7e5256-20260905-0305/packets` beneath `.network-runs/`.
  Wait for capture confirmation before bootstrapping the prepared job in gui/501.
  A quiet Terminal is expected while recording; never request a password in chat.
- After play: inspect capture completeness/drops and both stage/presentation
  traces, run endpoint-specific reports with the copied server trace, verify
  isolated server cleanup and remove the completed launchd job. If capture has
  already expired, use a fresh output directory; the helper refuses overwrites.

## Connection-versus-processing diagnostics implemented, 2026-09-05

- Owner requested the diagnostic setup. Read `docs/NETWORK_DIAGNOSTICS.md`.
  Added an opt-in observer before StateBundle/gameplay autoload subscriptions:
  per-loop forward/rollback prepare/simulate/record elapsed spans, frame gaps,
  clock anchors, native ENet local port and server publication queueing markers.
  Monitored clients receive unique stage-trace paths. Defaults remain off;
  authority/schema/clock/rollback logic and networking settings are unchanged.
- Added bounded endpoint-filtered tcpdump capture and a report that isolates
  sibling client ports and compares incoming packet observations with game gaps.
  It flags incomplete/dropped capture, clock shifts and unknown endpoints rather
  than inferring healthy networking. This is aggregate correlation, not exact
  packet-to-RPC queue delay or network-loss measurement; spans are not CPU time.
- Node fixture/mock tests and focused stage timing test PASS. Existing clean
  live headless gate with traces and injected 350 ms Bravo pause PASS: 0.300-unit
  worst probe discrepancy, zero reference rejects, no engine errors. All three
  stage traces have real loops/phases and zero drops; Bravo gap 386.9 ms.
- Final fast check and presentation-trace, remote-position and adaptive-delay
  regressions PASS without engine/script errors. PCAP fixture decoding/report
  CLI also passed from outside the project directory. Full suite not rerun for
  opt-in diagnostics; previous unrelated milestone failures remain open.
- Live packet capture did NOT start: macOS BPF requires admin authentication and
  `sudo -n` returned password required. The owner must authenticate the narrowly
  scoped capture command in their terminal at the next approved test; never ask
  them to share a password. No security settings/production services changed.
- Isolated macai2 still has the previous runtime. Next diagnostic playtest must
  refresh project.godot, the new diagnostic autoload/source and transport changes,
  not just copy the transport file. Enable server stage output as documented;
  do not deploy production. No rendered or browser test ran in this turn.
- Next: authorized short packet + stage + presentation capture on the original
  two-client setup, inspect per-stage stalls and packet timing. Only then choose
  a measured optimization. Rendered overhead, paired-server packet evidence,
  macOS/browser validation and prior milestone failures remain open.

## First rendered trace analyzed, 2026-09-05

- Owner finished the `6e47ca6` trace-enabled playtest. Both clients exited zero,
  isolated server stopped, completed job removed; production PID 57599/UDP 10080
  unchanged. No engine/script errors or display precursor; final states current.
- Read the first-rendered-result section in `docs/NETWORK_PRESENTATION_TRACE.md`.
  Both 120-second traces saved with zero dropped records. Alpha cruised; Bravo
  was the focused observer. No specific owner-marked hitch/new feel verdict.
- New evidence: both clients had 6.1/6.3-second wall callback gaps around
  02:07:47, hidden by 65-69 ms Godot deltas. Network-loop maxima reached
  5.9/6.0 seconds; Alpha rollback reached 5.7 seconds. CPU_Speed_Limit hit 24.
  Timers include scheduling delays, not CPU time; exact subsystem cause unknown.
- Bravo's earlier seconds 30-60 had 930/930 body samples interpolating with no
  hold/extrapolate. Whole-window processing stalls and cursor recovery are
  stronger next leads than blindly increasing the snapshot buffer. No tuning
  applied; detailed capture covers only the first two minutes, not all play.
- Next: targeted network/simulation profiling and a focused cursor-recovery
  characterization for wall-time versus engine-delta gaps. Keep two-client
  workflow; macOS/browser validation remains planned for later, not cleared.

## Trace-enabled cruise playtest active, 2026-09-05

- Owner approved this rendered test. Both monitored native clients connected
  to isolated macai2 UDP 12780 / TCP 12781 at runtime `6e47ca6`, with P cruise,
  HUD/telemetry and 120-second presentation traces verified in startup args.
  Legacy/fixed networking settings are unchanged. No browser test launched.
- Run: `.crash-runs/two-client-20260905-020617/`; alpha subrun
  `20260905-020617` PID 85989, bravo `20260905-020620` PID 86049.
  Each client writes `presentation-trace.jsonl` after two minutes or normal exit.
- Launcher/server evidence: `.network-runs/trace-6e47ca6-2026-09-05/`.
  Non-restarting job `com.whenjohn.car-fight-trace-6e47ca6-20260905` in `gui/501`.
  The isolated checkout received only the tested remote-position trace runtime
  update; production PID 57599/UDP 10080 was not changed. Launcher stops its
  isolated server and copies its log after both clients close.
- Await owner-observed stutter times; inspect actual trace records after flush.
  No smoothness claim yet. Remove the completed job after play; no auto-relaunch.

## Legacy presentation trace repaired, 2026-09-05

- Owner approved continued improvement and requested a macOS + browser test
  later, explicitly not now. Read `docs/NETWORK_PRESENTATION_TRACE.md` for the
  next bounded capture, regression evidence and deferred mixed-platform gate.
- Fixed a diagnostic blind spot: only batches previously started presentation
  traces, so the legacy mode used in human testing recorded nothing. Traces now
  start on connected frames/legacy arrivals, retain delivery identity and
  timestamped playback modes, and add monotonic callback gaps/focus separately
  from Godot delta. Completed captures stop gathering; 30,000-record cap remains.
- No movement, input/state/RPC schema, authority/replay, publication cadence,
  interpolation delay, networking defaults or production changes. This repairs
  measurement; it is not evidence that subtle stutter has been reduced yet.
- Validation: fast check, new real-transport-node trace regression, existing
  remote-position/adaptive tests PASS. Existing clean loopback two-client gate
  with traces/telemetry PASS (0.900-unit worst probe discrepancy, one guarded
  missing-reference rejection, no engine/script errors). Both saved legacy
  traces contain arrivals, body modes and monotonic frame gaps, with no drops.
- Human cruise run `.crash-runs/two-client-20260905-014319/` is now finished:
  both exits zero, isolated server stopped, completed launchd job removed;
  production PID 57599 remained on UDP 10080. No new rendered test launched.
- Next: explicitly approved trace-enabled cruise observation on the same
  two-client/isolated-server setup, separating whole-window stalls from remote
  hold/extrapolation or cursor jitter. Then choose one measured improvement.
  Later: macOS + browser, including browser background/resume and reconnect.
  Prior milestone failures remain open; do not claim cross-platform clearance.

## P-cruise human playtest active, 2026-09-05

- Owner's preliminary feedback: good, like before; very subtle stutter in the
  observed remote vehicle, plus occasional whole-world FPS drops. Keep these
  as separate symptoms. Bravo logged cruise active; session remains running.
- Live capture through about 01:46:32: preceding-minute median FPS 35/34;
  both clients dropped to single digits around 01:45:33-45 while both were
  unfocused. Network-loop maxima reached 193/242 ms and rollback 64/111 ms.
  macOS CPU_Speed_Limit minimum so far was 24; latest values remained reduced.
  These support local processing/power or background-scheduling pressure,
  not a proven CPU-only or thermal root cause. Latest applied state was current;
  no client engine/script errors or display precursor at capture. Fixed legacy
  playback still lacks the trace needed to explain subtle remote-only stutter.
- Owner approved launch. Both monitored clients connected to the isolated
  macai2 mux on UDP 12780 / TCP 12781 with `--client-cruise` verified in both
  process command lines. Runtime is `b8b6c36`; networking settings match the
  previous clock retest. Production UDP 10080 was left untouched.
- Run: `.crash-runs/two-client-20260905-014319/` (alpha PID 78509, bravo 78570).
  Launch/server evidence: `.network-runs/cruise-b8b6c36-2026-09-05/`.
  Non-restarting job: `com.whenjohn.car-fight-cruise-b8b6c36-20260905` in
  `gui/501`. Launcher stops only its isolated server and copies the server log
  when both clients close. Remove the completed job after the session.
- Await owner feedback; do not infer smoothness from startup connection.
  P starts/stops cruise in the chosen client and remains active while the
  owner observes from the other window. Do not restart automatically.

## Next playtest: P cruise enabled in both clients, 2026-09-05

- Owner requested the existing P auto-drive toggle for observing one client
  from the other. `scripts/play_macai2_two.sh` now enables it in both clients;
  `scripts/play_monitored.sh` forwards `CAR_FIGHT_CLIENT_CRUISE=1` as
  `--client-cruise`. Cruise starts inactive; P toggles full-speed/no-burst input
  and continues after focus moves. No rendered session was launched.
- Launcher configuration only: owning-client input, server body authority,
  schema, replay/lifecycle behavior and per-tick input cost remain unchanged.
  Ordinary unfocused manual input stays neutral. No new objects, RPCs,
  networking defaults, production changes or deployment.
- Validation: `scripts/check.sh` PASS; process-only zsh/Node checks exercised
  the real monitor argument block with cruise off/on and the two-client wrapper
  with mocked runners, verifying both flags, normal completion and client-failure
  propagation. No sockets or rendered windows. Full suite unnecessary for this
  launcher-only change; cross-client visual observation remains the next test.

## Clock retest completed: intermittent stutter, 2026-09-05

- Owner reports no desync but intermittent stutter/jumpiness versus an older
  optimized session. Both clients exited zero after about six minutes; temporary
  server stopped, user job booted out, production PID 57599 remained untouched.
  No settings or gameplay code changed during analysis.
- Read `docs/NETWORK_PLAYTEST_2026-09-05.md` for the result, settings, limitations
  and next experiment. Run: `.crash-runs/two-client-20260905-010252/`; completed
  server/derived analysis under `.network-runs/clock-retest-2026-09-05/`.
- After first-minute warmup: median 32/33 FPS, p95 interval-maximum frame delta
  70/68 ms, larger prediction mismatches alongside expensive processing.
  macOS CPU_Speed_Limit fell as low as 24. State remained current rather than
  seconds stale. No engine/script errors or display precursor in completed logs.
  Prediction discrepancies are not direct measurements of visible snap distance.
- Strongest lead is local frame/CPU pressure, with remote interpolation still
  unmeasured in this fixed/legacy mode. This was not a matched comparison with
  an older good preset: packing/bundles were off. Do not blame the optimizations
  or dismiss the same-machine two-client workflow without a controlled A/B.
- Next: match earlier good-session flags and profile a marked steady-state
  hitch, with monotonic frame gaps and subsystem costs. No broad optimization
  sweep, new smoothing, live server change, or automatic relaunch. Smoothness
  and full milestone acceptance are still open.

## Clock-fix human retest active, 2026-09-05

- Owner approved retrying the same two-client setup. Both monitored clients are
  connected on this Mac using runtime `e2a3121`, default networking plus telemetry.
  Run: `.crash-runs/two-client-20260905-010252/`; alpha PID 65585, bravo PID 65644.
- Updated only `addons/netfox/network-time.gd` in the stopped isolated macai2
  checkout; the remaining runtime matches the prior snapshot. Remote import
  verification passed. Temporary mux PID 57242 uses UDP 12780 / TCP 12781;
  production PID 57599 still listens independently on UDP 10080.
- Non-restarting user job `com.whenjohn.car-fight-clock-retest-20260905` was
  bootstrapped in `gui/501` with explicit `KeepAlive=false`. Plist and launch
  script are under ignored `.network-runs/clock-retest-2026-09-05/`. After both
  windows close, cleanup identity-checks/stops the temporary server and copies
  its log. Server also retains the 216000-tick limit.
- Initial samples: both clients see two players, applied state age 0 ticks,
  zero rejected states in the sampled interval, no observed engine/script or
  display-precursor errors yet. This is startup evidence only; collect human
  feedback and completed logs before claiming the desync is resolved.
- No new full-suite run, production update, default change or master merge.

## Diagnostic desync and pause-clock fix, 2026-09-05

- Owner reported the two clients out of sync. Captured both clients and the
  isolated server, then stopped the diagnostic run. Production PID 57599 on
  UDP 10080 remained running. The temporary launchctl-submit job restarted once
  on nonzero client exit; removed it explicitly and verified no diagnostic
  clients/server remained. Do not reuse that submit setup; any next detached
  launcher must explicitly disable automatic restart.
- Failed human run: `.crash-runs/two-client-20260905-004554/`. A brief unwanted
  restarted run is `two-client-20260905-004758`; keep its logs separate. Server
  capture is `.network-runs/playtest-2026-09-05/desync-server-live.log`.
- Both clients corrected their reference clocks at startup (+5.882 / +3.606 s)
  and later detected >1-second frame stalls. Final state tick ages were roughly
  284 / 216 ticks despite RTT around 16 / 20 ms. Those are misaligned tick ages,
  not measured multi-second packet transit. Bravo reached a 12.813-unit worst
  correction. This run failed human acceptance; no display precursor was found
  in captured original-run logs.
- Reproduced a concrete `NetworkTime` bug with injected clocks: pause recovery
  reset the tick label but retained the old simulation clock and tick schedule.
  Subsequent catch-up permanently shifted tick labels. The focused pre-fix
  test reached 227-257 ticks of drift for a +4-second reference offset.
- Fixed pause recovery by rebasing simulation clock, next tick, and tick label
  to one reference-time sample and resetting stretch to 1. No default, schema,
  authority, publication rate, smoothing, or stale-history guard changed.
  `network_time_pause_test.gd` now matches a clean timeline for 15 seconds with
  zero/+4/-4-second offsets and optional half-second backlog. This isolates the
  bug; a fresh rendered comparison is still needed to attribute the entire
  observed desync to it. No initial handshake RTT seed was added.
- Focused clock test and fast check pass. Stall-recovery gate passes with one
  reliable request, two applications and post-stall tick 500; its expected
  missing-reference/stale-history warnings remain logged. Reconnect passes with
  three joins/leaves and one missing-reference warning, no engine/script errors.
  Previous preflight failures remain open, not erased
  by this fix. No production deployment, master merge or automatic relaunch.
- Next: review the preserved desync and fix, then arrange the same two-client
  diagnostic retest with a non-restarting launcher. Full milestone clearance is
  still required before merge; do not spend another broad suite on a local fix.

## Playtest preflight, 2026-09-05

- UPDATE: Owner explicitly approved proceeding as a diagnostic playtest despite
  failed preflight. Launched temporary mux PID 56284 on macai2 UDP 12780 / TCP
  12781 and two monitored local clients, alpha/bravo, with default networking
  flags plus HUD/telemetry. Production PID 57599 remains on UDP 10080.
  Run: `.crash-runs/two-client-20260905-004554/`; launcher evidence:
  `.network-runs/playtest-2026-09-05/launch.log`. Temporary user launchd job
  `com.whenjohn.car-fight-networking-diagnostic-20260905` owns the wrapper;
  its exit cleanup stops remote PID 56284 and copies the server log after both
  windows close. Server also has a 216000-tick bound. Do not restart production.
  Collect human feedback and completed logs next; this is not acceptance.
- Owner approved two monitored macOS clients on this machine, connected to a
  temporary networking-branch server on macai2. Production must stay untouched.
  Read `MAC_INTEL_FULLSCREEN_FINDINGS.md`; use `scripts/play_macai2_two.sh` and
  its existing monitor, ordinary decorated inset windows, and staggered startup.
- Prepared source snapshot `ac9f89f` plus physical local art at
  `macai2-ts:/Users/macai2/Projects/car-fight-network-playtest-ac9f89f`.
  Both remote imports completed; verification had no engine/script errors.
  Isolated mux ports: UDP 12780 / signaling TCP 12781. Production remains PID 57599,
  canonical checkout, mux UDP 10080 / TCP 10181. Recheck before launching.
- Full-suite attempt found a stale case-sensitive collision-menu label in
  `tests/vehicle_size_respawn_test.gd`; corrected only the expectation to the
  existing text. The focused test then passed; fast check passed. No gameplay,
  networking defaults, or correction thresholds changed.
- Milestone clearance is FAILED: default `network_test.sh` (`latency120`) failed
  at 2.823 units and its one isolated retry at 3.615 (limit 2.0). Both largest
  corrections occur at startup with stall signals. A similar earlier baseline
  outlier exists; this is not yet attributed to the branch. Do not rerun until
  relevant evidence/code changes or relax the threshold.
- `vehicle_size_respawn_test.sh` also failed twice: observer reaches the scaled
  state, then gets CLIENT_STOPPED when the 420-tick server ends before the
  observer finishes. Keep harness lifetime debt separate from respawn behavior.
- Preserved logs under `.network-runs/playtest-2026-09-05/`. Remaining gates were
  continued separately, not counted as erasing either failure. See the networking
  review's September 5 follow-up for the completed result and log inventory.
- All eight final gameplay gates passed (mass collision, ball, tractor, reverse,
  combat, RC orb, shield, DET); the overall milestone still fails the two gates
  above. Owner chose diagnostic play, not acceptance. No production update or
  master merge is authorized.

## Active worktree: packet-size baseline, 2026-09-04

- Continuing on `codex/networking-review` in `car-fight-networking`. Added
  per-window `NETAPP payload_max` and `bundle_max` logical byte measurements;
  totals/copies and disabled behavior are preserved. No networking defaults,
  authority, schemas, replay, publication rates, or transport policy changed.
- Added focused telemetry regression and a real-schema packet-size fixture.
  Main factories supply 34 player properties and one physics property each for
  ball/prop; real encoders and in-memory Godot RPC dispatch project 2/4/8/16
  player templates plus one ball and 0/16/64 props. This is serialization
  evidence, not active-player simulation, encrypted datagrams, or fragmentation.
- Read `docs/NETWORK_PACKET_BUDGETS_2026-09-04.md` before the next packet-budget
  experiment. It documents measurement layers, table, engine/RFC sources and
  commands. A 16-player-template/one-ball/64-prop unpacked key is 13,419 bytes
  per RPC copy, 26,838 per recipient with its mirror. All-fields-changing diff
  is 16,043; 16-body pose batch is 1,086. Packing alone does not bound messages.
  The existing pressure guard still permits both recovery-key copies.
- Focused tests and fast check passed with clean final logs. Packed-input mixed
  gate passed at 0.900 units; bundled/packed ENet combined impairment passed at
  0.305, with live maxima and clean complete logs. Mixed logs retain two known
  missing-reference warning events and the expected collision-rejection error;
  that harness still kills the rejected client without proving natural exit.
  Evidence: `.network-runs/packet-size-2026-09-04/`; audit follow-up has details.
- Next: actual-link state-burst/queue/fragment measurements, then a scoped
  byte-budget experiment preserving recovery, route fairness and complete pose
  membership. Also audit remaining harness terminal-log/error coverage. Do not
  naively split pose lists or drop recovery mirrors based on size alone.
  Browser/TURN/device and actual multi-client CPU/load evidence remain open.
  Full milestone suite is still required before merging this branch. No
  deployment, master merge, rendered run, or default promotion.

## Active worktree: WebRTC server lifecycle, 2026-09-04

- Continuing on `codex/networking-review` in `car-fight-networking`. Reproduced
  malformed SDP emitting the server-fatal failure signal. Server peer errors now
  retire only their signaling/pending RTC session; listener/create-server errors
  remain fatal. Healthy DataChannels survive another peer's failure and their
  own signaling loss. Explicit mux/server rejection still removes gameplay.
- Added opt-in `--webrtc-pending-timeout-ms=N` and `--webrtc-max-pending=N` for
  pure WebRTC and mux servers. Both default to zero/disabled. Pending includes
  TCP acceptance through DataChannel establishment; connected peers are exempt.
  A positive cap closes excess TCP connections before RTC allocation and bounds
  accepts/rejections to 16 per process pass. No total-player/rate-limit claim.
- Peer cleanup runs outside RTC callbacks. Connection-instance checks reject
  stale callbacks after ID reuse; failure-time state prevents a failed join
  escaping cleanup if channels finish connecting before the process pass.
- New `tests/webrtc_server_lifecycle_test.gd` covers admission, timeout stages,
  malformed native SDP/ICE, healthy packet delivery, callback cleanup, ID reuse,
  explicit rejection, and genuine startup failure. Four native parser errors
  are intentional fixture output, not an allowlist for gameplay logs. Existing
  client bootstrap tests also pass. Both tests are in `scripts/test.sh`.
- Bounded Main smoke: cap 1, timeout 500 ms; excess TCP rejected, silent peer
  expired at 501 ms, bad SDP contained, subsequent ENet client completed 60 ticks,
  server completed 300 ticks/exit 0. Evidence and limitations are in the review
  follow-up and ignored `.network-runs/webrtc-server-2026-09-04/`.
- Fast check and final packed-input mixed gate passed; worst correction 0.576,
  zero codec fallbacks/rejects, no engine/script errors in complete mixed logs.
  Two bounded missing-reference diff warnings remain visible. Final mixed log
  folder: `car-fight-mixed.W8i4fI`.
- Next: inspect packet-byte/load budgets as player and object counts grow and
  audit remaining harness error/log coverage. Real browser/TURN and packaged
  platform evidence remain required before any limit/default promotion. The
  full milestone suite remains required before merging this branch. No default
  changes, deployment, master merge, rendered run, or same-session rejoin feature.

## Active worktree: WebRTC client bootstrap, 2026-09-04

- Continuing on `codex/networking-review` in `car-fight-networking`. Fixed async
  signaling failure before OPEN, once-only terminal failure, pending-resource
  cleanup, explicit-close polling, invalid peer-ID handling, and preservation
  of live DataChannels when signaling alone is lost. Main preserves the specific
  failure through subsequent stop/failure callbacks. RTC cleanup from SDP/ICE
  callbacks is deferred until poll unwinds.
- Added an opt-in total monotonic connection deadline spanning signaling open,
  assignment, and negotiation. Native `--webrtc-connect-timeout-ms=30000` or Web
  Network URL `webrtcConnectTimeoutMs=30000` enables an experiment. Zero remains
  the default; no silent-wait bound is claimed without opting in. No changes to
  authority, schemas, replication rates, channel lifetimes, or gameplay tuning.
- New `tests/webrtc_connection_test.gd` reproduced the original refusal bug and
  now covers real socket/RTC failures, injected deadline boundaries, duplicate
  IDs, callback-safe cleanup, explicit close, and packet delivery after signaling
  loss. Registered in `scripts/test.sh`; run it explicitly for WebRTC lifecycle
  changes. Native extension tests are not browser acceptance.
- The headless Main timeout smoke exited 2 with one expected error at 250 ms.
  Connection/frame lifecycle regression and fast check also passed. The focused
  RTC test passed with one native SCTP reset-stream teardown warning; keep that
  diagnostic separate from packet-delivery assertions. Evidence is under ignored
  `.network-runs/webrtc-bootstrap-2026-09-04/`; see the review follow-up for the
  contract, source reasoning, verification details, and limits.
- Final packed-input mixed ENet/WebRTC gate passed at 0.300 units, with zero
  codec fallbacks/rejects and no engine/script errors in complete logs. Four
  bounded missing-reference diff warnings remain visible. Collision rejection
  reached CLIENT_STOPPED normally. Final log folder: `car-fight-mixed.Vc6mQh`.
- Next bounded work: server pending-peer deadline/admission policy and peer-local
  signaling-error isolation. Some server SDP/ICE failures still reach Main's
  fatal global signal; this was identified by code review, not reproduced here.
  Same-session recovery and real browser/TURN/mobile-resume checks remain open.
  Full milestone suite remains required before merge. No deployment, master
  merge, rendered run, or networking default change.

## Active worktree: connection guards and complete logs, 2026-09-04

- Resumed networking work on `codex/networking-review` after the owner approved
  continuing. Fixed the observed inactive-peer frame callbacks using the shared
  `net/connection_state.gd` connected-peer predicate; offline peers still qualify.
  Main/local-player lookup, pickup prediction, vehicle presentation, city/oil
  visuals, and boost blur no longer query identity while connecting/disconnected.
- Client stop records DISCONNECTED and clears automatic cruise. Gameplay input,
  Main tick work, and settled probes are gated while inactive. No peer is replaced
  with an offline/server peer to hide errors; authority, schemas, replication
  rates, collision math, netfox history patches, and defaults remain unchanged.
- `network_test.sh` now waits for both client logs, bounds each post-server client
  wait (10 seconds by default), checks terminal exit status, reaps child processes,
  and fails engine errors as well as script errors. Server-first shutdown still
  permits the existing client exit 2 only with its CLIENT_STOPPED terminal marker.
  The two-unit correction limit is unchanged. Other harnesses need separate audit.
- Added a real-scene lifecycle regression with instrumented peer states; confirmed
  pre-fix failures, then passed connected/offline, connecting, disconnect/event,
  frame callbacks, gameplay input, and cruise checks. Process-only harness tests
  pass clean shutdown and reject late engine errors, unexpected exits, and hangs.
- Fast check and codec regression passed. Packed-input combined ENet gate passed
  at 0.805 units with complete error-free logs; mixed ENet/WebRTC passed at 0.300;
  default ENet reconnect passed (3 joins, 3 leaves). Mixed collision rejection has
  its expected signaling error; shared-gameplay/door-control logs are clean.
  Evidence: `.network-runs/lifecycle-2026-09-04/` and review follow-up.
- Next: bound WebRTC connection/negotiation failure paths while preserving live
  gameplay when signaling alone is lost. Same-session recovery, browser/mobile
  resume, and the earlier sporadic CityBall spawn/RPC ordering issue are not fixed
  by this change. Full milestone suite remains required before branch merge.
- No deployment, master merge, rendered run, or networking default change.

## Standing gameplay/networking guidance, 2026-09-04

- Owner requested durable rules and the reasoning behind them. Added
  `docs/NETWORK_SAFE_GAMEPLAY.md`, required from `AGENTS.md` and indexed by
  `.ai/CONTEXT.md`, `README.md`, and `docs/QUALITY_GATES.md`.
- Future gameplay/input/lifecycle/state work must state authority, replication
  class, replay safety, lifecycle behavior, bounded cost, and focused evidence.
  The guide explains general ownership/retry/budget/measurement principles and
  the Car Fight failures that motivate them, plus a reusable handoff checklist.
- At that documentation checkpoint, checks and proposed automation were explicitly
  separate. The codec
  regression is still run explicitly, network log/error enforcement still needs
  repair, and standardized feature-cost reports are not implemented yet.
- Documentation-only update on `codex/networking-review`; checked links/commands
  and diff formatting. No runtime, default, deployment, or canonical-master
  changes. These instructions reach master/new master worktrees only after the
  documentation is integrated there; the shared code change still needs the
  pre-merge milestone suite noted below.

## Active worktree: packed-input fix, 2026-09-04

- Owner authorized the first bounded implementation in
  `/Users/johnnguyen/Projects/car-fight-networking`, branch
  `codex/networking-review`. No merge, deployment, or networking default changes.
- Packed input now covers the real 14-property player schema, including troop
  drop, with explicit wire format 2. Version 1/unknown versions, malformed
  packed envelopes, and mismatched receiver schemas reject without decoding.
  Matching builds accept both packed and legacy Variant inputs; there is no
  old-build capability negotiation. Upgrade both ends before enabling packing.
- Send-queue thresholds now follow the actual payload, including schema
  fallback. Codec diagnostics count packed/fallback attempts, serialized bytes,
  successful unpacking, and rejects; NETAPP retains actual message accounting.
- Replaced the self-referential codec fixture with production player spawning
  and registration. Confirmed it failed before the fix; now covers all 8,192
  control masks, fixed version-2 bit positions, netfox redundant history and
  owner sanitization, cursor boundaries, malformed/versioned input, fallback
  thresholds, and mux routing. The test command now includes `-- --offline`.
- Focused codec test and state-bundle coalescing assertions passed; fast check
  passed. Headless packed-input-only combined ENet gate passed at 1.375 units;
  local mixed ENet/WebRTC gate passed at 0.385. Both paths report no codec
  fallbacks/rejects. Steady ENet input is 60 logical bytes/message versus 496
  in the review, not a measurement of transport bytes or improved visual feel.
- ENet shutdown still produces the known inactive-peer errors. Mixed shared
  gameplay logs were clean; its deliberate peer-ID collision case reports the
  expected signaling closure. No real browser/mobile/TURN or rendered tests.
  See the implementation follow-up in `docs/NETWORKING_REVIEW_2026-09-04.md`.
- Next: bounded lifecycle/gate fixes from the review. Before merging this shared
  codec/netfox change, run the full milestone suite once; it was intentionally
  deferred at this focused worktree checkpoint.

## Review checkpoint: networking review, 2026-09-04

Historical pre-fix checkpoint; its implementation next steps are superseded by
the packed-input section above and the standing development guidance.

- Created `/Users/johnnguyen/Projects/car-fight-networking` from updated master
  `9a25b09`, branch `codex/networking-review`; required local art copied with
  `scripts/sync_local_assets.sh`. Canonical master remains unchanged.
- Review and primary-source research are in
  `docs/NETWORKING_REVIEW_2026-09-04.md`. Runtime code/settings unchanged.
- First actionable finding: live input adds `drop_troops`, but the packed codec
  expects the older schema and silently falls back. Live opt-in input measured
  496 logical bytes/message. Existing codec test passes without live-schema
  coverage. Fix codec/version handling and actual-encoding telemetry first.
- Also found inactive-peer errors missed by the networking gate, unbounded
  browser connect paths, native/mux configuration differences, and packet-size
  budgeting gaps at larger object counts. See the review for evidence/limits.
- Headless combined profile: legacy failed at 2.852 units, passed its isolated
  repeat at 1.587; opt-in G2 divisor 1 passed at 0.586 with no missing-reference
  warnings. Both passing logs contain shutdown engine errors. These are short
  diagnostic comparisons, not clean lifecycle or cross-platform acceptance.
- Fast check and existing codec assertions passed. Raw evidence retained under
  ignored `.network-runs/review-2026-09-04/`. No rendered runs or deployment.
- Next: implement the bounded codec/schema fix, then connection/gate handling;
  compare all three transport paths before changing defaults. Platform and
  impairment matrix plus later pacing/interpolation/input-delay trials are
  documented in the review.

## Canonical baseline

- Active repository: `/Users/johnnguyen/Projects/car-fight` on `master`.
- Code-health audit baseline: `d949ba7`; validated audit head: `02c4829`.
- Engine: Godot 4.7.1 with Rapier 0.8.39.
- Renderer: Compatibility. Keep SSAO, directional shadows, native fullscreen,
  borderless fullscreen, and edge-to-edge windows disabled on this Intel Mac.
- Low Poly City is the sole authoritative world and map ID `0`.
- The deployed macai2 service uses native ENet on UDP 10080 and WebRTC
  signaling on TCP 10181. Use `ssh macai2-ts` and do not deploy as an implicit
  part of local work.

Read `AGENTS.md` for mandatory project rules and `.ai/CONTEXT.md` for the stable
architecture index. Read `GODOT_46_TO_47_HISTORY.md` before changing the engine,
renderer, lighting safety policy, Rapier, caches, or world architecture.

## Accepted: targeting optimization merged into canonical master

- Owner authorized merging `codex/targeting-optimization` into canonical
  `master`, preserving the newer modern-sprite and baked-shadow changes.
  Source worktree `/Users/johnnguyen/Projects/car-fight-targeting` was removed
  at owner request after verifying its clean state and ancestry in `master`.
  Profiling evidence was copied and hash-verified under ignored
  `.crash-runs/worktree-archive/targeting-optimization/runs/`. Local art matched
  canonical assets. The merged local/remote branch is retained.
- Acquisition applies the existing triangular coverage before visibility,
  skips candidates that cannot beat the nearest visible selection, and shares
  one candidate traversal/inverse transform/lazy ray setup across ready zones.
  Overlapping zones share each candidate's ray result within this call only.
  No cross-tick cache, scan throttling, cooldown, authority or wire changes.
- The first pass was committed/pushed as `3403e4a`. Follow-up matched headless
  256-fixture results: eager 12.233 ms, first pass 1.411 ms, shared pass 0.589 ms
  median per four zones. Shared scanning saves a further 58.3% in that run.
  This is acquisition CPU evidence, not rendered FPS or multiplayer capacity.
- Targeting tests cover 360 seeded comparisons, blocked fallback, ties, reversed
  tips, triangle corners, dead sprites, balls, shared overlap, cooldown masks,
  exact 15-tick firing and immediate empty-zone reacquisition. Real sprite
  combat exercises wall occlusion and matches all three selectors at 256.
- Follow-up validation passed targeting regressions, real sprite combat/CPU
  comparison, the focused server/client combat gate and `scripts/check.sh`.
  No broader state/network changes.
- Rendered profile completed after owner approval, monitor run
  `20260904-174243` clean: 256 fixtures with combat measured 20.727 ms median /
  27.135 ms P95, versus 19.827 / 23.189 ms without combat. Acquisition was
  1.560 ms per rendered frame. The historical unoptimized median was 148.97 ms;
  exact car pose and machine load are not controlled across those runs.
- Temporary instrumentation was removed after the run and retained as ignored
  diagnostic artifacts. See `docs/SPRITE_PROFILE.md` for raw evidence and limits.
- Merge validation passed `scripts/check.sh`, targeting regressions, sprite
  lab contracts (including modern samples), and live offline sprite combat.
  Focused gates cover the combined acquisition/presentation changes; no shared
  authority or transport changes warrant the broad networking suite.
- Optimization merged into `master`. No production deployment performed.

## Accepted: interactive sprite test in canonical master

- Baked-shadow trial for modern samples: confirmed translucent shadows in the
  downloaded PNGs. Changed modern-only alpha discard to opaque-prepass blending
  and ground registration from row 88 to 91 to retain soft pixels and avoid
  clipping the idle shadow's bottom rows. Depth testing and ghoul policy remain
  unchanged; no realtime shadows, physics, or networking changes. Fast check
  and expanded sprite contracts pass. Interactive run `20260904-174127` opens
  16 survivors for owner evaluation. Still a billboard shadow, not a ground
  projection. In repeat run `20260904-174641`, the owner confirmed shadows help
  ground the sprites and accepted keeping the adjustment. Added contact-shadow
  evaluation to the future-pack observations. Prone-pose alignment remains open.
- Added a local-only comparison for SmallScaleInt's two free modern exports:
  HD survivor (128px, 14 frames/clip) and outlined thug (64px, 8 frames/clip).
  `CAR_FIGHT_SPRITE_SAMPLE=survivor` or `thug` selects one at launch;
  Debug → Sprite test… → Character (local) switches live. Ghoul stays default.
  Source PNGs/archives remain ignored under `assets/local/smallscale-modern/`;
  setup/license notes are in `docs/SPRITE_MODERN_SAMPLE.md`. No paid creator,
  gameplay, collision, RPC, or targeting changes. These are sample art only.
  Fast check, expanded sprite contracts (including both local packs), and live
  offline sprite combat passed. Captures show both samples in-world; survivor
  death has ground clipping in some directions that still needs alignment work.
  Monitored capture runs `20260904-170858` and `20260904-171027` were stopped
  explicitly after their screenshot helpers waited on further rendered frames;
  neither completed the full perspective/UI capture sequence. Owner subsequently
  preferred the modern samples and found them smoother than the ghoul. Logged
  selection criteria in `docs/SPRITE_MODERN_SAMPLE.md`: prioritize gameplay-scale
  readability, pose spacing, loops and stable registration over raw frame counts.
  All samples have eight directions and default to 12 animation FPS; the exact
  comparison settings were not recorded and proposed causes remain hypotheses.
  Death alignment still needs work. No default change or purchase authorized.
  Start with 16, not a new performance stress test.
- Owner confirmed the spread-out 256-fixture slowdown on a repeat run; 128
  felt better. CPU profiling now identifies automatic target acquisition as
  the dominant cause, not a demonstrated sprite rendering limit. The matched
  256 test measured 148.97 ms median with combat versus 16.38 ms without it;
  acquisition used about 98% of combat CPU and performed about 57,000 visibility
  checks/second before range/angle filtering. See `docs/SPRITE_PROFILE.md`.
  Temporary instrumentation was removed; no optimization or deployment made.
  Next: filter range/angle before visibility queries, preserve targeting rules,
  then rerun 256 with full combat and owner driving/shooting validation.
- Research handoff saved in `docs/SPRITE_PROFILE.md` under "Next-session
  handoff": filter existing triangular coverage first, skip visibility checks
  that cannot change nearest-visible selection, and reuse per-tick setup.
  Preserve ties, blocked-nearest fallback, reversed-tip geometry and firing
  cadence. Defer scan throttling/spatial grids until reprofiled. Owner requested
  documentation only at this checkpoint; no targeting optimization implemented.
- Follow-up requested: raise the practical test ceiling and spread fixtures
  out. Added 128/256 count options and a street layout with at least four-unit
  initial separation, building clearance and a six-unit clear zone around the
  observer. Half the mixed fixture walks with staggered phases. Start with
  `CAR_FIGHT_SPRITE_COUNT=256 ./scripts/play_monitored.sh --offline --sprite-test`.
  Earlier performance samples below describe the original compact layout.
- Spread-layout validation passed: fast check, 256-position spacing/bounds
  checks at 100% and 200% scale, live sprite combat through all count options,
  and the 256-target two-client replication/late-join/MTU gate. Interactive
  monitored run `20260904-162251` was opened for owner evaluation.

- Session scope: evaluate sprites in Car Fight using the CC0 ghoul pack as
  sample art. This is not a zombie gameplay direction.
- Launch `./scripts/play_monitored.sh --offline --sprite-test`, or use
  `--local --sprite-test` for a local dedicated server/client. The ordinary
  launch stays unchanged; controls are under Debug → Sprite test….
- Eight-direction idle/walk/attack/death sprites support shared, on-demand
  128px/512px atlases, stable foot registration, camera-relative facing, local
  previews, and 1/16/64 server-controlled fixtures.
- Upright capsule hitboxes take three confirmed weapon/area hits to die.
  Swept contact with the actual scaled vehicle capsule kills immediately and
  never changes vehicle velocity. Death removes collision/target eligibility;
  reset restores health. Moving targets use lightweight updates, not rollback
  bodies. Reliable generation-fenced state handles hits, death and late joining.
- `docs/SPRITE_TEST.md` records commands, architecture, focused verification,
  measurements and limits. Source/CC0 metadata and the reproducible packer are
  included with the imported sample.
- Monitored visual runs `20260904-145702` and `20260904-150019` exited cleanly.
  At 16 fixtures, the 128px sample measured 16.68 ms median / 18.82 ms P95 and
  about 11 MiB additional texture memory; 512px used about 91 MiB additional.
  Keep 128px as default. At 64 fixtures, frame cost increased; some fixtures
  were outside the viewport, so this is not an all-visible crowd limit.
- Both runs showed an approximately 6.9-second initial rendering stall before
  warmed sampling. No claim is made about cold-start/network rendering latency.
- Owner accepted the sprite test after single-client runs `20260904-160642`
  and `20260904-161030`; both exited cleanly. Implementation is committed as
  `4a1324b` on canonical `master`. No production deployment occurred.
- Owner visual feedback: the sprites look okay as a proof of concept; more
  directional views and a higher animation frame rate could make them look
  good. Keep these as follow-up evaluation priorities, not completed changes.
- Verification: fast check; sprite asset/animation/capsule tests; live offline
  sprite combat; baseline offline and combat gates; and the 64-target server /
  two-client gate for hit/death replication, late joining and owner controls.
  Movement snapshots are batched to stay below the unreliable packet MTU.

## Accepted checkpoint: ramming lab, vehicle tuning, and scatter props

- Active feature worktree: `/Users/johnnguyen/Projects/car-fight-ramming-gameplay`
  on `codex/ramming-gameplay`, based on `master@cea2a3b`.
- The opt-in `--ramming-lab` starts three server-controlled, ordinary-physics
  vehicle drones on fixed opposing lanes at about six units/second. The Humvee,
  Apocalypse Bus, and LP Car cover separated-wheel, bounded-wheel, and
  body-baked-wheel presentation paths. Recovery occurs only after a bounded
  stall, overturn, off-course interval, or leaving the city.
- The lab isolates vehicle contact by disabling its existing server driver,
  ball, shield drone, and automatic combat. Server contact telemetry records
  the unchanged pre-enhancement collision baseline. The owner accepted the
  lab's traffic and general feel in monitored local runs.
- Vehicle size and mass are independent authoritative spawn properties. The
  compact `Vehicle Tuning…` popup exposes local draft and server-approved
  values, per-model mass defaults/weight classes, reset, collision visibility,
  and explicit `Apply & Respawn`. The reliable prepare/ack/drain replacement
  preserves the same player ID with a fresh generation and avoids stale input
  reaching the replacement path.
- The three lab drones use authoritative 150% model/collider sizing and
  representative masses: Humvee `3.2`, Apocalypse Bus `4.5`, LP Car `1.6`.
  The equal-speed collision gate proves the lighter car receives the larger
  velocity change. Debug collision capsules can be shown for every replicated
  vehicle at once and remain enabled through respawns.
- Twelve server-owned city-pack scatter props now occupy the ramming lanes:
  four barrels, four crates, two tires, and two mailboxes. Their masses range
  from `0.08` to `0.18`, use ordinary rigid-body response and CCD, and replicate
  through stable reserved negative StateBundle routes. Missing local art falls
  back to simple procedural meshes; the city extractor emits the selected
  visual library when the ignored source pack is present.
- Owner acceptance: vehicle tuning/respawn, all-vehicle capsule display, and
  the scatter-prop visual pass were tested interactively and accepted for
  commit.
- Validation passes: `./scripts/check.sh`, focused vehicle tuning, sizing,
  animation, ramming-lab, scatter-prop, city-audition, and StateBundle tests;
  `./scripts/vehicle_size_respawn_test.sh`;
  `./scripts/vehicle_mass_collision_test.sh`; and
  `./scripts/ramming_lab_test.sh`. The last gate replicated all 12 props and
  measured a `7.40` peak scatter speed. Monitored runs through
  `20260903-185440` ended cleanly or were owner-closed after evaluation.
- No deployment was performed or authorized.

Next checkpoint: tune explicit arcade ram response in small accepted steps—head
on first, then side swipe, drift slam, boost ram, and finally bounded airborne
knock-up—while preserving server authority, rollback determinism, mass ratios,
and the chassis/wheel presentation response.

## Completed work: camera tuning and opt-in always-forward experiment

- Merged to `master` from `codex/always-forward-camera` at `48732a2`, originally
  based on `master@b6c2fa0`. The completed worktree was removed after its three
  monitored runs were preserved under
  `.crash-runs/worktree-archive/always-forward-camera/runs/`; the merged branch
  remains as a recovery reference.
- The presentation-only camera experiment remains available but now starts
  disabled after the owner found the rotating-world orientation disorienting.
  Its toggle is deliberately session-only, so saved tuning can never make the
  experimental orientation replace the standard camera on a later launch.
  When enabled it keeps the local vehicle nose returning to screen-up. The first owner pass found that its hard
  22-degree bound forced near-1:1 world rotation and felt disorienting. The
  comfort revision instead uses a 10-degree active-turn soft zone and caps
  camera rotation at 95 degrees/second, then settles fully after the turn.
- Speed-scaled travel look-ahead now has separate acceleration and braking ease
  responses. Simulation, authority, rollback, and wire state are unchanged.
- The native Debug system menu contains an enable/disable comparison toggle and
  a `Camera tuning…` window. Turn catch-up, comfort zone,
  maximum camera turn speed, viewing angle, zoom, orthographic/perspective
  projection, look-ahead distance, acceleration ease, and braking ease update
  live and autosave locally. The comfort revision lowers
  the default pitch from the original 55 degrees to 48 degrees so building
  sides provide a stronger depth cue. Tool-window focus sends neutral controls.
- Gameplay status text and control hints now both start hidden. Separate Debug
  menu checks can restore either during development; browser hints require the
  explicit `hotkeyHints=1` query value.
- Validation passes: `./scripts/check.sh`, `tests/always_forward_camera_test.gd`,
  `tests/always_forward_camera_ui_test.gd`, `tests/sense_of_speed_test.gd`,
  `tests/asset_smoke_test.gd`, `tests/home_world_lighting_test.gd`, and
  `./scripts/offline_test.sh`.
- The owner rejected always-forward world rotation as the default but accepted
  merging it as an opt-in comparison alongside the general camera controls.
  No deployment was performed or authorized.

## Completed work: combined feature merge

- `master` now contains `codex/lighting-editor`, `codex/city-draw-order`, and
  `codex/ch-011-authority-probe` plus the accepted follow-up
  `codex/lighting-editor-input-focus`. Their four merged worktrees were removed
  after validation; the branches remain available as recovery references.
- Ignored monitor evidence from those worktrees is preserved under
  `.crash-runs/worktree-archive/` in the canonical repository.
- Combined validation passes: `./scripts/check.sh` and the complete
  `./scripts/test.sh`, including lighting/window policy, city presentation,
  authority-probe delivery, ENet, mixed transport, join, and reconnect gates.
- No deployment was performed. The macai2 production service remains separate.

## Completed work: Lighting Editor input focus

- Merged from `codex/lighting-editor-input-focus`, based on merged
  `master@9a1da6b`; its completed worktree has been removed.
- Owner testing showed that focusing the native editor, especially its look-name
  field, left vehicle keyboard state partially responsive while the game
  viewport's mouse position stopped updating. This was UI focus behavior, not
  the sustained rollback/network stall.
- Live vehicle input is now explicitly neutral whenever the Lighting Editor
  owns native-window focus. Clicking the game resumes normal mouse control; a
  visible `Return to game` button and submitting a look name also return native
  focus to the game window.
- Focused validation passes: `./scripts/check.sh`,
  `tests/home_world_lighting_test.gd`, `tests/asset_smoke_test.gd`, and
  `./scripts/offline_test.sh`.
- The owner verified the native macOS focus handoff in monitored run
  `.crash-runs/worktree-archive/lighting-input-focus/runs/20260902-225127`:
  after selecting the look-name field, returning to the game restored normal
  mouse steering. The result was accepted.

## Completed work: live lighting editor

- Merged from `codex/lighting-editor`, originally based on `master@353f824`;
  its completed worktree has been removed.
- The native `Scenery` system menu now opens a transient `Lighting Editor`
  window modeled on G2's live tuning UI. It starts from the selected lighting
  preset and updates the local presentation in real time.
- The editor is deliberately limited to nine high-impact choices: sun color,
  brightness, height, and direction; world fill; exposure; saturation; and
  positional contact-shadow visibility/darkness. It does not expose SSAO,
  directional shadows, renderer selection, or other unsafe/low-value knobs.
- `Reset to selected preset` discards experimental edits. Selecting another
  existing Scenery preset also refreshes the open editor to that preset.
- Each edit now autosaves a working look under `user://`; the look and its
  built-in base preset restore on the next launch. The same window can save,
  load, overwrite, and delete named look snapshots.
- The editor is a compact 470x540 native child window. It remains at native
  pixel size instead of growing with the game's fixed-viewport canvas stretch
  when the main window is resized.
- New Car Fight worktrees must run `./scripts/sync_local_assets.sh` immediately
  after creation. The tracked `AGENTS.md` rule and helper physically copy only
  the required ignored city and Collection tree families from a registered
  donor worktree; no symlinks, destructive sync, or retired audition packs.
- The Intel Mac window guard no longer imposes its former fixed 1280x720 cap.
  Ordinary decorated windows can be resized freely while they remain within
  the 48-pixel safe inset; fullscreen, maximized, borderless, and edge-to-edge
  presentation remain blocked.
- Validation passes: `./scripts/check.sh`,
  `tests/home_world_lighting_test.gd`, `tests/window_safety_policy_test.gd`, and
  `./scripts/offline_test.sh`. The local-asset bootstrap also passes its own
  `--check` plus the focused city-audition and tree-library tests from a
  previously empty feature worktree.
- Optional follow-up: one owner-approved monitored visual pass in an ordinary
  inset window to judge layout and whether the controls produce useful looks.

## Completed work: code health

- The owner approved and `master` was fast-forwarded from
  `codex/code-health-audit` through validated head `02c4829`.
- The cleanup worktree and branch remain available until a separately approved
  repository-housekeeping pass; do not delete them implicitly.
- Evidence ledger: `docs/CODE_HEALTH_LEDGER.md`.
- Stable architecture/index context now lives in `.ai/CONTEXT.md`. The shared
  project registry resolves `car-fight` to the active Godot repository and
  marks `car-fight-unity` archived. `.ai` intentionally remains tracked locally
  until its separate shared-storage decision.
- Cleanup must remain separate from gameplay, visual tuning, bug fixes, engine
  changes, and optimization.
- Networking, rollback, transports, RPC/state schema, physics feel, rendering
  behavior, and vendored netfox patches remain protected and are audited last.

Completed branch commits:

- `ece1668` — shared Claude/Codex project rules, risk-based quality gates, quiet
  fast check, and removal of three orphan UID sidecars.
- `6cb93cd` — code-health evidence ledger.
- `37ff6eb` — one shared two-pass Godot import verifier used by the fast check,
  complete suite, deployment import, and Web build.
- `177e7f2` — reduced the auto-read phase handoff to current information and
  preserved the former 890-line phase history under `docs/history/`.
- `668dc96` — added stable project architecture/context; the matching
  `claude-comms` registry repair is commit `234335f`.
- `2268137` — recorded the stale files retained on macai2 by non-deleting
  deployment sync; its original manual count of 31 was later corrected to 33.
  No remote file was changed.
- `f73ff79` — added a structural manifest guard; it now covers all 33 standalone
  GDScript tests without executing them during the fast check.
- `bcf13d9` — the macai2 deployment helper now defaults to a read-only preview,
  requires an explicit `apply` from a clean `master`, and preserves
  generated/local state.
  Its preview matched the exact 33 stale files plus two empty directories;
  nothing has been deleted remotely.
- `17b2068` — recorded protected recovery refs, both active worktrees, and 20
  merged local plus 20 merged remote cleanup candidates. No ref was deleted.
- `a38b91c` / `ba2b903` — characterized the server `RESULT` schema and moved
  its pure 32-field formatter outside `Main.gd`. Metric collection, report
  timing, gameplay, authority, RPCs, and transport behavior are unchanged.
- World/spawn layer: removed the city-only `_build_home_world()` forwarding
  wrapper. Focused checks pass, and the owner confirmed the complete city and
  dots during monitored local server/client play; the monitor ended cleanly.
- CH-013 records that offline startup does not seed dots. This predates the
  cleanup and remains separate gameplay bug debt.
- World/presentation layer: removed the unreachable proximity-landmark tree
  builders and their no-op Tree model menu. The owner confirmed city trees and
  retained lighting controls in monitored local play; the monitor ended cleanly.
- World/presentation layer: removed the obsolete local prop audition, which
  spawned visual-only props beyond the accepted north city wall. Focused city,
  lighting, and fast checks pass; the owner confirmed normal city, street-tree,
  dot, driving, and lighting behavior in monitored local play, and the monitor
  ended cleanly.
- World/presentation layer: reduced the tree visual library to the sole accepted
  Collection 121–130 family and removed the unreachable 37 MB Shapespark
  audition package. Focused tree, city, lighting, and fast checks pass; the
  owner confirmed the complete street-tree lining and normal play, and the
  monitor ended cleanly.
- World/construction layer: folded the obsolete arbitrary-rotation static-box
  helper into the live yaw-only city builder after tracing its removed ramp and
  upper-road callers. Focused city and reverse/wall checks pass; the owner
  confirmed building and outer-wall collision, and the monitor ended cleanly.
- Player layer: removed three uncalled helper methods while preserving their
  live backing state, setters, gesture fields, rollback schema, and correction
  sampling; corrected the stale sphere-collider comment to the accepted capsule.
  Focused vehicle, area-weapon, correction, and fast checks pass; the owner
  confirmed driving, vehicle cycling, and area targeting, and the monitor ended
  cleanly. CH-018 records removed-gate state that remains protected on hold.
- Combat layer: removed the uncalled shield-drone aiming method while preserving
  Main-owned targeting, projectile authority, timing, muzzle position, and
  current fixture orientation. Focused asset and shield runtime checks pass;
  the owner confirmed the drone shot and shield interaction, and the monitor
  ended cleanly.
- Documentation checkpoint: updated README and nearby comments that still
  described the retired tree/prop auditions, old arena size, sphere collider,
  ramps/map gates, and an outdated vehicle-mesh contract. Fast structural and
  exact stale-phrase checks pass; no runtime files changed.
- Network/rollback layer: removed three uncalled, side-effect-free transport/
  cadence query getters while preserving MultiplayerPeer overrides, transport
  ownership, routing, internal cadence decisions, state, and wire behavior.
  Focused StateBundle/codec/remote-position checks pass; the owner confirmed
  normal ENet play, and the monitor ended cleanly. Dormant recovery/failure
  injection seams remain protected on CH-022 hold.
- Scripts/tooling layer: removed the historical sunlit-aerial launcher after
  tracing the lighting/map selections that once distinguished it, and removed
  two unconsumed no-ramp environment assignments. Distinct Networking 1,
  Networking 2 mixed, and shaped one/two-client direct-entry harnesses remain.
- Agent-scaffolding layer: corrected the shared `AGENTS.md` collider and scope
  language to match the accepted capsule, existing bounded weapons, and the
  opt-in G2 lab stack. `CLAUDE.md` remains its relative symlink so both agent
  clients receive one project policy.
- Documentation-routing layer: marked the completed engine, Web, and Networking
  1/2 plans as historical snapshots; current sessions now route through README
  and stable context. README reflects accepted forced-TURN reconnect/two-player
  evidence and the deployed ENet/WebRTC mux while retaining unfinished public
  browser hosting/TURN and opt-in experiment boundaries.

Validation for the import-verifier cleanup:

- `./scripts/check.sh` passes.
- `./scripts/server_daemon.sh import` passes.
- A bounded Web Offline debug export passes.
- The test-manifest positive check and omitted-test negative control pass.
- At that import-only checkpoint, the complete gameplay/network suite was not
  run because the change affected validation tooling only.

Accumulated cleanup-boundary validation:

- After the final layer audit, all 33 focused GDScript contracts pass once.
  The WebRTC harness lifecycle, offline smoke, late-join recovery, reconnect,
  ball, tractor, reverse, combat, RC-orb, shield, and det gates also pass once
  at the final milestone.
- `network_test.sh` and `mixed_transport_test.sh` fail because no queued
  authority probe reaches clients. Both failures reproduce on untouched
  `master@d949ba7`, so they are recorded as pre-existing CH-011 network-test
  debt rather than a cleanup regression and were not wastefully rerun at the
  final milestone.
- The first sandboxed WebRTC lifecycle attempt failed with loopback
  `listen EPERM`; its required unsandboxed rerun passed.

## Completed work: CH-011 authority-probe delivery

- Merged from `codex/ch-011-authority-probe`, originally based on
  `master@353f824`; its completed worktree has been removed.
- Historical tracing found the intended consumer in sibling city commit
  `b20bb6a`. Promotion commit `3ccd8fe` retained the 20-tick delay constant,
  queue producer, and client receiver but omitted the loop that dequeued mature
  samples and sent them to their owning peers.
- Restored that exact bounded delivery seam before new samples are scheduled.
  It rechecks the live peer list at delivery time, preserving the existing
  disconnect-race guard, unreliable RPC contract, cadence, and authority model.
- Added `tests/authority_probe_delivery_test.gd` to prevent another partial
  promotion from leaving the queue without its delayed consumer.
- Focused validation passes: authority-probe delivery contract, fast check,
  ENet `network_test.sh` (1.674-unit worst correction), mixed ENet/WebRTC
  `mixed_transport_test.sh` (0.300), late join, and reconnect.
- The required integration-boundary `./scripts/test.sh` passes completely. Its
  ENet run reported a 1.834-unit worst correction and mixed transport reported
  0.300; all lifecycle and gameplay gates passed. The initial sandboxed ENet
  attempt failed only because local UDP bind was denied, and the required
  unsandboxed run passed.
- A two-rendered-client check used this exact branch on a temporary isolated
  macai2 server at UDP 12680; production UDP 10080 was not modified. Probe
  delivery worked, but sustained play failed: Alpha and Bravo reached 91.671
  and 92.553-unit corrections, respectively, and each client's remote-player
  view froze. Evidence is preserved under
  `.crash-runs/worktree-archive/ch011/runs/two-client-20260902-221336/`.
- The live failure followed a shared performance/rollback stall around
  22:14:53. Bravo reported a 562 ms process interval and 232-tick rollback
  depth; Alpha then reported a 653 ms process interval with deep rollback.
  Both exceeded the retained 64-tick history, stale-authority recovery repeated,
  and fresh body state did not converge even though the server kept ticking.
  The temporary server was stopped and production UDP 10080 remained running.
- The identical control used matching `master@353f824` clients and a temporary
  isolated macai2 server at that exact commit. It reproduced the large shared
  freeze, stale-history recovery loop, and an even stronger failure: macai2
  timed out and removed both peers while their windows continued producing
  inactive-multiplayer errors. The user saw the major freeze but no persistent
  split because both clients had disconnected. Evidence is preserved under
  `/Users/johnnguyen/Projects/car-fight/.crash-runs/two-client-20260902-222423/`.
- This control establishes that the sustained rendered stall/recovery failure
  predates restored probe delivery. Keep that investigation separate from
  CH-011; the probes make divergence measurable but do not mutate simulation
  state. Both temporary macai2 servers were stopped, and production UDP 10080
  remained running throughout.

## Next

1. Open the pre-existing sustained rendered stall/recovery failure as a separate
   networking worktree/task, preserving both captured runs. Do not repeat
   rendered testing without explicit owner approval.
2. Decide separately whether tracked `.ai` state should move into the shared
   `claude-comms` symlink model; preserve history and account for concurrent
   worktrees before changing storage.
3. Apply the reviewed 33-file/two-directory macai2 cleanup only after explicit
   owner approval from clean `master`. Its old
   remote `gate_test.sh` still consumes the constant-zero course/gate `RESULT`
   fields, so retain that output contract until deployment state is resolved.
4. Review the branch-ledger candidates; delete no ref without separate owner
   approval and a fresh merged/ancestor check.
5. Treat the characterized result-report boundary as the limit of this cleanup;
   argument parsing and any further `Main.gd` extraction remain on hold.

The complete former phase log is preserved at
`docs/history/CURRENT_PHASE_THROUGH_2026-09-02.md`.
