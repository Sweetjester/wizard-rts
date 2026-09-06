# Mangler: Eight-Direction Production Contract

## Scope

Both Mangler and Winged Mangler now use eight separately illustrated views.
This replaces the mirrored side-facing presentation, not the gameplay unit.
Momentum thresholds, collision damage, evolution, leap targeting, damage and
cooldowns remain authoritative in the existing unit/controller code.

Directions are clockwise in screen space: E, SE, S, SW, W, NW, N, NE.
S looks toward the viewer; N shows the back. These are not eight rotations of
one flat painting. Each source includes the anatomy visible from that side.

This is still illustrated 2D animation on Godot's existing 2D/3D sprite path.
It is not a rigged 3D model or 1,152 independently drawn animation poses.

## Asset Inventory

`assets_game/units/kon/mangler/directional_v2/sources/` has eight PNGs, one per
direction. Each has five poses across and two forms down:

| Column | Painted pose |
| --- | --- |
| 0 | Grounded idle / knuckle stance |
| 1 | Running contact A |
| 2 | Running contact B |
| 3 | Raised fists / airborne smash |
| 4 | Collapsed corpse |

Row 0 is wingless. Row 1 has four dragonfly wings. Total: 80 source poses.
The eight images were generated from the existing Mangler identity, with the
front sheet establishing proportions and subsequent views using approved
front/side/rear views as references. They retain blue-gray armored plates,
long gorilla-like forearms, squat legs, insect facial anatomy, red spines,
cyan eye/chest accents and pale cyan wings. No fur or human clothing.

The images are keyed magenta, not ready-to-use transparent textures. Runtime
loads only the baked transparent pages, never these keyed source sheets.
Existing `painted_v1` assets and portrait are preserved.

## Reproducible Art Brief

For another direction, reference the approved front image plus the closest
approved side/back image. Explicitly request the anatomical view, not merely
a compass label. For example, NE means back-right three-quarter: back plates,
rear arm surfaces and wing roots dominate, with only the far edge of the face.
Do not paste a front-facing head on a rear-facing body.

Use this brief as a starting template, not as an exact historical prompt:

> Production sprite poses of the SAME Mangler: gorilla proportions, insect
> face, huge knuckle-walking forearms, short powerful legs, blue-gray carved
> chitin, restrained red spines and cyan highlights. Illustrated game art with
> strong dark contours and clear painted planes. Fixed elevated RTS camera.
> Render [explicit anatomical direction] consistently for every pose. Five
> columns: idle, run contact A, run contact B, raised-fists smash, collapsed
> death. First row wingless, second row the same creature with four dragonfly
> wings. Full body and all extremities inside each cell, ample empty gutters,
> identical identity and body scale. Flat pure magenta background, no ground,
> shadows, lettering, particles, frame borders or neighboring pose overlap.

Reject wrong-sided heads, front torsos in rear views, missing limbs, changing
wing counts, inconsistent body size, overlapping cells and illegible contacts.
Generated sheets do not obey grids precisely; inspect every source at full
resolution. The baker's authored gutters are required, not optional guesses.

## Bake

`tools/mangler/directional_puppet.gd` defines source gutters and extracts tight
foreground bounds. It draws each pose through the existing chroma-key shader.
The south and southwest evolved smash wings require different final gutters
from their base forms; those overrides prevent fragments in the corpse cell.

All poses and both forms within a direction share one scale. The scale fits
the largest pose and keeps the base idle near 178 pixels high. Do not fit each
pose independently: that makes the body shrink when arms or wings spread.
Each frame is bottom-anchored at (128, 220), with breathing, run bob, recoil,
crouch and landing compression applied about that point.

`bake_directional.gd` renders at 512x512 and downsamples to 256x256. It writes
16 pages named `{mangler|winged_mangler}_{direction}.png`, each 2048x2304:
eight frames per row, nine action rows, 72 frames per page, 1,152 total.

| Row | Runtime action | Treatment |
| --- | --- | --- |
| 0 | Idle | Small breathing cycle |
| 1 | Run | Two painted contacts plus bob; playback speeds up with momentum |
| 2 | Attack | Immediate impact compression, raised fists, recovery |
| 3 | Hit | Recoil lean / compression |
| 4 | Leap windup | Grounded crouch |
| 5 | Leap flight | Raised-fists pose, subtle flex; world lift comes from gameplay |
| 6 | Landing | Compression and recovery |
| 7 | Evolution | Timed form-change presentation |
| 8 | Death | Initial collapse, painted corpse, then runtime hold/fade |

The base form contains leap-compatible rows for a uniform atlas contract but
cannot cast leap. Wing motion is pose-based, not an independently rigged wing
flap simulation. Hand-drawn in-between contacts would be the next animation
polish step; do not describe these baked transformations as new painted poses.

Combat applies damage immediately in the existing code. The attack row is
timed to that contract; there is no new animation event that applies damage.

## Runtime Integration

`scripts/units/eight_direction_facing.gd` quantizes heading in 45-degree sectors
with four degrees of hysteresis beyond each half-sector boundary. This avoids
rapid page flipping at diagonal path boundaries. Zero movement retains the
last world heading instead of resetting to south.

`mangler_painted_art.gd` chooses heading in this priority:

1. Active leap direction.
2. Current attack target direction.
3. Nonzero movement velocity.
4. Last remembered world direction.

For 3D, simulation XY maps to world XZ. Heading is projected onto the camera's
horizontal right/toward axes, normalized before use so pitch does not distort
the sector widths. For 2D, an active rotating Camera2D is accounted for.

`Map3DView._sync_unit_sprites()` calls an optional `sync_view_facing()` hook
before copying an actor's texture/frame into its Sprite3D. Other units are
unchanged. Changing direction swaps a same-layout texture page without
resetting the animation clock or frame. `flip_h` remains false.

Runtime anchor contract:

- Sprite2D scale: 0.72. Local Y offset: -92.
- Sprite3D pixel size: 0.01125. Grounded foot anchor: 220.
- Leap lift adds `leap_height / scale.y` to the foot anchor, with the matching
  negative Sprite2D offset. This preserves the prior simulation-to-render scale.
- Momentum pips retain their earlier apparent size and placement.
- Death captures the current direction/form and resets airborne offsets before
  spawning the existing corpse effect. Corpse lifetime remains 1s animation,
  2s hold, 0.7s fade. A corpse keeps its captured page if the camera later yaws;
  living units update camera-relative facing. Free camera-orbit corpse art is
  not implemented by this change.

## Efficiency and Limits

Painting five key poses per form/direction and baking small transformations
keeps source production manageable while reusing the proven gameplay path.
Shared static texture caching loads each page once, not once per unit. Pages
are loaded on first use; no network or image-generation dependency exists at
runtime. First-use loading may hitch and has not been stress-profiled.

The default lossless imports preserve the painted edges. Each uncompressed
RGBA8 page is 18 MiB, or 288 MiB if all 16 are resident, excluding source/editor
resources and other engine overhead. PNG disk size is not GPU memory usage.
Before scaling this approach to an entire roster, profile VRAM and first-use
latency on the minimum-spec machine. Consider validated texture compression,
prewarming during loading, or fewer baked subframes; do not blindly copy this
budget to every unit. Source sheets are editor inputs, not runtime references.

## Rebuild and Acceptance

From the Godot project root, with Godot 4.6.2:

```text
godot --headless --path . --editor --quit
godot --path . --rendering-method gl_compatibility --script tools/mangler/bake_directional.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/mangler/verify_directional.gd
godot --headless --path . --script tools/mangler/verify_mangler.gd
godot --path . --rendering-method gl_compatibility --script tools/mangler/preview_directional.gd
godot --path . --rendering-method gl_compatibility --script tools/mangler/verify_mangler_ingame.gd
```

Set `ART_SHOT_DIR` to an existing writable capture folder for rendered tests.
Baking and visual tests require a real graphical renderer. On the current
Windows test host, a writable redirected APPDATA/LOCALAPPDATA is used for
Godot's test user directory. This is test setup, not a project requirement.

Require zero failures and no script errors, not just process exit zero:

- Direction tests: all sectors, camera yaw, stopped facing, jitter boundaries.
- Asset tests: all 16 pages, every frame nonblank/in bounds, every action has
  visible changes, all direction/form idle images distinct.
- Runtime tests: page selection without mirroring, preserved frame on turning,
  running, immediate attack, hit, evolution, leap phases and grounded death.
- Gameplay regression: momentum, collision consumption, enemy-only splash,
  evolution stats, leap validation/cooldown, landing, interruption and corpse.
- Live map: actual factory, pathing, stacks, selection, manual leap and landing;
  both forms through the real Sprite3D bridge at all eight camera yaws.
- Visual review: inspect the idle/run/attack/airborne contact sheets and actual
  game captures at 1600x1000 and 1024x720. Check stray source fragments manually:
  nonblank/bounds tests cannot tell a valid wing tip from a neighboring fragment.

Retain the source images, authored gutters, baker and tests together. Do not
replace a bad direction with a mirrored shortcut and still label it complete.
