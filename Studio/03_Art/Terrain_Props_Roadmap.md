# Terrain & Props Art Roadmap

Written 2026-08-09, grounded in a direct audit of the current asset pack, asset folders, and generation scripts — not a guess. Scope: terrain, biome props, structures/landmarks. Unit art is out of scope here — units are 2D sprite sheets per the [2D decision](../06_Production/Decisions_Log.md), not this pipeline.

## Current state, verified

- **Style direction is solid.** `STYLE_BIBLE.md` already defines a clear target: dark painterly, Darkest Dungeon 2-inspired, chunky/readable silhouettes, cyan KON / magenta-pink corrupted-mushroom accent colors. This isn't the gap.
- **The generation pipeline is 100% procedural, not concept-driven.** `tools/blender/create_dark_forest_v2_assets.py` (the script that produces the current biome's GLBs) is pure `bpy` primitive scripting — boxes, cones, simple geometry — run headless with zero concept art or AI image-to-3D input. This is a fundamentally different, more limited technique than the pipeline you described and than what's already proven to work for units (Midjourney concept → Meshy image-to-3D → Blender style cleanup). **This is very likely the real root cause of the generic/placeholder look**, not just "needs more passes."
- **Coverage is thin.** The active `dark_forest_frontier_v2_asset_pack.json` defines 33 asset categories. Most have exactly 1-2 variants — near-zero visual variety. Three categories (`BASE_PLOT_MARKER`, `CONTENT_PLOT_MARKER`, `OUTPOST_MARKER`) have **zero** assets and always render through the fallback system. Only ~3 tree GLBs are active despite trees being the dominant visual element in every scene.
- **The fallback system is working as designed** (colored materials / placeholder shapes so nothing crashes) — which means an unknown amount of what's currently on screen, likely including some of what's in your screenshot, may be fallback rendering rather than finished art. Worth a deliberate visual audit rather than assuming.

## Recommended architecture: two tracks, not one pipeline

**Track 1 — Concept-driven (new for terrain/props, reuses proven unit_pipeline tooling).** For distinctive, seen-up-close, or landmark assets where bespoke art direction actually matters: the wizard monolith, shrines, ruin centerpieces, signature corrupted-tree formations, unique magical props. Same pattern already working for units: Midjourney concept art → Meshy image-to-3D → Blender style-profile cleanup (reuse the `darkest_dungeon_2_like_kon.json`-style material remap approach) → Godot registration. This is the highest-leverage change available — it's proven tooling, just never pointed at terrain/props.

**Track 2 — Procedural (keep, it's the right tool for this tier).** For repeated, parametric, bulk elements where bespoke concept art would be wasted effort: generic ground tiles, simple rock variants, filler road decor, basic foliage instances. The existing script-based approach is appropriate here — the problem isn't that procedural generation exists, it's that *everything* is currently on this track, including things that shouldn't be.

## Phased plan

1. **Style lock & fallback audit.** Before generating anything new: confirm the STYLE_BIBLE direction against real DD2 reference material, and do a deliberate visual pass through the biome preview (`map_3d_renderer.gd`, which already has debug toggles for exactly this) to determine what's genuinely styled vs. fallback rendering right now. Don't build on an unclear baseline.
2. **Close the zero-coverage gaps.** `BASE_PLOT_MARKER`, `CONTENT_PLOT_MARKER`, `OUTPOST_MARKER` have literally nothing — quick, clear, low-risk wins before anything else.
3. **Concept-driven pass for landmark/hero props.** Highest visual-impact work, and the track most likely to actually deliver "high standard" — this is where Track 1 pays off.
4. **Variety pass on thin categories.** Trees, rocks, mushrooms, roots — take each from 1-2 variants to enough real variation that repetition isn't obvious.
5. **Procedural track polish.** Once the split is real, improve materials/shading on what's deliberately staying procedural (Track 2) so it doesn't visually clash with the concept-driven hero assets.
6. **Full biome re-assessment.** Re-run the fallback/coverage audit from step 1. Target: zero fallback rendering in a normal play session, and a defined minimum variant count per category (not just "at least 1").

## What "high standard" should mean, concretely

- Zero categories with 0 assets.
- No single-variant categories for anything the player sees repeatedly (trees, common blockers).
- Every landmark/structure asset went through the concept-driven track, not procedural primitives.
- A visual QA checklist per new asset, checked against `STYLE_BIBLE.md` before it's considered done — not just "renders without crashing."

## Open question for Andrew

Given the pink/magenta accents visible in your screenshot: `STYLE_BIBLE.md` and the V2 status docs do describe "hot pink/red magical mushroom accents" as an intentional part of the corrupted-forest palette. Some of what reads as "broken placeholder" in the screenshot might actually be that intentional accent color, just overused or under-varied rather than wrong. Worth a deliberate look before assuming it's all fallback — that's exactly what step 1 above is for.

## Progress — 2026-08-10/11

Steps 2, 3, and part of 4 landed in one pass, prompted by Andrew supplying real concept art (5 "hellfirebaby" isometric forest-floor/wall tile images plus a seamless ground texture) and a Codex-drafted brief asking to "generate all the assets for our first map biome: VAMPIRIC_MUSHROOM_FOREST."

**Naming note**: `VAMPIRIC_MUSHROOM_FOREST` is not a registered biome — `map_generator.gd` only defines `DARK_FOREST_FRONTIER_V2`, and the supplied concept art is the same "hellfirebaby" Midjourney stream already behind this biome's units and `dark_forest_frontier_v2_props.json` style profile (same black-bark/blood-mushroom/cyan-KON language). Treated the brief as "flesh out DARK_FOREST_FRONTIER_V2 with this concept art," not "create a second biome" — creating a real second biome would mean forking `map_generator.gd`'s biome plumbing, which nothing in the brief or the repo actually calls for. `vampire_mushroom_forest` elsewhere in the repo (an audio track name, a unit-art folder) is unrelated legacy naming from the wizard-class/unit side, not this terrain biome.

What landed:

- **Zero-coverage gap (step 2) was already closed** before this pass by other in-flight work — `BASE_PLOT_MARKER`/`CONTENT_PLOT_MARKER`/`OUTPOST_MARKER` each had 1 asset already registered and wired into `map_3d_renderer.gd`'s plot-marker placement.
- **Concept-driven pass (step 3)**: `tools/prop_pipeline/create_prop.py` only supported `model.source: text_to_3d`. Added `image_to_3d` support (mirroring the pattern already proven in `tools/unit_pipeline/create_unit.py`), then cropped 3 clean sub-regions out of the supplied diorama concept art — a glowing-mushroom tree-root nook, a dense glowing root-wall cluster, a mushroom-and-soul-light cluster — as Meshy Image-to-3D inputs. Saved under `art/concepts/dark_forest_frontier_v2/`. All 3 generated successfully: `ancient_tree_hero_b` (`ANCIENT_TREE_BLOCKER`), `root_wall_hero_b` (`ROOT_WALL_BLOCKER`), `glowing_mushroom_ring_hero_b` (`GLOWING_MUSHROOM_RING`).
- **Variety pass (step 4, partial)**: added a 2nd/3rd text-to-3d variant to the thinnest visually-dominant categories — `TREE_BLOCKER` (now 3), `ROCK_BLOCKER`, `ROCK_MOSS_CLUSTER`, `MUSHROOM_CLUSTER_SMALL`, `MUSHROOM_CLUSTER_LARGE`, `TWISTED_ROOT_BLOCKER`, `DEAD_TREE_SPIKE` (all now 2). Cliffs/ramps deliberately left alone — the renderer still prioritizes procedural connected geometry for those (see V2 status doc's Known Limitations), so more GLB variants there wouldn't currently be visible.
- **Ground texture**: `LOW_GROUND_TILE`/`HIGH_GROUND_TILE` materials were flat `albedo_color` only. Processed the supplied seamless-texture concept art into a proper tileable albedo (cropped away the large baked-in mushroom-cap illustrations first — those would've repeated one giant mushroom per gameplay tile; kept a finer moss/root/pebble-detail crop instead) and wired it into both `.tres` materials via `uv1_scale`. New tool: `tools/prop_pipeline/process_ground_texture.py`.
- **Fixed a real bug found along the way**: `create_prop.py` hardcoded every generated prop's runtime path to `assets_game/props/plot_markers/dark_forest_frontier_v2/`, regardless of category — so a newly-generated tree or mushroom would've landed in the "plot markers" folder. Added `CATEGORY_RUNTIME_FOLDER` so props now route to the same `trees/roots/mushrooms/rocks/ruins/decor/plot_markers` taxonomy the existing procedurally-generated assets already use.

**Verified**: full reimport + a live BIOME-mode showcase capture reports `missing_categories=[]` and `fallback_count={}` — every one of the 39 categories the renderer asks for now resolves to a real asset, zero fallback rendering. Screenshots show the new ground texture and road contrast reading well; landmark mushroom clusters (pink/red glow) read well. **Not yet great**: dense blocker clusters (rock/moss/root fill at map edges) still read as fairly flat grey-blue at a distance — likely `discard_imported_materials: false` in the style profile keeping Meshy's raw PBR texture instead of the profile's curated flat palette. Worth an experiment: flip that flag for a batch and compare, per step 5 below.

Ten new specs live under `props/specs/*_b.yaml` / `*_c.yaml` as a template for the next variety-pass round.

## Progress — 2026-08-11: Art Bible + two-tier decision

Andrew's own read on the 2026-08-10/11 batch: pipeline works, assets are OK, but (1) most of the
live map is still the original pre-pipeline procedural assets — only a handful of categories have
been touched, and the highest-frequency categories (`ROCK_MOSS_CLUSTER` at 2,391 placements,
`TWISTED_ROOT_BLOCKER` at 1,426) are still mostly old stock; (2) art style isn't consistent enough
yet; (3) animation (wind-sway trees, etc.) is wanted. Correct read, confirmed against the actual
prop-count log from a live map generation — this pass was a variety top-up, not a full replacement.

Before doing more generation, wrote `wizard-rts/DARK_FOREST_FRONTIER_V2_ART_BIBLE.md` — the
locked reference every future prompt must be checked against. Notable finding along the way: the
concept art itself wasn't stylistically consistent. Two visibly different reference sets exist —
a muted "black-ink forest" (Aug 10, what today's assets were built from) and a much more saturated
"glowing glass mushroom" set (Apr 19, unrelated crystal-cave-adjacent look). Rather than pick one
and discard the other, Andrew confirmed this should become a **deliberate two-tier split by
elevation**: dark-ink low ground, glass-mushroom high ground — reinforcing `STYLE_BIBLE.md`'s
existing (previously unimplemented) "high ground should be visibly separated from low ground" rule
with an atmospheric channel, not just a height difference. See the Decisions Log for the full
reasoning.

**This is a documentation-only pass — no new generation happened.** The high-ground tier described
in the bible doesn't exist in the game yet (`HIGH_GROUND_TILE` is still a tinted copy of the
low-ground texture); regenerating the two weak hero props flagged in the last progress note hasn't
happened either. Both are now clearly scoped next steps rather than open-ended concerns.
