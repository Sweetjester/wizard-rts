# Poorper: Eight-Direction Upgrade

## Scope and Identity

The existing `poorper` scene now uses `poorper_directional_art.gd`. No new unit
ID, evolution, balance changes, transport rules or attack events were added.
The Knight and Proper Blimp retain their previous artwork. The existing vault
portrait is preserved: this task replaces battlefield facing and animation.

Keep the Steel Force silhouette: round iron head, oversized warm amber eyes,
ochre scarf, ragged charcoal clothing, leather pouches, short boots, dark feather
tuft and rough lamp-tipped cudgel. This is drawn, painted miniature art, not a
realistic metal render. Its broad head and scarf should read before small gear.

## Source Artwork

Built-in image_gen generated new directional key poses using the existing
`painted_v1/poorper_source.png` as the identity reference. Exact prompts,
including rejected-pass correction prompts, are in `poorper_prompts.json`.

Final sources live under `assets_game/units/steel_force/poorper/directional_v2/sources/`:

| Source | Top row | Bottom row |
| --- | --- | --- |
| e_w.png | Right profile E | Left profile W |
| s_se.png | Front S | Front-right SE |
| sw_nw.png | Front-left SW | Back-left NW |
| n_ne.png | Back N | Back-right NE |

Each row has five painted keys: idle, two stride contacts, melee attack, and
collapsed corpse. There are 40 primary painted poses, not 320 independent
paintings. Other frames are baked pose changes and small transforms.

The front generation initially had an opaque checkerboard and required a
magenta-background edit. Rear art has actual alpha; other sheets use chroma
key. Left views required a direction correction, and the west corpse needed
its orientation corrected. Inspect anatomical direction, not prompt labels.

`sw_corpse_fix.png` supplies ONLY the southwest corpse's extinguished eye.
That edit inadvertently also extinguished the attack eye, so the baker keeps
the original living poses. Do not replace the entire SW source with that file.

## Bake Contract

`poorper_puppet.gd` extracts connected foreground polygons, assigns them by
sheet row and column, and retains source alpha through the existing chroma-key
shader. Connected shapes may cross nominal grid gutters without being sliced.
Small detached noise below 20 square source pixels is excluded. Visual review
is still required; a foreground polygon test cannot understand anatomy.

One scale is selected per direction, shared by every pose. Idle target height
is 180 pixels, capped to fit the largest pose within 226x210 pixels. The foot
anchor is (128,220) in a 256x256 cell. Do not independently scale a collapsed
body up to standing height.

`bake_poorper.gd` renders 512x512 then downsamples to 256x256. Each of eight
direction pages is 2048x1280: eight columns and five action rows, 40 frames.

| Row | Animation | Treatment |
| --- | --- | --- |
| 0 | Idle | Restrained breathing |
| 1 | Walk | Two painted contacts with passing stance and small vertical bob |
| 2 | Attack | Painted strike and recovery, driven by attack_visual_age |
| 3 | Hit | Recoil/compression of the ready pose |
| 4 | Death | Brief collapse, painted corpse, existing hold/fade |

Attack art remains a visual response to immediate gameplay damage; it does
not apply damage. Rear keys use an overhead swing; other views use an extended
strike. This is economical key-pose animation, not skeletal animation or fully
hand-painted in-betweens. More bespoke stride contacts would be a future polish
pass, not grounds to claim a full skeletal rig exists now.

## Runtime Contract

- Direction order: E, SE, S, SW, W, NW, N, NE. No runtime horizontal mirroring.
- Uses shared `eight_direction_facing.gd`: 45-degree sectors with hysteresis.
- A live attack target supplies heading; otherwise velocity supplies heading.
- Stopping preserves the last world heading. Turning does not reset the frame.
- 3D camera yaw projects world heading onto camera-relative horizontal axes.
- Rotated Camera2D is handled when its rotation is enabled.
- Sprite2D scale .56, offset (0,-92), foot anchor 220.
- Sprite3D pixel size .009333333 preserves approximately the old unit size.
- Death row 4, 1.1 seconds, hold 2 seconds, existing fade .7 seconds.
- The Steel Force death helper no longer applies the old 384px anchor to Poorper.
- Corpses retain their captured direction; they do not repaint when orbiting
  the camera after death. This matches the existing eight-direction pipeline.
- Original scene/factory/transport ownership and gameplay logic are retained.

Pages are shared in a static lazy-load cache. Eight RGBA8 pages total about
80 MiB uncompressed, excluding imports/source images and overhead. Source
sheets are authoring inputs, not runtime dependencies. No minimum-spec swarm
benchmark or texture streaming system is implied by the functional tests.

## Rebuild and Checks

From the Godot project root (Godot 4.6.2):

```text
godot --headless --path . --editor --quit
godot --path . --rendering-method gl_compatibility --script tools/steel_force/bake_poorper.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/steel_force/verify_poorper.gd
godot --headless --path . --script tools/steel_force/verify_steel.gd
godot --path . --rendering-method gl_compatibility --script tools/steel_force/preview_poorper.gd
godot --path . --script tools/steel_force/verify_poorper_ingame.gd
```

Set ART_SHOT_DIR to an existing screenshot directory. Use a writable test
APPDATA/LOCALAPPDATA on the restricted Windows test host.

Acceptance covers every frame's transparency, bounds, nonblank content,
animation changes, eight distinct idle views, stopped facing, camera yaw,
frame preservation, attack/hit selection and 2D corpse metadata. The live
test checks the actual factory, path movement, all eight Sprite3D yaw/frame/
anchor combinations, real melee damage, transport boarding/unloading and
directional death, with 1600x1000 and 1280x720 captures.

Inspect the contact sheet and gameplay screenshots manually. Reject clipped
weapons, stray sprite fragments, opaque background, incorrect rear faces or
obvious size changes. Engine certificate/cache and existing shutdown resource
warnings may still appear; a successful test is not a warning-free engine.
