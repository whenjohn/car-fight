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
