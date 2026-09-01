# Godot 4.6.3 + Rapier 0.8.35 regression report

Status: integration candidate; do not promote to `master` yet.

## Candidate identity and preservation

- Integration branch: `integration/godot-46-rapier-0835`
- Initial merge commit: `a46f36d`
- Engine: `4.6.3.stable.official.7d41c59c4`
- Rapier: official `0.8.35`, 3D enhanced determinism, Godot API 4.6
- Rapier archive SHA-256:
  `f6477144bccf8002c71647193444bd540ed648204d84e6e69919f4affafbf414`
- Preserved canonical head: `2c8a710`, pushed tag
  `pre-godot-46-2026-08-31`
- Production `master` and macai2 deployment remain unchanged until every
  required row below passes.

## Automated acceptance

| Gate | Result | Evidence |
| --- | --- | --- |
| Godot 4.6.3 clean import/parse | Pass | Clean second import; no parse, compile, script-load, or autoload errors |
| Focused tests and complete `scripts/test.sh` | In progress | First suite passed through tractor, then hit the documented timing-sensitive course sample; isolated course and every downstream gate passed |
| Native ENet profile matrix | Pass | All seven profiles passed; worst correction stayed below 1 unit in the retained complete matrix |
| Web offline release build/smoke | Pass | `build/web-smoke-report.json`: Rapier 0.8.35, 60 FPS steady, 17.99 speed, zero browser errors |
| Browser/native WebRTC smoke | Needs human performance pass | Lifecycle, replacement, movement, queues, and errors pass; short steady FPS varied from 35.2 to 51.2 against the unchanged 45 average floor |
| Accepted WebRTC lifecycle/impairment gates | A/B performance open | Harness lifecycle passes. Candidate 120 ms TURN transport was healthy but measured 21.2 FPS; immediate preserved-4.7 control also failed at 18.6 FPS under the same machine load |
| Clean Git diff and active-version audit | Pending | |

The reconnect scanner remains strict for all runtime errors. It separately
counts only Godot 4.6's exact shutdown-only
`ERROR: 1 resources still in use at exit` warning after every process exits
successfully and the topology/replacement assertions pass.

Godot 4.6 headless startup required a longer observation window for the clean
native authority-probe assertion. The native harness now runs 600 server / 720
client ticks while retaining every existing correction, topology, traffic,
loss, and error threshold. The Web refresh scanner now counts only Godot's
actual `WARNING:` emission rather than also counting netfox's textual copy.

## Human Mac/Web acceptance

Each row must record the tested commit, duration, result, and evidence path.
Use only ordinary decorated windows on the affected Intel Mac.

| Scenario | Required observations | Result/evidence |
| --- | --- | --- |
| Native Mac offline | Mouse and DualSense handling; boost, reverse, drift, collisions, ball, tractor, weapons, defenses, vehicles, arena/city transitions, and scenery choices | Pass at `7463b5f`; human accepted macOS gameplay. Monitored run `.crash-runs/20260831-183253` exited cleanly after about 2 minutes with Vulkan Forward+, Rapier 0.8.35, roughly 145 FPS while idle in the city, and no GPU/display fault. |
| Native Forward+ stability | Vulkan Forward+, Rapier 0.8.35, shader warm-up followed by stable frame pacing, and no thermal/GPU/display fault during a 10-minute drive | Partial/open. Remote-network attempt `.network-runs/20260831T234408Z-79596-113-webrtc-clean` hit an Intel Metal/Vulkan `VK_TIMEOUT` before ENet readiness. After reboot, native remote run `.crash-runs/networking1-enet-clean-fixed-20260831-200950` played normally and the user accepted it, but the explicit 10-minute stability duration remains outstanding. |
| Two native ENet clients | Isolated candidate server; reciprocal movement/collision/weapons, late join, leave/rejoin, reconnect, clean link, and 120 ms impairment | Partial pass. Human two-client city review exposed that `remote_position_transport.gd` accepted only Arena and Driving Course recipient maps, so every LOW POLY CITY batch was rejected as malformed and the other Jeep was hidden. The candidate now delegates to the bounded shared map validator through `CITY_AUDITION`; focused transport/city tests plus clean G2 ENet, mixed ENet/WebRTC, and gate harnesses pass. Human rerun `.crash-runs/two-client-20260831-205007` confirmed reciprocal city visibility. Both clients recorded `map=2`, two active same-map remotes, advancing peer positions, and `malformed=0`. Remaining collision/weapons and impaired native observations still apply before promotion. |
| Native Mac + Chrome WebRTC | Same authoritative candidate world; drive and observe in both directions, collide/fire, refresh/rejoin browser while native survives | Partial pass. Local dual-window run `.crash-runs/web-network-local-20260831-184026` was load-bound, and the preserved-4.7 control was no better. Clean remote forced-TURN rerun `.network-runs/20260901T011620Z-3847-25842-webrtc-clean` played normally; the user accepted it and browser leave/rejoin succeeded. Complete combat observations remain outstanding. |
| Impaired Mac + Web | Accepted forced-TURN 120 ms path in both observation directions plus a 5–10 minute soak; bounded correction/queues and clean recovery | Partial pass. After one failed negotiation, retry `.network-runs/20260901T012817Z-9316-676-webrtc-latency120` connected and was accepted as playable by the user. Native ran about 48--57 FPS with 0.30-unit correction; Chrome ran about 18--25 FPS with 0.89-unit correction and open channels. The full-duration, both-direction soak remains outstanding. |

## Promotion rule

Only after all automated and human rows pass may `master` move to this exact
tested candidate. Production macai2 is updated afterward through the normal
deployment helper and receives a final connection/reconnect smoke. Keep the
safety tag and experiment worktrees until that production smoke is accepted.
Do not add or tune further lighting effects during this migration.
