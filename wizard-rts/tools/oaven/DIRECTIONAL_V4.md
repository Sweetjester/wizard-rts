# Oaven / Jumper: Eight-Direction V4

## What Changed

Replaced the two mirrored views with distinct E, SE, S, SW, W, NW, N and NE
artwork for both forms. S faces the viewer; N shows the back. The same
camera-relative direction helper and optional Sprite3D synchronization hook
introduced for Mangler are reused without modifying other units.

No balance, pathfinding, research, targeting, population, evolution or flight
rules were redesigned. Live testing exposed a shared bug: the Spawner-only
flight updater reset non-Spawner flight states every tick. Its early return
now leaves other units' flight state alone, preserving Jumper temporary flight.
`oaven_unit_smoke_test.gd` includes a regression for this ownership bug.
The original procedural mass-unit fallback still exists.
Vault portraits were not changed by this directional animation task.

## Identity and Source Production

The supplied Oaven concept and `painted_v3/source_parts.png` anchor the design:
large rounded blue chitin head, broad blunt face, cyan eyes, small spines and
antennae, ragged charcoal tunic, muted red scarf/wraps, blue clawed hands/feet
and segmented tail. It is not a furry ratman. Jumper adds four dragonfly wings.
Rear views show the scarf knot, back of the head/tunic and wing roots.

Generated with the built-in `image_gen` tool, not a CLI/API fallback. Exact
accepted prompt texts are saved in `directional_prompts.json`. Generation order
was front, front-right, right profile, rear-right, back, rear-left, left profile,
front-left. Approved front and adjacent views were referenced to lock identity.
One rear-left attempt was rejected because most poses still faced right; only
the corrected rear-left sheet was installed. No horizontal mirroring is used.

Final sources are under `assets_game/units/kon/oaven/directional_v4/sources/`.
Each 1774x887 image has six columns and two rows. Top: Oaven. Bottom: Jumper.

| Column | Source pose |
| --- | --- |
| 0 | Idle with upright spear |
| 1 | Running contact A |
| 2 | Running contact B |
| 3 | Spear thrust |
| 4 | Blowpipe held to mouth |
| 5 | Collapsed corpse with fallen weapon |

Total: 96 painted key poses. Magenta is a deliberate offline extraction key,
not a runtime background. The final runtime textures have transparency.

## Extraction and Bake

`directional_puppet.gd` classifies the key background into a Godot BitMap and
uses `opaque_to_polygons` to find connected foreground outlines. Each outline
is assigned to the closest nominal source slot by its bounding-box center.
Small specks below 16 square pixels of bounding-box area are discarded.

This allows a spear tip or wing to cross a nominal column boundary without
clipping it. Detached fallen weapons are grouped with the corpse in their
slot. All poses must remain physically separated in the original painting:
touching figures can merge into one component. Center-based assignment can
also fail for unusually long detached parts. Inspect the rendered sheets;
passing bounds tests cannot prove anatomy or correct component ownership.

The existing chroma-key shader removes magenta inside the outlines. All poses
and both forms within one direction share a scale; each pose is bottom-centered
at authored coordinates (128,210). Do not fit every pose independently, which
would shrink bodies as weapons extend. The maximum height includes flight and
taunt headroom, verified against every baked frame.

The baker renders 512x512, then downsamples to 192x192 with Lanczos. Smaller
cells suit this infantry unit's screen footprint while reducing the cost of
15 animation rows. Texture filtering remains linear, not nearest-neighbor.

Outputs: 16 `{oaven|jumper}_{direction}.png` pages. Each is 1536x2880: eight
columns, 15 rows, 120 frames per page, 1,920 total playback frames.

| Row | Action | Source treatment |
| --- | --- | --- |
| 0 | idle | Small breathing motion |
| 1 | move | Alternating painted contacts and bob |
| 2 | attack_spear | Idle / thrust / recover; frame 3 is contact |
| 3 | attack_blowpipe | Dedicated mouth/weapon pose with recoil |
| 4 | hit | Recoil lean and compression |
| 5 | death | Initial compression, collapsed painting, runtime hold/fade |
| 6 | taunt | Emphatic body expansion/breathing |
| 7 | swap_weapon | Spear-to-blowpipe poses; reversed for returning to spear |
| 8 | charge | Faster/larger running presentation |
| 9 | takeoff | Crouch and lift into running-contact pose |
| 10 | flying | Lifted alternating contacts and bob |
| 11 | landing | Compression and recovery |
| 12 | evolve | Form transition presentation |
| 13 | idle_blowpipe | Breathing with blowpipe equipped |
| 14 | move_blowpipe | Stable mouth/weapon with lower-limb deformation and bob |

These are key-pose/cutout animations with baked transforms, not 1,920 unique
hand-drawn poses or a skeletal 3D model. Flight uses the winged source poses;
independent anatomically rigged wing flapping is not part of this pack. Fine
secondary scarf motion and additional contact in-betweens remain polish work.

## Runtime Contract

`oaven_painted_art.gd` retains the existing action selection and attack clock.
The eight-frame attack phase is offset by 0.42 cycles so contact is shown when
authoritative damage fires, rather than adding a second damage event.
Weapon swap uses the actual remaining swap time and plays backward when the
new mode is spear. Turning swaps pages without resetting the frame or clock.

Facing priority: attack target, nonzero velocity, remembered world heading.
The shared helper projects world heading onto the 3D camera's normalized
horizontal axes, or accounts for an active rotating Camera2D. Four degrees
of sector hysteresis suppress direction flicker near 45-degree boundaries.
Stopped units remember their world direction and still respond to camera yaw.

192px cell presentation preserves the previous canvas/world conversion:

- Sprite2D scale: 0.598 / 0.75; offset Y: -61.5.
- Sprite3D pixel size: 0.01014 / 0.75; foot anchor Y: 157.5.
- hframes: 8; vframes: 15; death row: 5.
- Death uses the current direction/form and frames 40..47, then 1.2s hold and
  0.7s fade. `oaven_death_sprite.gd` now derives indexing from hframes instead
  of hardcoding the old 12-frame sheet. The generic 3D corpse already does so.
- Corpse art keeps the direction captured at death if the camera later yaws,
  matching the existing corpse system. Living units update camera-relative art.

## Cost and Scope Limits

Pages are lazy-loaded into a shared static cache, not duplicated per actor.
Each uncompressed RGBA8 page is 16.875 MiB. All 16 are 270 MiB before engine
overhead; 256px cells with the same layout would cost 480 MiB. The old two
384px/12-column sheets were 202.5 MiB. Disk PNG compression is not GPU memory.
No source sheet or generation service is needed in gameplay.

First-use page loading can hitch; it is not asynchronously prewarmed. The
16-actor live test is not a mass-army/minimum-spec performance benchmark.
Profile cache residency and first-use latency before replicating this budget
across a full roster. Do not enable lossy texture compression without checking
cyan eyes, thin weapons and alpha edges at the actual gameplay zoom.

## Rebuild and Verification

Run from the Godot project root with Godot 4.6.2:

```text
godot --headless --path . --editor --quit
godot --path . --rendering-method gl_compatibility --script tools/oaven/bake_directional.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/oaven/verify_oaven_art.gd
godot --headless --path . --script scripts/core/oaven_unit_smoke_test.gd
godot --headless --path . --script scripts/core/kon_faction_mechanics_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script tools/oaven/preview_directional.gd
godot --path . --rendering-method gl_compatibility --script tools/oaven/verify_directional_ingame.gd
```

For a targeted rebake append `-- s sw` (or any accepted direction names).
Set `ART_SHOT_DIR` to an existing writable output folder for rendered tests.
Graphical baking/capture cannot run with the headless dummy renderer.
On this Windows test host APPDATA and LOCALAPPDATA are redirected to a writable
test directory to avoid host user-directory crashes; not a game requirement.

Require PASS markers, zero test failures and no script errors. Checks cover:
all 1,920 frames visible/in bounds; every action has pixel changes; distinct
form/direction art; facing and target priority; frame continuity; all action
rows; weapon contact timing; evolution/flight/hit; independent corpse lifetime;
gameplay regression; real movement and weapon switching; all eight stationary
camera yaws for both forms through Sprite3D; 1600x1000 and 1024x720 captures.

Manually inspect the contact sheets and live screenshots for anatomy, pose
ownership, feet, weapon tips, wings, readable silhouette and direction drift.
Test-time raw image-load warnings refer to the offline validator, not runtime
asset loading. Known certificate/renderer teardown warnings are separate from
functional assertions; do not hide script errors among those warnings.
