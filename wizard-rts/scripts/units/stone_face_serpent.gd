extends RTSUnit

const STONE_WALL_VISUAL_SCRIPT := preload("res://scripts/units/serpent_stone_wall_visual.gd")
const STONE_WALL_SEGMENT_SCRIPT := preload("res://scripts/units/serpent_stone_wall_segment.gd")

var _stone_targeting := false
var _stone_dragging := false
var _stone_drag_start := Vector2i.ZERO
var _stone_drag_end := Vector2i.ZERO
var _pending_stone_cells: Array[Vector2i] = []
var _stone_cells: Array[Vector2i] = []
var _stone_cast_remaining := 0.0
var _stone_cooldown_remaining := 0.0
var _stone_form_active := false
var _stone_wall_visual: Node2D
var _stone_wall_segments: Array[Node2D] = []
var _registered_as_world_unit := true

func _ready() -> void:
	unit_archetype = &"stone_face_serpent"
	super()
	move_speed = 118.0
	selection_radius = 30.0
	collision_separation = 34.0
	_apply_growth_stats()

func _exit_tree() -> void:
	_release_stone_form()
	super()

func _physics_process(delta: float) -> void:
	_update_stone_form(delta)
	if _stone_form_active or _stone_cast_remaining > 0.0:
		velocity = Vector2.ZERO
		moving = false
		return
	super(delta)

func _process(delta: float) -> void:
	_stone_cooldown_remaining = maxf(0.0, _stone_cooldown_remaining - delta)
	if _stone_targeting or _stone_dragging or _stone_form_active:
		queue_redraw()
	super(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _stone_targeting or not selected or terrain == null or not is_instance_valid(terrain):
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_stone_targeting()
			get_viewport().set_input_as_handled()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			var cell := _mouse_cell()
			if mouse_button.pressed:
				_stone_dragging = true
				_stone_drag_start = cell
				_stone_drag_end = cell
				get_viewport().set_input_as_handled()
			elif _stone_dragging:
				_stone_drag_end = cell
				_begin_stone_cast(_line_cells(_stone_drag_start, _stone_drag_end, _stone_length()))
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _stone_dragging:
		_stone_drag_end = _mouse_cell()

func activate_stone_form() -> bool:
	if _stone_form_active:
		return activate_revert_stone_form()
	if _stone_cooldown_remaining > 0.0 or _stone_cast_remaining > 0.0:
		return false
	_stone_targeting = true
	_stone_dragging = false
	moving = false
	path.clear()
	unit_state = &"stone_targeting"
	_set_ability_animation(&"stone_cast", 0.4)
	return true

func activate_revert_stone_form() -> bool:
	if not _stone_form_active:
		return false
	_release_stone_form()
	var definition := UnitCatalog.get_definition(unit_archetype)
	_stone_cooldown_remaining = float(definition.get("stone_form_cooldown_seconds", 10.0))
	unit_state = &"idle"
	_set_ability_animation(&"revert_stone", 0.45)
	queue_redraw()
	return true

func rts_combat_tick(delta: float, nearby_units: Array[Node2D]) -> void:
	if _stone_form_active or _stone_cast_remaining > 0.0 or _stone_targeting:
		return
	super(delta, nearby_units)

func take_damage(amount: int, source: Node = null, damage_type: StringName = &"physical") -> void:
	super(amount, source, damage_type)
	if _stone_wall_visual != null and is_instance_valid(_stone_wall_visual):
		_stone_wall_visual.queue_redraw()

func heal_damage(amount: int) -> void:
	super(amount)
	if _stone_wall_visual != null and is_instance_valid(_stone_wall_visual):
		_stone_wall_visual.queue_redraw()

func _fire_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	super(target, damage_multiplier)
	if target != null and is_instance_valid(target) and target.has_method("apply_poison"):
		var definition := UnitCatalog.get_definition(unit_archetype)
		target.apply_poison(
			self,
			float(definition.get("poison_damage_per_second", 5.0)),
			float(definition.get("poison_duration_seconds", 4.0))
		)

func _blocks_movement_for_rooting() -> bool:
	return _stone_form_active or _stone_cast_remaining > 0.0 or super()

func _gain_evolution_xp(amount: float) -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var max_level := int(definition.get("max_evolution_level", 5))
	var needed := float(definition.get("evolution_xp_required", 0.0))
	if needed <= 0.0 or evolution_level >= max_level:
		return
	evolution_xp += amount
	while evolution_xp >= needed and evolution_level < max_level:
		evolution_xp -= needed
		_evolve(definition)
	if evolution_level >= max_level:
		evolution_xp = 0.0

func _evolve(definition: Dictionary) -> void:
	evolution_level += 1
	_apply_growth_stats()
	health = max_health
	_set_ability_animation(&"evolve_growth", 1.0)
	_queue_unit_redraw(true)

func get_evolution_progress() -> Dictionary:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var max_level := int(definition.get("max_evolution_level", 5))
	return {
		"xp": evolution_xp,
		"needed": 0.0 if evolution_level >= max_level else float(definition.get("evolution_xp_required", 0.0)),
		"level": evolution_level,
		"evolves_to": &"extra_tile" if evolution_level < max_level else &"",
	}

func _update_stone_form(delta: float) -> void:
	if _stone_cast_remaining <= 0.0:
		return
	_stone_cast_remaining = maxf(0.0, _stone_cast_remaining - delta)
	velocity = Vector2.ZERO
	moving = false
	path.clear()
	unit_state = &"stone_casting"
	if _stone_cast_remaining <= 0.0:
		_enter_stone_form(_pending_stone_cells)

func _begin_stone_cast(cells: Array[Vector2i]) -> void:
	if cells.is_empty() or not _stone_cells_are_valid(cells):
		_cancel_stone_targeting()
		return
	_pending_stone_cells = cells.duplicate()
	_stone_targeting = false
	_stone_dragging = false
	var definition := UnitCatalog.get_definition(unit_archetype)
	_stone_cast_remaining = float(definition.get("stone_form_cast_seconds", 2.0))
	moving = false
	path.clear()
	unit_state = &"stone_casting"
	_set_ability_animation(&"stone_cast", _stone_cast_remaining)

func _enter_stone_form(cells: Array[Vector2i]) -> void:
	if cells.is_empty() or not _stone_cells_are_valid(cells):
		unit_state = &"idle"
		return
	_stone_cells = cells.duplicate()
	_stone_form_active = true
	attack_target = null
	command_mode = &"hold"
	global_position = _cell_world(_stone_cells[0])
	target_pos = global_position
	_command_destination = global_position
	_has_command_destination = false
	if rts_world != null and is_instance_valid(rts_world) and _registered_as_world_unit:
		rts_world.unregister_unit(self)
		_registered_as_world_unit = false
	if terrain != null and is_instance_valid(terrain) and terrain.has_method("add_dynamic_blockers"):
		terrain.add_dynamic_blockers(_stone_cells)
	_make_stone_visual()
	_make_stone_segments()
	unit_state = &"stone_form"
	_set_ability_animation(&"stone_idle", 0.6)
	queue_redraw()

func _release_stone_form() -> void:
	_clear_stone_segments()
	if terrain != null and is_instance_valid(terrain) and terrain.has_method("remove_dynamic_blockers") and not _stone_cells.is_empty():
		terrain.remove_dynamic_blockers(_stone_cells)
	_stone_cells.clear()
	_pending_stone_cells.clear()
	_stone_form_active = false
	_stone_cast_remaining = 0.0
	_stone_targeting = false
	_stone_dragging = false
	if _stone_wall_visual != null and is_instance_valid(_stone_wall_visual):
		_stone_wall_visual.queue_free()
	_stone_wall_visual = null
	if rts_world != null and is_instance_valid(rts_world) and not _registered_as_world_unit and not _dying:
		rts_world.register_unit(self)
		_registered_as_world_unit = true

func _cancel_stone_targeting() -> void:
	_stone_targeting = false
	_stone_dragging = false
	_pending_stone_cells.clear()
	unit_state = &"idle"
	queue_redraw()

func _make_stone_visual() -> void:
	if get_parent() == null:
		return
	if _stone_wall_visual != null and is_instance_valid(_stone_wall_visual):
		_stone_wall_visual.queue_free()
	_stone_wall_visual = STONE_WALL_VISUAL_SCRIPT.new()
	get_parent().add_child(_stone_wall_visual)
	_stone_wall_visual.configure(_stone_cells, terrain, owner_player_id, self)

func _make_stone_segments() -> void:
	_clear_stone_segments()
	if get_parent() == null:
		return
	for cell in _stone_cells:
		var segment: Node2D = STONE_WALL_SEGMENT_SCRIPT.new()
		segment.global_position = _cell_world(cell)
		segment.configure(self, owner_player_id)
		get_parent().add_child(segment)
		_stone_wall_segments.append(segment)
		if rts_world != null and is_instance_valid(rts_world):
			rts_world.register_structure(segment)

func _clear_stone_segments() -> void:
	for segment in _stone_wall_segments:
		if segment != null and is_instance_valid(segment):
			if rts_world != null and is_instance_valid(rts_world):
				rts_world.unregister_structure(segment)
			segment.queue_free()
	_stone_wall_segments.clear()

func _stone_cells_are_valid(cells: Array[Vector2i]) -> bool:
	if terrain == null or not is_instance_valid(terrain):
		return false
	for cell in cells:
		if terrain.has_method("is_walkable_cell") and not bool(terrain.call("is_walkable_cell", cell)):
			return false
	return true

func _line_cells(start: Vector2i, end: Vector2i, max_length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := end - start
	var step := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	if step == Vector2i.ZERO:
		step = Vector2i(1, 0)
	for i in range(maxi(1, max_length)):
		cells.append(start + step * i)
	return cells

func _stone_length() -> int:
	var definition := UnitCatalog.get_definition(unit_archetype)
	return int(definition.get("stone_form_base_length", 1)) + maxi(0, evolution_level - 1)

func _apply_growth_stats() -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var growth := maxi(0, evolution_level - 1)
	max_health = int(definition.get("max_hp", max_health)) + int(definition.get("growth_hp_bonus", 58)) * growth
	health = mini(max_health, max(health, 1))
	attack_damage = int(definition.get("attack_damage", attack_damage)) + int(definition.get("growth_damage_bonus", 5)) * growth
	attack_range = (float(definition.get("attack_range_cells", 2.0)) + float(definition.get("growth_range_cells_bonus", 0.35)) * float(growth)) * 64.0
	var size_bonus := float(definition.get("growth_size_bonus", 3.0)) * float(growth)
	selection_radius = 30.0 + size_bonus
	collision_separation = 34.0 + size_bonus

func _mouse_cell() -> Vector2i:
	if terrain != null and is_instance_valid(terrain) and terrain.has_method("world_to_cell"):
		return terrain.call("world_to_cell", get_global_mouse_position())
	return Vector2i(roundi(get_global_mouse_position().x / 64.0), roundi(get_global_mouse_position().y / 64.0))

func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var body := team_secondary_color().darkened(0.12)
	var stone := Color("#6F8587")
	var glow := team_accent_color()
	var growth_scale := 1.0 + float(evolution_level - 1) * 0.09
	draw_circle(Vector2(0, 17) * growth_scale, 27.0 * growth_scale, Color(0, 0, 0, 0.3))
	if _stone_form_active:
		if selected:
			_draw_stone_anchor(glow, growth_scale)
	else:
		_draw_serpent_body(body, stone, glow, growth_scale)
	_draw_unit_transform_end()
	_draw_stone_preview()
	_draw_selection_and_path()

func _draw_serpent_body(body: Color, stone: Color, glow: Color, growth_scale: float) -> void:
	var points := PackedVector2Array([
		Vector2(-26, 14), Vector2(-15, -2), Vector2(4, -8), Vector2(25, -4),
		Vector2(35, 8), Vector2(20, 20), Vector2(-4, 18), Vector2(-22, 27)
	])
	for i in range(points.size()):
		points[i] *= growth_scale
	draw_colored_polygon(points, stone)
	draw_arc(Vector2(-10, 8) * growth_scale, 22.0 * growth_scale, 2.6, 6.2, 24, body, 6.0 * growth_scale)
	draw_circle(Vector2(23, -5) * growth_scale, 13.0 * growth_scale, stone.lightened(0.08))
	draw_circle(Vector2(27, -8) * growth_scale, 3.2 * growth_scale, glow)
	draw_line(Vector2(-18, 5) * growth_scale, Vector2(20, -1) * growth_scale, Color(glow.r, glow.g, glow.b, 0.72), 2.0 * growth_scale)
	draw_line(Vector2(-4, 15) * growth_scale, Vector2(27, 6) * growth_scale, Color(glow.r, glow.g, glow.b, 0.52), 1.8 * growth_scale)

func _draw_stone_anchor(glow: Color, growth_scale: float) -> void:
	draw_circle(Vector2.ZERO, 8.0 * growth_scale, Color(glow.r, glow.g, glow.b, 0.28))
	draw_circle(Vector2.ZERO, 4.0 * growth_scale, glow)

func _draw_stone_preview() -> void:
	if not _stone_targeting or terrain == null or not is_instance_valid(terrain):
		return
	var cells: Array[Vector2i] = []
	if _stone_dragging:
		cells = _line_cells(_stone_drag_start, _stone_drag_end, _stone_length())
	else:
		cells.append(_mouse_cell())
	var valid := _stone_cells_are_valid(cells)
	var fill := Color(0.35, 0.85, 0.75, 0.32) if valid else Color(0.9, 0.12, 0.12, 0.34)
	var line := Color("#7DDDE8") if valid else Color("#E85A5A")
	for cell in cells:
		var local := to_local(_cell_world(cell))
		var rect := Rect2(local - Vector2(31, 23), Vector2(62, 46))
		draw_rect(rect, fill, true)
		draw_rect(rect, line, false, 2.0)

func _cell_world(cell: Vector2i) -> Vector2:
	if terrain != null and is_instance_valid(terrain) and terrain.has_method("cell_to_world"):
		return terrain.call("cell_to_world", cell)
	return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

func signi(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0
