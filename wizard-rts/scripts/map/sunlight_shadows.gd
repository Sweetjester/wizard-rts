class_name SunlightShadows
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var redraw_interval: float = 0.75

const SUN := Color("#D6C7AE")
const SHADOW := Color("#050807")
const BLOOD_SUN := Color("#E85A5A")

var map: Node
var terrain_shadows: Array[Dictionary] = []
var sun_patches: Array[Dictionary] = []
var _elapsed := 0.0

func _ready() -> void:
	z_index = 6
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		redraw_interval = 1.0
	call_deferred("_rebuild")

func _process(delta: float) -> void:
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
	if map == null:
		return
	for shadow in terrain_shadows:
		draw_ellipse(shadow["pos"], shadow["width"], 18.0, _alpha(SHADOW, shadow["alpha"]))
	for patch in sun_patches:
		var color := BLOOD_SUN if bool(patch["blood"]) else SUN
		draw_circle(patch["pos"], patch["radius"], _alpha(color, 0.055))
		draw_circle(patch["pos"] + Vector2(-7, -4), patch["radius"] * 0.38, _alpha(color, 0.05))
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D:
			draw_ellipse(unit.global_position + Vector2(12, 18), 34.0, 9.0, _alpha(SHADOW, 0.28))

func _has_lower_south_neighbor(cell: Vector2i) -> bool:
	var south := cell + Vector2i(0, 1)
	if not map.is_in_bounds(south):
		return false
	return map.get_height(south) < map.get_height(cell)

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
