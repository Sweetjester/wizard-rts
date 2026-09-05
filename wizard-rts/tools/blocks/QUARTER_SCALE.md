# Kon buildings: runtime plans and restored tower

September 5 revision: the observation tower is restored to its untouched
18x32x18 master and original ObservationTowerSkin. It has NO compact profile.
The laboratory remains 9x5x7 but now uses purpose-built, unscaled geometry in
`scripts/blocks/compact_splicing_lab.gd`. Do not shrink either original skin.

## What was wrong

The full-size YAML masters were intact. The previous loader divided solid,
navigation, gate and socket coordinates by four and let navigation erase solid
cells. This merged rooms, erased thin walls and weakened closed gates. The
citadel was excluded from scaling. The old test runner checked full-size
navigation, not the reduced navigation being shipped. Hand-positioned and
geometry-derived decorations were also being scaled together inconsistently.

## Current source of truth

Edit `data/block_structures/runtime/kon_quarter_scale.yaml` for gameplay sizes.
Run `tools/blocks/convert_structures.py` to rebuild the JSON. The converter
attaches each compact plan to its full-size master as `runtime_profile`.

| Building | Master X/Y/Z | Runtime X/Y/Z |
| --- | --- | --- |
| Arcane Citadel | 96/46/96 | 24/12/24 |
| Observation Tower | 18/32/18 | 18/32/18 (restored) |
| Splicing Laboratory | 34/20/28 | 9/5/7 |

Quarter scale means approximately one-quarter of each linear dimension, not
one-quarter of the footprint area. Non-integer dimensions round upward. Unit
sizes and map dimensions are unchanged. Small decorative finials can extend
above the declared structural height.

These are compact architectural adaptations, not mathematically identical
miniatures: doors retain useful widths; landings and stairs are rearranged;
the laboratory has an open upper gallery and two specimen islands. The tower
uses its original multi-storey ascent, balconies and observatory. The castle
retains four accessible tower variants, courtyards, ring walk, stepped keep,
paired south gate leaves, north service gate and observation-tower door.

The full-size masters and their prefab composition remain unchanged. Eleven
reference-pack structures without runtime profiles remain unchanged.

## Runtime contract

- `BlockStructureLibrary.get_definition()` and `navigation_for()` return the
  explicit runtime plan, without calling `downsampled()`.
- `authored_definition()` still returns the full-size master. Pair it with
  `authored_validation_tests_for()` for design-master tests only.
- No consumer should divide authored coordinates. Locate floors by region ID
  or use runtime sockets. Kon's Observer checks `observatory` at original y=26, including
  instance rotation, ownership and completion.
- BuildSystem reads the runtime footprint; catalog fallbacks match it. Map
  generation reserves a 24x24 citadel plot, not a 96x96 plot.
- Citadel visuals subdivide the compact plan into quarter-cell painted blocks, then
  scale that visual child once. Navigation remains at gameplay resolution.
  Thin upper slabs and visual stair headroom prevent solid floor slabs from
  filling the stair route. Decoration never writes back into runtime nav.
- The lab bypasses that subdivision path. Its custom skin is constructed in
  game units, with a glazed pointed nave, irregular masonry, two retorts,
  front/rear gothic windows, burgundy vines, lanterns, four specimen vats and
  exposed stairs to the y=4 gallery. All mesh bounds fit 9x5x7. BuildSystem and
  the YAML still own placement, navigation and both gate states.
- Material sampling and actual light ranges follow the art scale. Existing
  full-size skins retain their original coordinates and material scale.
- Map3DView synchronizes gate leaves with live navigation gate states.
- Existing gate key names are retained; the compact keep has an additional
  `citadel_keep_gate_open` gate. Gate states remain globally keyed as before;
  this change does not introduce per-instance gate-state ownership.

## Verification

Verified after restoration: 31 runtime route cases and 1,031 compact checks
passed, plus laboratory bounds/gates, full-size art and Kon hero tests.
The graphical integration passed real construction, a live unit entering the
lab and reaching its gallery, citadel movement and gate visibility.
It exited with code 0 but emitted errors from the separate VantageEffects
script (invalid int conversion at line 62); that unrelated system is not fixed.
Earlier garrison/capture results below are not a fresh post-restoration run.

Run with Godot 4.6.2 and the project as `--path`:

```text
--headless --script scripts/core/structure_validation_smoke_test.gd
--headless --script tools/blocks/verify_quarter_scale.gd
--headless --script tools/blocks/verify_splicing_lab.gd
--headless --script tools/blocks/verify_art_skin.gd
--headless --script tools/kon/verify_kon.gd
--headless --script scripts/core/citadel_placement_smoke_test.gd
--headless --script scripts/core/citadel_garrison_smoke_test.gd
--script tools/blocks/verify_quarter_scale_ingame.gd
--script tools/blocks/shot_quarter_scale.gd
```

Set `ART_SHOT_DIR` to an existing output directory for graphical runs.

The compact suite checks dimensions, unmodified masters, solid/nav separation,
floor support, link endpoints, all five requested unit classes, four rotations,
raised-terrain socket connections, art isolation and gate visibility. The live
test uses the real map, construction system, 3D view and RTS unit movement to
enter the citadel and reach a keep terrace, and enter the laboratory and reach
its gallery. Captures: `quarter_ingame.png`, `redesigned_lab_ingame.png`.
Standalone captures: `restored_tower.png`, `redesigned_laboratory.png`.

The existing converter reports seven legacy master/reference schema warnings;
new compact profiles are validated separately and reject invalid bounds. The
test seed also reports an unrelated terrain high-zone-without-ramp warning.
Godot reports shader-cache/certificate and shutdown resource-leak warnings in
this environment. These are not claimed to be fixed by the building work.

Start a fresh game after changing profiles. Existing placed structures are not
hot-migrated to different footprints in a running session.
