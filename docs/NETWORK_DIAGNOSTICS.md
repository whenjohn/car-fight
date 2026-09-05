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
