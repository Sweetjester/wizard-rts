# Stone-Faced Serpent overhaul

Implemented September 5, 2026. This is an integrated 2D sprite character used
by both the simulation's 2D view and the existing 3D billboard renderer. It is
not a new rigged 3D creature or an eight-direction sculpt.

## Art and animation

`assets_game/units/kon/serpent/painted_v2/source.png` is the generated painted
parts sheet based on the supplied concept: cracked turquoise stone, coral eyes,
burgundy joints and black-veined cyan fins. Original source is retained.

Six stage atlases contain 108 frames each (nine actions, twelve frames/action):
idle, movement, poison bite, harden, hardened idle, revert, evolution, death,
and hit reaction. These 648 frames are procedurally animated from the painted
parts, not 648 independently painted poses. Facings are right and mirrored left.
Each evolution adds articulated body sections; the head remains the gameplay
pivot. Mobile tail sections are visual, not independent collision bodies.

`serpent_painted_art.gd` selects the stage and animation. The ordinary unit
scene now includes ArtSprite; the original vector art remains only as the
existing mass-unit performance fallback. The HUD portrait is replaced too.
Separate wall PNGs avoid runtime image cropping and are shared by all instances.

Rebuild with Godot 4.6.2 (graphical rendering required for baking):

```text
--path . --script tools/serpent/bake_serpent.gd
--path . --script tools/serpent/shot_serpent.gd
--headless --path . --editor --quit
```

Set ART_SHOT_DIR to an existing directory for preview captures. The shot tool
also extracts the portrait and wall tiles. Sprite sheets are shared textures
per stage, not generated separately for each unit.

## Gameplay

Five evolutions means base level 1 through level 6. Each evolution costs 45 XP.
Provisional balance values are in UnitCatalog, not in the art:

| Level | Mobile HP | Reach (cells) | Wall cells | Wall HP | Wall armor |
| --- | --- | --- | --- | --- | --- |
| 1 | 240 | 2.00 | 3 | 480 | 13 |
| 2 | 298 | 1.75 | 4 | 656 | 16 |
| 3 | 356 | 1.50 | 5 | 854 | 19 |
| 4 | 414 | 1.25 | 6 | 1076 | 22 |
| 5 | 472 | 1.00 | 7 | 1322 | 25 |
| 6 | 530 | 0.75 | 8 | 1590 | 28 |

Mobile armor is 5. Bite damage starts at 24 and adds 5 per evolution. Poison
uses the existing damage-over-time system: 5 damage/second for four seconds,
subject to that system's mitigation and refresh rules.

Stone Form: activate the existing ability, then drag a tile path. Dragging can
form several cardinal turns, never diagonal links. Backtracking shortens the
authored path; remaining length extends along its last direction. Overlaps,
invalid ground, occupied cells, elevation changes and remote starts are rejected.
Placement currently targets terrain, not elevated building navigation floors.

Click any wall segment to select its serpent. Once selected, left-drag from a
wall tile to reposition or reshape it. Right-click/Escape cancels placement.
The ability button reverts an active wall; revert starts a ten-second cooldown.
The two-second hardening cast retains the old wall until a valid replacement
is ready. The 3D view includes a valid/invalid placement preview.

All segments share one HP pool. Hardening and reverting preserve the health
fraction, so repeated toggles cannot heal. Wall form cannot move or attack,
including direct attack and central movement entry points. Deferred spawn
validation cannot eject a hardened owner from its own blocked tiles. Existing
poison continues ticking while hardened. Death/revert removes all terrain blockers
and targetable segments. Wall length changes on the next valid reshape if it
evolves while already deployed.

## Verification

```text
--headless --path . --script tools/serpent/verify_serpent.gd
--headless --path . --script scripts/core/stone_face_serpent_smoke_test.gd
--headless --path . --script scripts/core/evolution_stat_integrity_smoke_test.gd
--path . --script tools/serpent/verify_serpent_ingame.gd
```

Checks cover growth, reach, poison, hardening stats, shared damage, disarm,
multi-bend dragging, blocker replacement, health preservation, selection-owner
resolution, death animation, atlas dimensions/content and live 3D rendering.
The live fixture avoids the central generated ruin, whose geometry obscured an
earlier capture. Godot still reports environment certificate/shader-cache and
shutdown resource-leak warnings; those wider project issues are not resolved here.
