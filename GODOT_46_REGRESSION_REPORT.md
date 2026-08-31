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
| Godot 4.6.3 clean import/parse | Pending | |
| Focused tests and complete `scripts/test.sh` | Pending | |
| Native ENet profile matrix | Pending | |
| Web offline release build/smoke | Pending | |
| Browser/native WebRTC smoke | Pending | |
| Accepted WebRTC lifecycle/impairment gates | Pending | |
| Clean Git diff and active-version audit | Pending | |

The reconnect scanner remains strict for all runtime errors. It separately
counts only Godot 4.6's exact shutdown-only
`ERROR: 1 resources still in use at exit` warning after every process exits
successfully and the topology/replacement assertions pass.

## Human Mac/Web acceptance

Each row must record the tested commit, duration, result, and evidence path.
Use only ordinary decorated windows on the affected Intel Mac.

| Scenario | Required observations | Result/evidence |
| --- | --- | --- |
| Native Mac offline | Mouse and DualSense handling; boost, reverse, drift, collisions, ball, tractor, weapons, defenses, vehicles, arena/city transitions, and scenery choices | Pending |
| Native Forward+ stability | Vulkan Forward+, Rapier 0.8.35, shader warm-up followed by stable frame pacing, and no thermal/GPU/display fault during a 10-minute drive | Pending |
| Two native ENet clients | Isolated candidate server; reciprocal movement/collision/weapons, late join, leave/rejoin, reconnect, clean link, and 120 ms impairment | Pending |
| Native Mac + Chrome WebRTC | Same authoritative candidate world; drive and observe in both directions, collide/fire, refresh/rejoin browser while native survives | Pending |
| Impaired Mac + Web | Accepted forced-TURN 120 ms path in both observation directions plus a 5–10 minute soak; bounded correction/queues and clean recovery | Pending |

## Promotion rule

Only after all automated and human rows pass may `master` move to this exact
tested candidate. Production macai2 is updated afterward through the normal
deployment helper and receives a final connection/reconnect smoke. Keep the
safety tag and experiment worktrees until that production smoke is accepted.
Do not add or tune further lighting effects during this migration.
