class_name KonStructure
extends StaticBody2D

var archetype: StringName = &"bio_absorber"
var level: int = 1
var footprint: Vector2i = Vector2i.ONE
var cell: Vector2i = Vector2i.ZERO
var build_progress: float = 0.0
var build_time: float = 0.0
var complete: bool = true

func configure(new_archetype: StringName, new_cell: Vector2i, new_footprint: Vector2i) -> void:
	archetype = new_archetype
	cell = new_cell
	footprint = new_footprint
	name = "%s_%s_%s" % [String(archetype), cell.x, cell.y]
	z_as_relative = false
	_build_collision()
	queue_redraw()

func set_level(value: int) -> void:
	level = value
	queue_redraw()

func set_construction_state(progress: float, total_time: float, is_complete: bool) -> void:
	build_progress = progress
	build_time = total_time
	complete = is_complete
	queue_redraw()

func _build_collision() -> void:
	for child in get_children():
		child.queue_free()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72.0 * float(footprint.x), 48.0 * float(footprint.y))
	var collision := CollisionShape2D.new()
	collision.position = Vector2(0, -16)
	collision.shape = shape
	add_child(collision)

func _draw() -> void:
	var color := _main_color()
	var draw_color := color if complete else color.darkened(0.38)
	var shadow_size := Vector2(66.0 * float(footprint.x), 22.0 * float(footprint.y))
	_draw_flat_ellipse(Vector2(0, 20), shadow_size, Color(0, 0, 0, 0.36))
	match archetype:
		&"wizard_tower":
			_draw_tower(draw_color)
		&"bio_absorber":
			_draw_absorber(draw_color)
		&"barracks":
			_draw_barracks(draw_color)
		&"terrible_vault":
			_draw_vault(draw_color)
		&"vinewall":
			_draw_vinewall(draw_color)
		&"bio_launcher":
			_draw_launcher(draw_color)
		_:
			_draw_barracks(draw_color)
	if not complete:
		_draw_construction_overlay(color)
	_draw_level_badge()

func _draw_construction_overlay(color: Color) -> void:
	var width := 68.0 * float(footprint.x)
	var progress := 1.0
	if build_time > 0.0:
		progress = clampf(build_progress / build_time, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-width * 0.5, 28), Vector2(width, 6)), Color("#0A1612", 0.86), true)
	draw_rect(Rect2(Vector2(-width * 0.5, 28), Vector2(width * progress, 6)), Color("#7DDDE8", 0.95), true)
	draw_line(Vector2(-width * 0.45, -52), Vector2(width * 0.45, 12), Color("#D6C7AE", 0.72), 3)
	draw_line(Vector2(width * 0.45, -52), Vector2(-width * 0.45, 12), Color("#D6C7AE", 0.72), 3)
	draw_arc(Vector2.ZERO, width * 0.42, 0, TAU, 32, color.lightened(0.2), 2)

func _draw_flat_ellipse(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := float(i) * TAU / 24.0
		points.append(center + Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5))
	draw_colored_polygon(points, color)

func _draw_tower(color: Color) -> void:
	draw_rect(Rect2(Vector2(-24, -82), Vector2(48, 82)), color.darkened(0.25))
	draw_rect(Rect2(Vector2(-16, -96), Vector2(32, 20)), color)
	draw_circle(Vector2(0, -100), 11, Color("#7DDDE8"))
	draw_line(Vector2(-30, -18), Vector2(30, -18), Color("#D6C7AE"), 3)

func _draw_absorber(color: Color) -> void:
	draw_circle(Vector2.ZERO, 28, color.darkened(0.2))
	draw_circle(Vector2(0, -8), 18, color)
	draw_circle(Vector2(0, -8), 8, Color("#7DDDE8"))
	for i in 8:
		var angle := float(i) * TAU / 8.0
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle) * 0.55) * 42.0, color.darkened(0.35), 3)

func _draw_barracks(color: Color) -> void:
	draw_rect(Rect2(Vector2(-42, -42), Vector2(84, 58)), color.darkened(0.22))
	draw_rect(Rect2(Vector2(-34, -54), Vector2(68, 18)), color)
	draw_rect(Rect2(Vector2(-12, -14), Vector2(24, 30)), Color("#0A1612"))
	for x in [-30, 30]:
		draw_circle(Vector2(x, -22), 7, Color("#E85A5A"))

func _draw_vault(color: Color) -> void:
	draw_rect(Rect2(Vector2(-38, -48), Vector2(76, 64)), Color("#1A1410"))
	draw_rect(Rect2(Vector2(-26, -58), Vector2(52, 18)), color)
	draw_arc(Vector2(0, -12), 24, 0, TAU, 32, Color("#7DDDE8"), 3)
	draw_circle(Vector2(0, -12), 8, Color("#0E2C32"))

func _draw_vinewall(color: Color) -> void:
	draw_line(Vector2(-34, 8), Vector2(34, -8), color.darkened(0.35), 9)
	draw_line(Vector2(-30, -4), Vector2(30, 4), color, 7)
	for x in [-24, -8, 10, 26]:
		draw_circle(Vector2(x, -4 + (x % 3) * 3), 6, Color("#7BC47F"))
		draw_line(Vector2(x, -8), Vector2(x + 8, -20), Color("#332820"), 3)

func _draw_launcher(color: Color) -> void:
	draw_circle(Vector2(0, 0), 25, Color("#332820"))
	draw_line(Vector2(-28, 12), Vector2(22, -36), color, 12)
	draw_circle(Vector2(28, -42), 14, Color("#8B1A1F"))
	draw_circle(Vector2(30, -44), 6, Color("#7DDDE8"))
	draw_line(Vector2(-18, 16), Vector2(-36, 34), Color("#5C4838"), 5)
	draw_line(Vector2(18, 16), Vector2(36, 34), Color("#5C4838"), 5)

func _draw_level_badge() -> void:
	draw_circle(Vector2(31, -44), 9, Color("#1A1410"))
	draw_string(ThemeDB.fallback_font, Vector2(25, -38), str(level), HORIZONTAL_ALIGNMENT_CENTER, 12.0, 12, Color("#D6C7AE"))

func _main_color() -> Color:
	match archetype:
		&"wizard_tower":
			return Color("#8A7560")
		&"bio_absorber":
			return Color("#4A8A5C")
		&"barracks":
			return Color("#8B1A1F")
		&"terrible_vault":
			return Color("#3FA8B5")
		&"vinewall":
			return Color("#2D5A3E")
		&"bio_launcher":
			return Color("#C13030")
	return Color("#D6C7AE")
