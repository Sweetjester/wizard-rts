# Roadmap

Everything currently open, roughly prioritized. Not a schedule — a backlog. Update as items land or get reprioritized; move completed items to the [Decisions Log](Decisions_Log.md) rather than just deleting them here.

## Needs an Andrew decision before engineering picks it up

- **AI-test army mix** — confirm whether the stress-test mode spawning KON-vs-KON is intentional before anyone "fixes" it as a bug.

## Design targets set, implementation not yet updated (from `MASTER_DESIGN_DOC.md`, landed 2026-08-19)

- ~~Wizard death/loss condition~~ — **done 2026-08-23**. Wizard death and tower destruction are now independent loss triggers per §9 (previously required both, and only matched the `life_wizard` archetype). See Decisions Log.
- ~~Class unit rosters~~ — **first pass done 2026-08-23**. All 3 wizard classes trained from one identical shared roster (zero differentiation — a direct violation of §16). Now gated per class using only existing units (no new art commissioned). See Decisions Log for the split and what's still missing (full 5-6-unit rosters per class, class-specific buildings/economy twists).
- ~~A second win-objective type~~ — **first pass done 2026-08-23**. Boss-defeat was the only win path that existed. Added "destroy all required outposts" as a second, randomly-selected-per-run objective (`GameSession.objective_id`) — matches §9's "destroy an enemy stronghold" example. See Decisions Log.
- **Roguelike run structure** — design target: class selection [done], procedural map [done], randomized objective [first pass done — only 2 objective types exist, §9/§28 list ~9], map-discovered upgrades researched back at the tower (§17-18, still open — the existing "research" at the Terrible Vault is 4 hardcoded flat stat buffs bought outright, not upgrades discovered on the map). Real scope of work remains here — this isn't closed, just less empty.

## Engineering, prioritized (from `PERFORMANCE_CRITIQUE.md`)

1. ~~Wire in batched LOD rendering for swarm units~~ — **done 2026-08-09**.
2. ~~Move swarm-unit movement off `CharacterBody2D` physics toward manual position integration~~ — **done 2026-08-09**. Blob-tier swarm units now opt out of per-node physics processing and advance through `RTSWorld`'s central budgeted movement loop.
3. ~~Flow-field pathfinding for grouped movement~~ — **done 2026-08-09**, scoped to enemy waves converging on the player target. Player-issued orders and individual chase/arena-lane pathing still use per-unit A* — that was a deliberate scope decision, not a gap.
4. ~~Disable `SimulationState`/`SimulationRunner` while not authoritative~~ — **done 2026-08-09**. Gated behind an actual-multiplayer check rather than deleted, preserving it for planned co-op. Bonus find: fixed a latent `OfflineMultiplayerPeer` bug in `command_dispatcher.gd`'s existing multiplayer routing check too.
5. **Investigated 2026-08-09, not implemented — rescoped, premise was stale.** `TILESET_RUNTIME_DECISION_REPORT.md`'s "zero terrain sets" claim is outdated: `main_map.tscn` already uses `tiny_swords_plot_tileset.tres`, which already has 4 real terrain sets (grass, cliff, water, road) with working peering bits, and grass/road are already painted via real `set_cells_terrain_connect()` autotiling. The real remaining gap is narrower but not small: **water is deliberately still atlas-painted** (documented placeholder pending complete water terrain coverage) and **cliff terrain is defined but unused**. Finishing this needs completed asset-pack/TileSet coverage for water/cliff/ramp/edges first, then reconciling with the logical elevation grid (`E_LOW/E_MID/E_HIGH/E_RAMP/E_WATER/E_BLOCKED`) — that's real art + code work together, not a scoped code-only migration. Belongs jointly with [03_Art](../03_Art/README.md)'s asset pipeline work, not pure Engineering.

## Art

- **Artwork pipeline flagged as needing structural rework** — see `MASTER_DESIGN_DOC.md` §37 (2026-08-19). Two disconnected generation pipelines exist (3D/Meshy, was feeding a non-shipping preview scene; 2D/PixelLab, has actually shipped real assets but let a fully-generated batch sit unreviewed for ~4 months). **Animation is the single largest gap** — only one unit (Oaven Spear) has ever been bridged from any pipeline into real working 2D gameplay animation; everything else is placeholder motion. Don't generate more static art volume before this is addressed.
- ~~Build the actual 2D pipeline / decide what to do with the 3D investment~~ — **partially resolved 2026-08-19**. The real 2D terrain-paint + prop-sprite system in `map_generator.gd` was found already built (just pointed at placeholder "Tiny Swords" art); wired in salvaged PixelLab art + this session's tree sprites with zero new config, verified live (212 trees/710 rocks rendering in the actual shipping scene). The 3D/Meshy investment: still not formally archived-vs-kept decided, but §37 recommends 2D/PixelLab as the default going forward for new gameplay art.
- ~~Full-coverage pass on `DARK_FOREST_FRONTIER_V2`~~ — **done 2026-08-16 to 08-19** (see Decisions Log). Went from ~10 of 30+ categories touched to nearly full coverage, including a new `LANTERN_TREE_BLOCKER` category. This was all built for `map_3d_renderer.gd` (the non-shipping preview scene) before the architecture finding above — the assets themselves may still be worth salvaging into the real 2D pipeline the way the tree billboards were, but that hasn't been done category-by-category yet.
- Ground/road/water tiles in the real 2D game are still Tiny Swords placeholder colors — highest remaining visual-impact item, blocked on a `PIXELLAB_API_KEY` that isn't set anywhere (`.env` or shell). A new square-tile manifest is drafted and ready to submit the moment the key exists.
- Five prop types from the abandoned PixelLab batch were never generated (giant mushroom, ruin floor, wizard tower wall, bandit wall, economy plot) — already `enabled: true` in `tools/pixellab_terrain_asset_manifest.json`, just needs the key to run.
- High-ground tier (`HIGH_GROUND_TILE`, glass-mushroom palette per the Art Bible) — still not built; still just a tinted low-ground texture. Unchanged from 2026-08-11.
- Environmental animation (wind-sway trees, glow-pulse on emissive materials) — still documented intent only, not implemented. Now subsumed into the broader animation gap logged in §37 above.

## Multiplayer / Co-op

- Andrew confirmed the game needs co-op. Current `SimulationState` lockstep scaffolding isn't authoritative and coherent multiplayer is unproven. Scope this as its own piece of work once core single-player performance/design items above settle — don't build on top of a foundation likely to change (see item 4 above).

## Housekeeping

- `units/specs/*.yaml` are stale relative to `unit_catalog.gd` — worth deciding whether to delete, archive, or clearly mark as legacy-3D-pipeline-only so nobody mistakes them for live data again.
- `ASSET_REPLACEMENT_STATUS.md` is superseded by `DARK_FOREST_FRONTIER_V2_STATUS.md` — consider archiving the stale one rather than leaving both live.
- No audio/SFX plan exists yet — see [04_Audio](../04_Audio/README.md).
- No narrative bible exists yet — see [05_Narrative](../05_Narrative/README.md).
- ~~Stray `worktree-agent-...` branch~~ — **checked and deleted 2026-08-23**. It pointed at the same commit already in `main`'s history (the 2026-08-17 Lantern Tree recolor) — zero unique commits, nothing to salvage. Confirmed local-only (not on `origin`) before deleting.
