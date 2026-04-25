class_name WaterLightingEffects
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var pulse_speed: float = 1.35
@export var shimmer_stride: int = 3
@export var redraw_interval: float = 0.033

const AMBIENT := Color("#0A1612")
const DEEP_POOL := Color("#0E2C32")
const ALGAE_BLOOM := Color("#1A4F5C")
const WISP_LIGHT := Color("#3FA8B5")
const SOUL_SPARK := Color("#7DDDE8")
const BLOOD_LOW := Color("#2B0608")

var map: Node
var water_cells: Array[Vector2i] = []
var light_cells: Array[Vector2i] = []
var _redraw_elapsed := 0.0

func _ready() -> void:
	z_index = 3
	call_deferred("_rebuild")

func _process(delta: float) -> void:
	_redraw_elapsed += delta
	if _redraw_elapsed >= redraw_interval:
		_redraw_elapsed = 0.0
		queue_redraw()

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	water_cells.clear()
	light_cells.clear()
	for x in map.MAP_W:
		for y in map.MAP_H:
			var cell := Vector2i(x, y)
			if map.grid[x][y] == map.E_WATER:
				water_cells.append(cell)
				if (x * 5 + y * 7) % 13 == 0:
					light_cells.append(cell)
	for choke in map.get_chokepoints():
		light_cells.append(choke)
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	_draw_ambient_wash()
	_draw_water_shimmer()
	_draw_magic_lights()

func _draw_ambient_wash() -> void:
	var corners := PackedVector2Array([
		map.cell_to_world(Vector2i(-4, -4)),
		map.cell_to_world(Vector2i(map.MAP_W + 4, -4)),
		map.cell_to_world(Vector2i(map.MAP_W + 4, map.MAP_H + 4)),
		map.cell_to_world(Vector2i(-4, map.MAP_H + 4)),
	])
	draw_polygon(corners, PackedColorArray([_alpha(AMBIENT, 0.18)]))

func _draw_water_shimmer() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for i in water_cells.size():
		if i % shimmer_stride != 0:
			continue
		var cell := water_cells[i]
		var pos: Vector2 = map.cell_to_world(cell)
		var phase := t * pulse_speed + float((cell.x * 11 + cell.y * 17) % 100) * 0.05
		var shimmer := 0.5 + sin(phase) * 0.5
		draw_circle(pos, 18.0 + shimmer * 4.0, _alpha(DEEP_POOL, 0.22))
		draw_line(pos + Vector2(-12, -2), pos + Vector2(12, 2), _alpha(ALGAE_BLOOM, 0.15 + shimmer * 0.12), 2.0)

func _draw_magic_lights() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for cell in light_cells:
		var pos: Vector2 = map.cell_to_world(cell) + Vector2(0, -10)
		var phase := t * 1.7 + float((cell.x * 3 + cell.y * 19) % 64) * 0.1
		var pulse := 0.5 + sin(phase) * 0.5
		draw_circle(pos, 34.0 + pulse * 10.0, _alpha(WISP_LIGHT, 0.08 + pulse * 0.05))
		draw_circle(pos, 8.0 + pulse * 2.0, _alpha(SOUL_SPARK, 0.22 + pulse * 0.1))
	for cell in map.get_chokepoints():
		var pos: Vector2 = map.cell_to_world(cell)
		draw_circle(pos, 16.0, _alpha(BLOOD_LOW, 0.2))

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
