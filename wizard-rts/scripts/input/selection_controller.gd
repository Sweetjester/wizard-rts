class_name SelectionController
extends Node2D

signal selection_changed(selected: Array[Node])

const DOUBLE_TAP_MSEC := 350

@export var drag_threshold: float = 8.0
@export var formation_spacing: float = 34.0
@export var shared_path_threshold: int = 4
@export var command_dispatcher_path: NodePath = NodePath("../CommandDispatcher")
@export var build_system_path: NodePath = NodePath("../BuildSystem")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var camera_path: NodePath = NodePath("../Camera2D")
@export var map_3d_view_path: NodePath = NodePath("../Map3DView")
@export var combat_debug_logging: bool = false

var selected_units: Array[Node] = []
# Looked up once and kept: the bridge is a sibling that never moves, and this is
# consulted on every right-click.
var _cached_block_bridge: Node
var command_dispatcher: CommandDispatcher
var build_system: Node
var rts_world: RTSWorld
var camera: Camera2D
var map_3d_view: Node
var control_groups := ControlGroupManager.new()
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_end := Vector2.ZERO
var _pending_target_command: StringName = &""
var _ignore_next_left_release := false
var _last_group_index := 0
var _last_group_msec: int = -100000
var _last_hero_msec: int = -100000
var _idle_production_cursor := -1
var _idle_unit_cursor := -1
var _subgroup_source: Array[Node] = []
var _subgroup_types: Array[StringName] = []
var _subgroup_state := 0
var _subgroup_dirty := true
var _launcher_ground_target: Node = null

func _ready() -> void:
	z_index = 3500
	command_dispatcher = get_node_or_null(command_dispatcher_path)
	build_system = get_node_or_null(build_system_path)
	rts_world = get_node_or_null(rts_world_path)
	camera = get_node_or_null(camera_path)
	map_3d_view = get_node_or_null(map_3d_view_path)
	if build_system != null and build_system.has_signal("unit_trained"):
		build_system.unit_trained.connect(_on_unit_trained)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _dragging:
			_drag_end = _drag_point()
			_push_3d_overlay()
			queue_redraw()
		elif _pending_target_command != &"":
			_push_3d_overlay()
			queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)

# Simulation-space mouse position. In 2D that is just the canvas mouse; in 3D it
# is the cursor projected onto the ground plane and converted back into
# simulation coordinates, so every ORDER path below is identical in both modes.
func _world_mouse_position() -> Vector2:
	if _uses_3d_view():
		return map_3d_view.call("screen_to_sim_position", get_viewport().get_mouse_position())
	return get_global_mouse_position()

func _uses_3d_view() -> bool:
	return map_3d_view != null and is_instance_valid(map_3d_view) and map_3d_view.has_method("screen_to_sim_position")

# Drag-selection is tracked in SCREEN space in 3D, not simulation space.
#
# Projecting the two drag corners onto the ground and building a Rect2 from them
# is wrong under a perspective camera: a screen rectangle maps to a trapezoid on
# the ground, and any part of the drag above the horizon projects to nothing at
# all. Keeping the rectangle on screen and testing each unit's PROJECTED
# position is both correct and what 3D RTS games actually do.
func _drag_point() -> Vector2:
	if _uses_3d_view():
		return get_viewport().get_mouse_position()
	return get_global_mouse_position()

# Where a unit sits in whichever space the drag rectangle is using.
func _selection_point_for(node: Node) -> Vector2:
	if not (node is Node2D):
		return Vector2.ZERO
	var sim_position: Vector2 = (node as Node2D).global_position
	if _uses_3d_view():
		return map_3d_view.call("sim_to_screen", sim_position)
	return sim_position

func _selection_point_visible(node: Node) -> bool:
	if not _uses_3d_view():
		return true
	if not (node is Node2D):
		return false
	# Units behind the camera project to a mirrored on-screen point and would
	# otherwise be box-selected from off screen.
	return bool(map_3d_view.call("is_sim_position_on_camera", (node as Node2D).global_position))

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _pending_target_command != &"":
			_issue_pending_target_command(_world_mouse_position())
			_ignore_next_left_release = true
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			_dragging = true
			_drag_start = _drag_point()
			_drag_end = _drag_start
			queue_redraw()
		else:
			if _ignore_next_left_release:
				_ignore_next_left_release = false
				get_viewport().set_input_as_handled()
				return
			_dragging = false
			_drag_end = _drag_point()
			_select_units(_selection_rect())
			queue_redraw()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_pending_target_command = &""
		if _try_order_attack_target(_world_mouse_position()):
			get_viewport().set_input_as_handled()
			return
		_order_selected_units(_world_mouse_position())

func _handle_key(event: InputEventKey) -> void:
	if _handle_control_group_key(event):
		return
	if _handle_army_selection_key(event):
		return
	if KeybindManager.is_action(event, KeybindManager.ACTION_ATTACK_MOVE):
		_pending_target_command = &"attack_move"
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif KeybindManager.is_action(event, KeybindManager.ACTION_PATROL):
		_pending_target_command = &"patrol"
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif KeybindManager.is_action(event, KeybindManager.ACTION_HOLD):
		_pending_target_command = &""
		queue_redraw()
		if command_dispatcher != null:
			command_dispatcher.submit_hold_position(selected_units)
		get_viewport().set_input_as_handled()
	elif KeybindManager.is_action(event, KeybindManager.ACTION_STOP):
		_pending_target_command = &""
		queue_redraw()
		if command_dispatcher != null:
			command_dispatcher.submit_stop(selected_units)
		get_viewport().set_input_as_handled()

func _issue_pending_target_command(target: Vector2) -> void:
	if selected_units.is_empty() and _pending_target_command != &"launcher_ground":
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
		&"launcher_ground":
			if build_system != null and build_system.has_method("order_launcher_attack_ground") 				and _launcher_ground_target != null and is_instance_valid(_launcher_ground_target):
				build_system.call("order_launcher_attack_ground", _launcher_ground_target, target)
			_launcher_ground_target = null
	_pending_target_command = &""
	queue_redraw()
	_push_3d_overlay()

func _select_units(rect: Rect2) -> void:
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
			# Click radius is measured in whichever space the click was taken in.
			# In 3D that is screen pixels, so the radius is scaled by how big the
			# unit actually appears rather than by its world size.
			var point := _selection_point_for(unit)
			if _uses_3d_view() and not _selection_point_visible(unit):
				continue
			var distance: float = point.distance_to(rect.position)
			var radius := float(unit.get("selection_radius"))
			if _uses_3d_view():
				radius = _screen_click_radius(unit)
			if distance <= radius and distance < best_click_distance:
				best_click_distance = distance
				best_click_unit = unit
		elif _uses_3d_view():
			selected = _selection_point_visible(unit) and rect.has_point(_selection_point_for(unit))
		else:
			selected = unit.is_inside_selection_rect(rect)
		if selected:
			if _is_structure(unit):
				structure_candidates.append(unit)
			else:
				unit_candidates.append(unit)
	var final_selection: Array[Node] = []
	if click_select:
		if best_click_unit != null:
			final_selection.append(best_click_unit)
	else:
		final_selection = unit_candidates if not unit_candidates.is_empty() else structure_candidates
	_apply_selection(final_selection)
	_push_3d_overlay()

# The one place selection is mutated. Everything that changes the selection --
# drag, click, control-group recall, hero key, army key, idle cycling, subgroup
# filtering -- goes through here so the deselect/select/emit sequence and the
# subgroup-cache invalidation can never drift apart.
func _apply_selection(nodes: Array[Node], keep_subgroup_cache: bool = false) -> void:
	# Published before the select loop, not after, so set_selected() already
	# sees the new size and can decide whether this selection is squad-sized or
	# army-wide. Corrected below to the post-filter count.
	var world_valid := rts_world != null and is_instance_valid(rts_world)
	if world_valid:
		rts_world.selected_unit_count = nodes.size()
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	for node in nodes:
		if not is_instance_valid(node) or not _is_player_selectable(node):
			continue
		node.set_selected(true)
		selected_units.append(node)
	if not keep_subgroup_cache:
		_subgroup_dirty = true
	if world_valid:
		rts_world.selected_unit_count = selected_units.size()
	selection_changed.emit(selected_units.duplicate())

# Screen-space click radius: the unit's world radius projected at its own
# distance, so clicking feels the same whether zoomed in or out.
func _screen_click_radius(unit: Node) -> float:
	if not (unit is Node2D):
		return 24.0
	var centre: Vector2 = (unit as Node2D).global_position
	var edge := centre + Vector2(float(unit.get("selection_radius")), 0.0)
	var screen_centre: Vector2 = map_3d_view.call("sim_to_screen", centre)
	var screen_edge: Vector2 = map_3d_view.call("sim_to_screen", edge)
	return maxf(12.0, screen_centre.distance_to(screen_edge))

# Pushes the drag rectangle and order cursor to the 3D overlay. In 2D these are
# drawn by _draw() below; in 3D that CanvasItem is hidden, so the same shapes
# are drawn by a CanvasLayer overlay instead.
func _push_3d_overlay() -> void:
	if not _uses_3d_view() or not map_3d_view.has_method("set_drag_rect"):
		return
	map_3d_view.call("set_drag_rect", _dragging, _selection_rect())
	map_3d_view.call("set_cursor_mode", _pending_target_command)

func _is_player_selectable(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	# Plain property read instead of the get_property_list() scan this used to
	# do: it runs once per selectable node per selection change, and the new
	# hotkeys make selection changes far more frequent than drag-select alone.
	var owner_value: Variant = node.get("owner_player_id")
	if owner_value == null:
		return false
	return int(owner_value) == 1

func _is_structure(node: Node) -> bool:
	return node.has_method("get_selection_kind") and node.get_selection_kind() == &"structure"

func _has_property(node: Node, property_name: String) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _prune_invalid_selection() -> void:
	var removed := false
	for i in range(selected_units.size() - 1, -1, -1):
		if not is_instance_valid(selected_units[i]):
			selected_units.remove_at(i)
			removed = true
	if removed:
		if rts_world != null and is_instance_valid(rts_world):
			rts_world.selected_unit_count = selected_units.size()
		selection_changed.emit(selected_units.duplicate())

# =====================================================================
# Army control: control groups, hero/army selection, idle cycling, subgroup
# filtering. Every entry point below runs only on a key press -- none of this
# code is reachable from _process/_physics_process, and none of it uses
# has_method()/get_property_list() on a unit.
# =====================================================================

func _handle_control_group_key(event: InputEventKey) -> bool:
	var keycode := event.physical_keycode
	if keycode < KEY_1 or keycode > KEY_9:
		return false
	var index := keycode - KEY_1 + 1
	if event.ctrl_pressed:
		assign_control_group(index)
	elif event.alt_pressed:
		toggle_reinforce_group(index)
	elif event.shift_pressed:
		add_to_control_group(index)
	else:
		var now := Time.get_ticks_msec()
		var double_tap := index == _last_group_index and now - _last_group_msec <= DOUBLE_TAP_MSEC
		_last_group_index = index
		_last_group_msec = now
		recall_control_group(index, double_tap)
	get_viewport().set_input_as_handled()
	return true

func _handle_army_selection_key(event: InputEventKey) -> bool:
	if KeybindManager.is_action(event, KeybindManager.ACTION_SELECT_HERO):
		var now := Time.get_ticks_msec()
		var double_tap := now - _last_hero_msec <= DOUBLE_TAP_MSEC
		_last_hero_msec = now
		select_hero(double_tap)
	elif KeybindManager.is_action(event, KeybindManager.ACTION_SELECT_ARMY):
		select_all_army()
	elif KeybindManager.is_action(event, KeybindManager.ACTION_CYCLE_IDLE_PRODUCTION):
		cycle_idle_production()
	elif KeybindManager.is_action(event, KeybindManager.ACTION_CYCLE_IDLE_UNIT):
		cycle_idle_unit()
	elif KeybindManager.is_action(event, KeybindManager.ACTION_CYCLE_SUBGROUP):
		cycle_subgroup(event.shift_pressed)
	else:
		return false
	_pending_target_command = &""
	queue_redraw()
	get_viewport().set_input_as_handled()
	return true

# Bio Launcher manual fire. Arms the same click-a-point flow attack-move and
# patrol already use, so there is one targeting cursor in the game rather than
# a second bespoke one.
func begin_launcher_attack_ground(launcher: Node) -> void:
	if launcher == null or not is_instance_valid(launcher):
		return
	_launcher_ground_target = launcher
	_pending_target_command = &"launcher_ground"
	queue_redraw()

func assign_control_group(index: int) -> int:
	_prune_invalid_selection()
	return control_groups.assign(index, selected_units.duplicate())

func add_to_control_group(index: int) -> int:
	_prune_invalid_selection()
	return control_groups.add(index, selected_units.duplicate())

func recall_control_group(index: int, snap_camera: bool = false) -> int:
	var members := control_groups.get_group(index)
	if members.is_empty():
		return 0
	_apply_selection(members.duplicate())
	if snap_camera:
		_snap_camera_to(selected_units)
	return selected_units.size()

func toggle_reinforce_group(index: int) -> bool:
	return control_groups.toggle_reinforce_group(index)

func select_hero(snap_camera: bool = false) -> Node:
	var hero := _player_wizard()
	if hero == null:
		return null
	_apply_selection([hero] as Array[Node])
	if snap_camera:
		_snap_camera_to(selected_units)
	return hero

# F2 deliberately excludes the wizard. In a game built on one irreplaceable
# hero plus a disposable swarm, "select everything" is almost never what the
# player means -- sweeping the hero into an attack-move is how you lose the
# run (wizard death is an independent loss condition, per design doc section 9).
# Hero on F1, swarm on F2, and the two never blur into each other.
func select_all_army() -> int:
	var army: Array[Node] = []
	for unit in _player_units():
		if _is_wizard_archetype(str(unit.get("unit_archetype"))):
			continue
		army.append(unit)
	_apply_selection(army)
	return army.size()

func cycle_idle_production() -> Node:
	if build_system == null or not build_system.has_method("idle_production_nodes"):
		return null
	var idle: Array = build_system.call("idle_production_nodes", 1)
	if idle.is_empty():
		_idle_production_cursor = -1
		return null
	_idle_production_cursor = (_idle_production_cursor + 1) % idle.size()
	var node: Node = idle[_idle_production_cursor]
	_apply_selection([node] as Array[Node])
	_snap_camera_to(selected_units)
	return node

# Wizard RTS has no worker units at all -- the economy is buildings-only -- so
# SC2/AoE4's "idle villager" key has no direct analogue. What it maps onto here
# is stragglers: at hundreds of units, the swarm units that lost their order
# and stopped are the real leak, and they are invisible on a crowded map.
func cycle_idle_unit() -> Node:
	var idle := idle_army_units()
	if idle.is_empty():
		_idle_unit_cursor = -1
		return null
	_idle_unit_cursor = (_idle_unit_cursor + 1) % idle.size()
	var unit: Node = idle[_idle_unit_cursor]
	_apply_selection([unit] as Array[Node])
	_snap_camera_to(selected_units)
	return unit

func idle_army_units() -> Array[Node]:
	var idle: Array[Node] = []
	for unit in _player_units():
		var archetype := str(unit.get("unit_archetype"))
		if _is_wizard_archetype(archetype):
			continue
		if str(unit.get("unit_state")) != "idle":
			continue
		idle.append(unit)
	return idle

# WC3 Tab subgroup cycling, adapted to be non-lossy. WC3 keeps the whole group
# selected and only moves the active subgroup; reproducing that exactly would
# mean carrying a second selection concept through every consumer. Instead Tab
# walks full selection -> type A -> type B -> ... -> full selection, so cycling
# all the way around always restores what you had. Shift+Tab walks it back.
func cycle_subgroup(reverse: bool = false) -> Array[Node]:
	if _subgroup_dirty or _subgroup_source.is_empty():
		_rebuild_subgroup_cache()
	if _subgroup_types.size() <= 1:
		return selected_units
	var states := _subgroup_types.size() + 1
	_subgroup_state = posmod(_subgroup_state + (-1 if reverse else 1), states)
	var next: Array[Node] = []
	if _subgroup_state == 0:
		for node in _subgroup_source:
			if is_instance_valid(node):
				next.append(node)
	else:
		var wanted := _subgroup_types[_subgroup_state - 1]
		for node in _subgroup_source:
			if is_instance_valid(node) and StringName(str(node.get("unit_archetype"))) == wanted:
				next.append(node)
	_apply_selection(next, true)
	return selected_units

func subgroup_types() -> Array[StringName]:
	return _subgroup_types.duplicate()

func _rebuild_subgroup_cache() -> void:
	_subgroup_source.clear()
	_subgroup_types.clear()
	_subgroup_state = 0
	for node in selected_units:
		if not is_instance_valid(node):
			continue
		_subgroup_source.append(node)
		var archetype := StringName(str(node.get("unit_archetype")))
		if not _subgroup_types.has(archetype):
			_subgroup_types.append(archetype)
	_subgroup_dirty = false

# Reinforce group: a unit that just finished training joins the flagged group
# and walks to where that army actually is, instead of standing at the barracks
# or at a rally point set three fights ago. Fires once per completed unit, on a
# signal -- there is no polling anywhere in this path.
func _on_unit_trained(player_id: int, _archetype: StringName, unit: Node) -> void:
	if player_id != 1 or unit == null or not is_instance_valid(unit):
		return
	if not control_groups.absorb_reinforcement(unit):
		return
	var rally: Variant = control_groups.reinforce_rally_position()
	if rally == null or not unit.has_method("issue_attack_move_order"):
		return
	unit.call_deferred("issue_attack_move_order", rally)

func _player_wizard() -> Node:
	for unit in _player_units():
		if _is_wizard_archetype(str(unit.get("unit_archetype"))):
			return unit
	return null

func _player_units() -> Array[Node]:
	var units: Array[Node] = []
	if rts_world != null and is_instance_valid(rts_world):
		for unit in rts_world.units_for_owner(1):
			units.append(unit)
		return units
	for node in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(node):
			continue
		var owner_value: Variant = node.get("owner_player_id")
		if owner_value != null and int(owner_value) == 1:
			units.append(node)
	return units

# Matches rts_hud.gd's existing check, and stays a plain string comparison on
# purpose: a `class_name Wizard` / `is Wizard` test here would reintroduce the
# circular class-resolution failure logged on 2026-08-23, and
# get_property_list() reflection is the other half of that same regression.
func _is_wizard_archetype(archetype: String) -> bool:
	return archetype == "life_wizard" or archetype == "fire_wizard" or archetype == "evangalion_wizard"

func _snap_camera_to(nodes: Array[Node]) -> void:
	if camera == null or not is_instance_valid(camera):
		camera = get_node_or_null(camera_path)
	map_3d_view = get_node_or_null(map_3d_view_path)
	if camera == null:
		return
	var total := Vector2.ZERO
	var counted := 0
	for node in nodes:
		if is_instance_valid(node) and node is Node2D:
			total += (node as Node2D).global_position
			counted += 1
	if counted == 0:
		return
	camera.position = total / float(counted)

func _order_selected_units(target: Vector2) -> void:
	_prune_invalid_selection()
	if selected_units.is_empty():
		return
	if _try_set_rally_point(target):
		return
	var movable_units := _movable_selected_units()
	if movable_units.is_empty():
		return
	# Multi-level destinations route through the block lattice. Ordinary ground
	# has exactly one level, so this returns false there and the existing 2D
	# pathfinder handles the order exactly as it always has.
	if _try_block_move_order(target, movable_units):
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

# Routes a move order through BlockNavBridge when the destination column has
# more than one standable level -- a wall-walk over a passage, an upper floor.
#
# Returns false for anything else, which is almost every order on almost every
# map, so flat-ground movement keeps its formation offsets, shared paths and
# flow fields untouched. Units the lattice cannot route (no path to any level
# they can stand on) fall through to the normal order rather than silently
# refusing to move.
func _try_block_move_order(target: Vector2, movable_units: Array) -> bool:
	var bridge := _block_nav_bridge()
	if bridge == null:
		return false
	var terrain_node: Node = bridge.get("terrain")
	if terrain_node == null or not is_instance_valid(terrain_node):
		return false
	var cell: Vector2i = terrain_node.call("world_to_cell", target)
	if not bool(bridge.call("is_multi_level", cell)):
		return false
	var routed := 0
	for unit in movable_units:
		if is_instance_valid(unit) and bool(bridge.call("order_to_column", unit, cell)):
			routed += 1
	return routed > 0

func _block_nav_bridge() -> Node:
	if _cached_block_bridge != null and is_instance_valid(_cached_block_bridge):
		return _cached_block_bridge
	if get_parent() != null:
		_cached_block_bridge = get_parent().get_node_or_null("BlockNavBridge")
	return _cached_block_bridge

func _try_order_attack_target(world_pos: Vector2) -> bool:
	if selected_units.is_empty():
		return false
	var movable_units := _movable_selected_units()
	if movable_units.is_empty():
		if combat_debug_logging:
			print("[SelectionController] Attack target rejected: selection has no movable combat units")
		return false
	var target := _attackable_at_position(world_pos)
	if target == null:
		if combat_debug_logging:
			print("[SelectionController] Attack target rejected: no hostile attackable at ", world_pos,
				" selected=", selected_units.size())
		return false
	var ordered := 0
	var refused := 0
	var refusal := ""
	for unit in movable_units:
		if not is_instance_valid(unit):
			continue
		if int(unit.get("owner_player_id")) == int(target.get("owner_player_id")):
			continue
		# Intelligence gate, same as the dispatcher applies to every other
		# order. This path bypasses the dispatcher, so it has to check too.
		if unit.has_method("accepts_player_order") and not bool(unit.call("accepts_player_order", &"attack_target")):
			refused += 1
			if refusal.is_empty() and unit.has_method("refusal_reason"):
				refusal = str(unit.call("refusal_reason"))
			continue
		# Same spotting rule the AI obeys: no ordering an attack on something up
		# a cliff that nobody can see.
		if unit.has_method("can_engage_target") and not bool(unit.call("can_engage_target", target)):
			refused += 1
			if refusal.is_empty():
				refusal = "No line of sight to that target"
			continue
		if unit.has_method("issue_attack_target"):
			unit.issue_attack_target(target)
			ordered += 1
	if refused > 0 and command_dispatcher != null:
		command_dispatcher.order_partially_refused.emit(ordered, refused, refusal)
	if ordered > 0:
		if combat_debug_logging:
			print("[SelectionController] Attack target ordered target=", target.name,
				" owner=", target.get("owner_player_id"),
				" selected_units=", ordered,
				" hp=", target.get("health") if _has_property(target, "health") else "<unknown>")
		return true
	if combat_debug_logging:
		print("[SelectionController] Attack target failed: selected units cannot attack target=", target.name)
	return false

func _attackable_at_position(world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("units"):
		if node is Node2D:
			var candidate := node as Node2D
			if not _is_attackable_candidate(candidate):
				_log_attackable_rejection(candidate, "units_group")
				continue
			var radius := _selection_radius_of(candidate, 24.0)
			var distance := candidate.global_position.distance_to(world_pos)
			if distance <= radius and distance < best_distance:
				best = candidate
				best_distance = distance
	for node in get_tree().get_nodes_in_group("structures"):
		if node is Node2D:
			var candidate := node as Node2D
			if not _is_attackable_candidate(candidate):
				_log_attackable_rejection(candidate, "structures_group")
				continue
			var radius := _selection_radius_of(candidate, 48.0)
			var distance := candidate.global_position.distance_to(world_pos)
			if distance <= radius and distance < best_distance:
				best = candidate
				best_distance = distance
	return best

func _is_attackable_candidate(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not node.has_method("take_damage"):
		return false
	var node_owner: Variant = node.get("owner_player_id")
	if node_owner == null:
		return false
	for selected in selected_units:
		if not is_instance_valid(selected):
			continue
		var selected_owner: Variant = selected.get("owner_player_id")
		if selected_owner != null:
			return int(selected_owner) != int(node_owner)
	return false

func _selection_radius_of(node: Node, fallback: float) -> float:
	var value: Variant = node.get("selection_radius")
	return float(value) if value != null else fallback

func _log_attackable_rejection(node: Node, source_group: String) -> void:
	if not combat_debug_logging:
		return
	if node == null or not is_instance_valid(node):
		return
	var selected_owner := -999999
	for selected in selected_units:
		if is_instance_valid(selected) and _has_property(selected, "owner_player_id"):
			selected_owner = int(selected.get("owner_player_id"))
			break
	var node_owner := int(node.get("owner_player_id")) if _has_property(node, "owner_player_id") else -999999
	var distance := INF
	if node is Node2D:
		distance = (node as Node2D).global_position.distance_to(_world_mouse_position())
	var radius := float(node.get("selection_radius")) if _has_property(node, "selection_radius") else 48.0
	if distance > radius:
		return
	print("[SelectionController] Attackable rejected source=", source_group,
		" node=", node.name,
		" owner=", node_owner,
		" selected_owner=", selected_owner,
		" has_take_damage=", node.has_method("take_damage"),
		" has_owner=", _has_property(node, "owner_player_id"),
		" groups=", node.get_groups())

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
		var mouse := _world_mouse_position()
		var color := Color("#E85A5A") if _pending_target_command == &"attack_move" else Color("#7DDDE8")
		if _pending_target_command == &"launcher_ground":
			color = Color("#A95766")
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
