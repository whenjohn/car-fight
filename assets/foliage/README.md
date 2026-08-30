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

The audition also supports Shapespark's
[Low Poly Exterior Plants Kit](https://www.cgtrader.com/free-3d-models/plant/bush/shapespark-low-poly-plants-kit-free-low-poly-3d-model)
(model ID 3523647). It contains 12 trees plus smaller plants and is published
under CC0 1.0. Its double-sided FBX, extracted textures, and license are tracked
with Git LFS under:

- `assets/foliage/shapespark/`

The Scenery menu exposes the three four-tree families separately and loads only
the selected source pack.

## Local prop auditions

Optional stones and ruined-house trials live under ignored
`assets/local/prop_auditions/`. Their working textures are reduced to 1024px
for this Intel laptop. The game places one native-scale house and all six
vehicle-scale stones just north of the tree corridor; they are visual-only and
shadow-disabled.

## Local city audition

The ignored `assets/local/city_audition/` source contains the Low Poly City
FBX, its texture atlas, and the optional forest HDRI. Run
`tools/extract_city_audition.gd` through headless Godot to produce a small local
district under `assets/local/city_audition/extracted/`. Runtime presentation
loads only that extraction, keeps it shadowless and collision-free, and shows
it only after using the arena's `LOW POLY CITY` teleport pad. The dedicated
city floor, walls, fourteen building-footprint colliders, and two-way transition
remain available in clean checkouts. Its 3x3 road grid plus entrance avenue is
continuous and drivable even though the source meshes themselves stay visual.
