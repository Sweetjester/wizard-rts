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
@export var content_clear_radius: float = 128.0
@export var content_reward_bio: int = 180
@export var required_outpost_count: int = 2
@export var gate_boss_until_objectives_complete: bool = true

var map_generator: Node
var wave_director: WaveDirector
var economy_manager: EconomyManager
var build_system: BuildSystem
var rts_world: RTSWorld
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

func _ready() -> void:
	layer = 65
	if not enabled:
		visible = false
		return
	_build_ui()
	call_deferred("_initialize")

func _process(_delta: float) -> void:
	if not _initialized:
		return
	_prune_outposts()
	_check_content_clear()
	_check_boss_gate()
	_check_defeat()
	_update_overlay()
	if Time.get_ticks_msec() - _last_debug_print_msec > 7000:
		_last_debug_print_msec = Time.get_ticks_msec()
		print("[KonVerticalSlice] ", _status_line())

func _initialize() -> void:
	map_generator = get_node_or_null(map_generator_path)
	wave_director = get_node_or_null(wave_director_path)
	economy_manager = get_node_or_null(economy_manager_path)
	build_system = get_node_or_null(build_system_path)
	rts_world = get_node_or_null(rts_world_path)
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
				_outposts.append({"plot": plot, "node": null, "destroyed": false})
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
		outpost.global_position = map_generator.cell_to_world(cell)
		outpost.z_index = clampi(int(outpost.global_position.y) + 180, -4096, 4096)
		get_parent().add_child(outpost)
		_outposts[i]["node"] = outpost
		var blockers := _footprint_cells(cell, Vector2i(4, 4))
		_outposts[i]["blockers"] = blockers
		_outpost_blockers[outpost.get_instance_id()] = blockers
		var approach_walkable: bool = map_generator.is_walkable_cell(cell) if map_generator.has_method("is_walkable_cell") else true
		if map_generator.has_method("add_dynamic_blockers"):
			map_generator.add_dynamic_blockers(blockers)
		print("[KonVerticalSlice] Outpost objective spawned id=", plot.get("id", ""),
			" cell=", cell,
			" hp=", outpost.health,
			" approach_walkable_before_blocker=", approach_walkable)

func _configure_boss_gate() -> void:
	if wave_director == null or not gate_boss_until_objectives_complete:
		return
	wave_director.boss_arrival_seconds = maxf(wave_director.boss_arrival_seconds, 9999.0)
	print("[KonVerticalSlice] Boss gated until at least one content plot is cleared and required outposts are destroyed.")

func _prune_outposts() -> void:
	for i in _outposts.size():
		var node: Node = _outposts[i].get("node", null)
		if bool(_outposts[i].get("destroyed", false)):
			continue
		if node == null or not is_instance_valid(node):
			_outposts[i]["destroyed"] = true
			var blockers: Array[Vector2i] = _outposts[i].get("blockers", [])
			if not blockers.is_empty() and map_generator != null and map_generator.has_method("remove_dynamic_blockers"):
				map_generator.remove_dynamic_blockers(blockers)
			var plot: Dictionary = _outposts[i].get("plot", {})
			print("[KonVerticalSlice] Outpost destroyed id=", plot.get("id", ""), " remaining=", _outposts_remaining())

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
			var node: Node = outpost.get("node", null)
			if node != null and is_instance_valid(node):
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
