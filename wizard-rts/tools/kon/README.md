# Kon: Broken Staff / Life Wizard Overhaul

## Current Art: Eight Directions (2026-09-06)

The live hero now uses `directional_v3`, not the two mirrored facings described
in the historical overhaul below. Read [DIRECTIONAL_V3.md](DIRECTIONAL_V3.md)
for the current assets, generation prompts, animation pipeline and verification.
The existing `painted_v2/spells.png` effects are still used. Gameplay rules were
not rebalanced by this art upgrade.

## Delivered

The live `scenes/wizard.tscn` selects the new artwork for Bad Kon Willow only.
Fire Wizard and Evangalion keep their existing presentation. No duplicate hero
is spawned by the overhaul.

Kon's painted design follows the supplied concept: young, gaunt, black-haired,
cyan-eyed, ragged teal hood and wraps, red fungal shoulder growth, and two
unequal fragments of a broken wooden staff. He remains a 2D animated character
mirrored into the existing 3D battlefield by Sprite3D billboards.

This is NOT a new rigged 3D mesh or eight-direction character. The atlas uses
six generated painted key poses, two mirrored facings and authored transforms
and timing. Ninety-six atlas frames does not mean 96 separately painted poses.
The gait is a pose-based cycle, not a skeletal walk animation.

## Ability Rules

| Ability | Behaviour | Initial tuning |
| --- | --- | --- |
| Broken Staff | Two separately timed projectile releases, with the long/short staff attack poses and painted crescent effects. Each rechecks target, range, banishment and observation state. | Releases at 0.12s and 0.36s of the attack; retains catalog attack damage/cooldown. |
| Seal Away | Ground-targeted circle removes ALL units inside, friend or foe, including Kon if caught. They remain the same living objects but are invisible, non-colliding, unable to move/attack, immune to damage/healing, excluded from vision and combat queries. Return at the same position after five simulation seconds, with HP/upgrades/ownership intact. Orders are cleared on entry. | 150px radius; 640px cast range; 12s cooldown; no resource cost. Seal upgrade adds 12px radius per rank, never changes the five seconds. |
| Observation Aura | Free toggle. Kon is immobile, cannot attack or cast the other active spells, and projects increased fog-of-war sight until cancelled. Existing allied ranged support is retained. Damage can still hurt him. | Normal sight 9 cells; observation 18, plus 2 cells per existing Observation upgrade rank. |
| Biostorm | Ground-targeted persistent storm, re-evaluating living units in its circle every damage pulse. Friendly fire includes Kon. Units can walk out; banished units are immune. The storm remains if its caster dies. | 60 Bio; 200px radius; 640px cast range; 4s duration; eight 12-magic-damage pulses at 0.5s intervals; 18s cooldown. Magic armour applies to each pulse. |
| Observer | Observation gets a second sight multiplier only on the actual navigable crown floor of a completed, owned observation tower. Requires matching placed-instance ownership and authored level 26 divided by the library's current downsampling factor, plus terrain base. Wrong floor, enemy/unfinished tower, and banishment fail. | 2x observation radius: 36 cells at rank zero. Building placement during Observation must lie inside this range and still pass normal footprint/economy/resource checks. |

The durations explicitly requested by the user are preserved. Other costs,
radii and cooldowns are initial balance choices, not previously specified rules.
Circles operate in simulation XY across elevations, matching the existing RTS
area-query convention; they do not perform per-floor exclusion.

## Input and Existing Systems

Select Kon in the normal game. Seal Away and Biostorm enter the existing
selection controller's ground-target mode. Left-click confirms. Right-click or
Escape cancels without issuing a movement order. An out-of-range cast remains
in target mode and reports failure without charging resources. The preview
turns red when range/stance prevents casting. Feedback reports cooldown or
insufficient Bio. In 3D the preview and effects use the same screen-to-simulation
conversion as existing movement/building placement.

Observation uses the existing toggle button to enter/cancel. Movement commands
cannot move Kon while it remains active. Normal construction outside the stance
keeps the game's existing placement behaviour; this change does not impose a
new walking-builder system. Tower modules still use their existing module-host
installation route. The old Bio Mend action and hero levelling choices remain
for compatibility. Seal Away no longer deletes allies or refunds their Bio.

## Art and Effects

Assets live in `assets_game/units/kon/hero/painted_v2/`:

- `source.png`: generated six-pose chroma-key source, retained for rebaking.
- `kon.png`: actual transparent 4608x3072 runtime atlas; 12 columns, 8 rows,
  384px square tiles. Rows: idle, move, dual attack, seal, observe, storm, hit, death.
- `spells.png`: transparent 2x2 effect atlas: thorn seal, fungal storm,
  observation eye and double-branch crescent.

The source sheet is never referenced by the shipped hero. Godot's bake applies
the existing chroma shader, removes the magenta and fits each pose to padded
frames. Source regions are adjusted individually to exclude neighbouring art.
The effects combine painted imagery with moving spores, circular ground marks,
and procedural lightning strokes in 2D; 3D uses depth-tested painted billboards,
horizontal rings and rising motes. No spell collision is derived from the art.
The 3D observation effect follows Kon's authored floor elevation.

Death removes Kon from the simulation immediately and leaves a timed painted
corpse. Existing defeat handling still owns what happens to the match.

## Reproduction and Checks

Run from the Godot project directory with the installed Godot executable:

```powershell
godot --path . --script tools/kon/bake_kon.gd
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/kon/verify_kon.gd
godot --path . --script tools/kon/verify_kon_3d.gd
godot --path . --script tools/kon/preview_kon.gd
```

Set `ART_SHOT_DIR` to an existing writable directory to capture the review and
live 3D verification images. Pass `-- --capture` to close the review after saving.

The focused verifier checks all frame bounds and row variation, real alpha,
live art binding, timed banishment, friendly fire, charge failures, cooldowns,
observation immobilisation, owned/rotated tower conditions, summon radius,
separate staff impacts and final corpse pose. The 3D verifier extends the
existing live-map test and adds Kon atlas/facing, banish hiding and spatial FX.

## Boundaries

### Verification Result (2026-09-05)

- Focused Kon verifier: exit 0, zero failed assertions, including current
  downsampled/rotated crown detection and target-mode cancellation.
- Existing WizardLevelingSmokeTest: exit 0; both life and fire upgrade paths pass.
- Live-map Kon3D verifier: all state assertions pass; headless execution exits 0.
- Real Forward+/D3D12 render: hero and storm captured and visually inspected.
  This graphical test crashes during engine shutdown after assertions complete,
  with texture RID leak reports. Explicit scene teardown did not resolve it.
  Do not report this as a clean graphical test exit or a proven engine-only bug.
- Painted animation/effect review capture: exit 0. All atlas tiles are nonempty,
  padded and varied; neighbouring source-pose fragments were removed by region
  corrections. Final patch whitespace check passes.

The project also emits certificate-store, shader-cache-path and some existing
map-generation warnings during these runs. No attempt was made to change those
unrelated systems as part of this hero overhaul.

No sound recordings or voice lines are included. This is a painted pose system,
not a fully articulated 3D model. No new unit production or faction economy is
invented. Replay/network/save persistence for ongoing spell timers is not added;
these use the same local runtime lifecycle as existing unit effects. Returning
banished units retain their location; existing separation resolves crowds after
return, without attempting to rebuild a lost navigation route.
