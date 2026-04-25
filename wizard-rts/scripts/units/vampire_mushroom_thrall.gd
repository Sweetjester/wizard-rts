extends "res://scripts/units/rts_unit.gd"

func _ready() -> void:
	owner_player_id = 2
	unit_archetype = &"vampire_mushroom_thrall"
	super()
	move_speed = 130.0
	selection_radius = 18.0
	collision_separation = 20.0

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	draw_circle(Vector2(0, 9), 13, Color(0, 0, 0, 0.3))
	draw_line(Vector2(0, 8), Vector2(0, -15), Color("#D6C7AE"), 7.0)
	draw_circle(Vector2(0, -18), 18, Color("#8B1A1F"))
	draw_circle(Vector2(-5, -20), 4, Color("#E85A5A"))
	draw_circle(Vector2(4, -9), 2, Color("#7DDDE8"))
	_draw_unit_transform_end()
	_draw_selection_and_path()
