extends RTSUnit

func _ready() -> void:
	unit_archetype = &"life_treant"
	super()
	move_speed = 145.0
	selection_radius = 20.0
	collision_separation = 22.0

func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var body := team_secondary_color()
	var leaf := team_primary_color()
	var accent := team_accent_color()
	draw_circle(Vector2(0, 9), 13, Color(0, 0, 0, 0.3))
	draw_line(Vector2(0, 8), Vector2(0, -16), body, 8.0)
	draw_line(Vector2(-2, -5), Vector2(-13, -18), body.lightened(0.15), 4.0)
	draw_line(Vector2(2, -6), Vector2(13, -20), body.lightened(0.15), 4.0)
	draw_circle(Vector2(0, -18), 13, leaf.darkened(0.2))
	draw_circle(Vector2(-8, -17), 8, leaf)
	draw_circle(Vector2(8, -19), 7, leaf.lightened(0.12))
	draw_circle(Vector2(-3, -9), 1.5, accent)
	draw_circle(Vector2(4, -10), 1.5, accent)
	_draw_unit_transform_end()
	_draw_selection_and_path()
