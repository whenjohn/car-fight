# Survival Vehicle asset

`SurvivalVehicle.fbx` and its texture folder came from the owner-supplied
`survival+vehicle+3d+model.zip`. The ZIP contains no author, source URL, readme,
or license, so no license claim is made here.

The single PBR material retains its albedo, normal, metallic, and roughness
maps. Runtime copies are reduced from 2048–4096px to 1024px for the game's
camera distance. The original `.fbm` directory name is preserved because the
FBX references it directly.

The source combines the chassis and six wheels in one mesh and is rotated
diagonally in its own coordinate space. Six bounded extraction regions isolate
the actual tire assemblies; the source is normalized to the game's forward
axis, the front pair steers, and the middle/rear pairs use the normal wheel-spin,
suspension, skid-contact, cloak, and boost-echo presentation paths. The
authoritative gameplay collider remains unchanged.
