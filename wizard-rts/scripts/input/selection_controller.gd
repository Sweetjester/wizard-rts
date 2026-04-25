class_name SelectionController
extends Node2D

@export var drag_threshold: float = 8.0
@export var formation_spacing: float = 34.0

var selected_units: Array[Node] = []
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_end := Vector2.ZERO

func _ready() -> void:
	z_index = 3500

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _dragging:
		_drag_end = get_global_mouse_position()
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = get_global_mouse_position()
			_drag_end = _drag_start
			queue_redraw()
		else:
			_dragging = false
			_drag_end = get_global_mouse_position()
			_select_units(_selection_rect())
			queue_redraw()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_order_selected_units(get_global_mouse_position())

func _handle_key(event: InputEventKey) -> void:
	if event.physical_keycode == KEY_Q:
		for unit in selected_units:
			if unit.has_method("summon_treants"):
				var summoned: Array = unit.call("summon_treants")
				for new_unit in summoned:
					if new_unit.has_method("set_selected"):
						new_unit.set_selected(true)
						selected_units.append(new_unit)

func _select_units(rect: Rect2) -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()

	var click_select := rect.size.length() < drag_threshold
	for node in get_tree().get_nodes_in_group("selectable_units"):
		if not node.has_method("set_selected") or not node.has_method("is_inside_selection_rect"):
			continue
		var unit: Node = node
		var selected := false
		if click_select:
			selected = unit.global_position.distance_to(rect.position) <= float(unit.get("selection_radius"))
		else:
			selected = unit.is_inside_selection_rect(rect)
		if selected:
			unit.set_selected(true)
			selected_units.append(unit)

func _order_selected_units(target: Vector2) -> void:
	if selected_units.is_empty():
		return
	var offsets := _formation_offsets(selected_units.size())
	for i in selected_units.size():
		var unit: Node = selected_units[i]
		if is_instance_valid(unit):
			unit.issue_move_order_offset(target, offsets[i])

func _formation_offsets(count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var columns := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(columns))
	var origin := Vector2(float(columns - 1), float(rows - 1)) * formation_spacing * 0.5
	for i in count:
		var col := i % columns
		var row := i / columns
		offsets.append(Vector2(col, row) * formation_spacing - origin)
	return offsets

func _selection_rect() -> Rect2:
	return Rect2(_drag_start, _drag_end - _drag_start).abs()

func _draw() -> void:
	if not _dragging:
		return
	var rect := _selection_rect()
	if rect.size.length() < drag_threshold:
		return
	draw_rect(rect, Color(0.25, 0.95, 1.0, 0.12), true)
	draw_rect(rect, Color(0.49, 0.87, 0.91, 0.8), false, 2.0)
