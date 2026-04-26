extends RTSUnit

@export var enemy_archetype: StringName = &"vampire_mushroom_thrall"

func _ready() -> void:
	owner_player_id = 2
	unit_archetype = enemy_archetype
	super()
	_apply_enemy_tuning()

func configure_enemy(archetype: StringName) -> void:
	enemy_archetype = archetype
	unit_archetype = archetype
	_apply_catalog_definition()
	health = max_health
	_apply_enemy_tuning()
	queue_redraw()

func _apply_enemy_tuning() -> void:
	match unit_archetype:
		&"bloodcap_runner":
			move_speed = 165.0
			selection_radius = 15.0
			collision_separation = 17.0
		&"spore_spitter":
			move_speed = 120.0
			selection_radius = 17.0
			collision_separation = 18.0
		&"bloodcap_brute":
			move_speed = 92.0
			selection_radius = 26.0
			collision_separation = 28.0
		&"mycelium_boss":
			move_speed = 150.0
			selection_radius = 118.0
			collision_separation = 82.0
		_:
			move_speed = 130.0
			selection_radius = 18.0
			collision_separation = 20.0

func _draw() -> void:
	if has_node("ArtSprite"):
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var is_boss := unit_archetype == &"mycelium_boss"
	draw_circle(Vector2(0, 22 if is_boss else 9), 86 if is_boss else 13, Color(0, 0, 0, 0.34 if is_boss else 0.3))
	match unit_archetype:
		&"bloodcap_runner":
			draw_line(Vector2(0, 8), Vector2(0, -14), Color("#5C0F14"), 5.0)
			draw_circle(Vector2(0, -16), 12, Color("#C13030"))
			draw_circle(Vector2(-4, -18), 3, Color("#E85A5A"))
		&"spore_spitter":
			draw_line(Vector2(0, 8), Vector2(0, -12), Color("#332820"), 7.0)
			draw_circle(Vector2(0, -18), 16, Color("#5C0F14"))
			draw_circle(Vector2(4, -18), 5, Color("#7DDDE8"))
			draw_arc(Vector2(0, -18), 20.0, 0.2, PI - 0.2, 16, Color("#3FA8B5", 0.75), 2.0)
		&"bloodcap_brute":
			draw_line(Vector2(0, 10), Vector2(0, -18), Color("#332820"), 12.0)
			draw_circle(Vector2(0, -22), 24, Color("#8B1A1F"))
			draw_circle(Vector2(-7, -25), 5, Color("#E85A5A"))
			draw_circle(Vector2(7, -21), 4, Color("#2B0608"))
		&"mycelium_boss":
			_draw_mycelium_boss()
		_:
			draw_line(Vector2(0, 8), Vector2(0, -15), Color("#D6C7AE"), 7.0)
			draw_circle(Vector2(0, -18), 18, Color("#8B1A1F"))
			draw_circle(Vector2(-5, -20), 4, Color("#E85A5A"))
			draw_circle(Vector2(4, -9), 2, Color("#7DDDE8"))
	_draw_unit_transform_end()
	_draw_selection_and_path()

func _draw_mycelium_boss() -> void:
	var pulse := 0.5 + sin(_visual_elapsed * 3.0) * 0.5
	draw_circle(Vector2(0, -18), 105, Color("#2B0608", 0.88))
	draw_arc(Vector2(0, -18), 118.0 + pulse * 7.0, 0, TAU, 64, Color("#E85A5A", 0.65), 7.0)
	for i in 10:
		var angle := float(i) * TAU / 10.0 + sin(_visual_elapsed * 0.8) * 0.08
		var root_start := Vector2(cos(angle) * 38.0, -8 + sin(angle) * 20.0)
		var root_end := Vector2(cos(angle) * 120.0, 20 + sin(angle) * 54.0)
		draw_line(root_start, root_end, Color("#1A1410"), 12.0)
		draw_line(root_start, root_end, Color("#5C0F14", 0.78), 5.0)
	for i in 7:
		var x := -72.0 + float(i) * 24.0
		var height := 74.0 + float((i % 3) * 22)
		draw_line(Vector2(x, 22), Vector2(x * 0.55, -height), Color("#332820"), 18.0)
		draw_circle(Vector2(x * 0.55, -height - 14), 34.0 + float(i % 2) * 8.0, Color("#8B1A1F"))
		draw_circle(Vector2(x * 0.55 - 8, -height - 22), 8.0, Color("#E85A5A"))
	draw_circle(Vector2(0, -30), 64, Color("#5C0F14"))
	draw_circle(Vector2(-24, -54), 13, Color("#7DDDE8"))
	draw_circle(Vector2(26, -52), 13, Color("#7DDDE8"))
	draw_circle(Vector2(0, -22), 20 + pulse * 4.0, Color("#E85A5A", 0.72))
	draw_arc(Vector2(0, -30), 72.0, 0.15, PI - 0.15, 32, Color("#C13030", 0.8), 5.0)
	for i in 18:
		var angle := float(i) * TAU / 18.0
		var p := Vector2(cos(angle) * (42.0 + pulse * 8.0), -30 + sin(angle) * 32.0)
		draw_circle(p, 3.0, Color("#7DDDE8", 0.68))
