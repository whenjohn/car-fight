# Mac Intel true-fullscreen spike

This branch keeps true macOS fullscreen as a hard requirement. It tests whether
presentation setup or frame pacing can avoid the built-in Intel display's
`Invalid actual_host_time` loop. It does not change gameplay.

## Established boundary

- Long monitored windowed sessions did not emit the display-timestamp error.
- Native OpenGL and ANGLE/Metal true fullscreen both emitted it immediately.
- Minimal isolation reproduced without ENet, input, spawning, or replication.
- A later g2 session remained visibly playable but emitted 5,569 matching
  WindowServer errors from `02:27:26` until fullscreen ended at `02:30:46`.
- A same-spec `macai2` closed-lid windowed smoke test completed cleanly, but its
  powered-off panel reported 0 Hz. It validates the remote capture path only
  and must not be treated as an active-panel baseline or fullscreen result.

The visible game surviving is therefore not a clean result. A pass requires
zero `Invalid actual_host_time` messages and no later VBlank/display/watchdog
failure during the two-minute post-exit watch.

## Safety contract

Every rendered run can crash WindowServer after Godot has already stopped.

1. Reboot the whole Mac before the first approach. A WindowServer restart did
   not prove sufficient to reset the Intel framebuffer state.
2. Close unrelated work and run only one approach per boot.
3. Inspect the command first with `--dry-run`.
4. A real run requires the literal `--accept-crash-risk` acknowledgement.
5. If the login session restarts, run `./scripts/collect_crash_run.sh` before
   starting another Godot process.

The launcher detects the first invalid timestamp, takes a synchronized deep
snapshot, stops the rendered client, and observes WindowServer for 120 seconds.
It also stops cleanly after 30 seconds if no precursor occurs.

## Commands

```sh
./scripts/fullscreen_spike.sh list
./scripts/fullscreen_spike.sh run vulkan-runtime-vsync --dry-run
./scripts/fullscreen_spike.sh run vulkan-runtime-vsync --accept-crash-risk
```

Evidence is stored under `.fullscreen-spike-runs/`. A completed run invokes the
collector automatically. After a WindowServer restart, or to recollect later:

```sh
run_dir="$(< .fullscreen-spike-runs/last_run)"
./scripts/collect_crash_run.sh "$run_dir"
cat "$run_dir/report-summary.txt"
```

## Approach order

The highest-value order is:

1. `vulkan-runtime-vsync` — changes renderer family to Vulkan/MoltenVK while
   preserving true fullscreen, VSync, and a five-second windowed lead-in.
2. `opengl-runtime-cap60` — tests explicit pacing at the panel's nominal rate.
3. `opengl-runtime-cap30` — tests whether lowering presentation pressure helps.
4. `opengl-runtime-novsync60` — tests whether decoupling Godot from VSync while
   retaining a bounded 60 FPS render loop changes the display timing failure.
5. `opengl-runtime-vsync` — known-path runtime-transition control.
6. `opengl-startup-vsync` — compares process-start fullscreen to runtime entry.

Do not run the controls first merely to reconfirm the known failure. On macOS,
Godot exclusive fullscreen is equivalent to ordinary fullscreen, so it is not
a distinct experiment. ANGLE is omitted because it already failed.

## Result classification

- **FAIL — precursor:** any `Invalid actual_host_time` for the built-in display.
- **FAIL — system:** VBlank timeout, display-not-ready, WindowServer event-port
  death, changed WindowServer PID, or a new WindowServer watchdog report.
- **INCONCLUSIVE:** renderer/script failure before telemetry confirms true
  fullscreen, or the requested mode is not `fullscreen` at 2880 x 1800.
- **PROVISIONAL PASS:** zero precursor/system events through the run and
  post-exit watch. Repeat the same approach only after a reboot; two clean runs
  are required before trying it in g2.
