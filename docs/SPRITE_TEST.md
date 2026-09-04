# Interactive sprite test

Run from the canonical Car Fight checkout:

```sh
./scripts/play_monitored.sh --offline --sprite-test
```

For a local dedicated server and client:

```sh
./scripts/play_monitored.sh --local --sprite-test
```

Use **Debug → Sprite test…** to reset near your car, disable the fixture,
select 1/16/64/128/256 targets, change physical scale, or switch stationary/mixed
walking. The first player on an opted-in server owns fixture controls. Other
clients can inspect local presentation but cannot change server state. A server
must start with `--sprite-test` to accept client configuration requests.
Offline play can also enable the test from the menu without the flag.

For the larger spread-out test:

```sh
CAR_FIGHT_SPRITE_COUNT=256 ./scripts/play_monitored.sh --offline --sprite-test
```

Fixtures now occupy two lanes along the city's six main streets, spreading
outward from the observer. Starting positions stay at least four units apart,
outside building footprints and six units from the car. Walking phases are
staggered. The 128px default remains; the menu can reduce the count live.

The test stays disabled on ordinary startup. It does not deploy or modify the
macai2 service. Current native clients must use the same code revision for
the optional sprite fixture's RPC endpoints.

## Behavior

- The supplied ghoul is sample sprite art. No enemy AI or attacks are added.
- All four clips have eight directions. Camera-relative facing works in
  orthographic and perspective views; manual facing is available for inspection.
- The 128px default and 512px comparison share world scale and source-frame
  registration. Clips load on demand and share atlases across instances.
- Invisible upright capsules supply fixed hitboxes. Existing player bolts,
  homing missiles, area strikes, and burns can hit live targets. Walls block
  shots and sprite-target area damage. Three damage applications kill a target.
- A server-confirmed vehicle capsule contact kills immediately. Swept capsule
  checks include translation, rotation, vehicle size, and target movement.
  Targets do not push, slow, or otherwise apply forces to vehicles.
- Death stops movement and removes hit/target eligibility immediately, then
  plays once and holds. Reset recreates healthy targets; duplicate or stale
  hit events cannot resurrect them.
- Animation previews, pause, rate, resolution and facing are local. Previewing
  death does not change health; replay never revives a genuinely dead target.
- Static fixtures are seeded by a reliable configuration snapshot. Moving
  fixtures use 10 Hz lightweight updates in batches of at most 16, avoiding
  oversized unreliable packets at the 64-target gate. Clients smooth movement;
  hit/death events
  are reliable and fenced by fixture generation. Late joiners get current state.
- Tool-window focus neutralizes vehicle controls through the existing policy.

Asset provenance, frame packing and the source license are documented in
`assets/sprites/ghoul/README.md`. The archive supplies 170 idle, 25 walk,
70 attack and 69 death frames per direction and no timing metadata; the test
starts at 12 FPS with an adjustable playback multiplier.

## Validation, 2026-09-04

Focused gates:

```sh
./scripts/check.sh
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/sprite_test_lab_test.gd
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/sprite_combat_test.gd -- --offline --no-drone
./scripts/offline_test.sh
./scripts/combat_test.sh
./scripts/sprite_network_test.sh
```

Coverage includes directional mapping, complete asset manifests, capsule sweeps,
scaled vehicle contact, three-hit death, wall obstruction, projectile consumption,
area damage, reset/disable, no car impulse, generation fencing, replicated hit
and death, 256-target late joining, and rejection of non-owner configuration.
The network gate also rejects unreliable-packet MTU warnings.
The existing combat gate covers ordinary targeting, editor suppression and cloak.
These are localized presentation and target-family changes; player rollback,
state schemas, input ownership and transports are unchanged. The full milestone
suite is not required for this isolated fixture.

Monitored runs `20260904-145702` and `20260904-150019` both exited cleanly, with
no script errors or display precursors. Captures and measurements are under
`.crash-runs/sprite-visual-1788551836/` and
`.crash-runs/sprite-visual-1788552032/`. Inspected normal-distance and close-up
sprites, all four clips, completed death, perspective rendering and the native
controls. The owner subsequently accepted the sprite test after single-client
runs `20260904-160642` and `20260904-161030`, both of which exited cleanly.

Owner visual feedback: the sprites look okay as a proof of concept; more
directional views and a higher animation frame rate could make them look good.
Follow-up evaluation should focus on those two improvements. This is feedback
on the current eight-direction, 12 FPS presentation, not a request to change
the character theme or a claim that those improvements have been implemented.

Historical compact-layout, fixed-camera, five-second warmed samples on this Intel Mac, with the car frozen
and unrelated automatic combat suppressed:

For the newer spread-out 256-fixture investigation, see
[the CPU profile](SPRITE_PROFILE.md): automatic target acquisition dominated
the slowdown; this is not an established sprite-rendering capacity limit.

| Targets | Resolution | Median frame ms | P95 frame ms | Extra texture memory |
| --- | --- | --- | --- | --- |
| 0 | baseline | 16.25 | 18.95 | — |
| 1 | 128 | 16.24 | 18.98 | 0.33 MiB |
| 16 | 128 | 16.68 | 18.82 | 11.00 MiB |
| 64 | 128 | 18.16 | 22.28 | 11.00 MiB |
| 1 | 512 | 16.42 | 19.07 | 5.33 MiB |
| 16 | 512 | 16.84 | 20.47 | 90.67 MiB |
| 64 | 512 | 18.60 | 30.22 | 90.67 MiB |

Keep 128px as the default. These measurements predate the spread-out street
layout and 256-target option. The measured 64-target layout extends beyond the viewport;
these are whole-fixture costs at this camera position, not an all-visible crowd
capacity claim. Both runs had an approximately 6.9-second initial rendering
stall before sampling; these results do not characterize cold-start or network
rendering latency. Clip/resolution changes can load new resources synchronously.

Reproduce the bounded visual capture through the required safe-window monitor:

```sh
CAR_FIGHT_SPRITE_VISUAL_CHECK=1 ./scripts/play_monitored.sh --offline --sprite-test
# Close-up animations and controls only:
CAR_FIGHT_SPRITE_VISUAL_CHECK=close ./scripts/play_monitored.sh --offline --sprite-test
```

The capture helper affects only its explicitly requested offline session and
exits automatically. It does not save camera or sprite settings.
