# Sprite AI playground

This opt-in experiment adds Basic, Attacker, Evader, Ambusher and Mixed profiles
to Debug → Sprite test. Start with 16:

```sh
CAR_FIGHT_SPRITE_AI=mixed CAR_FIGHT_SPRITE_SAMPLE=survivor ./scripts/play_monitored.sh --offline --sprite-test
```

Rendered runs still follow the project's approval and safe-window rules. The
ordinary launch and legacy sprite fixture retain their existing defaults.
Modern art is an optional local sample, not a required character/theme change.
An opt-in [batched drawing prototype](SPRITE_BATCH_PROTOTYPE.md) is available
under Drawing (local prototype); original drawing remains the default.

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
  Each hunter has a seeded pace variation of ±12%, a small left/right approach
  preference, and a gentle 3–6-second steering variation. Steering stays within
  about 21 degrees of the route direction and fades near waypoints. It does
  not add idle wandering, change fire cadence or bypass spacing/world sweeps.
  Seeds derive from fixture IDs, so resets reproduce the same personalities.
  Variation is evaluated at the existing server decision cadence, not on clients.
- Evader has a seeded personal reaction distance: about 35% keep the original
  ten-unit trigger, while the others react between fourteen and twenty-two
  units when an observed car is closing at more than 0.5 units/second. Stationary,
  departing and tangential cars do not trigger this early reaction; all retain
  the original close-range response. Once retreating, each keeps a four-unit
  buffer beyond its personal threshold before stopping, avoiding rapid toggles.
  Existing detection/sight rules still govern acquisition, and a projected
  collision within one second overrides personality with a sidestep.
  While retreating, speed
  rises linearly from normal pace at ten units to its existing 1.5× cap at two
  units (3 → 4.5 units/second at default settings), easing off as the gap opens.
  It zig-zags with seeded individual phases and 1.5–3-second cycles, up to about
  37 degrees either side of the route direction. Existing waypoint fading and
  capsule sweeps constrain the turns; weaving never adds speed above the cap.
  A predicted run-over takes priority: full-speed direct sidestep until clear
  of the projected path, then weaving resumes if still evading. It does not
  read bullets or player input to predict intent.
- Ambusher runs at 1.5× speed into the existing grass field, reserves a spaced
  hiding spot, and stays there with a muted green tint at 22% opacity. It remains
  hittable/run-over-able; normal visibility returns on rush, death, profile reset
  or leaving the hiding state. Hit flashes override camouflage. Both original
  and batched drawing reuse the sprite's existing tint; no extra draw pass.
  This is grass camouflage, not building-ray occlusion or invulnerability.
  After one second settled in grass, observing a car approach within eighteen
  units arms the trap. It rushes only once the car is moving away at more than
  one unit/second radially, the sprite is behind its facing (dot < -0.35), and
  the car is still within twenty-four units. Merely turning away, parking or
  reversing past while facing the sprite does not trigger. Moving beyond
  twenty-four units clears the observed approach. Eligible-player changes also
  clear preparation; cloak/editing/RC/map exclusions remain.
  The rush pursues the current player at 1.5×, shoots with clear sight within
  eighteen units and closes to six. After three shots or ten seconds it returns
  to its reserved grass spot and prepares again. There is no exposed Basic fire
  fallback. It retries unavailable slots every two seconds, two candidates per
  job; if the field is full or blocked it waits rather than stacking reservations.
  Buildings now only constrain navigation: no building selection or circling.
  The one existing 42×42 grass field is centered at world (58, 0, 18), east of
  the central intersection. City-wide spawns must actually travel there; some
  take over a minute. No new field, grass density, renderer or spawn change.

Defaults: movement 3 units/second, attack 1.5× and evasion up to 1.5× movement, detection 32 units,
shot interval 1 second, aim delay at least 0.35 seconds. Decisions run at 5 Hz,
so transitions are quantized to that cadence. Bullet speed is 22 units/second,
lifetime two seconds. Show AI decisions displays profile/state labels on clients
and server/offline destination/cover markers for the nearest 16 living
sprites to the camera. Debug facts refresh at 5 Hz; invalid cover markers are
not allocated, and leaving the selection releases nodes. All obey depth occlusion.
Preview animation controls remain presentation-only; real deaths override them.

## Offline population prototype (2026-09-05)

Working target: **64 living sprites**, following the measured 57–63 average FPS
at true 64 in the [count experiment](SPRITE_BATCH_PROTOTYPE.md). Not a locked-60
guarantee; replenishment and corpses still need sustained rendered acceptance.

In offline play, open **Debug → Sprite test → Population (offline)**, directly
below Disable test, and select **Maintain 56–64 (reset)**. This explicitly resets
the fixture to 64 using the currently selected profile, size and movement settings.
Choose Attacker to keep the population hunting. The controller also works with
Basic, Evader, Ambusher, Mixed and legacy movement without retuning those behaviors.
The status at the top reports living sprites, retained corpses, whether it is
refilling, cumulative replacements and blocked candidate attempts (not failures).

- Hold while living count is 56–64. Below 56, refill until 64, at most one birth
  per 0.25 simulation seconds / service call. Large losses may temporarily take
  the count well below the band; no immediate full-wave replacement or queued
  catch-up requests. The existing simulation tick catch-up policy is unchanged.
- Use 64 cached, round-robin street spawn points distributed through the city.
  They are logical positions, not visible/destructible buildings. Try at most
  eight candidates per spawn interval. Reject positions within 12 horizontal
  units of a player, within combined capsule radii + 1.5 units of another living
  sprite, or overlapping actual world bodies using the current capsule. Occupied
  points wait; the controller never forces a spawn into an obstacle. There is no
  off-camera spawning guarantee and camera state never controls simulation.
- Keep corpses for about five simulation seconds, at most 16 after each controller
  pass, removing oldest first under pressure. At most 64 living + 16 retained
  corpses / 80 fixture objects. Cleanup releases per-sprite AI, route, pending,
  spacing, debug and managed-animation references. Queued frees finish at the
  frame boundary; existing practice shots finish normally within their lifetime.
- Replacement IDs increase within the fixture generation. New sprites inherit
  the current profile/size and seeded individual variation; surviving brains,
  routes, shots and generation are not reset by births. Profile/size resets
  preserve the population selection and clear the old population's history.
- Off stops both replacement and corpse cleanup, leaving the current fixture
  for inspection. Disable test clears it; selecting another target count turns
  population control off. Ordinary launch remains unchanged, default off.

Scope/authority: this is an **offline-only lifecycle prototype** of the existing
fixture family. Both the offline role and `OfflineMultiplayerPeer` are required;
the online UI is disabled and the simulation rechecks the gate. No new RPC,
codec, rollback state, transport or deployment change. Dynamic membership is
NOT implemented for network peers; do not enable it online without a separately
approved generation-safe spawn/despawn contract, reconstruction and load gates.

Focused checks: `tests/sprite_population_test.gd` exercises 64-live replenishment,
twelve 20-death waves, bounds, identity, actual obstacle/player/neighbor checks,
profile and size inheritance, UI wiring, stop/reset/retire and offline gating.
It also calls the ordinary lab service, but its accelerated lifecycle loops are
not FPS measurements. Existing AI runtime and sprite fixture/batch tests cover
the shared initialization and individual presentation-release changes; the
offline smoke gate covers ordinary startup/driving. Network tests and rendered
population/FPS acceptance remain deferred, not implicitly passed.

## Network feature contract

Guidance read from the networking worktree's `docs/NETWORK_SAFE_GAMEPLAY.md`,
initially `0e61e16`, then rechecked at `14d103b`. Its shared seven-line
`net/connection_state.gd` prerequisite is reused verbatim, including its UID.
Other networking changes have not been imported into this branch.

- Authority: server peer 1 decides AI, movement, shot creation and collision.
  Only the lab owner may request settings; the server validates and clamps them.
- Representation: lightweight 10 Hz sprite snapshots and reliable shot lifecycle
  events. No new rollback bodies, player inputs, codec fields or transports.
  Motion packets are only constructed when remote peers exist; offline ticks
  still simulate normally and advance the snapshot clock. Late joins retain
  full configuration, and local shot presentation is never skipped.
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
world clearance. Ambushers use a shared static grass-region descriptor, also
used to place the render-only field. At most 100 spaced, grid-aligned slots are
generated once per radius cache, excluding building/capsule overlap; the default
size supports at least 64. Each brain holds one reserved slot ID and one search
cursor. Reservations are released on death/despawn and cleared on reset/retire.
No scene-tree/per-blade scan, per-sprite list, added grass bodies, extra ray to
validate hiding, or replicated cover field. Candidate checking stays at two per
job under the shared four-job/tick limit (at most eight checks/paths per tick).
The fixed region remains available headlessly; simulation never reads grass
animation or rendering. Above field capacity, excess Ambushers wait and retry.
Attackers add server-only soft separation at 5 Hz using spatial
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
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://tests/sprite_cover_test.gd
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://tests/sprite_ai_test.gd
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://tests/sprite_ai_runtime_test.gd -- --offline --no-drone
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://tests/sprite_population_test.gd -- --offline --no-drone
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

### Grass Ambusher verification, 2026-09-05

PASS: fast check, cover/AI decision tests, AI runtime, sprite fixture/batch,
population and ordinary offline smoke. Runtime verifies actual travel to grass,
no parked/alongside trigger, then a passing car causes 4.46 units of movement
and three actual shots. All 64 achieve distinct grass hiding spots within 120
simulated seconds from city-wide spawns. Death/despawn/reset release reservations.
Camouflage tests verify the shared tint input and retained hitbox; the headless
Dummy renderer cannot read back uploaded MultiMesh colors. Actual visual blending
and rendered FPS remain owner acceptance, not inferred from those checks.

The existing `CAR_FIGHT_AI_PROBE_SCENARIO=cover` probe now retains the original
two 30-second phases and adds 30 seconds of repeated 10-unit/second passes through
the actual grass field. Local evidence: `.crash-runs/grass-ambush.bcVXyj/`, final
`runtime-final.log`, `presentation-final.log`, `population.log`, `probe-passes.log`.
No unexpected errors in final logs. The initial runtime compile error was fixed;
its exact stalled process was stopped. Retained failed assertions were corrected
to compare cumulative shots against the phase baseline and avoid unsupported
headless GPU-buffer readback; neither was hidden by a gameplay workaround.

| 64-live phase | Median / P95 / max service CPU |
| --- | --- |
| Travel/preparation, including cold grid | 0.762 / 1.269 / 6.678 ms |
| Original street-square drive | 0.436 / 0.740 / 1.499 ms |
| Repeated grass passes with active ambushes | 1.040 / 1.628 / 2.713 ms |

The earlier grass probe without the added pass phase (`probe.log`) measured
preparation 0.898/2.041/7.186 ms and square driving 0.498/0.914/2.298 ms;
separate-run timing varies, and longer initial travel is not a free improvement.
Final run: 64 candidates total, maximum one checked per job (hard cap two),
maximum four jobs/tick, 695 shots and peak 52 active. As in the matched probe,
diagnostic health restoration outside the timer keeps every tick at 64 living.
The grass-pass phase restored 2,290 repeated contact deaths; that is sustained
synthetic load, not normal gameplay survival or population-controller evidence.
No grass blades/bodies/draw passes were added. Thermal equality is unestablished;
these are sprite-service timings, not whole-frame, GPU or network capacity.
Network gates remain deferred: no authority, RPC schema or transport change.

### Superseded building-Ambusher CPU check, 2026-09-05

Historical evidence for the building version rejected by the owner; grass
camouflage now replaces this behavior and its object-tracking tests.

Run the existing probe with `CAR_FIGHT_AI_PROBE_SCENARIO=cover` and the offline
arguments above. Matched 64-live workload: 1,800 preparation ticks with a parked
car, then 1,800 ticks driving a 252-unit street square at 10 units/second.
Every measured tick starts with 64 living sprites: diagnostic-only health
restoration happens outside the timer after contact deaths. Normal gameplay
still allows run-overs. This measures the complete sprite service (AI, movement,
contacts and shots), not rendering, the complete frame, or FPS.

| Phase | Before median / P95 / max | Final median / P95 / max |
| --- | --- | --- |
| Preparation, including cold grid | 0.606 / 1.457 / 5.388 ms | 0.718 / 1.312 / 5.985 ms |
| Moving car | 0.640 / 1.158 / 2.266 ms | 0.756 / 1.279 / 2.670 ms |

Baseline gameplay: `6b992fb`. Local raw logs:
`.crash-runs/ambush-cover.W6rUWm/before-live64.log` and
`after-final-live64.log`. The earlier `before.log` fell to 63 and is superseded.
The baseline needed 23 diagnostic death restorations; the new run needed none.
Final work: 213 cover retargets, 277 candidates checked, maximum one candidate
actually used per job (hard limit two), maximum four jobs/tick, and 136 shots
versus zero before. Thus this is the cost of the changed behavior, not an
isolated object-lookup microbenchmark. The first after run (`after-live64.log`,
before the brief-exposure preparation fix) measured moving median/P95/max
0.843/1.527/2.536 ms and preparation 0.764/1.444/7.314 ms. Across those two
after runs moving P95 added 0.121–0.369 ms; scheduling variation matters.
Thermal state was unavailable, not established as equal. No budget is relaxed,
and these results do not prove sustained 60 FPS or network capacity.

Focused regression evidence: pure cover geometry/identity and opportunity
decisions; physical movement to the opposite side of the same building at four
vehicle stations without firing; then a turned-away car produces a 32.22-unit
peak excursion and two actual shots. All 64 sprites in the stationary runtime
cohort achieved real concealment within 40 simulated seconds. The fast check,
AI decision/runtime, cover and population tests cover this localized change;
no scene wiring, network schema or transport changes require broader gates.
Continuous rendered circling, feel and sustained FPS still need owner acceptance.

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
