# Car Fight

The project briefly shipped a Godot 4.6.3 Forward+ baseline before returning
to Godot 4.7.1 Compatibility for Intel stability. Read
[`GODOT_46_TO_47_HISTORY.md`](GODOT_46_TO_47_HISTORY.md) before changing the
engine, Rapier version, renderer, shadows, SSAO, caches, or world architecture.
For agent-assisted auditing, dead-code removal, and behavior-preserving
refactoring, follow
[`CODE_HEALTH_CLEANUP_PLAYBOOK.md`](CODE_HEALTH_CLEANUP_PLAYBOOK.md).
Before gameplay, input, lifecycle, or replicated-state changes, read
[`Network-safe gameplay`](docs/NETWORK_SAFE_GAMEPLAY.md) for the development
rules and their reasoning, and use
[`Quality gates`](docs/QUALITY_GATES.md) for the required focused checks.
For RPC-size measurements and the meaning of `NETAPP` maximum-payload fields,
see the [packet-size baseline](docs/NETWORK_PACKET_BUDGETS_2026-09-04.md).

> **Project status:** This Godot implementation is again the active Car Fight
> project. The Unity handoff was superseded after its browser transport proved
> non-reproducible from tracked source and its Editor/build iteration conflicted
> with the required workflow. See
> [`MAC_INTEL_FULLSCREEN_FINDINGS.md`](MAC_INTEL_FULLSCREEN_FINDINGS.md) for the
> canonical affected-Intel-Mac evidence and windowed policy, and
> [`MIGRATION_TO_UNITY.md`](MIGRATION_TO_UNITY.md) for the engine-decision
> history. The completed browser rollout sequence is preserved in the
> historical [`WEB_PLATFORM_PLAN.md`](WEB_PLATFORM_PLAN.md). Do not merge the diagnostic
> branches into this gameplay branch or rerun known-risk
> fullscreen/edge-to-edge probes merely to reconfirm them.

> **Historical engine migration:** The Godot 4.6.3 + Rapier 0.8.35 Forward+
> plan was completed, investigated, and ultimately superseded by the current
> Godot 4.7.1 Compatibility baseline. It is evidence, not current authorization.
> See [`GODOT_46_TO_47_HISTORY.md`](GODOT_46_TO_47_HISTORY.md).

A deliberately small Godot 4.7 multiplayer prototype: configure automatic firing coverage, drive CC0 Jeeps with high-fidelity FOLLOW mouse control, carry momentum through automatic powerslides, physically bump other equal-mass vehicles, and test a glass vehicle shield against a slow stationary firing drone.

Native networking remains ENet with G2's proven netfox 1.35.3 + Rapier 0.8.39 core: server-owned physics and automatic target combat, client-owned input, local prediction, rollback reconciliation, and interpolation for remote bodies. Browser WebRTC joins the same authoritative world through the server-side mux without moving native clients off ENet. The vendored netfox includes G2's D-040 stale-history recovery patch: after a client stall advances beyond retained rollback history, impossible origins are skipped with a bounded warning while the client waits for fresh authority. Vehicle damage, health, bots, resources, alternate maps, and progression remain out of scope.

## Play

```bash
./scripts/play.sh                 # monitored client, macai2 by default
./scripts/join.sh                 # another macai2 client
./scripts/play_local.sh           # explicit local server + monitored client
./scripts/join.sh 127.0.0.1       # join an already-running local server
./scripts/serve.sh                # explicit local mux server
./scripts/join_macai2.sh          # explicit macai2 alias
./scripts/play_macai2_two.sh      # two monitored native clients, remote server
```

Normal native client launches prefer macai2 over Tailscale (`100.113.2.60`) to
keep server simulation off this Mac. Set `CAR_FIGHT_HOST` to select another
remote host, or use `play_local.sh`/an explicit `127.0.0.1` host for isolated
development. Browser-local test helpers always use their own isolated local
ports and do not contact macai2.

## Offline Web build

The browser checkpoint is intentionally offline: it spawns one local Jeep and
the city without opening ENet, changing the native server, or adding a browser
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

Connection-deadline experiments are opt-in: pass
`--webrtc-connect-timeout-ms=30000` to a native WebRTC client or add
`webrtcConnectTimeoutMs=30000` to a Web Network URL. The value is the total
connection-attempt budget in milliseconds, not a gameplay idle timeout; zero
(the unchanged default) disables it. Failed attempts stop once, and an
established gameplay connection survives signaling loss. This does not add
automatic reconnect. Browser/TURN validation of the new deadline is still pending.

Server-side pending joins can be bounded experimentally with
`--webrtc-pending-timeout-ms=30000 --webrtc-max-pending=16` on either a mux or
pure WebRTC server. Both settings default to zero (disabled); these example
values are not promoted defaults. The budget starts at TCP acceptance and ends
when DataChannels connect. Connected players do not consume pending slots.
With the cap enabled, excess TCP connections are closed before RTC allocation,
and at most 16 accepts are handled per process pass. This is not a total-player
limit, automatic retry policy, or complete denial-of-service defense.

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
57.2 FPS average. Remote forced-TURN reconnect and two-player acceptance are
recorded in [`NETWORK_SHAPING_FINDINGS.md`](NETWORK_SHAPING_FINDINGS.md).

Controls:

- A normal client starts in the coverage editor. Drag a zone's centre handle to change range and either edge handle to change width. Press `F` to flip its tip and `R` to restore all four presets, then press `Enter` to drive. Press `E` to return to editing. Editor handles remain recoverable outside the Jeep when a cone is collapsed.
- Four triangular cones are preset at the Jeep's front, right, rear, and left. Their combined area cannot exceed the four default 90° cones at range 8. Narrowing or disabling one cone frees area for longer or wider coverage elsewhere.
- Press `F` to flip the selected cone. A vehicle-pointing cone starts precise and widens with distance; an outward-pointing cone starts wide beside the Jeep and narrows toward its far tip.
- Move the mouse around the vehicle to steer toward it. Press `V` to cycle
  your local presentation through the Jeep, Pickup, Sedan, Wagon, Bus, Humvee M242,
  Combat Vehicle, Apocalypse Bus, Post-Apocalyptic UAZ, Survival Vehicle, and
  the 30 cars, trucks, and tractors from LowPoly Cars 01.
- A PlayStation controller uses the left stick for camera-relative direction and
  analog speed. `Cross` bursts, `Circle` reverses, `L1` shields, `R1` cloaks,
  and `L2` vacuums. `Square` fires a homing missile, `Triangle` launches the RC
  orb, and `R2` is primary fire / RC detonate. D-pad up arms the area weapon,
  down activates det, right deploys troops, and left cycles the vehicle. Moving
  the mouse switches driving back to mouse control; moving the left stick takes
  control again.
- The native `Vehicle Model` system menu scales your selected local vehicle from
  100% to 500% and autosaves a separate choice for every vehicle. This is a
  presentation debug control; the authoritative gameplay collider remains unchanged.
- The native `Scenery` menu compares five Intel-safe, no-SSAO lighting setups.
  These controls change presentation only; collision, physics, and networking
  remain unchanged.
- When the owner-supplied local tree pack is installed, the city uses its fixed
  Collection 121–130 street-tree lining. Clean checkouts remain functional
  without the optional marketplace source.
- Cursor distance continuously controls speed and acceleration: inside 1 world unit is stopped; at 20 units it requests 18 units/s and the strongest normal acceleration. The wider control radius and softened small-angle steering provide room for precise throttle and racing-line adjustments.
- Braking and drifting need no extra button. At road speed, pull the cursor inward to fully lock the wheels and preserve an exaggerated forward skid; the chassis snaps into a pronounced 18-degree dive. Add a sharp direction change to rotate that same skid into an assisted powerslide. Keep the cursor far away for a broad planted turn, or point along the exit to recover grip.
- Hold `Space` to burst at 28 units/s with stronger acceleration and a wider, committed turn.
- Press `Q` to toggle the vehicle shield. It absorbs 85% of an incoming drone bolt's shove while a localized glass ripple shows where the shot landed.
- Press `R` to toggle cloak. Cloak and shield are mutually exclusive: cloaking lowers the shield, and the shield cannot be raised while cloaked.
- Hold `Shift` to vacuum the city ball toward the Jeep. The field does not change normal mouse steering.
- Hold `Tab` to reverse at low speed.
- Steering behaves like a ground vehicle: the Jeep cannot pivot while stopped, yaw builds with road speed, and the turning circle widens at high speed. The close cursor band has stronger, faster steering for carving; pulling farther away progressively trades that rotation for acceleration and speed.
- If a collision holds the Jeep nearly stationary while movement is still requested, a short side bump and forced steer peel it away. Cursor steering chooses the escape side; a stable per-player side handles a perfectly straight impact. There is no automatic reverse mode.
- In drive mode, each zone independently acquires the nearest visible stationary target dummy inside its wedge and fires four bolts per second. Walls and obstacles block acquisition and bolts. Hits flash the dummy and increment its permanent session hit count.
- Drive mode keeps a deliberately faint coverage debug around the local Jeep. A firing zone flashes briefly; press `C` to hide or show the debug.
- One stationary drone by itself in the empty west clearing arms after a short delay and fires once every two seconds at the nearest visible driving player. Its bolts lightly jostle and deflect an unshielded Jeep; cloak prevents targeting. The drone is a non-colliding shield-test fixture and cannot be targeted or destroyed.

The 330-unit-wide city floor uses a muted world-space shader grid with one-unit subdivisions, subtle four-unit lines, and quiet centre axes. Its building collision proxies, outer targets, and shield-test clearing are spread across longer driving lines. Because the grid is fixed in world space while the camera follows the Jeep, speed and direction remain readable without competing with the vehicles.

Four small fixed weapon mounts show the side zones. At runtime the vehicle
presentation normalizes several imported model layouts. Models with separable
wheel geometry animate chassis lean, front-wheel steering, and signed wheel
spin; atlas-baked models retain intact geometry with contact anchors for their
skid trails. This rig and the `V` selection are presentation-only; ordinary
play uses the same server-authoritative, equal-mass capsule on every peer.

## Tests

```bash
./scripts/test.sh
```

The complete suite checks FOLLOW movement, coverage geometry and budget enforcement, presentation assets and shaders, collision recovery, city-ball physics, reverse, boost, cloak, tractor, and shields. It runs real headless servers and clients, including a deterministic 120 ms one-way UDP relay, then verifies automatic combat, drone hits, shield absorption, and cloak/shield exclusion. The mixed-transport gate places ENet and WebRTC peers in one world and covers leave draining, peer-ID collisions, and either transport leg closing. The join-transient gate deliberately blocks a synchronized client for 1.5 seconds—longer than the 64-tick history—and requires bounded recovery without impossible rollback or stale-packet log flooding.

## Network shaping

The current impairment results, desynchronization recovery design, and measured
rollback/FPS bottleneck are recorded in
[`NETWORK_SHAPING_FINDINGS.md`](NETWORK_SHAPING_FINDINGS.md).

Native ENet and browser WebRTC use the same named one-way profiles: `clean`,
`latency60`, `latency120`, `jitter` (60 +/- 30 ms), `loss05`, `loss1`, and
`combined` (120 +/- 40 ms plus 1% loss).

```bash
./scripts/network_test.sh combined       # one focused native ENet row
./scripts/network_matrix_test.sh         # complete native ENet matrix
./scripts/play_shaped.sh combined        # one monitored client through macai2
./scripts/play_shaped_two.sh combined    # two monitored clients through macai2
./scripts/play_shaped_local.sh latency120      # one client + moving server car
./scripts/play_networking1_enet.sh latency120 adaptive

# Opt-in G2-derived transport A/B; normal game defaults remain unchanged.
CAR_FIGHT_G2_STACK=1 ./scripts/network_test.sh latency120
CAR_FIGHT_G2_STACK=1 CAR_FIGHT_STATE_RATE_DIVISOR=1 \
	./scripts/network_test.sh combined
CAR_FIGHT_G2_STACK=1 CAR_FIGHT_ADAPTIVE_STATE_RATE=1 \
	CAR_FIGHT_NETWORK_SERVER_TICKS=1500 CAR_FIGHT_NETWORK_CLIENT_TICKS=1500 \
	./scripts/network_test.sh latency120
```

`CAR_FIGHT_G2_STACK=1` enables the measured G2-derived lab profile on every
process: per-route `StateBundle` backpressure, packed input/state snapshots,
input broadcast disabled, ordinary state cadence division, 30 Hz complete-set
remote-position batches, same-map relevance, self exclusion, and render-only
remote interpolation. The default cadence divisor is 3 (20 Hz); use divisor 1
for the current robust combined-impairment baseline. Adaptive cadence may step
from 3 to 2 to 1 when the receiver reports pressure. All of these switches are
off in ordinary play until the A/B evidence justifies a product-default change.
`CAR_FIGHT_RESIM_BUDGET_MS=10` remains an explicit rejected experiment, not a
recommended mitigation: it preserved FPS but caused large divergence.

`play_networking1_enet.sh` is the current single-observer feel harness. It
copies this worktree to the dedicated
`/Users/macai2/Projects/car-fight-networking-1` path, starts a temporary server
on UDP 12680, and shapes its traffic through a local relay on UDP 12681. It does
not restart or modify the production Car Fight service. The first argument is a
named impairment profile and the second is `fixed` or `adaptive`. The adaptive
controller starts at 75 ms, raises through bounded 100/125/150 ms tiers only
after confirmed transport plus presentation pressure, and releases slowly
after a healthy interval. Ordinary play remains fixed at 75 ms.

The harness enables a compact four-line top-right diagnostic display: FPS and
frame time; transport/profile plus RTT/jitter; selected presentation delay,
buffer headroom, and interpolation/extrapolation/hold percentages; and rollback
cost/depth, worst correction, and recovery requests. The same snapshot is
written once per second as `NETWORKHUD` JSON. Set
`CAR_FIGHT_PRESENTATION_TRACE_SECONDS` to capture a deterministic JSONL input
trace, then replay it with:

```bash
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/adaptive_presentation_replay.gd -- \
  --trace path/to/presentation-trace.jsonl
```

`play_shaped_local.sh` is the visual smoothness harness. It owns an isolated
local server and relay, enables the G2 profile, and spawns peer 1 as a
server-authoritative Jeep following long straight runs around the city's open
perimeter, joined by short chamfered corners. The observer spawns beside it,
and the route stays clear of city fixtures. The harness uses the flat expanded
city for the moving test target and disables the physical
city ball, shield-test drone presentation, and the orange marker mounted above
each peer, leaving only the two Jeeps. A
server guard restores the moving Jeep if it ever leaves the city. The single rendered client can chase it; closing
that client window stops only the processes launched by the harness. For local browser/native
comparison, run `CAR_FIGHT_G2_STACK=1 ./scripts/play_web_network_local.sh`; its
server-driven car is enabled by default as well.

The native relay reports received, forwarded, dropped, reordered, queued, and
high-water packet counts in both directions. A gate fails if the configured
profile is not echoed, traffic does not cross the relay, requested loss drops
no packets, or requested jitter produces no packet reordering. Pass a host as
the second play argument to target a different isolated server, including
`127.0.0.1`.

Browser shaping uses a forced WebRTC TURN allocation rather than Chrome HTTP
throttling or the ENet relay:

```bash
./scripts/webrtc_turn_shape_test.sh combined  # one browser + native mux row
./scripts/webrtc_turn_matrix_test.sh           # complete browser matrix
CAR_FIGHT_G2_STACK=1 ./scripts/web_network_smoke.sh
CAR_FIGHT_G2_STACK=1 CAR_FIGHT_REMOTE_INTERP_MODE=adaptive \
	./scripts/webrtc_turn_shape_test.sh latency120
```

The browser smoke and forced-TURN harness accept the same
`CAR_FIGHT_REMOTE_INTERP_MODE`, `CAR_FIGHT_REMOTE_INTERP_MS`, and
`CAR_FIGHT_REMOTE_INTERP_MAX_MS` controls as ENet. Adaptive presentation
remains opt-in.

The harness serves the current Web build locally, syncs only to the isolated
`/Users/macai2/Projects/car-fight-network-shaping` checkout, starts the mux on
ENet 12480/signaling 12481, and creates uniquely named temporary TURN/netem
resources on macmini. It proves the browser requested relay-only ICE, requires
real packets and requested drops in the TURN qdisc, records browser and server
WebRTC queue high-water marks, and preserves reports under `.network-runs/`.
Cleanup targets only those harness resources and a remote failsafe removes TURN
if the local runner disappears. The production Car Fight UDP 10080/TCP 10181
service is not modified.

The local exported browser/native G2-stack smoke requires proof of a non-empty
remote-position batch. Its accepted run survived browser replacement, held
59.2 steady FPS, peaked at 678 queued bytes, drained the queue, and emitted zero
browser errors. The accepted 600-second forced-TURN reconnect soak recorded
zero recoveries, a 0.000887-unit worst correction, a 3,558-byte peak browser
queue, and 194,333 shaped packets. A later native/Chrome two-player session was
accepted as smooth in both driving directions with zero stale recoveries.
Combined impairment and adaptive cadence remain separate experiments; earlier
failed rows and the complete measurements remain in
[`NETWORK_SHAPING_FINDINGS.md`](NETWORK_SHAPING_FINDINGS.md).

## Structure

- `Main.gd` — role/transport router, ENet/WebRTC lifecycle, spawn authority, city, camera, and HUD.
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

The isolated Car Fight server is deployed on macai2. Preview the exact sync and
deletion manifest first:

```bash
./scripts/deploy_macai2.sh preview
./scripts/deploy_macai2.sh apply   # only after reviewing the preview
```

Preview is the safe default when no argument is supplied. Apply reconciles files
removed from the canonical source while preserving remote `.godot/`, generated
run/build evidence, and ignored `assets/local/`. It then installs the isolated
launchd label `com.whenjohn.car-fight-server`, keeps native ENet on UDP `10080`,
and listens for WebRTC signaling on TCP `10181`. It does not touch g2 or Starter.
This is game-service support only; a public browser client still needs HTTPS/WSS
hosting and TURN acceptance.

# Monitored local play

Because this Intel Mac has experienced WindowServer watchdog failures during rendered play, use the monitored launcher for ordinary play:

```sh
./scripts/play_monitored.sh
```

It writes flushed game/render telemetry—including window mode, focus, screen, and fullscreen transitions—plus process and thermal samples, filtered macOS display/GPU logs, and short Godot stack samples if telemetry stalls to `.crash-runs/<timestamp>/`. It does not upload anything. Every agent-initiated rendered run still requires explicit approval.

After a WindowServer/login-session recovery, attach the generated `.ips`, `.spin`, and historical unified log to the last run with:

```sh
./scripts/collect_crash_run.sh
```

It connects to macai2 by default. Add `--local` when the monitor must launch an
isolated local server, including the headless monitor check:
`./scripts/play_monitored.sh --local --headless --ticks 180`. Normal monitored
play explicitly starts windowed. Use `./scripts/play_monitored.sh --offline`
for a standalone visual or handling audition without network correction. On
the affected Intel Mac, keep the decorated
window inside the usable desktop area; native fullscreen, borderless fullscreen,
exact edge-to-edge windows, and edge-to-edge maximization are unsupported.
OpenGL, ANGLE, and Vulkan fullscreen alternatives have already been ruled out.
See [`MAC_INTEL_FULLSCREEN_FINDINGS.md`](MAC_INTEL_FULLSCREEN_FINDINGS.md)
before proposing any new display experiment.

For multiplayer feel testing without hosting the server on this Mac, deploy the isolated macai2 service and run `./scripts/play_macai2_two.sh`. It opens two named 1280 x 720 native clients side by side, both through the same telemetry and Intel-display monitor used above. Both clients enable the `P` cruise toggle: press `P` to start full-speed forward driving without burst, switch to the other client to observe, and press `P` again in the driving client to stop cruise. Cruise starts off and generates normal networked inputs even while unfocused. Otherwise, an unfocused client deliberately sends neutral controls, so its Jeep brakes instead of following the focused window's macOS cursor. For a single monitored client, opt in with `CAR_FIGHT_CLIENT_CRUISE=1 ./scripts/play_monitored.sh`. The server remains on macai2 UDP `10080`; G2 remains separate on UDP `9950`.

The first two-rendered-client trial exposed the stale-history loop later fixed by D-040. Subsequent pairs remain in one shared world and play smoothly. In the latest accepted run, accidentally enlarging one client from 1280 x 720 to 2800 x 1518 briefly reduced it to 6-8 FPS while physics stayed inexpensive; reducing the window restored performance. Keep both clients at the launcher's safe inset size. See [`NETWORK_SHAPING_FINDINGS.md`](NETWORK_SHAPING_FINDINGS.md) for the networking evidence.

To test the failure detector safely, run `./scripts/crash_monitor_test.sh`. It freezes only a headless Godot client's main thread for seven seconds, verifies that telemetry stops and resumes, and requires the external watcher to capture a real process stack during the stall. It does not stress the GPU, open a window, kill WindowServer, or simulate a successful result.

Low Poly City is the sole production world. Its local source art stays under
`assets/local/city_audition/`. To regenerate the lightweight 63-piece district
after changing the source selection, run:

```sh
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/extract_city_audition.gd
```

The game loads only the resulting small extracted district, not the complete
three-million-vertex FBX. The supplied forest EXR is currently omitted because
Godot cannot decode its compression. The entire city composition is presented
at 150% source scale—including its street spacing, collision footprints, and
map boundary—while vehicle scale remains unchanged.

Because `assets/local/` is intentionally ignored, Git does not populate it in
a new worktree. Immediately after `git worktree add`, bootstrap an independent
physical copy of the required city and Collection tree art from another
registered Car Fight worktree:

```sh
./scripts/sync_local_assets.sh
```

Use `./scripts/sync_local_assets.sh --check` when only verifying readiness.
The helper never symlinks the art, never deletes target files, and never copies
the retired prop or Shapespark audition packages.
