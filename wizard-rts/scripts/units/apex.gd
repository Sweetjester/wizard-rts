extends RTSUnit

func _ready() -> void:
	unit_archetype = &"apex"
	super()
	move_speed = 135.0
	selection_radius = 23.0
	collision_separation = 26.0

func eat_ally(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target == self or int(target.get("owner_player_id")) != owner_player_id:
		return false
	if not target.has_method("salvage_value"):
		return false
	_gain_evolution_xp(float(target.get("max_health")) * 1.3)
	target.queue_free()
	return true

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	draw_circle(Vector2(0, 12), 17, Color(0, 0, 0, 0.34))
	draw_circle(Vector2(0, -2), 18, Color("#332820"))
	draw_circle(Vector2(-8, -6), 9, Color("#2D5A3E"))
	draw_circle(Vector2(9, -5), 10, Color("#5C0F14"))
	draw_circle(Vector2(0, -12), 4, Color("#7BC47F"))
	draw_line(Vector2(-12, 10), Vector2(-28, 20), Color("#332820"), 4.0)
	draw_line(Vector2(12, 10), Vector2(28, 20), Color("#332820"), 4.0)
	_draw_unit_transform_end()
	_draw_selection_and_path()
