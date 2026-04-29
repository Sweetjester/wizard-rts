class_name FortWallVisual
extends Node2D

var map_generator: Node
var cells: Array[Vector2i] = []
var color := Color("#0A1612", 0.82)

func configure(new_map_generator: Node, new_cells: Array[Vector2i], new_color: Color) -> void:
	map_generator = new_map_generator
	cells = new_cells.duplicate()
	color = new_color
	z_as_relative = false
	z_index = 1800
	queue_redraw()

func _draw() -> void:
	if map_generator == null or not is_instance_valid(map_generator):
		return
	for cell in cells:
		var center: Vector2 = map_generator.cell_to_world(cell)
		var rect := Rect2(center - Vector2(32, 32), Vector2(64, 64))
		draw_rect(rect, color, true)
		draw_rect(rect, Color("#7BC47F", 0.26), false, 1.25)
