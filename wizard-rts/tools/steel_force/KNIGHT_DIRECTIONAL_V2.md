# Steel Knight: Eight-Direction Upgrade

## Scope

The existing `steel_knight` scene uses new eight-direction painted art. All
normal training/factory spawns and surviving mounted riders use that scene.
No damage, armor, costs, cooldowns, pathing classes or dismount rules changed.
The vault portrait is preserved. Poorper, Blimp and Mounted Knight artwork
remain intact.

The visual identity is pale iron plate, worn gold trim, amber visor slit and
blade, round shield, gray ragged tabard/scarf and a long gray helmet plume.
Match the reference's drawn ink contours and broad painted planes. The Knight
should read as heavier than the Poorper without enlarging its collision shape.

## Source and Generation

Built-in image_gen generated four paired sheets using
`assets_game/units/steel_force/painted_v1/steel_knight_source.png` as reference.
Exact prompts and corrections are retained in `knight_prompts.json`.

Final sources are in `assets_game/units/steel_force/steel_knight/directional_v2/sources/`:

| Source | Top row | Bottom row |
| --- | --- | --- |
| s_se.png | Front S | Front-right SE |
| e_w.png | Right E | Left W |
| n_ne.png | Back N | Back-right NE |
| sw_nw.png | Front-left SW | Back-left NW |

Each row has five keys: idle, two walking contacts, attack, collapsed corpse.
These are 40 painted key poses, not 320 independently painted frames. Opposite
views are generated anatomical views, never runtime horizontal mirroring.

Three sheets have actual alpha. The E/W correction produced an opaque
checkerboard and required another edit to flat magenta. The baker removes
magenta with the existing chroma-key shader. Never load a keyed source sheet
directly as live unit art. A pretty source preview does not prove transparency.

The correction also turns the west strike forward and places the west corpse's
head on the left. Inspect directions, handedness, intact sword tips and plume
silhouettes manually; automated tests cannot assess anatomy.

## Baking

`steel_knight_puppet.gd` follows the Poorper production pipeline: connected
foreground polygons, row/column assignment, one scale shared by all poses in
a direction, and a fixed foot anchor. No 3D rig is implied by this pipeline.
Source poses can cross nominal cell gutters; connected silhouettes must not
be cut at guessed rectangular boundaries.

Idle target height is 180 pixels, constrained by the widest/tallest pose to
fit 226x210 pixels. Frame size is 256x256, anchor (128,220). All actions share
that scale, including death, so a horizontal corpse is not enlarged to fill
a standing frame. Minor shape and plume differences remain between generated
keys; these are key-pose animations, not continuous skeletal deformation.

`bake_steel_knight.gd` renders at 512x512 and downsamples to 256x256. Each of
eight pages is 2048x1280: eight frames across and five rows, 320 frames total.

| Row | Action | Treatment |
| --- | --- | --- |
| 0 | Idle | Subtle armor/body breathing |
| 1 | Walk | Two stride contacts, passing guard stance, small heavy-step bob |
| 2 | Attack | Painted sword action and recovery; gameplay damage remains immediate |
| 3 | Hit | Restrained recoil using the ready pose |
| 4 | Death | Brief compression then painted corpse with existing hold/fade |

Different views use thrust, raised-slash or follow-through key poses, not a
fully authored multi-stage sword arc in every direction. Further in-between
painting is a possible polish pass; do not describe baked transforms as new
hand-painted animation drawings.

## Runtime

`scripts/units/steel_knight_directional_art.gd` uses the existing
`eight_direction_facing.gd` helper. Direction order is E, SE, S, SW, W, NW, N,
NE. Live target direction takes priority, then velocity, then remembered world
heading. Camera yaw is accounted for in 3D; rotated Camera2D is also supported.
Hysteresis avoids flickering between adjacent views. Turning preserves frame.

The Knight plays walking at 6 frames/second and idle at 4, compared with the
Poorper's 8 and 5. Attack presentation lasts .9 seconds, without changing the
gameplay attack interval. Hurt and stunned states use the hit row.

Sprite2D scale is .72 and offset (0,-92); foot anchor is 220. Sprite3D pixel
size is .012. Death uses row 4 for 1.25 seconds, holds 2 seconds, then the
existing .7-second fade. Captured corpses retain their last directional page;
they do not reorient if the camera is rotated after death.

The shared Steel Force death helper retains legacy anchor reset only for art
without the directional hook. This keeps both upgraded infantry aligned while
preserving the Blimp's existing reset behavior.

Pages are lazily cached per direction, shared across Knights. Eight RGBA8 pages
use approximately 80 MiB uncompressed, excluding sources/imports and overhead.
Lossless import preserves inked edges; PNG disk size is not GPU memory usage.
No minimum-spec swarm benchmark or streaming implementation is claimed.

## Rebuild and Verification

Run from the Godot project root with Godot 4.6.2:

```text
godot --headless --path . --editor --quit
godot --path . --rendering-method gl_compatibility --script tools/steel_force/bake_steel_knight.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/steel_force/verify_steel_knight.gd
godot --path . --rendering-method gl_compatibility --script tools/steel_force/preview_steel_knight.gd
godot --path . --script tools/steel_force/verify_steel_knight_ingame.gd
godot --headless --path . --script tools/steel_force/verify_mounted.gd
godot --headless --path . --script tools/steel_force/verify_steel.gd
godot --headless --path . --script tools/steel_force/verify_poorper.gd
```

Set ART_SHOT_DIR to an existing output directory for contact sheets and live
captures. On the restricted Windows host, redirect APPDATA/LOCALAPPDATA to a
writable test user directory. This is test setup, not a production dependency.

Checks cover every frame's bounds, alpha/key, nonblank content, animation
changes, distinct directions, retained stopped facing, hysteresis, camera yaw,
frame preservation, attack/hit selection, 2D/3D corpse anchors, real factory
spawning, path movement, damage, transport rejection and half-health dismount.
Live captures are at 1600x1000 and 1280x720. Inspect those and the contact sheet
manually before accepting an art revision.

Current test host can report certificate/shader-cache errors and existing
shutdown resource warnings. Require zero test failures and no script errors;
do not present these runs as a warning-free engine or exported-build QA.
