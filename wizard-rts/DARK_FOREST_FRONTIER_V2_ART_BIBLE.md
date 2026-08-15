# Dark Forest Frontier V2 — Art Bible for AI-Generated Assets

This is the single reference every `props/specs/*.yaml` prompt (and any future terrain/texture
generation) must be checked against before it's written. `STYLE_BIBLE.md` still governs the whole
game (units, buildings, general readability rules); this document is narrower and more concrete —
it exists because the pipeline had no locked palette or prompt discipline, and it showed: two
different asset generations in the same biome can currently look like they're from different games.

`tools/prop_pipeline/style_profiles/dark_forest_frontier_v2_props.json` is the machine-readable
half of this — its `material_palette` and `meshy_guidance` should stay in sync with what's written
here. If they ever disagree, this file wins; fix the JSON.

## Canonical reference art

Everything below is grounded in real reference images, not invented. All are checked into
`art/concepts/dark_forest_frontier_v2/reference/`:

**Low-ground / "black-ink forest" set** (generated 2026-08-10, most recent pass):
- `hellfirebaby_isometric_game_tile_dark_cramped_forest_floor_da_fb9648a3...png`
- `hellfirebaby_isometric_game_tile_dark_cramped_forest_floor_da_f8e04582...png`
- `hellfirebaby_isometric_game_tile_dark_cramped_forest_floor_da_2bf72f9b...png`
- `hellfirebaby_isometric_game_tile_impenetrable_wall_of_dark_tw_e5533439...png`
- `hellfirebaby_seamless_tileable_texture_top-down_dark_damp_for_a2d5b4cc...png` (source of the
  current ground albedo texture — see `tools/prop_pipeline/process_ground_texture.py`)

**High-ground / "glowing glass mushroom" set** (generated 2026-04-19, an earlier and visibly
different pass — see "Two deliberate tiers" below for why this isn't a mistake):
- `hellfirebaby_isometric_game_tile_elevated_forest_plateau_with_39c2bebe...png`
- `hellfirebaby_isometric_game_tile_open_elevated_forest_plateau_ebc36ef7...png`
- `hellfirebaby_isometric_game_tile_raised_forest_terrain_mossy__f25aa38e...png`

## Two deliberate tiers, not accidental drift

These two reference sets are stylistically quite different — muted ink-painted black bark with
sparse accent dots vs. saturated glass/crystal mushroom caps with teal pine trees. That's real
concept-art drift across two separate generation sessions eight months apart, and it's very likely
part of why the current map reads as inconsistent (Andrew's own assessment, 2026-08-11).

**Decision (2026-08-11, confirmed with Andrew): treat this as an intentional two-tier split by
elevation, not a mistake to resolve toward one direction.**

- **Low ground = the dark-ink tier.** Oppressive, muted, near-black. This is where the player
  spends most of their time and where most blockers/props live.
- **High ground / plateaus = the glowing-glass tier.** Brighter, more saturated, more overtly
  magical. Reinforces `STYLE_BIBLE.md`'s existing (previously unimplemented) rule: "High ground
  should be visibly separated from low ground."

This gives elevation a second, atmospheric readability channel beyond height alone — low ground
feels grounded and hostile, high ground feels elevated and touched by something stranger. That's a
stronger creative reason to keep both than to force one tier to "win."

**Known debt against this decision**: everything built through 2026-08-11 (today's ground texture,
all 10 new props) was built entirely from the dark-ink set. `HIGH_GROUND_TILE`'s texture is just a
brightness-tinted copy of the *low-ground* texture, not a real glass-mushroom-tier asset. That's
the top of the follow-up list, not something this pass fixed.

## Palette correction — 2026-08-12

Andrew's review of the first batch: workable pipeline, but wrong style entirely. Two corrections,
both now applied in `tools/prop_pipeline/style_profiles/dark_forest_frontier_v2_props.json`:

1. **"Vampiric forest, full of life, sinister red — not a desaturated dead one."** The palette
   below was always dark, but leaned too far toward muted/near-black with only sparse accent dots.
   Living green (moss, fern, undergrowth) should be a dominant, generous color, not a rare accent —
   and the recurring accent color across the whole low-ground tier is now **blood red**, not
   magenta/pink. Magenta is dropped entirely; cyan remains the one exception, reserved for
   KON-owned assets only, so it stays meaningful by contrast.
2. **A real bug, not just a direction problem.** `ensure_materials()` in `blender_process_prop.py`
   only ever assigned the curated palette to mesh geometry when `discard_imported_materials` was
   `true`. It was `false` the whole first batch — meaning every generated asset kept Meshy's raw
   PBR texture untouched and the palette below was **never actually applied to anything**. That's
   the real explanation for the flat grey-blue look in the first map screenshot, not just "needs
   more painterly polish." Flipped to `true`. Also raised `outline_scale` from `1.03` to `1.05` —
   the DD2 ink line needs to be the primary source of silhouette definition now that fill colors
   are flat, and `1.03` read as too thin at RTS camera distance.

One more real gap found while testing the fix: the keyword-based material-assignment rules
(`assignment_rules` in the style profile) had **no mushroom-related keywords at all** — every
mushroom category was silently falling through to the plain grey `stone` fallback, the single
worst possible result for the most vampiric-forest-defining asset type in the whole biome. Added
`mushroom`, `fungal`, `fungus`, `toadstool`, `glowing`, `spore` to `accent_corrupted_keywords`.
Also had to tune emission strength down (1.4 → 0.75 for `accent_corrupted`) after the first
re-test rendered as bright coral-pink rather than deep sinister red — Blender EEVEE's `Standard`
view transform doesn't roll off emission highlights the way `Filmic` would, so the raw hex value
alone doesn't predict the rendered brightness; always check a real render, not just the hex.

All 13 assets from the first batch were reprocessed through Blender with the corrected profile
(`tools/prop_pipeline/reprocess_batch.sh`, `--skip-meshy` — no new Meshy spend) rather than
regenerated from scratch, since the underlying meshes were fine; only material assignment was
broken.

## Locked palette

### Low-ground tier (dark-ink forest, full of life)

Sourced from the dark-ink reference set and `tools/prop_pipeline/style_profiles/dark_forest_frontier_v2_props.json`'s material_palette (kept in sync — this table should always match the JSON):

| Role | Hex | Notes |
| --- | --- | --- |
| Abyss / black bark | `#0A1612` – `#120F0D` | Darkest value in the scene — trunk cores, deep shadow, primary silhouette color |
| Wet bark | `#161311` – `#332820` | Primary trunk/root material, near-black with a hint of warmth |
| Damp floor | `#142420` | Base ground value |
| Forest floor green | `#1E3A2D` | Ground midtone |
| **Moss / living green** | `#3E7A46` | **Vivid, not desaturated — the primary "full of life" color. Use generously, not as a rare accent.** |
| Fern / spore accent | `#4A8A5C` – `#7BC47F` | Small live-plant highlights on top of the moss base |
| Old bone | `#5C5648` – `#8A7560` | Bone/ruin material |
| Bone highlight | `#D6C7AE` | Bone specular only, never a fill color |
| **Sinister blood red (ambient)** | `#4A0E14` base / `#8B1A1F` emission | The recurring vampiric accent — mushrooms, corruption, content-coded assets. Deep and brooding, not bright — keep emission strength low (~0.75), a hex value alone reads brighter once lit than it looks on paper. |
| **Sinister blood red (hostile)** | `#3A1210` base / `#C13030` emission | Same red family, hotter/brighter — outposts, danger, hostile-coded only. Distinguished from the ambient red by intensity, not hue. |

### High-ground tier (glowing-glass mushroom) — new, not yet built

Sampled directly from the reference images (see method note below — these are measured pixel
values from the actual concept art, not guesses):

| Role | Hex | Notes |
| --- | --- | --- |
| Glass mushroom cap body | `#902040` – `#C03050` | The saturated magenta-red glass material itself |
| Glass mushroom glow bloom | `#F0C0D0` – `#F0E0E0` | Near-white pink highlight/specular, use only as small hot spots |
| Teal pine foliage | `#306070` – `#5090A0` | Distinctly cooler and more saturated than any low-ground green |
| Plateau stone / cobblestone | `#2E3A45` – `#4A5560` | Cool blue-grey, paler and cooler than low-ground stone |

*(Method: bucketed pixel sampling of the 3 high-ground reference images, filtered to
high-saturation/high-value pixels for the accent rows and low-saturation/mid-value pixels for the
stone row. Re-run the sampling script in
`tools/prop_pipeline/process_ground_texture.py`'s spirit if the reference set changes.)*

### Cross-tier gameplay accent language (applies on top of either tier)

This is a **second, independent color axis** — ownership/threat semantics, not elevation. Do not
conflate the two. A high-ground base marker is still cyan; it just sits on brighter surroundings.

**As of 2026-08-12 this is a two-color system, not three** — magenta/pink is retired. Everything
that isn't KON-owned reads as some intensity of red; that's the whole point of "sinister red" as
the biome's signature.

- **Cyan** (`#1A6D72` base / `#34D9E8` emission) — reserved for `BASE_PLOT_MARKER` and other
  KON-owned/base-adjacent assets only. Never use generically. The *only* non-red accent in the
  entire biome, which is what makes it read as meaningful when the player sees it.
- **Blood red, ambient** (`#4A0E14` base / `#8B1A1F` emission) — the default vampiric accent.
  Mushrooms, corruption, content-plots, anything sinister-but-not-actively-hostile. Keep emission
  strength low (~0.75) — this should brood, not glow like a warning light.
- **Blood red, hostile** (`#3A1210` base / `#C13030` emission) — same family, hotter and brighter.
  Outpost markers, enemy structures, active danger. The intensity difference from the ambient red
  *is* the signal — don't reach for a different hue to mark "more dangerous."

## Silhouette & volume rules (the lesson from today's batch)

Two of the ten props generated in the 2026-08-11 pass came out visibly weaker than the rest:
`ancient_tree_hero_b` (doesn't read as a tree — collapsed into a flat sprawling blob) and
`twisted_root_blocker_b` (reads as ground debris, not a rising blocker mass). Both were Image-to-3D
outputs cropped from **wide, sprawling concept-art compositions** (a full trunk+canopy+roots frame
spanning ~500×660px at an angle). `root_wall_hero_b`, cropped from a more **compact, wedge-shaped**
region of the same source image, came out solid.

**Rule: for Image-to-3D specifically, crop concept art to a compact, roughly-square, frontal mass
— not a wide scenic slice.** Meshy's image-to-3D reconstructs depth from a single 2D image; a wide
composition with elements spread left-to-right gets reconstructed as a shallow relief, not a
rounded volume. If the source concept art you want to use is a wide scene, either:
- crop tightly to just the densest sub-cluster (what worked for `root_wall_hero_b`), or
- fall back to text-to-3d with a written silhouette description instead of forcing a bad crop.

This is in addition to the existing `ASSET_SCALE_GUIDE.md` rules (blockers must communicate blocked
movement, avoid long thin protrusions unless role-defining, clusters should use chunky forms).

## Prompt template (use this scaffold for every new spec)

```text
[SUBJECT], stylized vampiric dark fantasy RTS terrain prop, Darkest-Dungeon-2-like painterly
inked rendering, bold black ink outline, strong readable silhouette, chunky shapes, matte
[MATERIAL WORDS from the locked palette table above — lean on living moss/fern green, this
forest is full of life, not dead], [AT MOST ONE] controlled [cyan, KON-owned only / sinister
blood red — never magenta or pink] bioluminescent or ember accent, orthographic top-down game
asset reference, high contrast shadows, no photorealism
```

Negative prompt (always include, don't rewrite per-asset):

```text
photorealistic, glossy plastic, noisy AI texture, tiny surface detail, soft low-contrast
silhouette, desaturated dead colors, magenta, pink, purple, bright cheerful colors, modern
materials, sci-fi, UI, text, watermark, realistic photo-scan look
```

Every `visual.prompt` in a spec should read as this template filled in, not a freehand
description — that consistency in the *words* is most of what keeps the *output* consistent.

## Generator selection

- **`text_to_3d`**: default for anything without a strong, isolatable concept-art crop. Cheaper,
  faster, and safer for filler/variety-pass assets (rocks, generic mushroom clusters, dead spikes).
- **`image_to_3d`**: reserve for genuine landmark/hero pieces where the concept art has a real
  compact subject to crop (see Silhouette & Volume Rules above). Don't reach for it just because
  concept art exists somewhere in the scene — a bad crop produces a worse result than a good text
  prompt would have.

## Animation direction (documented now, not implemented)

Andrew's stated direction: environmental animation (wind-sway on trees/foliage) and the
high-ground tier's glass mushrooms are an obvious candidate for a slow emissive glow pulse. Neither
exists yet — `README_PROP_PIPELINE.md` is explicit that "Props are static assets... no rig or
animation needed," and that's still true as of this bible. Recording the intent here so future
prompts/models aren't authored in a way that fights it later:

- Trees generated for wind-sway will eventually need a simple bone chain (trunk base → mid → top)
  rather than a single rigid mesh — something to keep in mind if/when the Blender processing step
  (`tools/prop_pipeline/blender_process_prop.py`) grows animation support. Not a prompt-time
  concern today.
- Glow-pulse on emissive materials can likely be done in Godot shader/material space (animate
  `emission_energy_multiplier`) without touching the mesh at all — lower-effort, probably the right
  first animation feature to actually ship.
- This section should move to its own status doc once animation work actually starts; it stays
  here only as a placeholder so the intent isn't lost.

## QA checklist before promoting a new asset

1. Prompt was built from the template above, not written freehand.
2. Palette matches its tier (low-ground dark-ink vs high-ground glass) — check against the hex
   tables, not by eye.
3. Any emissive accent follows the ownership/threat rule (cyan for KON-owned, red for everything
   else — no magenta), or has none.
4. Silhouette AND color read correctly for its role in an actual render — check the Asset Forge
   gallery (`asset-forge`'s Asset Gallery tab, synced via `scripts/sync_gallery.py`), not just "did
   Meshy return a mesh without erroring." A hex value on paper is not what it looks like lit and
   emissive in Blender — always check the real render (this bit us on 2026-08-12: `#8B1A1F`
   emission at strength 1.4 rendered as bright coral-pink, not the intended deep blood red).
5. If a category has no visual result in the gallery, check `assignment_rules` actually has a
   keyword that matches the category/prop_id — the keyword-matching fallback is `stone` (flat
   grey), the single least-vampiric result possible, and it fails silently.
6. If generated via image_to_3d, the source crop was compact/frontal, not a wide scenic slice.
7. Category placement matches `CATEGORY_RUNTIME_FOLDER` in `create_prop.py` (trees/roots/
   mushrooms/rocks/ruins/decor/plot_markers) — don't let a new category silently fall to `misc/`.

## Renderer contract (scanned 2026-08-12, don't guess this again)

Andrew's direction after the full-coverage pass still "looked messed up": stop iterating blind
on individual Meshy assets and go read `scripts/map/map_3d_renderer.gd` directly to see how the
map actually places things. Real findings, not assumptions:

- **Magenta was never an asset-palette problem.** `_add_magenta_glow()` (now
  `_add_corruption_glow()`) spawns a hardcoded-color `OmniLight3D` at runtime for every
  `MUSHROOM_CLUSTER_SMALL/LARGE`, `MUSHROOM_BLOCKER`, `GLOWING_MUSHROOM_RING`,
  `CORRUPTED_ALTAR`, `RUINED_SHRINE`, `SHRINE_PROP` instance — completely independent of
  the asset's own material color. This is why magenta kept showing up on every map
  screenshot no matter how the material_palette was corrected. Fixed to `#C13030` (matches
  `accent_hostile`). Same for `_add_torch_glow()` (`#FF9A42` → `#D9502A`) and the
  `structure_rune` material. **If a color looks wrong in-game but right in the Asset Forge
  gallery, check for a hardcoded runtime light/material in the renderer before touching the
  Meshy pipeline again.**
- **`RAMP_MESH` is a dead asset-pack category.** `_add_ramps()` always builds ramp geometry
  procedurally via `_embedded_ramp_mesh_for_cell()` and never references `CAT_RAMP_MESH` or
  `_try_add_category_scene` at all. Don't spend Meshy credit generating ramp props — they
  cannot render in-game regardless of quality, this isn't a prompt/style problem.
- **`CLIFF_SIDE`/`CLIFF_CORNER` are sparse decoration, not the structural wall.**
  `_add_biome_cliff_edges()` places them on roughly 1-in-3 edge cells
  (`_hash_cell(cell, 77) % 3 != 0`), layered on top of the solid procedural `HighPlateaus`
  box-mesh wall (`HIGH_HEIGHT = 1.0`). A chunky rock/root/moss formation reads better here
  than a flat wall panel — don't chase "wall geometry" for these two categories.
- **Terrain scale contract**: `TILE_SIZE = 1.0`, `LOW_HEIGHT = 0.0`, `HIGH_HEIGHT = 1.0`,
  ground box meshes are `0.98 × thickness × 0.98` (thin slab for low ground, full 1.0-tall
  block for high plateaus). Any prop meant to sit convincingly on a tile should be sized
  against this, not guessed from the asset alone.
- **Biome fog/ambient genuinely mutes color at distance** —
  `fog_density = 0.011`, `fog_light_color = #233A34`, `ambient_light_color = #4A6358`,
  `ambient_light_energy = 0.58` (`_create_light()`). Confirmed by reading the values
  directly, not guessed. Untouched so far — the next lever if the map still reads too muted
  after the lighting-color fix above.

## Known deviations from this bible (as of 2026-08-12, updated after the full-coverage pass)

- **Resolved same day.** Every one of the 33 categories in the asset pack now has exactly one
  registered asset, and for every prop/terrain-GLB category that asset is new-pipeline —
  `tools/prop_pipeline/purge_procedural_assets.py` removed all 35 remaining entries sourced from
  `tools/blender/create_dark_forest_v2_assets.py`. A live map screenshot after this confirms real
  structural change (new silhouettes replacing the old blob clusters), not just individually
  correct assets sitting unused. The 4 material-based ground/road/water tile categories don't use
  GLBs and were checked separately — road and water were never off-palette to begin with.
- **New open item, found via the full-coverage screenshot**: at actual map-wide zoom the
  blood-red/living-green palette reads more muted than in close-up asset renders. Likely cause is
  the existing cool moonlit fog/ambient lighting (`godot_expectations.lighting` above) diluting
  saturation at distance — a lighting/fog tuning question, not an asset-palette problem. Next
  candidate lever if the map still doesn't feel vivid enough once viewed in-game at real zoom.
- Every category now has exactly 1 variant, no more — this isn't a regression from the purge
  (nothing generated earlier was lost; `purge_procedural_assets.py` only ever removes entries with
  no matching `props/specs/*.yaml`, and every asset generated by this pipeline has one), it's just
  that no category has ever had more than one new-pipeline spec written for it yet. Every placed
  instance of e.g. `ROCK_MOSS_CLUSTER` across the whole map is now the exact same mesh. Worth a
  real variety pass (2-3 variants per high-frequency category) once the palette/style is confirmed
  final — no sense adding variants before the base look is settled.
- `ancient_tree_hero_b` and `twisted_root_blocker_b` still don't meet the silhouette rule from
  earlier — the 2026-08-12 pass fixed material/color, not the underlying mesh shape issue. Worth
  regenerating with tighter crops before they're relied on further — they're currently the two
  most frequently *placed* categories on the live map (`ANCIENT_TREE_BLOCKER` and
  `TWISTED_ROOT_BLOCKER`), so their weakness is disproportionately visible.
- The high-ground tier described here doesn't exist in the game yet. `HIGH_GROUND_TILE` is a
  tinted copy of the low-ground texture; no prop has been generated against the glass-mushroom
  palette. This is the largest visible gap between this bible and the live map.
- Only 10 of ~30+ categories have been touched by the concept-driven/variety pass — the map is
  still mostly the original procedural-script assets from before this pipeline existed (Andrew's
  own observation, confirmed against the live prop-count log: e.g. `ROCK_MOSS_CLUSTER` alone
  places 2,391 times on one map, only some of which are the new variant).
