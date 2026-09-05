# Batched sprite drawing prototype

Opt-in, presentation-only MultiMesh drawing for the existing survivor/thug
samples. Godot 4.7.1 Compatibility is unchanged. AI, hitboxes, authority, network
messages, interpolation and sprite size/ground-registration rules are unchanged.

In Debug → Sprite test, choose **Drawing (local prototype) → Batched modern
sprites**. Select Original sprites to switch back without resetting AI.
Original drawing remains the default; ghoul art uses the original path.

```sh
CAR_FIGHT_SPRITE_BATCHED=1 CAR_FIGHT_SPRITE_AI=attacker CAR_FIGHT_SPRITE_COUNT=256 CAR_FIGHT_SPRITE_SAMPLE=survivor ./scripts/play_monitored.sh --offline --sprite-test
```

## Representation and limits

- Four action batches at most, each with capacity 256. One atlas/material per
  action, shared camera-facing quad geometry within each batch.
- Instance data selects each native clock's current frame and the current
  camera-relative facing. Managed animation applies current clip intent before
  upload. Shader geometry uses the
  existing pixel size, offset and world position; color carries hit flashes.
- Native AnimatedSprite3D nodes remain hidden but retain independent clocks,
  pause, replay and finished-death semantics. In managed batches their directional
  script callbacks are disabled. Four canonical frame sets are retained per
  batch lifetime; turning selects an atlas row without swapping hidden native
  frame resources. Original drawing resumes its script and real directional
  frames on fallback. Native internal clock/update costs still exist.
- The existing unshaded appearance, depth testing, transparent contact shadows
  and linear/nearest mipmap choice are retained. No new art or collider changes.
- Batches are cleared on fixture reset/retirement, sample change, disable or
  fallback. All original drawings are restored on fallback. No batches are
  constructed by the lab in headless mode.
- Whole-city bounds cover the current fixture area plus billboard extents.
  There is no per-sprite culling within a batch and no per-instance transparent
  sorting. Dense overlapping translucent shadows need continued visual review.
  A larger world would need spatially divided batches; not implemented here.

## Initial same-process A/B

Monitored run `20260904-225555` closed cleanly, no engine/script errors.
256 spawned survivor attackers, fixed car at (0,1,0), debug off, 15 seconds
convergence followed by six seconds per sample. Other car combat suppressed;
AI practice shots and ordinary run-over deaths remain active.

| Phase | Median / P95 frame | Endpoint draw calls | Alive |
| --- | ---: | ---: | ---: |
| Original | 51.364 / 59.452 ms | 343 | 227 |
| Batched | 32.996 / 48.014 ms | 159 | 226 |
| Original repeat | 50.892 / 57.927 ms | 342 | 229 |
| Batched repeat | 32.676 / 40.980 ms | 165 | 226 |

Approximately 20 → 30 FPS, measured as reciprocal of median frame time.
All 256 bodies/corpses are represented in batched samples; dead sprites are not
silently removed to improve the result. Trajectories and machine scheduling
still vary. It is not a 60-FPS guarantee or a network/server-capacity result.
Paired original/batched screenshots were inspected and closely match at the
tested city camera; this is not complete visual acceptance for every camera,
size, character and overlap case.

Initial evidence: `.crash-runs/batch-profile/` (results and paired images).

Final loaded-frame implementation: monitored run `20260904-230222` also
closed cleanly and passed real GLES transform/custom-data and fallback checks.
Original median/P95 samples were 50.613/58.792 and 49.169/56.278 ms; batched
samples were 33.268/42.577 and 32.379/38.439 ms. Original draws 344/339,
batched 163/161; alive counts 227/229 versus 226/226.
Final artifacts: `.crash-runs/sprite-batch-1788580961/`.
The short visual-only follow-up `20260904-230609` also closed cleanly and
passed uploads/fallback. It explicitly holds offline movement and sprite
poses; camera settling still shifts the whole view slightly, so its images
are not a pixel-identical comparison. Captures:
`.crash-runs/sprite-batch-1788581189/`.

## Reproduction and gates

```sh
./scripts/check.sh
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . --script res://tests/sprite_test_lab_test.gd
CAR_FIGHT_SPRITE_VISUAL_CHECK=batch CAR_FIGHT_SPRITE_AI=attacker CAR_FIGHT_SPRITE_SAMPLE=survivor ./scripts/play_monitored.sh --offline --sprite-test
```

The bounded rendered probe alternates original/batched twice, saves paired
held-pose screenshots, verifies actual GLES instance uploads against native frame/
transform data, checks fallback, then quits. Output is under
`.crash-runs/sprite-batch-<timestamp>/`.
Headless Dummy rendering does not retain uploaded MultiMesh buffers, so the
headless contract tests check generated instance data and lifecycle; real GPU
upload verification belongs to the rendered gate.

Focused AI runtime and offline startup gates cover the unchanged gameplay and
construction path. No RPC/schema or physics change requires a broad suite here.

Design references: [Godot MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html)
and [spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).
Instancing reduces drawing overhead, not AI or collision cost.
