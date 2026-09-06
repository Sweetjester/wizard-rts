# Kon's Observation Tower: HD Remaster V3

## What Ships

This is an in-game, orbitable 3D remaster of
`kons_observation_wizard_tower_01`, not a billboard, concept paintover, or
replacement gameplay building. `ObservationTowerSkin` remains the entry point.
The tower still occupies **18 x 18 cells and 32 authored vertical levels**.
Its decorative finial remains below y=35 in the existing reserved airspace.

The original tower YAML, compiled definition, navigation, gate rules, collision
boxes, unit permissions, observation floor and connection sockets are unchanged.
The flattened citadel and other buildings retain their own skins.

## Visual Direction

Read `STYLE_BIBLE.md` first. The goal is a readable painted miniature, not a
noisy photoreal building. Broad stone forms and the large glass crown identify
the tower at RTS distance; closer views reveal drawn surfaces and joinery.

- Pale neutral/cool limestone with painted bevels and restrained variation.
- Charcoal oak and slate, distinct from the masonry rather than recoloured stone.
- Cyan lancets with individually illustrated tracery and selective emission.
- Clouded blue glass dome, dark iron ribs and small aged-brass accents.
- Three pitched balcony canopies with physical shingle lips and open circulation.
- Sculpted cornices, pilasters, cantilever brackets and balcony framing.
- Observing-eye pennants, astronomical gate seal, crown armillary and telescope.
- Burgundy lobed ivy with dimensional centre folds, not pink triangular strips.
- A painted gate attached to the actual gate node, so it disappears when open.

## Actual Resolution And Sampling

The built-in image generator produced three **1254 x 1254** native PNGs. Prompts
requested 2048px, but that is not what was returned. Do not describe these as
2K/4K sources or enlarge them and claim additional detail.

`masonry.png` is dedicated to stone. `surfaces.png` contains four equal swatches:
top-left timber, top-right slate, bottom-left glass, bottom-right bronze.
`details.png` contains lancet, astrolabe, pennant and door in that order.
Each source quadrant is 627px square, before item-specific UV framing.
The production files are exact copies of the generated source pixels.

Quality comes from independently allocated materials, useful on-mesh texel
density, sharp painted silhouettes, lossless imports, anisotropic mipmapped
sampling, and genuine geometry. Stone repeats over six world units rather than
stretching one image over the whole tower. Timber and slate have their own scale.
The shader uses texture gradients across repeated atlas quadrants to avoid a
derivative spike at every repetition, with inset UVs limiting neighbouring-cell
bleed. Very distant mips may still lose detail, as expected.

Run `tools/blocks/configure_tower_hd_imports.gd` after the first editor import,
then reimport. Imports use lossless compression, generated mipmaps and no size
limit. The three uncompressed RGBA sources plus full mip chains are approximately
24 MiB together, excluding renderer padding and the shared legacy assets.

Exact generation prompts, native dimensions and source filenames are preserved
in `generation_record.json`. Generation used the built-in `image_gen` tool,
not an external API script.

## Integration

1. `scripts/blocks/structure_builder.gd` creates the unchanged block/nav structure.
2. For this tower only, family materials are replaced by dedicated HD materials.
3. `observation_tower_skin.gd` retains the existing deterministic gothic dressing,
   upgrades window artwork and leaf geometry, and installs the HD dome material.
4. `observation_tower_remaster.gd` builds the additional architectural mesh layer.
5. `observation_tower_effects.gd` responds to the existing display settings.

The additional architectural layer currently contains **692 bevelled pieces**,
batched by material, plus roof panels and illustrated facade meshes. It does not
create one node for every stone. The reusable bevelled mesh has chamfered corners
and top/bottom lips, which catch actual lighting.

New batched pieces and roof panels are rejected when their conservative bounds
overlap reserved walking/headroom cells. Reservations include two levels above
nav cells, authored open cells and samples along traversal links. This is a
visual clearance guard, not a change to collision or a universal unit-volume
solver. Existing geometry and surface-mounted plaques are outside this new-piece
guard; their known facade anchors still need visual review.

Rotated placements use a canonical tower decoration layout transformed with the
placement. Placeholder replacement tests also use canonical cell coordinates,
and the gate art transforms with its leaf. Do not rotate only the block grid.

## Lighting And Motion

At most six local lights survive construction. They do not cast extra shadows,
fade by distance (60 to 85 world units), and favour the entrance, lantern arm and
crown. Painted window emission carries the remaining illumination at distance.
Window/dome brightness breathes subtly; pennants move very slightly.

Performance mode or disabled atmospheric effects hides the six lights and stops
the shader motion. Static emissive glass remains readable. There are no extra
per-frame tower light searches or particle emitters. Geometry is not removed by
the effects setting. The existing global environment still controls bloom.

## Verification And Review

Run from the project directory using your installed Godot executable:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script tools/blocks/verify_tower_hd.gd
godot --headless --path . --script tools/blocks/verify_art_skin.gd
godot --path . --script tools/blocks/verify_tower_hd_ingame.gd
godot --path . --script tools/blocks/shot_tower_hd.gd
```

Set `ART_SHOT_DIR` to an existing output directory for image captures. The shot
tool produces front, back, crown, closed/open entry, RTS-distance and performance
views. Its neutral warm-key/cool-fill review lighting is intentionally different
from the old dark demo light. Compare geometry using consistent lighting;
`shot_observation_tower.gd` still supplies the original lighting setup.

`verify_tower_hd.gd` covers:

- All six YAML acceptance cases, including gate rejection and heavy restrictions.
- Infantry, archer, climber and flying access to all balconies and the crown.
- Four placement rotations and deterministic canonical geometry.
- Added sculpted-piece clearance, material resolution and mipmaps.
- Six-light budget, performance-mode disabling, gate and skin visibility.
- Byte-identical authored cells, links, sockets, gate cells and collision boxes.

The live tool constructs a tower through the real runtime placement API on a
generated map, verifies that the HD skin is installed at unit scale, exercises
the live navigation route to the observation floor, synchronizes the gate, and
saves an actual game-renderer screenshot. It does not modify the map generator
to force towers into every game.

The local test environment can emit certificate-store, shader-cache and shutdown
resource warnings. Check explicit test failure counts and script/shader errors;
do not call a run clean just because the process exits zero.

## Next Building Handoff

Reuse this approach, not these tower coordinates. Preserve the target building's
actual authored plan. Allocate surface and identity artwork separately, build a
few strong silhouette changes within clearance, batch detail geometry, wire
gate/cutaway state, and inspect both neutral review views and the actual game.
Never improve a screenshot by silently rescaling the gameplay footprint or
replacing the entire structure with a flat image.
