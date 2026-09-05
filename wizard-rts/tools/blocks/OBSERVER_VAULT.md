# Kon's Observer Vault / Library

Implemented as a standalone research building, matching the compact lab exactly:
9 x 7 ground footprint, 5 blocks tall. No global scaling is applied.

## Integration

- Catalog ID remains `terrible_vault`; structure ID is `kons_observer_vault_01`.
- Build from Kon's existing Vault action. Select the completed building for existing research.
- Existing 140 Bio cost, 320 HP, 7-second build time and research prices are retained.
- New construction no longer consumes an observation-tower module slot. Legacy installed vault modules retain their research buttons.
- Observation tower and laboratory definitions are unchanged.

## Files

- `data/block_structures/kons_observer_vault.yaml`: solids, independently authored navigation, gates, sockets and ten route tests.
- `scripts/blocks/compact_observer_vault.gd`: deterministic 3D skin, reusing the lab's material and primitive helpers.
- `scripts/blocks/vault_door.gd`: circular door rotation synchronized to gate state.
- `assets/structures/observer_vault/library_atlas.png`: generated painted bookcase, engraved door, cyan seal and slate atlas.
- `scripts/blocks/structure_builder.gd`: skin dispatch and gate-state integration.
- `resources/block_structures/structures.json`: generated runtime data; regenerate with the existing converter after YAML edits.

## Layout And Art

South entrance feeds a clear reading nave. Rear bookshelves span two levels, with a narrow gallery reached by west stairs. East desk bay and side entrance are separate from the main route. The circular door parks in reserved solid cells x=5, z=2..4; do not add navigation through this bay.

Heavy units can enter the main reading nave, but cannot use the narrow rear passage or upper gallery. Infantry, archers and climbers can reach the gallery. Flying keeps the existing navigation behavior.

Cyan gothic windows and lanterns, red climbing vines, irregular painted masonry, carved circular lock and illuminated eye seal identify the building. The roof is intentionally an open cutaway with narrow slate shoulders and iron ribs, keeping units visible from the RTS camera. It is not a fully enclosed roof with automatic occlusion fading.

The door changes orientation immediately with navigation state, avoiding a closed-looking door after its passage becomes traversable. It is not a timed door-opening animation. Player construction currently opens both gates through the existing block bridge. Gate keys remain globally shared by building type, following the existing system; per-instance manual gate controls are not introduced here.

## Verification

- `tools/blocks/verify_vault.gd`: PASS, ten route cases, four rotated mesh envelopes, both door states, navigation immutability, lab-size match, original tower size, research completion requirement, Bio charge, duplicate unlock rejection and tier prerequisite.
- `tools/blocks/verify_vault_ingame.gd`: PASS, generated-map construction through BuildSystem, live Oaven walking from terrain to the upper gallery, actual map skin and gate synchronization.
- `tools/blocks/verify_splicing_lab.gd`: PASS, existing lab routes and visual checks.
- `tools/blocks/shot_vault.gd`: actual Godot renderer captures of open, closed and interior views; output folder comes from ART_SHOT_DIR.

Existing unrelated structure-converter warnings and Godot shutdown resource warnings remain. Tests do not certify multiplayer gate isolation, old-save migration, or every research button's mouse interaction.
