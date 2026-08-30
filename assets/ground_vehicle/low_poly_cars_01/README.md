# LowPoly Cars 01

Imported from the owner-supplied files in `Downloads`:

- `LowPoly_Cars_01_fbx.FBX`
- `textures.rar`

The FBX contains 30 complete vehicle models arranged together: 23 cars, four
trucks, and three tractors/construction vehicles. The game selects each intact
top-level model independently from the shared source scene. Eleven loose wheel
display meshes and two empty helper nodes are not exposed as vehicles.

The FBX mixes normal and mirrored node transforms. Runtime extraction corrects
triangle winding per mesh and regenerates low-poly normals after transformation.
Because visible wheels are baked into many intact atlas meshes, four invisible
wheel-contact anchors provide skid trails without cutting or duplicating them.

The archive contains the same color atlas at five resolutions. Only the
referenced 1024x1024 atlas is retained for runtime use.

The supplied files contain no author, source URL, readme, or license metadata.
This note records that absence and does not make a license claim.
