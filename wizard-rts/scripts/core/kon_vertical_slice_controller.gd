class_name KonVerticalSliceController
extends CanvasLayer

const BIOME_ID := "DARK_FOREST_FRONTIER"
const OUTPOST_ARCHETYPE := &"enemy_outpost"
const PLAYER_ID := 1
const ENEMY_ID := 2

@export var enabled: bool = true
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var wave_director_path: NodePath = NodePath("../WaveDirector")
@export var economy_manager_path: NodePath = NodePath("../EconomyManager")
@export var build_system_path: NodePath = NodePath("../BuildSystem")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var selection_controller_path: NodePath = NodePath("../SelectionController")
@export var content_clear_radius: float = 128.0
@export var content_reward_bio: int = 180
@export var required_outpost_count: int = 2
@export var gate_boss_until_objectives_complete: bool = true
@export var outpost_spawn_interval: float = 28.0
@export var outpost_spawn_radius: int = 7
@export var outpost_max_active_spawned_enemies: int = 36
@export var combat_debug_logging: bool = false
@export var slice_update_interval: float = 0.25
@export var overlay_update_interval: float = 0.25

var map_generator: Node
var wave_director: WaveDirector
var economy_manager: EconomyManager
var build_system: BuildSystem
var rts_world: RTSWorld
var selection_controller: SelectionController
var _root_panel: PanelContainer
var _label: Label
var _initialized := false
var _content_plots: Array[Dictionary] = []
var _cleared_content_ids: Dictionary = {}
var _outposts: Array[Dictionary] = []
var _outpost_blockers: Dictionary = {}
var _boss_triggered_by_slice := false
var _defeat := false
var _last_debug_print_msec := 0
var _last_damage_event := "none"
var _slice_update_elapsed := 0.0
var _overlay_update_elapsed := 0.0

func _ready() -> void:
	layer = 65
	if not enabled:
		visible = false
		return
	_build_ui()
	call_deferred("_initialize")

func _process(delta: float) -> void:
	if not _initialized:
		return
	_slice_update_elapsed += delta
	_overlay_update_elapsed += delta
	if _slice_update_elapsed >= slice_update_interval:
		var step_delta := _slice_update_elapsed
		_slice_update_elapsed = 0.0
		_update_outpost_offense(step_delta)
		_prune_outposts()
		_check_content_clear()
		_check_boss_gate()
		_check_defeat()
	if _overlay_update_elapsed >= overlay_update_interval:
		_overlay_update_elapsed = 0.0
		_update_overlay()
	if combat_debug_logging and Time.get_ticks_msec() - _last_debug_print_msec > 7000:
		_last_debug_print_msec = Time.get_ticks_msec()
		print("[KonVerticalSlice] ", _status_line())

func _initialize() -> void:
	map_generator = get_node_or_null(map_generator_path)
	wave_director = get_node_or_null(wave_director_path)
	economy_manager = get_node_or_null(economy_manager_path)
	build_system = get_node_or_null(build_system_path)
	rts_world = get_node_or_null(rts_world_path)
	selection_controller = get_node_or_null(selection_controller_path)
	if map_generator == null:
		push_warning("[KonVerticalSlice] Missing MapGenerator; vertical slice overlay disabled.")
		visible = false
		return
	if str(map_generator.get("map_type_id")) != "seeded_grid_frontier":
		visible = false
		return
	_collect_content_and_outposts()
	_spawn_outpost_objectives()
	_configure_boss_gate()
	_initialized = true
	print("[KonVerticalSlice] Initialized KON slice | biome=", BIOME_ID,
		" | content=", _content_plots.size(),
		" | outposts=", _outposts.size(),
		" | required_outposts=", _required_outposts_total(),
		" | wave_enabled=", wave_director.enabled if wave_director != null else false)
	_validate_slice_routes()
	_update_overlay()

func _build_ui() -> void:
	_root_panel = PanelContainer.new()
	_root_panel.name = "KonVerticalSliceOverlay"
	_root_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root_panel.offset_left = -330
	_root_panel.offset_top = 82
	_root_panel.offset_right = -16
	_root_panel.offset_bottom = 310
	add_child(_root_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_root_panel.add_child(margin)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color("#D6C7AE"))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.86))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	margin.add_child(_label)

func _collect_content_and_outposts() -> void:
	_content_plots.clear()
	_outposts.clear()
	var plots: Array = map_generator.get_plots() if map_generator.has_method("get_plots") else []
	for plot in plots:
		var kind := str(plot.get("kind", ""))
		var archetype := str(plot.get("content_archetype", ""))
		if kind == "enemy_outpost" or _is_slice_outpost_archetype(archetype):
			if _outposts.size() < required_outpost_count:
				_outposts.append({"plot": plot, "node": null, "destroyed": false, "combat_destroyed": false, "missing": false, "spawn_elapsed": 0.0, "spawned": 0})
			continue
		if kind == "content_blank" or kind == "quest" or kind == "objective":
			_content_plots.append(plot)

func _is_slice_outpost_archetype(archetype: String) -> bool:
	var lower := archetype.to_lower()
	return lower.contains("outpost") or lower.contains("camp") or lower.contains("ambush")

func _spawn_outpost_objectives() -> void:
	for i in _outposts.size():
		var plot: Dictionary = _outposts[i]["plot"]
		var anchor: Vector2i = plot.get("anchor", Vector2i.ZERO)
		var cell: Vector2i = map_generator.nearest_walkable_cell(anchor, 10) if map_generator.has_method("nearest_walkable_cell") else anchor
		var outpost := KonStructure.new()
		outpost.configure(OUTPOST_ARCHETYPE, cell, Vector2i(4, 4))
		outpost.set_runtime_stats(ENEMY_ID, 640 + i * 160, 640 + i * 160, 1)
		outpost.combat_debug_logging = combat_debug_logging
		outpost.global_position = map_generator.cell_to_world(cell)
		outpost.z_index = clampi(int(outpost.global_position.y) + 180, -4096, 4096)
		get_parent().add_child(outpost)
		_outposts[i]["node"] = outpost
		outpost.damage_taken.connect(_on_outpost_damage_taken.bind(str(plot.get("id", ""))))
		outpost.destroyed.connect(_on_outpost_destroyed.bind(str(plot.get("id", ""))))
		var blockers := _footprint_cells(cell, Vector2i(4, 4))
		_outposts[i]["blockers"] = blockers
		_outpost_blockers[outpost.get_instance_id()] = blockers
		var approach_walkable: bool = map_generator.is_walkable_cell(cell) if map_generator.has_method("is_walkable_cell") else true
		if map_generator.has_method("add_dynamic_blockers"):
			map_generator.add_dynamic_blockers(blockers)
		if combat_debug_logging:
			print("[KonVerticalSlice] Outpost objective spawned id=", plot.get("id", ""),
				" cell=", cell,
				" hp=", outpost.health,
				" approach_walkable_before_blocker=", approach_walkable)
		_log_combat_entity("enemy_outpost_spawned", outpost)

func _update_outpost_offense(delta: float) -> void:
	if wave_director == null or map_generator == null:
		return
	if rts_world != null and rts_world.count_units_for_owner(ENEMY_ID) >= outpost_max_active_spawned_enemies:
		return
	for i in _outposts.size():
		if bool(_outposts[i].get("destroyed", false)):
			continue
		var node = _outposts[i].get("node", null)
		if node == null or not is_instance_valid(node):
			continue
		_outposts[i]["spawn_elapsed"] = float(_outposts[i].get("spawn_elapsed", 0.0)) + delta
		if float(_outposts[i]["spawn_elapsed"]) < outpost_spawn_interval:
			continue
		_outposts[i]["spawn_elapsed"] = 0.0
		_spawn_outpost_defender(i)

func _spawn_outpost_defender(outpost_index: int) -> void:
	if wave_director == null or map_generator == null:
		return
	var node = _outposts[outpost_index].get("node", null)
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return
	var outpost_node := node as Node2D
	var outpost_cell: Vector2i = map_generator.world_to_cell(outpost_node.global_position)
	var spawn_cell: Vector2i = map_generator.nearest_walkable_cell(outpost_cell + Vector2i(outpost_index + 1, 2), outpost_spawn_radius)
	var target := _player_target_world()
	var spawn_count := int(_outposts[outpost_index].get("spawned", 0))
	var archetype := &"deom_crosshirran" if spawn_count % 3 == 2 else &"deom_blade"
	var enemy: Node = wave_director.call("_spawn_enemy", archetype, spawn_cell, get_parent(), target)
	_outposts[outpost_index]["spawned"] = spawn_count + 1
	_log_combat_entity("outpost_defender_spawned", enemy)
	if combat_debug_logging:
		print("[KonVerticalSlice] Outpost spawned defender archetype=", archetype,
			" outpost=", _outposts[outpost_index].get("plot", {}).get("id", ""),
			" spawn_cell=", spawn_cell,
			" target=", target,
			" enemy=", enemy.name if enemy != null and is_instance_valid(enemy) else "<none>")

func _player_target_world() -> Vector2:
	if wave_director != null and wave_director.has_method("_player_target_world"):
		return wave_director.call("_player_target_world")
	for structure in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and structure is Node2D and int(structure.get("owner_player_id")) == PLAYER_ID:
			return (structure as Node2D).global_position
	for unit in _player_units():
		if is_instance_valid(unit):
			return unit.global_position
	return Vector2.ZERO

func _configure_boss_gate() -> void:
	if wave_director == null or not gate_boss_until_objectives_complete:
		return
	wave_director.boss_arrival_seconds = maxf(wave_director.boss_arrival_seconds, 9999.0)
	print("[KonVerticalSlice] Boss gated until at least one content plot is cleared and required outposts are destroyed.")

func _prune_outposts() -> void:
	for i in _outposts.size():
		var node = _outposts[i].get("node", null)
		if bool(_outposts[i].get("destroyed", false)):
			continue
		if node == null or not is_instance_valid(node):
			if bool(_outposts[i].get("missing", false)):
				continue
			_outposts[i]["missing"] = true
			var plot: Dictionary = _outposts[i].get("plot", {})
			push_warning("[KonVerticalSlice] Outpost node missing without combat destruction; objective remains uncleared: %s" % str(plot.get("id", "")))

func _on_outpost_damage_taken(amount: int, source: Node, remaining_health: int, plot_id: String) -> void:
	_last_damage_event = "outpost %s took %s from %s, hp %s" % [
		plot_id,
		amount,
		source.name if source != null and is_instance_valid(source) else "<none>",
		remaining_health,
	]
	if combat_debug_logging:
		print("[KonVerticalSlice] Damage event: ", _last_damage_event)

func _on_outpost_destroyed(structure: KonStructure, source: Node, plot_id: String) -> void:
	for i in _outposts.size():
		if _outposts[i].get("node", null) != structure:
			continue
		_outposts[i]["destroyed"] = true
		_outposts[i]["combat_destroyed"] = true
		_outposts[i]["missing"] = false
		var blockers: Array[Vector2i] = _outposts[i].get("blockers", [])
		if not blockers.is_empty() and map_generator != null and map_generator.has_method("remove_dynamic_blockers"):
			map_generator.remove_dynamic_blockers(blockers)
		break
	_last_damage_event = "outpost %s destroyed by %s" % [plot_id, source.name if source != null and is_instance_valid(source) else "<unknown>"]
	print("[KonVerticalSlice] Outpost destroyed via combat id=", plot_id, " remaining=", _outposts_remaining())

func _check_content_clear() -> void:
	if _content_plots.is_empty() or map_generator == null:
		return
	var players := _player_units()
	if players.is_empty():
		return
	for plot in _content_plots:
		var id := str(plot.get("id", ""))
		if id.is_empty() or _cleared_content_ids.has(id):
			continue
		var anchor: Vector2i = plot.get("anchor", Vector2i.ZERO)
		var world: Vector2 = map_generator.cell_to_world(anchor)
		for unit in players:
			if not is_instance_valid(unit):
				continue
			if unit.global_position.distance_to(world) <= content_clear_radius:
				_cleared_content_ids[id] = true
				if economy_manager != null:
					economy_manager.add_resource(PLAYER_ID, &"bio", content_reward_bio)
					economy_manager.add_resource(PLAYER_ID, &"essence", 1)
				print("[KonVerticalSlice] Content cleared id=", id,
					" reward_bio=", content_reward_bio,
					" cleared=", _cleared_content_ids.size(), "/", _content_plots.size())
				break

func _check_boss_gate() -> void:
	if wave_director == null or _boss_triggered_by_slice or wave_director.boss_has_spawned:
		return
	if _outposts_remaining() > 0:
		return
	if _cleared_content_ids.size() < 1:
		return
	if wave_director.has_method("trigger_boss_now"):
		_boss_triggered_by_slice = bool(wave_director.call("trigger_boss_now", "kon_vertical_slice_objectives_complete"))
	else:
		wave_director.call("_spawn_boss")
		_boss_triggered_by_slice = true
	print("[KonVerticalSlice] Boss trigger requested. outposts_remaining=", _outposts_remaining(),
		" content_cleared=", _cleared_content_ids.size())

func _check_defeat() -> void:
	if _defeat:
		return
	var has_tower := false
	var has_wizard := false
	for structure in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == PLAYER_ID and str(structure.get("archetype")) == "wizard_tower":
			has_tower = true
			break
	for unit in _player_units():
		if is_instance_valid(unit) and str(unit.get("unit_archetype")) == "life_wizard":
			has_wizard = true
			break
	if has_tower or has_wizard:
		return
	_defeat = true
	if wave_director != null:
		wave_director.enabled = false
	print("[KonVerticalSlice] DEFEAT: no wizard tower or KON wizard remains.")

func _update_overlay() -> void:
	if _label == null:
		return
	var resources := economy_manager.get_resources(PLAYER_ID) if economy_manager != null else {}
	var income_count := economy_manager.economy_buildings.size() if economy_manager != null else 0
	var base_id := _chosen_base_plot_id()
	var state := _victory_defeat_state()
	_label.text = "KON VERTICAL SLICE\nBiome: %s\nPhase: %s\nBase: %s\nIncome active: %s (%s absorbers)\nWave: %s\nOutposts remaining: %s/%s\nContent cleared: %s/%s\nBoss triggered: %s\nState: %s\nBio %s | Essence %s" % [
		BIOME_ID,
		_slice_phase(),
		base_id if not base_id.is_empty() else "unclaimed",
		"yes" if income_count > 0 else "no",
		income_count,
		wave_director.wave_index if wave_director != null else 0,
		_outposts_remaining(),
		_required_outposts_total(),
		_cleared_content_ids.size(),
		_content_plots.size(),
		wave_director.boss_has_spawned if wave_director != null else false,
		state,
		int(resources.get(&"bio", 0)),
		int(resources.get(&"essence", 0)),
	]
	_label.text += "\n\nCOMBAT DEBUG\n%s\nLast damage: %s" % [_combat_debug_text(), _last_damage_event]

func _combat_debug_text() -> String:
	var selected := _selected_debug_node()
	if selected == null:
		return "selected target: none"
	var owner := int(selected.get("owner_player_id")) if _node_has_property(selected, "owner_player_id") else -1
	var hp := int(selected.get("health")) if _node_has_property(selected, "health") else -1
	var max_hp := int(selected.get("max_health")) if _node_has_property(selected, "max_health") else -1
	var targetable := selected.has_method("take_damage")
	var hostile := owner != PLAYER_ID and owner != -1
	var attack_target: Variant = selected.get("attack_target") if _node_has_property(selected, "attack_target") else null
	var attack_cooldown: Variant = selected.get("attack_cooldown") if _node_has_property(selected, "attack_cooldown") else "<none>"
	var attackable_to_selection := targetable
	var selected_owner := _valid_selected_owner_for_debug()
	if selected_owner != -1:
		attackable_to_selection = targetable and owner != selected_owner
	return "selected=%s owner=%s hp=%s/%s attackable=%s hostile_to_player=%s hostile_to_selected=%s current_target=%s cooldown=%s" % [
		selected.name,
		owner,
		hp,
		max_hp,
		targetable,
		hostile,
		attackable_to_selection,
		attack_target.name if attack_target != null and is_instance_valid(attack_target) else "none",
		str(attack_cooldown),
	]

func _selected_debug_node() -> Node:
	if selection_controller != null and not selection_controller.selected_units.is_empty():
		for node in selection_controller.selected_units:
			if is_instance_valid(node):
				return node
	for outpost in _outposts:
		var node = outpost.get("node", null)
		if node != null and is_instance_valid(node):
			return node
	return null

func _valid_selected_owner_for_debug() -> int:
	if selection_controller == null:
		return -1
	for node in selection_controller.selected_units:
		if node != null and is_instance_valid(node) and _node_has_property(node, "owner_player_id"):
			return int(node.get("owner_player_id"))
	return -1

func _slice_phase() -> String:
	if wave_director == null:
		return "scouting"
	match wave_director.phase:
		&"scouting":
			return "scouting"
		&"buildup":
			return "basing"
		&"offense":
			return "assault"
		&"victory":
			return "assault"
	return str(wave_director.phase)

func _victory_defeat_state() -> String:
	if _defeat:
		return "defeat"
	if wave_director != null and wave_director.boss_has_been_defeated:
		return "victory"
	if wave_director != null and wave_director.boss_has_spawned:
		return "boss_active"
	return "running"

func _chosen_base_plot_id() -> String:
	if build_system != null:
		for structure in build_system.get_structures():
			if int(structure.get("player_id", -1)) != PLAYER_ID:
				continue
			var plot_id := str(structure.get("plot_id", ""))
			if not plot_id.is_empty():
				return plot_id
	for structure in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == PLAYER_ID and str(structure.get("archetype")) == "wizard_tower":
			return _nearest_base_plot_id((structure as Node2D).global_position)
	return ""

func _nearest_base_plot_id(world_pos: Vector2) -> String:
	if map_generator == null or not map_generator.has_method("get_base_plots"):
		return ""
	var best_id := ""
	var best_distance := INF
	for plot in map_generator.get_base_plots():
		var anchor: Vector2i = plot.get("anchor", Vector2i.ZERO)
		var distance := world_pos.distance_squared_to(map_generator.cell_to_world(anchor))
		if distance < best_distance:
			best_distance = distance
			best_id = str(plot.get("id", ""))
	return best_id

func _outposts_remaining() -> int:
	var remaining := 0
	for outpost in _outposts:
		if not bool(outpost.get("destroyed", false)):
			remaining += 1
	return remaining

func _required_outposts_total() -> int:
	return _outposts.size()

func _player_units() -> Array[Node2D]:
	if rts_world != null:
		return rts_world.units_for_owner(PLAYER_ID)
	var units: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == PLAYER_ID:
			units.append(unit)
	return units

func _footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(origin.x, origin.x + footprint.x):
		for y in range(origin.y, origin.y + footprint.y):
			cells.append(Vector2i(x, y))
	return cells

func _node_has_property(node: Node, property_name: String) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _validate_slice_routes() -> void:
	if map_generator == null or not map_generator.has_method("find_path_world"):
		return
	var base_plots: Array = map_generator.get_base_plots() if map_generator.has_method("get_base_plots") else []
	if base_plots.is_empty():
		push_warning("[KonVerticalSlice] No base plots found for route validation.")
		return
	var start_world: Vector2 = map_generator.cell_to_world(base_plots[0].get("anchor", Vector2i.ZERO))
	for outpost in _outposts:
		var plot: Dictionary = outpost.get("plot", {})
		var target_world: Vector2 = map_generator.cell_to_world(plot.get("anchor", Vector2i.ZERO))
		var path: Array = map_generator.find_path_world(start_world, target_world)
		if path.is_empty():
			push_warning("[KonVerticalSlice] Outpost route may be blocked: %s" % str(plot.get("id", "")))
	for plot in _content_plots:
		var target_world: Vector2 = map_generator.cell_to_world(plot.get("anchor", Vector2i.ZERO))
		var path: Array = map_generator.find_path_world(start_world, target_world)
		if path.is_empty():
			push_warning("[KonVerticalSlice] Content route may be blocked: %s" % str(plot.get("id", "")))

func _status_line() -> String:
	return "phase=%s base=%s income=%s wave=%s outposts=%s content=%s boss=%s state=%s" % [
		_slice_phase(),
		_chosen_base_plot_id(),
		economy_manager.economy_buildings.size() if economy_manager != null else 0,
		wave_director.wave_index if wave_director != null else 0,
		_outposts_remaining(),
		_cleared_content_ids.size(),
		wave_director.boss_has_spawned if wave_director != null else false,
		_victory_defeat_state(),
	]

func _log_combat_entity(context: String, node: Node) -> void:
	if not combat_debug_logging:
		return
	if node == null or not is_instance_valid(node):
		print("[CombatValidation] ", context, " node=<invalid>")
		return
	var groups := PackedStringArray()
	for group in node.get_groups():
		groups.append(str(group))
	var script_path := "<none>"
	var script: Variant = node.get_script()
	if script != null and script is Resource:
		script_path = str((script as Resource).resource_path)
	var group_text := ",".join(groups)
	print("[CombatValidation] ", context,
		" node=", node.name,
		" class=", node.get_class(),
		" script=", script_path,
		" owner=", node.get("owner_player_id") if _node_has_property(node, "owner_player_id") else "<missing>",
		" take_damage=", node.has_method("take_damage"),
		" rts_unit_registered=", _is_registered_unit(node),
		" rts_structure_registered=", _is_registered_structure(node),
		" groups=", group_text,
		" attack_damage=", node.get("attack_damage") if _node_has_property(node, "attack_damage") else "<missing>",
		" attack_range=", node.get("attack_range") if _node_has_property(node, "attack_range") else "<missing>",
		" health=", node.get("health") if _node_has_property(node, "health") else "<missing>",
		" max_health=", node.get("max_health") if _node_has_property(node, "max_health") else "<missing>")

func _is_registered_unit(node: Node) -> bool:
	if rts_world == null or not is_instance_valid(rts_world) or not (node is Node2D):
		return false
	return rts_world.all_units().has(node)

func _is_registered_structure(node: Node) -> bool:
	if rts_world == null or not is_instance_valid(rts_world) or not (node is Node2D):
		return false
	return rts_world.all_structures().has(node)
