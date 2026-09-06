# Steel Force Musterhouse & Croft

Delivered 2026-09-06. Structure ID: `steel_force_barracks_farm_01`.

## Scope and dimensions

This is a real block-navigation structure with a separate procedural 3D skin,
not a concept-image billboard. Barracks: 9x5x7 cells. Front farm: another
9x5x7 allocation. Combined: **9x5x14 (x,y,z)**. This matches the CURRENT
compact Kon laboratory, not its preserved 34x20x28 master. Nothing rescales or
replaces Kon's lab, tower or vault.

The farm occupies z=0..6; the hall occupies z=7..13. South is negative Z.
The compound reserves the entire footprint, including livestock and crops.

## Files and integration

- Authoring: `data/block_structures/steel_force_barracks_farm.yaml`.
- Compiled runtime: `resources/block_structures/structures.json`.
- Skin: `scripts/blocks/steel_barracks_skin.gd`.
- Paint, reference, shaders and exact prompts: `assets/structures/steel_barracks_hd/`.
- Builder hook: `BlockStructureBuilder.build`, art key `steel_barracks_hd_v1`.
- Interior hook: `Map3DView._sync_block_gates` calls `set_interior_view`.

Place through the existing `BlockNavBridge.place_runtime_structure` API, or
include the ID in the generator's structure placements. The supplied review
script demonstrates actual placement on the game's terrain.

This delivery does **not** register a new construction-menu entry, recruitment
queue, Steel Force player economy or farm resource production. The YAML's
`production_integration` section is a handoff contract, not executable gameplay.
It gives recruit anchor [4,1,10] and muster exit [4,1,6]. Do not replace Kon's
existing barracks/lab or conscription system to integrate this faction building.

## Art method

The supplied tall fantasy farmhouse is interpreted at the compact gameplay
scale: pale chalk masonry, weathered timber, charcoal slate, warm amber glass,
ivory anvil heraldry, an asymmetric lookout, a sheltered entrance and a croft.
It is a compact interpretation, not a literal reconstruction of every storey.

Four raster materials were generated with the built-in image generation tool,
using the user's image as the style reference. Exact prompts and actual source
sizes are in `generation_record.json`. The prompts requested 2048 square but
the returned files are **1254x1254**, retained at native resolution. They are
not 2K/4K assets and have not been upscaled. The user reference is 1024 square.

Stone uses about 418 source pixels/cell, timber about 527 and slate about 602.
This puts detail on individual surfaces rather than stretching a single atlas
over the whole building. The fourth image is a 2x2 atlas: window, door, banner,
wicker. Each patch is about 612 effective pixels after the shader gutter.

Surface shader: triplanar projection, anisotropic mipmapped sampling, matte
response. Detail shader: UV atlas sampling, selective amber emission and a
small animated flag displacement. Both use existing Godot materials/meshes;
no custom renderer, image projection facade or navigation-from-texture logic.

Geometry carries the silhouette: stepped shingle edges, diagonal timber braces,
window recesses/mullions, octagonal turret, chimneys, gate leaves and lantern
frames. Two short-range non-shadowed lights provide local warm spill. Repeated
boxes, stalks and rods are batched by material and visibility group with
MultiMesh. All generated surfaces have lossless imports and mipmaps; four RGBA
textures would occupy roughly 32 MiB including mips, before driver overhead.
This is a quality-first starting budget, not a measured hundred-building stress
test. Profile before mass placement; share/cache more meshes/materials or use
tested GPU compression if needed. Livestock are static sculpted props, not
animated farm units. No harvesting or livestock simulation is included.

## Navigation contract

YAML alone authors solid cells, standing cells, traversal links, gates and
sockets. The skin must never change the navigation lattice. Interior selection
hides the roof and front wall visuals; it does not delete collision or open gates.
The rear loft is an uncovered gallery, avoiding a roof through its standing row.

- Ground-level farm ramp has 2x2 landings, then a straight wide lane into the hall.
- Four authored corner links describe that ONE ramp. They retain a valid heavy
  minimum-corner footprint anchor after rotation. Do not collapse these to one
  link unless the shared navigation engine gains footprint-aware link rotation.
- Twelve visual stair treads follow the explicit stair link to loft level 4.
- Infantry, archers and climbers reach the loft; heavy cavalry stays downstairs.
- Crops, bunks, stair reserve and livestock pen cannot become walking shortcuts.
- Farm gate and hall gate default open; east service gate defaults closed.
- The service socket is at floor level 1, suitable for a raised connecting path.
- Flying uses the engine's existing ground-navigation bypass. The flying test
  does not claim a new volumetric flight or roof-avoidance system.

The current bridge opens gates when placing a runtime structure. The review
explicitly restores the service gate's authored closed state. Existing gate
state keys are global: multiple copies share the three Steel gate states until
the shared bridge supports instance-scoped keys. Do not promise independently
controlled gates on multiple copies without that engine change and tests.

## Rebuild and verify

Run from the Godot project directory. `godot` denotes the Godot 4.6 executable;
Python needs PyYAML. Do not regenerate unrelated art or overwrite dirty files.

```powershell
python tools/blocks/convert_structures.py
godot --headless --editor --path . --import
godot --headless --path . --script tools/blocks/configure_steel_barracks_imports.gd
godot --headless --editor --path . --import
godot --headless --path . --script tools/blocks/verify_steel_barracks.gd
godot --headless --path . --script tools/blocks/verify_quarter_scale.gd
godot --headless --path . --script tools/steel_force/verify_mounted.gd
```

For screenshots set `ART_SHOT_DIR` to an existing writable directory:

```powershell
godot --path . --script tools/blocks/shot_steel_barracks.gd
godot --path . --script tools/blocks/steel_barracks_review.gd
godot --path . --script tools/blocks/steel_barracks_review.gd -- --play
```

The last command leaves an interactive game review open, with three gate
toggles. The normal review runs its tests, captures the real game, and exits.
Its infantry and mounted knight use the normal runtime movement scheduler.
Do not test CharacterBody movement by calling move_and_slide repeatedly within
one frame; that previously gave misleading stuck-recovery failures.

## Verification and limits

Passed: 12 authored class/gate routes, the same routes stamped into a world in
all four rotations, all rotated mesh bounds, gate visibility, reversible
cutaway, unchanged navigation after skin building, native texture dimensions
and imported mipmaps. Existing lab/citadel regression: 1,031 checks passed.
Mounted knight regression passed after guarding its contact scan against
building nodes in the broad units group.

The graphical review passed real farm-to-loft infantry movement, cavalry entry,
heavy stair rejection, occupant selection cutaway, roof restoration and gate
leaves. Screenshots cover 1600x1000 and 1024x720; the isolated render captures
front, closed, rear, interior and detail views at 1800x1400. These are actual
Godot renders, not generated concept promises. Visual quality still needs the
user's aesthetic approval.

The converter still reports seven pre-existing schema warnings in other
structures, none for this building. This environment also reports certificate
store/shader-cache warnings and shutdown resource leaks. Functional test exit
codes pass, but these logs are not warning-free. One initial headless launch
crashed with the default user-data location; tests succeeded with APPDATA and
LOCALAPPDATA redirected to a writable review directory. No release export,
multi-instance gate isolation or large-army performance certification was done.
