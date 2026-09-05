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

The historical results below describe the initial drawing prototype; the
managed-animation follow-up is recorded at the end of this document.

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

## Managed-animation follow-up (2026-09-05)

At `625c3f9`, the batch disables hidden directional script callbacks, retains
four canonical frame sets and selects facing directly in instance data. Native
clocks remain independent. Headless contracts cover actual clock advancement,
different individual frame positions, eight facings, completed deaths, replay,
freeze/rate controls, sizes, sample changes and original-renderer restoration.
Those tests, AI runtime and fast check pass. No simulation or networking changes.

Before/after use the same offline fixed-car attacker scenario, 256 survivors,
size 1, batched drawing, debug off, 15-second warmup then six seconds measured,
twice per run. `CAR_FIGHT_BATCH_PERF_ONLY=1` selects these two batched phases
without the original-drawing/screenshot tail. Full command:

```sh
CAR_FIGHT_BATCH_PERF_ONLY=1 CAR_FIGHT_SPRITE_BATCHED=1 CAR_FIGHT_SPRITE_AI=attacker CAR_FIGHT_SPRITE_COUNT=256 CAR_FIGHT_SPRITE_SAMPLE=survivor CAR_FIGHT_SPRITE_VISUAL_CHECK=batch ./scripts/play_monitored.sh --offline --sprite-test
```

| Phase | Before median / P95, ms | After median / P95, ms |
| --- | ---: | ---: |
| First | 28.832 / 34.659 | 25.869 / 30.445 |
| Repeat | 29.321 / 35.162 | 25.076 / 31.065 |

Approximately 34–35 → 39–40 FPS by reciprocal median; a modest observed
10–14% reduction in median frame time, **not stable 60 FPS acceptance**.
This is not directly comparable to the owner's earlier 42–50 FPS interactive
driving: camera, convergence and surviving counts differ. All 256 sprites and
corpses remained batched, with endpoint alive counts 225/226 before, 226/227
after and draw counts 160/166 versus 162/168. Small trajectory differences,
machine load and separate-run timing prevent an exact isolated speedup claim.

Before run `20260905-002924`, data `sprite-batch-1788586184`, and after retry
`20260905-011034`, data `sprite-batch-1788588654`, both closed cleanly. The retry
has no engine/script errors and stayed at 1280x720; its five-second CPU-limit
samples remained 100, as did before-run start/end readings. The usual long
startup pause is outside timed windows. Intermediate after-run `20260905-003246`
was resized/closed before a result and is excluded, not counted as a performance
failure or success. Evidence directories are under `.crash-runs/`.

No new gameplay tests are needed for this documentation-only retry. A full
managed-path rendered visual check and owner feel acceptance remain separate
from this performance-only result; the original prototype's earlier screenshot
acceptance is not silently extended to the managed implementation.
