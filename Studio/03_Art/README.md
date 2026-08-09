# Art

Visual style, asset pipelines, sprites/models, UI art. **This is the most scattered department right now** — several docs were written at different points as the direction shifted, and some are stale. This README is the current index; trust it over guessing from file dates.

**Owner**: currently the least-staffed area. Andrew for direction/taste, Claude for pipeline architecture, Codex for pipeline tooling. No one is producing final art yet — everything shipped so far is placeholder/prototype quality.

## What's decided

- **Style target**: dark painterly fantasy RTS, "Darkest Dungeon 2"-inspired — heavy inked silhouettes, matte surfaces, warm/cool contrast, cyan KON emissive accents. See `STYLE_BIBLE.md`.
- **Units: 2D sprite sheets**, not the 3D GLB pipeline. See [Decisions Log](../06_Production/Decisions_Log.md). This closes the long-standing 2D/3D mismatch — the Meshy/Blender 3D pipeline produced real output but was never a good fit for gameplay (unsolved animation, expensive to batch-render at scale).
- Current in-game visuals are hand-drawn vector shapes (`_draw()` per unit) or flat colored quads (new LOD blob tier) — **nothing here is final art**.

## Reference docs (live with the code) — read in this order

1. `STYLE_BIBLE.md` — the actual visual direction, read this first
2. `ASSET_SCALE_GUIDE.md` — dimensions/footprint reference for every asset category
3. `docs/kon_unit_asset_template.md` — the 2D sprite-sheet contract (8-direction, per-unit creative briefs) — **this is now the live target** per the 2D decision
4. `ASSET_SPEC_TEMPLATE.md` — intake template for any new asset
5. `ASSET_PIPELINE_PLAN.md` — the `AssetRegistry`/`AssetPackConfig` runtime framework (terrain/prop side)
6. `BLENDER_EXPORT_GUIDE.md` — Blender conventions, still relevant for terrain/prop/building assets even though units moved off the 3D pipeline

## Known-stale, read with caution

- `ASSET_REPLACEMENT_STATUS.md` — superseded by `DARK_FOREST_FRONTIER_V2_STATUS.md`, don't trust its "current" claims
- `UNIT_ASSET_PIPELINE_STATUS.md`, `tools/unit_pipeline/README_UNIT_PIPELINE.md` — describe the **3D unit pipeline** (Meshy/Blender/GLB). Deprioritized per the 2D decision. Kept for reference (marketing renders, maybe) but not the active unit-art path anymore.
- `units/specs/*.yaml` — inputs to the old 3D pipeline, stat blocks don't match live gameplay. Not authoritative for anything.

## Open item

The actual sprite-sheet pipeline (concept art → 8-direction sheets per `docs/kon_unit_asset_template.md`) doesn't exist yet as working tooling — only the 3D one does. Building a real 2D pipeline is the natural next Art milestone now that the direction is settled. See [Roadmap](../06_Production/Roadmap.md).
