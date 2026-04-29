extends RTSUnit

func _ready() -> void:
	unit_archetype = &"spawner_drone"
	super()
	move_speed = 245.0
	selection_radius = 12.0
	collision_separation = 12.0

func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_selection_and_path()
		return
	var bob := sin(float(Time.get_ticks_msec()) / 130.0) * 3.0
	var body := team_primary_color()
	var accent := team_accent_color()
	draw_circle(Vector2(0, 12), 10, Color(0, 0, 0, 0.2))
	draw_circle(Vector2(0, -8 + bob), 8, body.darkened(0.1))
	draw_circle(Vector2(0, -9 + bob), 3, accent)
	draw_line(Vector2(-8, -7 + bob), Vector2(-18, -13 + bob), accent, 2.0)
	draw_line(Vector2(8, -7 + bob), Vector2(18, -13 + bob), accent, 2.0)
	_draw_selection_and_path()
