class_name FogOfWar
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var reveal_radius_cells: int = 8
@export var hard_fog_alpha: float = 0.82
@export var explored_fog_alpha: float = 0.38
@export var update_interval: float = 0.5
@export var draw_stride: int = 4
@export var reveal_enemy_vision: bool = false
@export var max_revealers_per_update: int = 64

const FOG_COLOR := Color("#050807")

var map: Node
var explored: Array = []
var visible_cells: Array = []
var _elapsed := 0.0

func _ready() -> void:
	z_index = 3000
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		update_interval = 0.75
		draw_stride = 6
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

	var revealed_origins: Dictionary = {}
	var revealer_count := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		if not reveal_enemy_vision and _property_or(unit, "owner_player_id", 1) != 1:
			continue
		var center: Vector2i = map.world_to_cell(unit.global_position)
		if revealed_origins.has(center):
			continue
		revealed_origins[center] = true
		var radius := _sight_radius_for(unit)
		_reveal_line_of_sight(center, radius)
		revealer_count += 1
		if revealer_count >= max_revealers_per_update:
			break
	queue_redraw()

func _reveal_line_of_sight(center: Vector2i, radius: int) -> void:
	if not map.is_in_bounds(center):
		return
	var radius_sq := radius * radius
	var viewer_height := int(map.get_height(center)) if map.has_method("get_height") else 0
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var cell := Vector2i(x, y)
			if not map.is_in_bounds(cell):
				continue
			var delta := cell - center
			if delta.length_squared() > radius_sq:
				continue
			if not _has_line_of_sight(center, cell, viewer_height):
				continue
			visible_cells[x][y] = true
			explored[x][y] = true

func _has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, viewer_height: int) -> bool:
	if from_cell == to_cell:
		return true
	var cells := _line_cells(from_cell, to_cell)
	for i in range(1, cells.size()):
		var cell := cells[i]
		if not map.is_in_bounds(cell):
			return false
		var is_target := i == cells.size() - 1
		if not is_target and not map.is_walkable_cell(cell):
			return false
		var cell_height := int(map.get_height(cell)) if map.has_method("get_height") else 0
		if cell_height > viewer_height:
			return false
	return true

func _line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := to_cell - from_cell
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		return [from_cell]
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector2i(roundi(lerpf(float(from_cell.x), float(to_cell.x), t)), roundi(lerpf(float(from_cell.y), float(to_cell.y), t)))
		if cells.is_empty() or cells[cells.size() - 1] != cell:
			cells.append(cell)
	return cells

func _sight_radius_for(unit: Node) -> int:
	var archetype := StringName(_property_or(unit, "unit_archetype", &""))
	var definition := UnitCatalog.get_definition(archetype)
	return int(definition.get("sight_radius_cells", reveal_radius_cells))

func _property_or(node: Node, property_name: String, fallback: Variant) -> Variant:
	for property in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return node.get(property_name)
	return fallback

func _draw() -> void:
	if map == null or explored.is_empty():
		return
	for x in range(0, map.MAP_W, draw_stride):
		for y in range(0, map.MAP_H, draw_stride):
			if _block_visible(x, y):
				continue
			var alpha := explored_fog_alpha if _block_explored(x, y) else hard_fog_alpha
			draw_polygon(_cell_diamond(map.cell_to_world(Vector2i(x, y)), float(draw_stride) * 1.08), PackedColorArray([_alpha(FOG_COLOR, alpha)]))

func _block_visible(start_x: int, start_y: int) -> bool:
	for x in range(start_x, mini(start_x + draw_stride, map.MAP_W)):
		for y in range(start_y, mini(start_y + draw_stride, map.MAP_H)):
			if visible_cells[x][y]:
				return true
	return false

func _block_explored(start_x: int, start_y: int) -> bool:
	for x in range(start_x, mini(start_x + draw_stride, map.MAP_W)):
		for y in range(start_y, mini(start_y + draw_stride, map.MAP_H)):
			if explored[x][y]:
				return true
	return false

func _cell_diamond(pos: Vector2, scale: float) -> PackedVector2Array:
	return PackedVector2Array([
		pos + Vector2(0, -32) * scale,
		pos + Vector2(64, 0) * scale,
		pos + Vector2(0, 32) * scale,
		pos + Vector2(-64, 0) * scale,
	])

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
