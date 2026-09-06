# Stone-Faced Serpent: eight-direction V3

Implemented September 6, 2026. This upgrades the mobile Serpent in the real
unit scene. It is not a standalone concept sheet or a new 3D model.

## Identity and deliverables

- Eight independently generated view sheets: E, SE, S, SW, W, NW, N, NE.
- Chunky turquoise stone, burgundy flexible joints, coral slit eyes, cyan
  black-veined neck fins and antennae. No legs or mammalian features.
- Base stage plus five evolutions: stages 1 through 6.
- Nine rows: idle, slither, poison bite, harden, stone hold, revert, grow,
  collapse/death, hit. Eight frames per row.
- 48 runtime pages, each 2048 x 2304 with 256 x 256 cells: 3,456 playback frames.
- Source parts, bake scripts, exact prompts, preview and automated tests retained.

## What was generated versus animated

The built-in image_gen tool generated eight 1774 x 887 source sheets. Each is
four columns by two rows: normal head, bite head, dead head, stone head; two
body chunks, tail, collapsed body chunk. Thus there are 64 painted source
parts, not 3,456 independently painted animation poses.

The initial E sheet references the existing V2 painted source. The other
seven sheets reference the accepted E sheet for consistency. Every exact
prompt and its reference are recorded in `directional_prompts.json`.
The prompts describe the existing Serpent design, not a new creature.

These source PNGs intentionally use a solid magenta extraction backdrop.
The runtime atlases have transparency. `directional_puppet.gd` extracts
connected silhouettes with BitMap outlines, assigns them by their center
to the eight slots, and uses the existing Oaven chroma-key shader during
rendering. This preserves antennae that cross nominal grid boundaries.
It checks every slot is populated. Do not crop these sources using a blind
uniform grid: some head outlines cross the halfway line.

The puppet animates connected parts with a traveling lateral wave, neck
breathing, bite extension, hit recoil and progressive collapse. Head art
switches to independently drawn bite/dead/stone poses. Components are sorted
by projected ground depth, so a rear-facing spine can obscure the neck and
an approaching head covers the body. The V2 poison and evolution effects
are reused. Effects are held as persistent textures throughout rendering.

S and SW source tail tips point the wrong way for their assembled spines;
the baker rotates those loose tail parts 180 degrees. It does not rotate
or mirror a side-profile head to fake front or rear views. The drawing style
is intentionally crisp and broad enough to read at normal RTS zoom.

## Head anchor and growth

Preserve this contract when changing either the baker or runtime:

```text
direction order = E, SE, S, SW, W, NW, N, NE
theta = direction_index * PI / 4
facing_projection = (cos(theta), sin(theta) * 0.6)
body_count = 3 + 2 * (stage - 1)
head_anchor = (128, 128) + facing_projection * body_count * 5.25
Sprite2D.offset = (128, 128) - head_anchor
foot_anchor_y = head_anchor.y
Sprite2D.scale = 1.152
billboard_pixel_size = 0.018
```

Baking uses a 512 x 512 viewport and downsamples to 256 x 256 with Lanczos.
The old puppet body spacing of 21 draw pixels and effective physical scale
are preserved. Longer stages add two body sections each; the head remains
the gameplay position. Bites extend the painted head without moving that
position. This is still a single unit with a decorative mobile tail, not
a chain of independent moving colliders.

`serpent_painted_art.gd` selects level, view and action. It shares the same
camera-relative facing helper as Mangler and Oaven, retains heading while
stationary, prioritizes an attack target over travel direction, and applies
the helper's boundary hysteresis. Changing pages preserves frame index.
There is no horizontal flip. Both rotating Camera2D and Map3DView are supported.

Map3DView already calls `sync_view_facing()` immediately before copying
art to its Sprite3D. It also copies the horizontal offset and computes
vertical placement from foot_anchor_y. Do not replace this with a fixed
foot location: long rear/front views have different pivots.

The death hook explicitly resolves facing before the independent corpse
captures its page, frame grid and anchor. Death is row 7, lasts 1.25 seconds,
holds for 2 seconds, then uses the existing corpse fade/cleanup.

## Memory and imports

Each runtime page has GPU compression enabled with high quality, alpha
border fixing, and no mipmaps. On this Windows Godot 4.6.2 installation the
importer produces BPTC/BC7 data. Tests verify imported images are compressed.

At 8 bits per texel, a page is 4.5 MiB and all 48 pages total 216 MiB of
texture payload, excluding resource/driver overhead. RGBA8 would be 864 MiB.
A shared lazy cache avoids re-reading a view whenever several units turn;
only requested pages are loaded, and instances share them. Source sheets
are not loaded by the mobile runtime. Other factions' caches are separate.
Validate platform-specific texture compression before targeting another GPU
or exporting to mobile/web; those targets were not tested in this upgrade.

## Preserved gameplay and wall form

No balance, poison, navigation or wall-placement rules are changed here.
Growth continues through the existing XP logic, increasing length and HP
while decreasing melee reach. Hardening hides the mobile billboard and uses
the existing separate wall segment visuals and tile blockers. The wall is
cardinal by design, with 90-degree bends, not an eight-direction mobile sprite.
Its V2 straight/bend/head/tail art and shared HP behavior are retained.
Reverting removes the blockers and brings back the matching stage/view.

The only gameplay-script edit is syncing facing before capturing death art.
All other runtime changes are confined to the Serpent presentation script.

## Rebuild

From the Godot project directory, using Godot 4.6.2 console:

```text
--headless --path . --editor --quit
--path . --rendering-method gl_compatibility --script tools/serpent/bake_directional.gd
--headless --path . --editor --quit
--headless --path . --script tools/serpent/configure_directional_imports.gd
--headless --path . --editor --quit
```

The baker needs graphical rendering; do not run it headless. Optional user
arguments restrict a rebuild, e.g. `-- s sw`. The import configuration tool
expects all 48 pages to exist with `.import` files. Always reimport after
configuring compression. Retain V2 source/effects/wall textures.

For captures, set ART_SHOT_DIR to an existing writable output directory:

```text
--path . --rendering-method gl_compatibility --script tools/serpent/preview_directional.gd
--path . --rendering-method gl_compatibility --script tools/serpent/verify_directional_ingame.gd
--path . --rendering-method gl_compatibility --script tools/serpent/verify_serpent_ingame.gd
```

This host needed APPDATA and LOCALAPPDATA redirected to the existing
workspace work/godot-user directory, as documented in the Oaven pipeline.
Do not launch hidden helper processes with visible terminal windows.

## Verification

```text
--headless --path . --script tools/serpent/verify_directional.gd
--headless --path . --script tools/serpent/verify_serpent.gd
--headless --path . --script scripts/core/stone_face_serpent_smoke_test.gd
--headless --path . --script scripts/core/evolution_stat_integrity_smoke_test.gd
```

Directional tests examine all 3,456 cells for visible content and safe bounds,
check motion in every non-hold row, unique stage/view pages, GPU compression,
all 48 runtime combinations, head-anchor agreement, camera rotation, target
priority, state transitions and corpse cleanup. The live directional fixture
uses the production factory and map, real movement, every camera yaw, all six
stage pivots, bite playback and a 3D corpse. It captures 1600 x 1000 and
1024 x 720 views. The separate live wall fixture verifies eight segments,
bending, selection-owner resolution and reversion.

Treat explicit PASS / failures=0 plus absence of script errors as success.
An exit code alone is insufficient. Existing certificate-store and renderer
teardown/resource-leak warnings are separate unresolved project issues.

### Results on this working tree

- PASS: directional asset/runtime checks, zero failures.
- PASS: Serpent mechanics fixture, zero failures.
- PASS: StoneFaceSerpentSmokeTest (positioning and targetable wall).
- PASS: live directional fixture and live wall fixture.
- PASS: rendered contact sheets, including the imported compressed textures.
- FAILED separately: EvolutionStatIntegritySmokeTest stops on the existing
  Horror research path: `Hardened Horrors should raise a Horror's max HP
  above the catalog 72, got 72`. It does not reach its later checks. That
  fixture and its Horror/research implementation were not modified here;
  do not report the complete cross-unit research suite as passing.

## Limits and follow-up boundaries

- The mobile body follows a baked slither and eight headings, not a runtime
  articulated trail around obstacles. Do not describe it as physical segment AI.
- Baked viewing elevation is fixed. Camera yaw works; arbitrary close-up
  pitch angles cannot reveal new surfaces from these 2D sprites.
- An already-spawned corpse retains its captured view if the camera rotates.
  That is the existing shared corpse behavior, not a full corpse turntable.
- The existing high-unit-count simplified visual fallback is unchanged.
- Card portraits, other units, balance and general HUD design are out of scope.
