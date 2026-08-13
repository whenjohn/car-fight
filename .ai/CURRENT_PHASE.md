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

## Next

- Play-test the expanded mouse range and automatic drift timing in the real arena. Tune initiation, rotation, and recovery by feel before adding drift presentation or combat-driving objectives.
- Recheck the shield and hit feel at the new west clearing, then tune the shader/SFX layer. Audio remains intentionally unimplemented for this visual-first pass.
