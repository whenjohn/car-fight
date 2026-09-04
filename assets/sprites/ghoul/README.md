# Sprite test sample

Source: https://whiteknightstudios.itch.io/free-animated-character-ghoul-zombie
Author: W_K_Studio / White Knight Studios.
Downloaded 2026-09-04, `ZOMBIE 1.rar` (itch upload 10805823).
The creator labels this asset CC0 and explicitly permits unlimited commercial
and private use. CC0: https://creativecommons.org/publicdomain/zero/1.0/

These are sample visuals for Car Fight's sprite experiment, not a game theme.
The original archive supplies 128px and 512px individual PNG frames in named
compass directions. No playback timing or additional license file is supplied.
The test defaults to adjustable 12 FPS.

Rebuild the lossless atlases from an extracted archive with:

```
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://scripts/pack_sprite_sample.gd -- /absolute/extracted/archive
```

Packing trims transparent padding, retaining each frame's original offset and
canvas dimensions in `frames.json`. It does not resample or recolor the source.
Atlases have transparent gutters. Original full-size canvases are reconstructed
with AtlasTexture margins, preserving animation registration and foot position.
Runtime resources are loaded per resolution/animation/direction and shared by
instances; inactive clips are released when no sprite references them.
