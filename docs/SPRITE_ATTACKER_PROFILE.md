# 256-attacker slowdown profile — 2026-09-04

Profile only; no optimization applied. Branch baseline: `585525d`.
The earlier automatic-targeting fix is already present. This run identifies
substantial attacker simulation cost plus a separate presentation cost, not
the original all-targets/all-zones visibility scan.

## Rendered comparison

Godot 4.7.1, Rapier, Compatibility on the development Intel Mac. Monitored
decorated window, offline, survivor art at the existing 128px/size-1 defaults.
Fixed frozen car at (0, 1, 0), 256 spawned fixtures per phase, 15 seconds of
convergence then six seconds sampled through `frame_post_draw`. Normal car
combat is suppressed using the existing fixture-isolation flag; AI shots stay
active. AI debug display is off in this comparison.

| Phase | Median frame | P95 frame | Live sprites at end |
| --- | ---: | ---: | ---: |
| Legacy movement | 29.193 ms | 33.284 ms | 256 |
| Attacker | 67.580 ms | 91.693 ms | 215 |
| Attacker, sprites hidden | 42.640 ms | 59.251 ms | 227 |
| Attacker, visual updates/animation paused | 48.566 ms | 58.584 ms | 226 |
| Converged scene, lab simulation disabled | 29.618 ms | 33.579 ms | 237 |
| Attacker repeat | 66.707 ms | 73.073 ms | 226 |

Attackers reproduce roughly 15 FPS here, not the owner's exact 7 FPS. The
unmodified prior interactive log also recorded approximately 66.67 ms at 256.
Visible animation/presentation and simulation both matter: neither reducing
spacing alone nor calling this purely a GPU capacity limit is supported.
Hiding sprites is not a direct GPU timer, and disabling simulation also removes
its changes to animation/heading. The phases are not perfectly identical
trajectories: per-frame movement/heading feedback and run-over deaths differ.

## Timed CPU scopes

Repeat attacker phase, average CPU time (inclusive scopes):

| Scope | Per simulation tick | Per rendered frame |
| --- | ---: | ---: |
| Whole sprite lab service | 8.189 ms | 32.575 ms |
| Attacker movement including world queries | 2.990 ms | 11.895 ms |
| Decisions, navigation and spacing | 1.437 ms | 5.718 ms |
| Practice shot simulation/events | 0.556 ms | 2.212 ms |
| Spacing alone (inside decisions) | 0.299 ms amortized | 1.188 ms |
| Sprite animation script | — | 4.632 ms |
| Lab presentation script | — | 0.943 ms |

Do not add nested rows to the whole-service row. The remaining service work
includes run-over contact checks, fixture iteration and 10 Hz snapshot creation.
Movement is the largest individually measured AI sub-scope. Spacing executes
about 4.6 times/second, averaging 3.86 ms per refresh in this sample; it is not
the dominant cost.

The repeat records 362 simulation services across 91 rendered frames: about
four ticks per frame. Thus an 8 ms per-tick service spends roughly 33 ms of each
slow rendered frame before the rest of the game and drawing. The older
synchronous headless probe did not measure this full-frame interaction,
native rendering/animation, or a longer-converged crowd.

## Evidence and limitations

### Follow-up: debug display reproduces roughly 7 FPS

Run `20260904-222858`, same fixed-car configuration, adds contact/visibility
timers and compares attacker with debug off/on:

| Setting | Median frame | P95 frame | Draw calls at sample end |
| --- | ---: | ---: | ---: |
| Debug off | 69.659 ms (~14.4 FPS) | 79.276 ms | 360 |
| Show AI decisions on | 135.497 ms (~7.4 FPS) | 206.270 ms | 697 |

This reproduces the reported magnitude, but whether the owner had debug on
is unconfirmed. Live counts ended at 223 off / 158 on: it is not an exact
same-trajectory comparison, and debug is slower despite fewer surviving sprites.
The debug presentation script itself increases from 0.127 to 3.837 ms/frame.
Labels and up to three marker meshes per fixture also add native rendering work
outside that timer. Draw counts are endpoint samples, not phase averages.
The debug frame averaged 7.8 simulation services; the whole lab consumed
56.65 ms per rendered frame, amplifying simulation cost as drawing slows.

With debug off, run-over checks account for 3.473 ms/frame (0.837 ms/tick),
versus movement's 12.362 ms/frame. Visibility rays total only 0.375 ms/frame
inside the AI scopes. This is not the earlier automatic-target-acquisition
ray explosion. Pathfinding is included in the decision scope, not independently
timed. World-query setup, movement queries and transform publication need a
finer split before choosing a collision optimization.

Both runs completed with clean monitor outcomes and no engine/script errors.
Detailed JSON: `.crash-runs/attacker-profile/detail-results.json`.

### Retained artifacts

- Broad run: `.crash-runs/20260904-222537/`, monitor outcome `clean`.
- Results: `.crash-runs/attacker-profile/results.json`.
- Temporary instrumentation and bounded runner retained in that ignored
  directory for reproduction; instrumentation is removed from gameplay source
  after profiling.
- Native eight-second stack sample:
  `/private/tmp/car-fight-attacker-39344.sample.txt`. Most Godot frames lack
  symbols; this does not supply a reliable GPU-time attribution.
- Background load was nonzero: a process snapshot showed macOS
  `duetexpertd` at 140% CPU and diagnostic/log services active. Absolute
  frame times should not be compared as a precisely matched speedup against
  historical runs. The within-run attacker repeat was consistent.
- No multiplayer capacity, browser or GPU timing claim. The debug-on magnitude
  reproduces ~7 FPS, not necessarily the owner's exact configuration.
  No renderer, sprite sizing, authority, input or wire changes.

For immediate testing, leave Show AI decisions off at high counts. First
optimization experiments should bound debug labels/markers and update them only
when needed, then target measured movement/contact work and changing-sprite
presentation independently. Preserve collision and
pursuit outcomes, and repeat this rendered comparison. An implementation
requires a separate owner decision; no optimization is included in this profile.

## First optimization pass — owner approved

Implemented without changing Godot, Compatibility, art/size defaults, AI
pursuit/spacing, simulation cadence or wire state:

- Reapply sprite appearance only when character, resolution or world height
  changes, not on each animation/direction change. Preserve playback progress,
  finished deaths and size controls. Avoid unchanged color/speed assignments.
- Bound debug display to the nearest 16 living sprites, refreshed at 5 Hz.
  Update text only on changes, omit nonexistent cover markers, and release
  nodes for sprites leaving the selection or when debug is disabled.
- Conservatively reject distant swept car/sprite bounding volumes before the
  original precise capsule-contact solver. Two thousand seeded comparisons
  cover translated/rotated capsules; the precise solver is unchanged.

Monitored run `20260904-224724` completed cleanly. Same phase setup as the
earlier detailed profile (15-second warmup, six-second sample, fixed car,
256 spawned survivors), without the old per-call timer overhead:

| Setting | Earlier median / P95 | Optimized median / P95 |
| --- | ---: | ---: |
| Debug off | 69.659 / 79.276 ms | 52.503 / 61.991 ms |
| Debug on | 135.497 / 206.270 ms | 60.107 / 67.747 ms |

Optimized endpoint alive counts were 224/228 and draw counts 355/366.
Results: `.crash-runs/attacker-profile/optimized-results.json`.
These are observed improvements across separate runs, not an isolated exact
speedup: earlier timers added overhead, machine load and trajectories differ,
and the debug display now intentionally shows fewer entities. This first pass
does NOT establish smooth 256-attacker play: approximately 19 FPS without debug
and 17 with it remain below the desired experience. Full-frame movement and
batched sprite presentation remain the next measured optimization candidates.

## 256-sprite CPU follow-up (2026-09-04)

With seeded movement variation retained, cache AI-active status and each car's
actual capsule transform/dimensions once per synchronous service tick, rather
than per sprite. Preserve player order, previous-tick transforms and the precise
run-over solver. Skip remote-only motion snapshot construction when there are
zero peers; keep simulation, snapshot cadence and late-join configuration intact.
No movement queries, collision checks, steering or visual sizing were removed.

Matched offline headless `sprite_ai_probe.gd`, attacker mode, 120 warmup ticks
and 600 measured ticks per case (microseconds converted to milliseconds):

| 256 sprites | Before median / P95 | After median / P95 |
| --- | ---: | ---: |
| Legacy | 3.202 / 4.764 ms | 1.946 / 2.581 ms |
| Attacker | 5.797 / 8.789 ms | 4.192 / 6.914 ms |

Observed attacker median decreases ~28%; this is simulation service CPU, not
rendered FPS or a multiplayer speedup claim. Separate runs remain sensitive to
machine load. Final timing ran after the other test processes finished; an
intermediate concurrent-test measurement is excluded. Attacker warmup maximum
was 7.983 ms versus 10.066 ms before. The unchanged incremental P95 budget of
2 ms over matched legacy still fails (4.333 ms); 256 capacity is not accepted.
The probe's long synchronous loop emits an expected netfox pause diagnostic.
Evidence: `/private/tmp/car-fight-cpu-{before,final}.log`.

Fast check, AI runtime (including no-recipient packet regression), actual-world
sprite combat/run-over, and ENet/mux lifecycle/load gates pass. These cover the
local service optimization and remote publication boundary without changing
schema, rollback or transport; the broad milestone suite is not required.

## Reusable movement query (2026-09-04)

Owner evaluated `4490e4d` with 256 attackers and batched drawing and reported
smoother play around 42–50 FPS. Monitored run `20260904-232809` closed cleanly.
This is interactive feedback, not a controlled live-count FPS comparison.

The next small CPU optimization reuses one synchronous movement-query object
and updates its dynamic-body exclusions once per tick. Each move still replaces
the actual shape, transform, motion and mask, and performs the same overlap and
cast checks. Reset discards the query and exclusions. Cover checks use separate
queries; navigation, decision cadence, steering and replication are unchanged.

A new 36-case runtime regression compares movement against independently built
fresh queries: three capsule sizes, open/wall/overlap positions, both directions,
and alternating wall exclusions. It passed against both the original and reused
implementation, along with existing pursuit, spacing and real ambush tests.

Same probe procedure as above, separate idle headless runs this session:

| 256 sprites | Before median / P95 | After median / P95 |
| --- | ---: | ---: |
| Legacy | 1.261 / 1.858 ms | 1.317 / 2.684 ms |
| Attacker | 2.642 / 4.532 ms | 2.468 / 4.366 ms |

Observed attacker median improvement is ~6.6%, not a large new FPS step.
Warmup maximum was 4.917 → 5.194 ms. Legacy tail noise and the considerably
lower baseline versus the prior session demonstrate machine-load sensitivity;
do not compare these numbers directly with the previous pass or certify the
high-count budget from one favorable incremental-tail subtraction. No limits
were relaxed. Logs: `/private/tmp/car-fight-query-{before,final}.log`.
An intermediate development measurement (`query-after.log`) predates the final
corrected implementation and is excluded from results.

Fast check, AI runtime (fresh-query oracle plus behavior), world combat and ENet
lifecycle pass with clean error scans. ENet run `sprite-ai-network.vTukQQ`
checks reset/reconfiguration with live clients;
no wire schema, authority, rollback or transport changed, so the broad milestone
suite is not required. Rendered acceptance of this small follow-up is pending.
