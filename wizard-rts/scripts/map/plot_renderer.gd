extends Node2D

@export var map_generator_path: NodePath = NodePath("../MapGenerator")

const BASE_FILL := Color(0.18, 0.36, 0.25, 0.2)
const BASE_EDGE := Color("#7BC47F")
const ECONOMY := Color("#D6C7AE")
const TOWER := Color("#7DDDE8")
const OUTPOST := Color("#C13030")
const DARK := Color("#1A1410")

var map: Node
var plots: Array = []

func _ready() -> void:
	z_index = 6
	call_deferred("_rebuild")

func _rebuild() -> void:
	map = get_node_or_null(map_generator_path)
	if map == null or not map.has_method("get_plots"):
		call_deferred("_rebuild")
		return
	plots = map.get_plots()
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	for plot in plots:
		match String(plot.get("kind", "")):
			"base":
				_draw_base_plot(plot)
			"quest":
				_draw_wizard_tower(plot)
			"enemy_outpost":
				_draw_bandit_outpost(plot)

func _draw_base_plot(plot: Dictionary) -> void:
	var rect: Rect2i = plot["rect"]
	var center: Vector2 = map.cell_to_world(plot["anchor"])
	var radius := 36.0 + float(plot.get("economy_count", 1)) * 8.0
	draw_circle(center, radius, BASE_FILL)
	draw_arc(center, radius, 0, TAU, 48, BASE_EDGE, 3.0)
	for economy_cell in plot.get("economy_spaces", []):
		var pos: Vector2 = map.cell_to_world(economy_cell)
		draw_circle(pos, 15.0, Color(0, 0, 0, 0.38))
		draw_circle(pos, 10.0, ECONOMY)
		draw_arc(pos, 17.0, 0, TAU, 24, BASE_EDGE, 2.0)
	_draw_plot_label(center + Vector2(0, -radius - 16), plot["name"])

func _draw_wizard_tower(plot: Dictionary) -> void:
	var pos: Vector2 = map.cell_to_world(plot["anchor"])
	draw_circle(pos, 30.0, Color(0.25, 0.95, 1.0, 0.12))
	draw_rect(Rect2(pos + Vector2(-12, -42), Vector2(24, 44)), DARK)
	draw_rect(Rect2(pos + Vector2(-8, -52), Vector2(16, 12)), TOWER)
	draw_line(pos + Vector2(-16, 2), pos + Vector2(16, 2), TOWER, 3.0)
	_draw_plot_label(pos + Vector2(0, -66), plot["name"])

func _draw_bandit_outpost(plot: Dictionary) -> void:
	var pos: Vector2 = map.cell_to_world(plot["anchor"])
	draw_circle(pos, 38.0, Color(0.76, 0.19, 0.19, 0.12))
	draw_rect(Rect2(pos + Vector2(-24, -18), Vector2(48, 36)), Color(0.1, 0.04, 0.03, 0.72))
	for offset in [Vector2(-28, -22), Vector2(28, -22), Vector2(-28, 22), Vector2(28, 22)]:
		draw_circle(pos + offset, 7.0, OUTPOST)
	draw_line(pos + Vector2(-30, 0), pos + Vector2(30, 0), OUTPOST, 3.0)
	_draw_plot_label(pos + Vector2(0, -56), plot["name"])

func _draw_plot_label(pos: Vector2, text: String) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 14, Color("#D6C7AE"))
