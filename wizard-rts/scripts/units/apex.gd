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
	var definition := UnitCatalog.get_definition(unit_archetype)
	if bool(definition.get("consume_ally_heals", false)):
		heal_damage(maxi(1, int(float(target.get("max_health")) * 0.65)))
	else:
		_gain_evolution_xp(float(target.get("max_health")) * 1.3)
	_set_ability_animation(&"consume_ally", 0.75)
	target.queue_free()
	return true

func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var body := team_secondary_color().darkened(0.12)
	var plate := team_primary_color().darkened(0.1)
	var accent := team_accent_color()
	draw_circle(Vector2(0, 12), 17, Color(0, 0, 0, 0.34))
	draw_circle(Vector2(0, -2), 18, body)
	draw_circle(Vector2(-8, -6), 9, plate)
	draw_circle(Vector2(9, -5), 10, team_primary_color())
	draw_circle(Vector2(0, -12), 4, accent)
	draw_line(Vector2(-12, 10), Vector2(-28, 20), body, 4.0)
	draw_line(Vector2(12, 10), Vector2(28, 20), body, 4.0)
	_draw_unit_transform_end()
	_draw_selection_and_path()
