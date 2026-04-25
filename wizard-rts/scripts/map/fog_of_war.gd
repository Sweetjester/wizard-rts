class_name FogOfWar
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var reveal_radius_cells: int = 8
@export var hard_fog_alpha: float = 0.82
@export var explored_fog_alpha: float = 0.38
@export var update_interval: float = 0.18

const FOG_COLOR := Color("#050807")

var map: Node
var explored: Array = []
var visible_cells: Array = []
var _elapsed := 0.0

func _ready() -> void:
	z_index = 3000
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		update_interval = 0.28
	call_deferred("_rebuild")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	_update_visibility()

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	explored.clear()
	visible_cells.clear()
	for x in map.MAP_W:
		explored.append([])
		visible_cells.append([])
		for y in map.MAP_H:
			explored[x].append(false)
			visible_cells[x].append(false)
	_update_visibility()

func _update_visibility() -> void:
	if map == null:
		return
	for x in map.MAP_W:
		for y in map.MAP_H:
			visible_cells[x][y] = false

	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		var center: Vector2i = map.world_to_cell(unit.global_position)
		_reveal_circle(center, reveal_radius_cells)
	queue_redraw()

func _reveal_circle(center: Vector2i, radius: int) -> void:
	var radius_sq := radius * radius
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var cell := Vector2i(x, y)
			if not map.is_in_bounds(cell):
				continue
			var delta := cell - center
			if delta.length_squared() > radius_sq:
				continue
			visible_cells[x][y] = true
			explored[x][y] = true

func _draw() -> void:
	if map == null or explored.is_empty():
		return
	for x in map.MAP_W:
		for y in map.MAP_H:
			if visible_cells[x][y]:
				continue
			var alpha := explored_fog_alpha if explored[x][y] else hard_fog_alpha
			draw_polygon(_cell_diamond(map.cell_to_world(Vector2i(x, y)), 1.04), PackedColorArray([_alpha(FOG_COLOR, alpha)]))

func _cell_diamond(pos: Vector2, scale: float) -> PackedVector2Array:
	return PackedVector2Array([
		pos + Vector2(0, -32) * scale,
		pos + Vector2(64, 0) * scale,
		pos + Vector2(0, 32) * scale,
		pos + Vector2(-64, 0) * scale,
	])

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
