# Traversable Building Production Procedure

## 1. Fix The Gameplay Envelope

State exact X/Y/Z dimensions and coordinate convention: X east, Y up, Z north;
the current YAML regions use inclusive cell ranges. A 9/5/7 definition spans
x=0..8, y=0..4, z=0..6; its mesh envelope reaches x=9, y=5, z=7.

Current examples: tower 18/32/18 restored; lab 9/5/7; vault 9/5/7; citadel
runtime 24/12/24 with preserved 96/46/96 master. Read runtime profiles, not only
design masters. New sizes require new architecture, not coordinate division.

Never shrink unit clearance to make a building fit. Preserve useful doorway
widths, stair landings and interior identity; remove a storey or simplify rooms
before squeezing the same plan into an invalid grid.

## 2. Author A Walkable Plan First

Sketch each floor with entrance, occupied fixtures, walkable aisles, stair
foot/top, gallery and service exit. Reserve door swing space. List who can reach
which region. Inspect unit-class width/depth/height in the current definitions.
A heavy agent needs a footprint of contiguous clear cells, not merely a wide
looking doorway. Test exact start/destination footprints and overhead clearance.

Write existing-schema YAML for dimensions, solids, nav_regions, links, gates,
sockets, art dispatch and validation_tests. Use the vault YAML as the compact
example. Use existing composition support for repeated large substructures;
do not invent unsupported YAML keys and imply the loader implements them.

Navigation is authored separately from visuals. Neither mesh generation nor a
downsampling pass may erase solids to make navigation pass. Decorative fixtures
that consume physical space need an appropriate authored occupied region.
Check floor support, headroom, valid link endpoints and landing widths.

For sockets, specify position/facing/width and use the existing rotation and
terrain-base transforms. Exterior paths outside the footprint must be explicit
and validated, never smuggled into supposedly bounded structural regions.

## 3. Convert And Test Runtime Data

Run tools/blocks/convert_structures.py with Python + PyYAML. The converter reads
root YAML structures and attaches configured compact profiles. Edit YAML, not
generated resources/block_structures/structures.json by hand.

Test BlockStructureLibrary.get_definition() and navigation_for(), which supply
the active runtime data. Master tests are supplementary. Keep old warnings
separate; every new warning introduced by the asset needs resolution.

Required cases: infantry/archer/climber reachable destinations, heavy valid
destination and prohibited route, flying behavior, gates open/closed independently,
reserved fixtures unreachable, rotations 0/90/180/270, and terrain-to-entry route.
If a test fails, explain the intended reachable region before changing expected
results. Never weaken a test solely to get a green report.

## 4. Construct The Skin At Native Size

Use compact_splicing_lab.gd and compact_observer_vault.gd as examples, not a
universal inheritance requirement. Reuse established stone/glass/iron materials,
primitive helpers, deterministic variation and batching where they fit.

Build in layers: foundation and broad masses -> walls/arches/supports -> floors
and stairs -> windows/doors -> identity props -> vines/books/lamps -> lighting.
Save a normal-camera capture after the broad forms before adding micro-detail.

Real 3D geometry supplies depth, silhouette and parallax. Painted textures supply
illustrated masonry, engravings and book detail. Use custom texture generation
for new production surfaces, not an exterior concept painting stretched across
every wall. Plan atlas UV regions, gutters and material response deliberately.

Keep a clear structural hierarchy and visible interior. An open atrium/cutaway
is an intentional solution; it is not automatic roof fading. Do not add beams
through walkable headroom simply because navigation does not see the mesh.

Door geometry must agree with state. Vault's round leaf rotates into reserved
space; existing simpler leaves hide when open. Animation duration, if added,
requires a defined moment when collision/nav becomes passable. State changes
must go through the authoritative gate system, not just a visual toggle.

## 5. Integrate Normal Construction

Register bespoke art dispatch in structure_builder.gd using the existing
art.bespoke_skin convention. Apply the established rotation translation once.
Preserve collision building and snapshot definition data before/after skinning
to prove visuals did not mutate nav, solids, links or gate cells.

Point the catalog's block_structure to the new ID and match its placement
footprint. Decide explicitly whether this is standalone or a tower module;
changing module_role changes gameplay. Preserve existing IDs, research/training
costs and unlocks unless the task authorizes changes. Check legacy consumers.

Trace BuildSystem -> BlockNavBridge -> placed runtime definition -> Map3DView
builder -> live gate synchronization. A successful standalone preview is not
proof this path selects your new skin. Start a fresh game after footprint edits.

Current caveat: gate state keys are shared by type, not isolated per instance.
Do not advertise independent manual doors on multiple copies without implementing
and testing per-instance ownership. Do not broaden a single-asset task into
that shared-system rewrite without approval.

## 6. Required Evidence

- Mesh bounds for all four rotations and both gate states. For headless
  MultiMeshes use authored_bounds metadata as the existing tests do.
- Data immutability and support/clearance validation, not only bounding boxes.
- Graphical inspection of actual stair/gate/fixture clearance; metadata tests
  alone cannot catch a decorative beam intersecting a unit.
- Real generated-map placement, unit walking from terrain through the gate to
  an upper destination, correct final nav level and visible skin selection.
- Closed/open gates, relevant research/training availability and resource costs.
- Regression tests for touched shared behavior and preserved neighboring assets.

Representative vault checks:

```text
python tools/blocks/convert_structures.py
godot --headless --path . --editor --quit
godot --headless --path . --script tools/blocks/verify_vault.gd
godot --headless --path . --script tools/blocks/verify_vault_ingame.gd
godot --headless --path . --script tools/blocks/verify_splicing_lab.gd
godot --path . --script tools/blocks/shot_vault.gd
```

Set ART_SHOT_DIR for captures. Use the actual game renderer for visual evidence.
Document remaining camera/occlusion and per-instance limitations honestly.
