# Car Fight

> **Project status:** This Godot implementation is again the active Car Fight
> project. The Unity handoff was superseded after its browser transport proved
> non-reproducible from tracked source and its Editor/build iteration conflicted
> with the required workflow. See
> [`MAC_INTEL_FULLSCREEN_FINDINGS.md`](MAC_INTEL_FULLSCREEN_FINDINGS.md) for the
> canonical affected-Intel-Mac evidence and windowed policy, and
> [`MIGRATION_TO_UNITY.md`](MIGRATION_TO_UNITY.md) for the engine-decision
> history. The next platform roadmap is in
> [`WEB_PLATFORM_PLAN.md`](WEB_PLATFORM_PLAN.md). Do not merge the diagnostic
> branches into this gameplay branch or rerun known-risk
> fullscreen/edge-to-edge probes merely to reconfirm them.

A deliberately small Godot 4.7 multiplayer prototype: configure automatic firing coverage, drive CC0 Jeeps with high-fidelity FOLLOW mouse control, carry momentum through automatic powerslides, physically bump other equal-mass vehicles, and test a glass vehicle shield against a slow stationary firing drone.

Native networking remains ENet with g2's proven netfox 1.35.3 + Rapier 0.8.39 core: server-owned physics and automatic target combat, client-owned input, local prediction, rollback reconciliation, and interpolation for remote bodies. An isolated localhost cross-play path now adds browser WebRTC without moving native clients off ENet; a server-side mux exposes both transports as one authoritative world. The vendored netfox includes G2's D-040 stale-history recovery patch: after a client stall advances beyond retained rollback history, impossible origins are skipped with a bounded warning while the client waits for fresh authority. Vehicle damage, health, bots, resources, alternate maps, and progression remain out of scope.

## Play

```bash
./scripts/play.sh                 # local server + one visible client
./scripts/join.sh 127.0.0.1      # another local client
./scripts/serve.sh               # server only, UDP 10080
./scripts/join_macai2.sh         # Tailscale address, if separately deployed
./scripts/play_macai2_two.sh      # two monitored native clients, remote server
```

## Offline Web build

The browser checkpoint is intentionally offline: it spawns one local Jeep and
the arena without opening ENet, changing the native server, or adding a browser
transport. Godot 4.7.1's matching Web export templates are required.

```bash
./scripts/web_build.sh release    # export build/web/index.html
./scripts/web_serve.sh            # serve only on http://127.0.0.1:8088
./scripts/web_smoke.sh            # release export + bounded Chrome smoke
```

The local server supplies the cross-origin isolation headers required by the
Rapier Web GDExtension. The smoke opens Chrome with a temporary profile,
focuses the canvas, drives through the normal mouse input path, captures a
screenshot and JSON telemetry under `build/`, then closes only the Chrome
process it started. It requires Rapier initialization, an offline-ready event,
movement, at least five telemetry samples, and no browser/script errors.

The accepted 2026-08-20 Chrome 151 release run used the single-threaded Web
export and a fixed 1280 x 720 render surface. Runtime ready took 2.42 seconds;
the final five samples averaged 59.6 FPS with a 58 FPS minimum, normal driving
reached 17.99 units/s, and the browser console was clean. A same-machine
threaded comparison produced no repeatable improvement, so threading remains
disabled. The offline preset remains the accepted standalone renderer
checkpoint.

## Local browser/native cross-play

The `Web Network` export connects browsers over WebRTC while the native macOS
client continues to use ENet. The mux server merges both into the same world;
WebSocket carries signaling only, never gameplay data.

```bash
./scripts/web_network_build.sh release  # export build/web-network/index.html
./scripts/web_network_smoke.sh          # automated browser + native ENet gate
./scripts/play_web_network_local.sh     # safe rendered browser/native session
./scripts/browser_native_baseline.sh    # separate-world render/CPU control
./scripts/mux_perf_test.sh              # pure ENet versus mux server CPU A/B
```

`play_web_network_local.sh` uses isolated localhost ports (ENet 12580, WebRTC
signaling 12581, HTTP 18089), launches the native client through the monitored
safe-window wrapper, and opens Chrome with a temporary profile. Closing the
native client ends the session and cleans up only the processes it started.
It does not deploy or modify macai2 UDP 10080.

The automated network smoke covers a browser refresh/replacement while the
native ENet peer survives, verifies changing two-player world snapshots and a
draining WebRTC queue, and records a JSON report plus screenshot in its printed
temporary directory. The current same-machine capacity floor is 30 FPS minimum
and 45 FPS average over the final browser samples. Repeated final-window
averages were 47.6-57.2 FPS; the final accepted run held a 49 FPS minimum and
57.2 FPS average. Remote/TURN impairment and a production cutover remain future work in
[`WEB_PLATFORM_PLAN.md`](WEB_PLATFORM_PLAN.md).

Controls:

- A normal client starts in the coverage editor. Drag a zone's centre handle to change range and either edge handle to change width. Press `F` to flip its tip and `R` to restore all four presets, then press `Enter` to drive. Press `E` to return to editing. Editor handles remain recoverable outside the Jeep when a cone is collapsed.
- Four triangular cones are preset at the Jeep's front, right, rear, and left. Their combined area cannot exceed the four default 90° cones at range 8. Narrowing or disabling one cone frees area for longer or wider coverage elsewhere.
- Press `F` to flip the selected cone. A vehicle-pointing cone starts precise and widens with distance; an outward-pointing cone starts wide beside the Jeep and narrows toward its far tip.
- Move the mouse around the vehicle to steer toward it. Press `V` to cycle
  your local presentation through the Jeep, Pickup, Sedan, Wagon, and Bus.
- Cursor distance continuously controls speed and acceleration: inside 1 world unit is stopped; at 20 units it requests 18 units/s and the strongest normal acceleration. The wider control radius and softened small-angle steering provide room for precise throttle and racing-line adjustments.
- Braking and drifting need no extra button. At road speed, pull the cursor inward to fully lock the wheels and preserve an exaggerated forward skid; the chassis snaps into a pronounced 18-degree dive. Add a sharp direction change to rotate that same skid into an assisted powerslide. Keep the cursor far away for a broad planted turn, or point along the exit to recover grip.
- Hold `Space` to burst at 28 units/s with stronger acceleration and a wider, committed turn.
- Press `Q` to toggle the vehicle shield. It absorbs 85% of an incoming drone bolt's shove while a localized glass ripple shows where the shot landed.
- Press `R` to toggle cloak. Cloak and shield are mutually exclusive: cloaking lowers the shield, and the shield cannot be raised while cloaked.
- Hold `Shift` to vacuum the arena ball toward the Jeep. The field does not change normal mouse steering.
- Hold `Tab` to reverse at low speed.
- Steering behaves like a ground vehicle: the Jeep cannot pivot while stopped, yaw builds with road speed, and the turning circle widens at high speed. The close cursor band has stronger, faster steering for carving; pulling farther away progressively trades that rotation for acceleration and speed.
- If a collision holds the Jeep nearly stationary while movement is still requested, a short side bump and forced steer peel it away. Cursor steering chooses the escape side; a stable per-player side handles a perfectly straight impact. There is no automatic reverse mode.
- In drive mode, each zone independently acquires the nearest visible stationary target dummy inside its wedge and fires four bolts per second. Walls and obstacles block acquisition and bolts. Hits flash the dummy and increment its permanent session hit count.
- Drive mode keeps a deliberately faint coverage debug around the local Jeep. A firing zone flashes briefly; press `C` to hide or show the debug.
- One stationary drone by itself in the empty west clearing arms after a short delay and fires once every two seconds at the nearest visible driving player. Its bolts lightly jostle and deflect an unshielded Jeep; cloak prevents targeting. The drone is a non-colliding shield-test fixture and cannot be targeted or destroyed.

The 168-unit-wide floor uses a muted world-space shader grid with one-unit subdivisions, subtle four-unit lines, and quiet centre axes. Its obstacles, outer targets, and shield-test clearing are spread across longer driving lines. Because the grid is fixed in world space while the camera follows the Jeep, speed and direction remain readable without competing with the vehicles.

Four small fixed weapon mounts show the side zones. At runtime every combined CC0 vehicle-pack mesh is split into a chassis and four wheel assemblies: only the chassis leans under turning load, the front tires visibly steer, and all tires spin with signed road speed. This rig and the `V` selection are presentation-only; collision always uses the same server-authoritative, equal-mass sphere on every peer.

## Tests

```bash
./scripts/test.sh
```

The gate checks FOLLOW movement, coverage geometry and budget enforcement, presentation assets and shaders, collision recovery, ball physics, ramps, reverse, boost, cloak, tractor, and shields. It runs real headless servers and clients, including a deterministic 120 ms one-way UDP relay, then verifies automatic combat, drone hits, shield absorption, and cloak/shield exclusion. The mixed-transport gate places ENet and WebRTC peers in one world and covers leave draining, peer-ID collisions, and either transport leg closing. The join-transient gate deliberately blocks a synchronized client for 1.5 seconds—longer than the 64-tick history—and requires bounded recovery without impossible rollback or stale-packet log flooding.

## Structure

- `Main.gd` — role/transport router, ENet/WebRTC lifecycle, spawn authority, arena, camera, and HUD.
- `net/mux_multiplayer_peer.gd` — server-side ENet/WebRTC peer merger.
- `net/webrtc_transport.gd` — WebSocket signaling and WebRTC peer lifecycle.
- `player/follow_controller.gd` — pure deterministic mouse steering math.
- `player/player_input.gd` — networked drive and editor intent.
- `player/player_body.gd` — predicted/rollback Rapier body.
- `player/impact_controller.gd` — pure drone-hit impulse, absorption, and segment-sweep math.
- `player/ground_vehicle_hull.gd` — CC0 Jeep, suspension lean, wheels, weapon mounts, and boost echoes.
- `combat/` — coverage geometry, target selection, stationary shield drone, targets, and bolt presentation.
- `fx/` — boost, cloak, ordinary impact, and glass shield presentation.
- `player/jeep_mesh_splitter.gd` — derives the chassis and four independently animated wheels without modifying the FBX.
- `world/grid_ground.gdshader` — anti-aliased world-space movement grid.
- `net/latency_proxy.gd` — test-only UDP delay/loss relay.
- `tests/` and `scripts/` — mechanic, asset, network, play, and deployment helpers.

The Jeep source and license are in `assets/ground_vehicle/`. Vendored add-on versions are recorded in their plugin manifests.

## macai2

The isolated Car Fight server is deployed on macai2. Redeploy it explicitly with:

```bash
./scripts/deploy_macai2.sh
```

It uses `ssh macai2-ts`, installs the isolated launchd label `com.whenjohn.car-fight-server`, keeps native ENet on UDP `10080`, and listens for WebRTC signaling on TCP `10181`. It does not touch g2 or Starter. This is game-service support only; a public browser client still needs HTTPS/WSS hosting and TURN acceptance.

# Monitored local play

Because this Intel Mac has experienced WindowServer watchdog failures during rendered play, use the monitored launcher for future local tests:

```sh
./scripts/play_monitored.sh
```

It writes flushed game/render telemetry—including window mode, focus, screen, and fullscreen transitions—plus process and thermal samples, filtered macOS display/GPU logs, and short Godot stack samples if telemetry stalls to `.crash-runs/<timestamp>/`. It does not upload anything. Every agent-initiated rendered run still requires explicit approval.

After a WindowServer/login-session recovery, attach the generated `.ips`, `.spin`, and historical unified log to the last run with:

```sh
./scripts/collect_crash_run.sh
```

Validate the monitor without opening a rendered window with `./scripts/play_monitored.sh --headless --ticks 180`. Normal monitored play explicitly starts windowed. On the affected Intel Mac, keep the decorated window inside the usable desktop area; native fullscreen, borderless fullscreen, exact edge-to-edge windows, and edge-to-edge maximization are unsupported. OpenGL, ANGLE, and Vulkan fullscreen alternatives have already been ruled out. See [`MAC_INTEL_FULLSCREEN_FINDINGS.md`](MAC_INTEL_FULLSCREEN_FINDINGS.md) before proposing any new display experiment.

For multiplayer feel testing without hosting the server on this Mac, deploy the isolated macai2 service and run `./scripts/play_macai2_two.sh`. It opens two named 1280 x 720 native clients side by side, both through the same telemetry and Intel-display monitor used above. An unfocused client deliberately sends neutral controls, so its Jeep brakes instead of following the focused window's macOS cursor. The server remains on macai2 UDP `10080`; G2 remains separate on UDP `9950`.

The first two-rendered-client trial exposed the stale-history loop later fixed by D-040. Subsequent pairs remain in one shared world and play smoothly. In the latest accepted run, accidentally enlarging one client from 1280 x 720 to 2800 x 1518 briefly reduced it to 6-8 FPS while physics stayed inexpensive; reducing the window restored performance. Keep both clients at the launcher's safe inset size. See [`WEB_PLATFORM_PLAN.md`](WEB_PLATFORM_PLAN.md) for the evidence and next platform sequence.

To test the failure detector safely, run `./scripts/crash_monitor_test.sh`. It freezes only a headless Godot client's main thread for seven seconds, verifies that telemetry stops and resumes, and requires the external watcher to capture a real process stack during the stall. It does not stress the GPU, open a window, kill WindowServer, or simulate a successful result.
