class_name WaveDirector
extends Node

signal phase_changed(phase: StringName)
signal wave_spawned(wave_index: int, count: int)
signal boss_spawned()
signal boss_defeated()

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var enemy_scene: PackedScene = preload("res://scenes/units/vampire_mushroom_thrall.tscn")
@export var enabled: bool = true
@export var scouting_seconds: float = 45.0
@export var buildup_seconds: float = 135.0
@export var first_wave_seconds: float = 50.0
@export var wave_interval_seconds: float = 32.0
@export var boss_arrival_seconds: float = 240.0
@export var base_wave_size: int = 6
@export var wave_size_growth: int = 3
@export var max_active_enemies: int = 120
@export var retarget_interval: float = 2.0
@export var max_retargets_per_tick: int = 12

var map_generator: Node
var rts_world: RTSWorld
var phase: StringName = &"scouting"
var elapsed := 0.0
var next_wave_at := 75.0
var wave_index := 0
var boss_has_spawned := false
var boss_has_been_defeated := false
var boss_node: Node = null
var _retarget_elapsed := 0.0

func _ready() -> void:
	map_generator = get_node_or_null(map_generator_path)
	rts_world = get_node_or_null(rts_world_path)
	next_wave_at = first_wave_seconds

func _process(delta: float) -> void:
	if not enabled:
		return
	elapsed += delta
	_update_phase()
	if elapsed >= next_wave_at:
		_spawn_wave()
		next_wave_at += wave_interval_seconds
	if not boss_has_spawned and elapsed >= boss_arrival_seconds:
		_spawn_boss()
	if boss_has_spawned and not boss_has_been_defeated and (boss_node == null or not is_instance_valid(boss_node)):
		boss_has_been_defeated = true
		phase = &"victory"
		phase_changed.emit(phase)
		boss_defeated.emit()
	_retarget_elapsed += delta
	if _retarget_elapsed >= retarget_interval:
		_retarget_enemy_army()
		_retarget_elapsed = 0.0

func _update_phase() -> void:
	var next_phase := phase
	if elapsed >= scouting_seconds + buildup_seconds:
		next_phase = &"offense"
	elif elapsed >= scouting_seconds:
		next_phase = &"buildup"
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)

func _spawn_wave() -> void:
	if map_generator == null or enemy_scene == null:
		return
	var active := rts_world.count_units_for_owner(2) if rts_world != null else _count_enemy_units_fallback()
	if active >= max_active_enemies:
		return
	wave_index += 1
	var spawn_count: int = mini(base_wave_size + wave_index * wave_size_growth, max_active_enemies - active)
	var spawns: Array = map_generator.get("enemy_spawns")
	if spawns.is_empty():
		return
	var target := _player_target_world()
	for i in spawn_count:
		var spawn_cell: Vector2i = _pathable_spawn_cell(spawns, target, i * 17 + wave_index * 11)
		_spawn_enemy(_enemy_archetype_for_wave(i), spawn_cell, get_parent(), target)
	wave_spawned.emit(wave_index, spawn_count)

func _spawn_boss() -> void:
	if map_generator == null or enemy_scene == null:
		return
	boss_has_spawned = true
	var spawns: Array = map_generator.get("enemy_spawns")
	if spawns.is_empty():
		return
	var target := _player_target_world()
	var spawn_cell: Vector2i = _pathable_spawn_cell(spawns, target, wave_index * 19 + 5)
	boss_node = _spawn_enemy(&"mycelium_boss", spawn_cell, get_parent(), target)
	boss_spawned.emit()

func _spawn_enemy(archetype: StringName, spawn_cell: Vector2i, parent: Node, preferred_target: Vector2 = Vector2.ZERO) -> Node:
	var enemy := enemy_scene.instantiate()
	parent.add_child(enemy)
	if enemy.has_method("configure_enemy"):
		enemy.call("configure_enemy", archetype)
	enemy.global_position = map_generator.cell_to_world(map_generator.nearest_walkable_cell(spawn_cell, 10))
	call_deferred("_send_enemy_to_player_target", enemy, preferred_target)
	return enemy

func _send_enemy_to_player_target(enemy: Node, preferred_target: Vector2 = Vector2.ZERO) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("issue_attack_move_order"):
		return
	var target := preferred_target if preferred_target != Vector2.ZERO else _player_target_world()
	if target == Vector2.ZERO:
		return
	if not bool(enemy.get("ignores_terrain")):
		target = _pathable_target_for_enemy(enemy as Node2D, target)
	enemy.issue_attack_move_order(target)
	if enemy.get("path").is_empty() and not bool(enemy.get("ignores_terrain")):
		target = _nearest_walkable_player_target(enemy as Node2D)
		if target != Vector2.ZERO:
			enemy.issue_attack_move_order(target)

func get_boss_seconds_remaining() -> int:
	if boss_has_spawned:
		return 0
	return maxi(0, ceili(boss_arrival_seconds - elapsed))

func _enemy_archetype_for_wave(index: int) -> StringName:
	if wave_index <= 1:
		return &"bloodcap_runner" if index % 3 == 0 else &"vampire_mushroom_thrall"
	if wave_index <= 3:
		if index % 4 == 0:
			return &"spore_spitter"
		return &"bloodcap_runner" if index % 3 == 0 else &"vampire_mushroom_thrall"
	if index % 6 == 0:
		return &"bloodcap_brute"
	if index % 4 == 0:
		return &"spore_spitter"
	return &"bloodcap_runner" if index % 3 == 0 else &"vampire_mushroom_thrall"

func _retarget_enemy_army() -> void:
	var target := _player_target_world()
	if target == Vector2.ZERO:
		return
	var retargeted := 0
	var enemies: Array[Node2D] = rts_world.units_for_owner(2) if rts_world != null else _enemy_units_fallback()
	for unit in enemies:
		if not is_instance_valid(unit) or int(unit.get("owner_player_id")) != 2:
			continue
		if unit.has_method("issue_attack_move_order") and _should_retarget(unit):
			_send_enemy_to_player_target(unit, target)
			retargeted += 1
			if retargeted >= max_retargets_per_tick:
				return

func _should_retarget(unit: Node) -> bool:
	var state: StringName = unit.get("unit_state")
	if state in [&"attacking", &"stunned"]:
		return false
	var target = unit.get("attack_target")
	return target == null or not is_instance_valid(target)

func _player_target_world() -> Vector2:
	var tower := _nearest_player_structure(&"wizard_tower")
	if tower != null:
		return _reachable_world_near(tower.global_position)
	var any_structure := _nearest_player_structure(&"")
	if any_structure != null:
		return _reachable_world_near(any_structure.global_position)
	var player_units: Array[Node2D] = rts_world.units_for_owner(1) if rts_world != null else _player_units_fallback()
	for unit in player_units:
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			return _reachable_world_near(unit.global_position)
	return Vector2.ZERO

func _reachable_world_near(world_pos: Vector2) -> Vector2:
	if map_generator == null or not map_generator.has_method("world_to_cell") or not map_generator.has_method("nearest_walkable_cell"):
		return world_pos
	var cell: Vector2i = map_generator.world_to_cell(world_pos)
	var reachable: Vector2i = map_generator.nearest_walkable_cell(cell, 16)
	if map_generator.has_method("cell_to_world"):
		return map_generator.cell_to_world(reachable)
	return world_pos

func _pathable_spawn_cell(spawns: Array, target: Vector2, start_index: int) -> Vector2i:
	if target == Vector2.ZERO or map_generator == null or not map_generator.has_method("find_path_world"):
		return spawns[posmod(start_index, spawns.size())]
	for offset in range(mini(spawns.size(), 36)):
		var cell: Vector2i = spawns[posmod(start_index + offset * 7, spawns.size())]
		var world: Vector2 = map_generator.cell_to_world(map_generator.nearest_walkable_cell(cell, 10))
		var path: Array = map_generator.find_path_world(world, target)
		if not path.is_empty():
			return cell
	return spawns[posmod(start_index, spawns.size())]

func _pathable_target_for_enemy(enemy: Node2D, preferred_target: Vector2) -> Vector2:
	if enemy == null or map_generator == null or not map_generator.has_method("find_path_world"):
		return preferred_target
	var path: Array = map_generator.find_path_world(enemy.global_position, preferred_target)
	if not path.is_empty():
		return preferred_target
	var fallback := _nearest_walkable_player_target(enemy)
	return fallback if fallback != Vector2.ZERO else preferred_target

func _nearest_walkable_player_target(enemy: Node2D) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for candidate in _player_target_candidates():
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var cell: Vector2i = map_generator.world_to_cell((candidate as Node2D).global_position)
		var target_cell: Vector2i = map_generator.nearest_walkable_cell(cell, 18)
		var target_world: Vector2 = map_generator.cell_to_world(target_cell)
		var path: Array = map_generator.find_path_world(enemy.global_position, target_world)
		if path.is_empty():
			continue
		var distance := enemy.global_position.distance_squared_to(target_world)
		if distance < best_distance:
			best = target_world
			best_distance = distance
	return best

func _player_target_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	for structure in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1:
			candidates.append(structure)
	var player_units: Array[Node2D] = rts_world.units_for_owner(1) if rts_world != null else _player_units_fallback()
	for unit in player_units:
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			candidates.append(unit)
	return candidates

func _nearest_player_structure(archetype: StringName) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	var origin := Vector2.ZERO
	var spawns: Array = []
	if map_generator != null:
		spawns = map_generator.get("enemy_spawns")
	if not spawns.is_empty():
		origin = map_generator.cell_to_world(spawns[0])
	for structure in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(structure) or int(structure.get("owner_player_id")) != 1:
			continue
		if archetype != &"" and str(structure.get("archetype")) != str(archetype):
			continue
		var distance := origin.distance_squared_to(structure.global_position)
		if distance < best_distance:
			best = structure
			best_distance = distance
	return best

func _count_enemy_units_fallback() -> int:
	var active := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 2:
			active += 1
	return active

func _enemy_units_fallback() -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == 2:
			enemies.append(unit)
	return enemies

func _player_units_fallback() -> Array[Node2D]:
	var players: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == 1:
			players.append(unit)
	return players
