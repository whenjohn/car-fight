# Car Fight

A deliberately small Godot 4.7 multiplayer prototype: configure automatic firing coverage, drive CC0 Jeeps with Starter's FOLLOW mouse control, physically bump other equal-mass vehicles, and test a glass vehicle shield against a slow stationary firing drone.

Networking is native ENet with g2's proven netfox 1.35.3 + Rapier 0.8.39 core: server-owned physics and automatic target combat, client-owned input, local prediction, rollback reconciliation, and interpolation for remote bodies. Vehicle damage, health, bots, resources, alternate maps, and progression remain out of scope.

## Play

```bash
./scripts/play.sh                 # local server + one visible client
./scripts/join.sh 127.0.0.1      # another local client
./scripts/serve.sh               # server only, UDP 10080
./scripts/join_macai2.sh         # Tailscale address, if separately deployed
```

Controls:

- A normal client starts in the coverage editor. Drag a zone's centre handle to change range and either edge handle to change width. Press `F` to flip its tip and `R` to restore all four presets, then press `Enter` to drive. Press `E` to return to editing. Editor handles remain recoverable outside the Jeep when a cone is collapsed.
- Four triangular cones are preset at the Jeep's front, right, rear, and left. Their combined area cannot exceed the four default 90° cones at range 8. Narrowing or disabling one cone frees area for longer or wider coverage elsewhere.
- Press `F` to flip the selected cone. A vehicle-pointing cone starts precise and widens with distance; an outward-pointing cone starts wide beside the Jeep and narrows toward its far tip.
- Move the mouse around the Jeep to steer toward it.
- Cursor distance continuously controls speed: inside 1 world unit is stopped; at 16 units it reaches 14 units/s.
- Hold `Space` to burst at 23.33 units/s with stronger acceleration and a wider, committed turn.
- Press `Q` to toggle the vehicle shield. It absorbs 85% of an incoming drone bolt's shove while a localized glass ripple shows where the shot landed.
- Press `R` to toggle cloak. Cloak and shield are mutually exclusive: cloaking lowers the shield, and the shield cannot be raised while cloaked.
- Hold `Shift` to vacuum the arena ball toward the Jeep. The field does not change normal mouse steering.
- Hold `Tab` to reverse at low speed.
- Steering behaves like a ground vehicle: the Jeep cannot pivot while stopped, yaw builds with road speed, and the turning circle widens at high speed. Pulling the cursor closer lowers the requested speed and sharpens the turn, preserving Starter FOLLOW's useful slow/tight versus fast/wide relationship.
- If a collision holds the Jeep nearly stationary while movement is still requested, a short side bump and forced steer peel it away. Cursor steering chooses the escape side; a stable per-player side handles a perfectly straight impact. There is no automatic reverse mode.
- In drive mode, each zone independently acquires the nearest visible stationary target dummy inside its wedge and fires four bolts per second. Walls and obstacles block acquisition and bolts. Hits flash the dummy and increment its permanent session hit count.
- Drive mode keeps a deliberately faint coverage debug around the local Jeep. A firing zone flashes briefly; press `C` to hide or show the debug.
- One stationary drone in the open clearing northeast of the starting area arms after a short delay and fires once every two seconds at the nearest visible driving player. Its bolts lightly jostle and deflect an unshielded Jeep; cloak prevents targeting. The drone is a non-colliding shield-test fixture and cannot be targeted or destroyed.

The floor uses a muted world-space shader grid with one-unit subdivisions, subtle four-unit lines, and quiet centre axes. Because the grid is fixed in world space while the camera follows the Jeep, speed and direction remain readable without competing with the vehicles.

Four small fixed weapon mounts show the side zones. At runtime the combined CC0 mesh is split into a chassis and four wheel assemblies: only the chassis leans under turning load, the front tires visibly steer, and all tires spin with signed road speed. This rig is presentation-only; collision always uses the same server-authoritative, equal-mass sphere on every peer.

## Tests

```bash
./scripts/test.sh
```

The gate checks FOLLOW movement, coverage geometry and budget enforcement, presentation assets and shaders, collision recovery, ball physics, ramps, reverse, boost, cloak, tractor, and shields. It runs real headless servers and clients, including a deterministic 120 ms one-way UDP relay, then verifies automatic combat, drone hits, shield absorption, and cloak/shield exclusion.

## Structure

- `Main.gd` — role router, ENet lifecycle, spawn authority, arena, camera, and HUD.
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

The deployment helper is intentionally manual and has not been run:

```bash
./scripts/deploy_macai2.sh
```

It uses `ssh macai2-ts`, installs the isolated launchd label `com.whenjohn.car-fight-server`, listens on UDP `10080`, and does not touch g2 or Starter.
