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
