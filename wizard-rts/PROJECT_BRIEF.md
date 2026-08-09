# Wizard-RTS — Project Brief

Living reference for anyone (human or AI) picking up this project. Last synthesized: 2026-08-08, from a full read of the codebase and design docs. Update this file when major systems change — don't let it go stale like some of the asset-pipeline status docs have.

## What the game is

A **Godot 4.6** real-time strategy game (confirmed via `project.godot`'s `config/features`). The player controls **KON**, led by a persistent, controllable **hero wizard unit** (not just a base — the wizard walks around, fights, and can die/respawn), commanding an evolving roster of creature units against **Deom Legion**, a tiered enemy faction, across procedurally generated 96×96 maps. Structurally it's closer to an RTS/hero-unit hybrid (WarCraft III-ish) than a pure base-builder.

Core loop: build economy (`bio_absorber`) → train units at `barracks` → units gain XP from combat and **evolve** into stronger forms → survive escalating enemy waves → destroy enemy outposts → beat a boss (`mycelium_boss`) to win. Defend your `wizard_tower` — if it falls, you lose; if your wizard dies, the tower absorbs the blow and the wizard respawns there instead.

## DECIDED: staying 2D (2026-08-08)

The 2D vs 3D question below is resolved. **Units render 2D** (sprite sheets per `docs/kon_unit_asset_template.md`/`STYLE_BIBLE.md`'s existing billboard spec — not the Meshy/Blender 3D GLB pipeline). The 3D unit pipeline is deprioritized as a gameplay path; keep it only for marketing/preview renders if wanted, don't bridge more units through it, don't build gameplay logic assuming 3D. Reasoning: the actual required scale (hundreds of units) is already proven achievable in 2D per `PERFORMANCE_CRITIQUE.md`; sprite-sheet rendering batches far more cheaply than per-unit 3D meshes with unsolved animation; and AI-assisted dev velocity (Claude/Codex) is materially higher on Godot 2D than on the 3D content pipeline's tooling.

Engine choice also settled: **staying on Godot**, not migrating to Spring/Recoil. Target scale (hundreds, not BAR's thousands) is already within Godot's proven range, and an engine migration would discard the tested systems already built here for a much weaker AI-assisted development position.

## Repo layout gotcha

The real project is nested: `wizard-rts/wizard-rts/` (the outer `wizard-rts/` has a placeholder README and legacy top-level `scripts`/`scenes` folders — ignore those, they're not the active project). `project.godot` lives in the nested folder.

## Boot flow & entry points (verified against `project.godot`)

- Boot scene: `res://scenes/ui/main_menu.tscn` (`scripts/ui/main_menu.gd`) — start game, character/wizard select, map select, audio/display settings, map editor, test maps.
- Gameplay scene: `res://scripts/map/main_map.tscn` — **this is the real one**, referenced by `main_menu.gd` and every smoke test.
- **Trap**: there is a second, near-identical-named `res://scenes/map/main_map.tscn` (103 bytes, a dead stub) that nothing references. If you're searching for "main map" and land on the one under `scenes/`, you're in the wrong file — the live scene lives under `scripts/map/`, not `scenes/map/`.
- HUD: `scripts/ui/rts_hud.gd` — Bio, wave phase, boss countdown, selection/unit details, evolution progress, build/train commands, alerts, plus AI-test telemetry and map-gen controls on test maps.
- Audio: `scripts/audio/audio_manager.gd` — one looping track at a time; main menu swaps track based on selected wizard (`Bad John Dillo Fixed.mp3`, `Fire Wizard.mp3`, `Evangalion.mp3`, plus `vampire mushroom forest.mp3` for that biome).

## Key files to read first

`project.godot` → `unit_catalog.gd` (live stats) → `rts_unit.gd` (base unit class) → `combat_system.gd`/`rts_world.gd` (combat) → `build_system.gd` → `wave_director.gd` → `selection_controller.gd` → `rts_hud.gd` → `map_generator.gd`. Plus `COMBAT_SYSTEM_REVIEW.md` and `STYLE_BIBLE.md` for the two areas with dedicated deep-dive docs.

## Working agreements for AI collaborators

- Treat this file as current high-level truth; update it when it drifts.
- `unit_catalog.gd` is the live gameplay stat source — not `units/specs/*.yaml` (offline art-pipeline input only, stats don't match).
- Live gameplay is 2D. Don't assume or introduce 3D gameplay logic — see the rendering-paths section above.
- Prefer existing Godot patterns/scripts over introducing new architecture; avoid refactoring unrelated systems.
- Add or run a smoke test (`scripts/core/*_smoke_test.gd`) when touching a gameplay system — the project already has strong coverage here, keep it that way.

## Two rendering paths — know which is real

- **Actual gameplay is 2D.** Units are `CharacterBody2D`, the map is `TileMapLayer`s, pathing is `AStarGrid2D`. This is what ships and what the player sees.
- **`map_3d_renderer.gd`/`map_3d_preview.gd` is a prototyping tool**, not the shipping renderer — it instantiates its own headless `MapGenerator` and extrudes the same logical grid into 3D purely to evaluate art direction. Don't confuse "there's a polished 3D renderer" with "the game is 3D."
- Similarly, the automated **unit art pipeline produces 3D GLB models** (Meshy → Blender → Godot `Node3D` scenes), but the live gameplay unit class (`RTSUnit`) is 2D. Only one unit (**Oaven Spear**) was manually bridged from the 3D pipeline into actual 2D gameplay. **This is now a closed decision, not an open question** — see "DECIDED: staying 2D" above. Units are moving toward sprite sheets, not more 3D bridging.

## Factions & roster

**KON (player)** — most units have a base form + an evolved form, triggered by accumulated combat XP:
| Unit | HP (base→evo) | Role/gimmick |
|---|---|---|
| Wizard hero (`life_wizard`/`fire_wizard`/`evangalion_wizard`) | 260/165/190 | Player-controlled, dual-casts, respawns at tower on death |
| `terrible_thing`→`gripper` | 64→132 | Cheap swarm, explodes on death (base only), evolved grapples/roots |
| `oaven_spear`→`oaven_jumper` | 58→118 | Taunt, Charge, evolved briefly flies |
| `horror`→`hunter` | 72→108 | Fast ranged, evolved builds burst-shot charges |
| `apex`→`champion` | 150→260 | Heals on attack, can eat allies, evolved scales with missing HP |
| `spawner`→`winged_spawner` | 360→430 | Siege artillery, must root to fire, summons drones |
| `stone_face_serpent` | 240, 5 evo levels | Poison, unique Stone Form (becomes a wall segment) |

Structures: `wizard_tower` (HQ), `bio_absorber` (economy), `barracks` (production, only 6 of ~10 unit types wired to train), `terrible_vault` (research gate), `vinewall` (drag-placed regenerating wall), `bio_launcher` (autonomous AoE turret).

**Deom Legion (enemy)** — tiered: `deom_scout`(T0) → `deom_blade`/`deom_crosshirran`(T1) → `deom_hammer`/`deom_glaive`(T2) → `deom_odden`(T3, flying transport, "troop drop" stat exists but isn't implemented).

Legacy biome enemies (`vampire_mushroom_forest` map type, likely superseded): `vampire_mushroom_thrall`, `bloodcap_runner`, `spore_spitter`, `bloodcap_brute`, `mycelium_boss`.

## Core systems (all in `scripts/core/` unless noted)

- **Map gen** (`map_generator.gd`, 4589 lines): deterministic, seeded (`DeterministicRng`). Default map type `seeded_grid_frontier` — base/content plots, elevation plateaus+ramps, road network, landmarks, all self-validating with `push_warning` diagnostics. A newer, more polished standalone island generator (`plots/PlotGenerator.gd`) exists but isn't integrated into the main map yet (test-only).
- **Combat** (`combat_system.gd`, `rts_world.gd`, `rts_unit.gd`): see `COMBAT_SYSTEM_REVIEW.md` in this repo for the full authoritative writeup — target acquisition, damage flow, structure vs unit targeting all documented there in detail.
- **Economy**: single resource `bio` (starts 1000, ticks from `bio_absorber`). A second resource `essence` is defined but unused anywhere.
- **Build system**: placement preview, construction timers, auto-evolving buildings, a small 4-upgrade tech tree gated behind `terrible_vault`.
- **Wave director**: story mode has a phase machine (scouting→buildup→offense→victory) with escalating wave composition and a boss at 240s. A separate, heavily-tuned **AI-stress-test mode** exists for pushing thousands of units to test performance (adaptive spawn throttling based on live FPS).
- **SimulationState / SimulationRunner**: a **parallel, deterministic lockstep simulation** (20Hz, own pathing, own RNG, hash-based desync detection) that mirrors commands from real gameplay but does **not** drive actual gameplay yet — it's scaffolding for future multiplayer/replay, tested in isolation but not authoritative. Real gameplay uses its own separate physics/pathing.
- **Multiplayer** (`multiplayer_session.gd`): real ENet networking plumbing, command relay works, but since it only synchronizes the (non-authoritative) SimulationState ledger and not actual unit positions/combat, it's unproven whether two peers would see a coherent shared game.
- **Fog of war**: fully implemented, but **disabled on the current default map type** (`seeded_grid_frontier`) — only active on the legacy `vampire_mushroom_forest` map.
- **Testing**: ~28 automated headless smoke/stress tests (`scripts/core/*_smoke_test.gd`, `extends SceneTree`, CI-shaped exit codes). Genuinely disciplined coverage — most core systems have at least one test enforcing invariants.

## Asset pipeline status (as of last docs, 2026-05-31)

Two parallel pipelines, both converging on a common `AssetRegistry`/`AssetPackConfig` runtime system:
1. **Terrain/biome** (Blender scripts → GLB → registered by tag, graceful fallback if missing). Current biome: Dark Forest Frontier **V2** (dark painterly, black twisted trees, cyan/magenta magical accents).
2. **Units** (YAML spec + concept art → Meshy Image-to-3D → Blender restyle/cleanup → Godot scene scaffold). Working for first-pass placeholders; **animation is unsolved** (only placeholder root-motion clips, no rig library). Style target: "Darkest Dungeon 2"-inspired dark painterly with cyan KON emissive accents.

Uncommitted work in progress when this brief was written: refinements to the Blender unit-processing script and the Oaven Spear model/spec (see `git status`/`git diff`).

## Open questions worth resolving before more content work

1. ~~2D vs 3D rendering path~~ — **Decided**, see top of file. Staying 2D.
2. **TileSet migration**: `TILESET_RUNTIME_DECISION_REPORT.md` found the live map's TileSet has zero terrain sets (autotiling is currently non-functional) and recommended migrating to `tiny_swords_plot_tileset.tres` — this was a fully-specified plan that, as far as the docs show, was never executed.
3. **AI-test mode may have a bug**: in `wave_director.gd`'s stress-test mode, both the "west" and "east" test armies appear to draw from the same KON unit mix rather than KON vs Deom — worth confirming whether that's intentional (controlled army-vs-army testing) or a leftover mistake.
4. **`units/specs/*.yaml` are stale**: their stat blocks don't match the live `unit_catalog.gd` numbers — they're inputs to the offline art pipeline only, not a live data source. Don't treat them as gameplay-authoritative.
5. **`ASSET_REPLACEMENT_STATUS.md` is superseded** by `DARK_FOREST_FRONTIER_V2_STATUS.md` (written the same day, later) — don't trust the V1 doc's "current" claims without cross-checking the actual renderer code.
6. ~~Rendering cost at scale~~ — **Done (2026-08-09)**. `mass_unit_multimesh_renderer.gd` is now a working distance/count-based LOD system, wired into `main_map.tscn`. Nearby/selected units keep full hand-drawn detail; distant swarm units batch-render as multimesh blobs. Verified against the stress-test suite at ~3000 units: worst-case `lowest_fps_observed` went from 2.0 to 40.0, `highest_process_ms_observed` from 85.4ms to 55.0ms, steady-state fps from 57-58 to a flat 60 (now hits the cap). Gameplay unaffected — hidden units remain fully selectable/targetable, covered by `scripts/core/mass_unit_lod_smoke_test.gd`. Still not blocked on real sprite art (flat colored quads for now) — that's a separate content-pipeline effort, worth doing next given units are committed to 2D.
7. **"Roguelike" isn't designed yet, only vibed toward**: no permadeath, run structure, or meta-progression found anywhere in code/docs — see `PERFORMANCE_CRITIQUE.md`'s genre-fit section.

## Source-of-truth docs for deep dives

- Combat mechanics: `COMBAT_SYSTEM_REVIEW.md`
- Performance at scale: `PERFORMANCE_CRITIQUE.md` (measured, not speculative — includes real stress-test telemetry)
- Visual direction: `STYLE_BIBLE.md`, `ASSET_SCALE_GUIDE.md`
- Asset pipelines: `UNIT_ASSET_PIPELINE_STATUS.md`, `tools/unit_pipeline/README_UNIT_PIPELINE.md`, `ASSET_PIPELINE_PLAN.md`, `docs/asset_pack_pipeline.md`
- Terrain rendering: `TILESET_RUNTIME_DECISION_REPORT.md`, `docs/procedural_plot_generator_design.md`
