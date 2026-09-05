# Sprite AI playground

This opt-in experiment adds Basic, Attacker, Evader, Ambusher and Mixed profiles
to Debug → Sprite test. Start with 16:

```sh
CAR_FIGHT_SPRITE_AI=mixed CAR_FIGHT_SPRITE_SAMPLE=survivor ./scripts/play_monitored.sh --offline --sprite-test
```

Rendered runs still follow the project's approval and safe-window rules. The
ordinary launch and legacy sprite fixture retain their existing defaults.
Modern art is an optional local sample, not a required character/theme change.

## Controls and behavior

Select a profile, speed, detection distance or shot interval in the existing
Sprite test window. These owner-controlled changes reset the fixture. Mixed
assigns the four profiles evenly. Car auto-fire starts off in AI mode and can
be restored in the same window; disabling the lab restores ordinary auto-fire.
Existing three-hit and run-over deaths remain. AI bullets provide hit flashes
and counters only: no damage, resources, impulses, shield or det interactions.

- Basic wanders within eight units of home and shoots a visible car within 24.
- Attacker relentlessly hunts an eligible player across the map at 1.5× speed,
  tracking their current position even behind buildings (not just last sight).
  It ignores the detection slider, keeps its target while eligible, and never
  times out or retreats. It fires with clear sight inside 18 units while closing
  to six units, then holds until the player moves away. Cloaked, editing, RC and
  other-map players remain excluded; without an eligible player it waits.
  Hunters use soft neighbor separation to stay loosely grouped rather than
  stacking: preferred center spacing is 2.5 units, increased when the actual
  capsule diameter plus 1.5 units requires it. Separation also works while
  holding firing distance; narrow passages can temporarily compress the group.
- Evader retreats inside ten units, resumes firing outside fourteen, and
  sidesteps a projected collision within one second. It does not read bullets
  or player input to predict intent.
- Ambusher searches nearby building corners for reachable cover and a firing
  position. It waits hidden for at least one second, steps out when its tracked
  car approaches within eighteen units, fires three shots, and returns to cover.
  If no cover is reachable it temporarily behaves like Basic and retries.

Defaults: movement 3 units/second, attack/evasion 1.5× movement, detection 32 units,
shot interval 1 second, aim delay at least 0.35 seconds. Decisions run at 5 Hz,
so transitions are quantized to that cadence. Bullet speed is 22 units/second,
lifetime two seconds. Show AI decisions displays profile/state labels on clients
and server/offline destination/cover/peek markers. All obey depth occlusion.
Preview animation controls remain presentation-only; real deaths override them.

## Network feature contract

Guidance read from the networking worktree's `docs/NETWORK_SAFE_GAMEPLAY.md`,
initially `0e61e16`, then rechecked at `14d103b`. Its shared seven-line
`net/connection_state.gd` prerequisite is reused verbatim, including its UID.
Other networking changes have not been imported into this branch.

- Authority: server peer 1 decides AI, movement, shot creation and collision.
  Only the lab owner may request settings; the server validates and clamps them.
- Representation: lightweight 10 Hz sprite snapshots and reliable shot lifecycle
  events. No new rollback bodies, player inputs, codec fields or transports.
  Existing five-field snapshots remain in legacy mode. AI adds behavior/profile,
  shot serial and moving state. Matching builds are required for this opt-in lab.
- Replay: simulation runs in the existing authoritative tick service, outside
  rollback. Seed-derived wandering and stable car-ID tie breaks make decisions
  reproducible for supplied inputs. Cosmetic smoothing/animation never feed it.
  Generation and shot-ID deduplication prevent old events reviving ended shots.
- Lifecycle: disconnected clients retire fixtures and pending state. New owners
  are the lowest remaining peer ID; an empty server disables the lab until a new
  player arrives. Late joining reconstructs complete configuration before use,
  then settings and active shots. Motion uses per-target monotonic ticks.
  Reset/disable clears routes, pending jobs, shots and their presentation.
- Configuration is reliable and commits only after all indexed parts arrive.
  Motion batches are independent updates to known membership, not fragments
  that erase objects absent from an individual packet. Application payloads
  reserve framing space and stay within 1,000 serialized bytes.

The other session owns sprite sizing. Navigation and clearance use current
capsule dimensions; world-height, pixel registration, defaults and size controls
are not modified by this feature. Navigation grids cache only the current radius.

## Work and traffic bounds

Validate 16, 64 and 256 sprites with one server/two clients. More peers are not
an established capacity claim. Perception is staggered at 5 Hz; route jobs run
at most twice/second per sprite and at most four per service tick. Pending jobs
hold only the latest request per sprite, and waiting sprites stop safely.
Routing uses a two-unit grid inflated for capsule and cell-corner clearance;
initial grid preparation is limited to 512 cells per tick, with routing held
until complete. It is not a synchronous full-grid build on the first AI tick.
Physics sweeps retain final authority. Cover/peek positions also require actual
world clearance. Attackers add server-only soft separation at 5 Hz using spatial
cells, capped at 16 representatives per cell and nine cells per hunter query.
Cached steering clears on reset and ignores dead/non-attacker sprites. The
combined steering uses existing capsule sweeps and the same speed cap; no rigid
sprite-to-sprite collision, additional RPC fields or rollback state is added.

Active shots are capped at `count * (ceil(2 / shot_interval) + 1)`; full capacity
defers firing without accumulating requests. Event batches flush each service
tick and motion is generated fresh at publication time, with no application
snapshot backlog. These are application bounds, not a claim that opaque ENet
reliable queues have been measured or newly bounded. Existing transport behavior
is unchanged; congestion and additional-peer capacity remain separate evidence.

Counters extend the existing NetworkPerformance application-message categories
(`sprite_motion`, `sprite_configuration`, `sprite_ai_events`). The lab additionally
records decision CPU, route jobs, pending maximum, active-shot peak and payload
maximum. Byte counters multiply by recipients but are serialized application
bytes, not encrypted transport bytes. Decision CPU excludes movement/contact and
bullet sweeps; the headless service probe includes those costs.

## Verification

```sh
./scripts/check.sh
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://tests/sprite_ai_test.gd
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://tests/sprite_ai_runtime_test.gd -- --offline --no-drone
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://scripts/sprite_ai_probe.gd -- --offline --no-drone
./scripts/sprite_ai_network_test.sh enet
./scripts/sprite_ai_network_test.sh mux
```

The AI network gate captures feature-off/on CPU/application traffic at all three
counts, denies non-owner requests, transfers ownership and reconnects an observer
within the same engine process by rebuilding its session scene. That is not an
in-place UI reconnect or a browser/background-resume test. It scans every process
log for engine/script errors and retains logs on both success and failure.

Also run existing sprite, offline/combat gates and the complete suite once before
merge because the fixture RPC contract changes. Input registration is unchanged;
if integration changes it, run the real input-schema regression from the
networking branch explicitly. The fast gate alone does not execute it.

Evidence and remaining acceptance are recorded in `.ai/CURRENT_PHASE.md`.
No production deployment or rendered acceptance is implied by headless results.

### Headless service evidence, 2026-09-04

Same process/hardware and stationary car at city origin; 120 warmup ticks then
600 measured service calls at 1/60 second. This measures the sprite service,
including AI, movement/contact, bullet sweeps and snapshot generation. It does
not measure complete frame/rollback time, rendered FPS or real-time scheduling.

| Sprites | Legacy median / P95 | Mixed AI median / P95 | AI warmup maximum |
| --- | --- | --- | --- |
| 16 | 0.147 / 0.240 ms | 0.238 / 0.390 ms | 4.597 ms |
| 64 | 0.556 / 0.856 ms | 0.807 / 1.265 ms | 1.700 ms |
| 256 | 2.336 / 3.562 ms | 2.908 / 4.567 ms | 6.005 ms |

The first 16-AI sample includes the cold grid; later counts reuse that radius.
Raw evidence: `.network-runs/sprite-ai/final-probe.log`. Original pre-integration
baseline: `baseline.log` in that directory (0.121/0.196, 0.487/0.816 and
1.967/2.837 ms respectively). The first baseline was sandboxed and emitted a
macOS system-certificate access error; the final unrestricted probe is clean.
Differences between separate runs include scheduling/load variation.

For this device/scenario, retain an incremental P95 budget of 2 ms over the
matched 256-sprite legacy service, and an 8 ms service warmup ceiling. The measured
increment is 1.005 ms and warmup maximum 6.005 ms. These provisional local limits
leave headroom within a 16.67 ms tick; they do not establish a budget for the
rest of the frame or additional peers. Existing correction limits remain intact.

### Aggressive attacker tuning, 2026-09-04

Follow-up rendered slowdown diagnosis:
[256-attacker profile](SPRITE_ATTACKER_PROFILE.md). It measures the full-frame
simulation/presentation interaction and the optional debug display's ~7-FPS case;
the headless service numbers below are not rendered capacity evidence.

Run the same probe with `CAR_FIGHT_AI_PROBE_MODE=attacker` for all hunters.
Evidence: `.network-runs/sprite-ai/attacker/probe.log`. Matched legacy/attacker
P95 service times were 0.412/0.659 ms (16), 1.720/2.537 ms (64), and
5.918/8.529 ms (256). The 256 increment of 2.611 ms and attacker warmup maximum
11.879 ms exceed the provisional limits above. This is an unresolved high-count
performance limitation, not an accepted 256-hunter capacity claim. Interactive
tuning stays at 16; optimize/revalidate high-count pursuit before accepting it.
Brain/runtime regressions cover persistent moving hidden targets, actual routes
around a building, fire while approaching, no close retreat and cloak exclusion.

Final soft-spacing probe (`attacker/spacing-probe-final.log` in the same log root):
matched legacy/attacker P95 was 0.355/0.734 ms at 16, 1.327/3.105 ms at 64,
and 5.477/8.910 ms at 256. Maximum attacker warmup was 10.829 ms. The existing
256-hunter performance limitation remains; no budget was relaxed. Runtime tests
also cover close-pair separation, exact overlaps, firing-position spacing,
dead-neighbor exclusion, reset, and a stacked 16-hunter pack spreading over time.

### Network evidence and remaining gates

Final ENet gate: `car-fight-sprite-ai-network.qGn0KI`; mux gate (one native ENet,
one native WebRTC extension client): `car-fight-sprite-ai-network.S3cO62`.
All server/owner/observer logs are clean. They are copied under the local ignored
`.network-runs/sprite-ai/enet-gate/` and `mux-gate/` directories. Both paths stayed
within 904 serialized bytes and four route jobs per tick. NETAPP was enabled;
the observed mux owner correction maximum was 0.015 units in this stationary-car
scenario. This is not a moving, impaired-network AI acceptance test.

Final ENet application traffic, summed across both recipients over a two-second
sample after 0.5 seconds of settling at each setting:

| Sprites | Legacy bytes | Mixed AI bytes |
| --- | --- | --- |
| 16 | 39,168 | 71,408 |
| 64 | 154,360 | 268,064 |
| 256 | 615,128 | 1,053,440 |

This increase is measured cost, not free replication. It includes extended AI
motion state and shots. Queue-age/rollback counters remain in NETAPP logs;
feature-specific state-age percentiles, encrypted transport bytes and ENet queue
occupancy are unavailable. No claim is made about higher recipient counts,
congested links, a real browser, background/resume, or TURN.

Fast check, focused AI/size-clearance/state/shot tests, existing sprite contracts,
live sprite combat and targeting regressions pass. The full suite was attempted,
then its unrun tail continued after failures were classified/fixed. Do not treat
the tail's `ALL_TESTS PASS` marker as a clean full-suite result:

- `vehicle_size_respawn_test.gd` expects old `Show Collision Capsule` menu text.
  Its failure reproduces on canonical master and is outside this sprite sizing
  boundary. The runtime vehicle-size and mass outcome harnesses report PASS.
- General ENet, mass, ball, tractor, reverse, combat, RC, shield and det harnesses
  report passing outcomes but retain inactive-peer errors after server shutdown
  in unchanged Main/dots/oil callbacks. The networking worktree's `14d103b`
  addresses those connection guards; only its reusable helper is included here.
  No broad error allowlist or relaxed threshold was added. The regular latency
  test measured 0.990 units and mixed transport 0.300, but shutdown errors preclude
  calling the former a clean run.
- The state-codec self-test intentionally emits a decoder error for its truncated
  payload rejection case. Feature-introduced preload/autoload and absent-lab
  test-harness issues were fixed and their focused tests rerun successfully.

Before merge, combine the separately owned fixes, check sizing compatibility,
and rerun affected gates. The owner has approved monitored 16-sprite interactive
tuning; behavior acceptance remains with the owner. No deployment has occurred.
