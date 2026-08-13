# Car Fight fullscreen rendering isolation

Each stage adds one rendering responsibility. Run a short monitored windowed
validation first, then request explicit approval before its fullscreen probe.
Stop when the known `Invalid actual_host_time` precursor appears.

0. Empty Godot Compatibility window with default display sizing.
1. Add car-fight's 1280 x 720 viewport/window overrides and `canvas_items` stretch.
2. Add a 3D camera and world clear color.
3. Add one unshaded primitive mesh.
4. Add a material and directional light.
5. Add a floor and dynamic shadows.
6. Animate the primitive transform.
7. Replace the primitive with the imported Jeep presentation mesh.
8. Load Rapier and select it as the 3D physics engine, without physics bodies.
9. Add one simulated rigid body and collider.
10. Load netfox autoload/tick infrastructure without creating ENet peers.
11. Add the minimal ENet server/client shell and local traffic.

Do not combine stages. A stage that reproduces the precursor identifies the
smallest newly introduced subsystem to investigate.
