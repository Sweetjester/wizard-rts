extends "res://scripts/units/rts_unit.gd"

func _ready() -> void:
	super()
	move_speed = 145.0
	selection_radius = 20.0
	collision_separation = 22.0

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	draw_circle(Vector2(0, 9), 13, Color(0, 0, 0, 0.3))
	draw_line(Vector2(0, 8), Vector2(0, -16), Color("#332820"), 8.0)
	draw_line(Vector2(-2, -5), Vector2(-13, -18), Color("#5C4838"), 4.0)
	draw_line(Vector2(2, -6), Vector2(13, -20), Color("#5C4838"), 4.0)
	draw_circle(Vector2(0, -18), 13, Color("#1E3A2D"))
	draw_circle(Vector2(-8, -17), 8, Color("#2D5A3E"))
	draw_circle(Vector2(8, -19), 7, Color("#4A8A5C"))
	draw_circle(Vector2(-3, -9), 1.5, Color("#7BC47F"))
	draw_circle(Vector2(4, -10), 1.5, Color("#7BC47F"))
	_draw_selection_and_path()
