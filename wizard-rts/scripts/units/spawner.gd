extends RTSUnit

func _ready() -> void:
	unit_archetype = &"spawner"
	super()
	move_speed = 92.0
	selection_radius = 30.0
	collision_separation = 34.0

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var flying := unit_archetype == &"winged_spawner"
	var rooted := unit_state in [&"rooted", &"rooting", &"uprooting"]
	draw_circle(Vector2(0, 16), 26, Color(0, 0, 0, 0.34))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, 12), Vector2(-10, -18), Vector2(16, -16), Vector2(28, 12), Vector2(12, 28), Vector2(-18, 26)
	]), Color("#1E3A2D") if not flying else Color("#2D5A3E"))
	draw_circle(Vector2(-8, -2), 10, Color("#5C0F14"))
	draw_circle(Vector2(10, -4), 8, Color("#2D5A3E"))
	if flying:
		draw_arc(Vector2(-18, -2), 18.0, 3.5, 5.8, 18, Color("#7BC47F", 0.9), 4.0)
		draw_arc(Vector2(18, -2), 18.0, -2.7, -0.5, 18, Color("#7BC47F", 0.9), 4.0)
	else:
		draw_line(Vector2(-18, 18), Vector2(-34, 28), Color("#4A8A5C"), 5.0)
		draw_line(Vector2(18, 17), Vector2(34, 25), Color("#4A8A5C"), 5.0)
	if rooted:
		var cast_color := Color("#D6C7AE") if unit_state in [&"rooting", &"uprooting"] else Color("#8B1A1F")
		draw_arc(Vector2(0, 1), 28.0, 0.0, TAU, 32, Color(cast_color.r, cast_color.g, cast_color.b, 0.9), 3.0)
		draw_line(Vector2(0, -18), Vector2(0, -42), Color("#8B1A1F"), 6.0)
		draw_circle(Vector2(0, -45), 8.0, Color("#E85A5A"))
	else:
		draw_circle(Vector2(0, -20), 6.0, Color("#7BC47F"))
	_draw_unit_transform_end()
	_draw_selection_and_path()
