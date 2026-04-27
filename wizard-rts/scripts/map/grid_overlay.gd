class_name GridOverlay
extends Node2D

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var grid_color := Color("#7DDDE8", 0.18)
@export var blocked_color := Color("#E85A5A", 0.22)
@export var ramp_color := Color("#D6C7AE", 0.25)
@export var line_width: float = 1.0
@export var major_line_every: int = 8

var map: Node
var _waiting_for_map := true

func _ready() -> void:
	z_as_relative = false
	z_index = 2450
	map = get_node_or_null(map_generator_path)
	if map != null and _map_ready():
		_waiting_for_map = false
		queue_redraw()
		set_process(false)
	else:
		set_process(true)

func _process(delta: float) -> void:
	if _waiting_for_map and map != null and _map_ready():
		_waiting_for_map = false
		queue_redraw()
		set_process(false)

func _draw() -> void:
	if map == null or not _map_ready():
		return
	var width: int = int(map.get("MAP_W"))
	var height: int = int(map.get("MAP_H"))
	for x in range(0, width + 1):
		var color := grid_color.lightened(0.25) if x % major_line_every == 0 else grid_color
		draw_line(map.cell_to_world(Vector2i(x, 0)), map.cell_to_world(Vector2i(x, height)), color, line_width)
	for y in range(0, height + 1):
		var color := grid_color.lightened(0.25) if y % major_line_every == 0 else grid_color
		draw_line(map.cell_to_world(Vector2i(0, y)), map.cell_to_world(Vector2i(width, y)), color, line_width)

func _map_ready() -> bool:
	if not map.has_method("cell_to_world"):
		return false
	var grid: Array = map.get("grid")
	return not grid.is_empty()

func _is_ramp_cell(cell: Vector2i) -> bool:
	var grid: Array = map.get("grid")
	if cell.x < 0 or cell.x >= grid.size():
		return false
	if cell.y < 0 or cell.y >= grid[cell.x].size():
		return false
	return int(grid[cell.x][cell.y]) == int(map.get("E_RAMP"))

func _cell_outline(cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = map.cell_to_world(cell)
	var size := _grid_cell_size()
	var half_width := size.x * 0.5
	var half_height := size.y * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half_height),
		center + Vector2(half_width, 0),
		center + Vector2(0, half_height),
		center + Vector2(-half_width, 0),
		center + Vector2(0, -half_height),
	])

func _grid_cell_size() -> Vector2:
	var layer = map.get("layer_low")
	if layer != null and is_instance_valid(layer) and layer.get("tile_set") != null:
		return Vector2(layer.get("tile_set").tile_size)
	return Vector2(111, 55)
