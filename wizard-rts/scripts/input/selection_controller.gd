class_name SelectionController
extends Node2D

signal selection_changed(selected: Array[Node])

@export var drag_threshold: float = 8.0
@export var formation_spacing: float = 34.0
@export var shared_path_threshold: int = 16
@export var command_dispatcher_path: NodePath = NodePath("../CommandDispatcher")
@export var build_system_path: NodePath = NodePath("../BuildSystem")

var selected_units: Array[Node] = []
var command_dispatcher: CommandDispatcher
var build_system: Node
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_end := Vector2.ZERO
var _pending_target_command: StringName = &""
var _ignore_next_left_release := false

func _ready() -> void:
	z_index = 3500
	command_dispatcher = get_node_or_null(command_dispatcher_path)
	build_system = get_node_or_null(build_system_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _dragging:
			_drag_end = get_global_mouse_position()
			queue_redraw()
		elif _pending_target_command != &"":
			queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _pending_target_command != &"":
			_issue_pending_target_command(get_global_mouse_position())
			_ignore_next_left_release = true
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			_dragging = true
			_drag_start = get_global_mouse_position()
			_drag_end = _drag_start
			queue_redraw()
		else:
			if _ignore_next_left_release:
				_ignore_next_left_release = false
				get_viewport().set_input_as_handled()
				return
			_dragging = false
			_drag_end = get_global_mouse_position()
			_select_units(_selection_rect())
			queue_redraw()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_pending_target_command = &""
		_order_selected_units(get_global_mouse_position())

func _handle_key(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_A:
			_pending_target_command = &"attack_move"
			queue_redraw()
			get_viewport().set_input_as_handled()
		KEY_P:
			_pending_target_command = &"patrol"
			queue_redraw()
			get_viewport().set_input_as_handled()
		KEY_H:
			_pending_target_command = &""
			queue_redraw()
			if command_dispatcher != null:
				command_dispatcher.submit_hold_position(selected_units)
			get_viewport().set_input_as_handled()
		KEY_S:
			_pending_target_command = &""
			queue_redraw()
			if command_dispatcher != null:
				command_dispatcher.submit_stop(selected_units)
			get_viewport().set_input_as_handled()

func _issue_pending_target_command(target: Vector2) -> void:
	if selected_units.is_empty():
		_pending_target_command = &""
		return
	if command_dispatcher == null:
		_pending_target_command = &""
		return
	match _pending_target_command:
		&"attack_move":
			command_dispatcher.submit_attack_move(selected_units, target)
		&"patrol":
			command_dispatcher.submit_patrol(selected_units, target)
	_pending_target_command = &""
	queue_redraw()

func _select_units(rect: Rect2) -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()

	var click_select := rect.size.length() < drag_threshold
	var best_click_unit: Node = null
	var best_click_distance := INF
	var unit_candidates: Array[Node] = []
	var structure_candidates: Array[Node] = []
	for node in get_tree().get_nodes_in_group("selectable_units"):
		if not node.has_method("set_selected") or not node.has_method("is_inside_selection_rect"):
			continue
		if not _is_player_selectable(node):
			continue
		var unit: Node = node
		var selected := false
		if click_select:
			var distance: float = unit.global_position.distance_to(rect.position)
			if distance <= float(unit.get("selection_radius")) and distance < best_click_distance:
				best_click_distance = distance
				best_click_unit = unit
		else:
			selected = unit.is_inside_selection_rect(rect)
		if selected:
			if _is_structure(unit):
				structure_candidates.append(unit)
			else:
				unit_candidates.append(unit)
	if click_select and best_click_unit != null:
		_select_node(best_click_unit)
	elif not click_select:
		var final_selection: Array[Node] = unit_candidates if not unit_candidates.is_empty() else structure_candidates
		for node in final_selection:
			_select_node(node)
	selection_changed.emit(selected_units.duplicate())

func _select_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if not _is_player_selectable(node):
		return
	node.set_selected(true)
	selected_units.append(node)

func _is_player_selectable(node: Node) -> bool:
	if not _has_property(node, "owner_player_id"):
		return false
	return int(node.get("owner_player_id")) == 1

func _is_structure(node: Node) -> bool:
	return node.has_method("get_selection_kind") and node.get_selection_kind() == &"structure"

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _order_selected_units(target: Vector2) -> void:
	if selected_units.is_empty():
		return
	if _try_set_rally_point(target):
		return
	var movable_units := _movable_selected_units()
	if movable_units.is_empty():
		return
	var offsets := _formation_offsets(movable_units.size())
	var shared_path: Array[Vector2] = []
	if movable_units.size() >= shared_path_threshold:
		shared_path = _shared_group_path(target, movable_units)
	if command_dispatcher != null:
		command_dispatcher.submit_move(movable_units, target, offsets, shared_path)
		return
	for i in movable_units.size():
		var unit: Node = movable_units[i]
		if is_instance_valid(unit) and not shared_path.is_empty() and unit.has_method("issue_shared_path_order"):
			unit.issue_shared_path_order(shared_path, offsets[i])
		elif is_instance_valid(unit):
			if unit.has_method("issue_move_order_offset"):
				unit.issue_move_order_offset(target, offsets[i])

func _shared_group_path(target: Vector2, units: Array[Node]) -> Array[Vector2]:
	var terrain: Node = null
	var center := Vector2.ZERO
	var counted := 0
	for unit in units:
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		center += unit.global_position
		counted += 1
		if terrain == null:
			terrain = unit.get("terrain")
	if counted == 0 or terrain == null or not terrain.has_method("find_path_world"):
		return []
	center /= float(counted)
	var path: Array[Vector2] = []
	for point in terrain.find_path_world(center, target):
		path.append(point)
	return path

func _movable_selected_units() -> Array[Node]:
	var movable: Array[Node] = []
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("issue_move_order_offset"):
			movable.append(unit)
	return movable

func _try_set_rally_point(target: Vector2) -> bool:
	if build_system == null:
		return false
	var handled := false
	var has_movable := false
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("issue_move_order_offset"):
			has_movable = true
			break
	if has_movable:
		return false
	for unit in selected_units:
		if is_instance_valid(unit) and _is_structure(unit) and str(unit.get("archetype")) == "barracks":
			if build_system.has_method("set_rally_point_for_structure"):
				handled = bool(build_system.call("set_rally_point_for_structure", unit, target)) or handled
	return handled

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
	if _pending_target_command != &"":
		var mouse := get_global_mouse_position()
		var color := Color("#E85A5A") if _pending_target_command == &"attack_move" else Color("#7DDDE8")
		draw_circle(mouse, 11.0, Color(color, 0.18))
		draw_arc(mouse, 15.0, 0, TAU, 24, color, 2.0)
		if _pending_target_command == &"attack_move":
			draw_line(mouse + Vector2(-8, -8), mouse + Vector2(8, 8), color, 2.0)
			draw_line(mouse + Vector2(8, -8), mouse + Vector2(-8, 8), color, 2.0)
		else:
			draw_arc(mouse, 7.0, 0.4, TAU - 0.4, 18, color, 2.0)
	if not _dragging:
		return
	var rect := _selection_rect()
	if rect.size.length() < drag_threshold:
		return
	draw_rect(rect, Color(0.25, 0.95, 1.0, 0.12), true)
	draw_rect(rect, Color(0.49, 0.87, 0.91, 0.8), false, 2.0)
