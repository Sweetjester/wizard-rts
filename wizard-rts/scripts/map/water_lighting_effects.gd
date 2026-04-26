class_name WaterLightingEffects
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var pulse_speed: float = 1.35
@export var shimmer_stride: int = 36
@export var surface_stride: int = 8
@export var max_magic_lights: int = 80

const AMBIENT := Color("#0A1612")
const DEEP_POOL := Color("#0E2C32")
const ALGAE_BLOOM := Color("#1A4F5C")
const WISP_LIGHT := Color("#3FA8B5")
const SOUL_SPARK := Color("#7DDDE8")
const BLOOD_LOW := Color("#2B0608")
const SHORE_GLOW := Color("#7DDDE8")

var map: Node
var day_night: DayNightCycle
var water_cells: Array[Vector2i] = []
var shore_cells: Array[Vector2i] = []
var light_cells: Array[Vector2i] = []
func _ready() -> void:
	z_index = 5
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		shimmer_stride = 56
		surface_stride = 12
		max_magic_lights = 48
	set_process(false)
	call_deferred("_rebuild")

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	day_night = get_node_or_null("../DayNightCycle")
	water_cells.clear()
	shore_cells.clear()
	light_cells.clear()
	for x in map.MAP_W:
		for y in map.MAP_H:
			var cell := Vector2i(x, y)
			if map.grid[x][y] == map.E_WATER:
				water_cells.append(cell)
				if _is_shore_cell(cell):
					shore_cells.append(cell)
				if light_cells.size() < max_magic_lights and (x * 5 + y * 7) % 37 == 0:
					light_cells.append(cell)
	var choke_index := 0
	for choke in map.get_chokepoints():
		if light_cells.size() < max_magic_lights and choke_index % 12 == 0:
			light_cells.append(choke)
		choke_index += 1
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	_draw_ambient_wash()
	_draw_water_surface()
	_draw_shoreline()
	_draw_water_shimmer()
	_draw_magic_lights()

func _draw_ambient_wash() -> void:
	var corners := PackedVector2Array([
		map.cell_to_world(Vector2i(-4, -4)),
		map.cell_to_world(Vector2i(map.MAP_W + 4, -4)),
		map.cell_to_world(Vector2i(map.MAP_W + 4, map.MAP_H + 4)),
		map.cell_to_world(Vector2i(-4, map.MAP_H + 4)),
	])
	draw_polygon(corners, PackedColorArray([_alpha(AMBIENT, 0.055)]))

func _draw_water_shimmer() -> void:
	var t := 0.0
	var night := _night_amount()
	for i in water_cells.size():
		if i % shimmer_stride != 0:
			continue
		var cell := water_cells[i]
		var pos: Vector2 = map.cell_to_world(cell)
		var phase := t * pulse_speed + float((cell.x * 11 + cell.y * 17) % 100) * 0.05
		var shimmer := 0.5 + sin(phase) * 0.5
		draw_circle(pos, 18.0 + shimmer * 4.0, _alpha(DEEP_POOL, 0.16 + night * 0.14))
		draw_line(pos + Vector2(-12, -2), pos + Vector2(12, 2), _alpha(ALGAE_BLOOM, 0.12 + shimmer * 0.08 + night * 0.10), 2.0)

func _draw_water_surface() -> void:
	for i in water_cells.size():
		if i % surface_stride != 0:
			continue
		var cell := water_cells[i]
		var pos: Vector2 = map.cell_to_world(cell)
		draw_polygon(_cell_diamond(pos, 1.02), PackedColorArray([_alpha(DEEP_POOL, 0.26)]))
		if (cell.x * 13 + cell.y * 17) % 5 == 0:
			draw_line(pos + Vector2(-22, -4), pos + Vector2(18, 4), _alpha(ALGAE_BLOOM, 0.26), 2.0)

func _draw_shoreline() -> void:
	for cell in shore_cells:
		var pos: Vector2 = map.cell_to_world(cell)
		draw_polyline(_cell_diamond(pos, 1.04), _alpha(SHORE_GLOW, 0.16), 2.0, true)

func _cell_diamond(pos: Vector2, scale: float) -> PackedVector2Array:
	return PackedVector2Array([
		pos + Vector2(0, -32) * scale,
		pos + Vector2(64, 0) * scale,
		pos + Vector2(0, 32) * scale,
		pos + Vector2(-64, 0) * scale,
		pos + Vector2(0, -32) * scale,
	])

func _is_shore_cell(cell: Vector2i) -> bool:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if map.is_in_bounds(neighbor) and map.grid[neighbor.x][neighbor.y] != map.E_WATER:
			return true
	return false

func _draw_magic_lights() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var night := _night_amount()
	for cell in light_cells:
		var pos: Vector2 = map.cell_to_world(cell) + Vector2(0, -10)
		var phase := t * 1.7 + float((cell.x * 3 + cell.y * 19) % 64) * 0.1
		var pulse := 0.5 + sin(phase) * 0.5
		draw_circle(pos, 34.0 + pulse * 10.0 + night * 12.0, _alpha(WISP_LIGHT, 0.06 + pulse * 0.04 + night * 0.08))
		draw_circle(pos, 8.0 + pulse * 2.0, _alpha(SOUL_SPARK, 0.18 + pulse * 0.08 + night * 0.18))
	var choke_index := 0
	for cell in map.get_chokepoints():
		if choke_index % 16 != 0:
			choke_index += 1
			continue
		choke_index += 1
		var pos: Vector2 = map.cell_to_world(cell)
		draw_circle(pos, 16.0, _alpha(BLOOD_LOW, 0.2))

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _night_amount() -> float:
	if day_night == null:
		day_night = get_node_or_null("../DayNightCycle")
	return day_night.get_night_amount() if day_night != null else 0.35
