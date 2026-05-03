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
var _hunt_elapsed := 0.0
var _hunt_charges := 0
var _observer_aura_enabled := false
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
var _damage_over_time_effects: Array[Dictionary] = []

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
		set_process(true)
	elif use_mass_vector_lod():
		set_process(false)
	queue_redraw()

func prepare_lightweight_arena_unit() -> void:
	_force_lightweight_arena_unit = true
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
	if _force_lightweight_arena_unit:
		return
	rts_movement_tick(delta)

func rts_movement_tick(delta: float) -> void:
	_life_elapsed += delta
	_update_limited_lifetime()
	_update_damage_over_time(delta)
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
		path.pop_front()
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
	if target == null or not is_instance_valid(target):
		return
	attack_target = target
	command_mode = &"attack_target"
	_has_command_destination = false
	path.clear()
	moving = false
	unit_state = &"attacking"

func issue_attack_move_order(world_pos: Vector2) -> void:
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

func issue_arena_attack_move_order(world_pos: Vector2) -> void:
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
	attack_target = null
	command_mode = &"hold"
	_has_command_destination = false
	path.clear()
	moving = false
	velocity = Vector2.ZERO
	unit_state = &"hold"
	_queue_unit_redraw()

func issue_stop_order() -> void:
	attack_target = null
	command_mode = &"idle"
	_has_command_destination = false
	path.clear()
	moving = false
	velocity = Vector2.ZERO
	unit_state = &"idle"
	_queue_unit_redraw()

func rts_combat_tick(delta: float, nearby_units: Array[Node2D]) -> void:
	if health <= 0 or _is_stunned() or _flight_cast_remaining > 0.0:
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
	if attack_target != null and (not is_instance_valid(attack_target) or not _is_enemy_unit(attack_target)):
		attack_target = null
		if command_mode == &"attack_move":
			_resume_attack_move_objective()
	if attack_target == null:
		attack_target = _find_nearest_enemy(nearby_units)
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
	path.clear()
	moving = false
	if _spawner_rooted:
		unit_state = &"rooted"
	else:
		unit_state = &"attacking"
	if _attack_elapsed < _current_attack_cooldown():
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
		path = _world_path_to(_command_destination)
		moving = not path.is_empty()
		if moving:
			target_pos = path[0]
			unit_state = &"attack_move"
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
			return 64.0
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

func team_primary_color() -> Color:
	match owner_player_id:
		1:
			return Color("#7BC47F")
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
			return Color("#2D5A3E")
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
			return Color("#7DDDE8")
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

func take_damage(amount: int, source: Node = null, damage_type: StringName = &"physical") -> void:
	if _dying:
		return
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

func heal_damage(amount: int) -> void:
	health = mini(max_health, health + amount)
	if not _mass_performance_mode() or selected:
		_queue_unit_redraw()

func stun_for_seconds(seconds: float) -> void:
	stunned_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	path.clear()
	moving = false
	unit_state = &"stunned"
	_queue_unit_redraw()

func salvage_value() -> int:
	return int(float(UnitCatalog.cost_bio(unit_archetype)) * 0.6) + int(float(max_health) * 0.12)

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
	_apply_catalog_definition()
	evolution_level += 1
	max_health = int(float(max_health) * (1.18 + float(evolution_level) * 0.03))
	health = max_health
	move_speed += float(definition.get("evolution_speed_bonus", 0.0))
	attack_damage = int(float(attack_damage) * 1.15)
	_set_ability_animation(&"evolve", 1.2)
	_queue_unit_redraw()

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
	unit_state = &"attack_move" if attack_target == null else &"attacking"
	_set_ability_animation(&"charge", 0.55)
	_queue_unit_redraw()
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
	if unit_archetype != &"life_wizard":
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
	return speed

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
	return other != self and other is Node2D and other.get("owner_player_id") != owner_player_id and other.has_method("take_damage")

func _find_nearest_enemy(units: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for unit in units:
		if not is_instance_valid(unit) or not _is_enemy_unit(unit):
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

func _advance_path_lookahead() -> void:
	if _skip_path_lookahead_for_mass_mode():
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
		path.pop_front()

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
	if not mass_mode or selected:
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
	if selected or rts_world == null or not is_instance_valid(rts_world):
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
