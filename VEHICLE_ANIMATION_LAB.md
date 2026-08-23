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

Focused validation:

```sh
/Applications/Godot47.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/vehicle_animation_test.gd
```

