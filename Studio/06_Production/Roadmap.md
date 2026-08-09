# Roadmap

Everything currently open, roughly prioritized. Not a schedule — a backlog. Update as items land or get reprioritized; move completed items to the [Decisions Log](Decisions_Log.md) rather than just deleting them here.

## Needs an Andrew decision before engineering picks it up

- **Wizard death/loss condition** — clarify whether wizard death should be its own fail state, separate from tower destruction. ([01_Design](../01_Design/README.md))
- **Roguelike run structure** — decide if this is a literal design target (permadeath, meta-progression, mid-run build choices — real scope of work) or if the current procedural/evolution systems already satisfy it. ([01_Design](../01_Design/README.md))
- **AI-test army mix** — confirm whether the stress-test mode spawning KON-vs-KON is intentional before anyone "fixes" it as a bug.

## Engineering, prioritized (from `PERFORMANCE_CRITIQUE.md`)

1. ~~Wire in batched LOD rendering for swarm units~~ — **done 2026-08-09**.
2. ~~Move swarm-unit movement off `CharacterBody2D` physics toward manual position integration~~ — **done 2026-08-09**. Blob-tier swarm units now opt out of per-node physics processing and advance through `RTSWorld`'s central budgeted movement loop.
3. ~~Flow-field pathfinding for grouped movement~~ — **done 2026-08-09**, scoped to enemy waves converging on the player target. Player-issued orders and individual chase/arena-lane pathing still use per-unit A* — that was a deliberate scope decision, not a gap.
4. ~~Disable `SimulationState`/`SimulationRunner` while not authoritative~~ — **done 2026-08-09**. Gated behind an actual-multiplayer check rather than deleted, preserving it for planned co-op. Bonus find: fixed a latent `OfflineMultiplayerPeer` bug in `command_dispatcher.gd`'s existing multiplayer routing check too.
5. **Investigated 2026-08-09, not implemented — rescoped, premise was stale.** `TILESET_RUNTIME_DECISION_REPORT.md`'s "zero terrain sets" claim is outdated: `main_map.tscn` already uses `tiny_swords_plot_tileset.tres`, which already has 4 real terrain sets (grass, cliff, water, road) with working peering bits, and grass/road are already painted via real `set_cells_terrain_connect()` autotiling. The real remaining gap is narrower but not small: **water is deliberately still atlas-painted** (documented placeholder pending complete water terrain coverage) and **cliff terrain is defined but unused**. Finishing this needs completed asset-pack/TileSet coverage for water/cliff/ramp/edges first, then reconciling with the logical elevation grid (`E_LOW/E_MID/E_HIGH/E_RAMP/E_WATER/E_BLOCKED`) — that's real art + code work together, not a scoped code-only migration. Belongs jointly with [03_Art](../03_Art/README.md)'s asset pipeline work, not pure Engineering.

## Art

- Build the actual 2D sprite-sheet pipeline (`docs/kon_unit_asset_template.md`'s contract) — nothing produces real sprite art yet, only the deprioritized 3D pipeline does.
- Decide what to do with the existing 3D asset investment (Meshy/Blender output) — archive, keep for marketing renders, or drop entirely.

## Multiplayer / Co-op

- Andrew confirmed the game needs co-op. Current `SimulationState` lockstep scaffolding isn't authoritative and coherent multiplayer is unproven. Scope this as its own piece of work once core single-player performance/design items above settle — don't build on top of a foundation likely to change (see item 4 above).

## Housekeeping

- `units/specs/*.yaml` are stale relative to `unit_catalog.gd` — worth deciding whether to delete, archive, or clearly mark as legacy-3D-pipeline-only so nobody mistakes them for live data again.
- `ASSET_REPLACEMENT_STATUS.md` is superseded by `DARK_FOREST_FRONTIER_V2_STATUS.md` — consider archiving the stale one rather than leaving both live.
- No audio/SFX plan exists yet — see [04_Audio](../04_Audio/README.md).
- No narrative bible exists yet — see [05_Narrative](../05_Narrative/README.md).
