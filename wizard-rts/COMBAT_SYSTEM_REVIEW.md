# Combat System Review

Scope: KON vertical slice combat, hostility, enemy outposts, objectives, and why visible enemies/outposts may fail to be attackable or aggressive.

This report is inspection-only. No gameplay code changes are proposed as already implemented here.

## Root Cause Hypotheses

Most likely historical causes of visible but non-combat enemies/outposts:

1. Outposts were objective visuals or plot markers, not real combat entities.
2. Right-click attack targeting only considered `units`, not `structures`.
3. Outposts were not registered with `RTSWorld` structure queries.
4. Outposts had no `owner_player_id = 2`, no `take_damage`, or no death signal.
5. Enemy units were visible but not issued attack-move orders after spawning.
6. Enemy AI/combat did not tick because units were not registered in `RTSWorld`.
7. Objective completion was inferred from proximity or invalid node pruning instead of combat death.

In the current workspace, several of these appear to have been addressed: enemy outposts are `KonStructure` nodes, registered as structures, grouped as `units` and `structures`, enemy-owned, damageable, and connected to vertical-slice destruction callbacks.

## Relevant Files

- `scripts/units/rts_unit.gd`
- `scripts/units/deom_legion_unit.gd`
- `scripts/units/rts_projectile.gd`
- `scripts/buildings/kon_structure.gd`
- `scripts/core/combat_system.gd`
- `scripts/core/rts_world.gd`
- `scripts/core/wave_director.gd`
- `scripts/core/kon_vertical_slice_controller.gd`
- `scripts/core/unit_catalog.gd`
- `scripts/input/selection_controller.gd`
- `scripts/core/build_system.gd`
- `scripts/wizard.gd`

## Core Combat Architecture

### Units

`RTSUnit` in `scripts/units/rts_unit.gd` is the main combat unit class. It extends `CharacterBody2D` and owns:

- `owner_player_id`
- `unit_archetype`
- `health`, `max_health`, `armor`, `magic_armor`
- `attack_damage`, `attack_range`, `attack_cooldown`, `attack_type`
- `attack_target`
- movement/path state
- command state such as `move`, `attack_move`, `attack_target`, `hold`, `patrol`

Concrete units generally extend `RTSUnit`:

- `scripts/units/deom_legion_unit.gd`
- `scripts/units/terrible_thing.gd`
- `scripts/units/horror.gd`
- `scripts/units/apex.gd`
- `scripts/units/spawner.gd`
- `scripts/units/oaven_spear.gd`

### Buildings/Structures

`KonStructure` in `scripts/buildings/kon_structure.gd` is the current building/combat-structure class. It extends `StaticBody2D` and owns:

- `archetype`
- `owner_player_id`
- `health`, `max_health`
- `attack_damage`, `attack_range`
- `selection_radius`
- `take_damage()`
- `damage_taken` and `destroyed` signals

`BuildSystem` creates player structures through `_create_structure_node()`. The vertical slice creates enemy outposts directly as `KonStructure`.

### Attack Ticking

`CombatSystem` in `scripts/core/combat_system.gd` is the global combat ticker.

Important functions:

- `_process(delta)`
- `_tick_combat(delta)`

It rebuilds `RTSWorld` spatial buckets, iterates registered units, queries nearby enemy attackables, then calls `unit.rts_combat_tick(...)`.

Important limitation: `CombatSystem` only ticks objects in `RTSWorld.all_units()`. Structures are queryable as targets, but structures do not currently attack unless another system explicitly handles their offence. Player `bio_launcher` offence is handled by `BuildSystem._update_bio_launchers()`. Enemy outpost offence is handled by `KonVerticalSliceController._update_outpost_offense()`, by spawning defenders rather than firing directly.

### Damage/HP/Death

Units:

- `RTSUnit.take_damage(...)`
- `RTSUnit._die(...)`
- `RTSUnit._spawn_death_fx(...)`

Structures:

- `KonStructure.take_damage(...)`
- `KonStructure.destroyed.emit(...)`
- `KonStructure.queue_free()`

Projectiles:

- `RtsProjectile._hit_target()`
- `RtsProjectile._hit_area()`

### Target Acquisition

Unit target acquisition is in `RTSUnit.rts_combat_tick(...)`.

Main flow:

- If an existing `attack_target` is invalid or no longer hostile, clear it.
- If no target exists, call `_find_nearest_enemy(nearby_units)`.
- `CombatSystem` supplies `nearby_units` from `RTSWorld.query_enemy_attackables(...)`.
- `_is_enemy_unit(other)` accepts any `Node2D` with different `owner_player_id` and `take_damage`.

`RTSWorld.query_enemy_attackables(...)` searches both:

- registered units in `_buckets`
- registered structures in `_structure_buckets`

### Commands

Right-click and selection commands are handled by `SelectionController`.

Important functions:

- `_handle_mouse_button(...)`
- `_try_order_attack_target(...)`
- `_attackable_at_position(...)`
- `_is_attackable_candidate(...)`
- `_order_selected_units(...)`

Movement/attack command entry points on units:

- `RTSUnit.issue_move_order(...)`
- `RTSUnit.issue_attack_target(...)`
- `RTSUnit.issue_attack_move_order(...)`
- `RTSUnit.issue_arena_attack_move_order(...)`
- `RTSUnit.issue_hold_position_order()`
- `RTSUnit.issue_stop_order()`

## Faction/Team/Hostility System

The practical team system is `owner_player_id`.

Observed values:

- `1`: player/KON
- `2`: enemy/waves/outposts
- `3`: AI test opposing side
- `4`: possible additional test faction/tint slot
- `-1`: unknown/no owner in helper functions

The catalog may contain `faction` values such as `&"deom_legion"`, but runtime hostility is not decided by catalog faction. Runtime hostility is decided by owner id.

Important checks:

- `RTSUnit._is_enemy_unit(other)`:
  - `other != self`
  - `other is Node2D`
  - `other.get("owner_player_id") != owner_player_id`
  - `other.has_method("take_damage")`

- `SelectionController._is_attackable_candidate(node)`:
  - node exists
  - node has `take_damage`
  - node has `owner_player_id`
  - node owner differs from selected owner

- `RTSWorld.query_enemy_units(...)`:
  - searches registered units only
  - filters by different owner

- `RTSWorld.query_enemy_attackables(...)`:
  - searches registered units and registered structures
  - filters by different owner

Structures and units are treated differently in storage but similarly as attack targets:

- Units register through `RTSWorld.register_unit`.
- Structures register through `RTSWorld.register_structure`.
- `query_enemy_units` ignores structures.
- `query_enemy_attackables` includes structures.
- `CombatSystem` ticks only units, but can feed structures as targets to unit combat.

## KON Unit Combat Flow

1. Selection
   - `SelectionController._select_units(...)` scans `selectable_units`.
   - Only nodes with `owner_player_id == 1` are player-selectable.
   - Units and structures both can be selectable, but drag prioritizes units over structures.

2. Right-click target
   - `SelectionController._handle_mouse_button(...)` receives right click.
   - `_try_order_attack_target(world_pos)` runs before movement.
   - `_attackable_at_position(world_pos)` checks both `units` and `structures` groups.
   - `_is_attackable_candidate(...)` requires different owner and `take_damage`.

3. Attack command
   - For each selected movable unit, `issue_attack_target(target)` is called.
   - This sets `attack_target`, clears movement path, and sets `unit_state = &"attacking"`.

4. Target validation
   - `RTSUnit.rts_combat_tick(...)` validates `attack_target` with `_is_enemy_unit(...)`.
   - A structure can pass this check if it is a `Node2D`, has different `owner_player_id`, and implements `take_damage`.

5. Movement into range
   - If target is outside `_effective_attack_range_to(...)`, `_chase_attack_target()` runs.
   - `_chase_attack_target()` uses `terrain.find_path_world(...)` unless the unit ignores terrain or mass direct chase is active.
   - For structures, `_effective_attack_range_to(...)` adds extra range based on `selection_radius`, helping melee/ranged units attack footprint-sized targets.

6. Damage application
   - In range, `_fire_attack(...)` runs.
   - Melee calls `target.take_damage(...)` directly.
   - Projectile units call `RTSWorld.spawn_projectile(...)`; projectile impact calls `target.take_damage(...)`.

7. Target death
   - Unit targets die through `RTSUnit._die()` and `queue_free()`.
   - Structure targets die through `KonStructure.destroyed.emit(...)` and `queue_free()`.
   - For vertical-slice outposts, `destroyed` is connected to `_on_outpost_destroyed(...)`.

## Enemy Combat Flow

1. Spawning
   - `WaveDirector._spawn_wave()` picks enemy archetypes and spawn cells.
   - `WaveDirector._spawn_enemy(...)` instantiates `enemy_scene`, currently `deom_legion_unit.tscn`.
   - `DeomLegionUnit.configure_enemy(archetype)` applies the catalog definition.

2. Team assignment
   - Deom units have `owner_player_id` defaulting through the unit scene/base class unless explicitly set.
   - In the normal wave path, `_spawn_enemy(...)` does not explicitly set owner in the shown function, so this relies on the enemy scene/script default or prior configuration. This is a high-value review point.
   - In AI test spawning, `_spawn_ai_test_unit(...)` explicitly sets `owner_player_id`.

3. Registration
   - `RTSUnit._ready()` registers itself with `RTSWorld.register_unit(self)` if `../RTSWorld` exists.
   - If spawned under a parent where `../RTSWorld` is not resolvable, the unit may not be included in combat ticking or spatial queries.

4. Initial command
   - `_spawn_enemy(...)` defers `_send_enemy_to_player_target(enemy, preferred_target)`.
   - `_send_enemy_to_player_target(...)` calls `enemy.issue_attack_move_order(target)`.

5. Target acquisition
   - During combat ticks, enemy units query `RTSWorld.query_enemy_attackables(...)`.
   - Player structures can be acquired if registered in `RTSWorld.register_structure`.
   - Player units can be acquired if registered in `RTSWorld.register_unit`.

6. Attacking
   - Same `RTSUnit.rts_combat_tick(...)` path as KON units.
   - Ranged Deom spawn projectiles; melee Deom apply direct damage.

7. Dying
   - Enemy units use `RTSUnit.take_damage()` and `_die()`.

## Enemy Outpost / Structure Combat

Current implementation is in `KonVerticalSliceController._spawn_outpost_objectives()`.

It creates:

- `KonStructure.new()`
- `archetype = &"enemy_outpost"`
- `owner_player_id = 2`
- footprint `4x4`
- HP `640 + i * 160`
- dynamic blockers for footprint cells
- signal connections:
  - `damage_taken -> _on_outpost_damage_taken(...)`
  - `destroyed -> _on_outpost_destroyed(...)`

The outpost is a real combat entity if its `_ready()` runs and finds `../RTSWorld`:

- It has HP.
- It has `owner_player_id = 2`.
- It has `take_damage`.
- It is added to `selectable_units`, `structures`, and `units` groups by `KonStructure.configure(...)`.
- It registers as a structure through `RTSWorld.register_structure(self)`.
- It can be targeted by `SelectionController._attackable_at_position(...)`.
- It can be targeted by automatic combat through `RTSWorld.query_enemy_attackables(...)`.
- It can receive damage from KON units and projectiles.
- It notifies `KonVerticalSliceController` on destruction.

Offence:

- `enemy_outpost` in `UnitCatalog` has `attack_damage = 0` and `attack_range_cells = 0`.
- It does not attack directly.
- It periodically spawns defenders through `KonVerticalSliceController._update_outpost_offense()` and `_spawn_outpost_defender()`.
- Defenders are spawned via `WaveDirector._spawn_enemy(...)`.

Objective completion:

- Primary path: `_on_outpost_destroyed(...)` marks outpost destroyed and removes dynamic blockers.
- Fallback/pruning path: `_prune_outposts()` marks an outpost destroyed if its node becomes invalid.
- Boss gate checks `_outposts_remaining() == 0` plus at least one content plot cleared.

Risk: `_prune_outposts()` can still mark an objective destroyed if the node disappears for any reason, not necessarily combat. That is useful cleanup but not strict “only on death.”

## Vertical Slice Glue

### `kon_vertical_slice_controller.gd`

Creates:

- content plot list from map plots
- required outpost objective list from `enemy_outpost` plots or archetypes containing `outpost`, `camp`, or `ambush`
- `KonStructure` enemy outposts
- periodic outpost defenders
- overlay/debug state
- boss gate
- defeat condition

Current objective model:

- Content plots are still proximity-cleared and reward Bio/Essence.
- Outposts are combat-cleared through `KonStructure.destroyed`.
- Boss trigger requires all tracked outposts destroyed and at least one content plot cleared.

### `wave_director.gd`

Creates enemy waves and boss:

- `_spawn_wave()`
- `_spawn_boss()`
- `_spawn_enemy()`
- `_send_enemy_to_player_target()`
- `_retarget_enemy_army()`

Main risk: normal `_spawn_enemy()` should be audited carefully for explicit `owner_player_id = 2`. AI test spawning sets owner explicitly; normal wave spawning relies on scene defaults unless hidden elsewhere.

### `unit_catalog.gd`

Defines:

- KON units and structures
- `enemy_outpost`
- Deom enemy units
- boss

`enemy_outpost` is an objective structure definition with HP and footprint but no direct attack.

### `kon_structure.gd`

Provides the actual combat interface for buildings:

- `owner_player_id`
- `health`
- `max_health`
- `take_damage`
- `destroyed`
- group registration
- `RTSWorld.register_structure`

Potential oddity: `KonStructure.configure()` adds structures to both `structures` and `units` groups. This helps some generic scans, but `CombatSystem` still only ticks `RTSWorld.all_units()`, not group `units`, when `RTSWorld` exists.

## Known Failure Points

### Wrong team/faction

Any entity with `owner_player_id == 1` is treated as player-owned. Any different owner is hostile. If an enemy unit/outpost is visible but has owner `1`, KON will not attack it and it may be selectable as a player unit/structure.

Normal wave `_spawn_enemy()` should be checked because it does not visibly set `owner_player_id = 2` in the inspected function.

### Missing attackable interface

Targets must have:

- `owner_player_id`
- `take_damage`
- `global_position`
- `is Node2D`

Plot markers, debug overlays, and plain sprites will not be attackable.

### Not registered in `RTSWorld`

For automatic targeting:

- units must be in `RTSWorld._units`
- structures must be in `RTSWorld._structures`

`RTSUnit._ready()` and `KonStructure._ready()` both look for `../RTSWorld`. If scene hierarchy changes and that path is wrong, combat queries can silently miss entities.

### Wrong collision/input layer

Selection currently uses group scans and distance checks, not physics picking, so collision layer is less important for 2D selection. However, if future code uses physics picking, `KonStructure.configure()` currently sets `collision_layer = 0` and disables its collision shape. That would make physics-based targeting fail.

### Target filters use units but not structures

`RTSWorld.query_enemy_units(...)` excludes structures. `query_enemy_attackables(...)` includes structures.

Any system using `query_enemy_units` for attack target acquisition or area damage will miss outposts/buildings. Current `CombatSystem` uses `query_enemy_attackables`; projectile AoE uses `query_enemy_units`, so AoE projectiles likely do not damage structures.

### Missing HP/damage receiver

Anything without `take_damage()` is not targetable by the selection controller or unit target validation.

### Right-click logic only attacks units

Current `SelectionController._attackable_at_position(...)` checks both `units` and `structures`. If a user tests an older build or a different controller path, this was a likely failure.

### Outpost death not connected

Current `_spawn_outpost_objectives()` connects `destroyed` to `_on_outpost_destroyed`. If outposts are created by a different path, the objective state may not update.

### Enemy AI not ticking

`CombatSystem` only calls `rts_combat_tick` for `RTSWorld.all_units()`. If enemies are visible but not registered, they will not acquire targets or attack.

### Wave director spawning passive actors

If `_spawn_enemy()` creates an actor but does not call `_send_enemy_to_player_target()`, or target resolution returns `Vector2.ZERO`, enemies may idle until auto-acquisition sees a nearby target.

### Path target blocked by structures

Outposts add dynamic blockers for their footprint. If the attack target is at the blocked center and no attack range padding existed, melee units could path poorly. Current `_effective_attack_range_to()` adds structure selection-radius padding, reducing this risk.

### Objective completion by invalid node

`_prune_outposts()` marks missing outpost nodes as destroyed. This can mask non-combat deletion as objective completion.

## Minimal Fix Plan

No implementation in this review. Recommended smallest safe changes, ranked:

1. Make enemy ownership explicit in normal wave spawning.
   - In `WaveDirector._spawn_enemy()`, set `owner_player_id = 2` before/after `configure_enemy()`.
   - Reason: removes reliance on scene defaults.

2. Add spawn-time combat validation logging.
   - Validate spawned enemy/outpost has `owner_player_id`, `take_damage`, `rts_world`, and expected groups.
   - Reason: fast diagnosis without changing gameplay.

3. Make outpost objective completion strict.
   - Keep `_on_outpost_destroyed()` as the authoritative clear path.
   - Change `_prune_outposts()` wording/state to “missing/invalid” rather than “destroyed”, or only count combat-destroyed outposts for boss gate.
   - Reason: objective state should update only on combat death.

4. Add direct outpost smoke test coverage.
   - Existing `kon_outpost_combat_smoke_test.gd` appears intended for this.
   - Confirm a KON unit can right-click/attack outpost, reduce HP, destroy it, and update `_outposts_remaining()`.

5. Ensure all target acquisition uses `query_enemy_attackables` where structures should be valid.
   - Keep `query_enemy_units` for unit-only effects.
   - Consider structure-inclusive AoE only if desired.

6. Confirm scene hierarchy assumptions.
   - `RTSUnit` and `KonStructure` expect `../RTSWorld`.
   - If spawned under another parent, pass or resolve `RTSWorld` robustly.

7. Add an outpost direct attack only if defender spawning is insufficient.
   - Current outpost offence is defender spawning, which is valid for the slice.
   - A ranged outpost attack would require adding structure ticking or a dedicated controller loop.

## Suggested Tests

### Automated

1. KON unit vs enemy unit
   - Spawn one KON unit owner `1`.
   - Spawn one Deom unit owner `2`.
   - Issue `issue_attack_target`.
   - Assert enemy HP decreases and enemy eventually dies.

2. Enemy unit attacks KON HQ
   - Spawn `KonStructure` wizard tower owner `1`.
   - Spawn Deom unit owner `2`.
   - Issue enemy attack-move toward tower.
   - Assert tower HP decreases.

3. KON unit vs enemy outpost
   - Spawn vertical-slice outpost owner `2`.
   - Spawn KON combat unit owner `1`.
   - Issue attack target.
   - Assert outpost `damage_taken` fires, HP decreases, then `destroyed` fires.

4. Outpost destruction updates objective count
   - Initialize vertical slice.
   - Destroy one outpost through `take_damage`.
   - Assert `_outposts_remaining()` decreases.

5. Boss trigger waits for real outpost destruction
   - Clear one content plot.
   - Leave outpost alive.
   - Assert boss does not trigger.
   - Destroy outpost through combat damage.
   - Assert boss trigger can occur.

6. Wave enemy ownership
   - Call `WaveDirector._spawn_enemy(...)`.
   - Assert spawned unit `owner_player_id == 2`.
   - Assert unit is present in `RTSWorld.units_for_owner(2)`.

### Manual

1. Start KON vertical slice.
2. Build/train one ranged and one melee KON unit.
3. Right-click a visible Deom unit.
4. Confirm attack command prints/acts and enemy loses HP.
5. Right-click an enemy outpost.
6. Confirm outpost health bar decreases and combat debug shows hostile/targetable.
7. Wait near an outpost.
8. Confirm outpost periodically spawns Deom defenders.
9. Let enemy wave reach the base.
10. Confirm enemies attack wizard tower or player units.
11. Destroy required outposts and clear one content plot.
12. Confirm boss gate triggers only after outpost destruction.

## Exact Functions/Classes To Inspect During Review

- `RTSUnit.issue_attack_target`
- `RTSUnit.issue_attack_move_order`
- `RTSUnit.rts_combat_tick`
- `RTSUnit._is_enemy_unit`
- `RTSUnit._find_nearest_enemy`
- `RTSUnit._chase_attack_target`
- `RTSUnit._fire_attack`
- `RTSUnit.take_damage`
- `RTSUnit._die`
- `RtsProjectile._hit_target`
- `RtsProjectile._hit_area`
- `KonStructure.configure`
- `KonStructure._ready`
- `KonStructure.set_runtime_stats`
- `KonStructure.take_damage`
- `CombatSystem._tick_combat`
- `RTSWorld.register_unit`
- `RTSWorld.register_structure`
- `RTSWorld.query_enemy_units`
- `RTSWorld.query_enemy_attackables`
- `SelectionController._try_order_attack_target`
- `SelectionController._attackable_at_position`
- `SelectionController._is_attackable_candidate`
- `WaveDirector._spawn_enemy`
- `WaveDirector._send_enemy_to_player_target`
- `WaveDirector._retarget_enemy_army`
- `KonVerticalSliceController._spawn_outpost_objectives`
- `KonVerticalSliceController._update_outpost_offense`
- `KonVerticalSliceController._spawn_outpost_defender`
- `KonVerticalSliceController._on_outpost_destroyed`
- `KonVerticalSliceController._prune_outposts`
- `KonVerticalSliceController._check_boss_gate`
