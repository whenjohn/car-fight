# SmallScaleInt HD knight audition

Source: https://smallscaleint.itch.io/hd-8-directional-top-down-character-pack-1
Author: SmallScaleInt. Retrieved 2026-09-04.

Only the explicitly free `2D HD Character Knight.zip` is used. The full pack's
other eight characters require $19.90 at retrieval and were not downloaded.
The source-page commercial license permits unlimited personal/commercial game
use and modification without attribution, but prohibits redistributing or
sublicensing the raw assets. Keep the archive and PNG sheets under ignored
`assets/local/`; this asset is not CC0 and must not be committed publicly.

## Install and compare

Use Download Now → No thanks, just take me to the downloads, download the free
knight archive, and extract it so this path exists:

```
assets/local/smallscale-knight/2D HD Character Knight/
  Spritesheets/With shadows/Idle.png
```

Then launch the local audition:

```sh
CAR_FIGHT_SPRITE_SAMPLE=knight CAR_FIGHT_SPRITE_COUNT=16 \
  ./scripts/play_monitored.sh --offline --sprite-test
```

It also appears as **HD knight (128px)** under Debug → Sprite test… →
Character (local). Missing local art is omitted and falls back to the ghoul.

## Test mapping

- 128px cells; 15 frames × 8 directions for each selected clip.
- Existing test clips map to Idle, Walk, Melee and Die.
- Source rows use E, SE, S, SW, W, NW, N, NE, matching the author's other
  exports and verified visually from the sheets.
- The supplied baked-shadow sheets are used. Opaque-prepass blending retains
  translucent shadow pixels while normal depth testing remains enabled.
- Measured first-frame bounds use a knight-specific 60px standing-height scale
  and row-112 ground registration. This is an audition starting point; owner
  visual judgment across moving, attack and death frames is still required.
- The pack contains many other animations, but this comparison wires only the
  same four states as the existing fixture. It adds no knight gameplay, gear,
  attacks, projectiles, collision or networking state.

Archive upload ID: `12895293`. The original archive is retained locally as
`assets/local/smallscale-knight/knight.zip`.
