# Godot 4.6.3 + Rapier 0.8.35 regression report

Status: accepted and promoted to `master`; production macai2 smoke passed.

## Candidate identity and preservation

- Integration branch: `integration/godot-46-rapier-0835`
- Initial merge commit: `a46f36d`
- Engine: `4.6.3.stable.official.7d41c59c4`
- Rapier: official `0.8.35`, 3D enhanced determinism, Godot API 4.6
- Rapier archive SHA-256:
  `f6477144bccf8002c71647193444bd540ed648204d84e6e69919f4affafbf414`
- Preserved canonical head: `2c8a710`, pushed tag
  `pre-godot-46-2026-08-31`
- `master` was fast-forwarded to tested candidate `e1923ab` and pushed after
  every required row below passed. Production macai2 was then deployed through
  `scripts/deploy_macai2.sh` and verified on Godot 4.6.3 + Rapier 0.8.35.

## Automated acceptance

| Gate | Result | Evidence |
| --- | --- | --- |
| Godot 4.6.3 clean import/parse | Pass | Clean second import; no parse, compile, script-load, or autoload errors |
| Focused tests and complete `scripts/test.sh` | Pass | Final permission-correct run completed with `ALL_TESTS PASS`, including reconnect, mixed transport, join transient, combat, shield, drone/det, course, and every focused test |
| Native ENet profile matrix | Pass | All seven profiles passed; worst correction stayed below 1 unit in the retained complete matrix |
| Web offline release build/smoke | Pass | `build/web-smoke-report.json`: Rapier 0.8.35, 60 FPS steady, 17.99 speed, zero browser errors |
| Browser/native WebRTC smoke | Pass | Automated lifecycle, replacement, movement, queues, and error checks pass. Human simultaneous remote play/rejoin passed, and separated full-scene browser/native combat runs each averaged about 59 FPS |
| Accepted WebRTC lifecycle/impairment gates | Pass | Harness lifecycle passes. Human 120 ms forced-TURN play passed in both observation directions; the separated rendered soak passed 6.5 minutes plus refresh/rejoin with bounded queues and zero recovery |
| Clean Git diff and active-version audit | Pass | Final `git diff --check` passed; active binary is Godot `4.6.3.stable.official.7d41c59c4`, project features are `4.6` / Forward Plus, and the loaded enhanced-determinism Rapier bundle reports `0.8.35` with Godot compatibility minimum 4.6 |

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
| Native Forward+ stability | Vulkan Forward+, Rapier 0.8.35, shader warm-up followed by stable frame pacing, and no thermal/GPU/display fault during a 10-minute drive | Pass at `7194739`. After the earlier pre-reboot remote `VK_TIMEOUT`, monitored offline run `.crash-runs/20260831-215500` completed 27 minutes in an ordinary 1280x720 Vulkan Forward+ window. Its 1,600 one-second samples averaged 59.73 FPS (34 minimum), with three isolated slow frames, a clean user-requested exit, no recovery, no crash report, and no Vulkan device-loss, GPU-reset, watchdog, thermal, or display fault. Godot reported 4.6.3 and Rapier 0.8.35. The user completed the drive and reported no visual stability problem. |
| Two native ENet clients | Isolated candidate server; reciprocal movement/collision/weapons, late join, leave/rejoin, reconnect, clean link, and 120 ms impairment | Pass. City review first exposed and then verified the fixed map-validation bug in `.crash-runs/two-client-20260831-205007`. Clean two-human-client run `.crash-runs/two-client-20260831-210742` passed reciprocal movement, collision, special weapons, leave, and rejoin through `.crash-runs/rejoin-20260831-212100`. The 120 ms one-way run `.crash-runs/two-client-20260831-211639` passed with the expected mild constant remote cadence but no sharp pullback; ordinary moving corrections were about 0.30 units and stayed below the existing 2-unit ceiling. The user accepted all behavior; client scans found no script, rollback-history, Vulkan, or device-loss errors. |
| Native Mac + Chrome WebRTC | Same authoritative candidate world; drive and observe in both directions, collide/fire, refresh/rejoin browser while native survives | Pass with separated full-scene combat evidence. Lean simultaneous remote run `.network-runs/20260901T011620Z-3847-25842-webrtc-clean` passed reciprocal Mac/Chrome play and browser refresh/rejoin while native survived; the user accepted movement and special-weapon behavior. Full-Arena simultaneous run `.network-runs/20260901T034206Z-69849-12227-webrtc-clean` connected the correct isolated macai2 Godot 4.6.3/Rapier 0.8.35 server with exactly two peers, but was rejected when two full local renderers drove native to about 15 FPS. This is the same local dual-render load class reproduced by the preserved-4.7 control, not a transport result. Full authoritative attacking-drone behavior then passed separately on each rendered platform: browser `.network-runs/20260901T034649Z-70505-5429-webrtc-clean` averaged 59.08 FPS over 99 HUD samples with zero recoveries; native `.crash-runs/networking1-enet-clean-proxy-20260831-225014` averaged 59.41 FPS over 181 samples and exited cleanly. On both platforms the user accepted unshielded hit/jostle, shield ripple/reduced shove, shield/cloak exclusion, and cloak stopping targeting. |
| Impaired Mac + Web | Accepted forced-TURN 120 ms path in both observation directions plus a 5–10 minute soak; bounded correction/queues and clean recovery | Pass with separated sustained-render evidence. Mixed run `.network-runs/20260901T012817Z-9316-676-webrtc-latency120` was human-accepted in both clients with open channels and bounded corrections. A same-machine dual-render soak `.network-runs/20260901T022018Z-42079-14213-webrtc-latency120` was rejected when both local renderers fell near 15 FPS; this matches the preserved-4.7 local-load control and is not counted as soak evidence. Corrected browser-rendered run `.network-runs/20260901T023352Z-47692-32167-webrtc-latency120` then passed about 6.5 minutes of driving plus refresh/rejoin: 43.62 average / 24.79 minimum FPS, zero recoveries, 3,896-byte maximum browser channel queue, and 110,724 shaped TURN packets with zero loss. The user reported normal driving after rejoin. |

## Promotion rule

Only after all automated and human rows pass may `master` move to this exact
tested candidate. Production macai2 is updated afterward through the normal
deployment helper and receives a final connection/reconnect smoke. Keep the
safety tag and experiment worktrees until that production smoke is accepted.
Do not add or tune further lighting effects during this migration.

Completed: `master` and `origin/master` were fast-forwarded from preserved
`2c8a710` to `e1923ab`. The production launchd service restarted successfully
as PID 77154 on UDP 10080 / TCP 10181. Smoke evidence
`/private/tmp/car-fight-production-smoke.3vu3BK` kept one survivor connected
while peer IDs `1057280035` and `1264133311` joined and left in sequence; the
survivor observed both, all clients exited cleanly, the server drained to zero
players, and the post-smoke error scan was clean. The rollback tag
`pre-godot-46-2026-08-31` remains preserved.
