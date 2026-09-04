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

### 2026-08-23 — Design: told to default to WC3 design logic when a call is needed and Andrew isn't around to weigh in

Andrew's instruction, given as a standing default rather than a one-off: **"if in doubt, follow WC3 design logic."** Applied immediately to the next open question (how to build the roguelike upgrade layer §17-18 asks for). WC3's actual hero model is XP from combat → level up → player picks which of the hero's own abilities to rank up (or a generic stat option if the hero has no more to pick from) — a materially different shape than "buy any of 4 flat buffs outright with resources" (the existing Terrible Vault research) or "random loot drops." Used that shape, not a from-scratch design, for the pass below.

### 2026-08-23 — Engineering: wizard hero leveling, WC3-style — first real player-choice-driven progression for the wizard

The [[2026-08-23 — Design/Engineering: audited the "evolution," "research," and class-roster systems against §16-18, found two of three were disguised]] audit found the wizard itself (the actual hero, §10) had zero progression of its own — the "evolution" system only ever applied to trained mob units, automatically, with no choice. Fixed by adding a separate, hero-specific leveling system to `wizard.gd` rather than overloading the generic per-unit evolution field (that field's automatic-swap semantics don't fit a player-choice mechanic, and reusing it would have put hero leveling at risk of interference from unrelated evolution-tuning changes elsewhere in the catalog):

- Wizard gains XP from its own combat (damage dealt and kills, via a new 2-line hook in `rts_unit.gd`'s shared `take_damage()` that credits any source exposing a `_gain_wizard_xp` method — generic and inert for every other unit, not wizard-specific plumbing bolted into the base class).
- Levels 1-6, WC3-shaped exponential XP curve. Each level-up sets a pending choice rather than applying anything automatically — the player must act, mirroring WC3's hero skill-point panel.
- **Bad Kon Willow** (the only class with named spells — Bio Mend, Seal Away, Observer Aura) picks one of its three spells to rank up per level, scaling real existing numbers: Bio Mend's heal (+25/rank), Seal Away's stun duration (+1.5s/rank), Observer Aura's ally range bonus (+16/rank). **Hellfire Baby and Evangalion** (no named spells in the catalog — a real, pre-existing content gap, not something this pass could fix without inventing new spell behavior) fall back to a generic 3-way stat choice (Power/Vitality/Swiftness), matching WC3's own "no more ranks available, take +stats" fallback pattern rather than leaving those two classes without any progression at all.
- HUD shows the choice as buttons when the wizard is selected and a choice is pending (mirrors the existing barracks-button pattern); the buttons disappear once chosen. Wired into the existing per-frame selection poll rather than a new signal-driven UI path, since one already existed and worked.

New smoke test `wizard_leveling_smoke_test.gd` covers both the spell-choice and stat-choice paths, and specifically exercises the real combat hook (spawns a Deom enemy and calls `take_damage` on it) rather than only calling the XP function directly, so a regression in that wiring would be caught. Ran alongside all 7 other core smoke tests — no regressions.

**Known limitations, not fixed here**: `pending_level_up` is a single flag, not a queue — an XP grant large enough to cross multiple level thresholds at once collapses into one pending choice, not several (realistic gradual combat XP won't hit this; only relevant to artificial mass-XP testing/debug tools). Damaging enemy *structures* doesn't grant wizard XP yet (`KonStructure` has its own separate `take_damage()`, not the `RTSUnit` one the hook lives in) — only unit kills/damage do. Fire Wizard and Evangalion still have no spell identity of their own, so their "upgrades" are stats-only until they get real named abilities — a content gap, not something patchable at the engineering layer.

### 2026-08-23 — Engineering: map-discovered wizard relics, WC3-style creep-camp item drops

Closed the other half of §17's "found on the map" language (the leveling pass above covers the "player chooses" half). Reused WC3's own shape rather than the level-up mechanic's shape: destroying a required outpost or clearing a content plot now automatically grants the wizard a permanent upgrade via `wizard.grant_relic_upgrade()` — no player choice, applied immediately, exactly like picking up a WC3 Tome of Strength off a dead creep camp. This is deliberately a different interaction than [[2026-08-23 — Engineering: wizard hero leveling, WC3-style — first real player-choice-driven progression for the wizard]]'s level-up choice: leveling is a decision the player actively makes; relics are automatic rewards for going out and clearing the map, directly reinforcing §13's "the player should want to leave the base because the best resources, upgrades... are outside the starting area."

Hooked into `KonVerticalSliceController._on_outpost_destroyed()` and `_check_content_clear()` via a new `_grant_wizard_relic(reason)` helper — every one of the ~8 map objectives on the current vertical slice grants a relic, no drop-chance roll (the map only has a small, curated set of objectives, not a spammy loot table, so a guaranteed drop was the right call rather than inventing a percentage).

**A real bug was caught here, not just written and shipped**: the first version of `grant_relic_upgrade()` had a GDScript static-typing error (`var chosen := option if options.has(option) else options[randi() % ...]` — mixing a `String` with an untyped `Array`'s `Variant` result, which GDScript's `:=` inference can't resolve). This wasn't a subtle behavioral bug — it was a **script compile failure that broke wizard spawning entirely**, caught immediately by the new smoke test for this feature (not by the 8 other smoke tests, none of which happened to touch the changed function) before it was committed. Fixed by explicitly typing the variable. Directly the scenario `Unattended_Work_Definition_of_Done.md` exists to prevent — a change that looked reasonable wasn't actually run until its own dedicated test existed.

New smoke test `wizard_relic_smoke_test.gd`. Ran alongside all 9 other core smoke tests after the fix — no regressions.

### 2026-08-23 — Engineering: Terrible Vault research is now tiered, WC3-style

Last piece of this session's roguelike-upgrade push. The Terrible Vault's research was a one-shot boolean per upgrade (`researched_upgrades: Dictionary`, `has(upgrade_id)`) — buy it once, done forever, no depth. WC3's actual Blacksmith/Arsenal upgrades are tiered instead: Melee Weapons/Armor go through 3 ranks, each strictly better and more expensive, each requiring the previous rank. Converted `hardened_horrors`, `thorned_vines`, and `launcher_bile` to 3-rank upgrades this way (escalating cost: rank *1.0/1.6/2.2*); left `accelerated_evolution` as a single-rank upgrade since a repeatable "grant flat XP" doesn't have a natural tiered shape, matching WC3's own mix of tiered upgrades alongside one-shot unlocks (e.g. Runed Bracers).

`researched_upgrades` (boolean dict) was replaced outright with `researched_upgrade_ranks` (int dict) rather than kept alongside it — grepped every usage first and confirmed all of them were internal to `build_system.gd`, so there was no external caller to preserve compatibility for. The three live-read effect sites (vinewall regen, bio launcher damage/radius, both computed fresh each tick/shot) needed only a one-line change each to scale by rank instead of a flat bonus. The one baked-once-per-unit effect (`hardened_horrors`'s +HP/+damage to Horrors) needed real care to stay idempotent across multiple rank purchases: tracks the *rank already applied* per unit via `set_meta`, not a boolean, and applies only the delta between the last-applied rank and the current one — verified in the new smoke test by calling the apply function twice in a row and confirming the bonus isn't double-counted.

New smoke test `tiered_research_smoke_test.gd` checks escalating cost across 3 ranks, rejection past max rank, that the single-rank upgrade still rejects a second purchase, and the idempotent-application behavior directly. Ran alongside all 10 other core smoke tests — no regressions.

**Not done**: only 3 of the 4 existing research upgrades got tiers (by design, see above) — this doesn't add new research *categories*, just depth to what already existed. The bigger remaining gap, not attempted here, is unifying the now-4 separate progression systems (evolution, wizard leveling, wizard relics, tower research) into something closer to §17's actual examples of upgrades that "change what you want to build next" rather than stack flat numbers — a design lift, not an engineering task.

### 2026-08-23 — Engineering: content plots now pay differentiated rewards by their existing archetype tag

Andrew: "just keep building off the master doc." Picked this next because it was a confirmed, cheap-to-close gap from the earlier systems audit: `_check_content_clear()` paid every content plot the exact same flat 180 Bio / 1 Essence / guaranteed relic, regardless of type — despite map generation already tagging each plot with a real narrative-flavor archetype (`content_archetype`: ruin, shrine, cache, crossroad, camp, ambush, landmark, encounter) that was being read for placement and then thrown away at reward time. §22 wants "risk, reward, choice, narrative flavor" per plot; this uses data that already exists rather than inventing new map-gen work.

Added `_content_reward_for_plot(archetype)` in `kon_vertical_slice_controller.gd`, string-matched against the existing tag: landmark (the plot with a real 3-floor dungeon structure already) pays the most and always grants a relic; shrine is relic-guaranteed but Bio-light (a magical site, not a resource site); cache is the opposite (heavy Bio, never a relic — it's just loot); ruin/camp/ambush/encounter sit in between with partial relic odds; crossroad is a deliberately minor waypoint reward. Unrecognized archetypes fall back to the old flat default, so nothing breaks if map generation ever adds a plot kind this table doesn't know about yet.

**A stale test assumption surfaced immediately, not a game bug**: `wizard_relic_smoke_test.gd` (from earlier this session) assumed content-plot clears always granted a relic, which was true before this change and is no longer true by design (cache/crossroad now never do, others are probabilistic). Fixed the test to target a shrine/landmark plot specifically (the two archetypes with a guaranteed relic) instead of asserting on whatever plot happened to be first — this is the correct fix, not a workaround, since the test's actual job is verifying the relic-granting *hook* fires, not re-asserting the old flat-reward behavior this same session just replaced on purpose.

New smoke test `content_plot_reward_variety_smoke_test.gd` checks the reward table's relative ordering (landmark > cache in Bio, shrine/cache have opposite relic odds, crossroad is minor, unknown archetypes fall back) and one real end-to-end plot clear paying exactly its expected reward. Ran alongside all 11 other core smoke tests, including the fixed relic test 3x to confirm it's no longer flaky — no regressions.

### 2026-08-23 — Engineering: a third win-objective type, "survive the siege" — and a real bug caught in the test, not the game

Added `OBJECTIVE_SURVIVE_SIEGE` ("survive_siege") alongside defeat_boss/destroy_outposts: win by surviving `SIEGE_SURVIVAL_SECONDS` (90s) after the boss spawns, instead of needing to kill it — §9's own "survive a final siege" example, and a genuinely different *feel* (defensive/passive) from the other two (proactive/offensive), directly serving §28's "the same map should feel different with different objectives." Reuses all existing boss-gate/spawn infrastructure unchanged; only what counts as "win" after the boss arrives is new. `GameSession.OBJECTIVE_IDS` now has 3 entries.

**Caught a real design flaw in the implementation while writing its test, before it shipped**: the first version used `_siege_started_msec: int = -1` as both the timestamp *and* the "has it started" sentinel (`< 0` meant not-started). That's fine for real gameplay, but it meant the value could never legitimately be tested by simulating elapsed time without accidentally going negative and being misread as "not started" again — which surfaced as an actual infinite mini-loop in the smoke test (the siege keeps "beginning" every check instead of ever completing). Rather than write a more contorted test to route around it, decoupled the state into a separate `_siege_started: bool` flag plus a plain `_siege_started_msec: int` that no longer carries dual meaning — the correct fix, since the original design conflated "has this started" with "what value does this timestamp hold," which is exactly the kind of bug that's invisible until something actually exercises the boundary.

New smoke test `survive_siege_objective_smoke_test.gd` triggers the boss directly (`trigger_boss_now`), confirms the timer doesn't start early, confirms it doesn't win prematurely, then simulates the survival duration elapsing and confirms victory + the signal fire. Ran alongside all 12 other core smoke tests — no regressions.

### 2026-08-23 — Engineering: a first Day/Night cycle, deliberately narrow in scope

§25 was entirely unbuilt — `PROJECT_BRIEF.md` already listed it as "documented intent only." Rather than build the full effect list §25 describes (vision, merchant activity, undead strength, special resources, bosses/events), picked two low-risk, already-existing knobs to avoid destabilizing tuned systems: **economy income rate** (Day +15%, Night -15%, via a new `EconomyManager.income_multiplier` applied in `_apply_income()`) and **outpost-defender composition** (Day 1/3 chance of the tougher `deom_crosshirran`, Night 55% — replacing a fixed `spawn_count % 3 == 2` pattern with a day/night-weighted roll that preserves the old average during Day). Deliberately did **not** touch `WaveDirector`'s spawn cadence (already tuned and stress-tested this project's own performance work depends on) or re-enable fog of war (explicitly flagged in `PROJECT_BRIEF.md` as intentionally disabled on `seeded_grid_frontier`) — both would have been real design/perf risk for a first pass, not just an engineering change.

Directly serves §25's actual design intent even at this scope: "Night should feel dangerous but rewarding. The player should prepare for night and use day to make progress" — Day now literally rewards banking economy, Night literally punishes turtling through it. 120s Day / 90s Night cycle, shown in the existing overlay label.

New smoke test `day_night_cycle_smoke_test.gd` drives the cycle with large synthetic deltas (no need to wait 210 real seconds) and confirms both hooked multipliers flip correctly in both directions. Ran alongside all 13 other core smoke tests — no regressions.

**Not done**: this doesn't touch vision/fog, enemy type unlocks, merchant activity, or any of §25's other listed effects — those need either fog of war (a separate, currently-disabled system) or merchants/quests (which don't exist yet at all, see §23). Flagged as future depth, not attempted here.

### 2026-08-23 — Bugfix: two real performance regressions from this session's wizard-leveling work, caught while Andrew was live-testing

Andrew reported lag after playing a run with everything from this session's roguelike-upgrade push. Two genuine regressions found, both from the wizard-leveling feature specifically:

1. **`RTSUnit.take_damage()`** (fires on every hit, every unit, the hottest path in the whole combat sim) called `source.has_method("_gain_wizard_xp")` unconditionally. First fix attempt (`class_name Wizard` + an `is Wizard` type check, expected to be cheaper than reflection) **broke the game outright** — a base class referencing a subclass's `class_name` created a circular class-resolution failure that failed to parse *every* unit script, not just the wizard's. Caught immediately by the smoke suite (parse errors, a hung test run) before it was ever committed. Fixed instead with a plain `StringName` property read (`source.get("unit_archetype")` against the 3 known wizard archetypes) — no cross-class reference needed, and `has_method()` now only runs for the rare actual-wizard case.
2. **`rts_hud.gd`'s `_selection_signature()`** — the change-detection check behind the HUD's selection panel, runs every frame for every currently-selected unit. Had a `_has_property()` call added to detect wizards, which does a full `get_property_list()` reflection scan. This one is worse than #1: it fires constantly regardless of whether anything is even happening, scaling with selection size, not combat activity. Replaced with the archetype check the function already computed anyway.

Neither would have been caught by the existing smoke suite on their own merits — smoke tests check correctness (does the right thing happen), not performance (how expensive is it). This is exactly the gap `Unattended_Work_Definition_of_Done.md`'s evidence check doesn't cover yet for code changes; noted as a real gap, not fixed here — the current bar is "smoke tests pass," and passing correctly while being slow is invisible to that bar.

**Lesson for future sessions**: this project already has a documented performance culture (LOD rendering, batched movement, ~3000-unit stress tests) — any new hook added to `RTSUnit`'s combat resolution or per-frame HUD update paths needs to be evaluated for hot-path cost, not just correctness, before it ships. `has_method()`/`get_property_list()` reflection is the specific pattern to watch for; a plain property read or an already-computed value is almost always available instead.

### 2026-08-26 — Design: corrected — Wizard RTS targets hundreds of units, not dozens

`MASTER_DESIGN_DOC.md` §5 said "Dozens of units, not hundreds" since it was first pasted into the vault. Andrew corrected this directly: the actual target is hundreds of units on screen, the opposite of what was written. Fixed §5 to say so, and reframed the accompanying "tactical, not high-APM" line — at hundreds of units that now means leaning on strong control tooling (control groups, army-wide orders, smart formations) to keep it manageable, not treating scale itself as the thing to avoid.

**No new engineering risk here** — this doesn't require new work to become possible. The existing LOD/rendering fix (2026-08-09) was already stress-tested to ~3000 units with a worst-case frame stall of 40 FPS (up from 2 FPS pre-fix); the engine ceiling was never the constraint, the design doc's stated target was just wrong. This also directly raises the priority of real control-group/army-management UX (see the QOL research prompt drafted the same day) — that tooling matters *more*, not less, once "readable at a glance" has to hold at hundreds of units instead of dozens.

### 2026-08-31 — Engineering: army-control QOL pass (control groups, hero/army keys, idle cycling, type filtering) — plus the LOD hole it would otherwise have opened

Direct follow-on from the 2026-08-26 §5 correction. With the target confirmed as *hundreds* of units and the design explicitly leaning on "strong control tooling rather than twitch reflexes," the game's input layer was the actual bottleneck: `selection_controller.gd` had drag/click select, attack-move, patrol, hold, stop, rally points and formation offsets, and **no control groups and no cycling of any kind**. Selecting a specific part of a 300-unit army meant a mouse drag, every time.

**Researched first, then filtered rather than ported.** Surveyed what SC2, AoE4, CoH3, Stormgate, They Are Billions, Northgard and Homeworld 3 actually ship. Three things from that survey were deliberately *not* built, because they don't fit this game's shape:

- **Idle-worker keys (SC2 F1 / AoE4 `.`)** have no analogue — Wizard RTS has no worker units at all; the economy is `bio_absorber` buildings ticking income. The thing that key *solves* (unspent economy) maps here onto **idle production buildings**, and the thing that actually leaks at scale maps onto **idle army stragglers**. Both got a key; "idle villager" did not.
- **Tactical pause (CoH3/Homeworld 3)** is a single-player pacing tool that would collide with the wave-timer/day-night systems already tuned around real-time pressure. Not attempted.
- **Northgard's answer (delete army micro entirely, micro the base instead)** is the opposite of §29's tactical pillars. Rejected as a direction, but it's the right reminder that the goal is fewer required actions, not more available ones.

**What shipped** (`scripts/input/control_group_manager.gd` new; `selection_controller.gd`, `keybind_manager.gd`, `build_system.gd`, `rts_hud.gd`, `pause_menu.gd` extended — no new autoloads, no scene changes, no parallel input system):

- **Control groups 1-9**, SC2/WC3 contract: `Ctrl+N` assign, `Shift+N` add, `N` recall, double-tap `N` snaps the camera to the group's centroid. Digits stay hard-bound (as they are in WC3, SC2 and AoE4); everything else went through `KeybindManager` and is therefore rebindable in the existing pause-menu Key Binds tab for free.
- **Auto-cleanup on death**, via each grouped unit's `tree_exiting` signal — not a per-frame scan. Ungrouped units cost nothing. This is what makes control groups usable at all with a roster that is deliberately disposable.
- **F1 select wizard / double-tap to snap** (WC3's hero key) and **F2 select army**. F2 **deliberately excludes the wizard**: wizard death is an independent loss condition (§9), so a key that could sweep the hero into an attack-move is a trap, not a convenience. Hero on F1, swarm on F2, never blurred.
- **F3 cycle idle Barracks**, **F4 cycle idle army units**, both selecting and snapping the camera.
- **Tab / Shift+Tab filter the selection by unit type** — WC3's subgroup cycling, per this project's standing "if in doubt, WC3" default. Adapted to be **non-lossy**: it walks *full selection → type A → type B → … → full selection*, so cycling around restores what you had, rather than WC3's second parallel "active subgroup" concept which would have to be threaded through every consumer of `selected_units`.

**The genuinely Wizard-RTS-specific piece: the reinforce group.** In SC2 a control group is a mostly-stable set you build once. Here the army is a *stream* — cheap units that die constantly and evolve in place — so "select the new units, Shift-add them to group 1" is a loop the player would run every thirty seconds forever. That is precisely the per-minute APM tax §5 says to design out. `Alt+N` flags one group as the reinforce target; units finishing training join it automatically (via a new `BuildSystem.unit_trained` signal that carries the node — `unit_produced` was left untouched so existing listeners are unaffected), and are sent to that group's **live centroid**, so reinforcements walk to where the army actually is rather than to a rally point set three fights ago. Event-driven end to end; nothing polls.

**The performance finding, which is the part worth reading.** Building this surfaced a real hole that the feature itself would have made trivially easy to fall into. `selected` was a **blanket exemption from every mass-LOD optimisation**: `mass_unit_multimesh_renderer.gd` force-promoted every selected unit to full detail regardless of distance, `set_central_mass_movement_active()` refused to run while selected (pulling units back off `RTSWorld`'s budgeted central movement loop), `_mass_simulation_delta()` skipped the physics stride, and `RTSUnit._process()` redrew every frame. All four are fine when "selected" means a dozen units — and all four turn **one press of F2 at 300 units into a lag switch**, silently undoing the 2026-08-09 LOD and batched-movement work.

Fixed by making the exemption size-aware: `RTSWorld.selected_unit_count` (a plain int, written once per selection change) plus `RTSWorld.BULK_SELECTION_THRESHOLD` (48). At or below the threshold — a hand-managed squad — behaviour is exactly as before. Above it, selected units keep normal mass-LOD treatment and still draw their selection ring on the tier's throttled cadence. `use_mass_vector_lod()` was deliberately **left alone**: it only applies to the AI stress arena, and hiding art for bulk-selected units would be a visual change headless tests cannot verify.

Cost discipline throughout, given the 2026-08-23 regression: the new manager has no `_process` at all; the HUD's control-group strip refreshes on a `groups_changed` signal rather than per frame; every idle/army scan is reachable only from a key press. **Three pre-existing `get_property_list()` reflection scans were also removed from paths this work makes hotter** — `_is_player_selectable()` (ran once per selectable node per selection change) and the two `selection_radius` lookups in the right-click attackable scan (ran over every unit on the map on every right-click) — all replaced with plain `get()` reads guarded against null. `has_method()`/`get_property_list()` appears nowhere in the new code.

One small input fix went with it: HUD buttons now use `focus_mode = FOCUS_NONE`. Without it, clicking a build button hands it keyboard focus, Godot's built-in `ui_focus_next` eats Tab before `_unhandled_input` ever sees it, and Space/Enter re-fire the last button pressed — the classic RTS-HUD input-stealing bug, and it would have broken the new Tab binding outright. The Key Binds tab also became a `ScrollContainer`, since the bindable-action list went from 4 to 9.

**Tests**: three new smoke tests, all booting the real `scripts/map/main_map.tscn`. `control_group_smoke_test.gd` (assign replaces / add unions / recall selects, death auto-cleanup across multiple groups, reinforce absorption + live-centroid rally + enemy-owned units rejected + exclusivity), `army_selection_hotkeys_smoke_test.gd` (hero key, army key excluding the wizard, both idle cyclers including the negative cases — a unit on hold isn't idle, a Barracks with a queue isn't idle production — and non-lossy subgroup cycling in both directions), and `bulk_selection_lod_smoke_test.gd`. That last one is the notable one: **it is a correctness test standing in for a cost property**, which is exactly the gap the 2026-08-23 entry flagged as uncovered ("passing correctly while being slow is invisible to that bar"). It asserts that a squad-sized selection keeps its full-fidelity exemptions and an army-sized one does not.

Whole suite run: **42 of 43 pass**. The one failure, `seeded_grid_frontier_smoke_test.gd` ("connected road arteries spanning west/east and north/south"), is **pre-existing and unrelated** — reproduced identically on a clean worktree at `d9576ec` before any of this work. Logged on the Roadmap; not fixed here, since map generation is nowhere near this change and it deserves its own look. Stress suite unchanged (`fortress_ai_arena_stress_test` passes at 3070 live units, combat 5.1ms).

**Not done, deliberately**: no army-wide stance system (§29 territory, and a real design decision about what stances even mean for evolving units — not an engineering gap to fill unasked); no camera-location hotkeys (Ctrl+F1-F4 in SC2/Stormgate) since double-tap-to-snap covers the common case at this map size; no queued/shift-chained orders; control-group digits are not rebindable.

### 2026-08-31 — Design + Engineering: the KoN faction doc is now the live faction

Andrew supplied the in-progress KoN roster document (`KoN (1).pdf`, 4 pages plus 4 concept-art plates). It is the first real faction bible this project has had, and auditing it against the code found the live game was implementing a *different* faction: the doc's KoN is Kon plus Oaven (T1) → Stone-Faced Serpent (T2) → Spawner (T3) → The Forbidden (T4), while `CLASS_UNIT_ROSTERS` gated Bad Kon Willow to `[apex, champion, oaven_spear, oaven_jumper]` — apex appears nowhere in the doc, and the Serpent and Spawner belonged to the other two wizard classes.

**Two scope calls put to Andrew before any code moved**, because both changed the shape of the work:

1. **Roster** — aligning Kon to the doc takes the Serpent off Evangalion and the Spawner off Hellfire Baby. Andrew's call: **doc wins, units shared**. Kon gets the doc's roster exactly; the other two classes keep what they had rather than being stripped. Per-class exclusivity (§16) becomes a later balance pass once Evangalion and Hellfire Baby have roster docs of their own. Logged here so nobody "fixes" the sharing later thinking it was an oversight.
2. **Art** — `PIXELLAB_API_KEY` is still unset (only `MESHY_API_KEY` exists, and that is the deprioritized 3D path), and the Oaven, Serpent and Spawner have **no sprite sheets at all** — they render as procedural vector art. Andrew's call: **do everything possible without a key**, and log what stays blocked.

#### What the doc said that the code did not do

Gaps found and closed, each traceable to a line in the doc:

- **Tier gating did not exist.** All six units trained from the first Biospawner. Now `BuildSystem.unlocked_tier()` gates production: tier 1 free from the first minute, tier 2 and 3 behind new **Observer Vault** research (`tier_two_hybrids`, `tier_three_hybrids`, the latter requiring the former), with `grant_tier_unlock()` as the doc's second route in — "finding upgrades on the map".
- **The Bio Absorber's heal aura was a button that did nothing.** `upgrade_choices: [heal_aura, bio_launcher]` existed in the catalog and the HUD had a "Heal Aura" button, but *nothing anywhere read the result* — picking it was a no-op. The doc says absorbers "naturally slowly heal units and buildings in a large radius" as a baseline, with the upgrade on top. Both now exist (`_update_absorber_heal_auras`, 1Hz, baseline 2 HP/s at 460px, upgraded 6 HP/s at 720px), and structures mend as well as units.
- **The Oaven had no blowpipe.** The doc's tier-1 unit "can switch between either a spear or a blowpipe". Implemented as a `weapon_modes` stat overlay on the archetype rather than two archetypes, so evolution, XP, control groups and the unit card all keep treating it as one unit. Swapping costs a beat of attack uptime, so it is a decision rather than a free toggle.
- **The Bio Launcher could not attack ground and could not be switched off.** The doc gives it both. Manual fire reuses the same click-a-point cursor attack-move and patrol already use rather than adding a second targeting mode; auto-fire defaults on, so existing behaviour is unchanged unless the player turns it off.
- **The Forbidden did not exist.** Tier 4, unleashed from the Observation Tower for 900 Bio, never trained. The doc is explicit that it "will not obey Kon and will turn it's wrath on all", so that is enforced *structurally* rather than by an AI rule: it spawns under `owner_player_id = 0`, an owner slot no faction uses. Every hostility check in this codebase is a plain `owner_player_id != my_owner` comparison, so it is automatically hostile to the player who paid for it, to the Deom Legion, and to anything added later — with no special-casing anywhere. It is also physically unselectable, because `SelectionController._is_player_selectable()` only accepts owner 1.
- **Building names contradicted the doc.** Barracks → **Biospawner**, Terrible Vault → **Observer Vault**, Wizard Tower → **Observation Tower**. Display names and blurbs only; the archetype keys are unchanged so no save, scene or test wiring breaks.
- **The duo colour scheme was unimplemented.** The doc splits KoN into an *observer* theme (black/silver — Kon, the tower, the vault) and an *evolution* theme (#67BED9 / #a95766 — every hybrid, the Vinewall, the Bio Launcher, the Bio Absorber), with the Biospawner as "the only building where these two themes cross over". Each archetype now carries a `kon_theme` tag, and `team_primary/secondary/accent_color()` resolve against it. Cached at spawn, not looked up in `_draw()`.

#### Unit cards

The doc is a stat sheet, so the game needed somewhere to show one. The existing "Unit Stat Sheets" window was upgraded into real unit cards — **concept-art portrait, tier badge with live LOCKED state, faction-themed accent, flavour blurb, weapon modes, evolution chain, and an explicit "UNCONTROLLABLE" line for the Forbidden** — and wired to a **Roster** button on the Biospawner's own command panel, which is where a player actually asks "what can I build". The four concept-art plates were extracted from the PDF, cropped to 512² portraits under `assets/ui/unit_cards/`, with the full-resolution sources kept alongside in `art/concept/kon/` as the pipeline inputs of record.

#### Art: what shipped, what is still blocked

Shipped without any API key: the four portraits, the doc's exact palette applied across every KoN unit and building, and a **redraw of the Serpent's and Spawner's in-game procedural art against the concept plates**. Those two were previously featureless lumps — verified in the before screenshot. The Serpent is now a segmented stone-plated body with #a95766 seams, a plated skull with the concept's single rose eye, and translucent wings that scale with its five growth stages; the Spawner is a bone-plated insect over a rose underbelly with six legs, antennae and wings that spread when it evolves into the Winged form.

**Still blocked, and the honest limit of this pass**: real sprite sheets and directional animation frames for Oaven, Serpent, Spawner and the Forbidden. Everything above is vector art drawn in `_draw()`. This needs `PIXELLAB_API_KEY`, which has now been unset for long enough to be the single biggest constraint on this project's art — it also still blocks the ground/road/water tiles from 2026-08-19. §37's animation gap is untouched by this pass.

#### Evidence

New `kon_faction_mechanics_smoke_test.gd` covers every mechanic above — tier gates in both directions including the tier-3-requires-tier-2 rule, weapon swap stats and uptime cost, heal aura in and out of radius, launcher auto/manual including an out-of-range rejection, the Forbidden's ownership/stats/aggression, and the unit-card builder run across ten archetypes asserting the portraits actually resolve. `class_unit_roster_smoke_test.gd` was updated, not worked around: it asserted `apex` was in Kon's roster, which was true before and is deliberately false now — the same class of stale-assumption fix as the relic test on 2026-08-23.

Visual evidence comes from the real shipping scene per the DoD, via a new `scripts/tools/kon_faction_screenshot.gd` (a windowed verification tool, deliberately **not** part of the headless suite): it boots `scripts/map/main_map.tscn` as a Bad Kon Willow run, stands up the base, spawns the roster and saves both a battlefield shot and a unit-card shot.

Suite: **43 of 44 pass**. The one failure, `seeded_grid_frontier_smoke_test.gd`, is the pre-existing road-artery failure already logged on the Roadmap — unrelated and unchanged.

#### Not done

No tower garrison (the doc's "Kon can garrison inside to build his base ... to provide auras, buffs while microing") — it needs a real decision about what happens to a garrisoned hero's selection, orders and death, which is design, not engineering. No free-upgrade-over-time on the Biospawner beyond the `auto_evolves` timer it already had. Observer research beyond the tier gates (`observer_sight`, `observer_oversight`) is costed and researchable but its effects are not yet wired to sight radius or aura strength — the gates were the part that made the faction playable. The Forbidden has stats, behaviour and a bespoke silhouette but no concept art of its own; the doc does not include a plate for it.

### 2026-08-31 — Performance: the in-game freezes were one flow-field rebuild costing 1.27 seconds

Andrew reported "a ton of lag, freezes to be specific" and exported telemetry. The export (`test_exports/session_data/20260831 180830_seeded_grid_frontier_13703`, a 386-second real play session) identified it exactly, and the answer was not what the symptom suggested.

**The session was mostly fine.** Median FPS was a flat 60, at 40-98 units — nowhere near this project's scale targets. What the player felt was 36 separate freeze samples, several of them a full second of frozen frames.

**The measurement that found it**: in every spike sample, `physics_ms / flow_field_recomputes` came out at **~1270ms**, at unit counts ranging from 23 to 81. Samples with two recomputes showed 2539ms; three showed 3783ms and 3846ms. A cost that lands on an exact per-unit-of-work quantum, independent of unit count, is a single fixed operation — not load. One flow-field rebuild = one ~1.3 second frozen frame. Reproduced on the live map at **1221ms** before touching anything.

The trigger is ordinary play: the flow-field cache is keyed on `_path_cache_version`, so **every building or Vinewall placed** invalidates it, and the next enemy wave to ask for a route pays the full rebuild inside the physics frame.

#### Why nothing caught it

- `flow_field_smoke_test.gd` passed throughout. It checks that units make measurable progress toward their target — a correctness question. It has no opinion about how long the field took to build.
- The stress suite scales *unit count*. This cost scales with **map area**, and is completely flat in unit count. Pushing to 3000 units would never have surfaced it.

This is precisely the gap the 2026-08-23 entry named and left open: *"smoke tests check correctness (does the right thing happen), not performance (how expensive is it) ... passing correctly while being slow is invisible to that bar."*

#### What was actually wrong — four things, in order of what they cost

1. **The Dijkstra frontier was a linear-insert sorted `Array[Dictionary]`.** Every relaxation did an O(n) scan plus an O(n) `Array.insert()` memmove and allocated a Dictionary per queue entry. Replaced with a binary min-heap over parallel packed arrays, no per-entry allocation.
   *A caution worth recording*: the first version of the heap used `PackedFloat32Array` for costs. The field still built, the tests still passed, and it was 2× faster — but it silently reached **3384 cells instead of 7017**. The float32-rounded cost read back off the heap compared as greater than the float64 value in the cost map, so the stale-entry check discarded valid expansions. It looked like a win and was a correctness bug. `PackedFloat64Array` throughout.
2. **`_is_path_traversable_cell()` was recomputed from scratch on every call** — and `_is_unramped_height_edge()` behind it loops every ramp rect twice (margins 1 and 4) and every plot rect, allocating `Rect2i`s. `_flow_field_neighbors()` calls it up to 16 times per expanded cell, so one field did millions of them.
3. **Memoising it was not enough on its own**, which is the interesting part. A memo cleared by `_invalidate_path_cache()` is dropped every time a building goes down — exactly the moment the field rebuilds — so it only moved the cost. The fix was to **split static from dynamic**: terrain shape (height edges, ramp proximity, plot rects, the neighbour sets themselves) is memoised for the life of the map, and runtime blockers are re-applied per edge as a dictionary lookup during expansion. Terrain does not change because something was built on it.
4. **Costs moved to a flat `PackedFloat64Array`** indexed `x * MAP_H + y` instead of a `Vector2i`-keyed Dictionary.

**Result: 1221ms → 79ms steady-state** (the first build on a fresh map is ~150ms while the terrain memos fill). Same 7017 cells reached, same routes.

#### A correctness fix that came with it

`_is_unramped_height_edge()` used to test `is_walkable_cell()`, which accounts for runtime blockers, on both the cell and its neighbours. So dropping a Vinewall beside a cliff edge made the neighbour loop skip that cell and could report the edge as *not* an edge — **building a wall next to a cliff could make the cliff walkable**. It now tests terrain only. That is what made the static memo possible, and it is the correct behaviour independently.

#### Evidence

New `flow_field_cost_smoke_test.gd`, which asserts on **time as well as behaviour** — the pattern the 2026-08-23 entry asked for. It measures a rebuild after a path-cache invalidation against a 400ms budget (generous against the 79ms measured, tight against the 1221ms before), and separately proves blockers still work now that neighbour sets are cached without them: a fully walled target reaches only itself, removing the wall restores the exact original reachable set, and a diagonal step between two blocked cells stays closed. Reported at **73.3ms** on this machine.

`scripts/tools/flow_field_bench.gd` added as a profiling tool (windowed or headless, not part of the suite) for anyone measuring this again.

Suite: 44 of 45 pass; the failure is the pre-existing `seeded_grid_frontier_smoke_test.gd` road-artery bug already on the Roadmap.

#### Not fixed: a second, separate cost

Excluding the freeze frames entirely, the same telemetry shows a real sustained problem that is **not** the flow field and was not touched here:

| units | median fps | process_ms | combat_tick_ms | path_requests/s |
|---|---|---|---|---|
| 0-19 | 60 | 13.4 | 0.1 | 0 |
| 20-39 | 60 | 10.4 | 0.9 | 11 |
| 40-59 | 56 | 27.4 | **18.6** | 54 |
| 60-79 | 58 | 28.5 | 20.1 | 130 |
| 80-99 | **47** | 30.8 | 22.8 | **370** |

Two things stand out. `combat_tick_ms` jumps 20× (0.9 → 18.6ms) for a 1.7× increase in units, which is a step change rather than a scaling curve and needs its own look. And path requests reach 370-540/second at 70-90 units — roughly 5-6 repaths per unit per second, which is a repath storm regardless of the 97% cache hit rate. **At 40+ units the game is already spending more than a 60fps frame budget in `process`**, which matters a great deal given §5's target of hundreds. Logged on the Roadmap as the next performance item; deliberately not rushed into the same pass as the freeze fix.

### 2026-08-31 - Bugfix: three stat-pipeline bugs, found by explaining the unit cards rather than by testing

Andrew asked what the numbers on the new unit cards meant. Walking the pipeline to answer it -- catalog to node to modifiers to card -- turned up three real bugs that no test would have caught, because every one of them is a case of two systems disagreeing while both behave "correctly" in isolation.

The shape they share: `UnitCatalog.DEFINITIONS` is design-time data that gets **copied** onto a node by `_apply_catalog_definition()` at spawn. From then on the node is authoritative, and several systems mutate it. Nothing reconciles the two, and nothing asserted they agreed.

**1. Evolution silently deleted researched upgrades, permanently.** `_evolve()` calls `_apply_catalog_definition()`, which resets `max_health` and `attack_damage` from the new archetype. A Horror carrying Hardened Horrors' +20 HP evolved into a Hunter and dropped straight back to base stats. Worse, the `hardened_horrors_rank_applied` meta marker survived, so `_apply_upgrades_to_unit()` treated the unit as already-upgraded and never re-applied it. The player paid for an upgrade that vanished the moment their unit improved. `_evolve()` now calls `_reapply_owner_upgrades()`, and `BuildSystem.reapply_upgrades_after_evolution()` clears the marker and re-bakes against the new base stats.

**2. Hardened Horrors was keyed on the archetype, not the family.** `if archetype == &"horror"` -- so even with the fix above, a Hunter would never qualify. Now matched on `UnitCatalog.family_of()`, which the catalog already carried (`horror` and `hunter` share `unit_family: &"horror"`). Whether an upgrade should follow a unit through evolution is a design call, and this is the answer the standing WC3 default supports: upgrades persist for the life of the unit, they are not un-bought by getting stronger.

**3. Every evolved unit on every card was understated.** `_evolve()` applies a growth multiplier *on top of* the evolved archetype's catalog entry (`max_health x (1.18 + level x 0.03)`, `attack_damage x 1.15`) -- but the card read the raw catalog. Oaven Jumper displayed **HP 118 / Damage 12**; the unit you actually field is **HP 146 / Damage 13**. Hunter displayed 108/16 against a real 133/18. Roughly 24% HP and 15% damage missing on every evolved form.

Fixed at the source of truth rather than in the card: the multipliers moved into `UnitCatalog` as named constants, `_evolve()` now uses them, and new `fielded_max_hp()` / `fielded_attack_damage()` helpers give the card what a player will really get. Evolved forms render as `HP 146 (base 118 +growth)` so the growth stays legible instead of being quietly folded in.

**Also cleaned up while in there**: the card's "Bio value" line read a `bio_value` catalog key that exists on **no archetype**, so it printed 0 for every unit in the game. It now uses the real salvage formula (60% of Bio cost + 12% of max HP), shared with `RTSUnit.salvage_value()` via `UnitCatalog.salvage_value_for()`. Cards also gained a derived **DPS** figure and a px conversion on range -- damage-per-hit alone hid that the Oaven's blowpipe is roughly half the DPS of its spear, and that Kon's double cast makes his real output 37.6 rather than the 16 shown.

#### Worth knowing for future stat work

- **`WeaponCatalog` is a partial second source of truth and its damage numbers are dead.** `get_weapon()` overwrites `damage` and `speed` from `UnitCatalog` whenever the unit defines them. So `weapon_catalog.gd` saying `life_wizard: damage 13` while the catalog says 16 is not a conflict -- the 13 simply never applies. What WeaponCatalog *does* own and what is very much live: `kind`, `color`, `casts` (Kon's double cast), `aoe_radius`, `lead_target`, `ground_attack`. Tuning damage in that file does nothing; tuning `casts` does a lot.
- **Armor is flat subtraction with a floor of 1**, not a percentage. Armor 5 removes 71% of a 7-damage hit and 13% of a 38-damage one, which makes armour a hard counter to swarms and near-irrelevant against heavy hitters. Now stated on the card instead of left to be reverse-engineered.
- **Magic armor is currently almost inert.** The only thing in the codebase that passes `&"magic"` is poison damage-over-time; every other attack is physical. Magic armour therefore reads as "Stone-Faced Serpent resistance" and nothing else. Not changed here -- it is a design decision whether more damage should be magic -- but it should not be tuned as though it were a general second armour stat.
- **Evolution XP is earned two ways**, and neither is on the card: +0.6 x attack_damage per attack made, and +0.35 x damage taken. Units level from being in a fight, not from winning it.

#### Evidence

New `evolution_stat_integrity_smoke_test.gd`. **Verified by reverting each fix and confirming the test fails**, then restoring -- not just by watching it pass. With the re-apply removed: *"Evolution dropped the researched bonus: Hunter has 133 HP, expected at least 153"*. With the family match reverted: same failure. It also covers idempotency (applying a rank twice must not double-count, the property the 2026-08-23 tiered-research work established) and asserts fielded stats exceed catalog stats for every evolved form while matching exactly for every base form.

Suite: 45 of 46 pass, the failure being the pre-existing `seeded_grid_frontier_smoke_test.gd` road-artery bug.

### 2026-08-31 - Design: "Micromanageable Levels" added to the Master Design Doc (Section 38)

Andrew's mechanic, his call, recorded here because it changes how units are specified from now on: **not every unit answers to the same degree of control.** Some can be fully micromanaged with precise responsiveness; others accept only primitive commands and otherwise fight their own way -- defend-only postures, or attack orders that cannot be called off once committed.

Added as Section 38 rather than folded into Section 15, with cross-references placed in Section 5 (scale and army control), Section 15 (Units) and Section 36 (the agent summary) so it cannot be missed by anyone reading only one of those. Numbered at the end deliberately: inserting it mid-document would have renumbered sixteen sections and broken every existing reference in the vault and the code comments.

**Why this matters beyond being one more mechanic.** It resolves a real tension that Section 5 and Section 29 have been carrying since the "hundreds of units" correction on 2026-08-26. Section 5 wants hundreds of units on screen; Section 29 forbids leaning on APM. The 2026-08-31 control-groups pass answered that by raising the ceiling on what a player *can* manage. This answers it from the other side, by lowering how much *needs* managing -- and the two together are a much more coherent position than control tooling alone. Recorded in the doc in those terms.

It also gives KoN a trade-off axis that is not power. A unit can be strong *and* awkward, which is exactly the alternative to the "pure stat scaling" Section 29 lists as a thing to avoid, and it arrived while the stat-system design conversation was live.

The doc proposes five named levels as a starting structure -- Commanded, Directed, Loosed, Bound, Unbound -- explicitly as a recommendation in the doc's usual register, not as a settled rule. Worth noting that **the extreme case is already built**: The Forbidden (Tier 4, 2026-08-31) spawns under `owner_player_id = 0` and is unselectable, which is "Unbound" implemented before the concept had a name. That is a useful anchor for whoever specifies the rest of the scale.

Three open questions are recorded in the doc rather than guessed at: whether control level belongs to the unit, to its evolution stage, or to its distance from Kon and the Observation Tower (an observer-magic leash); whether other classes use the axis at all; and how a mixed selection behaves when one order is issued to units that will and will not obey it.

**Not implemented.** This is a design entry only. The one engineering note worth carrying forward: it interacts directly with the control-group and army-order work from earlier the same day, and the "readable, not silently partial" requirement for mixed selections is a UI problem as much as a simulation one.

### 2026-08-31 - Design + Engineering: Intelligence and Aggro Range shipped as real stats

Andrew's call, made and built the same day the mechanic went into the doc. Section 38 was rewritten from the five-level structure originally proposed down to his three-point **Intelligence** scale, and implemented:

- **1 Feral** -- set behaviour, player orders refused outright.
- **2 Leashed** -- takes move orders, but only while no enemy is inside its aggro range. Once something closes it drops the order and fights its own way.
- **3 Bound** -- fully micromanageable.

Plus **Aggro range**, the companion stat: how far an enemy can be before the unit engages on its own. The two read together -- aggro range says when a unit starts fighting by itself, intelligence says whether you can stop it.

**Aggro range already existed, badly.** It was an implicit `max(attack_range * 1.5, 256px)` hardcoded in `combat_system.gd` with no design control over it at all. It is now authored per unit (`aggro_range_cells`), and the old expression is kept only as a floor for anything unauthored. That value is also the spatial query radius, so it is the main lever on `combat_tick_ms` -- noted in the code, because long aggro ranges cost real time at scale and the 2026-08-31 telemetry already flagged combat cost above 40 units.

#### The two design decisions inside the implementation

**Stop is always obeyed** above Feral. A Leashed unit refusing every order including Stop would leave the player unable to call anything off, which reads as a bug rather than as character. Written into the doc's design rules, not just the code.

**The gate applies on the player order path only** -- `CommandDispatcher` and `SelectionController`. Wave units and summons issue orders directly on the unit and are deliberately unaffected. This matters more than it sounds: enemy waves are Leashed and Feral too, and leaking the gate onto the direct call path would silently stop every enemy wave in the game. The smoke test pins that distinction explicitly.

Only `command_mode == &"move"` is overridden when a Leashed unit acquires a target. Attack-move, patrol and hold are untouched, because those are already fighting orders and because waves are issued as attack-move.

#### Two things done cheaply on purpose

`has_enemy_in_aggro_range()` reads the `attack_target` the combat tick already maintains rather than running its own spatial query. A query per unit per order click would be O(selection x neighbourhood) on every click, and RTSWorld's buckets are only rebuilt by the combat tick -- so querying them from the input path would read whatever staleness that cadence leaves. That is the exact trap the Bio Absorber heal aura hit earlier the same day, hit again here, and avoided the same way. The tradeoff is that a unit which has not noticed an enemy yet still obeys for a tick or two, which is the right way round: the leash tightens once the unit is visibly aware.

Intelligence from `observer_command` is **recomputed** from the catalog baseline plus current rank rather than incremented. That makes it naturally idempotent and, importantly, it survives the stat reset that evolution performs -- the bug fixed hours earlier in this same session. The new stat was built to not repeat it.

#### Partial orders are reported, not silent

New `CommandDispatcher.order_partially_refused(obeyed, refused, reason)` signal, surfaced by the HUD as "3 obeyed, 2 refused - Spawner is engaged and will not break off". This was the risk flagged when the mechanic first went into the doc: ordering a mixed selection where only some units comply must not look like the order was dropped.

#### Cards

Intelligence and aggro range render on the unit card as their own line, colour-coded (green Bound / amber Leashed / red Feral), with the rule spelled out in plain language and the unit's real aggro number substituted in -- "Takes move orders only while no enemy is within 7 cells." The live selection panel shows the current value rather than the catalog one, since research can have raised it. Verified in the running game, not just in a test.

#### Roster values

Obedience degrades toward the forbidden, as the doc's rationale asks: Oaven 3, Stone-Faced Serpent 2, Spawner 2, Spawner Drone 1, The Forbidden 1. Aggro ranges 5-14 cells, longest on the Forbidden. The wizard is 3 and always will be.

**The Forbidden needed no special-casing** -- it was already unowned and unselectable from the tier-4 work, so Intelligence 1 simply describes what it already does.

#### Evidence

New `intelligence_stat_smoke_test.gd`: all three levels gated correctly, aggro range measured in both directions, Stop's exemption, dispatcher filtering with a reason string, the AI-path bypass, and Observer Command raising and capping intelligence. Suite 46 of 47, the failure being the pre-existing road-artery bug.

One test-authoring trap worth recording: units spawned at coordinates beyond the 6144px map are silently teleported by `_snap_to_walkable_terrain()`, which pulled a test pair apart and made an aggro assertion fail for entirely the wrong reason. Test units must be placed on real walkable cells via `nearest_walkable_cell()`.

**Left open in the doc**: whether Intelligence 1 needs more than one "set behaviour". Today a Feral unit just fights on its own; Andrew's original framing also imagined defend-only postures, which would need a stance concept sitting alongside the stat.

### 2026-08-31 - Feature: 3D map view as a presentation mode over the unmodified 2D game

Andrew asked for "a new mode which has the map in the 3d one, same game mode". Built, and the shape of the answer matters more than the feature.

**What it is not.** `map_3d_renderer.gd` is a preview tool: it generates its own MapGenerator, runs its own toy unit probe, and owns its own camera, UI and input. Building gameplay against it is the mistake this project has already made twice -- 100+ assets against a non-shipping scene (2026-08-19), and the recurring confusion `PROJECT_BRIEF.md` warns about in its repo-layout section. Bending that tool into the game would have created a second, diverging implementation of Wizard RTS.

**What it is.** The 2D simulation stays authoritative for every unit position, order, path and combat result. A new `Map3DView` node sits alongside it and does four things: asks the preview renderer to draw the **live** MapGenerator's terrain, mirrors live units and structures into MultiMeshes, owns a 3D RTS camera, and converts screen position into simulation coordinates. **Delete the node and the game still runs.** That property is the whole design.

#### Decisions worth recording

**One scene, not two.** The 3D view is a node inside `scripts/map/main_map.tscn` that frees itself in `_ready()` unless `GameSession.render_3d` is set. A parallel `main_map_3d.tscn` was the obvious approach and was rejected: a copy starts diverging from the real scene the first time either is edited, which is the same drift that produced the dead `scenes/map/main_map.tscn` stub the brief already warns about.

**A narrow embedding API rather than a rewrite.** `map_3d_renderer.gd` gained `embedded_mode`, `render_live_map(generator)`, and coordinate helpers -- about 60 lines. In embedded mode it creates no generator, no camera, no UI, no probe, and consumes no input. Its 3400 lines of preview behaviour are untouched and still work standalone.

**One input bridge, not a second input system.** The 2D `SelectionController` works in simulation coordinates and asks the viewport for the mouse. In 3D that has no answer until the cursor is projected onto the ground plane, so `screen_to_sim_position()` does exactly that and every selection, order and placement path is shared between the two modes rather than forked. `BuildSystem` uses the same bridge for placement.

#### The bug worth remembering

Hiding the 2D presentation by a **list of known node names did not work**, and the failure was invisible until a screenshot: the terrain prop sprites live under `MapGenerator` as a `VisualProps` child, not under the scene root, so several hundred trees and rocks kept painting over the 3D world. Replaced with a recursive walk that hides every `CanvasItem` in the map subtree and stops at `CanvasLayer` boundaries -- which is also what keeps the HUD, pause menu and slice overlay working unchanged in both modes. The smoke test asserts specifically that `VisualProps` is hidden, because a name list would pass every other check.

Suppression also has to run **twice**: once in `_ready()`, and again after terrain build, because map generation paints its props during bootstrap, after `_ready()` has already run.

#### Evidence

New `map_3d_mode_smoke_test.gd`, written around the "presentation layer, not a second game" property rather than around "3D renders". It asserts the embedded renderer is drawing the *live* generator object (not one of its own), that the preview tool's `GameplayProbe` does not exist in the game mode, that units are still 2D nodes still registered with RTSWorld and still selectable, that they are being mirrored into the 3D layer, that the screen-to-simulation bridge round-trips within a cell, and that 2D mode is completely unaffected. Suite 47 of 48, the failure being the pre-existing road-artery bug.

Verified in the running game via `scripts/tools/map_3d_mode_screenshot.gd` (windowed, not part of the suite): real elevation, roads, blockers and props in 3D, the KoN roster mirrored as coloured instances, HUD intact.

#### First pass, honestly scoped

Working: terrain with elevation, roads, props and structures; live unit mirroring with owner and selection colours; 3D RTS camera with pan and zoom, opening on the player's tower; the full input bridge, so selection, orders and building placement all work.

**Not done**: units render as capsules rather than sprites or models, which is the obvious next step and the one that decides whether this mode is worth keeping; no drag-select rectangle drawn in 3D (the selection itself works, the visual feedback does not); no camera rotation; the building placement preview is still 2D and therefore invisible in this mode. The 3D presentation also does not yet reflect day/night, fog of war or the LOD system.

**Open question for Andrew**: this reopens, in a limited way, a decision closed on 2026-08-08 ("staying 2D"). Nothing about that decision is reversed here -- 2D remains the default and the only mode with real art -- but if the 3D view is meant to become more than a viewer, that is a design call about where art effort goes, not an engineering one. Flagged on the Roadmap rather than assumed either way.

### 2026-09-02 - 3D view: 2D unit sprites billboarded onto the 3D map

Andrew asked to use the existing 2D units on the 3D map. Built, and the interesting part is that it needed no new animation code at all.

**How it works.** A billboard is a flat textured quad in 3D that turns to face the camera -- the technique classic isometric games used for sprite units in 3D worlds. Godot's `Sprite3D` is exactly that, and it already carries `hframes`/`vframes`/`frame`, which is the same grid model `kon_unit_art.gd` uses.

**The shortcut that made this small.** The unit's own `ArtSprite` already computes, every tick, which of the 8 direction rows to show (`_direction_row()` from velocity and attack target) and which animation frame it is on. So the billboard carries **no animation logic** -- it mirrors `texture`, `hframes`, `vframes` and `frame` straight off the unit's existing 2D sprite. One animation implementation, two renderers, and they cannot drift apart. The smoke test asserts that mirroring directly rather than asserting that "3D shows something".

**Two tiers, mirroring the 2D LOD system.** A `Sprite3D` is one node and one draw call per unit, which is fine at the 40-100 units of Andrew's real play session and not fine at the hundreds section 5 targets. So units nearest the camera get billboards up to `MAX_SPRITE_UNITS` (220) and everything past that falls back to the existing capsule MultiMesh -- the same two-tier shape `MassUnitMultimeshRenderer` uses in 2D, for the same reason. When the budget is exceeded the FURTHEST units drop to capsules, not the nearest.

Three rendering choices worth recording:
- `BILLBOARD_ENABLED` (full camera-facing) rather than `BILLBOARD_FIXED_Y`. The sheets were rendered from a fixed -52 degree camera, so the sprite already contains that perspective; facing the camera squarely is what makes it read as a unit rather than a standing cardboard cutout.
- `shaded = false`. The painted art keeps its own values instead of being re-lit by the 3D sun, which would flatten the ink-outline look the Art Bible is built on.
- `ALPHA_CUT_DISCARD` rather than alpha blending. With hundreds of overlapping transparent quads there is no correct draw order, and blending produces flicker.

**The honest limit, and it is the familiar one.** Only four units have sprite sheets at all: `bad_kon_willow`, `terrible_thing`, `horror` and `apex`. **The actual KoN roster -- Oaven, Stone-Faced Serpent, Spawner, The Forbidden -- has none**, so those still render as capsules. The billboard system is complete; the art is not. This is the same section 37 gap blocking everything else, now visible in a second place.

That is also why the capsule fallback matters rather than being a stopgap: it is what the game looks like for most of its roster today, in either mode.

Suite 47 of 48, the failure being the pre-existing road-artery bug.

### 2026-09-02 - 3D view: interaction parity audit, after shipping it broken

Andrew: "it does not play like the 2d version, cant move map, cant build buildings or see preview, cant drag and select." All correct.

**The process failure, recorded because it is the useful part.** The first 3D pass shipped with a smoke test that verified the screen-to-simulation coordinate maths round-tripped, and that was reported as "selection, orders and building placement all work". Round-tripping a coordinate is not the same as being able to play. Every one of the three breakages below would have been caught by five minutes of actually driving the mode, or by a test that exercised the interaction rather than the arithmetic underneath it.

This is a close cousin of the 2026-08-23 lesson (smoke tests check correctness, not cost). Here they checked a *component* and were reported as covering a *capability*.

#### What was actually broken

1. **Camera** - the 3D view had keyboard pan only. `CameraController` gives the 2D game keyboard pan, edge pan, middle-mouse drag, wheel zoom and clamping to the map. Three of the five were missing, and without clamping the camera could pan off into empty space with no way back. Now feature-for-feature.

2. **Build preview** - `BuildSystem` is a `Node2D` and draws its placement footprint in `_draw()`. The 3D mode hides every CanvasItem in the map subtree, so `_draw()` never ran and the player was placing blind. The footprint is now pushed to the 3D view from `_process` as translucent ground pads, with the same valid/invalid colouring, and cleared when nothing is pending.

3. **Drag-select** - two separate faults. The rectangle was invisible for the same CanvasItem reason, and the selection maths was wrong: it projected the two drag corners onto the ground plane and built a `Rect2` from them. **Under a perspective camera a screen rectangle maps to a trapezoid on the ground**, and any part of the drag above the horizon projects to nothing at all, so the selected region did not match what the player dragged.

#### The fix worth understanding

Drag-selection is now tracked in **screen space** in 3D, not simulation space, and each unit is tested by its *projected* screen position. That is both correct and what 3D RTS games actually do - the ground-plane projection was solving the wrong problem. Units behind the camera are excluded explicitly, since they project to a mirrored on-screen point and would otherwise be box-selected from off screen. Click-select radius is likewise projected, so clicking feels the same zoomed in or out.

The drag rectangle and the order cursor are drawn by a new `map_3d_overlay.gd` inside a `CanvasLayer`, which survives the CanvasItem suppression. Screen space is also the right space for them: a drag rectangle is a screen gesture.

#### Evidence

New `map_3d_interaction_smoke_test.gd`, written specifically to not repeat the mistake: it drives the real paths rather than the maths. Camera moves and is clamped when pushed off-map; a screen-space drag over four units selects all four; a drag over empty screen selects none (proving the rectangle is actually tested, not always passing); the overlay shows and clears the rectangle; a pending structure produces visible 3D footprint pads; placement lands in the build system; and clearing the pending build clears the preview.

It found a real thing while being written: `bio_absorber` additionally requires an economy plot, so a placement failure with it would have been ambiguous. Test uses a Barracks.

Suite 48 of 49, the failure being the pre-existing road-artery bug.

#### Still not at parity

Vinewall drag-placement shows its footprint in 3D but has not been driven end-to-end. Right-click order feedback (the move/attack marker) is not drawn in 3D. Unit health bars, selection rings and the evolution/level chrome are all 2D `_draw()` and do not appear. Those are visual, not functional, but they are the remaining gap between "works" and "feels like the 2D game".

### 2026-09-02 - Fog of war rebuilt as a shared vision texture, plus a 3-minute grace period

Three asks, in both presentations. The systems are shared, so "for both 2D and 3D" cost nothing extra for the grace period and drove the whole design of the fog.

#### Grace period

`WaveDirector.grace_period_seconds` (180s). Phases, waves and the boss are all measured from `combat_time_elapsed()` -- seconds since the END of grace -- rather than from raw elapsed time. That matters: setting `first_wave_seconds` to 180 instead would have left only 60 seconds between the first wave and a boss still arriving at an absolute 240s. Measuring from the end of grace pushes the whole schedule back and keeps every gap exactly as tuned.

New opening phase `grace`, and the HUD leads with "Grace period | First wave in 3:00" plus a ten-second warning, because it is the only stretch of a run where the player can build unpressured.

#### Fog of war: one vision source, two presentations

Fog existed but was **switched off on seeded_grid_frontier**, and for a good reason -- `_draw()` painted opaque diamond polygons per 4x4 cell block every frame, which was both expensive and blocky.

It now publishes visibility as a **one-texel-per-cell texture** (0 = unseen, 128 = explored, 255 = visible) instead of drawing anything itself. That one change fixes both problems at once:

- **Nicer**, because sampling it with LINEAR filtering gives soft organic edges for free. The blockiness was a consequence of drawing cells, not of the vision data.
- **Cheaper**, one small texture upload per 0.45s update instead of thousands of `draw_polygon` calls per frame -- which is what makes it affordable to switch on at all.
- **Shared**, because the 2D overlay sprite and the 3D fog plane sample the same texture with the same shader maths. Same principle as the unit mirroring: one computation, two presentations, no way for them to disagree about what is hidden.

Both shaders add a slow UV warp so the fog line breathes rather than sitting as a hard static boundary. It perturbs the lookup, not geometry, so it costs effectively nothing.

`is_world_position_visible()` is public, and the 3D view uses it to skip mirroring concealed enemies -- otherwise the 3D mode would see straight through the fog, since fog hides enemies in 2D by flipping `visible`, which the 3D mode already owns for its own reasons. For the same reason `_apply_entity_visibility()` now skips entirely when `presentation_3d` is set, or it would flip the 2D sprites back on over the 3D world.

#### Three bugs found by screenshotting rather than by testing

All three passed every assertion and were only visible in an image:

1. **The fog plane cast a shadow.** A 96x96 quad above the map threw an enormous directional shadow across half the terrain. `cast_shadow` off.
2. **Tall props stood above the plane.** At y=1.75 the map's tree props poked through and rendered unfogged. Raised to 6.0 -- height only affects occlusion for an unshaded overlay, and the ceiling is the camera, which sits at about 9.5 above focus at minimum zoom.
3. **Raising it lost the far border to parallax**, leaving a bright unfogged band along the map edge. The plane is now drawn 3x map size with UVs remapped so the map still spans 0..1; outside clamps to the border texel, which is unexplored, so off-map ground is correctly black.

And a fourth, in 2D: the overlay sprite is a CHILD of the FogOfWar node, so hiding that node to suppress the old per-cell drawing hid the overlay too. The node stays visible; `_draw()` returns early instead. That one read as "fog does not work in 2D" rather than as a visibility bug.

#### Evidence

New `fog_and_grace_smoke_test.gd`: no wave, no phase advance and no boss countdown during grace; the schedule resuming from zero afterwards; the fog texture existing at one texel per cell; the overlay using a shader rather than per-cell drawing; an unscouted corner staying concealed; a friendly unit lighting its own cell; and an enemy in fog being hidden.

Screenshots from the real scene in both modes, which is what actually caught the four bugs above. Suite 49 of 50, the failure being the pre-existing road-artery bug.

#### Note

Enabling fog on the live map is a gameplay change, not just a visual one -- enemies are now concealed until scouted, which the day/night entry of 2026-08-23 explicitly declined to touch at the time. It is what was asked for, but it changes how the map plays and is worth a look before it is treated as settled.

### 2026-09-02 - Fixing what enabling fog broke: 63ms -> 4ms, grace period leak, and 1:1 mouse panning

Andrew after playing: "lots of performance issues and enemies still spawning at start, cant use the mouse to move the map very well." Three separate faults, two of them mine from the previous entry.

#### 1. The fog was costing 63ms per update

Measured, not guessed: 62.84ms per fog update with 60 units on the live map. At a 0.45s interval that is a hard hitch several times a second. **I switched fog on for the live map without auditing the code I was enabling**, and it contained every pattern this project has already been burned by:

1. **`_has_line_of_sight()` called `_line_cells()`**, which built and returned a fresh `Array[Vector2i]` for *every one of the ~300 cells tested per revealer*. Hundreds of array allocations per unit per update. Rewritten to walk the line in place with identical stepping maths.
2. **Every unit revealed individually**, even standing on top of one another, although vision radius is 7-8 cells and their fields overlap almost entirely. Revealers are now merged on a 3-cell grid, with the radius widened by half the merge distance so groups do not leave gaps. A clumped army of 60 costs about 8 reveals instead of 60.
3. **Two 9216-cell loops per update** -- one clearing visibility, one rebuilding the fog texture from scratch. Both now walk only the cells that actually changed, tracked as flat indices.
4. **`get_property_list()` reflection per unit, twice** -- once for `owner_player_id`, once for `unit_archetype` -- which is precisely the 2026-08-23 HUD regression, in a different file.

After those: **12ms**. Better, but still a single spike landing in one frame. So a full vision pass is now **spread across several updates** (`origins_per_update`) and committed only when it completes, so nothing flickers part-way through.

**Final: 3.98ms average, 6.25ms worst.** A 16x improvement on the worst case, and it now fits inside a frame.

There is also a plain bug worth recording: the first version of this fix did not parse at all. `map` is declared `var map: Node`, so `map.MAP_H` is a Variant and `var cx := index / map.MAP_H` cannot infer a type. The script silently failed to load, FogOfWar became a scriptless Node2D, and the smoke test *hung* rather than failing. **I had not re-run `--check-only` after that patch** -- I chained straight into the test. Cheap habit, and it cost a confusing debug session.

#### 2. Enemies still arriving during the grace period

The grace period gated `WaveDirector`, but **outposts spawn their own defenders on an independent timer** in `KonVerticalSliceController._update_outpost_offense()`, which knew nothing about it. Now gated on the same `is_in_grace_period()`. The grace period means no hostile pressure at all, not merely no waves.

#### 3. Mouse panning in 3D

The first version used a fixed pixels-to-world factor scaled by camera distance. That cannot be right under a perspective camera: the correct factor depends on distance *and* field of view *and* where on screen the cursor is.

Replaced with true 1:1 dragging -- project the cursor onto the ground plane before and after the motion, and shift the focus by the difference. The ground under the cursor now stays under the cursor exactly, at any zoom. Keyboard and edge panning also scale with zoom, so they cover a consistent fraction of the visible area instead of crawling when zoomed out.

#### Evidence

`map_3d_interaction_smoke_test.gd` gained a drag-pan case that asserts both that the camera moves and that the direction is not inverted. Suite 49 of 50, the failure being the pre-existing road-artery bug.

#### The lesson, which is the same one twice now

Enabling an existing subsystem is not a free action. `fog_of_war.gd` was written for a map type where it was switched off, so its hot paths had never been under the scrutiny the rest of the codebase has had. **Turning something on means owning its performance**, and I should have profiled it in the same pass that enabled it rather than after Andrew hit the stutter.

### 2026-09-02 - Vision rules: buildings see, nothing shoots uphill blind, and cliffs are marked

Three of Andrew's asks, all really one subject: what a side can see, and whether the player can read the ground.

#### Line of sight moved onto the terrain

`has_line_of_sight()` now lives on `MapGenerator`, and both fog of war and combat targeting call it. That placement is the point: it is a question about terrain, and two implementations would let vision and weapons disagree -- a unit could shoot something the fog says it cannot see. It is allocation-free because it is now on the combat tick as well as the fog tick.

The rule: **sight travels level or downhill freely and is blocked by anything higher than the viewer.**

#### Buildings reveal fog

Structures are now fog revealers alongside units, with authored `sight_radius_cells` (Observation Tower 12, Bio Launcher 10, outposts 9, others 4-7). A base used to be a blind spot -- you could stand a tower in the dark and it lit nothing around itself. The sight lookup handles both `unit_archetype` and `archetype`, because units and structures name that field differently.

#### No shooting up a cliff without a spotter

A unit cannot engage a target above it unless it has line of sight, **or a nearby ally does**. That is the spotter rule most RTS games use, and it makes a melee screen genuinely valuable to ranged units rather than just a damage sponge.

It applies to the enemy AI identically, and not by writing it twice: the check lives in the shared combat tick, so both sides obey it **by construction**. The test asserts that explicitly by swapping unit owners and re-running the same assertion. Manual right-click attack orders go through the same gate, so the player cannot order what their army cannot see; the refusal is reported through the existing partial-order channel.

**PERFORMANCE**: the expensive half only runs when the target is HIGHER than the attacker. On flat ground -- nearly every engagement -- it is two height lookups and an early return. Given fog had just taught me what an unguarded per-unit cost does here, that gate was designed in rather than added afterwards.

#### Impassable terrain marked orange

Baked once into a one-texel-per-cell texture at map generation, so it costs nothing per frame -- deliberately not a `_draw()` pass, which is exactly what made fog too expensive to leave on. Cliff edges are bright orange; water and hard blockers get a dim wash.

**Three separate traps getting this on screen**, all invisible to the tests, which passed throughout:

1. **z_index 4200 silently drew nothing.** Godot clamps `CanvasItem.z_index` to +/-4096. The node reported `visible = true` with a correctly baked texture and rendered no pixels.
2. **Below the fog layer, the marker was crushed to invisibility on exactly the cells it exists to warn about** -- a cliff blocks line of sight, so cliff cells are the least likely to be brightly lit. The indicator was being hidden by the terrain feature it describes.
3. **Above the fog it covered the army**, and it has to be masked by the fog texture anyway or it hands the player a free map of every cliff they have never scouted.

Settled at z 4096 with an in-shader fog mask and moderate alpha: explored cliffs read clearly, unexplored ones show nothing, and a unit standing on a lip is still visible through it. Diagnosis was by sampling rendered pixels rather than by eye -- "0 orange pixels" is a fact, "I cannot see it" is not.

#### Evidence

New `vision_and_terrain_smoke_test.gd`. It finds a real height transition on the generated map rather than assuming one, then asserts: sight blocked uphill, allowed downhill, the same rule holding after swapping owners (so the AI cannot cheat), a spotter unlocking the shot, structures appearing as fog revealers and lighting their own position, and the overlay baking a one-texel-per-cell texture that actually marks cells.

Suite 50 of 51, the failure being the pre-existing road-artery bug.

#### Worth knowing

The ground tiles are still the placeholder red/green/yellow blocks, which is why the cliff marker had to be an aggressive orange rather than a tasteful one -- there is no quiet colour left on that palette. It will want revisiting when real terrain art lands.

The 3D view does not draw the impassable overlay yet; it has real geometry, so cliffs are legible there already, but it will want the marker for consistency.

### 2026-09-02 - 3D view: structure art, fog gating for buildings, and camera easing

Andrew, on the 3D mode: "still not smooth camera movement, los still not working properly as shown, buildings and units not using their models."

#### The LOS symptom was structures, not units

Units were already fog-gated in the 3D view. **Structures were not gated at all**, so enemy outposts rendered plainly inside unexplored blackness -- which is exactly what "LOS not working" looked like in the screenshot. `_sync_structures()` simply had no reveal check where `_sync_units()` had one.

The helper was called `_is_unit_revealed()` and had been written for units, though it only ever needed `owner_player_id` and a position -- both of which structures have. Renamed `_is_revealed()` and applied to both. A single missing call, and it undermined the whole vision system visually.

#### Buildings now use their real art

Every KoN structure already builds an `art_sprite` from `STRUCTURE_TEXTURES` -- the tower, barracks, absorber, vault, vinewall and launcher all have painted 2D art. The 3D view was drawing coloured boxes anyway. Structures are now billboarded exactly like units, mirroring their own `art_sprite`.

Their world size is **derived from the 2D art scale** (`art.scale.y / 64`, since 64 simulation pixels is one world unit) rather than a tuned constant, so a building is the same size in 3D as it is in 2D by construction rather than by matching numbers by hand.

Units still fall back to capsules where no sprite exists, which remains the whole KoN roster -- the section 37 art gap, unchanged.

#### Camera smoothing

The per-frame cost was measured first and was *not* the problem: `_sync_units` 0.33ms at 80 units, `_sync_structures` 0.014ms, `_apply_camera_transform` 0.0025ms. Panning was rough because the camera focus was written **directly** by each input, so it moved in discrete per-event jumps -- one step per key frame, one per mouse-motion event.

Panning now moves a *target* and the camera eases toward it, frame-rate independently (`1 - exp(-k * delta)`, so it feels identical at 30fps and 144fps). Zoom eases the same way. Middle-drag deliberately does NOT ease: it is a 1:1 gesture and must not lag the cursor, so it moves camera and target together. Clamping applies to both, or panning into the map edge quietly accumulates an out-of-bounds target the camera keeps straining toward.

#### Evidence

`map_3d_mode_smoke_test.gd` gained assertions that structures render as billboards rather than boxes, and that a fog-concealed enemy structure is genuinely excluded from the draw. Suite 50 of 51, the failure being the pre-existing road-artery bug.

#### Note to self

Measuring before optimising was right and saved wasted effort -- the smoothness fix was in the input path, not the render path, and any amount of profiling the sync would have found nothing. Worth doing that consistently rather than only after being burned.

### 2026-09-02 - 3D view: impassable terrain marked, matching the 2D overlay

Ported the orange cliff/impassable indicator into the 3D mode.

**A MultiMesh of per-cell quads, not one map-sized sheet.** The 2D version is a single textured sprite laid over the map, which works because the 2D map is flat. The 3D terrain has real elevation, so a flat sheet at y=0 would be buried under every plateau -- hiding exactly the cliffs it exists to describe. Each mark instead sits on its own cell's rendered surface height. One draw call, 2178 instances on the test map, baked once after terrain generation because terrain does not change during a run.

**No fog masking needed here.** The 2D overlay had to be drawn above the fog and masked in-shader, which took three attempts to get right. In 3D the fog is a plane *above* the ground, so it occludes unexplored marks for free. Same requirement, and the 3D scene graph solves it without any special handling -- worth noting, because the 2D solution looks over-engineered until you know the 2D fog is a sprite in the same 2D layer stack.

Heights come from the renderer's own `surface_height_at_cell()`, which reads the terrain-type grid the 3D geometry is actually built from -- not `height_map`. Those are different things: `grid` holds E_LOW/E_MID/E_HIGH/E_RAMP/E_WATER, `height_map` holds elevation levels, and a cell can read height 2 in one and E_RAMP in the other. Using the grid is correct here precisely because it is what the visible geometry was built from.

#### A test that failed on correct code

The first assertion checked that marks occupy more than one distinct height, reasoning that a plateau should have some. It failed -- and the code was right. **Almost every marked cell is low ground**, because high-ground cliff lips fall inside base plots, and `_is_unramped_height_edge()` deliberately excludes plot interiors so a base does not paint itself orange. Marking the low-side lip is also the more useful behaviour: it is the side the player walks up to.

Replaced with the assertion that actually matters: each mark's height must equal its own cell's rendered surface height, derived back from the renderer rather than assumed. That tests "follows the terrain" without depending on what the generator happened to produce.

Suite 50 of 51, the failure being the pre-existing road-artery bug.

#### Recurring GDScript trap, third time

`var centre := Vector2(...) * _renderer.SIM_PIXELS_PER_CELL` does not compile: `_renderer` is typed `Node3D`, so reading a const off it yields a Variant and `:=` cannot infer. Same shape as the `map.MAP_H` failure in the fog work. **Run `--check-only` immediately after every patch** -- it is a few seconds and it has now caught this three times, twice only after a confusing downstream failure.

### 2026-09-02 - Investigated: KoN unit models cannot be rendered into sprites from what exists

Andrew asked to add KoN's unit models to the game. Investigated properly rather than assumed it was blocked, and the answer is that it is blocked on **source art**, not on tooling or engineering. Recording it so the next session does not repeat the work.

#### What exists

| KoN unit | 3D model | Sprite sheet |
|---|---|---|
| Oaven | `art/generated_models/oaven_spear` + a processed GLB | none |
| Stone-Faced Serpent | **none** | none |
| Spawner | **none** | none |
| The Forbidden | **none** | none |
| Bad Kon Willow | processed GLB | already has one |

So three of the four roster units have no geometry at all. Only the Oaven could even be attempted.

#### The Oaven attempt, and why it is not shippable

`asset-factory`'s `blender_sprite.py` is genuinely good and did its job: it rendered a full 8-row x 3-frame directional sheet from the GLB in about 8 seconds, in the exact layout `kon_unit_art.gd` expects, using the same -52 degree camera pitch. The tooling is not the problem.

Three findings on the way, all of them traps already recorded in `reference_blender_headless_render`:

1. **The default render came out untextured beige** -- trap 2, EEVEE dropping glTF textures in background mode.
2. **Forcing Cycles made it worse, not better** -- trap 4: this mesh carries an `_ink_outline` backface-culled proxy, which Cycles renders as a solid shell covering the model. The result was a dark tangle. The two traps pull in opposite directions and this mesh sits exactly on the seam.
3. **The Meshy statuette base is baked into the same mesh object**, not separable -- one mesh, one material, with the plinth as geometry. Removed it by deleting vertices below a height threshold, which worked cleanly (2760 verts).

After all of that the sheet still is not usable: **the model has no readable silhouette.** It is an amorphous cluster of grey shapes. At the size a unit occupies on screen you cannot tell it is an insectoid, that it carries a spear, or which way it is facing -- and facing is the entire point of an 8-direction sheet.

**The existing procedural vector art is better.** The in-engine Oaven has a clean teal body, large cyan eyes, a red scarf and a visible spear; it reads at a glance and matches the concept art. Shipping the render would be a visual regression, so nothing was committed.

#### The real conclusion

This is section 37's gap restated with a concrete measurement: the 3D pipeline produced *first-pass placeholder geometry*, not game-ready characters, and no amount of render tuning turns a shapeless mesh into a readable unit. The route to KoN unit art is new art -- clean models, or 2D sprite generation -- not a better render of what is on disk.

Consistent with the 2026-09-02 recommendation to Andrew: the cheapest real win remains pushing the procedural animation in `kon_unit_art.gd` harder, because it benefits every unit immediately and needs no pipeline at all.

**Nothing was changed in the game.** The render attempts are staged in `asset-factory/out/sprites/` as evidence.

### Open, not yet decided

- **AI-test army mix** — confirm whether the stress-test mode spawning KON-vs-KON is intentional before anyone "fixes" it as a bug.

### 2026-09-03 — 3D view: KoN units baked from their own 2D art, not modelled

The entire KoN roster rendered as featureless capsules in 3D, and the 2026-09-02 conclusion was that this was blocked on source art. That was wrong about the cause. Those units are not art-less — they draw detailed procedural art in `_draw()` (the Oaven has a teal body, cyan eyes, a red scarf and a spear); the 3D view was simply discarding art the 2D view already had, because it only looked for an `ArtSprite` node.

Each art-less archetype is now rendered once into a `SubViewport` and used as a billboard. No new art, no pipeline, no animation logic duplicated: 17 of 17 units now render as sprites in 3D, zero capsules. The 3D-specific art gap is closed; the remaining gap (only 4 units have real sprite sheets) is the same §37 gap 2D has, and both presentations are now equally unfinished rather than 3D being visibly worse.

**The hazard, and how it is contained.** Instantiating a unit to render it would otherwise put it in the live game: `RTSUnit._ready()` adds itself to the `units` and `selectable_units` groups *and* to a static registry. A leak there is an invisible, invincible unit — selectable, targetable, counted against supply. All three registrations are undone immediately and physics is disabled before any tick can observe the instance; `terrain` and `rts_world` do not resolve inside a `SubViewport`, which is what makes the rest of `_ready()` harmless (`_snap_to_walkable_terrain()` returns early with no terrain). The smoke test asserts the baker's subtree contains nothing in a live gameplay group.

Baked billboards are a single fixed east-facing frame, so units do not turn to face movement. That is the most visible remaining difference from 2D, and it is a deliberate limit of the approach rather than a bug.

### 2026-09-03 — 3D view: terrain marks are cliff edges only

The 3D view mirrored the 2D impassable overlay wholesale, including its dim wash over rocks, trees and water. That wash exists because on a flat map there is no other way to tell a blocker from open ground — but in 3D those are literal geometry you can see, so marking them scattered orange over open ground that read as arbitrary rather than as information. Andrew's read was "the terrain orange doesn't look right", and it was right.

3D now marks **cliff edges only**: the one thing a top-down 3D view genuinely cannot convey on its own, because a height change reads only as a change in shading. 2178 marks down to 484. The 2D overlay is unchanged — it still needs the full wash, for the reason above.

### 2026-09-03 — 3D view: economy spaces marked, and a staleness trap

"Can't place a Bio Absorber" was not a placement bug. Economy spaces are its only legal cells, `PlotRenderer` draws them, and the 3D mode hides every `CanvasItem` — so the legal cells were invisible and the building simply appeared unbuildable. They are now marked in cyan alongside the cliff marks.

Underneath it was a real ordering trap worth recording: the marks bake runs from a deferred terrain build, and **plots are registered with an empty `economy_spaces` array and filled in afterwards**. A first attempt watched the *plot count* for change — which sees 13 plots both before and after the fill, and so never rebuilds. The check now counts the economy spaces themselves, and sits ahead of the unit-refresh gate rather than behind it, because behind the gate a short-lived view can miss the fill window entirely.

### 2026-09-03 — Testing: a headless MultiMesh assertion that verified nothing

The 3D marks test inspected the uploaded `MultiMesh` buffer via `get_instance_transform()`. MultiMesh instance data lives on the rendering server, and under the headless dummy driver every read comes back as zeros — so the test was comparing every mark against cell (0,0), and would have passed on code that stacked all 516 marks on the origin. It had been passing that way since it was written.

Mark computation is now split from mark upload (`compute_marks()` returns plain data), and the test asserts on that. Same values, same code path, but verifiable without a GPU. The general rule: **anything that round-trips through the rendering server cannot be asserted headlessly** — assert the data you are about to upload instead. The same reason means the baked sprite *images* are deliberately not asserted headlessly either; the test asserts the bake was queued and that it leaked nothing, and the visual result is verified against a real renderer.

Also fixed while here: the sprite baker awaited `RenderingServer.frame_post_draw`, which never fires headless — the coroutine parked forever holding a live unit under the viewport and hung teardown (a CI hang, not a failure). The bake now returns early when `DisplayServer` is headless.

**Suite status:** 49 of 50 smoke tests pass. `seeded_grid_frontier_smoke_test.gd` fails on road-artery connectivity; verified pre-existing by running it against the `HEAD` copy of `map_generator.gd`, where it fails identically. Not caused by this pass and not fixed in it.

### 2026-09-04 — 3D view: the "pasted-on sprites" problem was the camera, not the art

Andrew's read was that 2D art looked well-connected to the tiles at one angle and clearly detached at another. Diagnosis: two camera values, both wrong, neither of them an art defect.

**FOV was never set**, so it was Godot's 75° default. That is very wide, and the consequence is worse than it sounds. At 75° with a 52° pitch, the ground is seen anywhere from **14.5° to 89.5° within a single frame**, while a `BILLBOARD_ENABLED` sprite presents the same face at every screen position. No art angle can match that — which is why a sprite looked right in one part of the frame and wrong in another. The two screenshots were not two camera angles; pitch is a constant and never changed. They were two parts of the frame.

**Pitch did not match the art.** Every sprite has a viewing angle baked in — the barracks shows a nearly undistorted front wall and a shallow roof plane, implying about 38°. Full billboarding is only correct when camera pitch equals the art's own angle. At 52° everything was 14° out even at frame centre.

Now 35° FOV / −38° pitch. Camera distances are authored in **reference units** (ground framed at the old 75°) and converted against the live FOV, which does two things: every existing `set_camera_distance()` caller — tools and smoke tests — keeps framing what it always framed with no number changes, and changing the FOV shows a perspective change rather than just zooming in.

`[` `]` FOV, `;` `'` pitch, `\` prints the constant lines to paste back, Backspace resets. Debug builds only (`OS.is_debug_build()` at the input site). These are art-direction values, not engineering ones, so they are meant to be dialled in against the real map rather than argued from a screenshot.

Deliberately **not** changed: the billboard mode. `BILLBOARD_FIXED_Y` was the obvious-looking alternative and is wrong here — the art is already pre-foreshortened, so Y-billboarding applies engine foreshortening on top and squashes it. Full billboard is correct once the pitch matches.

Known gap: the standalone prototype previewer (`map_3d_renderer.gd`) still uses 52°. Its embedded path is unaffected, but art evaluated in the previewer will not match the game.

**Test note:** the smoke test asserts the reframing invariant by projecting two screen points onto the ground through the real camera, sampled *symmetrically about screen centre*. The ground plane is oblique, so a single distance scale cannot hold framing exactly across the whole frame — nor should it, since changing FOV is supposed to change how the ground foreshortens away from centre. A first attempt sampled off-centre, read a 2% residual and failed; uncompensated, the same FOV step moves it 8%.

### 2026-09-04 — Art direction: 3D props look better because they are static, not because they are 3D

Prompted by the observation that the 3D terrain assets sit far more naturally on the map than the 2D billboards. True, but the sample is biased, and the inventory shows how: **128** prop models, **2** character models, **0** building models. Everything that reads as natural is static scenery; everything that reads as wrong either moves or is interacted with. That is not a coincidence about the medium — it is the exact axis where 3D cost becomes superlinear, and it is where this pipeline already failed once (the Oaven render with no readable silhouette, 2026-09-02).

Recommendation, which narrows rather than reverses the 2026-08-08 "staying 2D" decision:

- **Terrain/scenery: 3D.** Already is, already works.
- **Buildings: the strongest 3D candidate.** Seven of them, static or near-static (5 have simple state sheets), the largest things on screen, and the worst offenders visually. Seven models is tractable; hundreds of animated units is not. Note there are currently **zero** building models, so this is new work, not a conversion.
- **Units: 2D runtime, re-sourced from 3D renders.** The reason props fit is that they are rendered at the true camera angle every frame; a sprite gets the same fit by being rendered from 3D at the true camera angle *once*. That is exactly how AoE2, StarCraft and Diablo 2 built their art, it reuses the existing Meshy assets and `blender_sprite.py`, and it gives 3D asset quality at 2D runtime cost. It **requires** a fixed known camera angle, so it depends on the camera fix above.
- **Scale is unchanged.** §5 wants hundreds of units. That is what killed 3D units originally and nothing here changes it.

Not decided — routed to Andrew.

### 2026-09-04 — Structures: one component schema, and the tower becomes a megastructure

Andrew brought a design brief (written with another AI) to rebuild the structure system around a shared authored block/chunk schema, with layers for visual, collision, navigation, ranged occlusion and destruction. Assessment first, then what was built.

**The brief answered a different question than the one it opened with.** It led with wizard towers as megastructures hosting barracks and research as internal modules — a base-management and economy idea — and then specified ~90% combat: occlusion, cover grades, trajectory types. The economy half was unspecified. That half is now master doc section 39.

**Roughly 60% of the "new" system already existed.** Combat LOS: `MapGenerator.has_line_of_sight(from, to, viewer_height)` via `RTSUnit.can_engage_target()`, cell-keyed, elevation-aware, with an ally-spotter rule. Structures affecting navigation: `BuildSystem._register_blockers()` with footprint to `blocked_cells`. Elevation mattering: unit height is `terrain.get_height(cell)`. Multi-floor structures: the monolith prototype already carries floors, stairs and per-floor walkable counts. The brief's central rule — do not derive gameplay from the rendered mesh — is already this project's spine, so there was no architectural conflict, only redundancy.

**Combat deferred, 2026-09-04.** Dropped for scope, and because a second LOS system that can disagree with the first is how you get "why did my archer shoot through a wall" bugs nobody can reproduce. When occlusion lands it extends `has_line_of_sight`. Also flagged: CLEAR/LIGHT/HEAVY/BLOCKED cover with three sample points per unit is a Company of Heroes feature set, and CoH runs 20–40 units against section 5's hundreds — the player cannot act on per-unit cover at that scale, and it is paid for on every attack.

**Slots over floors or spatial packing.** Fixed slots was chosen because it adds a decision without adding a second building game, which section 14 explicitly warns against. Floors remain the natural upgrade and the prototype already has the groundwork.

**What was built.** `scripts/core/structure_components.gd` — a plain `RefCounted`, no scene dependency, so the whole destruction model is testable headlessly. Components carry HP, `critical`, `depends_on` and an authored cell region. Structural components own cells, so destroying one releases them back to navigation; functional components (modules) own a slot instead. Damage absorbs in a defined order — non-critical structural, then modules, then the critical core — so walls protect modules and modules are the last thing standing. That ordering is deliberately position-independent: which side an attack comes from cannot matter until the occlusion layer exists, and inventing a directional rule before then would be a guess dressed as a system.

**The seam that made it cheap.** Research and production ask "does this player have an Observer Vault". Making `_has_completed_structure()` answer yes for an installed module meant modules arrived without rewriting either system. Likewise `start_placement()` routes a module archetype straight to `build_module()`, so every existing HUD build button works unchanged.

A structure with no authored components gets one implicit critical component holding all its HP, so this is adoptable building by building. Only the tower has authored components today.

**Two tests changed rather than worked around.** `grid_test_map` and `map_3d_interaction` asserted ground placement using `barracks`, which no longer has a location at all — they now use `bio_launcher`, a building that genuinely goes on the ground. Using a module there would have asserted nothing.

**Known gap:** the HUD does not yet show slot counts, which violates section 39's own first design rule — a commitment the player cannot see coming is a trap, not a decision. The constraint is enforced but not communicated. Top follow-up.

**Suite:** 51/52. `seeded_grid_frontier` fails on road connectivity, still pre-existing.

### 2026-09-04 — Block structures: experimental fork, and what the spec pack actually says

Andrew supplied a block-structure test pack (YAML spec, 10 structures, 6 unit classes, 11 nav types) with the goal of Minecraft-style authored blocks generating large explorable structures — caves, ruins, gatehouses — that units enter and move through vertically. Isolated on `experimental/block-structures` at his request, because it is exploratory and because it does not fit the shipping simulation yet.

Built: a YAML→JSON build step with validation (`tools/blocks/convert_structures.py` — Godot has no YAML parser, and every other YAML here is Python-tooling-only, so this is the established pattern), plus `BlockStructureLibrary`, `BlockStructureDefinition` (region expansion into solid cells, nav cells and links) and `BlockStructureNavigation` (per-class traversal). All headlessly testable: navigation is authored data, so proving it needs no scene and no renderer.

**The pack's test cases A–G pass** — infantry through an open gate, infantry to the wall-walk by stairs, heavy through the gate, heavy barred from stairs, climber on a climb point, closed gate blocking ground movement, flying ignoring all of it. Plus two the pack did not ask for: an unconfigured gate defaults to *closed* rather than silently open, and a 3×3 siege unit is excluded from 1-wide stairs by footprint alone.

**Five schema problems, reported and not repaired**, per the pack's own instruction to preserve data and surface ambiguity rather than invent gameplay rules. Three are off-by-one or origin-rule violations (`hollowspire_tower_01` and `giant_stone_bridge_01` place blocks one level above their declared height; `sunken_temple_01` uses negative Y against its own "origin is the minimum corner" rule).

The fifth is structural and was found by probing rather than validating: **every vertical link's bottom endpoint sits in a cell no nav region declares.** `fortress_gatehouse_01`'s `left_stair` begins at (3,0,8), inside a solid block; both climb points on `titan_skull_keep_01` are the same. The gatehouse has no ground-level nav region at all, and its gate passage dead-ends into solid stone instead of running through. So the pack's own cases B and E cannot pass against the original data.

Resolved by authoring, not by inference: `fortress_gatehouse_02_walkable` is a separate id with the passage carved through and a floor declared, the original left byte-for-byte intact. Declaring link endpoints implicitly walkable was rejected — that is precisely the inferred navigation the spec forbids. The smoke test asserts the original's gaps *still exist*, so repairing the source data fails the test loudly rather than letting the correction diverge in silence.

**Not built:** the visual/collision builder, the debug overlay, procedural placement, and integration with the live game. That last one is the real cost and the reason for the fork: the simulation is 2D (`CharacterBody2D`, `AStarGrid2D`, one height per cell) and this system is 3D with authored levels. "Units go inside and move up and down" requires the 2D simulation to gain a concept of level — the same item flagged on 2026-09-04 as the most expensive piece of the earlier structure brief. Nothing here commits to that yet.

**Suite:** 52/53 on the branch. `seeded_grid_frontier` still fails pre-existing.

### 2026-09-04 — Block elevation system: one lattice for terrain and structures

Built on `experimental/block-structures`, on Andrew's call to go for the full system rather than place structures as scenery.

**The idea it rests on:** the terrain is *already* a block grid. Every cell stores an integer height, which is a column of blocks with one standable surface. The elevation system adds nothing to terrain — it stops assuming a column can only have one surface. A wall-walk over a gate passage is one column with two standable levels, and once that is expressible, interiors, bridges over roads and sunken temples are all the same representation. That is why blocks complement the existing grid rather than replacing it.

`BlockNavWorld` is one navigation lattice for a whole map, where a node is `(cell.x, level, cell.z)`. Terrain contributes one node per walkable cell at its own height; a placed structure contributes nodes at its authored levels plus the links between them. A* runs over the whole thing with per-class rules.

**Elevation only ever changes through an authored link.** There is no implicit step-up anywhere. On terrain that link is the existing ramp rule, and it is *delegated to `MapGenerator.is_cliff_edge_cell()`* rather than reimplemented — that function already is the unramped-height-edge test, and a second opinion about whether a unit can walk up a cliff is exactly how movement and vision end up disagreeing.

`BlockUnitRules` was extracted so the lattice and the per-structure navigation resolve class capabilities from one place. A unit that could climb a structure's stairs in isolation but not once it was placed on a map would be a genuinely horrible bug to find.

**Two performance choices made up front rather than as a later rescue**, given this project's history with the 1221ms flow field and the 63ms fog: nodes are encoded as a single int rather than a `Vector3i` dictionary key, and the A* heap uses `PackedFloat64Array` — float32 heap costs are precisely what made the flow field silently reach 3384 cells instead of 7017.

Demonstrated in `block_world_demo.tscn`: 2514 nav nodes over a 48×48 landscape, four authored structures, 18 agents pathing continuously. Measured across passes: 5–8 agents changing elevation at any time, and **zero illegal placements** — an invariant check asserting no agent stands on, or is routed through, a node its class may not occupy. That check catches a whole family of bugs (a heavy on a wall-walk, anything on a closed gate) that are easy to miss by eye in a moving scene.

Also fixed while building the demo: structures were pinned to level 0 regardless of the ground beneath them, leaving them half-buried where terrain rose. A structure's base level now comes from the terrain under its origin, so the two elevation sources compose.

**Not done:** `RTSUnit` still has no level of its own, so the real game is not on this yet. Worth recording that the terrain contract turned out to be only three calls — `is_walkable_cell`, `get_height`, `is_cliff_edge_cell` — all of which `MapGenerator` already implements, so pointing this at the real map is a substitution rather than a port. Flow fields over the lattice are still needed before wave movement at hundreds of units; A* per unit suits the demo's 18 and will not suit 300.

**Suite:** 53/54. `seeded_grid_frontier` still fails pre-existing.
