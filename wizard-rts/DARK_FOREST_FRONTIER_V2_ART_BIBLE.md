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

## Locked palette

### Low-ground tier (dark-ink forest)

Sourced from the dark-ink reference set and `tools/prop_pipeline/style_profiles/dark_forest_frontier_v2_props.json`'s existing material_palette (they agree; this is not a new palette, it's the confirmed one):

| Role | Hex | Notes |
| --- | --- | --- |
| Abyss / black bark | `#0A1612` | Darkest value in the scene — trunk cores, deep shadow |
| Wet bark | `#161311` – `#332820` | Primary trunk/root material, near-black with a hint of warmth |
| Damp floor | `#142420` | Base ground value |
| Forest floor green | `#1E3A2D` | Ground midtone |
| Moss green | `#2D5A3E` – `#3F5A3C` | Moss patches on bark/stone |
| Fern / spore accent | `#4A8A5C` – `#7BC47F` | Small live-plant highlights, used sparingly |
| Old bone | `#5C5648` – `#8A7560` | Bone/ruin material |
| Bone highlight | `#D6C7AE` | Bone specular only, never a fill color |

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

- **Cyan** (`#1A6D72` base / `#34D9E8` emission) — reserved for `BASE_PLOT_MARKER` and other
  KON-owned/base-adjacent assets only. Never use generically.
- **Magenta/pink** (`#6B1A55` base / `#F23FB0` emission) — the biome's corruption/mystery accent.
  Content plots, corrupted features, the low-ground tier's ambient accent dots.
- **Dull red/ember** (`#3A1210` base / `#B23A2C` emission) — hostile/Deom-coded only (outpost
  markers, enemy structures).

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
[SUBJECT], stylized dark fantasy RTS terrain prop, Darkest-Dungeon-2-like painterly inked
rendering, strong black silhouette, chunky readable shapes, matte [MATERIAL WORDS from the
locked palette table above], [AT MOST ONE] controlled [cyan/magenta/red — pick per the
gameplay accent rules, or omit for a fully neutral prop] bioluminescent or ember accent,
orthographic top-down game asset reference, high contrast shadows, no photorealism
```

Negative prompt (always include, don't rewrite per-asset):

```text
photorealistic, glossy plastic, noisy AI texture, tiny surface detail, soft low-contrast
silhouette, bright cheerful colors, modern materials, sci-fi, UI, text, watermark, realistic
photo-scan look
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
3. Any emissive accent follows the ownership/threat rule (cyan/magenta/red), or has none.
4. Silhouette reads correctly for its role at a glance in the rendered thumbnail (compare against
   `tools/prop_pipeline/blender_process_prop.py`'s output, e.g. via the Bell gallery at
   `~/bell/emit_gallery_html.py`) — not just "did Meshy return a mesh without erroring."
5. If generated via image_to_3d, the source crop was compact/frontal, not a wide scenic slice.
6. Category placement matches `CATEGORY_RUNTIME_FOLDER` in `create_prop.py` (trees/roots/
   mushrooms/rocks/ruins/decor/plot_markers) — don't let a new category silently fall to `misc/`.

## Known deviations from this bible (as of 2026-08-11)

- `ancient_tree_hero_b` and `twisted_root_blocker_b` don't meet the silhouette rule above. Worth
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
