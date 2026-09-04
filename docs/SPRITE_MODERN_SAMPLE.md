# SmallScaleInt modern character audition

Source: https://smallscaleint.itch.io/character-creator-2d-modern
Author: SmallScaleInt. Retrieved 2026-09-04.

Only the two explicitly free pre-exported characters are used. The full creator
is paid ($34.99 at retrieval); no purchase or creator installation was made.
The source page permits these free characters in games. Its licensing section
permits created sprites in your own games/interactive projects and prohibits
redistributing them as an asset pack or character bundle. This is not CC0.
Keep the archives and PNGs in ignored `assets/local/`, not the public repository.

## Install and compare

Use Download Now → No thanks, just take me to the downloads on the source page.
Download both FREE archives and extract into `assets/local/smallscale-modern/`,
preserving the archive's folder names:

```
assets/local/smallscale-modern/
  FREE Character HD Survivor W Bike/
    Idle.png  Walk.png  Attack1.png  Die.png  …
  FREE Character 16-bit Thug Outlined/
    Idle.png  Walk.png  Attack1.png  Die.png  …
```

Import with `./scripts/check.sh`, then launch:

```sh
CAR_FIGHT_SPRITE_SAMPLE=survivor ./scripts/play_monitored.sh --offline --sprite-test
# Or CAR_FIGHT_SPRITE_SAMPLE=thug
```

Debug → Sprite test… → Character (local) switches between available samples.
The original ghoul remains the default. Missing local art falls back to ghoul
and is not offered in the selector. Selection is presentation-only per client;
no RPC/state schema, hitbox, damage, movement, or targeting changes are made.
Start with 16 fixtures: the known 256-target acquisition CPU issue is unresolved.

## Frame interpretation

- HD survivor: 128px cells, 14 columns × 8 rows for the four selected clips.
- Outlined thug: 64px cells, 8 columns × 8 rows for those clips.
- Source rows: E, SE, S, SW, W, NW, N, NE, checked against composited PNGs.
- Idle/Walk loop; Attack1/Die play once. The same 12 FPS adjustable baseline
  is used because the archives do not include playback timing metadata.
  More frames per clip does not inherently mean higher playback FPS.
- Fixed ground registration at (64, 91), scaled by native cell size, and a
  roughly 44px standing height at 128px keep approximately the same world size
  as the existing 1.8-unit capsule. Registration is shared across animations.
- Modern samples use alpha blending with an opaque depth prepass to retain
  their baked translucent foot shadows. The original ghoul keeps alpha discard.
  Wall/ground depth testing remains enabled; no realtime shadow maps are added.
- PNG sheets load on demand and share resources across instances. The thug
  uses nearest filtering; survivor uses linear filtering. Ghoul resolution
  controls do not resample the new samples; they stay at native resolution.
- Only four animations are wired into the existing test. Other supplied clips,
  guns and bike are art, not authorization for new gameplay.

Archive upload IDs: thug `13539019`; survivor `13539020`. Original archives
are retained locally as `thug.zip` and `survivor.zip` alongside extracted folders.

## Validation and remaining visual work

Fast check, expanded `sprite_test_lab_test.gd` with both packs present, and
`sprite_combat_test.gd -- --offline --no-drone` passed. The latter exercised
three-hit death, run-over, reset and all fixture counts. No network/authority
schema changed, so a full multiplayer milestone suite was not required.

Local captures under `.crash-runs/sprite-visual-1788559755/` show the survivor's
idle, walk, attack and death; `.crash-runs/sprite-visual-1788559840/` contains
the thug idle view. Some survivor death directions clip into the road: shared
standing-foot registration is not a finished solution for these prone poses.
Keep that visible limitation for the next alignment pass rather than claiming
polished death presentation. Both monitored diagnostics were stopped explicitly
while awaiting further rendered frames, before the complete perspective/UI
capture sequence. No complete visual-check PASS or performance result is claimed.
Owner subsequently preferred these modern samples over the ghoul and reported
that they look smoother. This is visual preference feedback, not acceptance of
the remaining death-alignment issue or a measured performance improvement.

## Owner observation and future selection criteria (2026-09-04)

Shadow follow-up: inspected original idle PNGs and confirmed baked foot shadows
in both samples. Sampled main-shadow opacity is 164/255 (~64%), above the old
50% discard threshold; softer pixels below the threshold were removed. Thus
alpha discard did not remove the whole shadow. The initial row-88 anchor also
intersected bottom rows with the ground. Trial now uses opaque-prepass blending
and a row-91 anchor (source idle bounds reach row 90). This preserves translucency
and clears those idle rows without changing world scale or hitboxes. Shadows
still belong to the billboard, not a separate ground-projected layer; prone
poses and other camera/animation combinations still need visual evaluation.
Fast check and expanded sprite contracts pass. Monitored interactive trial
`20260904-174127` started with 16 survivors. After the repeat run
`20260904-174641`, the owner confirmed that the shadows help ground the sprites
and reduce the floaty appearance. Keep this adjustment. This accepts the shadow
improvement, not the still-unresolved death-pose alignment.

The modern samples look better and smoother to the owner than the ghoul.
All three have eight directions and default to 12 animation FPS in this test.
Playback settings during the owner's comparison were not recorded, so this was
not a controlled equal-speed comparison. No extra angles or higher configured
default FPS explain the preference by themselves.

Possible explanations include clearer silhouettes at gameplay scale, better
pose spacing and loop transitions, and less distracting fine-detail shimmer.
These are hypotheses, not findings established by frame-by-frame analysis.

For the next sprite audition:

- Judge at the actual gameplay camera distance, against the city background.
- Prioritize readable silhouettes, stable feet, natural motion and clean loops
  over advertised resolution or total frame count.
- Check contact shadows at gameplay scale: the owner confirmed that preserving
  these baked shadows improves grounding. Inspect transparency and ground
  clipping in-engine, not only the pack preview.
- Compare direction changes as well as idle, walking, attack and death; verify
  ground alignment and that poses remain readable in all eight directions.
- Record playback rate, filtering, camera, world scale and fixture count for
  fair comparisons. Distinguish animation FPS from game/render FPS.
- Evaluate additional angles separately from animation quality. More directions
  may reduce turning jumps, but eight can already look good to the owner.
- A faster playback setting speeds up existing motion; it does not add poses.
  Compare cycle duration and pose spacing, not just frames per animation.

Keep SmallScaleInt's modern samples as the preferred visual comparison reference
for future packs. This does not change the default sample, authorize a paid
purchase, or establish a character theme for the game.
