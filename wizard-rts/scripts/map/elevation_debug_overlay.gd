class_name ElevationDebugOverlay
extends Node2D

const CELL_SIZE := 64.0

const COLOR_LOW := Color(0.62, 0.95, 0.46, 0.72)
const COLOR_HIGH := Color(0.03, 0.25, 0.08, 0.78)
const COLOR_ROAD := Color(0.95, 0.05, 0.03, 0.82)
const COLOR_RAMP := Color(1.0, 0.55, 0.0, 0.88)
const COLOR_WATER := Color(0.0, 0.72, 1.0, 0.62)
const COLOR_BASE := Color(1.0, 0.9, 0.05, 0.82)
const COLOR_CONTENT := Color(0.7, 0.2, 1.0, 0.82)
const COLOR_BLOCKER := Color(0.02, 0.02, 0.02, 0.86)

var enabled := true
var grid: Array = []
var feature_grid: Array = []
var roads: Dictionary = {}
var plots: Array[Dictionary] = []

func configure(new_grid: Array, new_features: Array, new_roads: Dictionary, new_plots: Array[Dictionary]) -> void:
	grid = new_grid
	feature_grid = new_features
	roads = new_roads.duplicate()
	plots = new_plots.duplicate(true)
	visible = enabled
	queue_redraw()

func set_debug_enabled(value: bool) -> void:
	enabled = value
	visible = value
	queue_redraw()

func _draw() -> void:
	if not enabled or grid.is_empty():
		return
	for x in grid.size():
		var column: Array = grid[x]
		for y in column.size():
			var cell := Vector2i(x, y)
			var color := _color_for_cell(cell, int(column[y]))
			draw_rect(Rect2(Vector2(cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), color, true)

func _color_for_cell(cell: Vector2i, elevation: int) -> Color:
	var feature := ""
	if cell.x >= 0 and cell.x < feature_grid.size():
		var column: Array = feature_grid[cell.x]
		if cell.y >= 0 and cell.y < column.size():
			feature = str(column[cell.y])
	if feature == "ramp":
		return COLOR_RAMP
	if roads.has(cell) or feature == "path":
		return COLOR_ROAD
	for plot in plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.has_point(cell):
			var kind := str(plot.get("kind", ""))
			if kind == "base":
				return COLOR_BASE
			if kind != "":
				return COLOR_CONTENT
	match elevation:
		-2:
			return COLOR_BLOCKER
		-1:
			return COLOR_WATER
		2:
			return COLOR_HIGH
		3:
			return COLOR_RAMP
	return COLOR_LOW
