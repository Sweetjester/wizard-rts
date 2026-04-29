class_name RTSWorld
extends Node

@export var bucket_size: float = 384.0
@export var projectile_pool_preload: int = 96
@export var projectile_pool_cap: int = 512

var _units: Array[Node2D] = []
var _structures: Array[Node2D] = []
var _by_owner: Dictionary = {}
var _buckets: Dictionary = {}
var _structure_buckets: Dictionary = {}
var _projectile_pool: Array[RtsProjectile] = []
var _active_projectiles := 0
var _total_projectiles_spawned := 0
var _total_projectiles_recycled := 0
var _projectiles_spawned_this_second := 0
var _projectiles_recycled_this_second := 0
var _last_projectiles_spawned_per_second := 0
var _last_projectiles_recycled_per_second := 0
var _projectile_meter_elapsed := 0.0
var _damage_by_owner: Dictionary = {}
var _total_damage := 0
var _peak_units := 0
var _lightweight_move_cursor := 0
var _lightweight_move_accum := 0.0
var _lightweight_move_last_budget := 0
var _lightweight_move_last_ms := 0.0

func _ready() -> void:
	for i in projectile_pool_preload:
		_projectile_pool.append(_make_projectile())

func _process(delta: float) -> void:
	_update_lightweight_arena_movement(delta)
	_projectile_meter_elapsed += delta
	if _projectile_meter_elapsed < 1.0:
		return
	_last_projectiles_spawned_per_second = _projectiles_spawned_this_second
	_last_projectiles_recycled_per_second = _projectiles_recycled_this_second
	_projectiles_spawned_this_second = 0
	_projectiles_recycled_this_second = 0
	_projectile_meter_elapsed = 0.0

func _update_lightweight_arena_movement(delta: float) -> void:
	if _units.is_empty():
		_lightweight_move_last_budget = 0
		_lightweight_move_last_ms = 0.0
		return
	_lightweight_move_accum += delta
	var step_interval := _lightweight_move_interval()
	if _lightweight_move_accum < step_interval:
		return
	var step := _lightweight_move_accum
	_lightweight_move_accum = 0.0
	var started := Time.get_ticks_usec()
	var budget := _lightweight_move_budget()
	var scaled_step := step * (float(_units.size()) / float(maxi(1, budget)))
	var updated := 0
	var checked := 0
	while checked < _units.size() and updated < budget:
		var unit: Node2D = _units[posmod(_lightweight_move_cursor, _units.size())]
		_lightweight_move_cursor = posmod(_lightweight_move_cursor + 1, maxi(1, _units.size()))
		checked += 1
		if not is_instance_valid(unit) or not unit.has_method("rts_movement_tick"):
			continue
		if not bool(unit.get("_force_lightweight_arena_unit")):
			continue
		unit.call("rts_movement_tick", scaled_step)
		updated += 1
	_lightweight_move_last_budget = updated
	_lightweight_move_last_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _lightweight_move_interval() -> float:
	return 0.05

func _lightweight_move_budget() -> int:
	var count := count_units_all()
	if count >= 2400:
		return 760
	if count >= 1600:
		return 840
	if count >= 900:
		return 900
	return 960

func register_unit(unit: Node2D) -> void:
	if unit == null or _units.has(unit):
		return
	_units.append(unit)
	var owner := _owner_for(unit)
	if not _by_owner.has(owner):
		_by_owner[owner] = []
	_by_owner[owner].append(unit)
	_peak_units = maxi(_peak_units, _units.size())

func unregister_unit(unit: Node2D) -> void:
	_units.erase(unit)
	var owner := _owner_for(unit)
	if _by_owner.has(owner):
		_by_owner[owner].erase(unit)

func register_structure(structure: Node2D) -> void:
	if structure == null or _structures.has(structure):
		return
	_structures.append(structure)

func unregister_structure(structure: Node2D) -> void:
	_structures.erase(structure)

func all_units() -> Array[Node2D]:
	_prune_invalid(_units)
	return _units

func all_structures() -> Array[Node2D]:
	_prune_invalid(_structures)
	return _structures

func units_for_owner(owner_id: int) -> Array[Node2D]:
	if not _by_owner.has(owner_id):
		return []
	var units: Array[Node2D] = []
	for unit in _by_owner[owner_id]:
		if is_instance_valid(unit):
			units.append(unit)
	_by_owner[owner_id] = units
	return units

func count_units_for_owner(owner_id: int) -> int:
	return units_for_owner(owner_id).size()

func count_units_all() -> int:
	return _units.size()

func rebuild_spatial() -> void:
	_buckets.clear()
	for unit in all_units():
		var key := _bucket_for(unit.global_position)
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(unit)
	_structure_buckets.clear()
	for structure in all_structures():
		var key := _bucket_for(structure.global_position)
		if not _structure_buckets.has(key):
			_structure_buckets[key] = []
		_structure_buckets[key].append(structure)

func query_units(position: Vector2, radius: float, owner_filter: int = -1, max_results: int = -1) -> Array[Node2D]:
	var results: Array[Node2D] = []
	var min_bucket := _bucket_for(position - Vector2(radius, radius))
	var max_bucket := _bucket_for(position + Vector2(radius, radius))
	var radius_sq := radius * radius
	for x in range(min_bucket.x, max_bucket.x + 1):
		for y in range(min_bucket.y, max_bucket.y + 1):
			var key := Vector2i(x, y)
			if not _buckets.has(key):
				continue
			for unit in _buckets[key]:
				if not is_instance_valid(unit):
					continue
				if owner_filter >= 0 and _owner_for(unit) != owner_filter:
					continue
				if position.distance_squared_to(unit.global_position) <= radius_sq:
					results.append(unit)
					if max_results > 0 and results.size() >= max_results:
						return results
	return results

func query_enemy_units(position: Vector2, radius: float, owner_id: int, max_results: int = -1) -> Array[Node2D]:
	var results: Array[Node2D] = []
	for unit in query_units(position, radius):
		if _owner_for(unit) != owner_id:
			results.append(unit)
			if max_results > 0 and results.size() >= max_results:
				return results
	return results

func query_attackables(position: Vector2, radius: float, owner_filter: int = -1, max_results: int = -1) -> Array[Node2D]:
	var results: Array[Node2D] = query_units(position, radius, owner_filter, max_results)
	if max_results > 0 and results.size() >= max_results:
		return results
	var radius_sq := radius * radius
	_query_structure_buckets(position, radius, owner_filter, -999999, max_results, radius_sq, results)
	return results

func query_enemy_attackables(position: Vector2, radius: float, owner_id: int, max_results: int = -1) -> Array[Node2D]:
	var results: Array[Node2D] = []
	var min_bucket := _bucket_for(position - Vector2(radius, radius))
	var max_bucket := _bucket_for(position + Vector2(radius, radius))
	var radius_sq := radius * radius
	for x in range(min_bucket.x, max_bucket.x + 1):
		for y in range(min_bucket.y, max_bucket.y + 1):
			var key := Vector2i(x, y)
			if not _buckets.has(key):
				continue
			for unit in _buckets[key]:
				if not is_instance_valid(unit) or _owner_for(unit) == owner_id:
					continue
				if position.distance_squared_to(unit.global_position) <= radius_sq:
					results.append(unit)
					if max_results > 0 and results.size() >= max_results:
						return results
	_query_structure_buckets(position, radius, -1, owner_id, max_results, radius_sq, results)
	return results

func _query_structure_buckets(position: Vector2, radius: float, owner_filter: int, excluded_owner: int, max_results: int, radius_sq: float, results: Array[Node2D]) -> void:
	var min_bucket := _bucket_for(position - Vector2(radius, radius))
	var max_bucket := _bucket_for(position + Vector2(radius, radius))
	for x in range(min_bucket.x, max_bucket.x + 1):
		for y in range(min_bucket.y, max_bucket.y + 1):
			var key := Vector2i(x, y)
			if not _structure_buckets.has(key):
				continue
			for structure in _structure_buckets[key]:
				if not is_instance_valid(structure):
					continue
				var owner := _owner_for(structure)
				if owner_filter >= 0 and owner != owner_filter:
					continue
				if excluded_owner != -999999 and owner == excluded_owner:
					continue
				if position.distance_squared_to(structure.global_position) > radius_sq:
					continue
				results.append(structure)
				if max_results > 0 and results.size() >= max_results:
					return

func spawn_projectile(source: Node2D, target: Node2D, damage: int, color: Color, speed: float, origin: Vector2) -> RtsProjectile:
	var projectile: RtsProjectile = _projectile_pool.pop_back() if not _projectile_pool.is_empty() else _make_projectile()
	if projectile.get_parent() == null:
		add_child(projectile)
	projectile.visible = true
	projectile.process_mode = Node.PROCESS_MODE_INHERIT
	projectile.global_position = origin
	projectile.configure(source, target, damage, color, speed)
	projectile.activate(self)
	_active_projectiles += 1
	_total_projectiles_spawned += 1
	_projectiles_spawned_this_second += 1
	return projectile

func recycle_projectile(projectile: RtsProjectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if projectile.visible:
		_active_projectiles = maxi(0, _active_projectiles - 1)
		_total_projectiles_recycled += 1
		_projectiles_recycled_this_second += 1
	projectile.visible = false
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	if _projectile_pool.size() < projectile_pool_cap:
		_projectile_pool.append(projectile)
	else:
		projectile.queue_free()

func _make_projectile() -> RtsProjectile:
	var projectile := RtsProjectile.new()
	projectile.visible = false
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(projectile)
	return projectile

func _bucket_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / bucket_size), floori(position.y / bucket_size))

func _owner_for(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	return int(node.get("owner_player_id"))

func _prune_invalid(items: Array[Node2D]) -> void:
	for i in range(items.size() - 1, -1, -1):
		if not is_instance_valid(items[i]):
			items.remove_at(i)

func record_damage(source: Node, _target: Node, amount: int) -> void:
	if amount <= 0:
		return
	var owner := _owner_for(source)
	if not _damage_by_owner.has(owner):
		_damage_by_owner[owner] = 0
	_damage_by_owner[owner] = int(_damage_by_owner[owner]) + amount
	_total_damage += amount

func get_observation_telemetry() -> Dictionary:
	var owner_counts := {}
	var archetype_counts := {}
	var state_counts := {}
	var moving_units := 0
	var attacking_units := 0
	for owner in _by_owner.keys():
		owner_counts[owner] = count_units_for_owner(int(owner))
	for unit in all_units():
		if not is_instance_valid(unit):
			continue
		var archetype := str(unit.get("unit_archetype"))
		archetype_counts[archetype] = int(archetype_counts.get(archetype, 0)) + 1
		var state := str(unit.get("unit_state"))
		state_counts[state] = int(state_counts.get(state, 0)) + 1
		if bool(unit.get("moving")):
			moving_units += 1
		if state == "attacking":
			attacking_units += 1
	return {
		"units": count_units_all(),
		"structures": all_structures().size(),
		"owner_counts": owner_counts,
		"archetype_counts": archetype_counts,
		"state_counts": state_counts,
		"moving_units": moving_units,
		"attacking_units": attacking_units,
		"active_projectiles": _active_projectiles,
		"projectiles_spawned": _total_projectiles_spawned,
		"projectiles_recycled": _total_projectiles_recycled,
		"projectiles_spawned_per_second": _last_projectiles_spawned_per_second,
		"projectiles_recycled_per_second": _last_projectiles_recycled_per_second,
		"lightweight_move_budget": _lightweight_move_last_budget,
		"lightweight_move_ms": _lightweight_move_last_ms,
		"damage_total": _total_damage,
		"damage_by_owner": _damage_by_owner.duplicate(),
		"peak_units": _peak_units,
	}
