class_name RTSWorld
extends Node

@export var bucket_size: float = 384.0
@export var projectile_pool_preload: int = 96
@export var projectile_pool_cap: int = 512

var _units: Array[Node2D] = []
var _structures: Array[Node2D] = []
var _by_owner: Dictionary = {}
var _buckets: Dictionary = {}
var _projectile_pool: Array[RtsProjectile] = []

func _ready() -> void:
	for i in projectile_pool_preload:
		_projectile_pool.append(_make_projectile())

func register_unit(unit: Node2D) -> void:
	if unit == null or _units.has(unit):
		return
	_units.append(unit)
	var owner := _owner_for(unit)
	if not _by_owner.has(owner):
		_by_owner[owner] = []
	_by_owner[owner].append(unit)

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

func rebuild_spatial() -> void:
	_buckets.clear()
	for unit in all_units():
		var key := _bucket_for(unit.global_position)
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(unit)

func query_units(position: Vector2, radius: float, owner_filter: int = -1) -> Array[Node2D]:
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
	return results

func query_enemy_units(position: Vector2, radius: float, owner_id: int) -> Array[Node2D]:
	var results: Array[Node2D] = []
	for unit in query_units(position, radius):
		if _owner_for(unit) != owner_id:
			results.append(unit)
	return results

func spawn_projectile(source: Node2D, target: Node2D, damage: int, color: Color, speed: float, origin: Vector2) -> RtsProjectile:
	var projectile: RtsProjectile = _projectile_pool.pop_back() if not _projectile_pool.is_empty() else _make_projectile()
	if projectile.get_parent() == null:
		add_child(projectile)
	projectile.visible = true
	projectile.process_mode = Node.PROCESS_MODE_INHERIT
	projectile.global_position = origin
	projectile.configure(source, target, damage, color, speed)
	projectile.activate(self)
	return projectile

func recycle_projectile(projectile: RtsProjectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
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
