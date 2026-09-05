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

## Count sweep (2026-09-05)

Owner requested a lower-count recommendation for ~60 FPS. The existing probe
now accepts `CAR_FIGHT_BATCH_COUNT_SWEEP=1`, selecting batched 256/128/64/16/0
then repeated 16/64/128. Each uses the same 15-second warmup and six-second
wall-clock draw sample. Zero disables the lab; it does not add a gameplay count
option. All other settings match the managed-animation comparison above.

Run `20260905-012152` at `d0b987b` plus the diagnostic runner addition, results
`.crash-runs/sprite-batch-1788589333/`:

| Spawned | Alive at sample end | Median frame ms | Approx. typical FPS | P95 frame ms |
| --- | ---: | ---: | ---: | ---: |
| 256 | 226 | 26.334 | 38 | 32.218 |
| 128 | 72 | 17.483 | 57 | 24.159 |
| 64 | 28 | 15.222 | 66 | 28.014 |
| 16 | 16 | 11.725 | 85 | 22.836 |
| 0 | 0 | 11.523 | 87 | 23.513 |
| 16 repeat | 16 | 12.611 | 79 | 26.203 |
| 64 repeat | 28 | 14.722 | 68 | 28.218 |

Dead sprites remain rendered corpses, but no longer run AI movement/shots.
Therefore this is **spawned-setting performance, not a full-active capacity
claim**. A practical next playtest setting is 64, but these results do not prove
that 64 living attackers sustain 60 FPS. Even the zero-sprite city had a P95
above 16.7 ms, so fewer sprites alone do not establish a locked 60 FPS.

The window remained 1280x720 and recorded CPU speed limits stayed 100. Monitor
outcome was clean and no engine/script errors were found. Exclude the final
128 repeat: the window became obscured, `frame_post_draw` stopped arriving and
resuming it produced one 101,254 ms sample. That phase also overlapped an import
check and is not usable evidence. The runner currently requires a visible
window; a draw-signal await can outlive its nominal six-second measurement
window when rendering is suppressed. Do not mistake occluded-window engine FPS
or a single resumed sample for rendered performance.

To separate spawn/death effects, a temporary offline fixture suppressed hits
while retaining movement/contact queries, aiming to measure all 128/64/16 alive.
Run `20260905-012717` was also repeatedly obscured and produced no usable sample.
It was explicitly stopped with SIGTERM (`client-exit-143`), not an unexplained
game crash. Its diagnostic patch is preserved in the run directory. All hit
suppression and temporary follow-up runner changes were removed; gameplay source
matches HEAD. Full-active capacity remains unmeasured rather than inferred.

Fast check passed for the retained count-sweep addition; its requested phases
were exercised by the first run. Temporary fixture import passed separately.
No networking, defaults, AI, movement or collision behavior changes are shipped.

## Verified stationary-Jeep / 128-live test (2026-09-05)

Owner explicitly requested 128 attackers with the Jeep stationary and no
run-over deaths in the diagnostic. Baseline `18e2f92`, same Godot/Compatibility,
1280x720 window, survivor size 1, managed batches, debug off, offline.
The temporary hit-suppression fixture retained all AI, world movement sweeps
and vehicle contact calculations, but prevented hits from reducing sprite
health. Jeep frozen at (0,1,0), linear/angular velocity zero; ordinary car combat
suppressed using the existing fixture-isolation flag. Sprite practice shots
remained active. This is a count-load diagnostic, not shippable invulnerability.

Two fresh configurations, each with 15 seconds of warmup and 12 seconds of
wall-clock `frame_post_draw` samples:

| Sample | Frames | Live / drawn throughout | Median ms | P95 ms | P99 ms | Worst ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| First | 564 | 128 / 128 | 20.411 | 26.924 | 29.644 | 31.581 |
| Repeat | 565 | 128 / 128 | 20.356 | 26.690 | 30.140 | 31.956 |

Typical rate is ~49 FPS by reciprocal median, with P95 frame times equivalent
to ~37 FPS and worst measured frames ~31 FPS. Neither window contained a frame
over 33.333 ms. This is **not 60-FPS acceptance**, but it is valid evidence for
128 live attackers, unlike the earlier 128-spawn sample with only 72 alive.
It does not establish moving-player, sustained thermal-soak or network capacity.

Each recorded frame verifies alive=128 and drawn=128. The runner also rejected
Jeep movement, resizing, a draw gap over one second, no draw for 2.5 seconds,
or an overall timeout, rather than accepting an occluded-window result. Both
windows were focused throughout and lasted 12.008 / 12.003 wall-clock seconds.
Practice shot creation was 1,132 / 1,139 per sample; some shot hits belong to
bullets created before each window. Recorded CPU performance limits stayed 100.
No cap or VSync setting was changed (`max_fps=0`, VSync enabled).

Run `.crash-runs/20260905-014909/` closed cleanly with no engine/script errors;
the familiar long startup pause was outside measured windows. Raw per-frame
rows, settings and summaries: `.crash-runs/live128-1788590968/`.
Temporary fixture/runner patch: `20260905-014909/diagnostic.patch` under the
monitor root. Diagnostic import passed before launch. All temporary code was
removed afterward and both touched source files exactly match `18e2f92`.
This follow-up commits documentation only; source-restoration and diff checks
are the relevant gates. No network work, gameplay tuning or default change.
