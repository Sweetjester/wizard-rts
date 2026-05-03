class_name LightingLayer
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var update_interval: float = 1.0
@export var max_unit_lights: int = 32
@export var unit_light_stride: int = 8

const AMBIENT := Color("#050807")
const LIFE_GLOW := Color("#7BC47F")
const SOUL_SPARK := Color("#7DDDE8")
const BLOOD_GLOW := Color("#8B1A1F")

var map: Node
var day_night: DayNightCycle
var plot_lights: Array[Dictionary] = []
var _elapsed := 0.0

func _ready() -> void:
	z_index = 2500
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		update_interval = 1.5
		max_unit_lights = 18
		unit_light_stride = 12
	call_deferred("_rebuild")

func _process(delta: float) -> void:
	if _uses_square_grid_map():
		return
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	queue_redraw()

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	day_night = get_node_or_null("../DayNightCycle")
	plot_lights.clear()
	if _uses_square_grid_map():
		queue_redraw()
		return
	for plot in map.get_plots():
		var anchor: Vector2i = plot.get("anchor", Vector2i.ZERO)
		var kind := str(plot.get("kind", ""))
		plot_lights.append({
			"pos": map.cell_to_world(anchor) + Vector2(0, -18),
			"color": BLOOD_GLOW if kind == "enemy_outpost" else SOUL_SPARK,
			"radius": 92.0 if kind == "base" else 64.0,
		})
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	_draw_ambient()
	if _uses_square_grid_map():
		return
	_draw_plot_lights()
	_draw_unit_lights()

func _draw_ambient() -> void:
	var night := _night_amount()
	var corners := PackedVector2Array([
		map.cell_to_world(Vector2i(-4, -4)),
		map.cell_to_world(Vector2i(map.MAP_W + 4, -4)),
		map.cell_to_world(Vector2i(map.MAP_W + 4, map.MAP_H + 4)),
		map.cell_to_world(Vector2i(-4, map.MAP_H + 4)),
	])
	draw_polygon(corners, PackedColorArray([_alpha(AMBIENT, 0.035 + night * 0.11)]))

func _draw_plot_lights() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var night_boost := 1.0 + _night_amount() * 1.85
	for light in plot_lights:
		var pulse := 0.5 + sin(t * 1.2 + float(light["pos"].x) * 0.01) * 0.5
		_draw_glow(light["pos"], float(light["radius"]) + pulse * 10.0 + _night_amount() * 28.0, light["color"], 0.035 * night_boost)

func _draw_unit_lights() -> void:
	var unit_index := 0
	var drawn_count := 0
	var night_boost := 1.0 + _night_amount() * 1.5
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		var unit_archetype := str(unit.get("unit_archetype"))
		if unit_index % unit_light_stride != 0 and unit_archetype != "life_wizard":
			unit_index += 1
			continue
		unit_index += 1
		var radius := 46.0
		var color := LIFE_GLOW
		if unit_archetype == "life_wizard":
			radius = 76.0
			color = SOUL_SPARK
		_draw_glow(unit.global_position + Vector2(0, -18), radius + _night_amount() * 18.0, color, 0.032 * night_boost)
		drawn_count += 1
		if drawn_count >= max_unit_lights:
			break

func _draw_glow(pos: Vector2, radius: float, color: Color, alpha: float) -> void:
	draw_circle(pos, radius, _alpha(color, alpha))
	draw_circle(pos, radius * 0.35, _alpha(color, alpha * 1.8))

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _night_amount() -> float:
	if day_night == null:
		day_night = get_node_or_null("../DayNightCycle")
	return day_night.get_night_amount() if day_night != null else 0.35

func _uses_square_grid_map() -> bool:
	return map != null and str(map.get("map_type_id")) in ["seeded_grid_frontier", "grid_test_canvas", "ai_testing_ground", "fortress_ai_arena", "plot_generator_test"]
