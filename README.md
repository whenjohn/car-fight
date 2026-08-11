# Car Fight

A deliberately small Godot 4.7 multiplayer prototype: drive CC0 Jeeps with Starter's FOLLOW mouse control and physically bump other equal-mass vehicles in a flat isometric arena.

This first slice has no weapons, health, damage, bots, resources, alternate maps, or gameplay progression. Networking is native ENet with g2's proven netfox 1.35.3 + Rapier 0.8.39 core: server-owned physics, client-owned input, local prediction, rollback reconciliation, and interpolation for remote bodies.

## Play

```bash
./scripts/play.sh                 # local server + one visible client
./scripts/join.sh 127.0.0.1      # another local client
./scripts/serve.sh               # server only, UDP 10080
./scripts/join_macai2.sh         # Tailscale address, if separately deployed
```

Controls:

- Move the mouse around the Jeep to steer toward it.
- Cursor distance continuously controls speed: inside 1 world unit is stopped; at 16 units it reaches 14 units/s.
- Hold `Space` to burst at 23.33 units/s with stronger acceleration and a 6 rad/s steering cap.
- The normal steering cap blends from 30 rad/s nearby to 2.4 rad/s far away, matching the Starter FOLLOW controller.

The small turret points at the cursor and the Jeep body leans under turning load, but both are presentation-only. Collision always uses the same server-authoritative, equal-mass sphere on every peer.

## Tests

```bash
./scripts/test.sh
```

The gate checks the exact FOLLOW tuning, imports the Jeep, compiles every script, then runs a real headless server and two clients through a deterministic 120 ms one-way UDP relay. It requires both clients to connect and the authoritative server to observe vehicle contact.

## Structure

- `Main.gd` — role router, ENet lifecycle, spawn authority, arena, camera, and HUD.
- `player/follow_controller.gd` — pure deterministic mouse steering math.
- `player/player_input.gd` — the two network inputs: cursor offset and burst.
- `player/player_body.gd` — predicted/rollback Rapier body.
- `player/ground_vehicle_hull.gd` — CC0 Jeep, suspension lean, and cursor turret.
- `net/latency_proxy.gd` — test-only UDP delay/loss relay.
- `tests/` and `scripts/` — mechanic, asset, network, play, and deployment helpers.

The Jeep source and license are in `assets/ground_vehicle/`. Vendored add-on versions are recorded in their plugin manifests.

## macai2

The deployment helper is intentionally manual and has not been run:

```bash
./scripts/deploy_macai2.sh
```

It uses `ssh macai2-ts`, installs the isolated launchd label `com.whenjohn.car-fight-server`, listens on UDP `10080`, and does not touch g2 or Starter.

