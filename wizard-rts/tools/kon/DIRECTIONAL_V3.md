# Kon: Eight-Directional Painted Hero

Implemented 2026-09-06. This supersedes the two-facing character artwork in the
original Kon overhaul. It does not replace the hero's gameplay implementation.

## Live Integration

`scenes/wizard.tscn` still selects `scripts/units/kon_painted_art.gd` for Bad Kon
Willow. Other wizard classes keep their existing presentation. There is no new
hero registration, duplicate live hero, mesh rig, collision shape or balance edit.

The driver selects eight genuinely different painted pages, clockwise:
`e, se, s, sw, w, nw, n, ne`. It never mirrors them with `flip_h`. Movement and a
valid live attack target determine world heading; stopping retains that heading.
The shared `eight_direction_facing.gd` supplies camera-relative projection and
sector hysteresis. Camera orbit changes the page without rotating Kon in world
space. Stationary observation and casting preserve world heading. Successful
Seal Away/Biostorm casts explicitly face their target; rejected casts do not.
Freed attack targets are checked before their properties are accessed.

Both 2D and the production Sprite3D renderer use these pages. The 3D renderer
already calls `sync_view_facing`, copies animation frames, and respects foot
anchors and death metadata. No shared renderer modification was required.

## Art Contract

Young, gaunt, pale blue-grey face; black hair; ragged teal hood, wraps and cloak;
cyan eyes; red mushroom shoulder growth; long and short broken wooden staff
pieces. Inked contours and painted material shapes, not photorealistic rendering.
Front, back, side and diagonal silhouettes were generated separately. This is
painted pose animation, not a fully articulated skeletal or 3D model. Small
hand/cloth/prop inconsistencies between generated views remain possible.

Original references:

- `art/concept/kon/life_wizard_concept.png`
- `assets_game/units/kon/hero/painted_v2/source.png`

The old assets are retained. The original spell effects atlas at
`assets_game/units/kon/hero/painted_v2/spells.png` remains in use.

## Saved Sources and Runtime Assets

Root: `assets_game/units/kon/hero/directional_v3/`.

- `sources/{direction}.png`: eight native 1254x1254 generated 3x3 pose sheets.
- `kon_{direction}.png`: eight transparent 4608x3072 runtime animation pages.
- Each runtime page is 12 columns by 8 rows, with fixed 384x384 cells.
- 72 generated painted key poses produce 768 runtime frames through pose
  selection and authored transforms. These are NOT 768 hand-painted drawings.
- Runtime output dimensions describe atlas packing, not native generation detail.
  Supersampling improves edge sampling; it does not invent additional painted detail.

`tools/kon/directional_prompts.json` records the full image-generation prompts,
references, accepted generation paths, source pose order and rejected SW attempt.
The accepted images have been copied into the project, so rebaking does not
depend on the temporary generation folder. A fresh generation is not guaranteed
to reproduce identical pixels: use the saved sources for deterministic rebakes.

Source cells, row-major: idle, left stride, right stride, long-branch attack,
short-branch attack, Seal Away, Observation, Biostorm, death. Approved front/back
and side sheets were reused as references for subsequent angles. SW was rejected
and regenerated when the original result did not read as the requested view.

## Bake and Animation

`directional_puppet.gd` extracts connected silhouettes from the magenta source.
Component ownership uses source-grid position, preserving branches crossing
nominal cell gutters. Tiny detached marks below a pose are discarded so spell
particles in the next source row do not leak into attack frames. Substantial
branches and nearby casting sparks are retained.

Each direction uses one source scale across its poses. Foot-derived anchors
prevent centring the body on an extended weapon; bounds-aware horizontal
clamping gives staff tips enough padding. The death pose has its own anchor.
The baker renders at 2x tile size, then downsamples to 384px with Lanczos.

| Runtime row | Action | Playback |
| --- | --- | --- |
| 0 | Idle | Subtle breathing loop. |
| 1 | Move | Left/right stride key poses with low-amplitude bob. |
| 2 | Broken Staff | Distinct long/short branch strikes within the existing 0.75s attack. Gameplay impacts remain 0.12s and 0.36s. |
| 3 | Seal Away | Target-facing casting pose; existing one-second animation request. |
| 4 | Observation Aura | Planted, quiet breathing pose; no floating gait. |
| 5 | Biostorm | Separate storm-casting pose; existing effects and timings. |
| 6 | Hit | Short recoil derived from idle, not an extra painted key pose. |
| 7 | Death | Collapse into the directional death pose; production corpse renderer. |

Preserved display contract: 2D scale `0.43`, offset `(0,-138)`, foot anchor
`330`, Sprite3D pixel size `0.009`, 1.25-second death, 2.5-second corpse hold.
`preserve_painted_palette` prevents the existing owner tint from washing out
the authored palette. Health, damage, spell costs, cooldowns, movement speed,
tower observation rules and hit/attack timings are unchanged.

## Import and Memory

Runtime textures use lossless import, no mipmaps or size limit, and linear
sampling. Do not apply lossy colour compression or independently resize cells
without checking thin staff edges, cyan effects and frame/anchor metadata.

Pages are loaded on demand and shared through a static cache, following the
existing directional-unit pattern. The cache retains loaded pages. Eight
4608x3072 RGBA8 pages can occupy about **432 MiB uncompressed**, before other
assets and engine overhead; PNG disk size is not GPU memory consumption.
This is a quality-first hero asset, not a completed memory optimisation. Profile
target hardware before shipping; atlas compaction or platform compression needs
its own visual checks and renderer metadata changes. Mobile/export performance
and first-use texture-upload latency have not been benchmarked here.

## Reproduce

Run from the Godot project folder. `godot` below means the installed Godot 4.6.2
executable. Set `ART_SHOT_DIR` to an existing writable output directory for images.

```powershell
godot --path . --script tools/kon/bake_directional.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/kon/verify_directional.gd
godot --headless --path . --script tools/kon/verify_kon.gd
godot --path . --script tools/kon/preview_directional.gd
godot --path . --script tools/kon/verify_directional_ingame.gd
```

The bake and asset verifier read raw PNGs offline. Their export warnings do not
describe runtime loading: the actual hero loads imported Texture2D resources.
Do not run the old `bake_kon.gd` expecting it to update the new directional pages.

## Verification and Boundaries

- `verify_directional.gd`: all eight pages, 768 nonempty/padded frames, alpha,
  chroma rejection, row variation, distinct strikes, consistent idle height,
  eight movement headings, retained idle heading, ability rows, explicit cast
  facing, freed target safety, camera rotation and sector hysteresis.
- `verify_kon.gd`: existing gameplay regression tests passed, including separate
  staff impacts, five-second banishment, friendly-fire storm, observation and
  rotated/owned tower crown conditions, summon range and death. Its historical
  atlas scan still targets painted_v2; the new verifier covers directional_v3.
- `verify_directional_ingame.gd`: actual main-map scene in Build Sandbox, eight
  actors/headings and eight camera yaws, imported textures, frame synchronisation,
  palette, foot placement, fixed observation world heading, banish concealment,
  spatial Biostorm effects and the production directional corpse renderer.
  Graphical Forward+/D3D12 run exited 0 on RTX 5080; 1600x1000 and 1024x720
  screenshots were captured. The harness calls the corpse renderer directly to
  avoid ending the match; actual hero death is exercised by the gameplay test.
- `preview_directional.gd`: Godot-rendered contact sheets for every action, not
  an AI-generated mockup. Inspect these AND the in-game scale before approval.

The older `verify_kon_3d.gd` inherits the broad map smoke test. That parent still
expects mirrored Oaven sprites and fails before its Kon checks. The independent
directional in-game verifier avoids that unrelated obsolete assertion; it does
not mean the entire shared map test suite passes. The legacy run also crashed
during shutdown. No Oaven or shared test expectations were changed in this task.

Godot reported certificate-store/shader-cache directory errors and resource/RID
leak warnings at shutdown, including in the successful focused graphical run.
Do not describe these runs as warning-free or the leaks as proven engine bugs.
No standalone game export or full-match performance soak was run.

## Future Changes

Keep the source pose order, direction names and runtime row indices stable.
Rebake all affected pages, import, run both asset and gameplay checks, then
inspect actual 2D and 3D output. Never substitute mirrored art for back/diagonal
views, change world scale to compensate for inconsistent source framing, or
move damage logic into the animation baker. Preserve the existing stale-target
guard and avoid turning Kon when the player merely orbits the camera.
