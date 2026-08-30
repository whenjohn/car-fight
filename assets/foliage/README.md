# Foliage audition assets

Car Fight can optionally audition the CGTrader model
[Low Poly Trees Mega Pack - 200 Trees](https://www.cgtrader.com/free-3d-models/exterior/landscape/lowpoly-tree-collection-01-200-trees-lowpoly-collection)
by **ilkhom23** (model ID 3304599).

The listing applies CGTrader's **Royalty Free License (no AI)**. That license
allows the model to be incorporated into a game, but does not allow the source
model or a readily extractable copy to be redistributed. Therefore the FBX and
texture are deliberately local-only and ignored by Git. Do not commit them.

For an authorized local audition, place the owner-downloaded files at:

- `assets/local/lowpoly_tree_collection_01/LowPoly_Tree_Collection_01_fbx.FBX`
- `assets/local/lowpoly_tree_collection_01/textures/color_1024x1024.jpg`

The committed game falls back to its procedural trees when these files are
absent. Imported meshes are presentation-only; the deterministic trunk
colliders, object count, and network state remain unchanged.
