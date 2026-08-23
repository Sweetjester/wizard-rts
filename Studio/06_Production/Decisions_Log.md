# Decisions Log

Running record of major project decisions — what was decided, when, and why. Append to this; don't rewrite history. If a decision gets reversed later, add a new entry rather than editing the old one.

---

### 2026-08-08 — Rendering: staying 2D

Units render 2D (moving toward sprite sheets per `docs/kon_unit_asset_template.md`), not the 3D GLB pipeline. The project had been quietly funding two incompatible art directions — a fully-built 3D Meshy/Blender pipeline with unsolved animation, versus 2D gameplay that actually ships. Reasoning: the required scale (hundreds of units) is already achievable in 2D; 2D batches far more cheaply than per-unit 3D meshes; AI-assisted dev velocity (Claude/Codex) is materially higher on Godot 2D than on the 3D pipeline's specialized tooling. The 3D work isn't deleted, just deprioritized as a gameplay path — still useful for marketing renders if wanted.

### 2026-08-08 — Engine: staying on Godot

Considered migrating to Spring/Recoil (the engine Beyond All Reason uses) for its proven massive-scale RTS simulation and native lockstep multiplayer. Decided against it: the actual target scale (hundreds, not BAR's thousands) is already within Godot's proven range (see the LOD fix below), an engine migration would discard months of tested Godot systems, and Claude/Codex have vastly more depth on Godot than on Spring's Lua-based tooling — directly serving Andrew's own stated thesis that AI-assisted development is the efficiency lever here.

### 2026-08-09 — Performance: LOD rendering system landed

Fixed and wired up `scripts/units/mass_unit_multimesh_renderer.gd` (previously dead code — inverted visibility bug, never added to the scene). Now a working distance/count-based LOD system. Verified via the project's own stress-test suite at ~3000 units: worst-case frame stall went from 2 FPS to 40 FPS, steady-state hit a flat 60fps (up from 57-58). Gameplay unaffected — hidden units remain fully selectable/targetable. Full detail in `wizard-rts/wizard-rts/PERFORMANCE_CRITIQUE.md`.

### 2026-08-09 — Performance: blob-tier movement centralized

Moved blob-tier swarm movement off each unit's `CharacterBody2D` physics callback once the live unit count reaches swarm scale. Full-detail and selected units still use their normal per-node movement path; hidden multimesh-rendered units disable per-node physics and are advanced by `RTSWorld`'s existing budgeted central movement loop. This keeps gameplay objects selectable/targetable while removing the expensive per-unit physics callback from distant swarm units.

### 2026-08-09 — Performance: flow-field pathfinding for enemy waves

Added flow-field pathfinding scoped specifically to enemy waves converging on the player's base (`wave_director.gd`), not a full pathfinding rewrite. A cached Dijkstra flow field (keyed with the existing `_path_cache_version` invalidation) replaces per-unit A* for that one scenario; units with no valid flow route fall back to individual A*. Player-issued orders, chase-to-attack-range, and arena AI lane orders are untouched — deliberately scoped out, not missed. New telemetry: `flow_field_recomputes`, `units_using_flow_field`. Verified with a new smoke test asserting real behavioral outcomes (measured progress toward target, majority of wave units actually using the field) plus a clean-conditions rerun of the fortress stress test confirming zero effect there (as expected, since that mode doesn't route through wave_director's normal dispatch).

First task delivered through `claude-loop.js` instead of Bell's task-mode loop — Claude planned directly with full context already in hand (no blind planning call), and reviewed the result in-conversation rather than via an automated review pass.

### 2026-08-09 — Performance: SimulationRunner gated, not deleted

`SimulationRunner.auto_start` defaulted to `true` unconditionally, so the 20Hz deterministic lockstep layer ran in every single-player session with nothing consuming its output. Gated it behind an actual-active-multiplayer check instead of removing it — this is groundwork for planned co-op, not dead weight to cut. Found and fixed a real latent bug along the way: Godot always assigns a default `OfflineMultiplayerPeer` even with no networking set up, so the existing `multiplayer_peer != null` check in `command_dispatcher.gd` had silently always evaluated true. Both checks now correctly test for a genuinely active (non-offline) peer.

### 2026-08-09 — TileSet autotiling: investigated, premise found stale, not implemented

Roadmap task 5 claimed the live map's TileSet had zero terrain sets. Investigation found this was already fixed at some earlier point and the documentation just never caught up: `main_map.tscn` uses `tiny_swords_plot_tileset.tres` (4 real terrain sets, working peering bits), and grass/road already paint via real `set_cells_terrain_connect()` autotiling. Also found (and corrected) my own wrong guess about three `set_cell()` call sites at lines 4401/4403/4405 — despite the `terrain_name` parameter name, these are plot/feature overlay painting (walls, economy markers, objectives), not elevation surface painting, and are correctly left as direct paint. The real remaining gap — water is deliberately still atlas-painted pending complete terrain coverage, cliff terrain is defined but unused — needs completed asset-pack/TileSet work plus reconciling with the logical elevation grid. Declined to force a code migration for something that's actually art+code work together; rescoped on the roadmap instead of marking a fake "done."

### 2026-08-11 — Terrain/props: concept-driven pipeline stood up, treated as one biome not two

Andrew supplied real concept art (isometric forest-floor/wall tiles, a seamless ground texture) and a Codex-drafted brief to "generate all the assets for our first map biome: VAMPIRIC_MUSHROOM_FOREST." That name isn't a registered biome — `map_generator.gd` only defines `DARK_FOREST_FRONTIER_V2`, and the art is the same concept-art stream already behind it (same units, same `dark_forest_frontier_v2_props.json` style profile). Treated the brief as fleshing out the existing biome rather than forking a second one; forking would have meant duplicating `map_generator.gd`'s biome plumbing for no actual design reason.

Delivered: `create_prop.py` gained `image_to_3d` support (Meshy Image-to-3D from real concept art, not just text prompts, mirroring the pattern already proven in the unit pipeline) and a category-correct runtime folder fix (props were all landing in `plot_markers/` regardless of type — now route to `trees/roots/mushrooms/rocks/ruins/decor/plot_markers`). Generated 10 new assets (3 concept-art hero props, 7 variety-pass variants on the thinnest categories) and wired a real tileable ground texture into the low/high ground materials, replacing flat color. Live-verified: `missing_categories=[]`, `fallback_count={}` across all 39 renderer categories.

Not resolved yet: dense blocker clusters still read fairly flat grey-blue at a distance in the verification screenshots, likely because the style profile keeps Meshy's raw PBR texture (`discard_imported_materials: false`) rather than remapping to the profile's curated painterly palette. Flagged as the next experiment in `Terrain_Props_Roadmap.md`, not fixed here — didn't want to flip a global style-affecting flag and regenerate everything without Andrew's eyes on the current result first.

### 2026-08-11 — Art direction: dark-ink low ground / glass-mushroom high ground, deliberately

Auditing the concept art behind [[2026-08-11 — Terrain/props: concept-driven pipeline stood up, treated as one biome not two]] surfaced that it isn't stylistically consistent — a muted "black-ink forest" set (2026-08-10) and a much more saturated "glowing glass mushroom" set (2026-04-19, crystal-cave-adjacent) exist side by side, generated 8 months apart. That's real concept-art drift, and very likely part of why Andrew read the current map as visually inconsistent.

Asked Andrew which to treat as canonical. His call: **keep both, deliberately, split by elevation** — dark-ink for low ground, glass-mushroom for high ground/plateaus — rather than force one direction to win. Reasoning: this gives elevation a second, atmospheric readability channel beyond height alone (low ground grounded/hostile, high ground elevated/touched-by-something-stranger), and it directly fulfills `STYLE_BIBLE.md`'s existing but previously-unimplemented rule that high ground should be visibly separated from low ground.

Documented as `wizard-rts/DARK_FOREST_FRONTIER_V2_ART_BIBLE.md` — the new locked reference (real sampled hex palettes for both tiers, a prompt template, image-to-3D cropping rules) every future prop/terrain prompt must be checked against. `tools/prop_pipeline/style_profiles/dark_forest_frontier_v2_props.json` now points at it and is explicitly scoped as the low-ground-tier profile only; no high-ground profile exists yet.

**Not done yet, by design** — this was a documentation pass, not a generation pass: the high-ground tier has zero real assets (terrain material is still a tinted copy of low-ground), and the two weak props flagged in the prior entry weren't regenerated. Both are the clear next steps, not open questions.

### 2026-08-16 to 08-19 — Terrain/props: full-coverage volume pass, new Lantern Tree category

Ran three generation batches (60 new assets on top of the 39 from 2026-08-11) covering nearly every prop/terrain category that still had 1-3 variants: mushrooms, rocks, roots, ruins, shrines, altars, arches, torches, bone decor, dead trees, road/water decor, cliffs, and ramps. Added a new category, `LANTERN_TREE_BLOCKER` (trees with lantern-shaped hanging pods), wired into `map_3d_renderer.gd`'s placement roll — deliberately routed through the real category-registration path this time, not repeating the earlier `RAMP_MESH` mistake where an asset category existed but was never referenced by the renderer. Every asset's material was verified by reading each GLB's embedded `baseColorFactor` directly against the style profile, not by eyeballing thumbnails; zero material-fallback bugs across all 60.

Also fixed along the way: the Asset Forge gallery's thumbnail renderer was crushing every dark-stone/blood-red prop into an unreadable flat blob (near-black background + weak lights); a stale-row bug left purged procedural placeholders as permanent ghost entries in the dashboard.

Meshy credit balance ended at 50 (from 1810 at the start of this pass) — that's the real ceiling on this pipeline for now, not a stopping choice.

### 2026-08-19 — Architecture: confirmed `map_3d_renderer.gd` is not the shipping renderer, and everything generated against it was invisible in the real game

Andrew pushed back hard on the volume pass above: results were "mid," nothing was visibly changing in the actual game, and it didn't match the reference art style. All three were fair. Root cause, confirmed against `PROJECT_BRIEF.md` (already dated 2026-08-08, quoted verbatim): *"Live gameplay is 2D ... `map_3d_renderer.gd`/`map_3d_preview.gd` is a prototyping tool, not the shipping renderer ... Don't confuse 'there's a polished 3D renderer' with 'the game is 3D.'"* Every prop generated this session (and some from 2026-08-11) went into that non-shipping scene. This was always documented — nobody had re-read it against what the terrain/prop pipeline work was actually doing.

This reframes the terrain/prop pipeline's whole target: assets need to reach `scripts/map/main_map.tscn` (the real 2D game), not `map_3d_renderer.gd`.

### 2026-08-19 — Terrain/props: real 2D art pipeline found already built and already stocked, just never wired up

Investigation of `scripts/map/main_map.tscn`'s actual rendering found two things nobody had reconciled:

1. `scripts/map/map_generator.gd` already has a working terrain-autotile + `Sprite2D` prop-placement system (`_paint_square_grid_map()`, `_apply_connected_ground_and_roads()`, `_paint_visual_props()`/`_try_place_visual_prop()`) — it was just pointed at a placeholder third-party tileset ("Tiny Swords") and had almost no real prop art to draw from.
2. A PixelLab-generated isometric terrain-tile batch for this exact biome — fully scoped, correctly prompted, genuinely good quality, matte-painted and on-palette — had been sitting completely generated and completely unreviewed (`review_status.todo.json: "decision": "unreviewed"`) since roughly 2026-04-26. Nearly four months of paid-for, on-style art doing nothing because generation and review had drifted into two separate, disconnected cycles.

Salvaged the existing PixelLab foliage art plus this session's tree billboard sprites (already flat, transparent, painted PNGs from an earlier attempt) directly into the folders `asset_registry.gd`'s existing `TREE`/`ROCK` mappings already scanned — **zero new asset-pack wiring needed**. Verified live in the actual shipping scene (launched through the real `GameSession.start_new_game` path, not a shortcut): 212 tree props and 710 rock props confirmed rendering, via engine log counts and a direct screenshot. Ground/road/water are still the Tiny Swords placeholder colors — that's the next piece, blocked on a `PIXELLAB_API_KEY` that isn't set anywhere yet.

Also found and fixed a real, live bug while sorting art into those folders: the 3D GLB pipeline and the 2D sprite scanner write into the *same* folder names (`assets_game/props/{trees,rocks,ruins,decor}`), and leftover Meshy debug textures (normal maps, raw JPEG exports) were sitting there getting picked up by the 2D scanner as if they were flat sprite art. Cleaned up this instance; nothing currently stops it recurring on the next 3D-pipeline run — flagged in the new Master Design Doc (§37) as a needed permanent fix, not just a one-off cleanup.

### 2026-08-19 — Design: Master Design Doc adopted

Andrew supplied a full master design doc, hosted at `Studio/01_Design/MASTER_DESIGN_DOC.md`. It sets explicit design targets for both items previously logged as open below — wizard death **and** tower destruction both end the run (§9), and a real roguelike run structure is the literal target: class selection, procedural map, randomized objective, map-discovered upgrades researched back at the tower (§8, §17-18) — not just the procedural/evolution "texture" already in place. Also added §37, flagging the artwork generation pipeline (see the two entries above) as needing structural rework, with animation coverage called out as the single largest gap: only one unit (Oaven Spear) has ever been manually bridged from any generation pipeline into real working 2D gameplay animation.

**Design is now settled on both points; implementation is not yet updated to match** — see Roadmap.

### 2026-08-23 — Engineering: wizard death now ends the run, independent of tower state

First concrete implementation pass against [[2026-08-19 — Design: Master Design Doc adopted]]'s §9 target. Two bugs, found together by tracing the actual code path with a subagent before touching anything:

1. `scripts/wizard.gd`'s lethal-damage handler didn't let the wizard die at all — it redirected 120 damage onto the wizard tower and respawned the wizard at 40% HP with a stun. Wizard death was structurally impossible.
2. `scripts/core/kon_vertical_slice_controller.gd`'s `_check_defeat()` required *both* the tower destroyed *and* no life-archetype wizard alive (`has_tower or has_wizard: return`) — the opposite of the design target, where either loss condition alone should end the run. It also only ever matched `unit_archetype == "life_wizard"`, so the fire and evangalion wizard classes could never satisfy `has_wizard` — a second, independent latent bug masked by the first (as long as the tower stood, defeat never fired regardless).

Fix: `wizard.gd`'s lethal-damage path now calls the inherited `RTSUnit._die()` directly (real death FX/passives, `queue_free()`) instead of the tower-absorb-and-respawn detour. `_check_defeat()` now fires on either trigger going independently, checks all three wizard archetypes via a `WIZARD_ARCHETYPES` const, and emits a new `defeat_triggered(reason)` signal — previously defeat had zero player-facing feedback (a debug print only), asymmetric with victory's `boss_defeated` → HUD countdown. `rts_hud.gd` now listens and reuses the existing victory-return-to-menu countdown, generalized to carry a title/prefix instead of being hardcoded to "Victory."

New smoke test: `scripts/core/wizard_death_defeat_smoke_test.gd` — covers wizard death ending the run while the tower still stands (proves the independent-trigger fix) and a fire-wizard boot not false-triggering defeat at spawn (proves the archetype-matching fix; under the new OR-based logic, that bug would have caused instant defeat on boot for any non-life_wizard class). Ran against the existing `kon_vertical_slice_smoke_test.gd` and `wizard_movement_smoke_test.gd` too — no regressions.

### 2026-08-23 — Design/Engineering: audited the "evolution," "research," and class-roster systems against §16-18, found two of three were disguised

Before picking the next engineering target after the wizard-death fix, audited what the design doc's Priority 2 items (§17 Roguelike Upgrade System, §18 Research, §16 Classes) actually map to in code, rather than assuming from names alone:

- **"Evolution"** (`_gain_evolution_xp()` in `rts_unit.gd`, the evolution bar in the HUD) is automatic per-unit stat/archetype swapping triggered by dealing combat damage (e.g. Terrible Thing → Gripper at an XP threshold) — no player choice, nothing found in the world, no trip to the tower. It reads like the roguelike upgrade system at a glance but isn't one; it's closer to a leveling mechanic.
- **"Research"** (`build_system.gd`'s `research_upgrade()`, gated behind a completed Terrible Vault) is real but shallow: exactly 4 hardcoded flat stat buffs (thorned vines, accelerated evolution, hardened horrors, launcher bile), no choices, no tree, not tied to anything found on the map.
- **Class rosters** (§16, Pillar 7 "Classes Change How You Play") were the actual gap, and a clean one: `barracks`'s `production` list in `unit_catalog.gd` was a single hardcoded array of 6 unit families, identical regardless of which of the 3 wizard classes (`bad_kon_willow`/`hellfire_baby`/`evangalion`) the player picked. Choosing a class only ever changed the wizard's own sprite and combat stats — the entire army was always the same army. Confirmed via grep: no `wizard_class`/`class_id` filter existed anywhere in `unit_catalog.gd` or `build_system.gd`.

Class rosters were picked as the next target over deepening research/evolution: it's a core identity pillar that was **completely** unbuilt (not partially), it's the base a real roguelike upgrade system (future work) would need to differentiate against anyway, and — critically — it's fixable using only the 6 unit families that already exist and already have working art, with zero new art or animation required. Deepening "research" into real upgrade discovery, or "evolution" into a player-facing choice system, would both be real value but are follow-on work, not blocked by this pass.

### 2026-08-23 — Engineering: wizard classes now train different armies

Added `UnitCatalog.CLASS_UNIT_ROSTERS` (`scripts/core/unit_catalog.gd`) splitting the 6 existing KON unit families 2-per-class along their existing flavor text, no new units or art:

- **Bad Kon Willow** (life, the only builder/healer wizard — Bio Mend, tankiest HP): Apex/Champion ("combat healing" already in its role text) + Oaven Spear/Jumper (taunt-based frontline protector).
- **Hellfire Baby** (fire, highest raw damage/lowest HP, aggressive glass cannon): Terrible Thing/Gripper (explosive, sacrificial swarm) + Spawner/Winged Spawner (heavy AoE cannon).
- **Evangalion** (highest sight radius, scout-flavored): Horror/Hunter (fast ranged skirmisher) + Stone Face Serpent (defensive/utility wall-former).

Enforced in both `build_system.gd` production entry points (`produce_unit()`, `produce_unit_from_structure()` — rejects with "Not available for this class") and in `rts_hud.gd`'s barracks button list (out-of-roster units simply don't show a button, rather than showing then rejecting). Buildings (barracks, bio absorber, vault, vinewall, bio launcher) stay universal for this pass — the violation found was specifically about army composition, not base infrastructure, and buildings weren't in scope. AI-owned production (enemy waves, the fortress-arena test mode) is unaffected — confirmed by grep that every real call site of `produce_unit`/`produce_unit_from_structure` hardcodes `player_id=1`; AI factions spawn through an entirely separate path (`WaveDirector._spawn_enemy`).

New smoke test `scripts/core/class_unit_roster_smoke_test.gd` boots all 3 classes and confirms each can train its in-roster units and is rejected for another class's units. Ran alongside `kon_vertical_slice_smoke_test.gd`, `menu_start_smoke_test.gd`, `wizard_death_defeat_smoke_test.gd`, `fortress_ai_arena_smoke_test.gd`, and `kon_outpost_combat_smoke_test.gd` — no regressions.

**Explicitly not done here, and shouldn't be read as "classes are finished"**: each class still only has 2 of the design template's suggested 5-6 unit slots (core/defensive/advanced/elite) — going further needs either creative reuse of what exists or new units, which runs straight into §37's art/animation bottleneck. Buildings, economy twists, and defensive styles are still shared across all classes. This is a first differentiation pass, not the full §16 target.

### 2026-08-23 — Engineering: added a second win-objective type (destroy the outpost garrisons)

Continuing down the roguelike-run-structure gap after the class-roster pass: only one win path existed (`wave_director.boss_has_been_defeated`), against a design doc (§9, §28) that expects the run objective to vary. The needed pieces already existed and just weren't wired to a win condition — `KonVerticalSliceController` already tracks two required outposts and their destruction state (`_outposts_remaining()`), used only to gate the boss spawn, never as a victory condition in its own right.

Added `GameSession.objective_id` (`"defeat_boss"` default, `"destroy_outposts"` new), randomly chosen per new game unless a caller pins one explicitly (matches §8's "randomized or semi-randomized objective," and keeps every existing smoke-test call site working unchanged since the 4th param is optional). `KonVerticalSliceController._check_objective_victory()` fires when `objective_id == "destroy_outposts"` and all required outposts are destroyed, emitting a new `objective_completed(reason)` signal that `rts_hud.gd` wires into the existing victory-return-to-menu flow (the same one [[2026-08-23 — Engineering: wizard death now ends the run, independent of tower state]] generalized for defeat). The boss-defeat path is untouched — the new check only ever acts when the outpost objective is active, and boss defeat still wins independently regardless of which objective is currently selected.

New smoke test `destroy_outposts_objective_smoke_test.gd` pins the objective explicitly, destroys both required outposts, and confirms victory + the signal fire. Ran alongside all 5 other core smoke tests — no regressions (including the pre-existing `kon_vertical_slice_smoke_test.gd`, which now gets a randomized objective per run since it doesn't pin one; confirmed none of its assertions depend on which objective is active).

**Not done**: only 2 of the ~9 objective types §9/§28 describe exist. The remaining ones (seal portals, recover relics, defend a siege, cleanse landmarks) would need new content-plot types or map state that doesn't exist yet — this pass only picked the one objective type buildable entirely from state the game already tracks.

### Open, not yet decided

- **AI-test army mix** — confirm whether the stress-test mode spawning KON-vs-KON is intentional before anyone "fixes" it as a bug.
