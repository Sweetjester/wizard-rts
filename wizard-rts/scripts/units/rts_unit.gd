extends CharacterBody2D

@export var move_speed: float = 180.0
@export var selection_radius: float = 24.0
@export var stop_distance: float = 3.0
@export var terrain_path: NodePath = NodePath("../MapGenerator")
@export var collision_separation: float = 18.0
@export var separation_bucket_size: float = 96.0

static var _registered_units: Array[Node2D] = []
static var _spatial_frame := -1
static var _spatial_bucket_size := 96.0
static var _spatial_buckets: Dictionary = {}

var selected := false
var target_pos := Vector2.ZERO
var moving := false
var path: Array[Vector2] = []
var terrain: Node
var _last_z_cell_y := 999999

func _ready() -> void:
	target_pos = global_position
	terrain = get_node_or_null(terrain_path)
	add_to_group("selectable_units")
	add_to_group("units")
	_register_unit(self)
	call_deferred("_snap_to_walkable_terrain")

func _exit_tree() -> void:
	_unregister_unit(self)

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func is_inside_selection_rect(rect: Rect2) -> bool:
	return rect.has_point(global_position)

func issue_move_order(world_pos: Vector2) -> void:
	if terrain == null:
		path = [world_pos]
	else:
		path = terrain.find_path_world(global_position, world_pos)
	moving = not path.is_empty()
	if moving:
		target_pos = path[0]
	queue_redraw()

func issue_move_order_offset(world_pos: Vector2, offset: Vector2) -> void:
	issue_move_order(world_pos + offset)

func _physics_process(delta: float) -> void:
	_update_z_index()
	if path.is_empty():
		velocity = _separation_velocity()
		moving = false
		move_and_slide()
		return

	target_pos = path[0]
	var dir := target_pos - global_position
	var step := move_speed * delta
	if dir.length() <= max(stop_distance, step):
		global_position = target_pos
		velocity = Vector2.ZERO
		path.pop_front()
		moving = not path.is_empty()
		queue_redraw()
		return

	velocity = dir.normalized() * move_speed + _separation_velocity()
	move_and_slide()

func _separation_velocity() -> Vector2:
	var push := Vector2.ZERO
	for unit in _nearby_units():
		if unit == self or not (unit is Node2D):
			continue
		var delta: Vector2 = global_position - unit.global_position
		var distance: float = delta.length()
		if distance <= 0.01 or distance >= collision_separation:
			continue
		push += delta.normalized() * (collision_separation - distance) * 8.0
	return push

func _update_z_index() -> void:
	var cell_y := int(global_position.y / 8.0)
	if cell_y == _last_z_cell_y:
		return
	_last_z_cell_y = cell_y
	z_index = int(global_position.y)

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
