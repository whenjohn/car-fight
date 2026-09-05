# Packet-size baseline, 2026-09-04

Measured in `car-fight-networking`, based on `8ef25c7`, with Godot
4.7.1-stable official, Rapier 0.8.39, headless on the Intel development Mac.
This adds measurement, not a new packet budget or networking default. See the
[networking audit](NETWORKING_REVIEW_2026-09-04.md) and
[gameplay contract](NETWORK_SAFE_GAMEPLAY.md).

## What is measured

`tests/network_packet_size_test.gd` creates real player, CityBall, and crate
nodes through Main's factories, reads their registered server-owned schemas
(34, 1, and 1 properties), and uses netfox's actual full/diff encoders. It
replicates these encoded templates through route-only nodes for 2/4/8/16
players, one ball, and 0/16/64 props. This is not that many active physics bodies
or clients. Combat scalar fields are changed synthetically; combat itself is
not simulated. Additional combat object families/events are not included.

The real pose sender and StateBundle sender dispatch RPCs through real
SceneMultiplayer instances connected by an in-memory MultiplayerPeerExtension.
The receiver decodes the RPCs; a test-only StateBundle subclass checks envelope
shape/authority without applying synthetic states to gameplay. No production
transport, encoding, authority, replay, membership, or lifetime behavior changes.

The probe captures bytes **after Godot RPC encoding, before transport framing**.
It lets node-path cache negotiation complete and measures 11 subsequent sends.
The report also records the first dispatch for each row; only a node's initial
dispatch is necessarily uncached. RPC command filtering follows the
[Godot 4.7 SceneMultiplayer command definitions](https://github.com/godotengine/godot/blob/4.7/modules/multiplayer/scene_multiplayer.h).
Review this assumption when changing engine versions.

- `rpc_max_bytes`: largest individual warmed RPC in one recipient's publication.
- `rpc_bytes`: all RPC bytes for that recipient/publication, including key mirror.
- `all_recipient_rpc_bytes_projection`: multiply by the template player count;
  this is arithmetic fan-out, not an actual multi-recipient transmission.
- `logical_maxima` / `logical_bundle_maxima`: existing `var_to_bytes` accounting,
  now with per-window maximums. Not RPC size or encrypted datagram size.
- Dispatch timing covers queue construction, RPC encoding and in-memory copies,
  with telemetry enabled. It excludes state-template encoding/packing, receiving,
  transport, live simulation and rollback. The 11 samples are not a capacity or
  stable tail-latency benchmark; no CPU acceptance threshold is inferred.

## Measured sizes

All values below are **bytes per individual warmed RPC**, not kilobytes or
bandwidth. State columns show unpacked / packed physics state; player scalar
fields remain ordinary state. Packing stays opt-in. Every state scenario
includes one ball and sends all listed routes together.

| Player templates | Props | Physics-only diff | All-fields-changing diff | Full key, one copy |
| --- | --- | --- | --- | --- |
| 2 | 0 | 379 / 199 | 1,235 / 1,127 | 907 / 763 |
| 2 | 64 | 7,611 / 3,591 | 8,467 / 4,519 | 8,139 / 4,923 |
| 4 | 0 | 607 / 307 | 2,319 / 2,163 | 1,663 / 1,423 |
| 4 | 64 | 7,839 / 3,699 | 9,551 / 5,555 | 8,895 / 5,583 |
| 8 | 0 | 1,059 / 519 | 4,483 / 4,231 | 3,171 / 2,739 |
| 8 | 64 | 8,291 / 3,911 | 11,715 / 7,623 | 10,403 / 6,899 |
| 16 | 0 | 1,963 / 943 | 8,811 / 8,367 | 6,187 / 5,371 |
| 16 | 64 | 9,195 / 4,335 | 16,043 / 11,759 | 13,419 / 9,531 |

The all-fields diff changes each registered scalar once from its real initial
value, plus moving physics. It is a stress case, not an observed combat average
or a maximum over every possible value/integer width. Diffs can exceed full
snapshots because each changed property carries patch metadata.

Full keys produce **two** messages: reliable plus unreliable-ordered mirror.
Thus the largest unpacked key row submits 26,838 RPC bytes to one recipient,
or a projected 429,408 across 16 recipients, on one key publication. The packed
equivalent is 19,062 per recipient. The existing 65,536-byte queue-pressure
guard drops ordinary state but still sends both key copies; the fixture checks
this explicitly at an injected queue size of 65,537. This is not a saturation
or real-queue measurement.

Pose batches cover pilotable bodies under `Main/Players`, not balls or props:

| Pose bodies | Batch RPC bytes | Legacy total RPC bytes (82 each) |
| --- | --- | --- |
| 2 | 190 | 164 |
| 4 | 318 | 328 |
| 8 | 574 | 656 |
| 16 | 1,086 | 1,312 |
| 32, cap stress only | 2,110 | 2,624 |
| 64, cap stress only | 4,158 | 5,248 |

For these identifiers/ticks/cache state, a batch grows by 64 bytes per body.
32/64 are tests of the existing body cap, not supported player-count claims.
Batching reduces message count; the two-body case has more RPC bytes than
legacy before transport headers. Keep that distinction when comparing savings.

## Interpretation and next experiment

State-envelope growth and duplicated recovery bursts deserve investigation
before changing pose publication rates. Packing physics alone does not bound
an all-fields state envelope. These are priorities inferred from serialization,
not proof that fragmentation currently causes a particular gameplay hitch.

Godot's ENet sender selects unreliable fragmentation flags for ordinary
unreliable modes and warns about oversized sends in debug builds. ENet fragments
using peer MTU minus protocol/checksum overhead, not the advertised maximum
application packet size. See the
[Godot ENet sender](https://github.com/godotengine/godot/blob/4.7/modules/enet/enet_multiplayer_peer.cpp)
and [bundled ENet fragmentation code](https://github.com/godotengine/godot/blob/4.7/thirdparty/enet/peer.c).
The size probe bypasses ENet, so no fragmentation or loss rate was measured here.

Godot's WebRTC multiplayer API reports 1,200 as its maximum packet size but
passes sends to the selected DataChannel. That API value is not evidence of a
path MTU or the negotiated SCTP message limit. See the
[Godot WebRTC sender](https://github.com/godotengine/godot/blob/4.7/modules/webrtc/webrtc_multiplayer_peer.cpp).
WebRTC preserves application-message boundaries using SCTP; large messages can
monopolize an association without message interleaving, and message limits need
negotiation. The RFC's conditional 16 KB guidance is not a universal safe game
packet budget. See [RFC 8831, section 6.6](https://www.rfc-editor.org/rfc/rfc8831.html#section-6.6).

Next bounded experiment: replay representative ordinary/key bursts over actual
ENet and native WebRTC/mux links under controlled impairment; record send errors,
queue growth, input/state age and datagram/fragment evidence. Then choose a
byte-budget experiment that preserves recovery and fairness between routes.
Actual 2/4/8/16-client simulation/rollback load and browser/TURN/device evidence
remain separate required measurements before any supported-capacity claim.

Do not simply split complete pose membership lists: the receiver currently
treats each accepted list as the complete relevant set. Do not remove recovery
copies, omit authoritative properties, or promote packing based on this table
alone. Chunking/reassembly, per-route scheduling and pressure policy require
their own explicit contract and loss/reorder/late-join regressions.

## Reproduce and monitor

```bash
mkdir -p .network-runs/packet-size-local
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/network_payload_telemetry_test.gd
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/network_packet_size_test.gd -- --offline \
  --packet-size-report=.network-runs/packet-size-local/report.json
```

The report has 85 rows including pose modes, both packing states and pressure
control. Run from the worktree with its synced local art. Inspect full output
for engine/script errors, not only PASS/exit status. Both regressions are listed
in `scripts/test.sh`; `check.sh` verifies registration but does not execute them.

Live `--net-telemetry` now appends `payload_max=` and `bundle_max=` to `NETAPP`.
Existing totals and recipient-copy accounting remain intact. A maximum is one
logical payload, not multiplied by recipient count; it resets with the existing
reporting window. The bundle diagnostic array includes a key flag and wrapper
that are not identical to actual RPC arguments. Use these maxima to detect
growth, then this fixture or actual transport capture for the corresponding
layer's size. Disabled telemetry still returns before encoding/accounting.

Accepted fixture evidence: ignored `.network-runs/packet-size-2026-09-04/`
`size.log`, `report.json`, `telemetry.log`, and `check.log`. Both focused tests
and the fast check passed; final focused logs contain no engine/script errors
or warnings. Earlier fixture setup errors were corrected before collecting
this baseline. Live integration results are recorded in the audit follow-up.
