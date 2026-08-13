# Current phase

## Completed

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
- Documented two nearly identical WindowServer watchdog failures in `.ai/CRASH_LOG.md`. In both, the rendered Godot 4.7 client had been alive for about 69 seconds and the same built-in Intel display framebuffer became unready. Treat the rendered client/native OpenGL path as a probable trigger, not a proven game-logic crash. No mitigation or project change was applied at the user's request.
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

## Next

- Continue gameplay work, but do not automatically launch a rendered local client. Read `.ai/CRASH_LOG.md` first and get explicit approval before a rendered test because two attempts have killed WindowServer. Headless tests remain appropriate.
- When rendered testing is authorized, compare the same sharp corner first with an ordinary close-cursor pull and then with a latched drift. The ordinary line should still beat far-cursor steering but require a clear arc; the drift should earn a materially tighter high-speed 90-degree exit.
- Recheck the shield and hit feel at the new west clearing, then tune the shader/SFX layer. Audio remains intentionally unimplemented for this visual-first pass.
