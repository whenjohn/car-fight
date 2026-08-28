# Combat Vehicle asset

`CombatVehicle.glb` is a clean runtime conversion of the version 1.02 FBX by
Yoon's GameART. The included license permits use in any type of project; its
original text is preserved in `LICENSE.txt`.

The game uses the FBX's intended dark X-cam body diffuse plus the supplied body
normal, metallic, and occlusion maps. Tires use their matching diffuse and
normal maps. The diffuse remains at `Materials/tire.png` because the converted
scene references that relative path. Unity scenes, `.mat`/`.meta` files, the
duplicate OBJ, and unused body-color variants are intentionally excluded from
the runtime asset set.
