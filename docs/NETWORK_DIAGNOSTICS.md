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
