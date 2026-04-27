class_name WaveDirector
extends Node

signal phase_changed(phase: StringName)
signal wave_spawned(wave_index: int, count: int)
signal boss_spawned()
signal boss_defeated()

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var enemy_scene: PackedScene = preload("res://scenes/units/vampire_mushroom_thrall.tscn")
@export var terrible_thing_scene: PackedScene = preload("res://scenes/units/terrible_thing.tscn")
@export var horror_scene: PackedScene = preload("res://scenes/units/horror.tscn")
@export var apex_scene: PackedScene = preload("res://scenes/units/apex.tscn")
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
@export var ai_test_spawn_budget_per_frame: int = 48
@export var ai_test_min_spawn_budget_per_frame: int = 8
@export var ai_test_spawn_queue_limit: int = 640
@export var ai_test_live_unit_soft_cap: int = 1800
@export var ai_test_spawn_pause_fps: float = 28.0
@export var ai_test_spawn_slow_fps: float = 45.0

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
var ai_test_wave_index := 0
var _ai_test_spawn_queue: Array[Dictionary] = []
var _ai_test_units_spawned_this_second := 0
var _ai_test_spawn_meter_elapsed := 0.0
var _ai_test_last_units_spawned_per_second := 0

func _ready() -> void:
	map_generator = get_node_or_null(map_generator_path)
	rts_world = get_node_or_null(rts_world_path)
	next_wave_at = first_wave_seconds
	if is_ai_testing_ground():
		enabled = false
		phase = &"ai_test"
		phase_changed.emit(phase)

func _process(delta: float) -> void:
	if is_ai_testing_ground():
		_update_ai_test_spawn_queue(delta)
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

func is_ai_testing_ground() -> bool:
	return map_generator != null and str(map_generator.get("map_type_id")) == "ai_testing_ground"

func spawn_ai_test_wave() -> Dictionary:
	if map_generator == null:
		return {"wave": ai_test_wave_index, "west": 0, "east": 0, "queued": _ai_test_spawn_queue.size(), "accepted": false}
	var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
	var remaining_capacity: int = ai_test_live_unit_soft_cap - live_units - _ai_test_spawn_queue.size()
	if remaining_capacity <= 0:
		return {"wave": ai_test_wave_index, "west": 0, "east": 0, "queued": _ai_test_spawn_queue.size(), "accepted": false, "reason": "soft_cap"}
	if _ai_test_spawn_queue.size() >= ai_test_spawn_queue_limit:
		return {"wave": ai_test_wave_index, "west": 0, "east": 0, "queued": _ai_test_spawn_queue.size(), "accepted": false, "reason": "spawn_queue_full"}
	ai_test_wave_index += 1
	var count_per_side: int = mini(12 + ai_test_wave_index * 4, 80)
	var max_requests: int = mini(mini(count_per_side * 2, remaining_capacity), ai_test_spawn_queue_limit - _ai_test_spawn_queue.size())
	var parent := get_parent()
	var west_queued := 0
	var east_queued := 0
	for i in count_per_side:
		if west_queued + east_queued >= max_requests:
			break
		var west_cell := _ai_test_spawn_cell(Vector2i(18, 37), i, -1)
		var east_cell := _ai_test_spawn_cell(Vector2i(78, 37), i, 1)
		var west_target: Vector2 = _ai_test_lane_target(Vector2i(66, 37), i)
		var east_target: Vector2 = _ai_test_lane_target(Vector2i(30, 37), i)
		_ai_test_spawn_queue.append({"index": i, "side": 2, "cell": west_cell, "target": west_target, "parent": parent})
		west_queued += 1
		if west_queued + east_queued >= max_requests:
			break
		_ai_test_spawn_queue.append({"index": i, "side": 3, "cell": east_cell, "target": east_target, "parent": parent})
		east_queued += 1
	return {"wave": ai_test_wave_index, "west": west_queued, "east": east_queued, "queued": _ai_test_spawn_queue.size(), "accepted": west_queued + east_queued > 0}

func queue_ai_test_until(target_live_units: int) -> Dictionary:
	var queued_waves := 0
	var queued_units := 0
	var last_result := {}
	for _i in 40:
		var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
		if live_units + _ai_test_spawn_queue.size() >= target_live_units:
			break
		last_result = spawn_ai_test_wave()
		if not bool(last_result.get("accepted", false)):
			break
		queued_waves += 1
		queued_units += int(last_result.get("west", 0)) + int(last_result.get("east", 0))
	return {
		"target": target_live_units,
		"queued_waves": queued_waves,
		"queued_units": queued_units,
		"queued": _ai_test_spawn_queue.size(),
		"last_reason": str(last_result.get("reason", "")),
	}

func get_ai_test_spawn_telemetry() -> Dictionary:
	return {
		"spawn_queue": _ai_test_spawn_queue.size(),
		"spawn_queue_limit": ai_test_spawn_queue_limit,
		"spawn_budget_per_frame": ai_test_spawn_budget_per_frame,
		"effective_spawn_budget_per_frame": _effective_ai_test_spawn_budget(),
		"spawned_per_second": _ai_test_last_units_spawned_per_second,
		"live_soft_cap": ai_test_live_unit_soft_cap,
	}

func _update_ai_test_spawn_queue(delta: float) -> void:
	_ai_test_spawn_meter_elapsed += delta
	if _ai_test_spawn_meter_elapsed >= 1.0:
		_ai_test_last_units_spawned_per_second = _ai_test_units_spawned_this_second
		_ai_test_units_spawned_this_second = 0
		_ai_test_spawn_meter_elapsed = 0.0
	if _ai_test_spawn_queue.is_empty():
		return
	var budget := _effective_ai_test_spawn_budget()
	if budget <= 0:
		return
	var spawned := 0
	while spawned < budget and not _ai_test_spawn_queue.is_empty():
		var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
		if live_units >= ai_test_live_unit_soft_cap:
			_ai_test_spawn_queue.clear()
			return
		var request: Dictionary = _ai_test_spawn_queue.pop_front()
		var unit := _spawn_queued_ai_test_unit(request)
		if unit != null:
			spawned += 1
			_ai_test_units_spawned_this_second += 1
	if spawned > 0:
		wave_spawned.emit(ai_test_wave_index, spawned)

func _effective_ai_test_spawn_budget() -> int:
	var fps := float(Performance.get_monitor(Performance.TIME_FPS))
	var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var live_units: int = rts_world.count_units_all() if rts_world != null and rts_world.has_method("count_units_all") else _count_ai_test_units_fallback()
	if fps > 1.0 and fps < ai_test_spawn_pause_fps:
		return 0
	if process_ms > 75.0 or physics_ms > 45.0:
		return 0
	var max_budget := ai_test_spawn_budget_per_frame
	if live_units >= 1500:
		max_budget = mini(max_budget, 12)
	elif live_units >= 1000:
		max_budget = mini(max_budget, 24)
	elif live_units >= 600:
		max_budget = mini(max_budget, 32)
	if fps > 1.0 and fps < ai_test_spawn_slow_fps:
		return mini(max_budget, ai_test_min_spawn_budget_per_frame)
	if process_ms > 40.0 or physics_ms > 24.0:
		return maxi(ai_test_min_spawn_budget_per_frame, max_budget / 3)
	return maxi(ai_test_min_spawn_budget_per_frame, max_budget)

func _spawn_queued_ai_test_unit(request: Dictionary) -> Node:
	var index := int(request.get("index", 0))
	var side := int(request.get("side", 2))
	var spawn_cell: Vector2i = request.get("cell", Vector2i.ZERO)
	var parent: Node = request.get("parent", get_parent())
	var target: Vector2 = request.get("target", Vector2.ZERO)
	if parent == null or not is_instance_valid(parent):
		parent = get_parent()
	if side == 2:
		return _spawn_ai_test_west_unit(index, spawn_cell, parent, target)
	return _spawn_ai_test_east_unit(index, spawn_cell, parent, target)

func _ai_test_spawn_cell(anchor: Vector2i, index: int, side: int) -> Vector2i:
	var row := index / 10
	var col := index % 10
	var offset := Vector2i(col * side, row - 5)
	return map_generator.nearest_walkable_cell(anchor + offset, 12)

func _ai_test_lane_target(anchor: Vector2i, index: int) -> Vector2:
	var lane := (index % 14) - 7
	var depth := (index / 14) % 4
	var target_cell: Vector2i = map_generator.nearest_walkable_cell(anchor + Vector2i(depth, lane), 10)
	return map_generator.cell_to_world(target_cell)

func _spawn_ai_test_west_unit(index: int, spawn_cell: Vector2i, parent: Node, target: Vector2) -> Node:
	var archetypes: Array[StringName] = [&"terrible_thing", &"horror", &"terrible_thing", &"apex"]
	var scenes: Array[PackedScene] = [terrible_thing_scene, horror_scene, terrible_thing_scene, apex_scene]
	var slot := index % archetypes.size()
	return _spawn_ai_test_unit(scenes[slot], archetypes[slot], 2, spawn_cell, parent, target)

func _spawn_ai_test_east_unit(index: int, spawn_cell: Vector2i, parent: Node, target: Vector2) -> Node:
	var archetypes: Array[StringName] = [&"terrible_thing", &"horror", &"terrible_thing", &"apex"]
	var scenes: Array[PackedScene] = [terrible_thing_scene, horror_scene, terrible_thing_scene, apex_scene]
	var slot := index % archetypes.size()
	return _spawn_ai_test_unit(scenes[slot], archetypes[slot], 3, spawn_cell, parent, target)

func _spawn_ai_test_unit(scene: PackedScene, archetype: StringName, owner: int, spawn_cell: Vector2i, parent: Node, target: Vector2) -> Node:
	if scene == null:
		return null
	var unit := scene.instantiate()
	unit.set("owner_player_id", owner)
	unit.set("unit_archetype", archetype)
	if _has_property(unit, "enemy_archetype"):
		unit.set("enemy_archetype", archetype)
	if unit.has_method("configure_enemy"):
		unit.call("configure_enemy", archetype)
	parent.add_child(unit)
	unit.set("owner_player_id", owner)
	unit.global_position = map_generator.cell_to_world(map_generator.nearest_walkable_cell(spawn_cell, 10))
	if unit.has_method("set_arena_leash"):
		var min_world: Vector2 = map_generator.cell_to_world(Vector2i(8, 20))
		var max_world: Vector2 = map_generator.cell_to_world(Vector2i(88, 58))
		var arena_rect := Rect2(min_world, max_world - min_world)
		unit.call("set_arena_leash", arena_rect, target)
	if unit.has_method("issue_attack_move_order"):
		unit.issue_attack_move_order(target)
	return unit

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

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

func _count_ai_test_units_fallback() -> int:
	var active := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) in [2, 3]:
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
