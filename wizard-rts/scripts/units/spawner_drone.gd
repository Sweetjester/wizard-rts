extends RTSUnit

func _ready() -> void:
	unit_archetype = &"spawner_drone"
	super()
	move_speed = 245.0
	selection_radius = 12.0
	collision_separation = 12.0

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	var bob := sin(float(Time.get_ticks_msec()) / 130.0) * 3.0
	draw_circle(Vector2(0, 12), 10, Color(0, 0, 0, 0.2))
	draw_circle(Vector2(0, -8 + bob), 8, Color("#2D5A3E"))
	draw_circle(Vector2(0, -9 + bob), 3, Color("#7DDDE8"))
	draw_line(Vector2(-8, -7 + bob), Vector2(-18, -13 + bob), Color("#7BC47F"), 2.0)
	draw_line(Vector2(8, -7 + bob), Vector2(18, -13 + bob), Color("#7BC47F"), 2.0)
	_draw_selection_and_path()
