# Spawner Painted V2

Installed in the existing Spawner scene. The Winged Spawner uses the same atlas,
with separate airborne animations. Gameplay stats, pathing, drone limits and Bio
costs are unchanged. Procedural art remains available for the mass-unit fallback.

## Art

Bone-plated brood abdomen, burgundy membranes, cyan compound eyes and veined
wings; six articulated legs, independently moving head and antennae, opening
brood hatch, and an organic artillery siphon. New portrait used by both forms.

The built-in image generator created source_parts.png from the user's supplied
Spawner reference. The exact prompt is in art_prompt.txt. Magenta is only a source
key; runtime sprites are transparent and need no chroma shader or generation API.
The Godot puppet renders at twice the final resolution before downsampling.

## Contract

- spawner.png: 4608 x 6144; 384 x 384 cells, 12 columns, 16 rows, 192 frames.
- One three-quarter view mirrored left/right, not eight independent directions.
- Cutout rig animation, not 192 separately hand-painted poses.
- Feet: (192,310). 2D scale: 0.50. 3D pixel size: 0.009.
- Atlas is shared between all instances and both forms; RGBA8 is about 108 MiB
  before driver compression. Source art is loaded only by the offline baker.
- Rows in order: idle, move, root_cast, rooted_idle, artillery_attack,
  uproot_cast, summon_drone, evolve_wings, hit, death, takeoff, idle_flying,
  move_flying, landing, air_artillery, summon_flying.

Actual shot and successful drone-spawn callbacks trigger the corresponding clips.
Root/uproot/takeoff/landing frames follow the existing cast progress. Death removes
the unit immediately but leaves a visual-only corpse for a 1.4 second collapse,
2 second hold and 0.7 second fade, in both 2D and 3D.

## Rebuild and review

Run from the Godot project directory with your Godot executable:

```powershell
godot --path . --rendering-method gl_compatibility --script tools/spawner/bake_spawner.gd
godot --headless --path . --editor --import
godot --headless --path . --script tools/spawner/verify_spawner.gd
godot --headless --path . --script tools/spawner/verify_spawner_3d.gd
godot --path . --rendering-method gl_compatibility --script tools/spawner/preview_spawner.gd
```

The last command opens eight animated action views. Append `-- --capture` to save
animation_review.png and exit. The baker and preview require a real renderer.

## Boundaries

The brood insect in the summon clip is a brief visual cue; actual drone gameplay
and the drone unit's own artwork remain unchanged. Casts and locomotion currently
use authored poses rather than terrain-conforming foot placement. Additional
camera angles and a fuller wing spread are suitable next art passes.
