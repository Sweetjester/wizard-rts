extends "res://scripts/units/rts_unit.gd"

func _ready() -> void:
	unit_archetype = &"terrible_thing"
	super()
	move_speed = 155.0
	selection_radius = 18.0
	collision_separation = 20.0

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	_draw_body(Color("#5C0F14"), Color("#E85A5A"))
	_draw_unit_transform_end()
	_draw_selection_and_path()

func _draw_body(body: Color, glow: Color) -> void:
	draw_circle(Vector2(0, 9), 13, Color(0, 0, 0, 0.3))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 4), Vector2(12, 3), Vector2(9, 23), Vector2(-8, 22)
	]), body)
	draw_circle(Vector2(0, -8), 11, body.lightened(0.15))
	draw_circle(Vector2(-4, -10), 2, glow)
	draw_circle(Vector2(4, -10), 2, glow)
	draw_line(Vector2(-8, 14), Vector2(-20, 20), body.darkened(0.25), 3.0)
	draw_line(Vector2(8, 14), Vector2(20, 20), body.darkened(0.25), 3.0)
