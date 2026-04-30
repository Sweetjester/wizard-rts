class_name KonStructure
extends StaticBody2D

const STRUCTURE_TEXTURES := {
	&"wizard_tower": preload("res://assets/buildings/kon/wizard_tower.png"),
	&"bio_absorber": preload("res://assets/buildings/kon/bio_absorber.png"),
	&"barracks": preload("res://assets/buildings/kon/barracks.png"),
	&"terrible_vault": preload("res://assets/buildings/kon/terrible_vault.png"),
	&"vinewall": preload("res://assets/buildings/kon/vinewall_segment.png"),
	&"bio_launcher": preload("res://assets/buildings/kon/bio_launcher_rooted.png"),
}
const USE_PLACEHOLDER_FOOTPRINT_ART := true

var archetype: StringName = &"bio_absorber"
var owner_player_id: int = 1
var level: int = 1
var footprint: Vector2i = Vector2i.ONE
var cell: Vector2i = Vector2i.ZERO
var selection_radius: float = 48.0
var max_health: int = 200
var health: int = 200
var attack_damage: int = 0
var attack_range: float = 0.0
var build_progress: float = 0.0
var build_time: float = 0.0
var complete: bool = true
var production_queue_count: int = 0
var training_archetype: StringName = &""
var training_progress: float = 0.0
var training_time: float = 0.0
var rally_point := Vector2.ZERO
var rally_enabled := false
var attack_flash_msec: int = -10000
var selected := false
var art_sprite: Sprite2D
var rts_world: RTSWorld

func _ready() -> void:
	rts_world = get_node_or_null("../RTSWorld")
	if rts_world != null:
		rts_world.register_structure(self)
	if art_sprite != null and is_instance_valid(art_sprite):
		art_sprite.position = _art_position(art_sprite.texture, art_sprite.scale)

func _exit_tree() -> void:
	if rts_world != null and is_instance_valid(rts_world):
		rts_world.unregister_structure(self)

func configure(new_archetype: StringName, new_cell: Vector2i, new_footprint: Vector2i) -> void:
	collision_layer = 0
	collision_mask = 0
	archetype = new_archetype
	cell = new_cell
	footprint = new_footprint
	selection_radius = maxf(34.0, maxf(float(footprint.x) * 38.0, float(footprint.y) * 32.0))
	name = "%s_%s_%s" % [str(archetype), cell.x, cell.y]
	z_as_relative = false
	add_to_group("selectable_units")
	add_to_group("structures")
	add_to_group("units")
	_build_collision()
	_build_art_sprite()
	queue_redraw()

func set_runtime_stats(player_id: int, hp: int, max_hp: int, new_level: int = 1) -> void:
	owner_player_id = player_id
	health = hp
	max_health = max_hp
	level = new_level
	var definition := UnitCatalog.get_definition(archetype)
	attack_damage = int(definition.get("attack_damage", 0))
	attack_range = float(definition.get("attack_range_cells", 0)) * 64.0
	queue_redraw()

func set_level(value: int) -> void:
	level = value
	queue_redraw()

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func is_inside_selection_rect(rect: Rect2) -> bool:
	var size := Vector2(72.0 * float(footprint.x), 56.0 * float(footprint.y))
	return rect.intersects(Rect2(global_position - size * 0.5 + Vector2(0, -16), size))

func get_display_name() -> String:
	return str(UnitCatalog.get_definition(archetype).get("display_name", str(archetype)))

func get_selection_kind() -> StringName:
	return &"structure"

func set_construction_state(progress: float, total_time: float, is_complete: bool) -> void:
	build_progress = progress
	build_time = total_time
	complete = is_complete
	queue_redraw()

func set_training_state(queue_count: int, current_archetype: StringName, progress: float, total_time: float) -> void:
	production_queue_count = queue_count
	training_archetype = current_archetype
	training_progress = progress
	training_time = total_time
	queue_redraw()

func set_rally_point(point: Vector2) -> void:
	rally_point = point
	rally_enabled = true
	queue_redraw()

func get_rally_point() -> Vector2:
	return rally_point

func has_rally_point() -> bool:
	return rally_enabled

func take_damage(amount: int, source: Node = null) -> void:
	var actual_damage: int = mini(amount, health)
	if rts_world != null and is_instance_valid(rts_world):
		rts_world.record_damage(source, self, actual_damage)
	health = maxi(0, health - amount)
	if archetype == &"vinewall" and source != null and is_instance_valid(source) and source.has_method("take_damage"):
		var retaliation := int(UnitCatalog.get_definition(&"vinewall").get("retaliation_damage", 8)) + level * 2
		source.take_damage(retaliation, self)
		attack_flash_msec = Time.get_ticks_msec()
	queue_redraw()
	if health <= 0:
		queue_free()

func heal_damage(amount: int) -> void:
	health = mini(max_health, health + amount)
	queue_redraw()

func _build_collision() -> void:
	for child in get_children():
		child.queue_free()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(58.0 * float(footprint.x), 34.0 * float(footprint.y))
	var collision := CollisionShape2D.new()
	collision.position = Vector2.ZERO
	collision.disabled = true
	collision.shape = shape
	add_child(collision)

func _build_art_sprite() -> void:
	if USE_PLACEHOLDER_FOOTPRINT_ART:
		return
	if art_sprite != null and is_instance_valid(art_sprite):
		art_sprite.queue_free()
	if not STRUCTURE_TEXTURES.has(archetype):
		return
	art_sprite = Sprite2D.new()
	art_sprite.texture = STRUCTURE_TEXTURES[archetype]
	art_sprite.centered = true
	art_sprite.scale = _art_scale()
	art_sprite.position = _art_position(art_sprite.texture, art_sprite.scale)
	add_child(art_sprite)

func _draw() -> void:
	var color := _main_color()
	var draw_color := color if complete else color.darkened(0.38)
	_draw_footprint_base()
	if art_sprite == null:
		if USE_PLACEHOLDER_FOOTPRINT_ART:
			_draw_placeholder_structure(draw_color)
		else:
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
	elif not str(training_archetype).is_empty():
		_draw_training_overlay()
	if attack_flash_msec > 0 and float(Time.get_ticks_msec() - attack_flash_msec) / 1000.0 < 0.24:
		_draw_attack_flash()
	_draw_selection()
	_draw_health_bar()
	_draw_level_badge()
	_draw_rally_point()

func _draw_selection() -> void:
	if not selected:
		return
	for cell in _footprint_local_cells():
		var points := _cell_polygon_local(cell)
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_colored_polygon(points, Color("#7DDDE8", 0.12))
		draw_polyline(outline, Color("#7DDDE8", 0.9), 2.5)

func _draw_health_bar() -> void:
	var ratio := 1.0
	if max_health > 0:
		ratio = clampf(float(health) / float(max_health), 0.0, 1.0)
	var width := maxf(48.0, 52.0 * float(footprint.x))
	var y := -76.0
	var fill := Color("#7BC47F") if owner_player_id == 1 else Color("#C13030")
	if not complete:
		fill = Color("#7DDDE8")
	draw_rect(Rect2(Vector2(-width * 0.5 - 1.0, y - 1.0), Vector2(width + 2.0, 6.0)), Color("#0A1612", 0.88), true)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 4.0)), fill, true)

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

func _draw_training_overlay() -> void:
	var width := maxf(54.0, 48.0 * float(footprint.x))
	var progress := 0.0
	if training_time > 0.0:
		progress = clampf(training_progress / training_time, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-width * 0.5, 36), Vector2(width, 5)), Color("#0A1612", 0.82), true)
	draw_rect(Rect2(Vector2(-width * 0.5, 36), Vector2(width * progress, 5)), Color("#7BC47F", 0.95), true)
	if production_queue_count > 0:
		draw_string(ThemeDB.fallback_font, Vector2(width * 0.5 + 5, 41), "+%s" % production_queue_count, HORIZONTAL_ALIGNMENT_LEFT, 32.0, 11, Color("#D6C7AE"))

func _draw_attack_flash() -> void:
	var alpha := 1.0 - clampf(float(Time.get_ticks_msec() - attack_flash_msec) / 240.0, 0.0, 1.0)
	draw_arc(Vector2(0, 8), selection_radius * 0.7, 0.2, PI - 0.2, 28, Color("#E85A5A", alpha), 4.0)

func _draw_rally_point() -> void:
	if not selected or not rally_enabled:
		return
	var local := to_local(rally_point)
	draw_line(Vector2(0, 12), local, Color("#7DDDE8", 0.65), 2.0)
	draw_circle(local, 6.0, Color("#7DDDE8", 0.85))

func _draw_flat_ellipse(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := float(i) * TAU / 24.0
		points.append(center + Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5))
	draw_colored_polygon(points, color)

func _draw_footprint_base() -> void:
	for local_cell in _footprint_local_cells():
		var points := _cell_polygon_local(local_cell)
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_colored_polygon(points, Color("#332820", 0.55))
		draw_polyline(outline, Color("#D6C7AE", 0.42), 1.6)

func _draw_placeholder_structure(color: Color) -> void:
	var top_offset := Vector2(0, -22.0 - float(footprint.x + footprint.y) * 2.0)
	for local_cell in _footprint_local_cells():
		var base := _cell_polygon_local(local_cell)
		var top := PackedVector2Array()
		for point in base:
			top.append(point + top_offset)
		draw_colored_polygon(base, color.darkened(0.45))
		draw_colored_polygon(top, color)
		for i in base.size():
			var next := (i + 1) % base.size()
			draw_line(base[i], top[i], color.darkened(0.35), 2.0)
			draw_line(top[i], top[next], color.lightened(0.15), 2.0)
	var label := _placeholder_label()
	draw_string(ThemeDB.fallback_font, Vector2(-24, top_offset.y - 8), label, HORIZONTAL_ALIGNMENT_CENTER, 48.0, 13, Color("#F0E7D0"))

func _placeholder_label() -> String:
	match archetype:
		&"wizard_tower":
			return "HQ"
		&"bio_absorber":
			return "BIO"
		&"barracks":
			return "BAR"
		&"terrible_vault":
			return "VLT"
		&"vinewall":
			return "W"
		&"bio_launcher":
			return "BL"
	return "B"

func _footprint_local_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in footprint.x:
		for y in footprint.y:
			cells.append(Vector2i(x, y))
	return cells

func _footprint_boundary_segments(cells: Array[Vector2i]) -> Array[Array]:
	var occupied := {}
	for local_cell in cells:
		occupied[local_cell] = true
	var segments: Array[Array] = []
	for local_cell in cells:
		var points := _cell_polygon_local(local_cell)
		if not occupied.has(local_cell + Vector2i(0, -1)):
			segments.append([points[0], points[1]])
		if not occupied.has(local_cell + Vector2i(1, 0)):
			segments.append([points[1], points[2]])
		if not occupied.has(local_cell + Vector2i(0, 1)):
			segments.append([points[2], points[3]])
		if not occupied.has(local_cell + Vector2i(-1, 0)):
			segments.append([points[3], points[0]])
	return segments

func _cell_polygon_local(local_cell: Vector2i) -> PackedVector2Array:
	var center := _local_cell_center(local_cell)
	var size := _grid_cell_size()
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

func _local_cell_center(local_cell: Vector2i) -> Vector2:
	var size := _grid_cell_size()
	var average := Vector2(float(footprint.x - 1), float(footprint.y - 1)) * 0.5
	var delta := Vector2(float(local_cell.x), float(local_cell.y)) - average
	return Vector2(delta.x * size.x, delta.y * size.y)

func _grid_cell_size() -> Vector2:
	var map := get_node_or_null("../MapGenerator")
	if map != null:
		var map_type := str(map.get("map_type_id"))
		if map_type == "seeded_grid_frontier" or map_type == "grid_test_canvas" or map_type == "ai_testing_ground" or map_type == "fortress_ai_arena":
			return Vector2(64, 64)
	return Vector2(111, 55)

func _footprint_bottom_y() -> float:
	var bottom := -INF
	for local_cell in _footprint_local_cells():
		for point in _cell_polygon_local(local_cell):
			bottom = maxf(bottom, point.y)
	return bottom

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

func _art_position(texture: Texture2D, scale: Vector2) -> Vector2:
	var scaled_height := float(texture.get_height()) * scale.y
	return Vector2(0, _footprint_bottom_y() - scaled_height * 0.5 + 6.0)

func _art_scale() -> Vector2:
	if not STRUCTURE_TEXTURES.has(archetype):
		return Vector2.ONE
	var texture: Texture2D = STRUCTURE_TEXTURES[archetype]
	var target_width := maxf(54.0, float(footprint.x + footprint.y) * _grid_cell_size().x * 0.24)
	var scale := target_width / maxf(1.0, float(texture.get_width()))
	if archetype == &"vinewall":
		scale *= 0.82
	return Vector2(scale, scale)
