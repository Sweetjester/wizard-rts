extends RTSUnit

func _ready() -> void:
	unit_archetype = &"horror"
	super()
	move_speed = 205.0
	selection_radius = 17.0
	collision_separation = 18.0

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	draw_circle(Vector2(0, 9), 12, Color(0, 0, 0, 0.28))
	draw_line(Vector2(-12, 16), Vector2(5, -14), Color("#2B0608"), 5.0)
	draw_line(Vector2(12, 16), Vector2(-5, -14), Color("#2B0608"), 5.0)
	draw_circle(Vector2(0, -8), 10, Color("#8B1A1F"))
	draw_circle(Vector2(-3, -11), 2, Color("#7DDDE8"))
	draw_circle(Vector2(4, -11), 2, Color("#7DDDE8"))
	draw_line(Vector2(9, -4), Vector2(27, -12), Color("#3FA8B5"), 2.0)
	_draw_unit_transform_end()
	_draw_selection_and_path()
