# Current phase

## Completed

- Added a fixed, non-targetable arena drone that fires a slow server-authored bolt every two seconds at the nearest visible driving player.
- Added authoritative player impacts with a small linear deflection, torque jostle, and short steering-recovery window.
- Added a freely toggled `Q` shield that absorbs 85% of the drone shove; cloak and shield are mutually exclusive, with cloak taking priority.
- Added a glass bubble shader, localized shield ripple, ordinary impact burst, client-side visual prediction, and authoritative event deduplication.
- Added focused impact math, presentation, and network gates; the complete `./scripts/test.sh` suite passes.

## Next

- Play-test the shield and hit feel in the real arena, then tune the shader/SFX layer. Audio remains intentionally unimplemented for this visual-first pass.
