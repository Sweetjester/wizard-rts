extends RTSUnit

const STONE_WALL_VISUAL_SCRIPT := preload("res://scripts/units/serpent_stone_wall_visual.gd")
const STONE_WALL_SEGMENT_SCRIPT := preload("res://scripts/units/serpent_stone_wall_segment.gd")

var _stone_targeting := false
var _stone_dragging := false
var _stone_drag_start := Vector2i.ZERO
var _stone_drag_end := Vector2i.ZERO
var _stone_drag_cells: Array[Vector2i] = []
var _pending_stone_cells: Array[Vector2i] = []
var _stone_cells: Array[Vector2i] = []
var _stone_cast_remaining := 0.0
var _stone_cooldown_remaining := 0.0
var _stone_form_active := false
var _stone_wall_visual: Node2D
var _stone_wall_segments: Array[Node2D] = []
var _registered_as_world_unit := true
var _stone_preview_3d: Node3D

func _ready() -> void:
	unit_archetype = &"stone_face_serpent"
	super()
	move_speed = 118.0
	selection_radius = 30.0
	collision_separation = 34.0
	_apply_growth_stats()

func _exit_tree() -> void:
	if is_instance_valid(_stone_preview_3d): _stone_preview_3d.queue_free()
	_release_stone_form()
	super()

func _physics_process(delta: float) -> void:
	if _stone_form_active or _stone_cast_remaining > 0.0:
		velocity = Vector2.ZERO
		moving = false
		return
	super(delta)

func _process(delta: float) -> void:
	_update_stone_form(delta)
	if (_stone_form_active or _stone_cast_remaining>0) and not is_banished():
		_update_damage_over_time(delta)
		_update_temporary_status_effects()
	_update_stone_preview_3d()
	_stone_cooldown_remaining = maxf(0.0, _stone_cooldown_remaining - delta)
	if _stone_targeting or _stone_dragging or _stone_form_active:
		queue_redraw()
	super(delta)

func handle_stone_input(event: InputEvent) -> bool:
	if _stone_form_active and selected and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _mouse_cell() in _stone_cells:
		_stone_targeting = true
	if not _stone_targeting or not selected or terrain == null or not is_instance_valid(terrain):
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_stone_targeting()
		return true
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_stone_targeting()
			get_viewport().set_input_as_handled()
			return true
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			var cell := _mouse_cell()
			if mouse_button.pressed:
				_stone_dragging = true
				_stone_drag_start = cell
				_stone_drag_end = cell
				_stone_drag_cells.assign([cell])
				get_viewport().set_input_as_handled()
			elif _stone_dragging:
				_stone_drag_end = cell
				_extend_stone_drag(cell)
				_begin_stone_cast(_drag_wall_cells())
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _stone_dragging:
		_stone_drag_end = _mouse_cell()
		_extend_stone_drag(_stone_drag_end)
	return true

func activate_stone_form() -> bool:
	if _dying or is_banished(): return false
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

func rts_movement_tick(delta: float) -> void:
	# Central movement scheduling must respect hardening too, not only physics.
	if _stone_form_active or _stone_cast_remaining>0.0 or _stone_targeting:
		velocity = Vector2.ZERO
		moving = false
		path.clear()
		return
	super(delta)

func _snap_to_walkable_terrain() -> void:
	# Deferred spawn validation must not eject an owner from its own blockers.
	if _stone_form_active: return
	super()

func take_damage(amount: int, source: Node = null, damage_type: StringName = &"physical") -> void:
	super(amount, source, damage_type)
	if _stone_wall_visual != null and is_instance_valid(_stone_wall_visual):
		_stone_wall_visual.queue_redraw()

func heal_damage(amount: int) -> void:
	super(amount)
	if _stone_wall_visual != null and is_instance_valid(_stone_wall_visual):
		_stone_wall_visual.queue_redraw()

func _fire_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	if _stone_form_active or _stone_cast_remaining > 0.0 or _stone_targeting or _dying: return
	if not is_instance_valid(target): return
	if has_node("ArtSprite"): get_node("ArtSprite").play_attack()
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
	if _dying or is_banished(): return
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
		unit_state = &"stone_form" if _stone_form_active else &"idle"
		return
	if _stone_form_active:
		terrain.remove_dynamic_blockers(_stone_cells)
		_clear_stone_segments()
	_stone_cells = cells.duplicate()
	_stone_form_active = true
	set_meta("hide_unit_billboard",true)
	_apply_growth_stats()
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
	var was_active := _stone_form_active
	_clear_stone_segments()
	if terrain != null and is_instance_valid(terrain) and terrain.has_method("remove_dynamic_blockers") and not _stone_cells.is_empty():
		terrain.remove_dynamic_blockers(_stone_cells)
	_stone_cells.clear()
	_pending_stone_cells.clear()
	_stone_form_active = false
	set_meta("hide_unit_billboard",false)
	if was_active and not _dying: _apply_growth_stats()
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
	unit_state = &"stone_form" if _stone_form_active else &"idle"
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
		segment.set_meta("wall_part",8 if cell!=_stone_cells[0] else 10)
		var index := _stone_cells.find(cell)
		if index>0 and index<_stone_cells.size()-1 and _stone_cells[index]-_stone_cells[index-1]!=_stone_cells[index+1]-_stone_cells[index]: segment.set_meta("wall_part",9)
		if index==_stone_cells.size()-1: segment.set_meta("wall_part",11)
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
	if cells.is_empty() or cells.size() > _stone_length(): return false
	var seen := {}
	var origin: Vector2i = terrain.world_to_cell(global_position)
	var reach := int(UnitCatalog.get_definition(unit_archetype).get("stone_form_placement_range_cells",8))
	if origin.distance_to(cells[0]) > reach: return false
	for i in cells.size():
		var cell := cells[i]
		if seen.has(cell): return false
		seen[cell] = true
		if i>0 and absi(cell.x-cells[i-1].x)+absi(cell.y-cells[i-1].y)!=1: return false
		if terrain.has_method("get_height") and terrain.get_height(cell)!=terrain.get_height(cells[0]): return false
		if cell in _stone_cells: continue
		if terrain.has_method("is_walkable_cell") and not bool(terrain.call("is_walkable_cell", cell)):
			return false
		if is_instance_valid(rts_world):
			for unit in rts_world.query_units(_cell_world(cell),40.0):
				if unit != self and is_instance_valid(unit) and unit.global_position.distance_to(_cell_world(cell))<32.0: return false
	return true

func _update_stone_preview_3d() -> void:
	if not _stone_targeting or not selected:
		if is_instance_valid(_stone_preview_3d): _stone_preview_3d.visible = false
		return
	var view := get_parent().get_node_or_null("Map3DView")
	if not is_instance_valid(view) or not view.has_method("_instance_transform"): return
	if not is_instance_valid(_stone_preview_3d):
		_stone_preview_3d = Node3D.new()
		view.add_child(_stone_preview_3d)
	_stone_preview_3d.visible = true
	var cells := _drag_wall_cells() if _stone_dragging else _line_cells(_mouse_cell(),_mouse_cell(),_stone_length())
	var valid := _stone_cells_are_valid(cells)
	while _stone_preview_3d.get_child_count()<cells.size():
		var tile := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.94,0.18,0.94)
		tile.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tile.material_override = mat
		_stone_preview_3d.add_child(tile)
	for i in _stone_preview_3d.get_child_count():
		var tile := _stone_preview_3d.get_child(i) as MeshInstance3D
		tile.visible = i<cells.size()
		if not tile.visible: continue
		tile.global_transform = view._instance_transform(_cell_world(cells[i]),0.15)
		tile.material_override.albedo_color = Color(0.12,0.9,0.8,0.55) if valid else Color(0.9,0.1,0.2,0.55)

func _line_cells(start: Vector2i, end: Vector2i, max_length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := end - start
	var horizontal_first := absi(delta.x)>=absi(delta.y)
	var first := Vector2i(signi(delta.x),0) if horizontal_first else Vector2i(0,signi(delta.y))
	var second := Vector2i(0,signi(delta.y)) if horizontal_first else Vector2i(signi(delta.x),0)
	var first_length := absi(delta.x) if horizontal_first else absi(delta.y)
	if first == Vector2i.ZERO: first = Vector2i.RIGHT
	if second == Vector2i.ZERO: second = first
	var cursor := start
	for i in maxi(1,max_length):
		cells.append(cursor)
		cursor += first if i<first_length else second
	return cells

func _extend_stone_drag(target: Vector2i) -> void:
	if _stone_drag_cells.is_empty(): _stone_drag_cells.append(_stone_drag_start)
	if target in _stone_drag_cells:
		_stone_drag_cells.resize(_stone_drag_cells.find(target)+1)
		return
	while _stone_drag_cells.size()<_stone_length() and _stone_drag_cells.back()!=target:
		var from: Vector2i = _stone_drag_cells.back()
		var delta := target-from
		var step := Vector2i(signi(delta.x),0) if absi(delta.x)>=absi(delta.y) else Vector2i(0,signi(delta.y))
		if from+step in _stone_drag_cells: break
		_stone_drag_cells.append(from+step)

func _drag_wall_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = _stone_drag_cells.duplicate()
	if result.size()<2: return _line_cells(_stone_drag_start,_stone_drag_end,_stone_length())
	var step: Vector2i = result[-1]-result[-2]
	while result.size()<_stone_length(): result.append(result[-1]+step)
	return result

func _stone_length() -> int:
	var definition := UnitCatalog.get_definition(unit_archetype)
	return int(definition.get("stone_form_base_length", 1)) + maxi(0, evolution_level - 1)

func _apply_growth_stats() -> void:
	var definition := UnitCatalog.get_definition(unit_archetype)
	var growth := maxi(0, evolution_level - 1)
	var hp_ratio := float(health)/maxf(1,max_health)
	max_health = int(definition.get("max_hp", max_health)) + int(definition.get("growth_hp_bonus", 58)) * growth
	armor = int(definition.get("armor",5))
	if _stone_form_active:
		max_health = roundi(max_health*(float(definition.get("stone_form_hp_multiplier",2.0))+growth*float(definition.get("stone_form_growth_hp_multiplier",0.2))))
		armor += int(definition.get("stone_form_armor_bonus",8))+growth*int(definition.get("stone_form_growth_armor_bonus",3))
	health = clampi(roundi(max_health*hp_ratio),1,max_health)
	attack_damage = int(definition.get("attack_damage", attack_damage)) + int(definition.get("growth_damage_bonus", 5)) * growth
	attack_range = maxf(0.75,float(definition.get("attack_range_cells", 2.0)) + float(definition.get("growth_range_cells_bonus", -0.25)) * float(growth)) * 64.0
	if _stone_form_active: attack_damage = 0
	var size_bonus := float(definition.get("growth_size_bonus", 3.0)) * float(growth)
	selection_radius = 30.0 + size_bonus
	collision_separation = 34.0 + size_bonus

func _mouse_cell() -> Vector2i:
	var view := get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and view.has_method("screen_to_sim_position"):
		return terrain.world_to_cell(view.screen_to_sim_position(get_viewport().get_mouse_position()))
	if terrain != null and is_instance_valid(terrain) and terrain.has_method("world_to_cell"):
		return terrain.call("world_to_cell", get_global_mouse_position())
	return Vector2i(roundi(get_global_mouse_position().x / 64.0), roundi(get_global_mouse_position().y / 64.0))

func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_stone_preview()
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

# Redrawn 2026-08-31 against the KoN roster doc's concept art: a segmented,
# stone-plated serpent in the evolution palette -- cyan plates with #a95766
# showing through the seams, a heavy plated skull with one rose eye, and the
# translucent wings from the concept sheet. Every segment scales with
# growth_scale so the doc's "increases its length" evolution reads visually.
func _draw_serpent_body(body: Color, stone: Color, glow: Color, growth_scale: float) -> void:
	var plate := team_primary_color()
	var seam := team_accent_color()
	var segments := 5 + mini(evolution_level - 1, 4)
	# Wings first so the body sits over them.
	_draw_serpent_wings(plate, growth_scale)
	# Tail -> head along a shallow S, each segment a plated disc.
	var head_position := Vector2(26, -6) * growth_scale
	for i in range(segments):
		var t := float(i) / float(maxi(1, segments - 1))
		var along: float = lerp(-30.0, 26.0, t)
		var wave := sin(t * PI * 1.15) * 12.0 - 4.0
		var centre := Vector2(along, wave) * growth_scale
		var radius: float = lerp(7.0, 12.5, t) * growth_scale
		# Seam ring first, so it reads as flesh between the plates.
		draw_circle(centre, radius + 1.6 * growth_scale, Color(seam.r, seam.g, seam.b, 0.85))
		draw_circle(centre, radius, plate.darkened(0.12 + 0.05 * (1.0 - t)))
		draw_circle(centre + Vector2(-radius * 0.25, -radius * 0.3), radius * 0.42, plate.lightened(0.22))
		if i == segments - 1:
			head_position = centre
	# Plated skull.
	draw_circle(head_position, 14.0 * growth_scale, Color(seam.r, seam.g, seam.b, 0.9))
	draw_circle(head_position, 12.4 * growth_scale, plate)
	draw_colored_polygon(PackedVector2Array([
		head_position + Vector2(4, -10) * growth_scale,
		head_position + Vector2(17, -3) * growth_scale,
		head_position + Vector2(16, 7) * growth_scale,
		head_position + Vector2(3, 9) * growth_scale,
	]), plate.lightened(0.16))
	# The single rose eye from the concept art.
	draw_circle(head_position + Vector2(3, -3) * growth_scale, 4.2 * growth_scale, seam)
	draw_circle(head_position + Vector2(3.8, -4) * growth_scale, 1.6 * growth_scale, seam.lightened(0.45))
	# Forked tongue.
	var snout := head_position + Vector2(17, 3) * growth_scale
	draw_line(snout, snout + Vector2(9, 2) * growth_scale, seam, 1.6 * growth_scale)
	draw_line(snout + Vector2(9, 2) * growth_scale, snout + Vector2(14, -1) * growth_scale, seam, 1.3 * growth_scale)
	draw_line(snout + Vector2(9, 2) * growth_scale, snout + Vector2(13, 5) * growth_scale, seam, 1.3 * growth_scale)
	# Poison shimmer, so the passive is readable at a glance.
	draw_circle(head_position + Vector2(20, 4) * growth_scale, 2.2 * growth_scale, Color(glow.r, glow.g, glow.b, 0.55))

func _draw_serpent_wings(plate: Color, growth_scale: float) -> void:
	var wing := Color(plate.r, plate.g, plate.b, 0.34)
	var vein := Color(plate.r, plate.g, plate.b, 0.62)
	for side in [-1.0, 1.0]:
		var root := Vector2(2, -6) * growth_scale
		var tip := Vector2(2 + side * 6, -34) * growth_scale
		var spread := Vector2(side * 30, -22) * growth_scale
		draw_colored_polygon(PackedVector2Array([root, tip, spread]), wing)
		draw_line(root, tip, vein, 1.4 * growth_scale)
		draw_line(root, spread, vein, 1.2 * growth_scale)

func _draw_stone_anchor(glow: Color, growth_scale: float) -> void:
	draw_circle(Vector2.ZERO, 8.0 * growth_scale, Color(glow.r, glow.g, glow.b, 0.28))
	draw_circle(Vector2.ZERO, 4.0 * growth_scale, glow)

func _draw_stone_preview() -> void:
	if not _stone_targeting or terrain == null or not is_instance_valid(terrain):
		return
	var cells: Array[Vector2i] = []
	if _stone_dragging:
		cells = _drag_wall_cells()
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

func _spawn_death_fx(source: Node = null) -> void:
	var art := get_node_or_null("ArtSprite") as Sprite2D
	if art == null or art.texture == null:
		super(source)
		return
	if art.has_method("sync_view_facing"): art.sync_view_facing()
	var view := get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and view.has_method("spawn_painted_unit_death"):
		view.spawn_painted_unit_death(self,art)
	else:
		var corpse := preload("res://scripts/fx/painted_unit_death.gd").new()
		get_parent().add_child(corpse)
		corpse.configure(self,art)

func signi(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0
