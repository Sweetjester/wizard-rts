# Roadmap

Everything currently open, roughly prioritized. Not a schedule — a backlog. Update as items land or get reprioritized; move completed items to the [Decisions Log](Decisions_Log.md) rather than just deleting them here.

## Needs an Andrew decision before engineering picks it up

- **Wizard death/loss condition** — clarify whether wizard death should be its own fail state, separate from tower destruction. ([01_Design](../01_Design/README.md))
- **Roguelike run structure** — decide if this is a literal design target (permadeath, meta-progression, mid-run build choices — real scope of work) or if the current procedural/evolution systems already satisfy it. ([01_Design](../01_Design/README.md))
- **AI-test army mix** — confirm whether the stress-test mode spawning KON-vs-KON is intentional before anyone "fixes" it as a bug.

## Engineering, prioritized (from `PERFORMANCE_CRITIQUE.md`)

1. ~~Wire in batched LOD rendering for swarm units~~ — **done 2026-08-09**.
2. Move swarm-unit movement off `CharacterBody2D` physics toward manual position integration — biggest remaining architectural lever for performance headroom.
3. Flow-field pathfinding for grouped movement (wave-vs-wave, mass attack-move) instead of per-unit A*.
4. Disable `SimulationState`/`SimulationRunner` while not authoritative, or gate behind an explicit multiplayer/replay mode — currently pure overhead.
5. TileSet autotiling migration — the live map's TileSet has zero terrain sets; a fix was fully specified in `TILESET_RUNTIME_DECISION_REPORT.md` but never executed.

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
