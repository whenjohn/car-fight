# Vehicle animation lab

Run the standalone, network-free close-up tool from this worktree:

```sh
./scripts/play_vehicle_animation_lab.sh
```

The eight preset buttons (or number keys `1` through `8`) cover neutral, hard
left/right cornering, hard braking, launch, boost, and left/right drifting.
Every preset can be refined with live controls for road speed, steering, brake
and wheel lock, longitudinal gas/brake load, and signed drift amount.

- Drag empty 3D space with the left mouse button to orbit.
- Use the mouse wheel to zoom.
- Press `Space` to freeze/unfreeze the current pose.
- Press `V` or the vehicle button to cycle Jeep, Pickup, Sedan, Wagon, and Bus.

The lab instantiates `player/ground_vehicle_hull.gd`, so it exercises the same
presentation used in gameplay. Its preview dictionary bypasses gameplay and
network state only while the lab is running. Live gameplay derives the same
motion locally from rigid-body velocity, yaw, braking, boost, lateral slip, and
drift-assist state; rollback collision and FOLLOW handling remain unchanged.

Current presentation responses:

- independent front-wheel Ackermann steering and bounded drift countersteer;
- speed-based wheel spin and the existing hard-brake wheel lock;
- per-wheel front/rear and side-to-side suspension travel;
- speed/yaw body roll with extra, bounded drift load;
- the existing progressive hard-brake dive;
- acceleration/boost rear squat and small chassis compression;
- the existing boost afterimages.

## Physics and suspension decision

Keep the proven authoritative rigid body as the gameplay vehicle. Do not replace
it with a physical chassis plus four wheel colliders for current scope. Car
Fight's ordinary camera is far enough away that the additional contact detail
is unlikely to justify the tuning, stability, rollback, and network cost of a
true wheel rig.

The preset buttons are lab fixtures, not gameplay event triggers. They provide
repeatable inputs for tuning. In gameplay, the shared hull derives its pose from
real rigid-body motion and synchronized driving state.

Continue with a hybrid presentation model:

- real physics owns movement, collisions, ramps, airborne trajectory, and the
  landing itself;
- the separated chassis and four wheel anchors provide tunable visual response;
- add airborne wheel droop, landing compression/rebound, and a subtle whole-car
  bump response before considering more detailed suspension;
- add four independent terrain probes only if bumps are visibly unconvincing at
  the normal gameplay camera distance;
- keep terrain probes presentation-only and non-colliding if they are added;
- reconsider a true four-wheel physics rig only after a normal-view comparison
  demonstrates a clear gameplay benefit that the hybrid cannot provide.

This preserves predictable handling and multiplayer behavior while retaining
the ability to exaggerate readable arcade motion in one auditable script.

Focused validation:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/vehicle_animation_test.gd
```
