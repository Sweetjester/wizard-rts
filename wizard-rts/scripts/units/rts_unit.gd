class_name RTSUnit
extends CharacterBody2D

const UNIT_DEATH_FX_SCRIPT := preload("res://scripts/fx/unit_death_fx.gd")
const SPAWNER_DRONE_SCENE_PATH := "res://scenes/units/spawner_drone.tscn"

@export var move_speed: float = 180.0
@export var selection_radius: float = 24.0
@export var stop_distance: float = 3.0
@export var terrain_path: NodePath = NodePath("../MapGenerator")
@export var collision_separation: float = 18.0
@export var separation_bucket_size: float = 96.0
@export var owner_player_id: int = 1
@export var unit_archetype: StringName = &"life_treant"
@export var max_health: int = 80
@export var armor: int = 0
@export var magic_armor: int = 0
@export var attack_damage: int = 8
@export var attack_range: float = 96.0
@export var attack_cooldown: float = 1.0
@export var attack_type: StringName = &"melee"
@export var attack_splash_radius: float = 0.0
@export var projectile_speed: float = 620.0
@export var ignores_terrain: bool = false

static var _registered_units: Array[Node2D] = []
static var _spatial_frame := -1
static var _spatial_bucket_size := 96.0
static var _spatial_buckets: Dictionary = {}
static var _mass_collision_frame := -1
static var _mass_collision_calls := 0
static var _mass_collision_neighbors := 0
static var _mass_collision_overlap_checks := 0

var selected := false
var target_pos := Vector2.ZERO
var moving := false
var path: Array[Vector2] = []
# Block elevation (experimental, 2026-09-04). The level this unit is standing
# on. Terrain height for a unit on open ground, but a unit on a wall-walk or an
# upper floor stands at a level the terrain cell below it knows nothing about --
# which is the whole point of the lattice.
#
# `path_levels` runs parallel to `path`. It is EMPTY for every ordinary order,
# and an empty list means "no elevation data, keep the level you have", so
# nothing about normal 2D movement changes.
var nav_level: int = 0
var path_levels: Array[int] = []
var terrain: Node
var rts_world: RTSWorld
var simulation_entity_id: int = 0
var health: int = 80
var unit_state: StringName = &"idle"
var attack_target: Node2D = null
var command_mode: StringName = &"idle"
var patrol_a := Vector2.ZERO
var patrol_b := Vector2.ZERO
var _patrol_heading_to_b := true
var evolution_xp: float = 0.0
var evolution_level: int = 1
var stunned_until_msec: int = 0
var _attack_elapsed: float = 0.0
var _last_z_cell_y := 999999
var _visual_elapsed := 0.0
var _facing_sign := 1.0
var _last_melee_attack_msec: int = -10000
var _command_destination := Vector2.ZERO
var _has_command_destination := false
var _last_progress_position := Vector2.ZERO
var _stuck_elapsed := 0.0
var _last_repath_msec: int = -10000
var _last_chase_repath_msec: int = -10000
var _last_arena_objective_msec: int = -10000
var _redraw_elapsed := 0.0
var _mass_physics_accum := 0.0
var _last_leash_repath_msec: int = -10000
var _grapple_elapsed := 99.0
var _spawner_elapsed := 99.0
var _life_elapsed := 0.0
var _charge_until_msec := 0
var _spawner_rooted := false
var _root_cast_remaining := 0.0
var _uproot_cast_remaining := 0.0
var _flight_cast_remaining := 0.0
var _flight_state: StringName = &"grounded"
var _temporary_flight_until_msec := 0
var _slowed_until_msec := 0
var _slow_multiplier := 1.0
var _taunt_until_msec := 0
var _cripple_last_msec := -100000
var _jumper_landing_ready := false
var _hunt_elapsed := 0.0
var _hunt_charges := 0
var _observer_aura_enabled := false
# Master Design Doc section 38. Runtime values, not constants -- Observer Vault
# research raises intelligence, so a unit can become more obedient over a run.
var intelligence: int = UnitCatalog.DEFAULT_INTELLIGENCE
var aggro_range: float = 256.0
var weapon_mode: StringName = &""
# How far above the ground this unit is standing, when it is on a structure's
# floor rather than on open ground. Set by VantageEffects; 0 means no vantage.
var vantage_height: int = 0
var vantage_region: StringName = &""
var _weapon_swap_remaining := 0.0
# Cached at spawn from UnitCatalog.kon_theme() so _draw() never has to look it
# up. The KoN roster doc splits the faction into an "observer" theme
# (black/silver -- Kon himself, the Observation Tower, the Observer Vault) and
# an "evolution" theme (#67BED9 / #a95766 -- every hybrid, the Vinewall, the
# Bio Launcher, the Bio Absorber).
var _kon_theme: StringName = &"evolution"
var animation_action: StringName = &"idle"
var ability_animation_action: StringName = &""
var _ability_animation_until_msec := 0
var _economy_manager: EconomyManager
var mass_lane_offset := Vector2.ZERO
var arena_leash_enabled := false
var arena_leash_rect := Rect2()
var arena_home := Vector2.ZERO
var _dying := false
var _drone_children: Array[Node2D] = []
var _mass_art_hidden := false
var _force_lightweight_arena_unit := false
var _central_mass_movement_active := false
var _damage_over_time_effects: Array[Dictionary] = []
var _flow_field_attack_move_active := false
var _last_flow_field_refresh_msec: int = -10000

func _ready() -> void:
	collision_layer = 2
	collision_mask = 2
	target_pos = global_position
	_apply_catalog_definition()
	_apply_owner_art_tint()
	health = max_health
	terrain = get_node_or_null(terrain_path)
	rts_world = get_node_or_null("../RTSWorld")
	_economy_manager = get_node_or_null("../EconomyManager")
	add_to_group("selectable_units")
	add_to_group("units")
	# In 3D presentation the unit is rendered as a multimesh instance by
	# Map3DView, so its 2D canvas drawing is switched off. Hiding the node skips
	# _draw() entirely rather than paying for it and discarding the result.
	if rts_world != null and is_instance_valid(rts_world) and rts_world.presentation_3d:
		visible = false
	if rts_world != null:
		rts_world.register_unit(self)
	_register_unit(self)
	call_deferred("_snap_to_walkable_terrain")

func _exit_tree() -> void:
	if rts_world != null and is_instance_valid(rts_world):
		rts_world.unregister_unit(self)
	_unregister_unit(self)

func _process(delta: float) -> void:
	_visual_elapsed += delta
	_redraw_elapsed += delta
	var mass_mode := _mass_performance_mode()
	_update_mass_art_lod()
	if selected:
		if not _selection_is_bulk():
			queue_redraw()
			_redraw_elapsed = 0.0
			return
		# Bulk selection: use the same throttled redraw cadence as everything
		# else instead of redrawing every frame. The selection ring still
		# draws, just at the tier's normal interval.
		var selected_interval := _mass_redraw_interval() if mass_mode else _normal_redraw_interval()
		if _redraw_elapsed >= selected_interval:
			queue_redraw()
			_redraw_elapsed = 0.0
		return
	if health < max_health:
		var damaged_redraw_interval := 0.35 if mass_mode else 0.18
		if _redraw_elapsed >= damaged_redraw_interval:
			queue_redraw()
			_redraw_elapsed = 0.0
		return
	if moving or unit_state in [&"attacking", &"attack_move", &"patrol", &"hold", &"stunned"]:
		var redraw_interval := _mass_redraw_interval() if mass_mode else _normal_redraw_interval()
		if _redraw_elapsed >= redraw_interval:
			queue_redraw()
			_redraw_elapsed = 0.0

func set_selected(value: bool) -> void:
	selected = value
	if selected:
		if not _selection_is_bulk():
			set_central_mass_movement_active(false)
		set_process(true)
	elif use_mass_vector_lod():
		set_process(false)
	queue_redraw()

func prepare_lightweight_arena_unit() -> void:
	_force_lightweight_arena_unit = true
	_central_mass_movement_active = true
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var shape := get_node_or_null("CollisionShape2D")
	if shape != null:
		shape.queue_free()
	var art := get_node_or_null("ArtSprite")
	if art != null:
		art.queue_free()
	_mass_art_hidden = true
	queue_redraw()

func is_inside_selection_rect(rect: Rect2) -> bool:
	return rect.has_point(global_position)

func issue_move_order(world_pos: Vector2) -> void:
	_clear_flow_field_order()
	if _blocks_movement_for_rooting():
		return
	if _requires_takeoff_for_move():
		_start_takeoff()
		_command_destination = _legal_destination(world_pos)
		_has_command_destination = true
		return
	attack_target = null
	command_mode = &"move"
	unit_state = &"moving"
	_set_path_to_world(world_pos, true)
	_queue_unit_redraw()

func issue_move_order_offset(world_pos: Vector2, offset: Vector2) -> void:
	issue_move_order(world_pos + offset)

func issue_shared_path_order(shared_path: Array[Vector2], offset: Vector2) -> void:
	_clear_flow_field_order()
	if _blocks_movement_for_rooting():
		return
	attack_target = null
	command_mode = &"move"
	unit_state = &"moving"
	path.clear()
	if shared_path.is_empty():
		moving = false
		_has_command_destination = false
		return
	var final_target := _legal_destination(shared_path[shared_path.size() - 1] + offset)
	if _requires_takeoff_for_move():
		_start_takeoff()
		_command_destination = final_target
		_has_command_destination = true
		return
	_command_destination = final_target
	_has_command_destination = true
	path = _joined_shared_path(shared_path, final_target)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()
	_queue_unit_redraw()

func _physics_process(delta: float) -> void:
	if uses_central_mass_movement():
		return
	rts_movement_tick(delta)

func set_central_mass_movement_active(enabled: bool) -> void:
	if _force_lightweight_arena_unit:
		return
	# A hand-managed squad stays on per-node physics so it feels responsive.
	# A whole-army selection does not -- otherwise Select Army would pull every
	# blob unit off RTSWorld's budgeted central movement loop at once.
	if selected and not _selection_is_bulk():
		enabled = false
	if enabled == _central_mass_movement_active:
		return
	_central_mass_movement_active = enabled
	set_physics_process(not enabled)

func uses_central_mass_movement() -> bool:
	return _force_lightweight_arena_unit or _central_mass_movement_active

func rts_movement_tick(delta: float) -> void:
	if is_banished():
		velocity = Vector2.ZERO
		moving = false
		path.clear()
		path_levels.clear()
		return
	_life_elapsed += delta
	_update_weapon_swap(delta)
	_update_limited_lifetime()
	_update_damage_over_time(delta)
	_update_temporary_status_effects()
	if _observer_aura_enabled:
		velocity=Vector2.ZERO
		moving=false
		path.clear()
		path_levels.clear()
		unit_state=&"observing"
		return
	_update_spawner_root_casts(delta)
	_update_winged_spawner_flight(delta)
	if _flight_cast_remaining > 0.0:
		velocity = Vector2.ZERO
		moving = false
		return
	var mass_mode := _mass_performance_mode()
	var sim_delta := _mass_simulation_delta(delta, mass_mode)
	if sim_delta <= 0.0:
		return
	if _blocks_movement_for_rooting():
		velocity = Vector2.ZERO
		moving = false
		return
	if _is_stunned():
		velocity = Vector2.ZERO
		if not mass_mode:
			move_and_slide()
		return
	_update_z_index()
	if arena_leash_enabled and not arena_leash_rect.has_point(global_position):
		_pull_back_to_arena()
	if _flow_field_attack_move_active and command_mode == &"attack_move" and attack_target == null:
		_refresh_flow_field_attack_move_path()
	if path.is_empty():
		_reset_stuck_watch()
		velocity = _mass_idle_separation_velocity() if mass_mode else _separation_velocity()
		moving = false
		if command_mode == &"patrol" and attack_target == null:
			_resume_patrol_leg()
		elif attack_target == null and command_mode == &"hold":
			unit_state = &"hold"
		elif attack_target == null and command_mode == &"attack_move":
			unit_state = &"attack_move"
			_maintain_arena_attack_objective()
		elif attack_target == null:
			unit_state = &"idle"
			_try_land_winged_spawner()
		if mass_mode:
			if velocity.length_squared() > 1.0:
				global_position += velocity * sim_delta
		else:
			move_and_slide()
		return

	target_pos = path[0]
	_advance_path_lookahead()
	if path.is_empty():
		_reset_stuck_watch()
		moving = false
		return
	target_pos = path[0]
	var dir := target_pos - global_position
	if absf(dir.x) > 0.5:
		_facing_sign = signf(dir.x)
	var current_speed := _current_move_speed()
	var step := current_speed * sim_delta
	if dir.length() <= max(stop_distance, step):
		global_position = target_pos
		velocity = Vector2.ZERO
		_pop_path_front()
		moving = not path.is_empty()
		if not moving:
			if command_mode == &"patrol":
				_resume_patrol_leg()
			elif command_mode == &"attack_move":
				unit_state = &"attack_move"
			else:
				unit_state = &"idle"
				_try_land_winged_spawner()
		_queue_unit_redraw()
		return

	var move_dir := dir.normalized()
	var separation := _mass_separation_velocity(move_dir) if mass_mode else _separation_velocity(move_dir)
	velocity = move_dir * current_speed + separation
	if mass_mode:
		var proposed := global_position + velocity * sim_delta
		if _uses_hard_mass_overlap_blocking() and _would_overlap_at(proposed, move_dir):
			var side_step := Vector2(-move_dir.y, move_dir.x) * current_speed * 0.35
			var side_a := global_position + (side_step + separation) * sim_delta
			var side_b := global_position + (-side_step + separation) * sim_delta
			if not _would_overlap_at(side_a, move_dir):
				velocity = side_step + separation
			elif not _would_overlap_at(side_b, move_dir):
				velocity = -side_step + separation
			else:
				velocity = separation + move_dir * current_speed * 0.12
		global_position += velocity * sim_delta
	else:
		move_and_slide()
	_update_stuck_recovery(sim_delta)

func issue_attack_target(target: Node2D) -> void:
	_clear_flow_field_order()
	if target == null or not is_instance_valid(target):
		return
	attack_target = target
	command_mode = &"attack_target"
	_has_command_destination = false
	path.clear()
	moving = false
	unit_state = &"attacking"

func issue_attack_move_order(world_pos: Vector2) -> void:
	_clear_flow_field_order()
	if _blocks_movement_for_rooting():
		return
	if _requires_takeoff_for_move():
		_start_takeoff()
		command_mode = &"attack_move"
		unit_state = &"takeoff"
		_command_destination = _legal_destination(world_pos)
		_has_command_destination = true
		return
	issue_move_order(world_pos)
	command_mode = &"attack_move"
	unit_state = &"attack_move"

func issue_flow_field_attack_move_order(world_pos: Vector2) -> void:
	if _blocks_movement_for_rooting():
		return
	if _requires_takeoff_for_move():
		_start_takeoff()
		_flow_field_attack_move_active = true
		command_mode = &"attack_move"
		unit_state = &"takeoff"
		_command_destination = _legal_destination(world_pos)
		_has_command_destination = true
		return
	attack_target = null
	command_mode = &"attack_move"
	unit_state = &"attack_move"
	_command_destination = _legal_destination(world_pos)
	_has_command_destination = true
	_flow_field_attack_move_active = true
	_refresh_flow_field_attack_move_path(true)
	if path.is_empty():
		path = _world_path_to(_command_destination)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()
	_queue_unit_redraw()

func issue_arena_attack_move_order(world_pos: Vector2) -> void:
	_clear_flow_field_order()
	if _blocks_movement_for_rooting():
		return
	if _requires_takeoff_for_move():
		_start_takeoff()
		command_mode = &"attack_move"
		unit_state = &"takeoff"
		var deferred_target := _legal_destination(_clamp_to_arena(world_pos))
		_command_destination = deferred_target
		_has_command_destination = true
		return
	attack_target = null
	command_mode = &"attack_move"
	unit_state = &"attack_move"
	var legal_target := _legal_destination(_clamp_to_arena(world_pos))
	_command_destination = legal_target
	_has_command_destination = true
	path = [legal_target]
	moving = true
	target_pos = legal_target
	_reset_stuck_watch()
	_queue_unit_redraw()

func issue_patrol_order(world_pos: Vector2) -> void:
	_clear_flow_field_order()
	if _blocks_movement_for_rooting():
		return
	if _requires_takeoff_for_move():
		_start_takeoff()
		command_mode = &"patrol"
		patrol_a = global_position
		patrol_b = world_pos
		_patrol_heading_to_b = true
		_command_destination = _legal_destination(world_pos)
		_has_command_destination = true
		return
	attack_target = null
	command_mode = &"patrol"
	patrol_a = global_position
	patrol_b = world_pos
	_patrol_heading_to_b = true
	_set_path_to_world(patrol_b, true)
	unit_state = &"patrol"

func issue_hold_position_order() -> void:
	_clear_flow_field_order()
	attack_target = null
	command_mode = &"hold"
	_has_command_destination = false
	path.clear()
	moving = false
	velocity = Vector2.ZERO
	unit_state = &"hold"
	_queue_unit_redraw()

func issue_stop_order() -> void:
	_clear_flow_field_order()
	attack_target = null
	command_mode = &"idle"
	_has_command_destination = false
	path.clear()
	moving = false
	velocity = Vector2.ZERO
	unit_state = &"idle"
	_queue_unit_redraw()

func rts_combat_tick(delta: float, nearby_units: Array[Node2D]) -> void:
	if health <= 0 or is_banished() or _is_stunned() or _flight_cast_remaining > 0.0:
		return
	_attack_elapsed += delta
	_grapple_elapsed += delta
	_spawner_elapsed += delta
	_update_hunt_passive(delta)
	_update_animation_action()
	if _observer_aura_enabled:
		attack_target = null
		unit_state = &"observing"
		return
	if attack_target != null and (not is_instance_valid(attack_target) or not _is_enemy_unit(attack_target) or not can_engage_target(attack_target)):
		attack_target = null
		if command_mode == &"attack_move":
			_resume_attack_move_objective()
	if attack_target == null:
		attack_target = _find_nearest_enemy(nearby_units)
	_update_autonomy_override(attack_target)
	if attack_target == null:
		_update_spawner_drones(nearby_units)
		return
	_update_spawner_drones(nearby_units)
	if _requires_root_to_fire() and not _spawner_rooted:
		if owner_player_id != 1 and _root_cast_remaining <= 0.0:
			activate_root()
		return
	var distance := global_position.distance_to(attack_target.global_position)
	var effective_attack_range := _effective_attack_range_to(attack_target)
	if distance > effective_attack_range:
		if _blocks_movement_for_rooting():
			return
		if command_mode == &"hold":
			return
		if unit_state == &"attacking" or command_mode in [&"attack_move", &"attack_target", &"patrol"]:
			_chase_attack_target()
		return
	if _try_oaven_jumper_landing(attack_target):
		return
	path.clear()
	moving = false
	if _spawner_rooted:
		unit_state = &"rooted"
	else:
		unit_state = &"attacking"
	if _attack_elapsed < _current_attack_cooldown():
		return
	# Swapping between the Oaven's spear and blowpipe costs a beat of uptime --
	# otherwise the swap is a free stat toggle with no decision behind it.
	if _weapon_swap_remaining > 0.0:
		return
	_attack_elapsed = 0.0
	if attack_target.has_method("take_damage"):
		if not _spend_attack_bio():
			return
		_try_auto_grapple(attack_target)
		var weapon := WeaponCatalog.get_weapon(unit_archetype)
		var casts := int(weapon.get("casts", 2 if bool(UnitCatalog.get_definition(unit_archetype).get("dual_cast", false)) else 1))
		var damage_multiplier := _consume_attack_damage_multiplier()
		for _i in casts:
			if is_instance_valid(attack_target):
				_fire_attack(attack_target, damage_multiplier)
				_gain_evolution_xp(float(attack_damage) * 0.6)
		var heal := int(UnitCatalog.get_definition(unit_archetype).get("heal_per_attack", 0))
		if heal > 0:
			heal_damage(heal)

func needs_combat_query() -> bool:
	if health <= 0 or _is_stunned():
		return false
	if attack_target != null and is_instance_valid(attack_target) and _is_enemy_unit(attack_target):
		return false
	return true

func _chase_attack_target() -> void:
	if attack_target == null:
		return
	var now := Time.get_ticks_msec()
	var mass_mode := _mass_performance_mode()
	var repath_interval := _mass_repath_interval() if mass_mode else 300
	if moving and now - _last_chase_repath_msec < repath_interval:
		return
	_last_chase_repath_msec = now
	var chase_target := attack_target.global_position
	if arena_leash_enabled:
		chase_target = _clamp_to_arena(chase_target)
	_command_destination = _legal_destination(chase_target)
	_has_command_destination = true
	if _requires_takeoff_for_move():
		_start_takeoff()
		return
	if ignores_terrain or terrain == null or _uses_direct_mass_arena_chase():
		path = [_command_destination]
	else:
		path = terrain.find_path_world(global_position, _command_destination)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()
	unit_state = &"attacking"

func _resume_attack_move_objective() -> void:
	if command_mode != &"attack_move" or _blocks_movement_for_rooting():
		return
	if arena_leash_enabled:
		var now := Time.get_ticks_msec()
		if now - _last_arena_objective_msec < _arena_objective_interval_msec():
			return
		_last_arena_objective_msec = now
		var objective := _arena_pressure_objective()
		if objective != Vector2.ZERO:
			_command_destination = objective
			_has_command_destination = true
			path = _single_point_path(objective) if _uses_direct_mass_arena_chase() or ignores_terrain else _world_path_to(objective)
			moving = not path.is_empty()
			if moving:
				target_pos = path[0]
				unit_state = &"attack_move"
				_reset_stuck_watch()
		return
	if _has_command_destination:
		if _flow_field_attack_move_active:
			_refresh_flow_field_attack_move_path(true)
			if path.is_empty():
				path = _world_path_to(_command_destination)
		else:
			path = _world_path_to(_command_destination)
		moving = not path.is_empty()
		if moving:
			target_pos = path[0]
			unit_state = &"attack_move"
			_reset_stuck_watch()

func _clear_flow_field_order() -> void:
	_flow_field_attack_move_active = false
	_last_flow_field_refresh_msec = -10000

func _refresh_flow_field_attack_move_path(force: bool = false) -> void:
	if not _flow_field_attack_move_active or not _has_command_destination:
		return
	if ignores_terrain or terrain == null or not terrain.has_method("get_flow_field_waypoints_world"):
		return
	if global_position.distance_squared_to(_command_destination) <= maxf(attack_range * 0.35, 32.0) * maxf(attack_range * 0.35, 32.0):
		path.clear()
		moving = false
		return
	var now := Time.get_ticks_msec()
	if not force and not path.is_empty() and now - _last_flow_field_refresh_msec < 550:
		return
	_last_flow_field_refresh_msec = now
	var flow_path: Array[Vector2] = []
	for point in terrain.call("get_flow_field_waypoints_world", global_position, _command_destination, 5):
		flow_path.append(point)
	if flow_path.is_empty():
		if force or path.is_empty():
			path = _world_path_to(_command_destination)
			moving = not path.is_empty()
			if moving:
				target_pos = path[0]
				_reset_stuck_watch()
		return
	path = _dedupe_path(flow_path)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()

func _maintain_arena_attack_objective() -> void:
	if not arena_leash_enabled or command_mode != &"attack_move" or attack_target != null or _blocks_movement_for_rooting():
		return
	var now := Time.get_ticks_msec()
	if now - _last_arena_objective_msec < _arena_objective_interval_msec():
		return
	_last_arena_objective_msec = now
	var count := rts_world.count_units_all() if rts_world != null and is_instance_valid(rts_world) else 0
	if count < 300:
		var nearby_target := _arena_nearest_enemy_objective()
		if nearby_target != null and is_instance_valid(nearby_target):
			attack_target = nearby_target
			unit_state = &"attacking"
			return
	var objective := _arena_pressure_objective()
	if objective == Vector2.ZERO:
		return
	if global_position.distance_squared_to(objective) < 48.0 * 48.0:
		objective += _arena_lane_jitter()
	_command_destination = objective
	_has_command_destination = true
	path = _single_point_path(objective) if _uses_direct_mass_arena_chase() or ignores_terrain else _world_path_to(objective)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()

func _arena_pressure_objective() -> Vector2:
	if rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 300:
		return _clamp_to_arena(arena_home + _arena_lane_jitter())
	var target := _arena_nearest_enemy_position(1800.0)
	if target != Vector2.ZERO:
		return _clamp_to_arena(target + _arena_lane_jitter())
	return _clamp_to_arena(arena_home + _arena_lane_jitter())

func _arena_nearest_enemy_objective() -> Node2D:
	if rts_world == null or not is_instance_valid(rts_world):
		return null
	var radius := 520.0
	var candidates := rts_world.query_enemy_attackables(global_position, radius, owner_player_id, 4) if rts_world.has_method("query_enemy_attackables") else []
	var best: Node2D = null
	var best_distance := INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or not _is_enemy_unit(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func _arena_nearest_enemy_position(radius: float) -> Vector2:
	if rts_world == null or not is_instance_valid(rts_world):
		return Vector2.ZERO
	var candidates := rts_world.query_enemy_attackables(global_position, radius, owner_player_id, 8) if rts_world.has_method("query_enemy_attackables") else []
	var best := Vector2.ZERO
	var best_distance := INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or not _is_enemy_unit(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best = candidate.global_position
			best_distance = distance
	return best

func _arena_lane_jitter() -> Vector2:
	var seed := float(posmod(get_instance_id(), 23)) - 11.0
	return Vector2(0.0, seed * 10.0) + mass_lane_offset * 0.35

func _arena_objective_interval_msec() -> int:
	if rts_world == null or not is_instance_valid(rts_world):
		return 1100
	var count := rts_world.count_units_all()
	if count >= 2000:
		return 9000
	if count >= 1600:
		return 7000
	if count >= 900:
		return 5200
	if count >= 500:
		return 3600
	if count >= 300:
		return 2200
	return 850

func _single_point_path(point: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	result.append(point)
	return result

func _set_path_to_world(world_pos: Vector2, track_destination: bool = false) -> void:
	var legal_target := _legal_destination(world_pos)
	if track_destination:
		_command_destination = legal_target
		_has_command_destination = true
	if ignores_terrain or terrain == null:
		path = [legal_target]
	else:
		path = terrain.find_path_world(global_position, legal_target)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
		_reset_stuck_watch()

func _legal_destination(world_pos: Vector2) -> Vector2:
	if ignores_terrain or terrain == null or not terrain.has_method("world_to_cell") or not terrain.has_method("is_walkable_cell"):
		return world_pos
	var target_cell: Vector2i = terrain.world_to_cell(world_pos)
	if terrain.is_walkable_cell(target_cell):
		return terrain.cell_to_world(target_cell)
	if terrain.has_method("nearest_walkable_cell"):
		var legal_cell: Vector2i = terrain.nearest_walkable_cell(target_cell, 12)
		if terrain.is_walkable_cell(legal_cell):
			return terrain.cell_to_world(legal_cell)
	return world_pos

func _joined_shared_path(shared_path: Array[Vector2], final_target: Vector2) -> Array[Vector2]:
	if shared_path.is_empty():
		return []
	if ignores_terrain or terrain == null or not terrain.has_method("find_path_world"):
		return _dedupe_path([final_target])
	var join_limit: int = mini(shared_path.size(), 8)
	for join_index in join_limit:
		var join_path: Array[Vector2] = []
		for point in terrain.find_path_world(global_position, shared_path[join_index]):
			join_path.append(point)
		if join_path.is_empty():
			continue
		for i in range(join_index + 1, shared_path.size()):
			join_path.append(shared_path[i])
		if not join_path.is_empty():
			join_path[join_path.size() - 1] = final_target
		return _dedupe_path(join_path)
	return _world_path_to(final_target)

func _world_path_to(world_pos: Vector2) -> Array[Vector2]:
	var target := _legal_destination(world_pos)
	if ignores_terrain or terrain == null or not terrain.has_method("find_path_world"):
		return [target]
	var world_path: Array[Vector2] = []
	for point in terrain.find_path_world(global_position, target):
		world_path.append(point)
	return _dedupe_path(world_path)

func _dedupe_path(points: Array[Vector2]) -> Array[Vector2]:
	var clean: Array[Vector2] = []
	for point in points:
		if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(point) > 9.0:
			clean.append(point)
	return clean

func _reset_stuck_watch() -> void:
	_last_progress_position = global_position
	_stuck_elapsed = 0.0

func _update_stuck_recovery(delta: float) -> void:
	if ignores_terrain or terrain == null or path.is_empty():
		_reset_stuck_watch()
		return
	if global_position.distance_squared_to(_last_progress_position) > 36.0:
		_reset_stuck_watch()
		return
	if global_position.distance_squared_to(target_pos) <= 144.0:
		_reset_stuck_watch()
		return
	_stuck_elapsed += delta
	if _stuck_elapsed < 0.65:
		return
	var now := Time.get_ticks_msec()
	if now - _last_repath_msec < 650:
		return
	_last_repath_msec = now
	_recover_from_stuck()

func _recover_from_stuck() -> void:
	_reset_stuck_watch()
	_nudge_to_walkable_cell()
	if _has_command_destination:
		path = _world_path_to(_command_destination)
	elif not path.is_empty():
		path = _world_path_to(path[path.size() - 1])
	if path.is_empty():
		path = _escape_path_to_neighbor()
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
	else:
		velocity = Vector2.ZERO

func _nudge_to_walkable_cell() -> void:
	if terrain == null or not terrain.has_method("world_to_cell") or not terrain.has_method("is_walkable_cell") or not terrain.has_method("nearest_walkable_cell"):
		return
	var cell: Vector2i = terrain.world_to_cell(global_position)
	if terrain.is_walkable_cell(cell):
		return
	var legal_cell: Vector2i = terrain.nearest_walkable_cell(cell, 4)
	if terrain.is_walkable_cell(legal_cell):
		global_position = terrain.cell_to_world(legal_cell)

func _escape_path_to_neighbor() -> Array[Vector2]:
	var escape: Array[Vector2] = []
	if terrain == null or not terrain.has_method("world_to_cell") or not terrain.has_method("is_walkable_cell"):
		return escape
	var origin: Vector2i = terrain.world_to_cell(global_position)
	for radius in range(1, 4):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if not terrain.is_walkable_cell(cell):
					continue
				if terrain.has_method("_has_clear_path_segment") and not terrain.call("_has_clear_path_segment", origin, cell):
					continue
				escape.append(terrain.cell_to_world(cell))
				return escape
	return escape

func _resume_patrol_leg() -> void:
	_patrol_heading_to_b = not _patrol_heading_to_b
	_set_path_to_world(patrol_b if _patrol_heading_to_b else patrol_a, true)
	unit_state = &"patrol"

func _fire_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	if _uses_projectile():
		if _uses_mass_direct_aoe_attack():
			_fire_mass_direct_aoe_attack(target, damage_multiplier)
			return
		if _uses_mass_hitscan_attack():
			var weapon := WeaponCatalog.get_weapon(unit_archetype)
			target.take_damage(maxi(1, int(float(weapon.get("damage", attack_damage)) * damage_multiplier)), self)
			return
		_spawn_projectile(target, damage_multiplier)
	else:
		_last_melee_attack_msec = Time.get_ticks_msec()
		if not _mass_performance_mode() or selected:
			queue_redraw()
		target.take_damage(maxi(1, int(float(attack_damage) * damage_multiplier)), self)
		_try_oaven_crippling_attack(target)

func _uses_projectile() -> bool:
	return WeaponCatalog.uses_projectile(unit_archetype)

func _uses_mass_hitscan_attack() -> bool:
	if selected or rts_world == null or not is_instance_valid(rts_world):
		return false
	var threshold := 900
	if terrain != null and str(terrain.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena"]:
		threshold = 260
	if rts_world.count_units_all() < threshold:
		return false
	var weapon := WeaponCatalog.get_weapon(unit_archetype)
	if weapon.get("kind", &"melee") == &"artillery":
		return false
	if float(weapon.get("aoe_radius", 0.0)) > 0.0:
		return false
	return unit_archetype in [&"horror", &"hunter", &"apex", &"champion", &"spawner_drone", &"spore_spitter", &"deom_scout", &"deom_crosshirran", &"deom_glaive", &"deom_odden"]

func _uses_mass_direct_aoe_attack() -> bool:
	if selected or rts_world == null or not is_instance_valid(rts_world):
		return false
	if terrain == null or str(terrain.get("map_type_id")) not in ["ai_testing_ground", "fortress_ai_arena"]:
		return false
	if rts_world.count_units_all() < 180:
		return false
	var weapon := WeaponCatalog.get_weapon(unit_archetype)
	return weapon.get("kind", &"melee") == &"artillery" and float(weapon.get("aoe_radius", 0.0)) > 0.0

func _fire_mass_direct_aoe_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	if target == null or not is_instance_valid(target) or rts_world == null or not is_instance_valid(rts_world):
		return
	var weapon := WeaponCatalog.get_weapon(unit_archetype)
	var radius := float(weapon.get("aoe_radius", 0.0))
	var damage := maxi(1, int(float(weapon.get("damage", attack_damage)) * damage_multiplier))
	var center := target.global_position
	var max_hits := 10
	var count := rts_world.count_units_all()
	if count >= 1800:
		max_hits = 5
	elif count >= 1000:
		max_hits = 7
	var victims := rts_world.query_enemy_units(center, radius, owner_player_id, max_hits) if rts_world.has_method("query_enemy_units") else []
	if victims.is_empty() and target.has_method("take_damage"):
		target.take_damage(damage, self)
		return
	for victim in victims:
		if not is_instance_valid(victim) or not victim.has_method("take_damage"):
			continue
		var falloff := clampf(1.0 - center.distance_to(victim.global_position) / maxf(radius * 1.35, 1.0), 0.35, 1.0)
		victim.take_damage(maxi(1, int(float(damage) * falloff)), self)

func _update_hunt_passive(delta: float) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var interval := float(definition.get("hunt_charge_seconds", 0.0))
	if interval <= 0.0:
		_hunt_elapsed = 0.0
		_hunt_charges = 0
		return
	_hunt_elapsed += delta
	var max_charges := int(definition.get("hunt_max_charges", 1))
	while _hunt_elapsed >= interval:
		_hunt_elapsed -= interval
		_hunt_charges = mini(max_charges, _hunt_charges + 1)

func _consume_attack_damage_multiplier() -> float:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var multiplier := 1.0
	if _hunt_charges > 0:
		_hunt_charges -= 1
		multiplier *= float(definition.get("hunt_damage_multiplier", 1.0))
		_set_ability_animation(&"hunt_attack", 0.45)
	if bool(definition.get("ignores_terrain", false)) and moving and definition.has("moving_attack_damage_multiplier"):
		multiplier *= float(definition.get("moving_attack_damage_multiplier", 1.0))
	return multiplier

func _current_attack_cooldown() -> float:
	var cooldown := attack_cooldown
	var definition := UnitCatalog.get_definition(unit_archetype)
	if definition.has("low_health_attack_speed_bonus"):
		var missing_health_ratio := 1.0 - (float(health) / maxf(1.0, float(max_health)))
		var bonus := clampf(float(definition.get("low_health_attack_speed_bonus", 0.0)) * missing_health_ratio, 0.0, 0.75)
		cooldown *= 1.0 - bonus
	return maxf(0.1, cooldown)

# Height is reach. Only for units that already shoot -- putting a spearman on a
# wall does not let him stab further, and the bonus is capped so a tall tower
# does not turn an archer into artillery.
func _vantage_range_bonus() -> float:
	if vantage_height <= 0:
		return 0.0
	if int(UnitCatalog.get_definition(unit_archetype).get("attack_range_cells", 0)) <= 1 			and attack_range <= 64.0:
		return 0.0
	var cells := minf(float(vantage_height) * VantageEffects.RANGE_CELLS_PER_LEVEL,
		VantageEffects.MAX_RANGE_CELLS)
	return cells * 64.0

func _observer_aura_range_bonus() -> float:
	if owner_player_id != 1:
		return 0.0
	var definition := UnitCatalog.get_definition(unit_archetype)
	if int(definition.get("attack_range_cells", 0)) <= 1:
		return 0.0
	if rts_world == null or not is_instance_valid(rts_world):
		return 0.0
	var allies := rts_world.query_units(global_position, 420.0) if rts_world.has_method("query_units") else []
	for ally in allies:
		if ally == self or not is_instance_valid(ally):
			continue
		if _owner_id_for_node(ally) != owner_player_id:
			continue
		if ally.has_method("is_observer_aura_enabled") and bool(ally.call("is_observer_aura_enabled")):
			var rank := int(ally.call("wizard_upgrade_rank", "observer_aura")) if ally.has_method("wizard_upgrade_rank") else 0
			return 64.0 + float(rank) * 16.0
	return 0.0

func _update_animation_action() -> void:
	if _ability_animation_until_msec > 0 and Time.get_ticks_msec() >= _ability_animation_until_msec:
		ability_animation_action = &""
		_ability_animation_until_msec = 0
	if not str(ability_animation_action).is_empty():
		animation_action = ability_animation_action
		return
	if _dying:
		animation_action = &"death"
	elif _is_stunned():
		animation_action = &"stunned"
	elif unit_state in [&"rooting", &"rooted", &"uprooting", &"takeoff", &"landing", &"observing"]:
		animation_action = unit_state
	elif attack_target != null and is_instance_valid(attack_target):
		animation_action = &"attack"
	elif moving:
		animation_action = &"move"
	else:
		animation_action = &"idle"

func get_evolution_progress() -> Dictionary:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var needed := float(definition.get("evolution_xp_required", 0.0))
	return {
		"xp": evolution_xp,
		"needed": needed,
		"level": evolution_level,
		"evolves_to": definition.get("evolves_to", &""),
	}

func debug_force_evolve() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var progress := get_evolution_progress()
	var needed := float(progress.get("needed", definition.get("evolution_xp_required", 0.0)))
	if needed <= 0.0:
		return false
	_gain_evolution_xp(needed - evolution_xp + 0.01)
	return true

func _set_ability_animation(action: StringName, seconds: float = 0.7) -> void:
	ability_animation_action = action
	_ability_animation_until_msec = Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)

func _effective_attack_range_to(target: Node2D) -> float:
	var range := attack_range
	var definition := UnitCatalog.get_definition(unit_archetype)
	if _hunt_charges > 0:
		range *= float(definition.get("hunt_range_multiplier", 1.0))
	if bool(definition.get("ignores_terrain", false)) and moving and definition.has("moving_attack_range_multiplier"):
		range *= float(definition.get("moving_attack_range_multiplier", 1.0))
	range += _observer_aura_range_bonus()
	range += _vantage_range_bonus()
	if target != null and is_instance_valid(target) and target.has_method("get_selection_kind") and target.get_selection_kind() == &"structure":
		return range + maxf(32.0, float(target.get("selection_radius")) * 0.75)
	return range

func _spawn_projectile(target: Node2D, damage_multiplier: float = 1.0) -> void:
	var origin := global_position + Vector2(0, -12)
	if rts_world != null and is_instance_valid(rts_world):
		var weapon := WeaponCatalog.get_weapon(unit_archetype)
		var projectile := rts_world.spawn_projectile(self, target, maxi(1, int(float(weapon.get("damage", attack_damage)) * damage_multiplier)), weapon.get("color", _projectile_color()), float(weapon.get("speed", projectile_speed)), origin)
		projectile.set_aoe_radius(float(weapon.get("aoe_radius", 0.0)))
		return
	var projectile := RtsProjectile.new()
	projectile.configure(self, target, maxi(1, int(float(attack_damage) * damage_multiplier)), _projectile_color(), projectile_speed)
	projectile.set_aoe_radius(float(WeaponCatalog.get_weapon(unit_archetype).get("aoe_radius", 0.0)))
	get_parent().add_child(projectile)
	projectile.global_position = origin

func _projectile_color() -> Color:
	var team := team_accent_color()
	match unit_archetype:
		&"horror", &"hunter":
			return team.lightened(0.1)
		&"apex":
			return team
		&"life_wizard":
			return Color("#7DDDE8")
		&"fire_wizard":
			return Color("#E85A5A")
		&"evangalion_wizard":
			return Color("#7DDDE8")
	return Color("#D6C7AE")

# KoN's two themes, straight out of the roster doc's colour scheme section.
# Observer units and buildings read black/silver; everything born of evolution
# reads #67BED9 with an #a95766 accent. Both are cached-theme lookups, not
# catalog reads, because these are called from _draw().
const KON_EVOLUTION_PRIMARY := Color("#67BED9")
const KON_EVOLUTION_BODY := Color("#2E5F70")
const KON_EVOLUTION_ACCENT := Color("#A95766")
const KON_OBSERVER_PRIMARY := Color("#C9CDD4")
const KON_OBSERVER_BODY := Color("#20222A")
const KON_OBSERVER_ACCENT := Color("#E6EAF0")

func team_primary_color() -> Color:
	match owner_player_id:
		1:
			return KON_OBSERVER_PRIMARY if _kon_theme == &"observer" else KON_EVOLUTION_PRIMARY
		2:
			return Color("#C13030")
		3:
			return Color("#3FA8B5")
		4:
			return Color("#D6A84F")
	return Color("#D6C7AE")

func team_secondary_color() -> Color:
	match owner_player_id:
		1:
			return KON_OBSERVER_BODY if _kon_theme == &"observer" else KON_EVOLUTION_BODY
		2:
			return Color("#5C0F14")
		3:
			return Color("#1A4F5C")
		4:
			return Color("#8A7560")
	return Color("#5C4838")

func team_accent_color() -> Color:
	match owner_player_id:
		1:
			return KON_OBSERVER_ACCENT if _kon_theme == &"observer" else KON_EVOLUTION_ACCENT
		2:
			return Color("#E85A5A")
		3:
			return Color("#7DDDE8")
		4:
			return Color("#F0D487")
	return Color("#D6C7AE")

func team_health_color() -> Color:
	match owner_player_id:
		1:
			return Color("#7BC47F")
		2:
			return Color("#E85A5A")
		3:
			return Color("#7DDDE8")
		4:
			return Color("#F0D487")
	return Color("#D6C7AE")

func _apply_owner_art_tint() -> void:
	var art := get_node_or_null("ArtSprite")
	if art == null:
		return
	var tint := Color.WHITE
	match owner_player_id:
		2:
			tint = Color(1.14, 0.78, 0.78, 1.0)
		3:
			tint = Color(0.74, 1.05, 1.18, 1.0)
		4:
			tint = Color(1.16, 1.02, 0.72, 1.0)
	art.modulate = tint

const _WIZARD_ARCHETYPES := {&"life_wizard": true, &"fire_wizard": true, &"evangalion_wizard": true}

# Cheap check for the hot combat-resolution path (take_damage fires on every hit
# from every unit in the simulation). A class_name-based "is Wizard" check was
# tried first but caused a circular class-resolution failure across every unit
# script (RTSUnit referencing a subclass's class_name deadlocked Godot's global
# class cache) -- a plain StringName property read has no such issue and is
# also cheaper than has_method()'s reflection, which only ever needs to run for
# the rare case (an actual wizard) instead of on every single damage event.
func _is_wizard_archetype(archetype: String) -> bool:
	return _WIZARD_ARCHETYPES.has(StringName(archetype))

func take_damage(amount: int, source: Node = null, damage_type: StringName = &"physical") -> void:
	if _dying or is_banished():
		return
	if Time.get_ticks_msec() < _taunt_until_msec:
		amount = maxi(1, int(float(amount) * (1.0 - float(UnitCatalog.get_definition(unit_archetype).get("taunt_damage_reduction", 0.0)))))
	var mitigation := magic_armor if damage_type == &"magic" else armor
	if UnitCatalog.get_definition(unit_archetype).has("low_health_armor_bonus"):
		var missing_health_ratio := 1.0 - (float(health) / maxf(1.0, float(max_health)))
		mitigation += int(round(float(UnitCatalog.get_definition(unit_archetype).get("low_health_armor_bonus", 0)) * missing_health_ratio))
	var mitigated_amount := maxi(1, amount - mitigation)
	var actual_damage: int = mini(mitigated_amount, health)
	if rts_world != null and is_instance_valid(rts_world):
		rts_world.record_damage(source, self, actual_damage)
	health = maxi(0, health - actual_damage)
	_gain_evolution_xp(float(actual_damage) * 0.35)
	if source != null and is_instance_valid(source) and _is_wizard_archetype(str(source.get("unit_archetype"))):
		source.call("_gain_wizard_xp", float(actual_damage) * 0.5 + (40.0 if health <= 0 else 0.0))
	if not _mass_performance_mode() or selected or health <= 0:
		_queue_unit_redraw(health <= 0)
	if health <= 0:
		_die(source)

func apply_poison(source: Node = null, damage_per_second: float = 4.0, duration_seconds: float = 4.0) -> void:
	if _dying or damage_per_second <= 0.0 or duration_seconds <= 0.0:
		return
	var source_ref: WeakRef = null
	if source != null and is_instance_valid(source):
		source_ref = weakref(source)
	_damage_over_time_effects.append({
		"source_ref": source_ref,
		"dps": damage_per_second,
		"remaining": duration_seconds,
		"carry": 0.0,
	})

func _update_damage_over_time(delta: float) -> void:
	if _damage_over_time_effects.is_empty() or _dying:
		return
	for i in range(_damage_over_time_effects.size() - 1, -1, -1):
		var effect: Dictionary = _damage_over_time_effects[i]
		var remaining := float(effect.get("remaining", 0.0)) - delta
		var carry := float(effect.get("carry", 0.0)) + float(effect.get("dps", 0.0)) * delta
		var damage := int(floor(carry))
		effect["remaining"] = remaining
		effect["carry"] = carry - float(damage)
		_damage_over_time_effects[i] = effect
		if damage > 0:
			var source: Node = null
			var source_ref = effect.get("source_ref", null)
			if source_ref is WeakRef:
				var source_candidate = source_ref.get_ref()
				if source_candidate is Node and is_instance_valid(source_candidate):
					source = source_candidate
			elif effect.has("source"):
				var legacy_source = effect.get("source", null)
				if legacy_source is Node and is_instance_valid(legacy_source):
					source = legacy_source
			take_damage(damage, source, &"magic")
			if _dying:
				return
		if remaining <= 0.0:
			_damage_over_time_effects.remove_at(i)

func _die(source: Node = null) -> void:
	if _dying:
		return
	_dying = true
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.record_felled(unit_archetype, owner_player_id, _owner_id_for_node(source))
	_apply_death_passives(source)
	_spawn_death_fx(source)
	queue_free()

func _apply_death_passives(source: Node = null) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if not bool(definition.get("friendly_fire_explodes", false)):
		return
	if source == null or not is_instance_valid(source) or not source is Node:
		return
	if _owner_id_for_node(source) != owner_player_id:
		return
	var radius := float(definition.get("death_explosion_radius", 0.0))
	var damage := int(definition.get("death_explosion_damage", 0))
	if radius <= 0.0 or damage <= 0:
		return
	var units := rts_world.query_units(global_position, radius) if rts_world != null and is_instance_valid(rts_world) else []
	for unit in units:
		if unit == self or not is_instance_valid(unit) or not unit.has_method("take_damage"):
			continue
		var distance := global_position.distance_to(unit.global_position)
		var falloff := clampf(1.0 - distance / maxf(1.0, radius * 1.25), 0.35, 1.0)
		unit.take_damage(maxi(1, int(float(damage) * falloff)), self)

func _spawn_death_fx(source: Node = null) -> void:
	if _is_ai_stress_arena() and rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 250:
		return
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var fx: Node2D = UNIT_DEATH_FX_SCRIPT.new()
	parent.add_child(fx)
	if fx.has_method("configure_from_unit"):
		fx.call("configure_from_unit", self, source)

func is_alive() -> bool:
	return health > 0

func is_banished() -> bool:
	return bool(get_meta("kon_banished",false))

func heal_damage(amount: int) -> void:
	if is_banished(): return
	health = mini(max_health, health + amount)
	if not _mass_performance_mode() or selected:
		_queue_unit_redraw()

func stun_for_seconds(seconds: float) -> void:
	stunned_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	path.clear()
	moving = false
	unit_state = &"stunned"
	_queue_unit_redraw()

func slow_for_seconds(seconds: float, multiplier: float) -> void:
	if seconds <= 0.0:
		return
	_slowed_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	_slow_multiplier = clampf(multiplier, 0.1, 1.0)
	_queue_unit_redraw()

func salvage_value() -> int:
	# Uses this unit's live max_health, so an evolved or research-buffed unit is
	# worth more than its catalog entry suggests.
	return UnitCatalog.salvage_value_for(unit_archetype, max_health)

func _gain_evolution_xp(amount: float) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var needed := float(definition.get("evolution_xp_required", 0.0))
	if needed <= 0.0:
		return
	evolution_xp += amount
	while evolution_xp >= needed:
		evolution_xp -= needed
		_evolve(definition)
		definition = UnitCatalog.get_definition(unit_archetype)
		needed = float(definition.get("evolution_xp_required", 0.0))
		if needed <= 0.0:
			break

func _evolve(definition: Dictionary) -> void:
	var evolves_to: StringName = definition.get("evolves_to", &"")
	if not str(evolves_to).is_empty():
		unit_archetype = evolves_to
		_spawner_rooted = false
		_root_cast_remaining = 0.0
		_uproot_cast_remaining = 0.0
		_temporary_flight_until_msec = 0
		_jumper_landing_ready = false
	# NOTE: _apply_catalog_definition() RESETS max_health/attack_damage from the
	# catalog, which wipes anything research had baked into this unit. That is
	# why _reapply_owner_upgrades() runs at the end -- see the 2026-08-31
	# Decisions Log entry; before that fix, a researched Horror silently lost its
	# bonus the moment it evolved, permanently.
	_apply_catalog_definition()
	evolution_level += 1
	max_health = int(float(max_health) * UnitCatalog.evolution_hp_multiplier(evolution_level))
	health = max_health
	move_speed += float(definition.get("evolution_speed_bonus", 0.0))
	attack_damage = int(float(attack_damage) * UnitCatalog.EVOLUTION_DAMAGE_MULTIPLIER)
	_reapply_owner_upgrades()
	_set_ability_animation(&"evolve", 1.2)
	_queue_unit_redraw()

# Asks the BuildSystem to re-bake any researched upgrades onto this unit after
# its stats were reset by an evolution. Only called from _evolve(), so it costs
# nothing on the normal path.
func _reapply_owner_upgrades() -> void:
	if owner_player_id != 1:
		return
	var build_system := get_node_or_null("../BuildSystem")
	if build_system == null or not build_system.has_method("reapply_upgrades_after_evolution"):
		return
	build_system.call("reapply_upgrades_after_evolution", self)

func _try_auto_grapple(target: Node2D) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var power := int(definition.get("grapple_power", 0))
	if power <= 0 or _grapple_elapsed < float(definition.get("grapple_cooldown_seconds", 4.0)):
		return
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_squared_to(target.global_position) > pow(attack_range + 24.0, 2.0):
		return
	_grapple_elapsed = 0.0
	var until_msec := Time.get_ticks_msec() + int(float(definition.get("grapple_seconds", 2.0)) * 1000.0)
	var stacks: Array = target.get_meta("grapple_stacks", [])
	stacks.append({"owner": get_instance_id(), "power": power, "until": until_msec})
	for i in range(stacks.size() - 1, -1, -1):
		if int(stacks[i].get("until", 0)) < Time.get_ticks_msec():
			stacks.remove_at(i)
	target.set_meta("grapple_stacks", stacks)
	var total_power := 0
	for stack in stacks:
		total_power += int(stack.get("power", 0))
	var target_archetype := StringName(target.get("unit_archetype")) if _node_has_property(target, "unit_archetype") else &""
	var resistance := int(UnitCatalog.get_definition(target_archetype).get("grapple_resistance", 1))
	if total_power >= resistance and target.has_method("stun_for_seconds"):
		target.stun_for_seconds(float(definition.get("grapple_seconds", 2.0)))
	var aoe_radius := float(definition.get("grapple_aoe_radius", 0.0))
	if aoe_radius > 0.0 and rts_world != null and is_instance_valid(rts_world):
		var victims := rts_world.query_enemy_units(target.global_position, aoe_radius, owner_player_id, 12) if rts_world.has_method("query_enemy_units") else []
		for victim in victims:
			if victim == target or not is_instance_valid(victim) or not victim.has_method("stun_for_seconds"):
				continue
			victim.stun_for_seconds(float(definition.get("grapple_seconds", 2.0)))

func activate_charge() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if not definition.has("charge_speed_multiplier"):
		return false
	_charge_until_msec = Time.get_ticks_msec() + 3200
	if definition.has("jumper_landing_stun_seconds") and _is_temporary_flying():
		_jumper_landing_ready = true
	unit_state = &"attack_move" if attack_target == null else &"attacking"
	_set_ability_animation(&"charge", 0.55)
	_queue_unit_redraw()
	return true

func activate_taunt() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var radius := float(definition.get("taunt_radius", 0.0))
	if radius <= 0.0 or rts_world == null or not is_instance_valid(rts_world):
		return false
	var enemies := rts_world.query_enemy_attackables(global_position, radius, owner_player_id, 18)
	if enemies.is_empty():
		return false
	_taunt_until_msec = Time.get_ticks_msec() + int(float(definition.get("taunt_seconds", 3.0)) * 1000.0)
	var affected := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == self:
			continue
		if enemy.has_method("issue_attack_target"):
			enemy.issue_attack_target(self)
			affected += 1
		elif _node_has_property(enemy, "attack_target"):
			enemy.set("attack_target", self)
			affected += 1
	print("[Oaven] Taunt archetype=", unit_archetype, " affected=", affected, " radius=", radius)
	_set_ability_animation(&"taunt", 0.8)
	_queue_unit_redraw()
	return affected > 0

func activate_flight() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var seconds := float(definition.get("temporary_flight_seconds", 0.0))
	if seconds <= 0.0:
		return false
	_temporary_flight_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	_flight_state = &"flying"
	_flight_cast_remaining = 0.0
	ignores_terrain = true
	unit_state = &"takeoff"
	_set_ability_animation(&"takeoff", 0.65)
	_queue_unit_redraw()
	print("[Oaven] Flight activated seconds=", seconds)
	return true

func activate_grapple() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if int(definition.get("grapple_power", 0)) <= 0:
		return false
	var target := _nearest_enemy(float(definition.get("grapple_active_radius", 150.0)))
	if target == null:
		return false
	_grapple_elapsed = float(definition.get("grapple_cooldown_seconds", 4.0))
	_set_ability_animation(&"grapple", 0.65)
	_try_auto_grapple(target)
	issue_attack_target(target)
	return true

func activate_observer_aura() -> bool:
	if unit_archetype != &"life_wizard" or is_banished() or _dying:
		return false
	_observer_aura_enabled = not _observer_aura_enabled
	if _observer_aura_enabled:
		attack_target = null
		path.clear()
		moving = false
		velocity = Vector2.ZERO
		unit_state = &"observing"
		ability_animation_action = &"observer_aura"
		_ability_animation_until_msec = 0
	else:
		unit_state = &"idle"
		ability_animation_action = &""
		_ability_animation_until_msec = 0
	_queue_unit_redraw()
	return true

func is_observer_aura_enabled() -> bool:
	return _observer_aura_enabled

func activate_summon_drone() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if not definition.has("drone_archetype"):
		return false
	if _owned_drones().size() >= int(definition.get("drone_cap", 2)):
		return false
	var cost := int(definition.get("drone_summon_cost_bio", 0))
	if cost > 0 and not _spend_bio(cost):
		return false
	var target := _nearest_enemy(520.0)
	_spawn_drone(StringName(definition.get("drone_archetype", &"spawner_drone")), target)
	_spawner_elapsed = 0.0
	return true

func activate_root_cannon() -> bool:
	return activate_root()

func activate_root() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if not bool(definition.get("requires_root_to_fire", false)):
		return false
	if _spawner_rooted or _root_cast_remaining > 0.0:
		return false
	moving = false
	path.clear()
	velocity = Vector2.ZERO
	_root_cast_remaining = float(definition.get("root_cast_seconds", 2.0))
	unit_state = &"rooting"
	_set_ability_animation(&"root_cast", float(definition.get("root_cast_seconds", 2.0)))
	return true

func activate_uproot() -> bool:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if not bool(definition.get("requires_root_to_fire", false)):
		return false
	if not _spawner_rooted or _uproot_cast_remaining > 0.0:
		return false
	_uproot_cast_remaining = float(definition.get("uproot_cast_seconds", 2.0))
	unit_state = &"uprooting"
	_set_ability_animation(&"uproot_cast", float(definition.get("uproot_cast_seconds", 2.0)))
	return true

func activate_eat_ally() -> bool:
	if not has_method("eat_ally"):
		return false
	var ally := _nearest_ally(120.0)
	if ally == null:
		return false
	return bool(call("eat_ally", ally))

func _update_spawner_drones(nearby_units: Array[Node2D]) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if not definition.has("drone_archetype"):
		return
	if _should_throttle_spawner_drones():
		return
	var drones := _owned_drones()
	if drones.size() >= int(definition.get("drone_cap", 2)):
		return
	if _spawner_elapsed < float(definition.get("drone_summon_cooldown_seconds", 8.0)):
		return
	var target := attack_target if attack_target != null and is_instance_valid(attack_target) else _find_nearest_enemy(nearby_units)
	if target == null:
		return
	var cost := int(definition.get("drone_summon_cost_bio", 0))
	if cost > 0 and not _spend_bio(cost):
		return
	_spawner_elapsed = 0.0
	_spawn_drone(StringName(definition.get("drone_archetype", &"spawner_drone")), target)

func _owned_drones() -> Array[Node2D]:
	for i in range(_drone_children.size() - 1, -1, -1):
		if not is_instance_valid(_drone_children[i]):
			_drone_children.remove_at(i)
	return _drone_children

func _spawn_drone(archetype: StringName, target: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var drone_scene: PackedScene = load(SPAWNER_DRONE_SCENE_PATH)
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	drone.set("owner_player_id", owner_player_id)
	drone.set("unit_archetype", archetype)
	drone.set_meta("spawner_parent_id", get_instance_id())
	drone.global_position = global_position + Vector2(randf_range(-22.0, 22.0), randf_range(-18.0, 18.0))
	parent.add_child(drone)
	if drone is Node2D:
		_drone_children.append(drone)
	if target != null and is_instance_valid(target) and drone.has_method("issue_attack_target"):
		drone.issue_attack_target(target)

func _spend_attack_bio() -> bool:
	var cost := int(UnitCatalog.get_definition(unit_archetype).get("shot_cost_bio", 0))
	return cost <= 0 or _spend_bio(cost)

func _spend_bio(amount: int) -> bool:
	if amount <= 0:
		return true
	if owner_player_id != 1:
		return true
	if _economy_manager == null or not is_instance_valid(_economy_manager):
		return true
	return _economy_manager.spend(owner_player_id, {&"bio": amount})

func _update_weapon_swap(delta: float) -> void:
	if _weapon_swap_remaining > 0.0:
		_weapon_swap_remaining = maxf(0.0, _weapon_swap_remaining - delta)

func _update_limited_lifetime() -> void:
	var lifetime := float(UnitCatalog.get_definition(unit_archetype).get("lifetime_seconds", 0.0))
	if lifetime > 0.0 and _life_elapsed >= lifetime:
		_die(null)

func _update_spawner_root_casts(delta: float) -> void:
	if _root_cast_remaining > 0.0:
		_root_cast_remaining = maxf(0.0, _root_cast_remaining - delta)
		unit_state = &"rooting"
		moving = false
		path.clear()
		if _root_cast_remaining <= 0.0:
			_spawner_rooted = true
			unit_state = &"rooted"
		_queue_unit_redraw()
		return
	if _uproot_cast_remaining > 0.0:
		_uproot_cast_remaining = maxf(0.0, _uproot_cast_remaining - delta)
		unit_state = &"uprooting"
		moving = false
		path.clear()
		if _uproot_cast_remaining <= 0.0:
			_spawner_rooted = false
			unit_state = &"idle"
		_queue_unit_redraw()

func _blocks_movement_for_rooting() -> bool:
	return _spawner_rooted or _root_cast_remaining > 0.0 or _uproot_cast_remaining > 0.0

func _requires_root_to_fire() -> bool:
	return bool(UnitCatalog.get_definition(unit_archetype).get("requires_root_to_fire", false))

func _is_winged_spawner() -> bool:
	return unit_archetype == &"winged_spawner"

func _requires_takeoff_for_move() -> bool:
	return _is_winged_spawner() and _flight_state == &"grounded" and _flight_cast_remaining <= 0.0

func _start_takeoff() -> void:
	if not _is_winged_spawner():
		return
	var definition := UnitCatalog.get_definition(unit_archetype)
	_flight_state = &"taking_off"
	_flight_cast_remaining = float(definition.get("takeoff_seconds", 0.5))
	moving = false
	velocity = Vector2.ZERO
	path.clear()
	unit_state = &"takeoff"
	_set_ability_animation(&"takeoff", _flight_cast_remaining)
	_queue_unit_redraw()

func _try_land_winged_spawner() -> void:
	if not _is_winged_spawner() or _flight_state != &"flying" or moving:
		return
	if attack_target != null and is_instance_valid(attack_target):
		return
	var definition := UnitCatalog.get_definition(unit_archetype)
	_flight_state = &"landing"
	_flight_cast_remaining = float(definition.get("landing_seconds", 0.5))
	velocity = Vector2.ZERO
	unit_state = &"landing"
	_set_ability_animation(&"landing", _flight_cast_remaining)
	_queue_unit_redraw()

func _update_winged_spawner_flight(delta: float) -> void:
	if not _is_winged_spawner():
		_flight_state = &"grounded"
		_flight_cast_remaining = 0.0
		return
	if _flight_cast_remaining <= 0.0:
		return
	_flight_cast_remaining = maxf(0.0, _flight_cast_remaining - delta)
	moving = false
	velocity = Vector2.ZERO
	if _flight_state == &"taking_off":
		unit_state = &"takeoff"
		if _flight_cast_remaining <= 0.0:
			_flight_state = &"flying"
			ability_animation_action = &""
			_ability_animation_until_msec = 0
			if _has_command_destination:
				if _flow_field_attack_move_active and not ignores_terrain:
					_refresh_flow_field_attack_move_path(true)
				else:
					path = _single_point_path(_command_destination) if ignores_terrain else _world_path_to(_command_destination)
				moving = not path.is_empty()
				if moving:
					target_pos = path[0]
					unit_state = command_mode if command_mode != &"idle" else &"moving"
					_reset_stuck_watch()
				else:
					unit_state = &"idle"
					_try_land_winged_spawner()
			else:
				unit_state = &"idle"
				_try_land_winged_spawner()
		_queue_unit_redraw()
	elif _flight_state == &"landing":
		unit_state = &"landing"
		if _flight_cast_remaining <= 0.0:
			_flight_state = &"grounded"
			ability_animation_action = &""
			_ability_animation_until_msec = 0
			unit_state = &"idle"
		_queue_unit_redraw()

func _current_move_speed() -> float:
	var speed := move_speed
	var definition := UnitCatalog.get_definition(unit_archetype)
	if definition.has("charge_speed_multiplier") and (Time.get_ticks_msec() < _charge_until_msec or attack_target != null and is_instance_valid(attack_target)):
		var charge_range := maxf(attack_range * 4.0, 160.0)
		if Time.get_ticks_msec() < _charge_until_msec or global_position.distance_squared_to(attack_target.global_position) <= charge_range * charge_range:
			speed *= float(definition.get("charge_speed_multiplier", 1.0))
	if _is_temporary_flying():
		speed *= float(definition.get("temporary_flight_speed_multiplier", 1.0))
	if Time.get_ticks_msec() < _slowed_until_msec:
		speed *= _slow_multiplier
	return speed

func _update_temporary_status_effects() -> void:
	if _temporary_flight_until_msec > 0 and Time.get_ticks_msec() >= _temporary_flight_until_msec:
		_temporary_flight_until_msec = 0
		_jumper_landing_ready = false
		if not _is_winged_spawner():
			_flight_state = &"grounded"
			ignores_terrain = bool(UnitCatalog.get_definition(unit_archetype).get("ignores_terrain", false))
			if unit_state == &"takeoff" or unit_state == &"flying" or unit_state == &"landing":
				unit_state = &"idle"
			_queue_unit_redraw()
	if _slowed_until_msec > 0 and Time.get_ticks_msec() >= _slowed_until_msec:
		_slowed_until_msec = 0
		_slow_multiplier = 1.0

func _is_temporary_flying() -> bool:
	return _temporary_flight_until_msec > Time.get_ticks_msec()

func _try_oaven_crippling_attack(target: Node2D) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var seconds := float(definition.get("cripple_seconds", 0.0))
	if seconds <= 0.0 or target == null or not is_instance_valid(target):
		return
	var now := Time.get_ticks_msec()
	if now - _cripple_last_msec < int(float(definition.get("cripple_cooldown_seconds", 3.0)) * 1000.0):
		return
	if bool(definition.get("cripple_requires_moving_target", false)) and _node_has_property(target, "moving") and not bool(target.get("moving")):
		return
	_cripple_last_msec = now
	if target.has_method("slow_for_seconds"):
		target.slow_for_seconds(seconds, 0.42)
	if target.has_method("take_damage"):
		target.take_damage(int(definition.get("cripple_bonus_damage", 0)), self)
	print("[Oaven] Crippling spear target=", target.name, " seconds=", seconds)

func _try_oaven_jumper_landing(target: Node2D) -> bool:
	if not _jumper_landing_ready or target == null or not is_instance_valid(target):
		return false
	var definition := UnitCatalog.get_definition(unit_archetype)
	var radius := float(definition.get("jumper_landing_radius", 0.0))
	var stun_seconds := float(definition.get("jumper_landing_stun_seconds", 0.0))
	var damage := int(definition.get("jumper_landing_damage", 0))
	if radius <= 0.0 or stun_seconds <= 0.0:
		return false
	_jumper_landing_ready = false
	_temporary_flight_until_msec = 0
	_flight_state = &"grounded"
	ignores_terrain = bool(definition.get("ignores_terrain", false))
	_charge_until_msec = 0
	unit_state = &"attacking"
	moving = false
	path.clear()
	var victims: Array[Node2D] = []
	if rts_world != null and is_instance_valid(rts_world):
		victims = rts_world.query_enemy_units(target.global_position, radius, owner_player_id, 12)
	else:
		victims.append(target)
	for victim in victims:
		if not is_instance_valid(victim) or not victim.has_method("take_damage"):
			continue
		if victim.has_method("stun_for_seconds"):
			victim.stun_for_seconds(stun_seconds)
		if damage > 0:
			victim.take_damage(damage, self)
	print("[Oaven] Jumper landing target=", target.name, " victims=", victims.size(), " stun=", stun_seconds)
	_set_ability_animation(&"landing_stun", 0.85)
	_queue_unit_redraw()
	return true

func _nearest_enemy(radius: float) -> Node2D:
	if rts_world == null or not is_instance_valid(rts_world):
		return null
	var best: Node2D = null
	var best_distance := INF
	for unit in rts_world.query_units(global_position, radius, -1, 48):
		if not is_instance_valid(unit) or not _is_enemy_unit(unit):
			continue
		var distance := global_position.distance_squared_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return best

func _nearest_ally(radius: float) -> Node2D:
	if rts_world == null or not is_instance_valid(rts_world):
		return null
	var best: Node2D = null
	var best_distance := INF
	for unit in rts_world.query_units(global_position, radius, owner_player_id, 48):
		if unit == self or not is_instance_valid(unit) or not unit.has_method("salvage_value"):
			continue
		var distance := global_position.distance_squared_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return best

func _owner_id_for_node(node: Node) -> int:
	if node == null or not is_instance_valid(node) or not _node_has_property(node, "owner_player_id"):
		return -1
	return int(node.get("owner_player_id"))

func _node_has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _is_stunned() -> bool:
	if stunned_until_msec <= 0:
		return false
	if Time.get_ticks_msec() <= stunned_until_msec:
		return true
	stunned_until_msec = 0
	if unit_state == &"stunned":
		unit_state = &"idle"
	return false

func _is_enemy_unit(other: Node) -> bool:
	if bool(other.get_meta("kon_banished",false)): return false
	return other != self and other is Node2D and other.get("owner_player_id") != owner_player_id and other.has_method("take_damage")

# ---------------------------------------------------------------------------
# Spotting: you cannot shoot what your side cannot see.
#
# Sight travels level or downhill freely and is blocked by higher ground, so a
# unit on low ground cannot engage something on a plateau by itself. It CAN
# engage it if an ally is close enough to the target to see it -- the spotter
# rule most RTS games use, and it applies to the enemy AI identically because
# this runs inside the shared combat tick rather than in player input.
#
# PERFORMANCE: the expensive part only runs when the target is HIGHER than the
# attacker. On flat ground -- which is nearly every engagement -- this is two
# height lookups and an early return, so the common case costs almost nothing.
# ---------------------------------------------------------------------------
const SPOTTER_RADIUS := 320.0
const MAX_SPOTTERS_CHECKED := 4

func can_engage_target(target: Node2D) -> bool:
	if is_banished() or bool(target.get_meta("kon_banished",false)): return false
	if terrain == null or not is_instance_valid(terrain):
		return true
	if not terrain.has_method("has_line_of_sight"):
		return true
	var my_cell: Vector2i = terrain.world_to_cell(global_position)
	var target_cell: Vector2i = terrain.world_to_cell(target.global_position)
	var my_height: int = terrain.get_height(my_cell)
	# Level or below: always engageable. Only uphill needs proving.
	if terrain.get_height(target_cell) <= my_height:
		return true
	if terrain.has_line_of_sight(my_cell, target_cell, my_height):
		return true
	return _ally_spots(target_cell)

# Is any nearby ally close enough to the target to see it? Bounded to a handful
# of candidates so a large army does not turn this into an O(n) scan per shot.
func _ally_spots(target_cell: Vector2i) -> bool:
	if rts_world == null or not is_instance_valid(rts_world):
		return false
	if not rts_world.has_method("query_units"):
		return false
	var target_world: Vector2 = terrain.cell_to_world(target_cell)
	var checked := 0
	for ally in rts_world.query_units(target_world, SPOTTER_RADIUS, owner_player_id, MAX_SPOTTERS_CHECKED):
		if not is_instance_valid(ally) or ally == self:
			continue
		var ally_cell: Vector2i = terrain.world_to_cell(ally.global_position)
		var ally_height: int = terrain.get_height(ally_cell)
		if terrain.get_height(target_cell) > ally_height:
			continue
		if terrain.has_line_of_sight(ally_cell, target_cell, ally_height):
			return true
		checked += 1
		if checked >= MAX_SPOTTERS_CHECKED:
			break
	return false

func _find_nearest_enemy(units: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for unit in units:
		if not is_instance_valid(unit) or not _is_enemy_unit(unit):
			continue
		if not can_engage_target(unit):
			continue
		var distance := global_position.distance_squared_to(unit.global_position)
		var score := distance / maxf(0.1, _target_priority(unit))
		if score < best_score:
			best = unit
			best_score = score
	return best

func _target_priority(unit: Node) -> float:
	if unit.has_method("get_selection_kind") and unit.get_selection_kind() == &"structure":
		var archetype := str(unit.get("archetype"))
		if archetype == "wizard_tower":
			return 1.45
		if archetype == "bio_launcher":
			return 1.2
		if archetype == "bio_absorber":
			return 1.05
		return 0.9
	return 4.0 if owner_player_id != 1 else 1.0

func _apply_catalog_definition() -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	if definition.is_empty():
		return
	max_health = int(definition.get("max_hp", max_health))
	armor = int(definition.get("armor", armor))
	magic_armor = int(definition.get("magic_armor", magic_armor))
	attack_damage = int(definition.get("attack_damage", attack_damage))
	attack_range = float(definition.get("attack_range_cells", 1)) * 64.0
	attack_cooldown = float(definition.get("attack_speed_seconds", float(definition.get("attack_cooldown_ticks", 20)) / 20.0))
	attack_type = StringName(definition.get("attack_type", attack_type))
	attack_splash_radius = float(definition.get("attack_splash_radius_cells", 0.0)) * 64.0
	projectile_speed = float(definition.get("projectile_speed", projectile_speed))
	ignores_terrain = bool(definition.get("ignores_terrain", false))
	_kon_theme = StringName(definition.get("kon_theme", &"evolution"))
	intelligence = UnitCatalog.intelligence_of(unit_archetype)
	aggro_range = float(UnitCatalog.aggro_range_cells(unit_archetype)) * 64.0
	var modes: Dictionary = definition.get("weapon_modes", {})
	if not modes.is_empty():
		var preferred := StringName(definition.get("default_weapon_mode", &""))
		if not modes.has(preferred):
			preferred = StringName(modes.keys()[0])
		_apply_weapon_mode_stats(preferred, modes)

# ---------------------------------------------------------------------------
# Weapon modes. The roster doc gives the Oaven a spear OR a blowpipe, swapped
# at will: melee poke versus a slower ranged pea-shooter. Implemented as a stat
# overlay on top of the archetype rather than as two archetypes, so evolution,
# control groups, XP and the unit card all keep treating it as one unit.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Intelligence: how far this unit obeys the player. Checked on the PLAYER order
# path only (CommandDispatcher / SelectionController) -- never on the AI path,
# so wave units and summons keep taking their own orders regardless.
# ---------------------------------------------------------------------------

# Whether a player-issued order of this kind would be obeyed right now.
# `kind` is the order verb: "move", "attack_move", "patrol", "hold", "stop",
# "attack_target". Feral units refuse everything; Leashed units refuse while
# something is inside their aggro range.
func accepts_player_order(kind: StringName = &"move") -> bool:
	if intelligence >= UnitCatalog.INTELLIGENCE_BOUND:
		return true
	if intelligence <= UnitCatalog.INTELLIGENCE_FERAL:
		return false
	# Leashed. Stop is always allowed -- refusing it would leave the player no
	# way to call anything off at all, which reads as a bug rather than as
	# character.
	if kind == &"stop":
		return true
	return not has_enemy_in_aggro_range()

func refusal_reason() -> String:
	if intelligence <= UnitCatalog.INTELLIGENCE_FERAL:
		return "%s ignores orders" % UnitCatalog.get_definition(unit_archetype).get("display_name", unit_archetype)
	return "%s is engaged and will not break off" % UnitCatalog.get_definition(unit_archetype).get("display_name", unit_archetype)

# Deliberately reads the target the combat tick already maintains rather than
# running its own spatial query. Two reasons:
#
#  * Cost. This is called once per selected unit on every player order. A query
#    per unit would be O(selection x neighbourhood) on every click, and at the
#    army scale section 5 targets that is exactly the kind of per-action cost
#    this project has been bitten by before.
#  * Correctness. RTSWorld's spatial buckets are only rebuilt by the combat
#    tick, so querying them from the input path reads whatever staleness that
#    cadence happens to leave -- the same trap the Bio Absorber heal aura hit.
#
# The tradeoff is that a unit which has not noticed an enemy yet still obeys for
# a tick or two. That is the right way round: the leash tightens once the unit
# is actually aware of the threat, which is also what it looks like on screen.
func has_enemy_in_aggro_range() -> bool:
	if attack_target == null or not is_instance_valid(attack_target):
		return false
	return global_position.distance_to(attack_target.global_position) <= aggro_range

# The "reverts to its set behaviour" half of Leashed. A plain move order is
# abandoned the moment something enters aggro range; attack-move, patrol and
# hold are deliberately untouched, because those already ARE fighting orders and
# because enemy waves are issued as attack-move -- overriding those would break
# wave behaviour entirely.
func _update_autonomy_override(target: Node2D) -> void:
	if intelligence >= UnitCatalog.INTELLIGENCE_BOUND:
		return
	if target == null or not is_instance_valid(target):
		return
	if command_mode != &"move":
		return
	if global_position.distance_to(target.global_position) > aggro_range:
		return
	command_mode = &"attack_move"
	unit_state = &"attack_move"
	_command_destination = target.global_position
	_has_command_destination = true
	path.clear()

func has_weapon_modes() -> bool:
	return not UnitCatalog.weapon_modes(unit_archetype).is_empty()

# The modes a player can CHOOSE between. Excludes any weapon granted by
# position rather than picked.
#
# The Oaven's heavy blowpipe is issued by standing on a firing step and taken
# away on the way down -- it is not a third option on the toggle. Leaving it in
# meant the toggle cycled spear -> blowpipe -> heavy -> spear, so a player could
# simply select it on open ground and keep the range and damage without ever
# climbing anything, which is the entire mechanic given away for one keypress.
func available_weapon_modes() -> Array:
	var granted := StringName(UnitCatalog.get_definition(unit_archetype).get("vantage_weapon_mode", &""))
	var out: Array = []
	for mode in UnitCatalog.weapon_modes(unit_archetype):
		if StringName(mode) != granted:
			out.append(mode)
	return out

func current_weapon_mode() -> StringName:
	return weapon_mode

func weapon_mode_display_name() -> String:
	var modes := UnitCatalog.weapon_modes(unit_archetype)
	var mode: Dictionary = modes.get(weapon_mode, {})
	return str(mode.get("display_name", str(weapon_mode).capitalize()))

func is_swapping_weapon() -> bool:
	return _weapon_swap_remaining > 0.0

func set_weapon_mode(mode: StringName) -> bool:
	var modes := UnitCatalog.weapon_modes(unit_archetype)
	if not modes.has(mode) or mode == weapon_mode:
		return false
	_apply_weapon_mode_stats(mode, modes)
	var swap_seconds := float(UnitCatalog.get_definition(unit_archetype).get("weapon_swap_seconds", 0.0))
	if swap_seconds > 0.0:
		_weapon_swap_remaining = swap_seconds
		_set_ability_animation(&"swap_weapon", swap_seconds)
	_queue_unit_redraw()
	return true

func toggle_weapon_mode() -> StringName:
	var modes := available_weapon_modes()
	if modes.size() < 2:
		return weapon_mode
	var index := modes.find(weapon_mode)
	set_weapon_mode(StringName(modes[(index + 1) % modes.size()]))
	return weapon_mode

func _apply_weapon_mode_stats(mode: StringName, modes: Dictionary) -> void:
	var stats: Dictionary = modes.get(mode, {})
	if stats.is_empty():
		return
	weapon_mode = mode
	attack_damage = int(stats.get("attack_damage", attack_damage))
	attack_range = float(stats.get("attack_range_cells", attack_range / 64.0)) * 64.0
	attack_cooldown = float(stats.get("attack_speed_seconds", attack_cooldown))
	attack_type = StringName(stats.get("attack_type", attack_type))
	projectile_speed = float(stats.get("projectile_speed", projectile_speed))

func _separation_velocity(move_dir: Vector2 = Vector2.ZERO) -> Vector2:
	var push := Vector2.ZERO
	var nearby := _nearby_units_limited(_spacing_neighbor_budget())
	for unit in nearby:
		if unit == self or not (unit is Node2D):
			continue
		var delta: Vector2 = global_position - unit.global_position
		var distance: float = delta.length()
		if distance <= 0.01:
			var hash_angle := float(posmod(get_instance_id() - unit.get_instance_id(), 997)) / 997.0 * TAU
			delta = Vector2(cos(hash_angle), sin(hash_angle))
			distance = 0.01
		var desired := _desired_unit_spacing(unit)
		if distance >= desired:
			continue
		var weight := 8.5
		if move_dir != Vector2.ZERO and delta.normalized().dot(move_dir) < -0.35:
			weight = 4.0
		push += delta.normalized() * (desired - distance) * weight
	var cap := move_speed * (0.72 if _mass_performance_mode() else 0.46)
	return push.limit_length(cap)

func _mass_separation_velocity(move_dir: Vector2 = Vector2.ZERO) -> Vector2:
	if rts_world == null or not is_instance_valid(rts_world):
		return Vector2.ZERO
	if terrain != null and str(terrain.get("map_type_id")) in ["seeded_grid_frontier", "grid_test_canvas"]:
		return Vector2.ZERO
	var push := Vector2.ZERO
	var checked := 0
	var nearby := _nearby_units_limited(_spacing_neighbor_budget())
	for unit in nearby:
		if unit == self or not (unit is Node2D) or not is_instance_valid(unit):
			continue
		checked += 1
		var delta: Vector2 = global_position - unit.global_position
		var distance_sq := delta.length_squared()
		if distance_sq <= 0.001:
			var hash_angle := float(posmod(get_instance_id() - unit.get_instance_id(), 997)) / 997.0 * TAU
			delta = Vector2(cos(hash_angle), sin(hash_angle))
			distance_sq = 0.01
		var desired := _desired_unit_spacing(unit)
		if distance_sq >= desired * desired:
			continue
		var distance := sqrt(distance_sq)
		var away := delta / maxf(distance, 0.01)
		var pressure := (desired - distance) / desired
		var weight := 1.0
		if move_dir != Vector2.ZERO and away.dot(move_dir) < -0.25:
			weight = 0.45
		push += away * pressure * move_speed * 1.85 * weight
	_track_mass_collision_query(checked, 0)
	return push.limit_length(move_speed * 0.95)

func _would_overlap_at(position: Vector2, move_dir: Vector2 = Vector2.ZERO) -> bool:
	var checked := 0
	for unit in _nearby_units_limited(_overlap_neighbor_budget()):
		if unit == self or not (unit is Node2D) or not is_instance_valid(unit):
			continue
		checked += 1
		var desired := _desired_unit_spacing(unit) * 0.78
		var delta: Vector2 = position - unit.global_position
		if delta.length_squared() < desired * desired:
			if move_dir == Vector2.ZERO or delta.normalized().dot(move_dir) < 0.75:
				_track_mass_collision_query(0, checked)
				return true
	_track_mass_collision_query(0, checked)
	return false

func get_collision_separation() -> float:
	return collision_separation

func _desired_unit_spacing(unit: Node) -> float:
	var other_separation := collision_separation
	if unit != null and is_instance_valid(unit) and unit.has_method("get_collision_separation"):
		other_separation = float(unit.call("get_collision_separation"))
	var spacing := maxf(collision_separation, other_separation) * 1.12
	if _mass_performance_mode():
		spacing *= 1.18
	return spacing

func _spacing_neighbor_budget() -> int:
	if rts_world == null or not is_instance_valid(rts_world):
		return 12
	var count := rts_world.count_units_all()
	if count >= 2600:
		return 3
	if count >= 1800:
		return 4
	if count >= 900:
		return 5
	if count >= 500:
		return 6
	return 12

func _overlap_neighbor_budget() -> int:
	if rts_world == null or not is_instance_valid(rts_world):
		return 8
	var count := rts_world.count_units_all()
	if count >= 1800:
		return 0
	if count >= 2600:
		return 0
	if count >= 900:
		return 2
	return 8

# Every removal from `path` goes through here, so `path_levels` cannot drift out
# of step with it. Two callers pop -- arrival and the lookahead shortcut -- and a
# desync between them would put a unit at the right place on the wrong floor.
func _pop_path_front() -> void:
	if path.is_empty():
		return
	path.pop_front()
	if not path_levels.is_empty():
		nav_level = path_levels.pop_front()

# Orders a unit along a path produced by BlockNavWorld. Points are world
# positions as usual; levels are the block level of each point, so the unit
# knows which floor it is on rather than inferring it from the ground below.
func follow_block_path(points: Array[Vector2], levels: Array[int]) -> void:
	path = points.duplicate()
	path_levels = levels.duplicate()
	if not path_levels.is_empty():
		# The first entry is where the unit already is; the level it will be at
		# after the first step is what matters.
		nav_level = path_levels[0]
	moving = not path.is_empty()
	if moving:
		unit_state = &"move"

func _advance_path_lookahead() -> void:
	if _skip_path_lookahead_for_mass_mode():
		return
	# Never shortcut a lattice path.
	#
	# The lookahead skips waypoints when a straight 2D line to them is clear,
	# which is a fine optimisation on open ground and nonsense inside a building:
	# "clear in 2D" knows nothing about floors, walls or doorways, so it cut the
	# corner through the wall AND popped the levels along with the points, which
	# is why a unit ordered into the laboratory adopted the first floor's height
	# while still outside and walked to the door through the air.
	#
	# A lattice path is already the shortest route through a graph that does know
	# about all three, so there is nothing here worth shortening.
	if not path_levels.is_empty():
		return
	if terrain == null or path.size() < 3 or not terrain.has_method("world_to_cell") or not terrain.has_method("_has_clear_path_segment"):
		return
	var current_cell: Vector2i = terrain.world_to_cell(global_position)
	var best_index := 0
	var limit: int = mini(path.size() - 1, 4)
	for i in range(limit, 0, -1):
		var cell: Vector2i = terrain.world_to_cell(path[i])
		if terrain.call("_has_clear_path_segment", current_cell, cell):
			best_index = i
			break
	for i in best_index:
		_pop_path_front()

func _update_z_index() -> void:
	var cell_y := int(global_position.y / 8.0)
	if cell_y == _last_z_cell_y:
		return
	_last_z_cell_y = cell_y
	z_index = clampi(int(global_position.y), -4096, 4096)

func _nearby_units() -> Array[Node2D]:
	_rebuild_spatial_buckets_if_needed()
	var nearby: Array[Node2D] = []
	var bucket := _bucket_for_position(global_position)
	for x in range(bucket.x - 1, bucket.x + 2):
		for y in range(bucket.y - 1, bucket.y + 2):
			var key := Vector2i(x, y)
			if _spatial_buckets.has(key):
				nearby.append_array(_spatial_buckets[key])
	return nearby

func _nearby_units_limited(max_results: int) -> Array[Node2D]:
	_rebuild_spatial_buckets_if_needed()
	var nearby: Array[Node2D] = []
	if max_results == 0:
		return nearby
	var bucket := _bucket_for_position(global_position)
	for x in range(bucket.x - 1, bucket.x + 2):
		for y in range(bucket.y - 1, bucket.y + 2):
			var key := Vector2i(x, y)
			if not _spatial_buckets.has(key):
				continue
			for unit in _spatial_buckets[key]:
				nearby.append(unit)
				if max_results > 0 and nearby.size() >= max_results:
					return nearby
	return nearby

func _mass_idle_separation_velocity() -> Vector2:
	if rts_world == null or not is_instance_valid(rts_world):
		return Vector2.ZERO
	var count := rts_world.count_units_all()
	if count >= 2200 and unit_state in [&"attacking", &"rooted"]:
		return Vector2.ZERO
	if count >= 2800:
		return Vector2.ZERO
	return _mass_separation_velocity()

func _should_throttle_spawner_drones() -> bool:
	if rts_world == null or not is_instance_valid(rts_world):
		return false
	if terrain == null or str(terrain.get("map_type_id")) not in ["ai_testing_ground", "fortress_ai_arena"]:
		return false
	var count := rts_world.count_units_all()
	if owner_player_id != 1 and count >= 180:
		return true
	if count < 700:
		return false
	if unit_archetype == &"winged_spawner":
		return count >= 1200
	return true

func _is_ai_stress_arena() -> bool:
	return terrain != null and str(terrain.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena"]

static func _track_mass_collision_query(neighbors: int, overlap_checks: int) -> void:
	var frame := Engine.get_physics_frames()
	if _mass_collision_frame != frame:
		_mass_collision_frame = frame
		_mass_collision_calls = 0
		_mass_collision_neighbors = 0
		_mass_collision_overlap_checks = 0
	_mass_collision_calls += 1
	_mass_collision_neighbors += neighbors
	_mass_collision_overlap_checks += overlap_checks

static func get_mass_collision_telemetry() -> Dictionary:
	return {
		"mass_collision_calls": _mass_collision_calls,
		"mass_collision_neighbors": _mass_collision_neighbors,
		"mass_collision_overlap_checks": _mass_collision_overlap_checks,
	}

static func get_registered_units_snapshot() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for unit in _registered_units:
		if is_instance_valid(unit):
			result.append(unit)
	return result

func _queue_unit_redraw(force: bool = false) -> void:
	if force or selected or not _mass_performance_mode():
		queue_redraw()

static func _register_unit(unit: Node2D) -> void:
	if not _registered_units.has(unit):
		_registered_units.append(unit)
	_spatial_frame = -1

static func _unregister_unit(unit: Node2D) -> void:
	_registered_units.erase(unit)
	_spatial_frame = -1

static func _rebuild_spatial_buckets_if_needed() -> void:
	var frame := Engine.get_physics_frames()
	if _spatial_frame == frame:
		return
	_spatial_frame = frame
	_spatial_buckets.clear()
	for unit in _registered_units:
		if not is_instance_valid(unit):
			continue
		var key := _bucket_for_position(unit.global_position)
		if not _spatial_buckets.has(key):
			_spatial_buckets[key] = []
		_spatial_buckets[key].append(unit)

static func _bucket_for_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _spatial_bucket_size), floori(position.y / _spatial_bucket_size))

func _snap_to_walkable_terrain() -> void:
	if ignores_terrain:
		return
	if terrain == null:
		return
	var cell: Vector2i = terrain.world_to_cell(global_position)
	if terrain.is_walkable_cell(cell):
		return
	var spawn: Vector2i = terrain.get_spawn_position()
	var walkable_spawn: Vector2i = terrain.nearest_walkable_cell(spawn)
	if terrain.is_walkable_cell(walkable_spawn):
		global_position = terrain.cell_to_world(walkable_spawn)
		target_pos = global_position

func _draw_selection_and_path() -> void:
	_draw_sprite_shadow()
	_draw_melee_swing_fx()
	var mass_mode := _mass_performance_mode()
	var hide_mass_health := mass_mode and rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 250
	if selected or not hide_mass_health and (health < max_health or not mass_mode):
		_draw_health_bar()
	if not selected:
		return
	draw_arc(Vector2(0, 10), selection_radius, 0, TAU, 40, Color(0.25, 0.95, 1.0), 2.5)
	if path.is_empty():
		return
	var previous := Vector2.ZERO
	for point in path:
		var local_point := to_local(point)
		draw_line(previous, local_point, Color(0.25, 0.95, 1.0, 0.55), 2.0)
		previous = local_point
	draw_circle(to_local(path[path.size() - 1]), 5.0, Color(0.25, 0.95, 1.0, 0.8))

func _draw_sprite_shadow() -> void:
	if _mass_performance_mode() and not selected:
		return
	if not has_node("ArtSprite"):
		return
	var radius := maxf(12.0, selection_radius * 0.72)
	var points := PackedVector2Array()
	for i in 20:
		var angle := float(i) * TAU / 20.0
		points.append(Vector2(cos(angle) * radius, 10.0 + sin(angle) * radius * 0.28))
	draw_colored_polygon(points, Color(0, 0, 0, 0.28))

func _draw_unit_transform_begin() -> void:
	var bob := 0.0
	var squash := 1.0
	if moving:
		bob = sin(_visual_elapsed * 12.0) * 2.0
		squash = 1.0 + sin(_visual_elapsed * 12.0) * 0.04
	elif unit_state == &"attacking":
		bob = -absf(sin(_visual_elapsed * 18.0)) * 3.0
		squash = 1.0 + absf(sin(_visual_elapsed * 18.0)) * 0.08
	elif unit_state == &"hold":
		squash = 1.04
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(_facing_sign, squash))

func _draw_unit_transform_end() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_health_bar() -> void:
	var ratio := 1.0
	if max_health > 0:
		ratio = clampf(float(health) / float(max_health), 0.0, 1.0)
	var width := 38.0
	var y := -42.0
	var fill := team_health_color()
	if ratio < 0.35:
		fill = Color("#E85A5A")
	draw_rect(Rect2(Vector2(-width * 0.5 - 1.0, y - 1.0), Vector2(width + 2.0, 5.0)), Color("#0A1612", 0.85), true)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 3.0)), fill, true)
	if unit_state == &"hold":
		draw_line(Vector2(-12, y - 5), Vector2(12, y - 5), Color("#D6C7AE", 0.9), 2.0)
	elif command_mode == &"patrol":
		draw_arc(Vector2(0, y - 6), 6.0, 0.3, TAU - 0.3, 16, Color("#7DDDE8", 0.85), 1.5)
	elif command_mode == &"attack_move":
		draw_line(Vector2(-7, y - 7), Vector2(7, y - 3), Color("#E85A5A", 0.9), 1.5)
		draw_line(Vector2(7, y - 7), Vector2(-7, y - 3), Color("#E85A5A", 0.9), 1.5)

# True when the player has an army-wide selection rather than a squad. One
# null check and one int compare against an already-cached node reference --
# this is read from _process/_physics_process on every unit every frame, so it
# is deliberately as cheap as a property read can be (no has_method(), no
# get_property_list(); see the 2026-08-23 HUD reflection regression).
#
# Note: use_mass_vector_lod() is deliberately NOT gated on this. It only
# applies to the AI stress arena, and letting it hide art for bulk-selected
# units would be a visual change that headless tests cannot verify.
func _selection_is_bulk() -> bool:
	if rts_world == null or not is_instance_valid(rts_world):
		return false
	return rts_world.selected_unit_count > RTSWorld.BULK_SELECTION_THRESHOLD

func _mass_performance_mode() -> bool:
	if terrain != null and str(terrain.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena"]:
		return rts_world == null or not is_instance_valid(rts_world) or rts_world.count_units_all() >= 120
	if terrain != null and str(terrain.get("map_type_id")) in ["seeded_grid_frontier", "grid_test_canvas"]:
		return rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 160
	return rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 360

func _mass_redraw_interval() -> float:
	if rts_world == null or not is_instance_valid(rts_world):
		return 0.5
	var count := rts_world.count_units_all()
	if count >= 2400:
		return 4.0
	if count >= 1600:
		return 3.0
	if count >= 900:
		return 1.5
	if count >= 500:
		return 0.75
	return 0.3

func _normal_redraw_interval() -> float:
	if terrain != null and str(terrain.get("map_type_id")) in ["seeded_grid_frontier", "grid_test_canvas"]:
		return 0.12
	return 0.08

func _mass_simulation_delta(delta: float, mass_mode: bool) -> float:
	if _force_lightweight_arena_unit:
		return delta
	if not mass_mode or (selected and not _selection_is_bulk()):
		_mass_physics_accum = 0.0
		return delta
	var stride := _mass_physics_stride()
	if stride <= 1:
		_mass_physics_accum = 0.0
		return delta
	_mass_physics_accum += delta
	var frame := int(Engine.get_physics_frames())
	if posmod(frame + int(get_instance_id()), stride) != 0:
		return 0.0
	var result := _mass_physics_accum
	_mass_physics_accum = 0.0
	return result

func _mass_physics_stride() -> int:
	if rts_world == null or not is_instance_valid(rts_world):
		return 1
	var count := rts_world.count_units_all()
	if terrain != null and str(terrain.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena"]:
		if count >= 2400:
			return 8
		if count >= 1600:
			return 6
		if count >= 900:
			return 4
		if count >= 400:
			return 2
		return 1
	if terrain != null and str(terrain.get("map_type_id")) in ["seeded_grid_frontier", "grid_test_canvas"]:
		if count >= 700:
			return 3
		if count >= 160:
			return 2
		return 1
	if count >= 1200:
		return 2
	return 1

func mass_art_update_interval() -> float:
	if rts_world == null or not is_instance_valid(rts_world):
		return 0.0
	if selected and not _selection_is_bulk():
		return 0.0
	var count := rts_world.count_units_all()
	if _is_ai_stress_arena() and count >= 250:
		return 0.5
	if count < 700:
		return 0.0
	if count >= 2400:
		return 0.25
	if count >= 1600:
		return 0.18
	if count >= 900:
		return 0.12
	return 0.08

func use_mass_vector_lod() -> bool:
	if _force_lightweight_arena_unit:
		return true
	if selected or rts_world == null or not is_instance_valid(rts_world):
		return false
	if terrain == null or str(terrain.get("map_type_id")) not in ["ai_testing_ground", "fortress_ai_arena"]:
		return false
	return rts_world.count_units_all() >= 900

func _update_mass_art_lod() -> void:
	var should_hide := use_mass_vector_lod()
	if should_hide == _mass_art_hidden:
		return
	_mass_art_hidden = should_hide
	_update_mass_collision_lod(should_hide)
	visible = true
	var art := get_node_or_null("ArtSprite")
	if art != null:
		art.visible = not should_hide
		art.process_mode = Node.PROCESS_MODE_DISABLED if should_hide else Node.PROCESS_MODE_INHERIT
	queue_redraw()

func _update_mass_collision_lod(should_hide: bool) -> void:
	if should_hide:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 2
		collision_mask = 2
	var shape := get_node_or_null("CollisionShape2D")
	if shape != null:
		shape.disabled = should_hide

func _mass_repath_interval() -> int:
	if rts_world == null or not is_instance_valid(rts_world):
		return 850
	var count := rts_world.count_units_all()
	if count >= 1500:
		return 1800
	if count >= 900:
		return 1300
	return 850

func _skip_path_lookahead_for_mass_mode() -> bool:
	if not _mass_performance_mode():
		return false
	if terrain != null and str(terrain.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena"]:
		return true
	return rts_world != null and is_instance_valid(rts_world) and rts_world.count_units_all() >= 900

func _uses_direct_mass_arena_chase() -> bool:
	return _mass_performance_mode() and terrain != null and str(terrain.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena"]

func _uses_hard_mass_overlap_blocking() -> bool:
	return terrain != null and str(terrain.get("map_type_id")) in ["ai_testing_ground", "fortress_ai_arena"]

func set_arena_leash(rect: Rect2, home: Vector2) -> void:
	arena_leash_enabled = true
	arena_leash_rect = rect
	arena_home = home

func _pull_back_to_arena() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_leash_repath_msec < _mass_repath_interval():
		global_position = _clamp_to_arena(global_position)
		return
	_last_leash_repath_msec = now
	var return_target := _clamp_to_arena(global_position)
	if return_target.distance_squared_to(global_position) < 4.0:
		return_target = arena_home
	attack_target = null
	command_mode = &"attack_move"
	unit_state = &"attack_move"
	_set_path_to_world(return_target, true)

func _clamp_to_arena(point: Vector2) -> Vector2:
	if not arena_leash_enabled:
		return point
	return Vector2(
		clampf(point.x, arena_leash_rect.position.x, arena_leash_rect.end.x),
		clampf(point.y, arena_leash_rect.position.y, arena_leash_rect.end.y)
	)

func _draw_melee_swing_fx() -> void:
	if _uses_projectile():
		return
	var elapsed := float(Time.get_ticks_msec() - _last_melee_attack_msec) / 1000.0
	if elapsed < 0.0 or elapsed > 0.22:
		return
	var alpha := 1.0 - elapsed / 0.22
	var side := _facing_sign
	var center := Vector2(18.0 * side, -5.0)
	draw_arc(center, 18.0, -1.3 if side > 0.0 else PI - 1.8, 1.0 if side > 0.0 else PI + 1.3, 18, Color("#D6C7AE", 0.75 * alpha), 3.0)
	draw_line(Vector2(4.0 * side, -4), Vector2(25.0 * side, -14), Color("#E85A5A", 0.65 * alpha), 2.0)
