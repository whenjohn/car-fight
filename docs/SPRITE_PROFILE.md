# Spread-out sprite CPU profile — 2026-09-04

The 256-fixture slowdown is dominated by automatic target acquisition, not
sprite animation script updates. This is a combined offline server/client
bottleneck, not evidence that 256 sprites exceed the renderer's capacity.
No optimization was applied; temporary timing instrumentation was removed.

## Measurements

Godot 4.7.1, Rapier 0.8.39, Compatibility renderer on the development Intel
Mac; master `bebd534`. Fixed camera and frozen car, 128px sprites, mixed walking
fixtures spread across streets. Each phase warmed for three seconds and sampled
for eight seconds. Frames were measured through `RenderingServer.frame_post_draw`;
direct microsecond timers measured script scopes. Both monitored runs exited cleanly.

Focused matched comparison (256 live fixtures in both phases):

| Measurement | Combat enabled | Combat disabled |
| --- | ---: | ---: |
| Median rendered frame | 148.97 ms | 16.38 ms |
| P95 rendered frame | 164.68 ms | 18.81 ms |
| Combat CPU / rendered frame | 112.09 ms | 0 |
| Target acquisition CPU / rendered frame | 109.36 ms | 0 |
| Sprite animation script CPU / rendered frame | 0.70 ms | 0.66 ms |
| Fixture simulation CPU / simulation tick | 2.58 ms | 2.99 ms |
| Reported texture memory | 98,979,908 bytes | 98,979,908 bytes |

Acquisition consumed approximately 98% of the timed combat scope. Within
acquisition, line-of-sight preparation/checking consumed 68.80 ms per rendered
frame, of which the actual physics ray query consumed 33.25 ms. These scopes
are nested: do not add them together. Slow rendering accumulated multiple
simulation ticks per frame, explaining the large per-rendered-frame CPU totals.

There were 464,832 visibility checks in 8.142 seconds, about 57,000 per second:
269 candidates (256 fixtures, 12 dummies, one ball) × four weapon zones × 432 ticks.
A preceding broader run independently measured 139.61 ms median with combat
enabled versus 16.58 ms with combat disabled at 256 fixtures.

## Cause and next meaningful test

`Main.gd::_acquire_target` transforms and constructs candidates and checks
line of sight for every active target/ball before `AUTO_TARGETING.select_nearest`
filters weapon range and firing angle. `_has_target_line_of_sight` also rebuilds
the dynamic collision exclusion list for each query. Empty weapon zones do not
advance firing cooldown, so they repeat acquisition every simulation tick.

The smallest useful optimization experiment is cheap range/angle rejection
before visibility queries and candidate allocation. Reusing a per-car inverse
transform/exclusion list is a possible follow-up. Preserve nearest-visible
selection, tie ordering, wall occlusion, and firing behavior. Validate those
rules with combat regression tests, then repeat the same 256-fixture test with
combat fully enabled and follow it with an owner driving/shooting pass.

Do not reduce art quality or declare a sprite-count ceiling based on this run.
Some sprites were offscreen; GPU time was not measured directly. The sub-1 ms
animation number is script CPU, not total rendering cost. This fixed-car scan-heavy
case was slower than the owner's driving runs, and instrumentation adds overhead.
These are warmed local offline results, not multiplayer capacity or cold-load tests.

## Next-session handoff: researched optimization priorities

Owner requested that the research and proposed next steps be saved. This is
a documented proposal, not an implemented optimization or an instruction to
deploy. Continue in canonical `/Users/johnnguyen/Projects/car-fight`, `master`.
The ghoul asset remains sample sprite art, not a zombie gameplay direction.

Recommended first pass, preserving firing frequency and responsiveness:

1. Reject inactive targets and run the existing `COVERAGE.point_in_zone` test
   before visibility queries or candidate dictionary allocation. Preserve its
   adjustable triangular geometry, reversed-tip option, boundaries, and local
   coordinate semantics. `reach` is longitudinal extent, not a circular radius;
   a naive distance cutoff could incorrectly exclude valid corner targets.
2. Skip a visibility query when the candidate cannot beat an already-visible
   nearer candidate. Alternatively, order eligible candidates nearest-first
   and stop at the first visible one; preserve original equal-distance ordering.
   A blocked nearest target must not prevent selecting a farther visible target.
   Measure whether sorting is worthwhile rather than assuming it is faster.
3. Reuse the car inverse transform, physics-query setup, and dynamic exclusion
   list within the acquisition pass/tick. Share visibility across overlapping
   zones only where shooter, target, ray endpoints, obstruction rules, and
   simulation state match. Do not carry stale visibility across ticks or deaths.

Defer until the first pass is measured:

- A dedicated visibility-obstruction collision mask could replace repeated
  dynamic exclusions, but audit layers and preserve current blocking semantics.
- Budget/stagger empty-zone searches or use a lower acquisition frequency only
  if needed. This changes acquisition latency and needs explicit gameplay
  evaluation; do not silently change weapon cooldown or nearest-target behavior.
- A spatial grid can replace full-list searches if target/car counts make the
  remaining scans expensive. Its maintenance cost is not justified by default.
- Do not start with threading, a language rewrite, art reductions, or a new
  physics system; the measured problem is avoidable targeting work.

Verification for an authorized implementation session:

1. Add/extend combat tests for cone/range boundaries, reversed-tip zones,
   nearest-visible selection, equal-distance ties, blocked-nearest fallback,
   dead targets, balls, overlapping zones, and unchanged firing cadence.
2. Repeat the same warmed fixed-camera 256-fixture profile with combat enabled.
   Compare raycasts/second, acquisition CPU, median/P95 frame time, and fixture
   simulation cost. Keep count, layout, resolution, and camera matched.
3. Owner driving/shooting pass at 256: verify wall blocking, quick acquisition,
   target death/reselection, and frame-time spikes. Then test multiple cars if
   relevant; single offline-client results do not establish server capacity.

Research sources (consulted 2026-09-04):

- [Epic EQS overview](https://dev.epicgames.com/documentation/unreal-engine/environment-query-system-overview-in-unreal-engine?lang=en-US):
  filters before scoring to reduce subsequent work. Applying cheap coverage
  filtering before raycasts is our recommendation for this code.
- [Godot raycasting guidance](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html):
  documents ray queries, exclusions, physics-space access, and recommends masks
  over large/dynamic exception lists. Preserve the project's safe physics phase.
- [Epic sight API](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/AIModule/Perception/UAISense_Sight?application_version=5.5):
  exposes trace/time budgets and separates in-range/out-of-range queries.
  This is a scheduling reference, not an Unreal dependency recommendation.
- [Spatial partition pattern](https://gameprogrammingpatterns.com/spatial-partition.html):
  organize objects by position for nearby queries; weigh benefit against overhead
  for small populations.

These sources support the general techniques, not a promised FPS improvement.
The local profile is the evidence for prioritizing acquisition in Car Fight.

## Local diagnostic artifacts (retained)

Ignored artifacts remain available on this machine:

- `.crash-runs/20260904-163424/`: broad monitored run.
- `.crash-runs/20260904-163731/`: focused monitored run.
- `.crash-runs/sprite-profile/broad-results.json`: broad phase measurements.
- `.crash-runs/sprite-profile/results.json`: focused measurements above.
- `.crash-runs/sprite-profile/runner.gd`: bounded phase runner.
- `.crash-runs/sprite-profile/focused-instrumentation.patch`: temporary timers/hook.

Reproduction requires restoring that diagnostic patch on the matching baseline;
the normal committed client does not include the profiler hook. The focused run
used the required safe-window monitor:

```sh
CAR_FIGHT_SPRITE_PROFILE=1 CAR_FIGHT_SPRITE_PROFILE_DETAIL=1 CAR_FIGHT_SPRITE_VISUAL_CHECK=1 ./scripts/play_monitored.sh --offline --sprite-test
```
