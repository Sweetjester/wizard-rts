class_name SunlightShadows
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var redraw_interval: float = 1.5
@export var unit_shadow_stride: int = 4
@export var max_unit_shadows: int = 80

const SUN := Color("#D6C7AE")
const SHADOW := Color("#050807")
const BLOOD_SUN := Color("#E85A5A")

var map: Node
var day_night: DayNightCycle
var terrain_shadows: Array[Dictionary] = []
var sun_patches: Array[Dictionary] = []
var _elapsed := 0.0

func _ready() -> void:
	z_index = 6
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		redraw_interval = 2.0
		unit_shadow_stride = 8
		max_unit_shadows = 48
	call_deferred("_rebuild")

func _process(delta: float) -> void:
	if _uses_square_grid_map():
		return
	_elapsed += delta
	if _elapsed < redraw_interval:
		return
	_elapsed = 0.0
	queue_redraw()

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	if _uses_square_grid_map():
		terrain_shadows.clear()
		sun_patches.clear()
		queue_redraw()
		return
	day_night = get_node_or_null("../DayNightCycle")
	terrain_shadows.clear()
	sun_patches.clear()
	for x in map.MAP_W:
		for y in map.MAP_H:
			var cell := Vector2i(x, y)
			var elevation: int = map.grid[x][y]
			if elevation >= map.E_MID and (x + y) % 3 == 0 and _has_lower_south_neighbor(cell):
				terrain_shadows.append({
					"pos": map.cell_to_world(cell) + Vector2(34, 36),
					"width": 76.0 + float(elevation) * 12.0,
					"alpha": 0.16 + float(elevation) * 0.04,
				})
			if elevation >= map.E_LOW and (x * 17 + y * 23) % 173 == 0:
				sun_patches.append({
					"pos": map.cell_to_world(cell) + Vector2(-10, -12),
					"radius": 34.0 + float((x + y) % 18),
					"blood": (x * 5 + y * 7) % 4 == 0,
				})
	queue_redraw()

func _draw() -> void:
	if map == null or _uses_square_grid_map():
		return
	var daylight := _daylight()
	var night := 1.0 - daylight
	var sun_dir := _sun_direction()
	var shadow_offset := Vector2(30.0, 22.0) + sun_dir * (32.0 + night * 10.0)
	for shadow in terrain_shadows:
		draw_ellipse(shadow["pos"] + shadow_offset, shadow["width"], 18.0, _alpha(SHADOW, float(shadow["alpha"]) * (0.45 + daylight * 0.75)))
	for patch in sun_patches:
		var color := BLOOD_SUN if bool(patch["blood"]) else SUN
		draw_circle(patch["pos"], patch["radius"], _alpha(color, 0.025 + daylight * 0.07))
		draw_circle(patch["pos"] - sun_dir * 12.0, patch["radius"] * 0.38, _alpha(color, daylight * 0.06))
	var unit_index := 0
	var drawn_units := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D:
			var unit_archetype := str(unit.get("unit_archetype"))
			if unit_index % unit_shadow_stride != 0 and unit_archetype != "life_wizard":
				unit_index += 1
				continue
			unit_index += 1
			draw_ellipse(unit.global_position + Vector2(12, 18) + sun_dir * 12.0, 34.0, 9.0, _alpha(SHADOW, 0.14 + daylight * 0.22))
			drawn_units += 1
			if drawn_units >= max_unit_shadows:
				break

func _has_lower_south_neighbor(cell: Vector2i) -> bool:
	var south := cell + Vector2i(0, 1)
	if not map.is_in_bounds(south):
		return false
	return map.get_height(south) < map.get_height(cell)

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _daylight() -> float:
	if day_night == null:
		day_night = get_node_or_null("../DayNightCycle")
	return day_night.get_daylight_amount() if day_night != null else 0.75

func _sun_direction() -> Vector2:
	if day_night == null:
		day_night = get_node_or_null("../DayNightCycle")
	return day_night.get_sun_direction() if day_night != null else Vector2(1.0, 0.45).normalized()

func _uses_square_grid_map() -> bool:
	return map != null and str(map.get("map_type_id")) in ["seeded_grid_frontier", "grid_test_canvas", "ai_testing_ground", "fortress_ai_arena", "plot_generator_test"]
