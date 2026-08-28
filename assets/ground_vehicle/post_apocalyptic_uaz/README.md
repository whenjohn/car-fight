# Post-Apocalyptic UAZ asset

`Post_Apocalyptic_UAZ.fbx` and its textures came from the owner-supplied
`Post_Apocalyptic_UAZ.fbx` and `Post_Apocalyptic_UAZ_textures.7z`. Neither
download contains an author, source URL, readme, or license, so no license claim
is made here.

The runtime asset retains four PBR material sets for body, wheels, frame, and
accessories. Albedo, normal, metallic, and roughness maps plus the available
accessory ambient-occlusion map are reduced to 1024px for the game's camera
distance. Height maps are omitted because the compatibility-renderer vehicle
presentation does not use displacement.

The FBX contains four named, separate wheel nodes. They feed the standard
steering, spin, suspension, skid-contact, cloak, and boost-echo presentation
paths without changing the authoritative gameplay collider.
