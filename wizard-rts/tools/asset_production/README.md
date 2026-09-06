# Kon Asset Production Handbook

Version 1.0 - 2026-09-06. A documented production method, not a new generator.

## Start Here

For the detailed explanation of how generated art becomes animation and in-game
building materials, read [Image Generation And Animation](IMAGE_GENERATION_AND_ANIMATION.md).

Read STYLE_AND_QUALITY.md, then either UNITS.md or BUILDINGS.md. Fill out
ASSET_BRIEF_TEMPLATE.md before implementation. An unattended worker also reads
OVERNIGHT_AGENT.md. These files live together in tools/asset_production/.

This handbook was assembled by reading the existing bakers, presentation code,
building skins, navigation tests and asset handoffs. It does not imply every
historical asset has been re-tested today. Actual code and fresh evidence win
over old documentation. Record discrepancies instead of quietly copying them.

## What We Actually Built

Two pipelines share one art direction but produce different runtime assets:

1. Units: reference -> painted parts or key poses -> authored Godot puppet ->
   offline transparent animation atlases -> existing Sprite2D/Sprite3D unit
   presentation -> gameplay integration -> automated and visual verification.
2. Buildings: reference + exact gameplay dimensions -> independently authored
   solids/navigation/gates/sockets -> converted runtime definition -> real 3D
   modular skin with painted textures -> actual construction and navigation.

Units are NOT generally new skeletal 3D models. Structures are NOT flat concept
paintings pasted over boxes. Neither pipeline needs an image-generation service
at runtime. Painted sources are retained for offline rebuilds.

## Current Examples To Study

| Need | Working reference |
| --- | --- |
| Art-only replacement and foot alignment | tools/oaven/README.md; tools/oaven/oaven_puppet.gd |
| Articulated cutout creature | tools/spawner/README.md; tools/spawner/spawner_puppet.gd |
| Pose-based new unit and active ability | tools/mangler/README.md; tools/mangler/ |
| Segmented creature and alternate form | tools/serpent/README.md; tools/serpent/ |
| Hero spells and targeting | tools/kon/README.md; scripts/units and scripts/input implementations |
| Compact traversable building | tools/blocks/OBSERVER_VAULT.md; scripts/blocks/compact_observer_vault.gd |
| Compact lab and scale history | tools/blocks/QUARTER_SCALE.md; scripts/blocks/compact_splicing_lab.gd |
| Navigation and live construction testing | tools/blocks/verify_vault.gd; tools/blocks/verify_vault_ingame.gd |

Do not assume tools/unit_pipeline/ (the separate Blender/3D pipeline) describes
the painted billboard workflow. Do not mix its output contract into this one
without explicitly choosing a different production method.

## Known Documentation Traps

- SPLICING_LAB.md preserves a full-size master and historical module behavior.
  The current compact lab is 9/5/7 X/Y/Z; read QUARTER_SCALE.md and the catalog.
- The observation tower is restored to 18/32/18 and is not downsampled.
- Older Kon notes mention dividing observer-floor height. The restored tower
  uses the original observation region; inspect the current ownership/floor check.
- Observer Vault is now standalone, while existing installed vault modules
  retain research access. Catalog IDs are compatibility contracts, not labels
  to rename casually.
- Historical PASS counts certify their recorded run, not your modified branch.

## Production Gates

Each asset moves through: BRIEF -> SOURCE_ART -> PLAYABLE -> VERIFIED -> REVIEW_READY.
APPROVED is reserved for the user's visual acceptance. A worker must not
self-approve artistic quality simply because it generated the asset.

Store a small evidence folder per task: completed brief, changed-file list,
exact commands and logs, contact sheet or animation review, real-map captures,
limitations and handoff. Cite current artifacts, never another asset's screenshots.

## Recommended Overnight Setup

Use one approved asset brief per task in an isolated checkout. Supply references,
an approved comparison screenshot, writable paths, available art tools, explicit
time/spend limits and the overnight prompt. Ask for REVIEW_READY, not automatic
merging or a claim of perfect art. Review the resulting evidence in the morning.

A less capable model will be more reliable modifying one proven example than
inventing a universal pipeline. Start with an art-only replacement or simple
building variant; leave complex new gameplay to a separate reviewed task.

No automation, paid job, plugin installation or model training was started by
writing this handbook. These are reusable instructions and acceptance criteria.
