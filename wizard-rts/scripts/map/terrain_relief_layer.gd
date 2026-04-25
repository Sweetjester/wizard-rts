class_name TerrainReliefLayer
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")

const TILE_HALF_W := 64.0
const TILE_HALF_H := 32.0
const LEVEL_RISE := 64.0

const CLIFF_FACE := Color("#080D0B", 0.86)
const CLIFF_FACE_DEEP := Color("#030605", 0.92)
const CLIFF_LIP_HIGH := Color("#D6C7AE", 0.72)
const CLIFF_LIP_MID := Color("#8A7560", 0.62)
const MOSS_EDGE := Color("#7BC47F", 0.38)
const BLOOD_ROOT := Color("#5C0F14", 0.52)
const RAMP_STONE := Color("#D6C7AE", 0.48)
const RAMP_SHADOW := Color("#050807", 0.38)
const RAMP_GLOW := Color("#7DDDE8", 0.22)

var map: Node
var cliff_faces: Array = []
var lip_lines: Array = []
var ridge_marks: Array = []
var ramp_marks: Array = []

func _ready() -> void:
	z_index = 3
	call_deferred("_rebuild")

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	_build_relief()
	queue_redraw()

func _build_relief() -> void:
	cliff_faces.clear()
	lip_lines.clear()
	ridge_marks.clear()
	ramp_marks.clear()

	for x in map.MAP_W:
		for y in map.MAP_H:
			var cell := Vector2i(x, y)
			var elevation: int = map.grid[x][y]
			if elevation == map.E_RAMP:
				_add_ramp_mark(cell)
				continue
			if elevation == map.E_BLOCKED:
				_add_impassible_ridges(cell)
				continue
			if elevation == map.E_WATER:
				continue
			_add_cliff_edges(cell)

func _add_cliff_edges(cell: Vector2i) -> void:
	var elevation: int = map.grid[cell.x][cell.y]
	if elevation == map.E_LOW:
		return
	var height := _visual_height(cell)
	var edges := _diamond_edges(cell, height)
	var neighbors := [
		{"offset": Vector2i(1, 0), "edge": edges["right"]},
		{"offset": Vector2i(0, 1), "edge": edges["bottom"]},
		{"offset": Vector2i(-1, 0), "edge": edges["left"]},
		{"offset": Vector2i(0, -1), "edge": edges["top"]},
	]
	for item in neighbors:
		var neighbor: Vector2i = cell + item["offset"]
		var neighbor_height := _visual_height(neighbor)
		if _is_ramp_transition(cell, neighbor):
			continue
		if neighbor_height >= height:
			continue
		var drop_levels: int = maxi(1, height - neighbor_height)
		_add_cliff_face(item["edge"][0], item["edge"][1], drop_levels, elevation)

func _add_impassible_ridges(cell: Vector2i) -> void:
	var touching_walkable := false
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if _is_walkable_terrain(neighbor):
			touching_walkable = true
			break
	if not touching_walkable:
		return

	var height := _dominant_neighbor_height(cell)
	var points := _diamond_points(cell, height)
	ridge_marks.append({
		"points": points,
		"center": _cell_world(cell, height),
		"height": height,
	})

func _add_ramp_mark(cell: Vector2i) -> void:
	var height := _visual_height(cell)
	var center := _cell_world(cell, height)
	var east_west := _ramp_is_east_west(cell)
	var lines: Array = []
	if east_west:
		lines.append([center + Vector2(-42, -11), center + Vector2(42, -11)])
		lines.append([center + Vector2(-50, 0), center + Vector2(50, 0)])
		lines.append([center + Vector2(-42, 11), center + Vector2(42, 11)])
	else:
		lines.append([center + Vector2(-24, -19), center + Vector2(24, 19)])
		lines.append([center + Vector2(-34, -10), center + Vector2(34, 10)])
		lines.append([center + Vector2(-24, 19), center + Vector2(24, -19)])
	ramp_marks.append({
		"diamond": _diamond_points(cell, height),
		"lines": lines,
		"center": center,
	})

func _add_cliff_face(a: Vector2, b: Vector2, drop_levels: int, elevation: int) -> void:
	var drop := Vector2(0, 34.0 + 28.0 * float(drop_levels))
	var face := PackedVector2Array([a, b, b + drop, a + drop])
	cliff_faces.append({
		"points": face,
		"color": CLIFF_FACE_DEEP if drop_levels > 1 else CLIFF_FACE,
	})
	var lip_color := CLIFF_LIP_HIGH if elevation == map.E_HIGH else CLIFF_LIP_MID
	lip_lines.append({"a": a, "b": b, "color": lip_color, "width": 3.0})
	lip_lines.append({"a": a + Vector2(0, 4), "b": b + Vector2(0, 4), "color": MOSS_EDGE, "width": 2.0})

func _draw() -> void:
	for face in cliff_faces:
		draw_colored_polygon(face["points"], face["color"])
	for ridge in ridge_marks:
		draw_colored_polygon(ridge["points"], Color("#050807", 0.62))
		var center: Vector2 = ridge["center"]
		for i in range(4):
			var angle := float(i) * TAU / 4.0 + 0.55
			var root_end := center + Vector2(cos(angle) * 46.0, sin(angle) * 20.0)
			draw_line(center, root_end, BLOOD_ROOT, 3.0)
	for ramp in ramp_marks:
		draw_colored_polygon(ramp["diamond"], RAMP_SHADOW)
		for line in ramp["lines"]:
			draw_line(line[0], line[1], RAMP_STONE, 5.0)
			draw_line(line[0] + Vector2(0, -2), line[1] + Vector2(0, -2), RAMP_GLOW, 2.0)
	for line in lip_lines:
		draw_line(line["a"], line["b"], line["color"], line["width"])

func _diamond_edges(cell: Vector2i, height: int) -> Dictionary:
	var points := _diamond_points(cell, height)
	return {
		"top": [points[3], points[0]],
		"right": [points[0], points[1]],
		"bottom": [points[1], points[2]],
		"left": [points[2], points[3]],
	}

func _diamond_points(cell: Vector2i, height: int) -> PackedVector2Array:
	var center := _cell_world(cell, height)
	return PackedVector2Array([
		center + Vector2(0, -TILE_HALF_H),
		center + Vector2(TILE_HALF_W, 0),
		center + Vector2(0, TILE_HALF_H),
		center + Vector2(-TILE_HALF_W, 0),
	])

func _cell_world(cell: Vector2i, height: int) -> Vector2:
	return map.cell_to_world(cell) + Vector2(0, -LEVEL_RISE * float(height))

func _visual_height(cell: Vector2i) -> int:
	if map == null or not map.is_in_bounds(cell):
		return -1
	var elevation: int = map.grid[cell.x][cell.y]
	if elevation == map.E_BLOCKED:
		return _dominant_neighbor_height(cell)
	if elevation == map.E_WATER:
		return -1
	return int(map.get_height(cell))

func _dominant_neighbor_height(cell: Vector2i) -> int:
	var best := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if map.is_in_bounds(neighbor) and map.grid[neighbor.x][neighbor.y] >= map.E_LOW:
			best = maxi(best, int(map.get_height(neighbor)))
	return best

func _is_walkable_terrain(cell: Vector2i) -> bool:
	return map != null and map.is_in_bounds(cell) and map.grid[cell.x][cell.y] >= map.E_LOW

func _is_ramp_transition(cell: Vector2i, neighbor: Vector2i) -> bool:
	if not map.is_in_bounds(neighbor):
		return false
	return map.grid[cell.x][cell.y] == map.E_RAMP or map.grid[neighbor.x][neighbor.y] == map.E_RAMP

func _ramp_is_east_west(cell: Vector2i) -> bool:
	var horizontal := 0
	var vertical := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0)]:
		var neighbor: Vector2i = cell + offset
		if map.is_in_bounds(neighbor) and map.grid[neighbor.x][neighbor.y] == map.E_RAMP:
			horizontal += 1
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if map.is_in_bounds(neighbor) and map.grid[neighbor.x][neighbor.y] == map.E_RAMP:
			vertical += 1
	return horizontal >= vertical
