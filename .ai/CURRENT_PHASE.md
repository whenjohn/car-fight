# Current phase

## Active session: Car-Fight: sprite ai

- Owner observed the grass Ambusher, said "I like it", and requested committing
  this version for now. Keep the current behavior and camouflage as the accepted
  iteration. Explained that hiding uses green tint at 22% opacity, not complete
  invisibility; hitboxes remain active and rush/death restores visibility.
  Implementation is already committed as `2bdd129`; this records owner feedback.
  No new FPS figures or sustained performance acceptance were provided. No
  behavior changes or test reruns needed for this documentation-only checkpoint.

- Owner requested starting the grass-Ambusher playtest. Launched gameplay
  `2bdd129` in monitored run `20260905-040430`, client PID 22018: offline,
  64 initial Ambushers, survivor sample, batched drawing, inset window at 100,100.
  Offline readiness and count confirmed; no startup errors seen. Population
  remains opt-in in the existing UI. Await camouflage, pass timing and FPS notes;
  no visual/performance acceptance yet. Supersedes "no grass-version launch" below.

- Owner rejected building Ambusher as too complicated and requested grass:
  run there, blend in, rush from behind after the vehicle passes. Replaced
  building selection/sector circling with the existing single grass field at
  (58, 0, 18), east of the central intersection. Shared static `grass_layout.gd`
  also drives unchanged render placement/dimensions; no additional blades,
  physics bodies, world scans, renderer or sprite-size changes.
- At most 100 spaced, grid-aligned slots generated once per current radius;
  actual world/capsule checks validate reachable endpoints. Each brain reserves
  one slot and uses a round-robin cursor, two candidates/job, two-second retries,
  existing four jobs/tick and staggered 5 Hz decisions. Claims release on
  death/despawn/reset; excess sprites wait if no slots are free. The accepted
  64-live count fits. Initial city-wide travel can take over a minute.
- Arrival hides with green 22%-opacity tint through existing original/batched
  sprite color. Hitbox and run-over deaths remain; rush/death restore visibility
  and hits still flash. After one second settled, observe approach within 18,
  then departure while behind the car's facing within 24 to trigger 1.5x rush.
  Parked/merely turned-away/alongside cars do not trigger. Three shots or ten
  seconds returns to reserved grass. No building-occlusion requirement remains.
- Final PASS: fast check, cover and AI decisions, AI runtime, sprite fixture/
  batch, population and offline smoke. Real grass rush moved 4.46 units and fired
  three shots; all 64 reached distinct grass spots within 120 simulated seconds.
  Lifecycle reservation and shared tint/hitbox checks pass. Headless GPU color
  readback is unavailable, so visual blend-in is still explicitly unaccepted.
- Existing probe extended with actual grass passes, keeping every tick at 64
  living using diagnostic-only health restoration outside CPU timing. Final
  service median/P95/max: prepare 0.762/1.269/6.678 ms, street square
  0.436/0.740/1.499 ms, active grass passes 1.040/1.628/2.713 ms. 695 shots,
  peak 52 active, max four jobs/tick; grass-pass diagnostic restored 2,290
  repeated run-over deaths, not normal gameplay survival evidence. Earlier
  preparation P95 was 2.041 ms; no cherry-picked locked-FPS claim. Logs and
  retained initial failures: `.crash-runs/grass-ambush.bcVXyj/`; limitations and
  full evidence in `docs/SPRITE_AI.md`. No networking work/tests/deployment.
- Previous building playtest `20260905-033038` ended cleanly. No grass-version
  rendered launch yet; next is owner observation of camouflage, pass timing
  and sustained FPS with 64. Attacker/Evader and population behavior unchanged.

- Owner requested the revised Ambusher playtest. Launched gameplay `fd41fc7`
  in monitored run `20260905-033038`, client PID 8194: offline, 64 initial
  Ambushers, survivor sample, batched drawing, ordinary inset window at 100,100.
  Offline readiness and 64-fixture startup confirmed; no startup errors seen.
  Population remains opt-in in the Sprite test UI. Await owner observations of
  circling cover, passing/turning-away rushes and sustained FPS. No code changes
  or new acceptance claim; this launch supersedes "no new rendered launch" below.

- Owner requested object-aware Ambusher hiding: run to cover, keep the same
  object between sprite and circling car, then rush a passing/turned-away car.
  Also explicitly required bounded object tracking to protect the accepted
  64-live performance target. This supersedes the proximity-trigger pass below.
- Implemented a shared registry of the 14 static city buildings with eight
  cached anchors each, current capsule radius/height eligibility, persistent
  per-brain object ID/sector and at most 14 candidate IDs. Dynamic crates,
  trees/decor are excluded for now; no new physics bodies, per-frame scene scans
  or network fields. Read sibling `NETWORK_SAFE_GAMEPLAY.md`; network work stays
  deferred. Existing 5 Hz staggered decisions and four route jobs/tick retained;
  cover jobs now check at most two candidates each, with sector hysteresis and
  0.5-second reposition / two-second acquisition retry bounds.
- Ambushers run at the existing 1.5x cap into/around real occluding cover. One
  second genuinely hidden prepares the trap; circling/facing alone no longer
  triggers. Within 24 units of the building surface, facing away or departing
  after passing close triggers a current-player rush, then return after three
  shots or ten seconds. Actual sight still required to fire. Preparation survives
  brief exposure during repositioning, but resets on player change, lost cover
  or rush completion. No teleport/invisibility; cars can outpace the reposition.
- Regressions added before implementation and observed failing on old behavior.
  Fast check, cover, AI decision, runtime and population tests PASS. Physical four-side
  station test retained building ID 1, reached actual opposite-side occlusion
  without shots, then turning away caused 32.22-unit peak movement and two shots.
  Stationary cohort: 64/64 reached concealment within 40 simulated seconds.
  Detailed CPU evidence/limitations and commands are in `docs/SPRITE_AI.md`.
- Matched 64-live headless sprite-service probe: moving median/P95 changed from
  0.640/1.158 ms to 0.756/1.279 ms; first after sample P95 was 1.527 ms. Final
  preparation P95/max 1.312/5.985 ms. New behavior emitted 136 shots versus zero
  before, with 213 retargets; maximum four jobs/tick. Diagnostic revival outside
  timer kept all 64 active; no gameplay immunity added. Logs retained under
  `.crash-runs/ambush-cover.W6rUWm/`. Thermal equality unavailable. Small measured
  service increase is NOT rendered FPS or network acceptance.
- Next: owner observes continuous circling/opportunities with 64 Ambushers and
  checks sustained FPS; previous monitored run `20260905-025721` ended cleanly.
  No new rendered launch yet. Engine/renderer, sprite sizing, spawners, accepted
  Attacker/Evader tuning and network transport/schema remain unchanged.

- Owner rejected baseline Ambusher: exposed standing and no convincing rush.
  Confirmed implementation only searched after sight, required a visible peek
  point, fell back to Basic shooting on failure and attacked from that peek.
  Replaced with cover-first preparation → real concealment → 1.5× rush toward
  the current player → return after three shots or six seconds. Prepared hide
  lasts at least one second, trigger 18 units, close to six; actual sight remains
  required for shooting. No exposed Basic fallback. Cover revalidated at arrival.
- Ambusher preparation now tracks an eligible player before sight (like hunter
  acquisition, preserving cloak/edit/RC/map exclusions). Unlike weapon sight-range
  filtering, its hide test uses real occlusion. Cover search uses 64-unit corner
  candidates with four candidate/path checks per queued job, rolling cursor,
  two-second retries; existing four-job/tick and incremental-grid limits retained.
  No new RPC/codec fields, rollback bodies, engine/sizing or spawner changes.
- New decision regression was added before the change and failed on old behavior.
  Final fast check, decision, runtime and population tests PASS, including actual walking to cover and
  a nearby occluded city-corner approach: rush peak displacement 7.29 units,
  three actual shots, then return. The initial assertion incorrectly measured
  final displacement after returning; now it tracks maximum excursion.
- Representative offline cohort: 64/64 found cover, 59/64 physically reached
  concealment within 40 simulated seconds; five were still taking longer paths
  around buildings. Stationary car stayed outside their rush range. This is not
  instant hidden spawning or an FPS claim. Final pure/runtime runs had no errors;
  an initial explicit-bool compile issue was fixed and its two stalled test
  processes stopped precisely. No networking tests/deployment. Owner visual feel
  and sustained FPS acceptance remain pending on the revised 64-Ambusher playtest.
- Owner accepted varied Evader reactions ("feels good") and moved on to Ambusher.
  Evader run `20260905-023808` ended cleanly. Launched baseline Ambusher observation
  at `ebfd37f`, run `20260905-023956`, PID 94874: offline, 64 initial sprites,
  survivor, batched drawing, ordinary inset window. Population remains an in-game
  opt-in. No behavior/code changes this turn; awaiting notes on finding cover,
  hiding, stepping out, three-shot burst and retreat. No new performance claim.
- Owner approved the sprint/zig-zag feel, then requested varied reaction range:
  some Evaders sense the approaching car earlier; some wait as before. Added a
  per-ID seeded reaction distance: ~35% retain 10 units, the rest draw 14–22.
  Early reaction requires planar closing speed >0.5 units/sec from the observed
  player's velocity; parked/departing/tangential cars retain the close trigger.
  Personal release distance is trigger +4 units to prevent reaction chatter.
  Existing acquisition, emergency sidestep, 10→2-unit speed ramp/cap and zig-zag
  steering remain; no extra perception/routing work or replicated fields.
- Regression added before code and confirmed uniform old behavior fails the
  cohort test. Final PASS: fast check, `sprite_ai_test.gd` (seeded bounds, early
  vs patient cohort, direction/closing checks, release buffer, all previous
  sprint/zig-zag tests), `sprite_ai_runtime_test.gd` (mixed reaction at the same
  18-unit distance through real 64-fixture player observation, plus retained
  movement/collision/other-profile/lifecycle checks). Final tests clean, no errors.
  Documented in `docs/SPRITE_AI.md`; ready for owner repeat playtest. Networking,
  engine/sizing, spawners and speed caps unchanged; no new FPS acceptance claim.
- Prior tuned-Evader run `20260905-023254` ended cleanly before this edit.
- Owner found baseline Evader reasonable and requested faster retreat as the
  pursuer closes plus zig-zag evasion. Added a distance ramp from base speed at
  ten units to the existing 1.5× maximum at two units, with seeded 1.5–3-second
  alternating steering up to 0.65 radians. Existing per-waypoint fading, speed
  limiting and capsule sweeps are reused unchanged. Predicted run-over retains
  full-speed direct sidestep priority; no added route jobs/RPC/state fields.
- Added regression BEFORE behavior change and confirmed the old behavior fails
  ramp/weave assertions. Final PASS: fast check, `sprite_ai_test.gd` (all slider
  extremes, cap, easing/hysteresis, repeatable individual turns, crossing priority),
  `sprite_ai_runtime_test.gd` (real movement and fresh-sweep equivalence at two
  capsule sizes, both turn directions, wall blocking and speed cap; existing
  other-profile/contact/lifecycle checks retained). Final runs clean, no errors.
  No engine, sprite size, population or network changes/tests. Rendered feel/FPS
  for the tuned Evader remains pending owner observation; ready for a repeat
  monitored 64-Evader playtest.
- Baseline observation run `20260905-022650` ended cleanly before this edit.
- Owner requested observation of the next behavior before tuning. Launched
  monitored offline Evader playtest at `9cedf26`: 64 initial sprites, survivor,
  batched drawing, ordinary 1280x720 inset window. Run `20260905-022650`,
  client PID 91201; offline readiness and 64-fixture configuration confirmed.
  Population starts off and is enabled via the existing in-game selector.
  Await owner notes; no Evader changes or performance acceptance yet.
- Implemented optional **offline population spawners** after recording the
  accepted 64-live target in `f618961`. Debug → Sprite test → Population (offline)
  → Maintain 56–64 (reset), immediately below Disable test. Monitor at the top
  reports living/corpse counts, refill state, replacements and blocked attempts.
  Defaults remain off; no networking or engine/sizing changes.
- Below 56 living, replace gradually toward 64: one per 0.25 simulation seconds,
  at most eight candidate checks per interval across 64 cached street points.
  Actual capsule/world, player-distance and neighbor checks prevent unsafe births.
  Corpses expire after about five seconds; retain at most 16 per controller pass,
  at most 80 fixtures total. No queued spawn backlog; existing tick policy unchanged.
- Per-generation monotonic IDs, per-newborn brain setup, per-despawn AI/debug
  and managed-animation cleanup avoid resetting survivors or retaining references
  through waves. Newborns inherit the selected behavior and actual size. Off stops
  both refill and cleanup; Disable test clears fixtures. Different count turns it
  off; same-count profile/size resets preserve the population selection.
- Validation PASS: `./scripts/check.sh`, new `sprite_population_test.gd` (12
  twenty-death waves, counts/identity/bounds, real obstacle/player/neighbor checks,
  inheritance, ordinary service/UI wiring, stop/reset/retire/offline gate), existing
  `sprite_ai_runtime_test.gd`, `sprite_test_lab_test.gd`, and `scripts/offline_test.sh`.
  Final runs exited cleanly, no engine/script errors. Initial new-test setup failed
  obstacle registration because stopped NetworkTime also pauses Rapier space steps;
  fixed the harness with an explicit physics step. Also corrected its cursor when
  replacing candidate points. No collision behavior was relaxed to pass the test.
- These headless gates cover the changed lifecycle/shared initialization and
  presentation release, not rendered FPS. No network test or deployment performed.
  Next: approved monitored playtest of repeated kills/replenishment at 64, then
  tune Evader and Ambusher individually. Sustained moving-player/spawner FPS and
  birth/death visual acceptance remain unmeasured. Details: `docs/SPRITE_AI.md`.
- Owner accepted **64 living sprites** as the working population target.
  Hold there for behavior development; the measured 57–63 average FPS is not
  a locked-60 guarantee. No further speculative optimization or engine change.
  Next: offline-only, bounded replenishing spawners and a live population
  monitor; then tune Evader and Ambusher individually. Networking remains deferred.
- Valid lower-live-count retry completed at `83127c0` plus temporary diagnostic.
  Owner approved keeping the ordinary window above other windows. Run
  `20260905-015827` closed cleanly with no engine/script errors; 1280x720,
  stationary Jeep, all requested attackers alive and drawn on every frame.
- 64 living: average 62.73 / 57.36 FPS across two 12-second samples, median
  13.912 / 16.510 ms, P95 27.710 / 28.002 ms. Mac CPU allowance fell during
  the repeat (end speed limit 65); not an isolated count-only comparison.
  32 living: average 73.58 / 76.89 FPS, median 11.886 / 11.769 ms, P95
  23.645 / 23.219 ms. Recommendation: 64 is a reasonable ~60-FPS playtest
  target; 32 has more headroom. Neither is a locked-60 claim.
- Full-active rows/config/results: `.crash-runs/live-count-1788591520/`.
  Diagnostic patch and CPU samples are in the monitored run directory.
  Window focus varied but remained visible above others and produced complete
  uninterrupted draw samples. Prior true-128 test used an ordinary nonfloating
  window; do not infer an exact scaling law across those separate runs.
- Test-only immortality, 32-count allowance and always-on-top/runner code were
  removed; both touched source files match HEAD. Default counts unchanged.
  Import passed before run; final source-restoration and diff checks cover
  this documentation-only handoff. No networking or gameplay changes shipped.
- Owner requested same all-alive stationary-Jeep test at lower counts.
  Prepared 64/32 with two repeats, matching 15-second warmup / 12-second
  samples, temporarily permitting 32 only in the offline diagnostic.
  Run `20260905-015453` aborted before any sample: no rendered frame for
  2.5 seconds after window became obscured. Expected diagnostic exit 2,
  NOT valid FPS evidence. Import passed; no engine/script errors observed.
- Diagnostic patch preserved in that run directory. All temporary runner,
  hit suppression and 32-count changes removed; gameplay matches HEAD.
  Asked owner whether the next test may temporarily keep its small ordinary
  window above others to prevent occlusion. No lower-live-count result yet.
- Valid TRUE 128-live-attacker test completed at `18e2f92` plus temporary
  offline diagnostic. Run `20260905-014909` closed cleanly; all 128 stayed
  alive AND batched in every sampled frame, Jeep fixed at (0,1,0), window
  1280x720 and focused throughout, recorded CPU limits 100. Results:
  `.crash-runs/live128-1788590968/`; diagnostic patch in monitored run folder.
- Two 12-second windows after separate 15-second warmups: median/P95
  20.411/26.924 ms and 20.356/26.690 ms (~49 FPS typical, ~37 at P95).
  Worst frames 31.581/31.956 ms; zero measured frames over 33.333 ms.
  1,132/1,139 practice shots created during samples. No claim of locked 60
  or longer-session/moving-Jeep/network capacity. Full-active 64 still untested.
- Temporary offline hit suppression retained all movement/contact queries;
  runner checked live count and Jeep position every frame, added draw-gap
  and overall timeout/resize guards. Import passed; both runtime samples valid,
  no engine/script errors. Test-only code fully removed; gameplay and probe
  match HEAD. Only docs changed, verified with source-restoration/diff checks.
- This supersedes the earlier unverified 128 recommendation: the ~57 FPS
  spawned-count result had only 72 alive; TRUE 128 was ~49 FPS in this scene.
- Owner asked whether lower counts reach ~60 FPS. Added optional diagnostic
  `CAR_FIGHT_BATCH_COUNT_SWEEP=1` to the existing rendered probe; no gameplay
  defaults or AI changes. Fast check passed; bounded count phases exercised.
- Run `20260905-012152` closed cleanly, window stayed 1280x720. Valid samples:
  256 spawned / 226 alive median 26.334 ms (~38 FPS); 128/72 median 17.483 (~57);
  64/28 median 15.222 and 14.722 (~66–68); 16/16 median 11.725 and 12.611 (~79–85).
  Zero-sprite city median 11.523 ms but P95 23.513: a smaller count does not
  guarantee every frame meets 16.7 ms. Details in batch prototype doc.
- Important: spawn counts are NOT all-active capacity. Follow-up attempted
  128/64/16 with temporary offline hit suppression while retaining movement/
  contact queries. Window repeatedly became obscured; no usable full-active
  sample completed. Stopped exact diagnostic PID 76385 with SIGTERM, removed
  all immunity/temporary-runner changes, and verified gameplay source matches
  HEAD. No claim that 64 living attackers sustain 60 is supported yet.
- Exclude final 128 repeat in first run (one 101-second frame after occlusion),
  and all full-active run `20260905-012717`. Original first-run results are
  `.crash-runs/sprite-batch-1788589333/`; temporary diagnostic patch preserved
  in second run directory. Original last repeat also overlapped an import
  check, another reason it is unusable. Recorded CPU speed limits were 100.
- Practical next playtest candidate: 64 spawned, with explicit live-count and
  frame-tail caveats. Full-active 64/128 measurement still needs a visible,
  uninterrupted rendered window. No network tests or gameplay changes.
- Managed-animation rendered retry `20260905-011034` completed both phases
  and closed cleanly at `625c3f9`, with no engine/script errors. Window remained
  1280x720; recorded CPU speed limits stayed 100. Median/P95: 25.869/30.445 and
  25.076/31.065 ms, versus before 28.832/34.659 and 29.321/35.162. Roughly
  35 → 39–40 FPS in this controlled fixed-car scene, not stable 60 acceptance.
  Timed phases each retain all 256 rendered sprites/corpses; alive 226/227.
  Artifacts `.crash-runs/sprite-batch-1788588654/`. Details in batch prototype doc.
- This is a modest observed 10–14% median frame-time reduction across separate
  runs; machine load and small survivor-count differences limit exact claims.
  No gameplay/network changes in retry. Owner feel and full managed-path
  rendered visual acceptance remain separate; performance-only runner used.
- Owner authorized next offline FPS optimization, explicitly no networking yet.
  Implemented managed batch animation: disable hidden directional script
  callbacks, retain four canonical frame sets and independent native clocks,
  compute facing directly for batch data, restore original directional frames
  and processing on fallback. No simulation, sizing or network changes.
- Sprite contracts pass, including actual independent clock advancement with
  scripts disabled, eight facings, death hold, replay, speed/pause and fallback.
  AI runtime and final fast check after expanded test pass with clean error scans.
  Logs `/private/tmp/car-fight-managed-*.log`. Initial typed-vector compile
  error was corrected; the exact hung test process was stopped before retry.
- Before capture `20260905-002924` closed cleanly: batched median/P95
  28.832/34.659 and 29.321/35.162 ms, alive225/226, window1280x720 and CPU
  limit100 at start/end. Results `.crash-runs/sprite-batch-1788586184/`.
- After-run `20260905-003246` closed cleanly but was resized repeatedly and
  closed before its first benchmark result. It is INVALID as an A/B result.
  That interrupted run supports no FPS or visual acceptance claim. Owner
  approved the successful untouched retry recorded above.
- Existing batch probe now supports `CAR_FIGHT_BATCH_PERF_ONLY=1` for two
  batched phases, without original-drawing phases or screenshot tail. Functional
  offline tests do not establish performance; no network tests/deployment run.
- Latest request was rendered profiling of drops near 20 FPS and apparent
  ~50-FPS ceiling, not another fix. Baseline `79615ad`; no gameplay changes.
  Full report: `docs/SPRITE_FRAME_DROPS_2026-09-05.md`.
- Runtime max_fps=0, VSync enabled; no configured 50 cap. Ordinary attacker
  frames measured 22.5 ms control / 24.3 ms instrumented. Simulation averages
  7.56 ms/frame, sprite presentation scripts 4.80 ms, render CPU elapsed 5.98 ms.
  Route searches only 0.190 ms/frame: not the leading CPU target.
- Moving-car phase reproduced P95 55.076 ms, max 75.28 ms. Mac reported CPU
  speed limits falling from 100 to 51/41 while ~22–25 ms frames became ~53–57.
  Per-tick costs rose and ~1–2 sprite services/frame became ~3–4, amplifying
  dips. Exact thermal/power trigger is not established; no system settings
  were changed. Prior owner's run `20260905-000717` closed cleanly but ended
  with CPU speed limit 24, versus 100 for the earlier smoother run.
- Eight-phase monitored run `20260905-001325` completed cleanly with no script/
  engine errors. Raw frames and instrumentation: `.crash-runs/frame-cost-1788585220/`.
  GPU timing returned zero despite enabling measurement: unavailable, not free.
  Background load, timer overhead and varying live counts limit exact A/B claims.
- Temporary instrumentation passed two-pass import then was fully removed;
  source matches `79615ad`. Only documentation changed; source-restoration and
  diff checks are sufficient. No new optimization, wire or display-policy change.
- Next recommendation: reduce remaining sprite presentation/animation and
  batch-upload work, then movement/contact costs; record OS CPU limits during
  comparisons. Do not prioritize route-cache changes or lower tick rates on
  this evidence. Owner decision required before implementing the next fix.
- Owner's 256-batched playtest at `4490e4d` felt smoother, reported ~42–50 FPS.
  Monitored run `20260904-232809` closed cleanly. This is owner feedback, not
  a matched rendered benchmark or guaranteed 256-live-sprite frame rate.
- Next bounded optimization: reuse one synchronous AI movement shape query,
  refreshing dynamic-body exclusions once per tick. Reset releases the last
  shape/exclusions. All individual wall/overlap sweeps, pursuit, spacing,
  randomness, navigation scheduling, sizing and network state stay unchanged.
- Same-session headless attacker256 median/P95: 2.642/4.532 → 2.468/4.366 ms
  (~6.6% observed median improvement). Smaller than the prior CPU pass; not
  an FPS claim. Baseline machine load differs from earlier session readings.
  New fresh-query equivalence regression passed before and after the change;
  fast check, AI runtime, combat and ENet lifecycle pass with clean error scans.
- Next: benchmark route planning separately before changing navigation. No
  new rendered run or renderer/engine migration. Evidence in profile doc.
- 256 CPU follow-up: cache per-tick AI status/car capsule inputs and avoid
  remote-only motion packing with zero peers. Preserve pursuit, randomness,
  spacing, all world sweeps, run-over solver and sprite sizing. No engine change.
- Offline 256-attacker service median/P95 improved from 5.797/8.789 ms to
  4.192/6.914 ms (~28% median reduction observed). This is CPU tick time, not
  rendered FPS. Incremental P95 budget still fails; next bottleneck remains
  movement/navigation work. Details: `docs/SPRITE_ATTACKER_PROFILE.md`.
- Fast check, AI runtime, world combat/run-over and ENet/mixed-transport
  load/lifecycle gates pass with clean error scans. Logs `/private/tmp/car-fight-cpu-*.log`.
  Prior interactive run `20260904-231501` closed cleanly; no new rendered run.
- Latest tuning: owner requested randomness in attacker movement. Added
  deterministic per-fixture pace (±12%), left/right preference and gentle
  3–6-second steering variation (up to ~21 degrees), faded near waypoints.
  Persistent pursuit, firing cadence, spacing and world sweeps remain intact.
  Only server decisions generate steering; no new replicated fields or RPCs.
- Fast check and focused brain/runtime gates pass, covering repeatable seeds,
  varied individuals, smooth bounded steering, no idle drift, building pursuit
  and spacing. Logs: `/private/tmp/car-fight-random-{brain,runtime}.log`.
  No broad suite required for this localized steering tune. High-count rendered
  performance has not been rebenchmarked for the variation.
- Previous batched interactive run `20260904-230807` closed cleanly.
- Opened approved monitored run `20260904-231501` at `875022e`, 256 batched
  survivor attackers with varied movement. Owner feel evaluation and final
  monitor outcome remain pending.
- Latest owner request: try batched sprite drawing, with no engine/backend
  change. Added opt-in MultiMesh presentation for survivor/thug, original
  AnimatedSprite3D clocks retained. AI, hitboxes, spacing, wire data and sizing
  formulas are unchanged. Original sprites remain default and ghoul fallback.
- Initial alternating rendered comparison `20260904-225555` closed cleanly:
  original medians 51.364/50.892 ms, batched 32.996/32.676 ms (~20 → 30 FPS);
  endpoint draws ~343 → 159–165. Frozen paired screenshots visually match at
  the tested city camera. Remaining visual acceptance and 60-FPS capacity are
  not claimed. Details: `docs/SPRITE_BATCH_PROTOTYPE.md`.
- Final batch implementation follows actually loaded clip/facing rather than
  next-frame lab intent. A checked-in bounded `sprite_batch_probe.gd` verifies
  actual instance uploads on GLES, captures paired images and tests fallback.
  Final run `20260904-230222` closed cleanly and passed real GLES uploads and
  fallback: original medians 50.613/49.169, batched 33.268/32.379 ms.
  Captures/results: `.crash-runs/sprite-batch-1788580961/`.
  AI runtime, offline startup, appearance/fallback and fast gates pass.
  Visual-only follow-up `20260904-230609` also passed actual uploads/fallback
  and closed cleanly; held-pose captures retain a small camera-settling shift.
- UI: Debug → Sprite test → Drawing (local prototype) → Batched modern sprites.
  Environment: `CAR_FIGHT_SPRITE_BATCHED=1`. Four whole-city action batches,
  capacity 256 each; no individual culling/sorting inside batches. Kept opt-in
  pending owner visual review. No backend migration or network changes.
- Opened approved interactive monitored run `20260904-230807` at `bc9ebde`
  with 256 batched survivor attackers. Owner visual/feel evaluation and final
  monitor outcome remain pending.
- Owner authorized trying optimization and explicitly ruled out engine changes.
  First pass stays on Godot 4.7.1 Compatibility: avoids redundant appearance/
  color/speed updates, bounds debug labels/markers to nearest 16 living sprites
  at 5 Hz, and adds conservative rejection before unchanged precise run-over
  collision math. No pursuit, spacing, art-size defaults or network changes.
- Optimized rendered run `20260904-224724` closed cleanly with no engine/script
  errors. Median/P95: debug off 52.503/61.991 ms, debug on 60.107/67.747 ms,
  versus historical 69.659/79.276 and 135.497/206.270. Different instrumentation,
  surviving counts and machine load limit exact speedup claims. Approximately
  19/17 FPS is an improvement, NOT smooth 256-sprite acceptance.
- Final fast check, sprite appearance/contact, AI runtime and sprite combat
  gates selected for local appearance/debug and collision optimization.
  Collision coverage compares 2,000 seeded translated/rotated cases against
  the original precise solver; no shared schema/transport changed, so no
  repeated broad suite. All four gates pass; focused runtime logs are
  `/private/tmp/car-fight-opt-{sprite,ai,combat}.log`.
- Render runner hook removed from gameplay source. Evidence and remaining work:
  `docs/SPRITE_ATTACKER_PROFILE.md`. Next: further movement and batched sprite
  presentation investigation within the same engine, not a platform migration.
- Latest request: profile the 256-attacker slowdown, not implement a fix.
  Rendered investigation at `585525d` is recorded in
  `docs/SPRITE_ATTACKER_PROFILE.md`. Temporary timers were removed; gameplay
  source is unchanged. Monitored runs `20260904-222537` and
  `20260904-222858` completed cleanly without engine/script errors.
- Broad results: legacy median 29.2 ms, attacker 67.6 ms, hidden sprites 42.6,
  frozen visuals 48.6, lab simulation disabled 29.6, attacker repeat 66.7.
  Whole lab costs ~8.2 ms/tick, accumulating ~32.6 ms/rendered frame.
  Movement/world queries are the largest measured AI sub-scope; spacing and
  visibility are much smaller. The prior targeting optimization is present.
- Debug follow-up: Show AI decisions off/on measured 69.7/135.5 ms median
  (~14.4/~7.4 FPS), with 360/697 endpoint draw calls. This reproduces the
  reported magnitude; owner's exact debug/auto-fire settings remain unconfirmed.
  Different surviving counts and background OS load limit exact comparisons.
- Next: owner decision on optimizing high-count debug presentation, then
  movement/contact and animation update costs. Keep debug off for high-count
  playtests in the meantime. No behavior, size or network changes made.
- Latest tuning: owner requested loose attacker groups instead of run-over
  clumps. Added server-only 5 Hz soft separation, preferred center gap 2.5 units
  or actual capsule diameter + 1.5, with bounded spatial-neighbor sampling.
  Existing sweeps/speed caps still govern movement, including making room while
  firing. Other profiles, sprite sizing, replication and rollback are unchanged.
- Fast check and focused runtime regression pass, including a fully stacked
  16-hunter group spreading, opposing overlap steering, hold-position spacing,
  dead exclusion and reset. Full suite is not required for this local steering
  change; existing AI network lifecycle is checked separately.
- Final spacing probe: 16-attacker P95 0.734 ms, 256 P95 8.910 ms versus matched
  legacy 5.477 ms; warmup maximum 10.829 ms. High-count performance remains
  unaccepted under unchanged budgets. Logs: `attacker/spacing-*.log` under
  `.network-runs/sprite-ai/`.
- First spacing ENet gate failed observer-disconnect timing, then logged
  inactive-peer errors in unchanged Main/player/dots paths after shutdown.
  Preserved run `car-fight-sprite-ai-network.xZqWd2`; isolated retry passed with
  clean logs (`car-fight-sprite-ai-network.19DNk0`, payload max 904 bytes).
  Final local steering polish fades small corrections to avoid full-speed
  spacing jitter; runtime and load checks rerun for that final adjustment.
- Previous attacker playtest `20260904-220627` closed cleanly.
- Reopened approved 16-Attacker offline playtest `20260904-221422` at `2a44fd4`
  for owner evaluation of loose grouping; final monitor outcome is pending.
- Worktree: `/Users/johnnguyen/Projects/car-fight-sprite-ai`.
- Branch: `codex/sprite-ai`, created from current `master@9a25b09`.
- Required ignored city/tree assets copied with `scripts/sync_local_assets.sh`.
- Owner's session scope: add basic sprite logic, attacking, evading, and
  ambush (hide, then attack), with room to experiment with other behaviors.
- Implemented Basic, Attacker, Evader and real building-cover Ambusher profiles,
  plus Mixed, in the existing sprite lab. AI shots are feedback only; car
  auto-fire can be toggled and starts suppressed in AI mode. Ordinary launch
  and legacy sprite movement defaults remain unchanged.
- Launch for the next owner-approved visual pass:
  `CAR_FIGHT_SPRITE_AI=mixed CAR_FIGHT_SPRITE_SAMPLE=survivor ./scripts/play_monitored.sh --offline --sprite-test`.
  Default count is 16. Modern local art was physically copied from canonical.
- Network guidance rechecked at networking branch `14d103b`. Reused its exact
  connection-state helper/UID; did not merge its other pending fixes. Explicit
  feature contract, bounds, commands and evidence: `docs/SPRITE_AI.md`.
- Server-only decisions, capsule sweeps and practice shots; lightweight motion
  snapshots, byte-bounded configuration and shot events; no new rollback bodies
  or player inputs. Navigation builds incrementally (512 cells/tick), with at
  most four route jobs/tick. Sprite sizing remains owned by the other session.
- Fast check, AI brain/navigation/runtime tests, existing sprite contracts,
  live sprite combat and targeting regression pass. The finalized AI ENet and
  mux gates pass with all three process logs clean, including non-owner denial,
  owner transfer, same-process scene-reconstruction reconnect and active AI.
- AI load gates exercised 16/64/256 sprites with two clients; largest serialized
  payload 904 bytes. Final headless 256 service: legacy median/P95 2.336/3.562 ms,
  mixed AI 2.908/4.567 ms. Full-frame/rendered capacity remains unmeasured.
- Complete suite was attempted and remaining gates continued without repeating
  already-passing tests. It is NOT a clean overall PASS: the old vehicle-size
  source assertion expects absent `Show Collision Capsule` text, and reproduces
  on canonical master. General network/combat harnesses also print PASS despite
  inactive-peer shutdown errors from unchanged callbacks; these are the fixes
  being handled in the networking worktree. Preserve their work ownership.
- Feature integration errors found by broad tests (autoload access during
  preload and auto-fire calls without an instantiated lab) were fixed; affected
  sprite and targeting regressions reran cleanly. The state-codec negative
  control intentionally logs a truncated-payload decoder error.
- Logs: `.network-runs/sprite-ai/`, including final probe, final ENet, full-suite
  attempt and resumed tails; clean AI process logs copied to `enet-gate/` and
  `mux-gate/`, and existing shutdown-error evidence to `baseline-shutdown/`.
- Next: owner-approved monitored playtest at 16; tune behavior from actual feel.
  Before merge, integrate the separately-owned networking/sizing work and rerun
  affected lifecycle/size gates. Browser, TURN and rendered acceptance are open.
  No master merge or production deployment performed.
- Owner approved interactive testing. Opened monitored offline run
  `20260904-205333` at `a920836`, with 16 Mixed AI survivors and auto-fire off.
  Startup reached the fixture and logged a 6.96-second initial stall; behavior
  acceptance remains with the owner; the monitor subsequently closed cleanly.
- Owner requested aggressive, continuous Attacker pursuit. Attacker now tracks
  eligible players across the map/behind cover, moves at 1.5× speed, shoots while
  closing inside 18 units, holds at six and never retreats or gives up. Cloak
  and existing eligibility exclusions remain respected. Other profiles and
  sprite sizing are unchanged.
- Attacker tuning checks pass: fast check, brain/navigation and real-world
  runtime regressions, plus ENet AI lifecycle gate with clean process logs
  (`car-fight-sprite-ai-network.BKXEhB`, max payload 904, max four route jobs).
  These cover the changed decisions/movement and existing replicated lifecycle;
  no wire/input/transport schema changed, so no repeated broad suite this turn.
- All-attacker load probe is NOT accepted at 256: incremental P95 2.611 ms
  and warmup 11.879 ms exceed the existing 2/8 ms limits. Details and raw log
  location are in `docs/SPRITE_AI.md`; interactive tuning remains at 16.
- Opened owner-approved offline monitored run `20260904-220627` at `1908a3d`
  with 16 Attacker survivors. Safe decorated-window wrapper is active; final
  monitor outcome and owner evaluation are pending.

## Canonical baseline

- Active repository: `/Users/johnnguyen/Projects/car-fight` on `master`.
- Code-health audit baseline: `d949ba7`; validated audit head: `02c4829`.
- Engine: Godot 4.7.1 with Rapier 0.8.39.
- Renderer: Compatibility. Keep SSAO, directional shadows, native fullscreen,
  borderless fullscreen, and edge-to-edge windows disabled on this Intel Mac.
- Low Poly City is the sole authoritative world and map ID `0`.
- The deployed macai2 service uses native ENet on UDP 10080 and WebRTC
  signaling on TCP 10181. Use `ssh macai2-ts` and do not deploy as an implicit
  part of local work.

Read `AGENTS.md` for mandatory project rules and `.ai/CONTEXT.md` for the stable
architecture index. Read `GODOT_46_TO_47_HISTORY.md` before changing the engine,
renderer, lighting safety policy, Rapier, caches, or world architecture.

## Accepted: targeting optimization merged into canonical master

- Owner authorized merging `codex/targeting-optimization` into canonical
  `master`, preserving the newer modern-sprite and baked-shadow changes.
  Source worktree `/Users/johnnguyen/Projects/car-fight-targeting` was removed
  at owner request after verifying its clean state and ancestry in `master`.
  Profiling evidence was copied and hash-verified under ignored
  `.crash-runs/worktree-archive/targeting-optimization/runs/`. Local art matched
  canonical assets. The merged local/remote branch is retained.
- Acquisition applies the existing triangular coverage before visibility,
  skips candidates that cannot beat the nearest visible selection, and shares
  one candidate traversal/inverse transform/lazy ray setup across ready zones.
  Overlapping zones share each candidate's ray result within this call only.
  No cross-tick cache, scan throttling, cooldown, authority or wire changes.
- The first pass was committed/pushed as `3403e4a`. Follow-up matched headless
  256-fixture results: eager 12.233 ms, first pass 1.411 ms, shared pass 0.589 ms
  median per four zones. Shared scanning saves a further 58.3% in that run.
  This is acquisition CPU evidence, not rendered FPS or multiplayer capacity.
- Targeting tests cover 360 seeded comparisons, blocked fallback, ties, reversed
  tips, triangle corners, dead sprites, balls, shared overlap, cooldown masks,
  exact 15-tick firing and immediate empty-zone reacquisition. Real sprite
  combat exercises wall occlusion and matches all three selectors at 256.
- Follow-up validation passed targeting regressions, real sprite combat/CPU
  comparison, the focused server/client combat gate and `scripts/check.sh`.
  No broader state/network changes.
- Rendered profile completed after owner approval, monitor run
  `20260904-174243` clean: 256 fixtures with combat measured 20.727 ms median /
  27.135 ms P95, versus 19.827 / 23.189 ms without combat. Acquisition was
  1.560 ms per rendered frame. The historical unoptimized median was 148.97 ms;
  exact car pose and machine load are not controlled across those runs.
- Temporary instrumentation was removed after the run and retained as ignored
  diagnostic artifacts. See `docs/SPRITE_PROFILE.md` for raw evidence and limits.
- Merge validation passed `scripts/check.sh`, targeting regressions, sprite
  lab contracts (including modern samples), and live offline sprite combat.
  Focused gates cover the combined acquisition/presentation changes; no shared
  authority or transport changes warrant the broad networking suite.
- Optimization merged into `master`. No production deployment performed.

## Accepted: interactive sprite test in canonical master

- Baked-shadow trial for modern samples: confirmed translucent shadows in the
  downloaded PNGs. Changed modern-only alpha discard to opaque-prepass blending
  and ground registration from row 88 to 91 to retain soft pixels and avoid
  clipping the idle shadow's bottom rows. Depth testing and ghoul policy remain
  unchanged; no realtime shadows, physics, or networking changes. Fast check
  and expanded sprite contracts pass. Interactive run `20260904-174127` opens
  16 survivors for owner evaluation. Still a billboard shadow, not a ground
  projection. In repeat run `20260904-174641`, the owner confirmed shadows help
  ground the sprites and accepted keeping the adjustment. Added contact-shadow
  evaluation to the future-pack observations. Prone-pose alignment remains open.
- Added a local-only comparison for SmallScaleInt's two free modern exports:
  HD survivor (128px, 14 frames/clip) and outlined thug (64px, 8 frames/clip).
  `CAR_FIGHT_SPRITE_SAMPLE=survivor` or `thug` selects one at launch;
  Debug → Sprite test… → Character (local) switches live. Ghoul stays default.
  Source PNGs/archives remain ignored under `assets/local/smallscale-modern/`;
  setup/license notes are in `docs/SPRITE_MODERN_SAMPLE.md`. No paid creator,
  gameplay, collision, RPC, or targeting changes. These are sample art only.
  Fast check, expanded sprite contracts (including both local packs), and live
  offline sprite combat passed. Captures show both samples in-world; survivor
  death has ground clipping in some directions that still needs alignment work.
  Monitored capture runs `20260904-170858` and `20260904-171027` were stopped
  explicitly after their screenshot helpers waited on further rendered frames;
  neither completed the full perspective/UI capture sequence. Owner subsequently
  preferred the modern samples and found them smoother than the ghoul. Logged
  selection criteria in `docs/SPRITE_MODERN_SAMPLE.md`: prioritize gameplay-scale
  readability, pose spacing, loops and stable registration over raw frame counts.
  All samples have eight directions and default to 12 animation FPS; the exact
  comparison settings were not recorded and proposed causes remain hypotheses.
  Death alignment still needs work. No default change or purchase authorized.
  Start with 16, not a new performance stress test.
- Owner confirmed the spread-out 256-fixture slowdown on a repeat run; 128
  felt better. CPU profiling now identifies automatic target acquisition as
  the dominant cause, not a demonstrated sprite rendering limit. The matched
  256 test measured 148.97 ms median with combat versus 16.38 ms without it;
  acquisition used about 98% of combat CPU and performed about 57,000 visibility
  checks/second before range/angle filtering. See `docs/SPRITE_PROFILE.md`.
  Temporary instrumentation was removed; no optimization or deployment made.
  Next: filter range/angle before visibility queries, preserve targeting rules,
  then rerun 256 with full combat and owner driving/shooting validation.
- Research handoff saved in `docs/SPRITE_PROFILE.md` under "Next-session
  handoff": filter existing triangular coverage first, skip visibility checks
  that cannot change nearest-visible selection, and reuse per-tick setup.
  Preserve ties, blocked-nearest fallback, reversed-tip geometry and firing
  cadence. Defer scan throttling/spatial grids until reprofiled. Owner requested
  documentation only at this checkpoint; no targeting optimization implemented.
- Follow-up requested: raise the practical test ceiling and spread fixtures
  out. Added 128/256 count options and a street layout with at least four-unit
  initial separation, building clearance and a six-unit clear zone around the
  observer. Half the mixed fixture walks with staggered phases. Start with
  `CAR_FIGHT_SPRITE_COUNT=256 ./scripts/play_monitored.sh --offline --sprite-test`.
  Earlier performance samples below describe the original compact layout.
- Spread-layout validation passed: fast check, 256-position spacing/bounds
  checks at 100% and 200% scale, live sprite combat through all count options,
  and the 256-target two-client replication/late-join/MTU gate. Interactive
  monitored run `20260904-162251` was opened for owner evaluation.

- Session scope: evaluate sprites in Car Fight using the CC0 ghoul pack as
  sample art. This is not a zombie gameplay direction.
- Launch `./scripts/play_monitored.sh --offline --sprite-test`, or use
  `--local --sprite-test` for a local dedicated server/client. The ordinary
  launch stays unchanged; controls are under Debug → Sprite test….
- Eight-direction idle/walk/attack/death sprites support shared, on-demand
  128px/512px atlases, stable foot registration, camera-relative facing, local
  previews, and 1/16/64 server-controlled fixtures.
- Upright capsule hitboxes take three confirmed weapon/area hits to die.
  Swept contact with the actual scaled vehicle capsule kills immediately and
  never changes vehicle velocity. Death removes collision/target eligibility;
  reset restores health. Moving targets use lightweight updates, not rollback
  bodies. Reliable generation-fenced state handles hits, death and late joining.
- `docs/SPRITE_TEST.md` records commands, architecture, focused verification,
  measurements and limits. Source/CC0 metadata and the reproducible packer are
  included with the imported sample.
- Monitored visual runs `20260904-145702` and `20260904-150019` exited cleanly.
  At 16 fixtures, the 128px sample measured 16.68 ms median / 18.82 ms P95 and
  about 11 MiB additional texture memory; 512px used about 91 MiB additional.
  Keep 128px as default. At 64 fixtures, frame cost increased; some fixtures
  were outside the viewport, so this is not an all-visible crowd limit.
- Both runs showed an approximately 6.9-second initial rendering stall before
  warmed sampling. No claim is made about cold-start/network rendering latency.
- Owner accepted the sprite test after single-client runs `20260904-160642`
  and `20260904-161030`; both exited cleanly. Implementation is committed as
  `4a1324b` on canonical `master`. No production deployment occurred.
- Owner visual feedback: the sprites look okay as a proof of concept; more
  directional views and a higher animation frame rate could make them look
  good. Keep these as follow-up evaluation priorities, not completed changes.
- Verification: fast check; sprite asset/animation/capsule tests; live offline
  sprite combat; baseline offline and combat gates; and the 64-target server /
  two-client gate for hit/death replication, late joining and owner controls.
  Movement snapshots are batched to stay below the unreliable packet MTU.

## Accepted checkpoint: ramming lab, vehicle tuning, and scatter props

- Active feature worktree: `/Users/johnnguyen/Projects/car-fight-ramming-gameplay`
  on `codex/ramming-gameplay`, based on `master@cea2a3b`.
- The opt-in `--ramming-lab` starts three server-controlled, ordinary-physics
  vehicle drones on fixed opposing lanes at about six units/second. The Humvee,
  Apocalypse Bus, and LP Car cover separated-wheel, bounded-wheel, and
  body-baked-wheel presentation paths. Recovery occurs only after a bounded
  stall, overturn, off-course interval, or leaving the city.
- The lab isolates vehicle contact by disabling its existing server driver,
  ball, shield drone, and automatic combat. Server contact telemetry records
  the unchanged pre-enhancement collision baseline. The owner accepted the
  lab's traffic and general feel in monitored local runs.
- Vehicle size and mass are independent authoritative spawn properties. The
  compact `Vehicle Tuning…` popup exposes local draft and server-approved
  values, per-model mass defaults/weight classes, reset, collision visibility,
  and explicit `Apply & Respawn`. The reliable prepare/ack/drain replacement
  preserves the same player ID with a fresh generation and avoids stale input
  reaching the replacement path.
- The three lab drones use authoritative 150% model/collider sizing and
  representative masses: Humvee `3.2`, Apocalypse Bus `4.5`, LP Car `1.6`.
  The equal-speed collision gate proves the lighter car receives the larger
  velocity change. Debug collision capsules can be shown for every replicated
  vehicle at once and remain enabled through respawns.
- Twelve server-owned city-pack scatter props now occupy the ramming lanes:
  four barrels, four crates, two tires, and two mailboxes. Their masses range
  from `0.08` to `0.18`, use ordinary rigid-body response and CCD, and replicate
  through stable reserved negative StateBundle routes. Missing local art falls
  back to simple procedural meshes; the city extractor emits the selected
  visual library when the ignored source pack is present.
- Owner acceptance: vehicle tuning/respawn, all-vehicle capsule display, and
  the scatter-prop visual pass were tested interactively and accepted for
  commit.
- Validation passes: `./scripts/check.sh`, focused vehicle tuning, sizing,
  animation, ramming-lab, scatter-prop, city-audition, and StateBundle tests;
  `./scripts/vehicle_size_respawn_test.sh`;
  `./scripts/vehicle_mass_collision_test.sh`; and
  `./scripts/ramming_lab_test.sh`. The last gate replicated all 12 props and
  measured a `7.40` peak scatter speed. Monitored runs through
  `20260903-185440` ended cleanly or were owner-closed after evaluation.
- No deployment was performed or authorized.

Next checkpoint: tune explicit arcade ram response in small accepted steps—head
on first, then side swipe, drift slam, boost ram, and finally bounded airborne
knock-up—while preserving server authority, rollback determinism, mass ratios,
and the chassis/wheel presentation response.

## Completed work: camera tuning and opt-in always-forward experiment

- Merged to `master` from `codex/always-forward-camera` at `48732a2`, originally
  based on `master@b6c2fa0`. The completed worktree was removed after its three
  monitored runs were preserved under
  `.crash-runs/worktree-archive/always-forward-camera/runs/`; the merged branch
  remains as a recovery reference.
- The presentation-only camera experiment remains available but now starts
  disabled after the owner found the rotating-world orientation disorienting.
  Its toggle is deliberately session-only, so saved tuning can never make the
  experimental orientation replace the standard camera on a later launch.
  When enabled it keeps the local vehicle nose returning to screen-up. The first owner pass found that its hard
  22-degree bound forced near-1:1 world rotation and felt disorienting. The
  comfort revision instead uses a 10-degree active-turn soft zone and caps
  camera rotation at 95 degrees/second, then settles fully after the turn.
- Speed-scaled travel look-ahead now has separate acceleration and braking ease
  responses. Simulation, authority, rollback, and wire state are unchanged.
- The native Debug system menu contains an enable/disable comparison toggle and
  a `Camera tuning…` window. Turn catch-up, comfort zone,
  maximum camera turn speed, viewing angle, zoom, orthographic/perspective
  projection, look-ahead distance, acceleration ease, and braking ease update
  live and autosave locally. The comfort revision lowers
  the default pitch from the original 55 degrees to 48 degrees so building
  sides provide a stronger depth cue. Tool-window focus sends neutral controls.
- Gameplay status text and control hints now both start hidden. Separate Debug
  menu checks can restore either during development; browser hints require the
  explicit `hotkeyHints=1` query value.
- Validation passes: `./scripts/check.sh`, `tests/always_forward_camera_test.gd`,
  `tests/always_forward_camera_ui_test.gd`, `tests/sense_of_speed_test.gd`,
  `tests/asset_smoke_test.gd`, `tests/home_world_lighting_test.gd`, and
  `./scripts/offline_test.sh`.
- The owner rejected always-forward world rotation as the default but accepted
  merging it as an opt-in comparison alongside the general camera controls.
  No deployment was performed or authorized.

## Completed work: combined feature merge

- `master` now contains `codex/lighting-editor`, `codex/city-draw-order`, and
  `codex/ch-011-authority-probe` plus the accepted follow-up
  `codex/lighting-editor-input-focus`. Their four merged worktrees were removed
  after validation; the branches remain available as recovery references.
- Ignored monitor evidence from those worktrees is preserved under
  `.crash-runs/worktree-archive/` in the canonical repository.
- Combined validation passes: `./scripts/check.sh` and the complete
  `./scripts/test.sh`, including lighting/window policy, city presentation,
  authority-probe delivery, ENet, mixed transport, join, and reconnect gates.
- No deployment was performed. The macai2 production service remains separate.

## Completed work: Lighting Editor input focus

- Merged from `codex/lighting-editor-input-focus`, based on merged
  `master@9a1da6b`; its completed worktree has been removed.
- Owner testing showed that focusing the native editor, especially its look-name
  field, left vehicle keyboard state partially responsive while the game
  viewport's mouse position stopped updating. This was UI focus behavior, not
  the sustained rollback/network stall.
- Live vehicle input is now explicitly neutral whenever the Lighting Editor
  owns native-window focus. Clicking the game resumes normal mouse control; a
  visible `Return to game` button and submitting a look name also return native
  focus to the game window.
- Focused validation passes: `./scripts/check.sh`,
  `tests/home_world_lighting_test.gd`, `tests/asset_smoke_test.gd`, and
  `./scripts/offline_test.sh`.
- The owner verified the native macOS focus handoff in monitored run
  `.crash-runs/worktree-archive/lighting-input-focus/runs/20260902-225127`:
  after selecting the look-name field, returning to the game restored normal
  mouse steering. The result was accepted.

## Completed work: live lighting editor

- Merged from `codex/lighting-editor`, originally based on `master@353f824`;
  its completed worktree has been removed.
- The native `Scenery` system menu now opens a transient `Lighting Editor`
  window modeled on G2's live tuning UI. It starts from the selected lighting
  preset and updates the local presentation in real time.
- The editor is deliberately limited to nine high-impact choices: sun color,
  brightness, height, and direction; world fill; exposure; saturation; and
  positional contact-shadow visibility/darkness. It does not expose SSAO,
  directional shadows, renderer selection, or other unsafe/low-value knobs.
- `Reset to selected preset` discards experimental edits. Selecting another
  existing Scenery preset also refreshes the open editor to that preset.
- Each edit now autosaves a working look under `user://`; the look and its
  built-in base preset restore on the next launch. The same window can save,
  load, overwrite, and delete named look snapshots.
- The editor is a compact 470x540 native child window. It remains at native
  pixel size instead of growing with the game's fixed-viewport canvas stretch
  when the main window is resized.
- New Car Fight worktrees must run `./scripts/sync_local_assets.sh` immediately
  after creation. The tracked `AGENTS.md` rule and helper physically copy only
  the required ignored city and Collection tree families from a registered
  donor worktree; no symlinks, destructive sync, or retired audition packs.
- The Intel Mac window guard no longer imposes its former fixed 1280x720 cap.
  Ordinary decorated windows can be resized freely while they remain within
  the 48-pixel safe inset; fullscreen, maximized, borderless, and edge-to-edge
  presentation remain blocked.
- Validation passes: `./scripts/check.sh`,
  `tests/home_world_lighting_test.gd`, `tests/window_safety_policy_test.gd`, and
  `./scripts/offline_test.sh`. The local-asset bootstrap also passes its own
  `--check` plus the focused city-audition and tree-library tests from a
  previously empty feature worktree.
- Optional follow-up: one owner-approved monitored visual pass in an ordinary
  inset window to judge layout and whether the controls produce useful looks.

## Completed work: code health

- The owner approved and `master` was fast-forwarded from
  `codex/code-health-audit` through validated head `02c4829`.
- The cleanup worktree and branch remain available until a separately approved
  repository-housekeeping pass; do not delete them implicitly.
- Evidence ledger: `docs/CODE_HEALTH_LEDGER.md`.
- Stable architecture/index context now lives in `.ai/CONTEXT.md`. The shared
  project registry resolves `car-fight` to the active Godot repository and
  marks `car-fight-unity` archived. `.ai` intentionally remains tracked locally
  until its separate shared-storage decision.
- Cleanup must remain separate from gameplay, visual tuning, bug fixes, engine
  changes, and optimization.
- Networking, rollback, transports, RPC/state schema, physics feel, rendering
  behavior, and vendored netfox patches remain protected and are audited last.

Completed branch commits:

- `ece1668` — shared Claude/Codex project rules, risk-based quality gates, quiet
  fast check, and removal of three orphan UID sidecars.
- `6cb93cd` — code-health evidence ledger.
- `37ff6eb` — one shared two-pass Godot import verifier used by the fast check,
  complete suite, deployment import, and Web build.
- `177e7f2` — reduced the auto-read phase handoff to current information and
  preserved the former 890-line phase history under `docs/history/`.
- `668dc96` — added stable project architecture/context; the matching
  `claude-comms` registry repair is commit `234335f`.
- `2268137` — recorded the stale files retained on macai2 by non-deleting
  deployment sync; its original manual count of 31 was later corrected to 33.
  No remote file was changed.
- `f73ff79` — added a structural manifest guard; it now covers all 33 standalone
  GDScript tests without executing them during the fast check.
- `bcf13d9` — the macai2 deployment helper now defaults to a read-only preview,
  requires an explicit `apply` from a clean `master`, and preserves
  generated/local state.
  Its preview matched the exact 33 stale files plus two empty directories;
  nothing has been deleted remotely.
- `17b2068` — recorded protected recovery refs, both active worktrees, and 20
  merged local plus 20 merged remote cleanup candidates. No ref was deleted.
- `a38b91c` / `ba2b903` — characterized the server `RESULT` schema and moved
  its pure 32-field formatter outside `Main.gd`. Metric collection, report
  timing, gameplay, authority, RPCs, and transport behavior are unchanged.
- World/spawn layer: removed the city-only `_build_home_world()` forwarding
  wrapper. Focused checks pass, and the owner confirmed the complete city and
  dots during monitored local server/client play; the monitor ended cleanly.
- CH-013 records that offline startup does not seed dots. This predates the
  cleanup and remains separate gameplay bug debt.
- World/presentation layer: removed the unreachable proximity-landmark tree
  builders and their no-op Tree model menu. The owner confirmed city trees and
  retained lighting controls in monitored local play; the monitor ended cleanly.
- World/presentation layer: removed the obsolete local prop audition, which
  spawned visual-only props beyond the accepted north city wall. Focused city,
  lighting, and fast checks pass; the owner confirmed normal city, street-tree,
  dot, driving, and lighting behavior in monitored local play, and the monitor
  ended cleanly.
- World/presentation layer: reduced the tree visual library to the sole accepted
  Collection 121–130 family and removed the unreachable 37 MB Shapespark
  audition package. Focused tree, city, lighting, and fast checks pass; the
  owner confirmed the complete street-tree lining and normal play, and the
  monitor ended cleanly.
- World/construction layer: folded the obsolete arbitrary-rotation static-box
  helper into the live yaw-only city builder after tracing its removed ramp and
  upper-road callers. Focused city and reverse/wall checks pass; the owner
  confirmed building and outer-wall collision, and the monitor ended cleanly.
- Player layer: removed three uncalled helper methods while preserving their
  live backing state, setters, gesture fields, rollback schema, and correction
  sampling; corrected the stale sphere-collider comment to the accepted capsule.
  Focused vehicle, area-weapon, correction, and fast checks pass; the owner
  confirmed driving, vehicle cycling, and area targeting, and the monitor ended
  cleanly. CH-018 records removed-gate state that remains protected on hold.
- Combat layer: removed the uncalled shield-drone aiming method while preserving
  Main-owned targeting, projectile authority, timing, muzzle position, and
  current fixture orientation. Focused asset and shield runtime checks pass;
  the owner confirmed the drone shot and shield interaction, and the monitor
  ended cleanly.
- Documentation checkpoint: updated README and nearby comments that still
  described the retired tree/prop auditions, old arena size, sphere collider,
  ramps/map gates, and an outdated vehicle-mesh contract. Fast structural and
  exact stale-phrase checks pass; no runtime files changed.
- Network/rollback layer: removed three uncalled, side-effect-free transport/
  cadence query getters while preserving MultiplayerPeer overrides, transport
  ownership, routing, internal cadence decisions, state, and wire behavior.
  Focused StateBundle/codec/remote-position checks pass; the owner confirmed
  normal ENet play, and the monitor ended cleanly. Dormant recovery/failure
  injection seams remain protected on CH-022 hold.
- Scripts/tooling layer: removed the historical sunlit-aerial launcher after
  tracing the lighting/map selections that once distinguished it, and removed
  two unconsumed no-ramp environment assignments. Distinct Networking 1,
  Networking 2 mixed, and shaped one/two-client direct-entry harnesses remain.
- Agent-scaffolding layer: corrected the shared `AGENTS.md` collider and scope
  language to match the accepted capsule, existing bounded weapons, and the
  opt-in G2 lab stack. `CLAUDE.md` remains its relative symlink so both agent
  clients receive one project policy.
- Documentation-routing layer: marked the completed engine, Web, and Networking
  1/2 plans as historical snapshots; current sessions now route through README
  and stable context. README reflects accepted forced-TURN reconnect/two-player
  evidence and the deployed ENet/WebRTC mux while retaining unfinished public
  browser hosting/TURN and opt-in experiment boundaries.

Validation for the import-verifier cleanup:

- `./scripts/check.sh` passes.
- `./scripts/server_daemon.sh import` passes.
- A bounded Web Offline debug export passes.
- The test-manifest positive check and omitted-test negative control pass.
- At that import-only checkpoint, the complete gameplay/network suite was not
  run because the change affected validation tooling only.

Accumulated cleanup-boundary validation:

- After the final layer audit, all 33 focused GDScript contracts pass once.
  The WebRTC harness lifecycle, offline smoke, late-join recovery, reconnect,
  ball, tractor, reverse, combat, RC-orb, shield, and det gates also pass once
  at the final milestone.
- `network_test.sh` and `mixed_transport_test.sh` fail because no queued
  authority probe reaches clients. Both failures reproduce on untouched
  `master@d949ba7`, so they are recorded as pre-existing CH-011 network-test
  debt rather than a cleanup regression and were not wastefully rerun at the
  final milestone.
- The first sandboxed WebRTC lifecycle attempt failed with loopback
  `listen EPERM`; its required unsandboxed rerun passed.

## Completed work: CH-011 authority-probe delivery

- Merged from `codex/ch-011-authority-probe`, originally based on
  `master@353f824`; its completed worktree has been removed.
- Historical tracing found the intended consumer in sibling city commit
  `b20bb6a`. Promotion commit `3ccd8fe` retained the 20-tick delay constant,
  queue producer, and client receiver but omitted the loop that dequeued mature
  samples and sent them to their owning peers.
- Restored that exact bounded delivery seam before new samples are scheduled.
  It rechecks the live peer list at delivery time, preserving the existing
  disconnect-race guard, unreliable RPC contract, cadence, and authority model.
- Added `tests/authority_probe_delivery_test.gd` to prevent another partial
  promotion from leaving the queue without its delayed consumer.
- Focused validation passes: authority-probe delivery contract, fast check,
  ENet `network_test.sh` (1.674-unit worst correction), mixed ENet/WebRTC
  `mixed_transport_test.sh` (0.300), late join, and reconnect.
- The required integration-boundary `./scripts/test.sh` passes completely. Its
  ENet run reported a 1.834-unit worst correction and mixed transport reported
  0.300; all lifecycle and gameplay gates passed. The initial sandboxed ENet
  attempt failed only because local UDP bind was denied, and the required
  unsandboxed run passed.
- A two-rendered-client check used this exact branch on a temporary isolated
  macai2 server at UDP 12680; production UDP 10080 was not modified. Probe
  delivery worked, but sustained play failed: Alpha and Bravo reached 91.671
  and 92.553-unit corrections, respectively, and each client's remote-player
  view froze. Evidence is preserved under
  `.crash-runs/worktree-archive/ch011/runs/two-client-20260902-221336/`.
- The live failure followed a shared performance/rollback stall around
  22:14:53. Bravo reported a 562 ms process interval and 232-tick rollback
  depth; Alpha then reported a 653 ms process interval with deep rollback.
  Both exceeded the retained 64-tick history, stale-authority recovery repeated,
  and fresh body state did not converge even though the server kept ticking.
  The temporary server was stopped and production UDP 10080 remained running.
- The identical control used matching `master@353f824` clients and a temporary
  isolated macai2 server at that exact commit. It reproduced the large shared
  freeze, stale-history recovery loop, and an even stronger failure: macai2
  timed out and removed both peers while their windows continued producing
  inactive-multiplayer errors. The user saw the major freeze but no persistent
  split because both clients had disconnected. Evidence is preserved under
  `/Users/johnnguyen/Projects/car-fight/.crash-runs/two-client-20260902-222423/`.
- This control establishes that the sustained rendered stall/recovery failure
  predates restored probe delivery. Keep that investigation separate from
  CH-011; the probes make divergence measurable but do not mutate simulation
  state. Both temporary macai2 servers were stopped, and production UDP 10080
  remained running throughout.

## Next

1. Open the pre-existing sustained rendered stall/recovery failure as a separate
   networking worktree/task, preserving both captured runs. Do not repeat
   rendered testing without explicit owner approval.
2. Decide separately whether tracked `.ai` state should move into the shared
   `claude-comms` symlink model; preserve history and account for concurrent
   worktrees before changing storage.
3. Apply the reviewed 33-file/two-directory macai2 cleanup only after explicit
   owner approval from clean `master`. Its old
   remote `gate_test.sh` still consumes the constant-zero course/gate `RESULT`
   fields, so retain that output contract until deployment state is resolved.
4. Review the branch-ledger candidates; delete no ref without separate owner
   approval and a fresh merged/ancestor check.
5. Treat the characterized result-report boundary as the limit of this cleanup;
   argument parsing and any further `Main.gd` extraction remain on hold.

The complete former phase log is preserved at
`docs/history/CURRENT_PHASE_THROUGH_2026-09-02.md`.
