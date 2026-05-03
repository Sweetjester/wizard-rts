extends RTSUnit

@export var enemy_archetype: StringName = &"deom_scout"

func _ready() -> void:
	unit_archetype = enemy_archetype
	super()
	_apply_deom_tuning()

func configure_enemy(archetype: StringName) -> void:
	enemy_archetype = archetype
	unit_archetype = archetype
	_apply_catalog_definition()
	health = max_health
	_apply_deom_tuning()
	queue_redraw()

func _apply_deom_tuning() -> void:
	match unit_archetype:
		&"deom_scout":
			move_speed = 178.0
			selection_radius = 15.0
			collision_separation = 17.0
		&"deom_blade":
			move_speed = 132.0
			selection_radius = 18.0
			collision_separation = 21.0
		&"deom_crosshirran":
			move_speed = 118.0
			selection_radius = 18.0
			collision_separation = 20.0
		&"deom_hammer":
			move_speed = 92.0
			selection_radius = 26.0
			collision_separation = 30.0
		&"deom_glaive":
			move_speed = 158.0
			selection_radius = 22.0
			collision_separation = 24.0
		&"deom_odden":
			move_speed = 78.0
			selection_radius = 42.0
			collision_separation = 48.0
		_:
			move_speed = 120.0
			selection_radius = 18.0
			collision_separation = 20.0

func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var cloth := Color("#B79655")
	var metal := Color("#74746C")
	var dark := Color("#2B2924")
	var glow := team_accent_color()
	match unit_archetype:
		&"deom_scout":
			_draw_scout(cloth, dark, glow)
		&"deom_blade":
			_draw_blade(cloth, metal, dark, glow)
		&"deom_crosshirran":
			_draw_crosshirran(cloth, metal, dark, glow)
		&"deom_hammer":
			_draw_hammer(cloth, metal, dark, glow)
		&"deom_glaive":
			_draw_glaive(cloth, metal, dark, glow)
		&"deom_odden":
			_draw_odden(cloth, metal, dark, glow)
		_:
			_draw_scout(cloth, dark, glow)
	_draw_unit_transform_end()
	_draw_selection_and_path()

func _draw_scout(cloth: Color, dark: Color, glow: Color) -> void:
	draw_circle(Vector2(0, 12), 12, Color(0, 0, 0, 0.26))
	draw_line(Vector2(0, 8), Vector2(0, -14), dark, 5.0)
	draw_circle(Vector2(0, -20), 13, dark.lightened(0.1))
	draw_circle(Vector2(-4, -22), 3.4, glow)
	draw_circle(Vector2(4, -22), 3.4, glow)
	draw_line(Vector2(-5, 0), Vector2(-20, -7), cloth, 3.0)
	draw_line(Vector2(5, 0), Vector2(22, -9), cloth, 3.0)
	draw_line(Vector2(14, -7), Vector2(30, -13), glow, 2.0)

func _draw_blade(cloth: Color, metal: Color, dark: Color, glow: Color) -> void:
	draw_circle(Vector2(0, 14), 15, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(Vector2(-9, -7), Vector2(18, 27)), dark.lightened(0.08), true)
	draw_circle(Vector2(0, -18), 14, dark.lightened(0.12))
	draw_circle(Vector2(-4, -20), 3.5, glow)
	draw_circle(Vector2(4, -20), 3.5, glow)
	draw_line(Vector2(9, 0), Vector2(31, -25), metal.lightened(0.2), 5.0)
	draw_line(Vector2(9, 0), Vector2(31, -25), glow, 1.5)
	draw_line(Vector2(-8, 4), Vector2(-20, 17), cloth.darkened(0.2), 4.0)

func _draw_crosshirran(cloth: Color, metal: Color, dark: Color, glow: Color) -> void:
	draw_circle(Vector2(0, 14), 14, Color(0, 0, 0, 0.28))
	draw_rect(Rect2(Vector2(-8, -4), Vector2(16, 24)), dark, true)
	draw_circle(Vector2(0, -17), 13, dark.lightened(0.08))
	draw_circle(Vector2(-4, -19), 3.2, glow)
	draw_circle(Vector2(4, -19), 3.2, glow)
	draw_line(Vector2(-18, -3), Vector2(24, -10), metal, 4.0)
	draw_line(Vector2(8, -8), Vector2(34, -16), glow, 2.0)
	draw_line(Vector2(-4, 16), Vector2(-13, 27), cloth.darkened(0.25), 4.0)

func _draw_hammer(cloth: Color, metal: Color, dark: Color, glow: Color) -> void:
	draw_circle(Vector2(0, 18), 23, Color(0, 0, 0, 0.34))
	draw_rect(Rect2(Vector2(-16, -9), Vector2(32, 36)), metal.darkened(0.12), true)
	draw_circle(Vector2(0, -24), 18, metal.darkened(0.18))
	draw_circle(Vector2(-6, -27), 4.0, glow)
	draw_circle(Vector2(6, -24), 4.0, glow)
	draw_line(Vector2(17, 1), Vector2(39, -25), metal.lightened(0.1), 7.0)
	draw_rect(Rect2(Vector2(34, -36), Vector2(22, 16)), metal.darkened(0.05), true)
	draw_arc(Vector2(0, 2), 25.0, -0.8, 2.7, 22, Color(glow.r, glow.g, glow.b, 0.55), 3.0)
	draw_line(Vector2(-12, 22), Vector2(-18, 36), cloth.darkened(0.3), 5.0)

func _draw_glaive(cloth: Color, metal: Color, dark: Color, glow: Color) -> void:
	draw_circle(Vector2(0, 15), 18, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(Vector2(-11, -7), Vector2(22, 29)), metal.darkened(0.08), true)
	draw_circle(Vector2(0, -21), 15, metal.darkened(0.16))
	draw_circle(Vector2(-5, -23), 3.8, glow)
	draw_circle(Vector2(5, -21), 3.8, glow)
	draw_line(Vector2(-27, 16), Vector2(33, -22), metal.lightened(0.05), 5.0)
	draw_arc(Vector2(35, -23), 16.0, 1.9, 5.3, 18, glow, 3.0)
	draw_line(Vector2(-9, 20), Vector2(-20, 33), cloth.darkened(0.25), 4.0)

func _draw_odden(cloth: Color, metal: Color, dark: Color, glow: Color) -> void:
	draw_circle(Vector2(0, 26), 42, Color(0, 0, 0, 0.22))
	_draw_body_ellipse(Rect2(Vector2(-52, -42), Vector2(104, 62)), metal.darkened(0.12))
	draw_arc(Vector2.ZERO, 53.0, 0.0, TAU, 48, dark.lightened(0.2), 3.0)
	draw_circle(Vector2(-24, -12), 9.0, glow)
	draw_circle(Vector2(18, -16), 8.0, glow)
	draw_rect(Rect2(Vector2(-31, 10), Vector2(62, 23)), cloth.darkened(0.22), true)
	draw_line(Vector2(-42, 0), Vector2(-62, 15), metal, 3.0)
	draw_line(Vector2(42, 0), Vector2(64, 13), metal, 3.0)
	draw_circle(Vector2(-44, 34), 8.0, dark.lightened(0.1))
	draw_circle(Vector2(44, 34), 8.0, dark.lightened(0.1))

func _draw_body_ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius := rect.size * 0.5
	for i in 48:
		var angle := TAU * float(i) / 48.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
