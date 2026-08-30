# Apocalypse Bus asset

`ApocalypseBus.glb` is a runtime conversion of the owner-supplied
`Apocalypse+bus_fbx.rar` FBX. The archive contains no author, source URL,
readme, or license metadata, so no license claim is made here.

The four numbered PBR material sets retain their matching albedo, normal,
metallic, and roughness maps. Runtime copies are reduced from 2048x2048 to
1024x1024 for the game's camera distance. The supplied height maps are omitted
because this compatibility-renderer presentation does not use displacement.

The original model stores the four wheels inside material 3 along with static
armor. The presentation importer extracts only their known source-space bounds
so steering, spin, suspension, skid contacts, cloak, and boost echoes continue
to use the standard four-wheel rig.
