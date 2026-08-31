# Current phase

## Godot 4.6.3 Forward+ Intel experiment ready for review

- Isolated on `codex/forwardplus-46-rendering` at
  `/Users/johnnguyen/Projects/car-fight-forwardplus-46`, based on the completed
  sunlit city worktree; both `master` and the Compatibility study are untouched.
- Pins the project to Godot 4.6 Forward+ and replaces Rapier 0.8.39/API 4.7 with
  the official Rapier 0.8.35 enhanced-determinism/API 4.6 release. The published
  release archive SHA-256
  `f6477144bccf8002c71647193444bd540ed648204d84e6e69919f4affafbf414`
  was verified before installation.
- Starts with a lean Intel baseline: real clustered Forward+, 2048 cascaded sun
  shadows, low SSAO and 2x MSAA at 1280x720. SSIL, SSR, SDFGI and TAA remain off
  until stability and driving frame rate are measured.
- The monitored human run initialized as `Vulkan 1.2.283 - Forward+` on the Intel
  Iris Plus and exited cleanly. It had one 20.2-second first-cache shader stall
  plus a non-fatal MoltenVK pipeline-cache write warning, but none of Godot 4.7's
  compute-pipeline compile/null-dispatch failures. Ten focused driving samples
  ranged from 16–145 FPS and averaged 58.8 FPS, with 94–101 draw calls, at most
  44.6k visible primitives and about 216 MB reported video memory.
- Human visual review accepted the lean Forward+ city baseline as looking good;
  preserve these settings as the comparison point before enabling heavier effects.
- Presentation, city and deterministic physics gates pass. The permission-correct
  full suite also passes its unit tests, WebRTC lifecycle, offline, latency,
  mixed-transport and join-transient stages. Its reconnect stage stops only
  because Godot 4.6 emits `1 resources still in use at exit` for each deliberately
  short-lived client and the strict scanner classifies any `ERROR:` line as a
  failure; this shutdown-only 4.6 compatibility warning remains to resolve.

## Sunlit aerial city driving worktree ready for review

- Isolated on `codex/sunlit-aerial-rendering` at
  `/Users/johnnguyen/Projects/car-fight-sunlit-aerial`; `master` is untouched.
- Adds a fifth `Scenery > Lighting` preset, `Sunlit aerial (Intel-safe)`, porting
  the godot-aerial study's bright sky dome, warm midday key, Filmic exposure and
  restrained grade into the full Car Fight world and controls.
- Replaces the old simplified `Soft overcast (shadowless)` scenery option with
  `Overcast city HDRI`, reusing the accepted Overcast City panorama, sky ambient
  and reflections, Filmic grade, weak warm sun, and stable contact shadow while
  retaining the selected Arena/Low Poly City geometry.
- Lines both sides of the Low Poly City street grid with the owner-local
  Collection 121–130 tree family at deterministic block-center sites. Building
  footprints are excluded and the trees remain presentation-only, with no new
  gameplay collision or network state.
- `scripts/play_sunlit_aerial.sh` launches offline directly inside `LOW POLY
  CITY`, retaining the normal mouse/controller follow driving, boost, reverse,
  weapons, vehicle cycling, camera, physics, and collision behavior.
- The owner-local extracted city is shared from the main checkout without
  copying or tracking its unlicensed source files. The sunlit launcher restores
  building shadows but keeps road tiles out of the shadow pass.
- A true Forward+ port was attempted and rejected on this machine: Godot 4.7.1
  repeatedly fails to compile MoltenVK compute pipelines on the Intel Iris Plus
  and then dispatches null pipelines. The live preset therefore uses Car Fight's
  proven Compatibility renderer with a procedural sky, sky ambient/reflections,
  directional color key, and stable moving spotlight shadows. The full Forward+
  version remains appropriate for a newer GPU target.
- Focused presentation and city tests pass, as does a 180-tick direct-city
  offline boot. The monitored human drive exited cleanly. After one shader
  warm-up stall, telemetry sampled roughly 64–112 FPS, 117–136 draw calls,
  35k–43k visible primitives, and 122 MB video memory while driving in map 2.

## Next for this worktree

- Human visual call on brightness, shadow opacity, sky color, and whether the
  existing orthographic Car Fight camera should tilt closer to the drone photo.
- If the Compatibility approximation is accepted, tune materials and camera
  before adding more effects. If true Forward+ is required, move validation to
  Apple Silicon/Windows hardware rather than fighting this Intel MoltenVK path.

## Trees, foliage, and lighting audition ready for human review

- Added a third, physically separate `LOW POLY CITY` map at the south arena
  teleport pad, with a paired return pad, deterministic map transitions, a
  220-meter collision floor, and boundary walls. The local city source is far
  too heavy to load whole (491 meshes / about 3 million vertices), so the
  audition uses a small extraction of 63 placed instances from 16 meshes: a
  continuous 3x3 street grid with an entrance avenue, five houses, three shops,
  two apartment buildings, two lightweight skyscrapers, a gas station, and a
  factory. Fourteen deterministic footprint colliders keep cars on the streets.
  Dense 40k-112k triangle park
  meshes are deliberately excluded. The supplied forest EXR uses compression
  Godot cannot decode and is not used. Focused city/course/prop tests, a
  five-tick presentation boot, and the permission-correct complete
  `./scripts/test.sh` suite pass (`ALL_TESTS PASS`); monitored human review is
  next.
- Enlarged the complete city composition to 150% relative to the unchanged
  vehicles. One shared scale now expands road widths and spacing, buildings,
  deterministic footprint collision, the city floor/walls, and its entrance
  and return placement together.
- Added native-scale local auditions of six stone meshes and one ruined house
  just north of the tree corridor. Their working textures are capped at 1024px,
  shadows and collisions are disabled, and the imported files remain ignored.
  A monitored near-house pass stayed mostly around 55 FPS after one-time asset
  warm-up, with no thermal, GPU, or display fault.
- Shapespark's CC0 low-poly exterior plants kit is tracked with Git LFS and
  exposed as three four-tree families. Family 1 is the new local default; the
  prior 200-tree collection and procedural baseline remain selectable. The
  library loads only the selected source pack. All nine imported menu choices
  pass the focused normalization/fallback/shadow test.
- The first monitored offline Shapespark run paused once for 10.9 seconds while
  Godot uploaded 22 embedded textures, then remained continuous while driving
  at roughly 55-68 FPS. It used about 58 MB texture / 67 MB video memory, with
  no thermal warning, GPU reset, or recurring simulation stall.
- Work is isolated on `codex/trees-foliage-lighting` in
  `/Users/johnnguyen/Projects/car-fight-trees-foliage-lighting`. The locally
  installed ilkhom23 CGTrader pack supplies 200 one-material trees. Its Royalty
  Free License (no AI) permits incorporated game use but not source-file
  redistribution, so the FBX and 1024px atlas remain under ignored
  `assets/local/`; a clean checkout falls back to procedural trees.
- The native `Scenery` menu live-switches the procedural baseline, six
  deterministic ten-tree collection ranges, and three Shapespark families.
  Shapespark family 1 is the local default; the more detailed collection ranges
  remain explicit auditions. Every imported mesh is normalized to the existing landmark
  height, grounded, and shadow-disabled. The existing 142 static/seeded
  objects, 76-tree corridor, simple trunk colliders, gameplay, and network
  state are unchanged. Normal headless servers do not instantiate the library
  or probe the optional asset path.
- The same menu live-switches current warm shadow, G2 warm-key/cool-fill,
  G2 key/fill/rim, and soft shadowless overcast lighting. SSAO is forcibly off
  in every mode because G2 measured a roughly 55-to-10/13 FPS collapse on this
  Intel Compatibility laptop.
- Matching monitored local runs found the procedural baseline at 54.7 FPS
  average / 54 median and light collection 21-30 at 53.0 average / 54 median.
  The imported row added about 16% visible primitives and 15 MB video memory;
  its short sample minimum was 45 FPS. No GPU reset, WindowServer fault, or
  script error occurred. Detailed rows still need human visual/performance
  review before any selection is promoted.
- Project parse, focused foliage/presentation/layout checks, WebRTC lifecycle,
  offline, network (0.300 worst correction), mixed transport, join recovery,
  reconnect, ball, tractor, reverse, gate, combat, RC-orb, shield, and det
  gates pass. The latest monolithic suite hit only the documented
  timing-sensitive course sample; its immediate isolated retry passed with a
  1.651 rebound. The final focused foliage test passes all nine imported menu
  choices with the tracked Shapespark pack and local collection pack.
- Human review exposed periodic stop/start motion in the monitored `--local`
  client caused by stale authority recovery, not rendering. The monitored
  launcher now accepts `--offline` for foliage, lighting, and handling review;
  the replacement single-process run advances continuously without recovery
  events and uses substantially less CPU.

## Current decision

- The requested combined rendering/scenery integration is now on local
  `master`: `codex/trees-foliage-lighting` contributes the switchable tree
  library, Shapespark foliage audition, optional prop/city auditions, expanded
  city map, and Scenery lighting menu; `codex/rendering-styles` contributes the
  separate sparse HDRI-lit `Overcast City` world and offline-safe
  `World > Arena / Overcast City` menu. Merge resolution keeps the foliage and
  World menu command ranges separate, preserves the foliage branch's monitored
  offline launcher behavior, and prevents foliage/city audition dressing from
  leaking into the deliberately uncluttered overcast world. Combined clean
  import, shell/diff checks, normal Arena offline, Overcast City offline drive,
  presentation assets, and all four focused foliage/city/overcast tests pass.
  The complete suite again stopped only at the pre-existing timing-sensitive
  escape-assist sample; the identical miss was reproduced on untouched
  `master`. Every subsequent gate was then run manually: mixed transport, join,
  reconnect, ball, tractor, course, reverse, map gate, combat, shield, and det
  passed; RC orb missed once and passed immediately in isolation. The combined
  merge commit `566fd49` is pushed to `origin/master`.
- Rendering-style exploration now has a separate sparse `Overcast City` debug
  world on `codex/rendering-styles`. It preserves the normal car and physics but
  replaces the cluttered arena with an open cross-street, four distant building
  masses, restrained sidewalks/puddles, and the accepted CC0 Poly Haven
  Kloofendal overcast HDRI from the older `godot-aerial` study. Filmic grading,
  sky ambient/reflections, a weak directional key, and a shallow stable
  Compatibility spotlight approximate that Forward+ study without enabling the
  Intel-breaking renderer or SSAO/SDFGI. The native system menu adds
  `World > Arena / Overcast City`; it is enabled only in offline debug sessions
  and stops/restarts the offline scene so visual geometry and authoritative
  collision always switch together. `scripts/play_overcast_world.sh` launches
  this through the existing monitored, window-safe wrapper. The new focused
  world/menu test, presentation asset test, normal offline regression, clean
  import, shell syntax, and diff checks pass. The complete suite reached the
  network gate, where the timing-sensitive escape-assist sample missed twice;
  the identical gate then produced the same miss on untouched `master`, with
  clean contact/bump evidence in all three runs, confirming baseline test drift
  rather than a rendering-world regression. Human lighting/layout tuning and
  the requested combined merge with `codex/trees-foliage-lighting` are next.
- PlayStation controller support is merged to `master` at `5083b43`. The left
  stick supplies a
  camera-relative analog cursor through a radial deadzone, preserving the
  existing distance-based FOLLOW throttle and rollback input path. Cross,
  Circle, shoulders, triggers, face buttons, and D-pad cover boost, reverse,
  shield, cloak, tractor vacuum, both aimed weapons, area weapon, det, troop
  deployment, and local vehicle selection. Meaningful mouse motion returns
  steering to the mouse; left-stick motion takes it back, and disconnecting the
  active pad clears controller drive state. A focused controller regression,
  offline test, and the complete permission-correct `./scripts/test.sh` suite
  pass (`ALL_TESTS PASS`), including 0.300-unit worst correction in the 120 ms
  network gate. A windowed Godot probe detects the USB DualSense as standardized
  joypad device 0 with all six axes neutral at 0.0, and the hands-on controller
  pass was accepted as good for now. The feature worktree can be removed.
- Sense-of-speed work is merged to `master` at `ee634a6`. The normal arena now
  uses the previously proven network-test half-extent of 240 units; the separate
  driving-course world moved east to preserve its physical gap. Two broad
  boulevard corridors plus a dedicated east-side tree path are framed by 142
  deterministic static/seeded landmarks with real collision and a bounded
  focused count, spaced to clear the established server-driver route. The tree
  path uses two dense rows 24 units apart, nine-unit longitudinal spacing, and
  trees 55% taller than the ordinary landmark trees. Each presented vehicle
  now emits compatibility-safe road dust and small debris at speed plus rear
  tire smoke under fast braking/drift. The local camera gains velocity-aligned forward
  lead, a short boost-onset pullback, subtle burst-speed vibration, and jolts on
  drift commitment, wall bumps, and weapon impacts; none of these presentation
  cues feed physics, rollback, or network state. Focused layout/camera/FX,
  vehicle-animation, forced-presentation, offline, and 120 ms networking checks
  pass. After the denser tree path and smoke-variation follow-ups, the complete
  post-merge `./scripts/test.sh` suite passes (`ALL_TESTS PASS`), including the
  120 ms network gate at 0.300-unit worst correction and the RC-orb, shield,
  and detonation gates. Human rendered feel review remains next so lead, boost
  lag, vibration, particle density, landmark spacing, and the varied large
  smoke silhouettes can be tuned together.
- The first tire-smoke presentation has been replaced after human feedback that
  its equal flat particles looked generated rather than smoky, then enlarged
  again after feedback that the first layered follow-up still read as small
  particles. The exact accepted G2 isometric campfire reference was recovered
  from commit `8178080`: its detailed 512px CC0/MIT smoke card is now preserved
  locally with source/license metadata. Tire smoke uses only 22 darker core
  cards and broad haze cards randomized like that reference. A second human
  review found that revision still too small, sparse, and brief to see. The
  current intentionally overt calibration uses 48 darker core cards and 36
  haze cards; outer billows grow to 15.4 units and linger for seven seconds in
  world space. Slower drift, damping, rotation, lifetime variation, expansion,
  higher opacity, and grey fade make adjacent cards overlap into a cloud. The smoke
  remains compatibility-safe, client-local, and driven by the same synchronized
  skid values. Focused asset/scale/lifetime coverage, clean import,
  forced-presentation construction, and vehicle-animation checks pass. Fresh
  rendered feedback then found the enlarged card's repeated silhouette too
  obvious. The source card now produces a four-frame atlas: original, mirrored,
  wide-cropped, and tall-cropped silhouettes. Every puff randomly selects a
  frame and combines it with 42–100% scale, 64% lifetime, emission-time, and
  rotation variation, removing synchronized stamped copies. Focused variation
  coverage, forced-presentation construction, and the complete post-merge suite
  pass. Fresh human review is next.
- LowPoly Cars 01 is imported as 30 additional local presentation choices,
  bringing the `V` cycle to 40 models. The owner-supplied FBX contains 23 cars,
  four trucks, three tractors/construction vehicles, 11 loose wheel samples,
  and two empty helpers; only the 30 intact vehicles are exposed. They share
  the supplied 1024px color atlas, while redundant 128/256/512/2048 copies are
  omitted. The source includes no author, URL, readme, or license metadata, so
  the asset note records that absence without making a license claim. A static
  subtree extractor recenters each selected display model and preserves its
  complete atlas mesh; most models bake wheels into that mesh, so those wheels
  remain visually intact rather than risking body damage from guessed cuts.
  The two sideways semis are normalized separately. A 30-model overview plus
  representative car/truck lab renders confirmed texture mapping, complete
  geometry, scale, and forward axes against the player-corrected Survival
  Vehicle reference. Every model has a collider-safe default scale and retains
  its own 100–500% debug scale setting. Clean import, 40-vehicle asset coverage,
  live atlas-model construction, animation/scale coverage, offline, 0.300-unit
  network, join, reconnect, ball, tractor, reverse, jump-gate, combat, shield,
  and detonation gates pass. Mixed transport, course rebound, and RC-orb each
  missed one timing sample, then passed immediately in isolation (mixed also at
  0.300 units). Gameplay collision, physics, rollback, and network state remain
  unchanged.
- LowPoly Cars 01 follow-up fixes the pack's mixed mirrored transforms. Every
  static subtree now flips triangle winding when its accumulated FBX transform
  has a negative determinant, then regenerates low-poly normals from the
  corrected triangles. This fixes partially inverted grouped vehicles and the
  fully mirrored C02, C05, and C08 cars while preserving atlas UVs/materials.
  Because their wheels are baked into intact meshes, each pack model now also
  receives four invisible presentation-only wheel-contact anchors; the rear
  pair feeds the existing braking, drift, boost, and oil skid ribbons without
  cutting or duplicating visible wheels. A fresh 30-model render confirms
  consistent exterior lighting and complete geometry. Focused 40-vehicle asset,
  live contact-anchor, animation/scale, and skid-trail coverage pass, followed
  by a clean full `./scripts/test.sh` run (`ALL_TESTS PASS`, including 0.300-unit
  network and mixed-transport corrections). Gameplay collision, physics,
  rollback, and network state remain unchanged.
- Survival Vehicle is imported as the tenth local presentation model on
  `codex/more-vehicles`. The owner-supplied zip contains one FBX and albedo,
  normal, metallic, and roughness maps, but no author, source URL, readme, or
  license; the asset note records that absence without making a license claim.
  Runtime maps were reduced to 1024px. The source combines its body and wheels
  in one mesh, so six tight bounds extract all three axles into independent
  animation pivots, with the front pair steering and all six wheels spinning
  and feeding skid presentation. A rendered vehicle-lab capture confirmed the
  armored body, cargo, full PBR texture assignment, scale, and intact six-wheel
  layout. Player verification caught the FBX facing backward; its presentation
  yaw is corrected by 180 degrees and focused asset/animation checks pass.
  Gameplay collision, physics, rollback, and network
  state remain unchanged. Clean import, ten-vehicle asset coverage, animation
  coverage, and the complete offline suite pass. The subsequent timing-sensitive
  network gate produced inconsistent pre-existing authority/escape-assist
  samples across retries; no presentation asset is loaded on its headless path.
- Post-Apocalyptic UAZ is imported as the ninth local presentation model on
  `codex/more-vehicles`. The owner-supplied FBX and texture 7z contain no author,
  source URL, readme, or license, so the asset note records that absence without
  making a license claim. Four PBR sets cover the yellow/rusted body, wheels,
  frame, and roof/accessory equipment; their 2048–4096px albedo, normal,
  metallic, roughness, and available AO maps are reduced to 1024px, while
  unused height maps are omitted. The FBX's four named wheel nodes feed the
  existing separated-wheel presentation path. A rendered vehicle-lab capture
  confirmed orientation, scale, emergency-service body, roof tanks/racks,
  texture assignment, and intact wheel pivots. All vehicle scenes and imported
  PBR maps now resolve lazily only when selected, keeping the growing visual
  library out of dedicated/headless startup. Gameplay collision, physics,
  rollback, and network state remain unchanged. Clean import, nine-vehicle
  asset coverage, animation coverage, offline, 0.300-correction network, mixed
  transport, join, reconnect, ball, tractor, course, reverse, jump-gate,
  combat, RC-orb, shield, and detonation gates pass. Reconnect and shield test
  windows were extended to retain their strict assertions after larger project
  resource scans; a stale RPC-cache reconnect sample failed once, then its
  immediate repeat passed.
- The native `Vehicle Model` menu now stores an independent presentation scale
  for each of the eight vehicle names instead of one shared multiplier. Its
  disabled status row identifies the currently selected vehicle, `V` restores
  that next vehicle's own saved value, reset affects only the current vehicle,
  and the available presets now extend from 100% through 500% with finer steps
  above the old 200% ceiling. Existing single-value config files migrate that
  value to all vehicles on first load; subsequent saves use the per-vehicle
  dictionary. Chassis, wheels, weapon mounts, cloak, boost echoes, and skid
  contacts still rebuild together while collision, physics, rollback, and wire
  state remain unchanged. Clean parse and focused scale/animation coverage pass.
  The permission-correct full suite passed all focused/offline checks, then its
  timing-sensitive 120 ms network gate missed one same-tick probe sample. The
  immediate isolated retry passed at 0.662-unit worst correction; mixed
  transport, join recovery, reconnect, ball, tractor, course, reverse, jump
  gate, combat, RC-orb, shield, and detonation gates all pass afterward.
- Apocalypse Bus is imported as the eighth local presentation model on
  `codex/more-vehicles`. The owner-supplied RAR contained one FBX and four
  numbered PBR texture sets but no author, source URL, readme, or license, so
  the asset note records that absence without making a license claim. The FBX
  was converted to GLB with repaired local texture references; albedo, normal,
  metallic, and roughness maps were reduced from 2048px to 1024px, while unused
  height maps were omitted. A bounded material-aware splitter extracts the four
  wheel assemblies from material 3 without pulling nearby armor into the wheel
  rig, normalizes the FBX's sideways source axis, and retains all four PBR body
  materials. A rendered vehicle-lab capture confirmed the rusted yellow bus,
  armor/cargo details, orientation, scale, and intact wheels. Gameplay collision,
  physics, rollback, and network state remain unchanged. Clean import, focused
  asset/animation checks, and the full permission-correct `./scripts/test.sh`
  suite pass (`ALL_TESTS PASS`), including 0.300-unit worst correction in the
  120 ms network gate.
- Combat Vehicle Ver 1.02 is imported as the seventh local presentation model
  on `codex/more-vehicles`. The free-use Yoon's GameART source license is
  preserved beside the assets. The supplied FBX was converted to a clean GLB;
  its dark X-cam body albedo, normal, metallic, and occlusion maps and tire
  albedo/normal maps are applied explicitly. The presentation splitter now also
  handles a separate chassis plus one combined four-wheel mesh, clustering that
  mesh into four independently animated wheels. Scale, placement, texture, and
  wheel separation were confirmed in a rendered vehicle-lab capture. Gameplay
  collision, physics, rollback, and network state remain unchanged. Clean
  import, focused asset/animation checks, and all full-suite gates pass. The
  complete run reached the RC-orb gate after a 0.300-unit worst correction in
  the 120 ms network test; that timing-sensitive gate missed once, then passed
  immediately in isolation along with the remaining shield and detonation
  gates.
- The Humvee worktree now has a native `Vehicle Model` system menu beside
  `Oil Slick`. It applies a client-local, presentation-only 100%, 110%, 125%,
  150%, 175%, or 200% multiplier to the currently selected vehicle and keeps
  that multiplier while cycling with `V`. Chassis, separated animated wheels,
  wheel-roll radius, weapon-mount height, boost echoes, cloak wipe, X-ray, and
  skid contact presentation rebuild together; gameplay collision, shield size,
  physics, rollback, and network state do not change. Reset returns to 100%,
  and native client/offline changes autosave to the project-scoped
  `user://vehicle_model_debug.cfg`. Clean import, focused vehicle-animation and
  asset tests pass. The permission-correct full suite passed through tractor,
  including 0.300-unit worst correction in the 120 ms network gate, then hit
  the documented timing-sensitive course sample with zero rebound. Its
  immediate isolated retry passed at 1.570 rebound/1.042 degrees, followed by
  passing reverse, jump-gate, combat, RC-orb, shield, and detonation gates.
- Humvee M242 vehicle import is complete on `codex/more-vehicles` in
  `/Users/johnnguyen/Projects/car-fight-more-vehicles`. The matching FBX and
  1024x1024 texture from the two owner-supplied RAR archives are stored together
  under `assets/ground_vehicle/humvee_m242/`. The presentation importer now
  supports models with four already-separated wheel meshes in addition to the
  existing combined-mesh vehicle pack: it recenters the axle footprint, places
  the tire bottoms on the ground, preserves the textured chassis material, and
  feeds the wheels into the existing steering, suspension, spin, skid, cloak,
  boost-echo, and X-ray presentation paths. `V` cycles to Humvee M242 as the
  sixth presentation model; gameplay collision, physics, rollback, and network
  state remain unchanged. A rendered vehicle-lab capture confirmed the body,
  M242 turret, four wheels, texture, scale, and orientation. Focused import and
  animation tests pass, and the permission-correct full `./scripts/test.sh`
  suite passes (`ALL_TESTS PASS`), including 0.300-unit worst correction in the
  120 ms network gate.
- Dynamic tire skid marks are implemented on `codex/skid-marks` in
  `/Users/johnnguyen/Projects/car-fight-skid-marks`. They are client-local,
  presentation-only world-space ribbons sampled from all four animated tire
  contact points. Hard braking marks all tires, drift/physical lateral scrub is
  rear-biased, and oil residue marks every rolling tire. Marks curve with tire
  steering, break across air/teleports, fade after 12 seconds, and retain a
  bounded 1,200-segment budget per presented car. Physics, rollback, and wire
  state are unchanged. The permission-correct full `./scripts/test.sh` suite
  passes (`ALL_TESTS PASS`). First rendered feedback confirmed marks appear but
  found later assisted drifts could stop painting and the tread breakup looked
  too fragmented. The follow-up uses sustained assist charge/amount through
  brief velocity alignment and renders a denser, darker, nearly solid ribbon;
  the next rendered check found a tight drift-assist circle still produced no
  visible marks and requested boost marks. The current follow-up treats a
  latched assist as definite scrub, includes rotational tire speed, paints rear
  tires during boost, and raycasts each actively marking tire onto the real
  surface so body roll cannot bury the ribbon. The next feedback clarified that
  active effects must not paint continuously: boost should mark only its launch,
  drift should mark only peak peel-out, and most events should produce a rear
  pair even though true hard wheel lock can still make four. Emission now uses
  short, armed boost/drift traction-break pulses with oil lowering the real-slip
  trigger. Final direction is simpler: every skid case emits only the two driven
  rear-wheel marks; front tires never paint. Testing then found boost release
  created an unwanted pair because FOLLOW reports hard braking while normalizing
  from burst speed. Boost exit now cancels residual pulses and suppresses marks
  during that brief speed normalization. Reverse is also an intentional hard
  brake: while held above seven units/s of forward travel it now paints the rear
  pair, reaching full strength by 15 units/s, but ordinary backward travel does
  not paint. Latest visual direction lowers the rubber ribbon to 62% peak alpha
  and tapers every individual stroke from transparent at its first quad back to
  transparent at its final quad, removing hard rectangular start/end caps.
  Human testing accepted this state as good for now. The final permission-correct
  `./scripts/test.sh` suite passes (`ALL_TESTS PASS`), including 0.698-unit worst
  correction in the 120 ms network gate; merge to `master` is approved.
- Oil slicks are merged to `master` at `5a2a919`. Three fixed, static/seeded
  arena puddles use presentation-only metallic decals and exact deterministic
  footprints. Road-speed contact engages instantly and leaves roughly four
  seconds of rollback-synchronized residue. The handling uses actual center and
  rear-contact lateral velocity: steering supplies front-end torque, rear grip
  nearly disappears, world-space momentum carries on, and weak restoring force
  plus angular inertia produce turn-induced step-out, countersteer swing,
  sustained slides, and spins without scripted side-to-side wobble. Affected
  vehicles flash amber/magenta over a pulsing orange underbody ring. Slicks add
  no body, collider, trigger, replicated object family, or phase state; only the
  per-car residue scalar joins existing rollback state. The native macOS `Oil
  Slick` system menu exposes the full handling calibration, reset, and automatic
  project-scoped persistence. Client edits are validated and rebroadcast by the
  server so prediction and authority remain matched; headless tests and dedicated
  servers retain checked-in defaults. Dropping slicks as a defensive weapon is
  explicitly deferred.
- Off-screen awareness is now a client-local presentation layer: at most the
  three nearest same-map opposing cars plus the arena ball can reach the rim,
  within 150 units. Cars use their rendered trajectory for a screen-projected
  triangle; the ball is a directionless distance-scaled diamond. Do not add
  dots, troops, bolts, targets, or scenery without a new UX decision—the prior
  all-objects approach made the feature useless. Focused coverage and the full
  `./scripts/test.sh` suite pass (`ALL_TESTS PASS`).
- Vehicle animation lab and presentation refinements are merged to `master` at
  `0b2c760`. Its merged feature worktree and branch were removed after acceptance;
  start any later airborne/landing experiment in a fresh worktree from current
  `master`. Use `./scripts/play_vehicle_animation_lab.sh` before tuning the live
  presentation; the lab drives the real ground-vehicle hull without networking
  or gameplay physics.
- Retain the stable authoritative rigid body rather than introducing a physical
  chassis and four wheel colliders. At the ordinary gameplay camera distance,
  use tunable presentation for body/wheel response. Next prioritize airborne
  wheel droop, landing compression/rebound, and subtle bump response. Add four
  presentation-only ground probes only if normal-view testing proves independent
  terrain following is visibly necessary.
- Active Car Fight development returned to this Godot repository on 2026-08-19. The prior Unity handoff is superseded; see `MIGRATION_TO_UNITY.md` and `~/Projects/car-fight-unity/docs/RETURN_TO_GODOT.md`.
- Preserve the Unity repository at revision `e312c42` as an investigation. Carry its useful native multiplayer authority, prediction, lifecycle, impairment, telemetry, and launcher requirements back into Godot tests; do not port its scene, FishNet adapters, or browser transport fork.
- On affected macOS Intel systems, rendered play must use an ordinary decorated window inside the usable desktop area. Do not use native fullscreen, borderless fullscreen, or exact edge-to-edge/maximized presentation. This bounded compatibility limitation is accepted.
- The full G2-derived transport is available as an explicit A/B profile on native ENet and browser WebRTC; ordinary game launches remain on legacy defaults. The forced-TURN path is operational and its fixed 120 ms Networking-1 jump/teleport gate is accepted. Preserve the earlier queue failures and 64 KiB ceiling as evidence; combined impairment remains a separate unaccepted experiment.
- Networking 1 is implemented on `feature/networking-1` in `/Users/johnnguyen/Projects/car-fight-networking-1`. The fixed 120 ms forced-TURN jump/teleport investigation is complete: per-route settled-state starvation is fixed and human no-contact, rear/head-on/side-impact, and deterministic local-stall controls are accepted. Fixed 75 ms presentation remains the ordinary default; the accepted 1.05-radius/3.40-length capsule remains harness-only.
- Networking 2 is complete on `feature/networking-2` in `/Users/johnnguyen/Projects/car-fight-networking-2`, based on accepted commit `a535364`. The 600-second reconnect soak and two-real-player forced-TURN checks pass. A harness-only local hull/camera reconciler removed the subtle moving-observer tug in both cross-platform directions without changing physics, rollback, collision, input, ordinary presentation defaults, or gameplay capsule defaults.

## Completed

- Created `codex/skid-marks` in
  `/Users/johnnguyen/Projects/car-fight-skid-marks` from current `master`. Added
  a compatibility-renderer tire shader with soft edges and broken tread, a
  batched/fading world-space trail mesh, live integration with each separated
  animated wheel, and focused coverage for skid-source thresholds, low-speed
  suppression, continuous curves, generated geometry, and teleport breaks.
  Clean second import, focused skid/vehicle/oil/asset checks, and the complete
  permission-correct suite pass (`ALL_TESTS PASS`), including 0.300-unit worst
  correction in the 120 ms network gate.
- Merged `feature/oil-slick` into `master` as `5a2a919`. The permission-correct
  post-merge `./scripts/test.sh` run passed every focused, browser-lifecycle,
  offline, network, reconnect, course, reverse, jump-gate, combat, RC-orb,
  shield, and detonation gate (`ALL_TESTS PASS`); the 120 ms two-player row had a
  0.316-unit worst correction.
- Created `feature/oil-slick` in
  `/Users/johnnguyen/Projects/car-fight-oil-slick` from current `master`. Added
  three large world-placed oil patches in open arena lanes, irregular dark/oily
  compatibility-renderer decals with subtle iridescent sheen, shared footprint
  math, and speed/turn-dependent deterministic loss of grip and yaw stability.
  Added a focused layout/handling/rollback/presentation regression to the full
  suite. Project import, focused FOLLOW/oil checks, the 120 ms network gate,
  mixed transport, lifecycle, reconnect, course, reverse, jump gate, combat,
  RC-orb, shield, and detonation gates pass. The complete suite twice reached
  later gates; its first stop was the RC gate's four-tick timing window and its
  second was the documented zero-rebound course sample. Unchanged `master`
  reproduced that course miss; the isolated feature retry passed at 1.571 units,
  and every remaining gate passed afterward.
- First human handling feedback found the original oil response visually readable
  but mechanically too subtle. Added a rollback-synchronized alternating phase,
  1.55 rad/s straight-crossing fishtail target, faster oil yaw response, and
  2.8x peak turn amplification. Focused oil/FOLLOW/import checks and the 120 ms
  network gate pass (0.311-unit worst correction in the complete run). The
  complete suite passed through course and then missed the timing-sensitive gate
  round trip during a stale-history recovery; its immediate isolated retry and
  all remaining combat/RC-orb/shield/detonation gates pass.
- Second human feedback asked for more duration and intensity. Slowed residue
  release from 1.35 to 0.62 per second (about 1.6 seconds from full), reduced
  minimum grip to 16%, raised peak turn amplification to 3.4x, yaw momentum to
  0.68, tail target to 2.1 rad/s, and peak oil yaw to 5.2 rad/s. The final
  permission-correct `./scripts/test.sh` run passes every gate (`ALL_TESTS PASS`),
  including a 0.300-unit worst correction in the 120 ms two-player test.
- Third human feedback requested an unmistakable extreme calibration and a
  visible affected-car cue. Residue now releases at 0.25 per second (roughly four
  seconds from full), minimum grip is 5%, peak turn amplification is 5x, and oil
  yaw can reach 7 rad/s. Added presentation-only alternating amber/magenta corner
  flashes and a pulsing orange underbody ring. The focused oil, vehicle-animation,
  and presentation tests pass. The permission-correct complete suite passed
  through reverse with a 0.300-unit worst correction; its timing-sensitive jump
  gate completed only the outbound transition, then passed immediately in
  isolation, followed by passing combat, RC-orb, shield, and detonation gates.
- Fourth human feedback identified the extreme alternating yaw as artificial
  side-to-side control instead of a rear-wheel fishtail. Replaced the scripted
  rollback phase and forced yaw target with deterministic rear-axle slip dynamics
  derived from the rigid body's real planar and angular velocities. Oil steering
  now acts as torque, rear lateral grip is 0.18/s, drift-assist carve reaches zero
  at full oil, and 3% navigation grip preserves world-space momentum while the
  chassis rotates into a major slide. The focused oil regression covers stable
  straight travel, turn breakaway, rear contact slip, sustained lateral velocity,
  and inertia-respecting countersteer. Clean import and the permission-correct
  complete `./scripts/test.sh` suite pass (`ALL_TESTS PASS`), including a
  0.475-unit worst correction in the 120 ms two-player test.
- Fifth human feedback requested the extreme response at initial contact rather
  than after even a short buildup. Oil amount now snaps upward to the exact
  speed/footprint target on the first physics tick and retains the existing slow
  0.25/s release. Focused coverage asserts both full-center and feathered-edge
  one-tick engagement. Clean import and the permission-correct complete
  `./scripts/test.sh` suite pass (`ALL_TESTS PASS`), including a 0.300-unit worst
  correction in the 120 ms two-player test.
- Added an `Oil Slick` dropdown to the existing native/global system menu bar.
  Every gameplay-facing oil parameter is selectable at runtime through nested
  radio menus, instant entry is toggleable, and one action restores the accepted
  extreme defaults. The server validates known keys/ranges, applies the change,
  broadcasts the complete snapshot to every peer, and seeds joining clients with
  the current snapshot. Focused coverage verifies live duration/grip changes,
  default restoration, unknown-key rejection, and the menu/RPC wiring. Clean
  import, focused oil, offline, 120 ms network, mixed-transport, lifecycle,
  reconnect, ball, and tractor checks pass. The complete suite reached the known
  nondeterministic course landing fixture; two samples recorded the landing but
  missed its rebound/tilt instant, then the next isolated run passed at 1.571
  rebound/1.043 degrees. Reverse, jump gate, combat, RC-orb, shield, and
  detonation gates pass afterward (RC-orb passed its isolated retry after a
  parallel six-gate batch missed the short scripted action window).
- Added automatic native persistence for the Oil Slick system menu. Every
  accepted menu change and reset rewrites the project-scoped ConfigFile, and the
  menu explicitly reports that changes autosave. Startup sanitizes saved keys
  through the same bounded tuning API. A joining client waits for the server's
  initial snapshot, submits its saved full snapshot through a separately
  validated RPC, and persists the authoritative broadcast; offline play saves
  directly. Web, headless tests, proxy, and dedicated-server processes do not
  read or write the developer preference file. Clean import and focused oil,
  offline, 120 ms network, mixed-transport, lifecycle, reconnect, ball, and
  tractor checks pass. The complete suite again hit only the known zero-rebound
  course sample; its immediate isolated retry passed at 1.571 rebound/1.044
  degrees, followed by passing reverse, jump-gate, combat, RC-orb, shield, and
  detonation gates.

- Extended the occluded-silhouette worktree with a presentation-only hint for
  the solid ramp supports hidden beneath the upper road. At ground level, a
  small projected deck-top outline fades in only within 3.75 m or when the
  Jeep's current travel corridor reaches the support within 0.75 seconds; it
  otherwise stays absent. The focused hint and asset-smoke tests pass.

- Created `feature/occluded-silhouette` in
  `/Users/johnnguyen/Projects/car-fight-occluded-silhouette` from current
  `master`. Ported G2's selective Godot 4.7 stencil X-ray overlay to every
  live vehicle mesh: a cyan silhouette now appears only behind walls or other
  obscuring geometry, while the ground grid and interactive grass mask it at
  the tires. Cloak ghosts and frozen boost echoes explicitly exclude the
  overlay. The focused asset-smoke and boost-afterimage tests pass; a rendered
  safe-window check remains required for final visual acceptance.

- Added the standalone close-up vehicle animation lab with mouse orbit/zoom,
  five selectable vehicle bodies, eight driving-condition presets, and live
  road-speed, steering, brake/wheel-lock, longitudinal-load, signed-drift, and
  boost controls. Extended the shared presentation-only hull with independent
  Ackermann front steering, bounded drift countersteer, per-wheel suspension
  travel, acceleration/boost squat, small load compression, and drift-aware
  roll while preserving the existing peak-brake dive and wheel lock. The lab
  boots both headlessly and in a safe 1100x720 decorated window. Focused tests,
  existing asset/boost tests, and the permission-correct complete
  `./scripts/test.sh` suite pass (`ALL_TESTS PASS`).
- Revalidated the animation branch after integrating the accepted gameplay
  capsule changes from current `master`. The permission-correct suite passed
  through reverse; its documented timing-sensitive jump-gate row completed only
  the outbound transition. The immediate isolated gate retry passed both
  transitions, and combat, RC-orb, shield, and detonation gates all passed.
- Ported G2's unmerged adaptive-presentation experiment as a pure, deterministic client-local estimator driven by batch arrival variation/gaps plus actual buffer headroom and interpolation/extrapolation/hold outcomes. Added bounded JSONL capture/replay, focused pressure/saturation/epoch tests, fixed-mode fast paths, and the same controls for ENet and WebRTC. Ordinary play remains fixed at 75 ms.
- Added the opt-in four-line Networking 1 HUD and matching once-per-second `NETWORKHUD` JSON: FPS/frame average+maximum, transport/profile and RTT/jitter, presentation target/headroom/I-E-H shares, and rollback cost/depth plus correction/recovery. Added `scripts/play_networking1_enet.sh`, which uses a temporary server-driven Jeep on the isolated macai2 checkout/UDP 12680 and one local rendered observer through UDP 12681 without touching production.
- Networking 1 visual runs now hide the general hotkey hint line and show a prominent three-second `FIXED/ADAPTIVE BUFFER` banner at startup and every presentation-tier change, after the first adaptive playtest made its 75→100→125→150 ms transitions too easy to miss.
- Completed the human ENet fixed/adaptive series against the isolated macai2 server. Adaptive improved every matched comparison: clean selected 100 ms and reduced side-by-side vibration; latency120 selected 100 ms and softened mixed stutters; jitter selected 125 ms and replaced harsh jerk/grass separation with continuous but occasionally vibrating motion; combined selected 100 ms and was rated very playable and smooth. No adaptive phase produced a recovery pullback. The residual drawn-out combined stutters aligned with 35-39 FPS and 25-33 ms rollback loops while presentation remained 100% interpolated. Fixed-mode per-body I/E/H instrumentation is still missing, so its aggregate network counters must not be treated as direct motion-quality measurements.
- The jitter comparison exposed a large-clock-correction startup defect: a monotonic presentation cursor could remain outside its retained history and hold an endpoint for seconds. Large corrections beyond the one-second history now establish a fresh cursor epoch while ordinary clock discipline remains damped; focused forward/backward rebase tests and clean import pass. Two permission-correct complete-suite confirmations passed all presentation/transport/network/lifecycle tests through reverse, then the pre-existing timing-sensitive jump-gate route completed only its outbound transition under cumulative suite load; its immediate isolated rerun passed both transitions. Do not attribute that unrelated gate flake to presentation work.
- Validated Networking 1 with two short clean macai2 traces (both replayed at the 75 ms floor with 100% interpolation after warmup), the adaptive local ENet gate, the exported browser/native adaptive smoke (58 steady FPS, 3,896-byte peak/487-byte final queue, zero browser errors), clean Godot import, and the complete suite (`ALL_TESTS PASS`). Temporary rollback stage profiling found no proven safe 5% optimization, so no replay behavior or hot-loop profiler was retained.

- Integrated the pickup/dropoff prototype into the network-shaping baseline: a
  green recruitment area streams troops into a nearby car, and holding `F` in
  the red destination area deploys them. Troops remain lightweight server-owned
  presentation/events rather than rollback physics bodies.
- Created `/Users/johnnguyen/Projects/car-fight-network` on `feature/network-shaping`. Added shared `clean`, 60/120 ms, jitter/reordering, 0.5/1% loss, and combined profiles; deterministic ENet relay seeds; per-direction receive/forward/drop/reorder/queue telemetry; focused and complete matrix gates; and safe monitored one/two-client launchers. The complete native matrix passes. Its combined 120 +/- 40 ms plus 1% loss row measured 1,488/5,145 forwarded packets, 17/48 drops, 1,053/4,377 reordered packets, and a 1.532-unit worst correction under the unchanged two-unit ceiling.
- Added browser query support for credentialed TURN plus relay-only ICE and an isolated WebRTC/TURN shaping harness. It syncs only to `/Users/macai2/Projects/car-fight-network-shaping`, uses mux ports 12480/12481, creates uniquely named temporary coturn/netem resources on macmini, requires qdisc traffic/drop proof, records both browser and server WebRTC queue bounds, and leaves production UDP 10080/TCP 10181 untouched. The combined row proved 2,998 shaped packets and 24 qdisc drops, held 60.2 average FPS with zero browser errors, and survived browser refresh/rejoin beside a native ENet peer, but failed because the browser queue peaked at 125,197 bytes/finalized at 15,166 and the server ordered queue grew past 600 KiB. A clean forced-relay row also failed with a 106,560-byte browser peak and buffer-full errors, so browser backpressure is now the measured next problem.
- Validated the shaping changes with `./scripts/network_matrix_test.sh` (`NETWORK_MATRIX PASS`), the focused join-transient gate, syntax/import checks, and the complete `./scripts/test.sh` suite (`ALL_TESTS PASS`). One earlier matrix pass caught a one-off rollback RPC during teardown after the server quit; the clean full matrix rerun did not reproduce it, so retain the runtime-error assertion and watch for recurrence.
- Diagnosed the apparent permanent desynchronization in two rendered `latency120` clients. A diff whose acknowledged reference had left history was being merged against an empty state, and D-040 could then wait indefinitely when a locally owned authority tick fell behind retained history. The recovery fix rejects every missing-base diff while rate-limiting its warning, retains state-only diff bases for two rollback windows, and uses a rate-limited reliable/authority-validated full-state request and reply. The deterministic 1.5-second join stall passed with one requested and one applied recovery; the focused 120 ms gate passed after the retention change.
- Repeated the rendered 120 ms comparison against a temporary patched local server. The first five-minute recovery build stayed synchronized but applied 74 emergency full states; retaining diff bases reduced the next run to 16 total recoveries while both clients still agreed and recent correction returned to zero. The user reported smooth-ish high-FPS play and visible stutter at 10-15 FPS. Exact evidence and per-client counts are in `NETWORK_SHAPING_FINDINGS.md`.
- Extended crash telemetry with per-second maxima for netfox forward-loop time, rollback-loop time, forward ticks, and replayed ticks. The unshaped two-rendered-client control still produced low-FPS intervals: rollback replay reached 62/63 ticks and 84.5/81.1 ms in one frame while ordinary loops were about 2-4 ms. This identifies the remaining stutter as a rollback starvation feedback loop, not rendering physics and not shaping alone, and motivated the bounded-resimulation A/B recorded below.
- Ported and adapted the remaining applicable G2 network stack behind `CAR_FIGHT_G2_STACK=1`: per-route StateBundle backpressure/coalescing, fixed-size packed input, packed state/diffs, input-broadcast control, fixed/adaptive state cadence, application telemetry, complete-set 30 Hz remote-position batching with same-map relevance/self exclusion, and render-only delayed interpolation. Car Fight required per-route/body coalescing because sparse server resimulation envelopes otherwise starved another body's authority. Focused codec, coalescing, and remote-transport tests pass.
- Validated the full profile natively: `latency120` passes at fixed divisor 3 with a 1.379-unit worst correction and real non-empty batches; `combined` passes at divisor 1 with 0.388 but rejects divisor 3 after a 10.890 startup correction; a long adaptive run passed while stepping 3 -> 2 -> 1 with a 0.860 worst correction. A final 10 ms resimulation-budget retest still diverged to 34.176 units, so the option remains a zero-default lab lever only.
- Validated the real exported browser batch/presentation path after adding a non-empty-envelope assertion. The accepted local browser/native replacement run held 59.2 steady FPS, peaked at 678 queued bytes, ended at 102, drained normally, and emitted zero browser errors. The latest isolated `latency120` TURN run failed before gameplay with ICE stuck connecting; it is not desynchronization evidence.
- Added an opt-in server-authoritative car (`--server-driver`) and the single-observer `scripts/play_shaped_local.sh`. Peer 1 generates input on the server and drives long straight runs around the open perimeter without firing, using short chamfered corners and advancing if it stops making progress. An earlier northeast leg clipped the driving-course gate; the corrected route stays inward of it, and a map/bounds guard restores the fixture if it ever leaves the arena. The observer spawns beside the fixture. The visual harness disables elevated ramps, the physical arena ball, the shield-test drone, and the orange peer marker mounted above each Jeep while retaining the cursor line, interactive grass, and the rest of the arena presentation. Runtime instrumentation confirmed zero ball, RC-orb, and bolt nodes in the affected run; the persistent orange object was the server Jeep's attached peer marker.
- Created the `feature/area-weapon` Car Fight worktree. Ported G2 Splash's slot-3 arm→hold/drag→release interaction as rollback-synchronized input/state: bounded tap clusters and 18-unit bombing runs release five server-authored impacts, which apply a compact jostle and leave lightweight authoritative burn zones. The isometric aircraft, falling bombs, target reticle shader, and fire-ground presentation are carried into the Car Fight visual language. Pressing `3` calls the plane in from offscreen and it hovers/orbits the live cursor target; holding the drag adds five live reticles showing the exact server-bounded footprint. Release fires one strike then immediately returns to default auto-fire. The rendered client title is `Car Fight — Area Weapon` to distinguish this worktree. Added the focused area-gesture layout test; complete `./scripts/test.sh` passes, including the 120 ms network check.
- Added a fixed, non-targetable arena drone that fires a slow server-authored bolt every two seconds at the nearest visible driving player.
- Added authoritative player impacts with a small linear deflection, torque jostle, and short steering-recovery window.
- Added a freely toggled `Q` shield that absorbs 85% of the drone shove; cloak and shield are mutually exclusive, with cloak taking priority.
- Added a glass bubble shader, localized shield ripple, ordinary impact burst, client-side visual prediction, and authoritative event deduplication.
- Isolated the drone in the empty west clearing, with no red targets or arena structures beside it.
- Increased authoritative drone shove and torque, and briefly relaxes suspension recovery after hits so shielded and unshielded body jostle remains visible.
- Added focused impact math, presentation, and network gates; the complete `./scripts/test.sh` suite passes.
- Expanded the arena from 128 to 168 units across, widened the driving camera, and moved obstacles, outer targets, and the shield drone outward to use the new space.
- Expanded the analog mouse radius from 16 to 20 units and softened small heading corrections for finer throttle, line, and combat-spacing control.
- Added automatic grounded powerslides with no new input: speed, a sharp heading request, and pulling the cursor inward continuously trade velocity correction for rotation; wide turns, boost, reverse, and airborne movement stay planted.
- Added focused control and arena regressions, and made the reverse gate measure clearance relative to the configured boundary.
- Raised normal speed from 14 to 18 and burst speed from 23.33 to 28; cursor length now scales normal acceleration as well as target speed.
- Strengthened the close cursor carving band while retaining the no-pivot rule and broad high-speed arcs.
- Split inward-pull handling into automatic straight brake skid and turn-driven powerslide amounts, so braking can lose tire response before rotation develops.
- Made dynamic collision escape measure progress along each driver's request only while player bodies touch, preventing free skids from being mistaken for stalls.
- Made duplicate projectile cleanup tolerate an already-freed presentation node, removing the nonfatal runtime error found during live play.
- Lengthened hard-brake momentum, slightly strengthened powerslide rotation, nearly locks visual wheel roll during a full skid, and pitches only the presentation chassis up to 9 degrees forward.
- Exaggerated the arcade brake read: full wheel lock, 18-degree faster chassis dive, roughly halved straight-skid velocity correction again, and slightly more powerslide rotation.
- Documented three nearly identical WindowServer watchdog failures in `.ai/CRASH_LOG.md`. All involved the fullscreen rendered Godot 4.7 client and the same built-in Intel display framebuffer becoming unready; the third lasted about 156 seconds and captured an explicit Intel framebuffer VBlank timeout immediately before Godot observed WindowServer's event port dying. No known windowed session has failed. Treat fullscreen presentation on the native OpenGL path as a probable trigger, not a proven game-logic crash. No renderer or gameplay mitigation has been applied.
- Delayed the presentation-only hard-brake dive until skid intensity passes 72%, builds it to full near 98%, and slowed its easing to one-quarter of the previous response speed while retaining the exaggerated 18-degree peak. The complete `./scripts/test.sh` suite passes.
- Made Drive the default launch mode with combat coverage cones hidden until `C` or the `E` editor is requested.
- Added a local speed ring around the Jeep: normal speed fills the main arc, burst speed adds an outer orange arc, and peak braking brightens the display.
- Added faint rear-corner drift zones centered around +/-135 degrees. Peak braking inside either zone adds bounded rotation and forward-carry assistance, fills a 0.65-second local timing meter, and displays `MAX -> GAS` before resetting after the cursor leaves. Straight-back braking and ordinary sideways powerslides remain unchanged.
- Synchronized drift-assist amount, charge, and side through rollback state and added focused control/presentation regressions. The complete `./scripts/test.sh` suite passes.
- Replaced each thin drift-zone bar with a translucent cursor wedge spanning 1.55-6.3 units, showing the full area that gives maximum assist from normal top speed.
- Strengthened assisted yaw and momentum preservation, then added a bounded 0.85 rad/s path carve. During a committed rear-corner brake the chassis rotates faster than its travel direction while the velocity path bends around the corner, producing a sharper high-speed sliding turn rather than an in-place spin. The complete `./scripts/test.sh` suite passes.
- Expanded each drift target to a broad 1.3-9.0 unit rear wedge covering 90-178 degrees. Wedges are nearly invisible below drift-entry speed, become readable as the Jeep approaches full speed, and brighten on entry/activation.
- Replaced continuous moving-zone tracking with a rollback-synchronized latch: hold a qualifying rear wedge for 0.18 seconds to store the drift side, after which assistance continues without chasing the rotating wedge. Far forward acceleration exits immediately; reaching a 72-degree natural side slip releases into the ordinary powerslide. Low speed, reverse, and leaving the ground also cancel the latch. The complete `./scripts/test.sh` suite passes.
- Made drift-assist activation unmistakable: the latched-side wedge snaps to a strong persistent glow, the opposite wedge fades, and a matching `DRIFT ASSIST` marker remains visible until assistance exits. The complete `./scripts/test.sh` suite passes.
- Fixed the drift gesture defeating its own latch: a qualifying high-speed wedge entry now captures readiness for the 0.18-second arm window, so the commanded braking and resulting speed loss cannot cancel it. The cursor must remain in the rear corner and the Jeep must stay above 8 units/s; straight-back input, reverse, and airborne movement still cancel. Added a focused falling-speed arming regression, and the complete `./scripts/test.sh` suite passes.
- Reduced ordinary close-cursor turn authority by 20%, preserving a noticeably tighter line than far-cursor steering while restoring a visible driving arc. Added bounds ensuring close steering stays useful but cannot substitute for a successful drift; drift assist remains at least 25% tighter in the focused control regression. The complete `./scripts/test.sh` suite passes.
- Widened the ordinary close-cursor arc again after live testing: near turn authority is now 2.7 rather than 3.2, and the non-assisted powerslide rotation bonus is 1.10 rather than 1.28. Ordinary inward pulls retain braking, tire slip, and a tighter line than far steering, but a regression now caps them to a broad high-speed arc so missed drift assists cannot fake the reward. The complete `./scripts/test.sh` suite passes.
- Added a warm-white max-speed reference dot projected along the cursor ray at the full-throttle distance. The existing colored endpoint dot remains the live command: below full throttle the reference sits ahead as a target, and at full throttle the endpoint meets it while the smaller warm center remains visible. This is presentation-only and does not change input or speed. The focused asset smoke test and complete `./scripts/test.sh` suite pass (one transient rollback-startup failure cleared on the clean full rerun).
- Added an explicit second world space for a dedicated driving course, reached through the glowing blue `DRIVING COURSE` pad near the arena's +X/+Z corner and left through its `RETURN TO ARENA` pad. Player `map_id`, gate cooldown, and transition count are rollback-synchronized; transit resets velocity and active drift state, and arena auto-combat/drone targeting ignores course drivers. The server/client gate regression completes a full arena→course→arena round trip.
- Added a closed 18-leg driving circuit with stable live-test vocabulary: `A` long straight, `B` fast sweeper, `C` tight 90, `D` back straight, `E` hairpin, `F` slalom, and `G` technical return. The broad green route and its centerline pulse amber/orange whenever the local Jeep leaves the 15-unit-wide track; the HUD also shows the nearest section and `OFF TRACK`. Health, damage, and death were deliberately not ported because map transit and visual off-track feedback are independent of them. The full `./scripts/test.sh` suite passes.
- Added opt-in crash telemetry and `scripts/play_monitored.sh`. Each run records and immediately flushes renderer/GPU identity, FPS/frame stalls, draw and memory counters, local driving/drift state, focus, window mode/fullscreen transitions, display/screen state, Godot and WindowServer PIDs, CPU/RSS/thread samples, thermal/swap state, filtered macOS display/GPU/watchdog events, and a short external Godot sample if telemetry stalls. The launcher explicitly requests windowed mode by default.
- Added `scripts/collect_crash_run.sh` to attach delayed WindowServer/Godot `.ips` and `.spin` reports after login recovery, recover the matching unified log, and preserve short pre-failure telemetry/process tails. Both scripts were validated with clean headless runs; the complete `./scripts/test.sh` suite passes.
- Added a headless-only `--fake-stall` fault and `scripts/crash_monitor_test.sh`. It freezes only the Godot client main thread for seven seconds, requires the external watcher to capture a real stack during the telemetry gap, and verifies clean recovery. The end-to-end test passes with the sampled main thread blocked in `nanosleep`; it cannot be combined with a rendered run and does not stress the GPU or WindowServer.
- Completed the first controlled monitored windowed play test at `db43dec`: 423 seconds across both arena and driving course, burst speed and drift assist exercised, no window-mode transitions, no telemetry stall, no thermal warning, no VBlank/GPU/display failure signature, same WindowServer PID at exit, and a normal client shutdown. This supports—but does not yet prove—the fullscreen-specific hypothesis.
- Completed the controlled native-OpenGL fullscreen comparison at `ba96b6d`. It reproduced the same WindowServer watchdog after about 192 seconds, while the otherwise equivalent 423-second windowed run was clean. Fullscreen caused 6,811 `Invalid actual_host_time` errors for the built-in display beginning about four seconds after client telemetry started, followed by an Intel framebuffer VBlank timeout and WindowServer event-port death. Godot telemetry stayed regular, memory stayed stable, and both Godot processes survived the desktop restart until stopped by exact PID. This strongly isolates fullscreen presentation on the Intel OpenGL/display path rather than gameplay logic or a Godot process crash.
- Improved crash recovery classification: the collector records whether the exact server/client PIDs survived, marks a changed WindowServer PID as `windowserver-restarted`, and the monitored launcher honors that recovered PID even when its final live lookup is unavailable. Narrowed noisy watchdog log capture and made report summaries focus on WindowServer/Godot evidence.
- Completed a second monitored windowed driving-course session at `ee562b4`: 534 seconds across both maps, normal top speed and drift assist exercised, with no fullscreen display-failure signature. The user could negotiate the course without relying on drift by pulling the cursor inward and shedding speed, revealing that ordinary hard braking still made tight corners too forgiving.
- Added a high-speed braking commitment penalty. A fully locked ordinary skid now preserves about 40% more forward momentum and retains only 68% of its pre-skid steering grip, so late braking carries the Jeep wide instead of giving simultaneous rapid deceleration and close-cursor rotation. Low-speed steering is unchanged, while a successfully latched rear-corner drift restores the sharper turn reward. Added a regression separating low-speed close steering, ordinary high-speed braking, and assisted drift; the complete `./scripts/test.sh` suite passes.
- Live-tested the braking commitment in monitored windowed mode for 135 seconds across both maps. The session reached normal top speed, latched drift assist, produced no display-failure signature, and the user accepted the handling balance for now.
- Updated the active engine from Godot 4.7 stable to the official signed Godot 4.7.1 maintenance release at `/Applications/Godot47.app`, retaining 4.7.0 at `/Applications/Godot470.app` as a rollback. The archive checksum and application signature verified successfully. The focused network retry, complete `./scripts/test.sh` suite, and headless seven-second crash-monitor fault test pass under 4.7.1. Fullscreen has not been tested under the new engine and remains unsafe until explicitly authorized.
- Prevented drift-assist circle chaining. A natural side-skid exit now spends the current assist and a rollback-synchronized rearm gate blocks another rear-wedge latch until the player accelerates forward (or fully resets through low speed, reverse, or leaving the ground). Holding the cursor still can no longer repeatedly re-enter the moving wedge as the Jeep rotates. The spent wedges visibly dim until rearmed. Focused control/presentation checks and the complete `./scripts/test.sh` suite pass under Godot 4.7.1; the 120 ms rollback gate completed with zero correction after the concurrent rendered baseline was closed.
- Confirmed during the 4.7.1 windowed baseline that the shield is present and functional. Its intentionally faint glass shell overlaps the local speed/drift rings from the overhead camera; the initial report of a missing shield was withdrawn, so no shield behavior or presentation was changed.
- Completed the first monitored Godot 4.7.1 windowed baseline: 587 seconds (9 minutes 47 seconds), both maps, 27.98-unit/s burst speed, and drift assist exercised. Telemetry stayed windowed with no gap over 2.46 seconds, and the logs contained no invalid display timestamps, VBlank timeout, GPU reset, display-not-ready, or WindowServer event-port failure.
- Completed the controlled Godot 4.7.1 native-OpenGL fullscreen comparison at `03672ea`. The exact known precursor returned immediately: 736 `Invalid actual_host_time` errors for built-in DisplayID `0x4280f40` during a 20-second run, versus zero in the 9-minute-47-second windowed baseline. The test was stopped before a VBlank timeout or watchdog; WindowServer stayed alive and both Godot processes ended. Godot 4.7.1 does not fix fullscreen on this path.
- Completed the explicitly approved Godot 4.7.1 ANGLE fullscreen comparison at `03672ea`. Runtime output confirmed ANGLE 2.1.1 using its Metal renderer on the Intel Iris Plus GPU, while telemetry confirmed true 2880 x 1800 fullscreen. The same DisplayID emitted 235 `Invalid actual_host_time` errors immediately during an 18-second run. The test was stopped before a VBlank timeout or watchdog; WindowServer stayed alive and both Godot processes ended. ANGLE does not remove the precursor and should not be adopted as the macOS fullscreen workaround.
- Built a durable staged reconstruction in the `diagnostics/render-isolation` worktree, adding one responsibility at a time from an empty Godot 4.7 fullscreen window through viewport scaling, camera, mesh, lighting, shadows, animation, imported Jeep, Rapier initialization, active physics, netfox, and local ENet. Stages 0-10 each completed cleanly during the initial display session. The separate Rapier editor-shutdown `EXC_BAD_ACCESS` is reproducible but does not occur in ordinary game runtime and is not the WindowServer failure.
- macOS power history confirms sleep at 01:28:43 and a deep-idle wake at 01:32:29 due to lid-open/user activity. Stage 11 reproduced the invalid-display-timestamp precursor about one minute later without player input. An immediate recheck of the exact previously clean Stage 10 build then reproduced 623 errors without ENet or input. At that point Stage 11's earlier position left the initial activator order-confounded. The client remained at 115-117 FPS and both Godot processes were stopped, but roughly 30 seconds later the Intel framebuffer timed out and WindowServer watchdog incident `AFEF1DCD-F77C-4EE2-BB15-CD64A924D9D2` restarted the desktop. Earlier power history confirms wake is not required: the 03:24 incident had no immediate preceding wake, and no sleep separated the 13:15 and 14:04 incidents. The stable conclusion is an intermittent/stateful fullscreen Intel display-path failure, and stopping after the precursor does not guarantee safety.
- Added and validated `--deep-capture` monitoring. It detects the first invalid display timestamp, preserves synchronized Godot stacks plus display/framebuffer/accelerator/memory/power snapshots, and continues observing WindowServer after both Godot processes exit. The collector now rejects older reports whose modification time changed only because macOS added later submission metadata. The safe seven-second headless stall test and complete `./scripts/test.sh` suite pass.
- Ran the clean-order Stage 10-first fullscreen probe in restarted WindowServer PID 50563 before Stage 11 or any other rendered Godot test in that session. With no ENet peers, traffic, player input, spawning, or replication, it produced 853 invalid timestamps from 02:07:30.044 through 02:07:47.439. This rules active networking and input out as initiators. Both Godot processes were stopped and WindowServer survived the 120-second post-exit watch with no VBlank timeout, display-not-ready event, GPU reset, event-port death, or new crash report. Deep snapshots showed no thermal warning, memory exhaustion, or GPU recovery. Evidence: `/private/tmp/car-fight-stage10-recheck/.crash-runs/20260814-020722`.
- Completed the broader investigation in the pushed `diagnostics/render-isolation`, `diagnostics/mac-intel-fullscreen`, and `diagnostics/g2-render-bisect` branches. The combined evidence rules gameplay, networking, input, specific imported assets, materials, surface count, draw count, and native fullscreen Spaces out as requirements. Exact edge-to-edge Godot presentation is the strongest activation boundary; native OpenGL and ANGLE reproduce the precursor, Vulkan/MoltenVK caused an Intel graphics kernel panic, and one minimal OpenGL watchdog occurred roughly 278 seconds after Godot exited.
- Completed the separate `unity-mac-fullscreen-spike`. Unity Metal still produced the Intel/macOS timestamp-warning family and presentation stalls, but its tested players recovered without a WindowServer restart or kernel panic. At that point the project chose Unity, with `MaximizedWindow` as the preferred no-border mode and ordinary `Windowed` as the safest fallback; that handoff was later superseded.
- Returned active development to Godot after the Unity browser transport could not be reproduced from tracked source and the CLI-first Editor/build loop proved unsustainable. Consolidated the three Godot diagnostic branches into the canonical `MAC_INTEL_FULLSCREEN_FINDINGS.md`, linked it from the README and migration history, and made its decorated inset-window policy an explicit agent rule.
- Deployed an isolated boot-persistent Car Fight server to macai2 over Tailscale on UDP 10080 without touching G2's UDP 9950 service. Deployment now performs two clean Godot import passes and rejects parse/compile errors from the verification pass. Extended the monitored launcher for remote host, client name, and safe window position, and added `scripts/play_macai2_two.sh` for two side-by-side decorated clients.
- Fixed multi-window live input ownership on macOS. An unfocused client now sends neutral cursor/buttons while remaining in drive mode, so its Jeep brakes instead of following the cursor position from the focused sibling process. Scripted/headless clients retain their deterministic input. Added a pure focus-policy regression and client world telemetry containing replicated player count plus every peer position.
- Ran the first two-rendered-client macai2 trial at `.crash-runs/two-client-20260820-002835`. Both clients consistently reported `players=2`, both Jeeps were visible, and the unfocused Jeep held speed 0 through focus swaps. The trial was not valid networking-feel evidence: each client saturated roughly one CPU core, fell to about 4-7 FPS, and entered a persistent netfox rollback-history loop; the remote view could therefore appear frozen/desynchronized. No display-failure precursor occurred and both windows exited cleanly.
- Re-ran the base two-client headless network gate with 120 ms one-way latency after adding explicit shared-world assertions. Both clients reported both peer bodies and observed the moving remote position advance. The final clean full suite passed every gate, with a 0.479-unit worst same-tick correction and no rollback-history warning; the ball gate reached 16.294 authoritative speed. One earlier back-to-back suite attempt had a transient load-related history warning, then its isolated retry and the final full rerun passed.
- Identified the rendered-client FPS collapse as a missing proven G2 netfox patch, not ordinary two-window render cost. A single rendered client joining the long-running macai2 server reproduced the same fixed stale rollback origin, saturated one core, and fell to about 19 FPS. The new deterministic `scripts/join_transient_test.sh` forced a 1.5-second post-sync stall and proved the unpatched baseline with 31 stale-history/flood matches.
- Ported G2 D-040 only: `NetworkRollback` now skips an origin older than retained `history_start`, reports recovery at most once per second, and the full/diff/redundant encoders silently reject the already-owned stale packet condition. The identical positive control then passed with 1-2 bounded recovery warnings, zero impossible rollback attempts or stale-packet flood, and healthy ticks through 500. The complete suite passed, including the ordinary 120 ms two-client gate at 0.189 worst correction.
- Deployed D-040 to the isolated macai2 server and repeated the real rendered late-join at `.crash-runs/20260820-004847`. Initial recovery produced nine bounded stale-origin skips and then stopped completely; no impossible rollback/stale-packet flood occurred. Sustained driving afterward averaged 91 FPS over the final 20 samples (median 94, latest 115) instead of the pre-fix 19 FPS collapse. This validates one rendered client against the long-running server; it does not yet validate two rendered clients.
- Completed the staggered two-rendered-client macai2 validation after D-040 at `.crash-runs/two-client-staggered/alpha/20260820-005519` and `bravo/20260820-005553`. Alpha was allowed to stabilize before bravo joined. Both clients reported both peer IDs, each observed the other's movement at matching world positions, focus-neutral input worked in both directions, and there were zero impossible-history floods, script errors, or display precursors. The final measured 20-sample averages were about 73 FPS for alpha and 54 FPS for bravo; the user reported good FPS, a little skipping when the Jeeps first appeared together, and smooth play afterward.
- Recorded the G2 scaling lesson as an active Car Fight design constraint: G2 degraded sharply as gameplay-object count grew and required careful per-class redesign. A smooth two-player world does not authorize making future props, projectiles, bots, effects, or resources full rollback bodies. Each object family must choose the cheapest correct replication class and enter with a representative count/load gate measuring client frame time, rollback debt/history recovery, wire fan-out, nodes, and draw calls.
- Ported G2's detached-input lifecycle guard: `BaseNetInput` now verifies that its node is still inside the scene tree before querying multiplayer authority during the global tick callback. Added `scripts/reconnect_test.sh`, which keeps one client live while a same-named second client disconnects and rejoins. The survivor observed the world transition from two players to one and back to two; the replacement remained healthy through tick 300. This gate also exposed and fixed a Car Fight authority-probe race where a queued-for-deletion body could target an ENet peer that had already left.
- Evaluated and rejected G2's half-handshake-RTT initial time seed rather than carrying it on reputation. With the seed, the isolated 120 ms two-client gate passed only one of three runs; the other two produced first-probe corrections of 3.464 and 3.162 units. With only the seed removed, three consecutive controls passed at 1.178, 0.758, and 0.001 units. No acceptance threshold was weakened. The final complete suite passed with the lifecycle hardening retained, including 0.300-unit worst correction, one bounded late-join recovery, and a clean three-join/three-leave reconnect gate.
- Deployed the accepted lifecycle build to the isolated macai2 UDP 10080 service and validated it with two overlapping headless clients across Tailscale. The survivor observed the cycler join and remained at two players through tick 780, then returned cleanly to one player after the cycler left; its worst correction was 0.006. The cycler saw both peer IDs through tick 300 and produced two bounded D-040 recovery warnings with no flood. macai2 recorded every join and leave with no runtime error. Also replaced the service status helper's unavailable `rg` dependency with macOS `/usr/bin/grep`, so its launchd check now truthfully reports the running service.
- Completed a roughly 168-second two-rendered-client macai2 run at `710cf5b` under `.crash-runs/two-client-20260820-013633`. The user reported that play felt good. Both clients stayed in one world; worst corrections were 0.587/0.933, no impossible-history flood or script error occurred, both exited cleanly, and the final 20-sample FPS averages were about 132/135. Bravo's brief 6-8 FPS interval matched an accidental resize from 1280 x 720 to 2800 x 1518 (about 4.6x the pixels), not physics or networking, and recovered after reducing the window. Separately, WindowServer emitted 306 known invalid-timestamp precursor lines during the first 21 seconds; there was no VBlank/GPU/watchdog follow-on or restart. This strengthens the need for the pending safe-size clamp even in decorated windowed mode.
- Added the canonical `WEB_PLATFORM_PLAN.md`. The next platform sequence is: Intel-Mac safe-window enforcement, isolated offline Web/Rapier export smoke, isolated WebRTC browser plus native proof while ENet UDP 10080 remains untouched, measured latency/loss/reconnect acceptance, then an explicit mixed-transport production decision. Do not use WSS for gameplay or bulk-port G2's browser optimization stack before measurement.
- Completed Web platform Phases 0 and 1 in the isolated `feat/web` worktree. Rendered Intel macOS now has a tested runtime window policy that restores decorated windowed mode, clamps to 1280 x 720 within a 48-pixel usable-screen inset, permits minimization, and records every enforcement action through crash telemetry. The policy tests cover maximized, borderless, oversized, and near-edge states without another dangerous native fullscreen/edge probe.
- Added the offline Web path, `Web Offline` export preset, reproducible build and localhost isolation-header server, headless offline regression, and bounded Chrome smoke. Offline mode spawns one local Jeep and ball without ENet or rollback synchronizers; normal mouse input drove the Chrome Jeep to 17.99 units/s with Rapier 0.8.39 and zero console/script errors. The accepted Chrome 151 single-thread release run reached runtime-ready in 2.42 seconds and its final five samples averaged 59.6 FPS (58 minimum) at a fixed 1280 x 720 render resolution. A threaded A/B showed no repeatable improvement, so the compatible single-thread preset remains accepted. Native ENet and macai2 UDP 10080 were unchanged.
- Merged the Web checkpoint, selectable vehicle presentations, interactive grass, auto-pickup dots, det defense, area weapon, homing missile, and RC orb branches into `master` as ordered merge commits. Consolidated shared `Main.gd`, player input, rollback, telemetry, and asset smoke-test seams while retaining native ENet and offline Web behavior.
- Final validation passed: `./scripts/test.sh` (`ALL_TESTS PASS`), `scripts/det_test.sh`, `scripts/shield_test.sh`, `scripts/rc_orb_test.sh`, and `scripts/web_smoke.sh` (`WEB_SMOKE PASS`, zero browser errors).
- Follow-up Web usability fix: Mac/Web DET now uses Command (with Alt as a Web fallback), the Web HUD documents `2: RC orb` and click-to-detonate, and the RC orb presentation was enlarged for the wide Web camera.
- Implemented the isolated localhost browser-networking checkpoint on `feature/browser-networking`. Native clients remain on ENet, browsers use WebRTC DataChannels, and a minimal server-side mux presents both as one authoritative netfox world. Added separate `Web Network` export/build/play helpers while preserving the offline preset and leaving macai2 UDP 10080 untouched.
- Ported only the required G2 transport subset: WebSocket signaling, native/browser WebRTC lifecycle, channel telemetry, the mux, and the macOS universal native WebRTC extension with its licenses. No StateBundle, packing, batching, rate division, TURN, shaping, or production defaults were carried over.
- Added mixed-transport regressions for distinct peer IDs, shared-world movement/contact, ENet departure with a surviving WebRTC peer, a one-second RPC tombstone drain, cross-transport ID collision containment, and either transport listener closing without interrupting the other leg. The focused gate passes with zero runtime errors and zero worst correction in the retained run.
- Added an exported Chrome/native ENet refresh gate. Browser peers 2 then 3 joined the same world as a surviving ENet client, shared-world snapshots changed over time, the WebRTC buffer drained after peaks no larger than 5,080 bytes, and no browser/script error occurred. Repeated final-window averages were 47.6-57.2 FPS; the final accepted run held a 49 FPS minimum and 57.2 FPS average. Same-machine browser/native testing is viable with a 30-minimum/45-average local capacity floor.
- Added a three-sample pure-ENet versus mux CPU A/B. With the same two native ENet clients, median server CPU was 3.37 versus 3.76 seconds over an eight-second run: 0.39 CPU-seconds added, 4.88% of one core and 11.57% relative to the tiny control.
- Completed the first human same-machine browser/native cross-play validation using `play_web_network_local.sh`: the safe-windowed macOS client stayed on ENet, Chrome stayed on WebRTC, and both remained responsive in the same authoritative world for more than five minutes at documentation time. The user reported that it played well and attributed the earlier lower automation samples to heavy unrelated machine load. Native telemetry averaged 58.3 FPS overall and 74.4 FPS across the latest 20 samples. Retain the conservative automation floor, but same-machine browser plus macOS testing is now human-accepted.
- Promoted the accepted mux server configuration to the isolated macai2 Car Fight service at the user's request. It preserves native ENet on UDP 10080 and adds WebRTC signaling on TCP 10181. The remote server has no `.git` checkout by design (deployment syncs source excluding `.git`), so deployment verification uses the running daemon and listener rather than a remote Git revision. Public browser play is still separate work: it needs HTTPS/WSS hosting and likely TURN before remote acceptance.
- Changed normal native client launches to prefer macai2 over Tailscale, keeping server simulation off the local Intel Mac. `play.sh`, `join.sh`, direct client startup, and `play_monitored.sh` now default to `100.113.2.60`; `CAR_FIGHT_HOST` overrides it. Local development remains explicit through `play_local.sh`, `play_monitored.sh --local`, or a passed `127.0.0.1` host. Browser/local test helpers retain their isolated endpoints.

## Networking-1 checkpoint (2026-08-22)

- Completed the ENet-to-WebRTC presentation series through a forced-TURN 120 ms
  collision-proxy checkpoint. Human testing accepted the 1.05-radius,
  3.40-length horizontal capsule for both the server fixture and the player in
  the Networking-1 harness. Ordinary gameplay retains its proven sphere.
- Added a slow non-evasive left-lane server driver for repeatable collision
  judgment, a rollback-aware fixture collision proxy, a synchronized cyan
  collider visualization, proxy/authority telemetry, and map-relevance visual
  cleanup. Detailed results remain in `NETWORK_SHAPING_FINDINGS.md`.
- A global capsule-default attempt exposed separate handling integration work:
  elevated-road touchdown became intermittent, the reverse fixture overlapped
  the longer shape, and projectile/shield pitch response changed with rotational
  inertia. Speculative compensations were removed. Add a dedicated gameplay
  capsule workstream later; do not mix it into jump/teleport diagnosis.
- Final validation passed every ordinary gameplay/network gate. One complete-suite
  course run missed its timing-sensitive rebound sample; the immediate isolated
  repeat passed at 1.366 units, followed by passing reverse, gate, combat, RC orb,
  shield, and detonation gates. `git diff --check` is clean.
- Hardened the forced-TURN harness against stale processes and mismatched runs:
  unique run identity spans browser/server/TURN/evidence, readiness verifies
  connection/state/nonzero RTT, cleanup owns exact resources, and the lifecycle
  regression passes both `INT` and `TERM` with successful port rebinding.
- Added multi-signal correction telemetry and HUD counts for stall, stale,
  impact, and unknown causes, including route-specific applied age, recovery,
  rollback/history, frame/process, contact, proxy/authority, and map evidence.
- Diagnosed the teleport as StateBundle route starvation. Remote-input authority
  settled during historical replay, but the post-rollback flush discarded those
  route entries while healthier server-owned routes masked the freeze. The
  bundler now retains the newest settled entry per route, preserves its source
  tick ordering, and explicitly requests a coordinated key after apply failure.
- Human forced-TURN run `20260822T185708Z-56142-16179` was smooth without contact
  and through accepted rear, head-on, and repeated side impacts. State age stayed
  mostly 6-11 ticks with no stale recovery loop. Controlled impact corrections
  remained about 0.176-0.561 units, so collision disagreement was not the jump.
- Human stall-control run `20260822T191625Z-58196-23649` injected one 695 ms
  main-thread pause. The world visibly slowed as FPS briefly reached 4, but no
  network jump/teleport occurred; recoveries, key requests, rejected states, and
  fast-forwards stayed at zero. The harness observer now starts clear of the lane.
- Focused parser/classifier/coalescing/lifecycle checks pass. The G2 divisor-1
  120 ms native gate passes with a 0.302-unit worst correction. The complete
  `./scripts/test.sh` suite passes (`ALL_TESTS PASS`).

## Networking-2 reconnect soak (2026-08-22)

- Added an exact-resource 600-second forced-TURN soak with a stationary native
  survivor, one browser leave/rejoin, forced relay proof, topology assertions,
  correction/recovery/movement telemetry, and bounded queue/error checks.
- The first long diagnostic exposed harness contamination: its mouse helper
  continuously drove the replacement into arena geometry and produced a
  4.845-unit correction. Canvas center was also not neutral under the isometric
  camera, causing one 3.833-unit startup recovery. Long soaks now use the
  harness-only `script=idle` input path; ordinary browser input and short
  movement smokes are unchanged.
- Run `20260822T222345Z-66042-30123` completed all 600 seconds with 607 shared
  samples, zero recovery, 0.000887-unit worst correction, 0.00013-unit maximum
  planar displacement, zero browser errors, a 3,558-byte peak browser queue,
  and 194,333 TURN qdisc packets with zero drops. The final 30-second renderer
  window held a 30 FPS minimum / 41.67 average; long unattended acceptance uses
  30 / 40 while the short playable smoke retains 30 / 45.
- Reconnect testing also found two presentation lifecycle defects unrelated to
  transport: empty dot meshes after teardown and troop visuals assigned a
  global transform before entering the scene tree. Both now have focused
  regressions and no longer emit browser errors.
- Focused import, syntax, dots, troop, explicit-idle, and unchanged-report
  checks pass. The permission-correct complete `./scripts/test.sh` run passes
  every gate (`ALL_TESTS PASS`); an earlier sandboxed attempt reached the
  lifecycle listener with `listen EPERM` and is not a code failure.

## Networking-2 two-player presentation (2026-08-23)

- Added a hardened mixed-client harness with one direct native ENet player and
  one Chrome player forced through TURN at 120 ms one-way. An atomic per-port
  run lock closes the preflight/build race that previously allowed overlapping
  launches; the lifecycle regression also proves a concurrent launch is
  rejected before either run can mutate shared resources.
- Added a harness-only 480 x 480 arena, client-local `P` cruise input, and an
  `L` presented-motion recorder/graph. Cruise enters through the same local
  input path as human control. Each trace has monotonic/unix timestamps plus
  frame, network, correction, recovery, and rollback context, and a new capture
  archives the prior samples before clearing the visible line.
- Moving-observer traces separated renderer cadence from transport recovery.
  The native-observer trace held 59 median FPS with 0.038-unit p95 residual;
  the Chrome-observer trace ran near 32 median FPS with 0.058-unit p95 residual.
  Error was overwhelmingly longitudinal and correlated with uneven local frame
  time; both had zero stale recovery. A discarded overlapping-launch run instead
  showed a clock about 109 ticks ahead and repeated 6-22-unit stale snaps,
  confirming why run identity/locking is required.
- Added opt-in local presentation reconciliation for the detached local Jeep
  hull and its camera anchor. It feeds forward the raw physics velocity and
  applies frame-rate-independent half-life correction, snapping genuine pose
  changes above 2 units. Physics, rollback, collision, and input remain raw;
  ordinary launches leave the feature disabled.
- Human run `20260823T202607Z-81872-13577` used direct native ENet plus Chrome
  forced TURN, 120 ms one-way, divisor 1, fixed proxy 75-150 ms, the harness
  capsule, and local presentation enabled. Chrome driving beside a cruising
  native Jeep and native driving beside a cruising Chrome Jeep were both rated
  smooth with no visual issues. Recoveries stayed at zero. Median FPS was 85
  native and 42 Chrome; the browser's ordinary roughly 0.3-unit rollback
  corrections were no longer visible as tugging.
- Focused smoothing, cruise, motion-trace, remote-presentation, harness-lifecycle,
  clean import, and Web export checks pass. The complete permission-correct
  `./scripts/test.sh` suite passes (`ALL_TESTS PASS`).
- After acceptance, the normal Networking-2 launcher retains `P` client cruise
  for repeatable driving comparisons but leaves `L` motion tracing disabled.
  Ordinary play enables neither; both remain explicit harness options.

## Next

- Run the oil branch through `./scripts/play_local.sh` in the safe decorated
  window. Drive across the west (-48, 0), east (47, 23), and south (14, 50)
  patches at speed; judge straight-line veer, correction fishtail, sharp-turn
  over-rotation/spin frequency, decal readability, and whether the short residue
  feels fair. Tune only the constants in `world/oil_slick.gd` and the decal
  shader after this human pass.
- Keep defensive oil drops out of this checkpoint. If world slicks are accepted,
  design dropped slicks separately as a bounded server-authored event-driven
  object family with lifetime/count limits and a representative multiplayer
  load gate; reuse the same footprint and handling response rather than adding
  physics bodies or per-slick rollback history.
- Run `./scripts/play_vehicle_animation_lab.sh` and judge each preset from front,
  rear, and three-quarter views. Tune only the presentation constants after a
  human pass, then compare the accepted lab poses during normal cursor driving;
  do not change FOLLOW handling or the rollback collider as part of animation
  polish.
- Extend the lab with repeatable airborne, ramp landing, and bump conditions.
  Let authoritative physics own the actual trajectory/contact while the visual
  rig adds wheel droop, impact compression, rebound, and settling. Do not add
  physical wheel colliders; defer independent terrain probes until a normal
  gameplay-view comparison shows that whole-car bump response is insufficient.
- Gameplay capsule integration is merged to `master` at `372bffe`. Ordinary
  gameplay now defaults to the accepted horizontal capsule (radius 1.05, total length 3.40),
  while `--player-capsule` and `--no-player-capsule` remain synchronized A/B
  controls for player and server-driver bodies.
- Gameplay projectile sweeps, RC-orb rams/blasts, area effects, and local impact
  prediction now query the active capsule or sphere instead of assuming the old
  1.55-radius sphere. Reverse-test wall clearance was corrected without changing
  the capsule, and projectile torque was raised to preserve readable shielded
  jostle under capsule inertia while retaining exact 15% shield passthrough.
- Focused capsule geometry plus course, reverse, gate, ball, tractor, combat,
  RC-orb, shield, detonation, and 120 ms two-player collision gates pass. The
  complete `./scripts/test.sh` suite passes (`ALL_TESTS PASS`). Local human
  handling and the final shaped-network collision pass are accepted.
- Replaced the temporary in-game Debug button with G2's standard `MenuBar`
  pattern (`prefer_global_menu = true`), giving macOS a native `Debug` menu and
  a fallback menu bar elsewhere. `Show collision capsule` draws a translucent
  cyan mesh from the local player's active collider and exact transform without
  changing physics. `Show gameplay text` hides only status/help and coverage
  editor labels; FPS, network diagnostics/notices, and pre-connection status
  remain visible. The focused presentation/collider contract and clean import
  pass. The complete suite reached the course gate, where three
  reruns hit its documented timing-sensitive landing sample (zero rebound twice,
  then 0.174-degree jostle); all preceding tests passed and the debug path is
  absent from headless physics runs. The native menu and both toggles were
  visually accepted.
- Final human network run
  `networking1-enet-latency120-proxy-20260823-173834` used this exact branch at
  120 ms one-way against the remote server-driven capsule. Rear, head-on, side,
  and sustained contacts felt good to the user. Evidence recorded six contact
  samples, a 0.472-unit worst correction, zero recovery, no runtime/rollback
  error, and a clean monitored exit. The earlier forced-TURN launch did not
  reach gameplay because TURN allocation timed out; it is infrastructure
  evidence, not a collision failure.

- Gameplay capsule integration is accepted and merged. Preserve the capsule
  dimensions and fixed 75 ms presentation default.
- Combined impairment and adaptive cadence may resume only as a separate next
  experiment; neither was changed to accept the 120 ms forced-TURN result.

- Start the next session in `/Users/johnnguyen/Projects/car-fight-network` on `feature/network-shaping`, pull, then run `./scripts/play_shaped_local.sh latency120`. This is the accepted one-observer visual harness: the cursor line and interactive grass remain visible; ramps, the physical arena ball, the shield-test drone, and orange peer markers are intentionally absent. Do not revisit these fixture decisions unless runtime evidence contradicts them.
- First judge remote motion on the long north/south straightaways rather than during cornering. Record whether stutter correlates with low FPS, whether the two Jeeps remain in one world, and the evidence directory printed by the launcher. Avoid changing route or presentation during the observation run.
- Then compare one condition at a time with the same route: `clean`, `latency120`, `jitter`, and `CAR_FIGHT_STATE_RATE_DIVISOR=1 ./scripts/play_shaped_local.sh combined`. Divisor 1 is required for the accepted combined baseline; fixed divisor 3 previously failed combined startup correction.
- After the native visual comparison, bring the same straight-moving server fixture and fixture exclusions to the browser harness, then evaluate Chrome under the same named profiles. Repair the isolated forced-TURN ICE setup before treating remote browser shaping as valid evidence.
- If straight-line stutter remains at healthy FPS, inspect remote batch cadence/interpolation and correction telemetry. If it appears only when FPS falls toward 10-15, continue the rollback replay-cost investigation. Do not re-enable the rejected resimulation budget; all three budget experiments caused divergence.
- Keep the merged `master` as the integration baseline; the feature worktrees are no longer needed for gameplay integration.
- Deploy to macai2 only as a separate explicit step; this merge did not alter the production UDP 10080 service.
- Resume feature development from this accepted Godot implementation rather than reconstructing existing gameplay in Unity.
- Keep the merged Phase 0 window safety and Phase 1 offline browser checkpoint as the current baseline.
- Keep the accepted localhost mux proof isolated on new ports. The next browser-network step is the explicit remote/TURN latency-loss matrix and soak; do not deploy or add Web transport directly to macai2 UDP 10080 without a separate decision.
- Keep using the monitored windowed launcher on this Mac. Do not merge the diagnostic branches or repeat known Godot fullscreen, edge-to-edge, ANGLE, or Vulkan experiments.
- Review the preserved Unity native multiplayer acceptance evidence and add only the missing high-value Godot regressions; do not reproduce Unity-specific infrastructure.
- Treat the native peer lifecycle baseline as complete for current scope. Keep the detached-node guard and reconnect gate; do not reintroduce the rejected half-handshake-RTT seed or treat adaptive cadence as part of the baseline.
- Before the next gameplay-object family, establish a representative network/object load gate and an explicit per-class replication budget. The G2-derived A/B tools now exist, but each new family still needs the cheapest correct replication class and measured wire/CPU bounds.
- Keep the adaptive-presentation branch unmerged for now. Its passive interpolation-delay experiment is separate from stale rollback recovery and is not required by the accepted single-client result.
- Next browser-network workstream: repair/retry the isolated TURN ICE path with the G2 profile, then run the full browser profile matrix and a bounded monitored human soak. Keep the transport, FPS, lifecycle, and 64 KiB bounds fixed; do not reinterpret the latest pre-game ICE timeout as a stack result.
- Keep the fixed 20 Hz state cadence out of the combined-impairment default until its startup correction is fixed; use divisor 1 there or continue evaluating the passing adaptive 3 -> 2 -> 1 policy.
- Keep the rollback-resimulation budget unset. Three shaped experiments, including the coordinated full-stack retest, prove that dropping correction origins can preserve FPS while visibly desynchronizing. Future replay work must preserve every authoritative origin, reduce replay cost, or continue reconciliation safely across frames.
- Next native-platform workstream: add a Windows export/build smoke following G2's packaging pattern, including the matching Windows WebRTC-native extension binary for explicit mux/WebRTC tests. Windows remains ENet by default; platform-specific integration stays outside gameplay code.
