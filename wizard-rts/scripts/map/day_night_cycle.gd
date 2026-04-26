class_name DayNightCycle
extends Node2D

@export var map_path: NodePath = NodePath("../MapGenerator")
@export var cycle_duration_seconds: float = 240.0
@export_range(0.0, 1.0, 0.01) var start_time_of_day: float = 0.28
@export var redraw_interval: float = 0.5

const DAWN := Color("#E85A5A")
const DAY := Color("#D6C7AE")
const DUSK := Color("#8B1A1F")
const NIGHT := Color("#050807")
const MOON := Color("#7DDDE8")

var map: Node
var time_of_day := 0.0
var _elapsed := 0.0
var _redraw_elapsed := 0.0

func _ready() -> void:
	z_index = 2450
	time_of_day = start_time_of_day
	var display_manager := get_node_or_null("/root/DisplayManager")
	if display_manager != null and bool(display_manager.get("performance_mode")):
		redraw_interval = 0.85
	call_deferred("_rebuild")

func _process(delta: float) -> void:
	if cycle_duration_seconds <= 0.0:
		return
	_elapsed += delta
	time_of_day = fposmod(start_time_of_day + _elapsed / cycle_duration_seconds, 1.0)
	_redraw_elapsed += delta
	if _redraw_elapsed >= redraw_interval:
		_redraw_elapsed = 0.0
		queue_redraw()

func _rebuild() -> void:
	map = get_node_or_null(map_path)
	if map == null or map.grid.is_empty():
		call_deferred("_rebuild")
		return
	queue_redraw()

func get_daylight_amount() -> float:
	var sun_height := sin(time_of_day * TAU - PI * 0.5) * 0.5 + 0.5
	return smoothstep(0.10, 0.82, sun_height)

func get_night_amount() -> float:
	return 1.0 - get_daylight_amount()

func get_sun_direction() -> Vector2:
	var angle := time_of_day * TAU
	return Vector2(cos(angle) * 1.25, sin(angle) * 0.55).normalized()

func get_sun_color() -> Color:
	var daylight := get_daylight_amount()
	var dawn_dusk: float = 1.0 - abs(time_of_day - 0.5) * 2.0
	dawn_dusk = clampf(1.0 - daylight + dawn_dusk * 0.12, 0.0, 1.0)
	var warm := DAWN.lerp(DUSK, smoothstep(0.45, 0.72, time_of_day))
	return warm.lerp(DAY, daylight)

func get_shadow_alpha() -> float:
	return 0.16 + get_daylight_amount() * 0.25

func _draw() -> void:
	if map == null:
		return
	var bounds := _map_bounds()
	var daylight := get_daylight_amount()
	var night := get_night_amount()
	var tint := get_sun_color()
	var night_color := NIGHT.lerp(MOON, 0.10)
	draw_polygon(bounds, PackedColorArray([_alpha(tint, 0.025 + daylight * 0.055)]))
	draw_polygon(bounds, PackedColorArray([_alpha(night_color, night * 0.32)]))
	_draw_sunshaft(bounds, daylight)
	_draw_vignette(bounds, night)

func _draw_sunshaft(bounds: PackedVector2Array, daylight: float) -> void:
	if daylight <= 0.05:
		return
	var center := (bounds[0] + bounds[2]) * 0.5
	var dir := get_sun_direction()
	var cross := Vector2(-dir.y, dir.x)
	var length := bounds[0].distance_to(bounds[2]) * 0.34
	var width := 2200.0
	var p := PackedVector2Array([
		center - dir * length - cross * width,
		center + dir * length - cross * width * 0.55,
		center + dir * length + cross * width * 0.55,
		center - dir * length + cross * width,
	])
	draw_polygon(p, PackedColorArray([_alpha(DAY, daylight * 0.032)]))

func _draw_vignette(bounds: PackedVector2Array, night: float) -> void:
	if night <= 0.05:
		return
	var center := (bounds[0] + bounds[2]) * 0.5
	var radius := bounds[0].distance_to(bounds[2]) * 0.32
	draw_circle(center, radius, _alpha(MOON, night * 0.016))
	draw_circle(center + Vector2(0, 220), radius * 1.35, _alpha(NIGHT, night * 0.09))

func _map_bounds() -> PackedVector2Array:
	return PackedVector2Array([
		map.cell_to_world(Vector2i(-8, -8)),
		map.cell_to_world(Vector2i(map.MAP_W + 8, -8)),
		map.cell_to_world(Vector2i(map.MAP_W + 8, map.MAP_H + 8)),
		map.cell_to_world(Vector2i(-8, map.MAP_H + 8)),
	])

func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
