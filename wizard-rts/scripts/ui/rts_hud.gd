class_name RTSHud
extends CanvasLayer

const ONE_SHOT_SPRITE_FX := preload("res://scripts/fx/one_shot_sprite_fx.gd")
const BIO_MEND_FX: Texture2D = preload("res://assets/fx/kon/bio_mend_spell_sheet.png")
const SEAL_AWAY_FX: Texture2D = preload("res://assets/fx/kon/seal_away_spell_sheet.png")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const VICTORY_RETURN_SECONDS := 5.0
const BARRACKS_UNIT_BUTTONS := [
	{"archetype": &"terrible_thing", "label": "Thing"},
	{"archetype": &"oaven_spear", "label": "Oaven"},
	{"archetype": &"horror", "label": "Horror"},
	{"archetype": &"apex", "label": "Apex"},
	{"archetype": &"spawner", "label": "Spawner"},
	{"archetype": &"stone_face_serpent", "label": "Serpent"},
	{"archetype": &"mangler", "label": "Mangler"},
]

@export var economy_manager_path: NodePath = NodePath("../EconomyManager")
@export var wave_director_path: NodePath = NodePath("../WaveDirector")
@export var selection_controller_path: NodePath = NodePath("../SelectionController")
@export var build_system_path: NodePath = NodePath("../BuildSystem")
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var combat_system_path: NodePath = NodePath("../CombatSystem")
@export var kon_vertical_slice_path: NodePath = NodePath("../KonVerticalSliceController")

var economy_manager: EconomyManager
var wave_director: WaveDirector
var selection_controller: SelectionController
var build_system: Node
var map_generator: Node
var rts_world: RTSWorld
var combat_system: Node
var kon_vertical_slice: Node
var resource_label: Label
var phase_label: Label
var selection_label: Label
var status_label: Label
var detail_name_label: Label
var detail_body_label: Label
var detail_meta_label: Label
var evolution_bar: ProgressBar
var evolution_label: Label
var alert_label: Label
var command_container: HFlowContainer
var observer_vault: CanvasLayer
var command_dock: PanelContainer
var ai_test_container: HBoxContainer
var map_tool_container: HBoxContainer
var _fog_button: Button
var ai_telemetry_label: Label
var ai_spawn_button: Button
var control_group_label: Label
var unit_stat_window: Window
var _last_selection_signature := ""
var _alert_until_msec: int = 0
var _boss_warning_shown := false
var _grace_warning_shown := false
var _victory_return_remaining := -1.0
var _last_victory_second := -1
var _return_phase_title := "Victory"
var _return_alert_prefix := "VICTORY"
var _telemetry_elapsed := 0.0

func _ready() -> void:
	layer = 50
	economy_manager = get_node_or_null(economy_manager_path)
	wave_director = get_node_or_null(wave_director_path)
	selection_controller = get_node_or_null(selection_controller_path)
	build_system = get_node_or_null(build_system_path)
	map_generator = get_node_or_null(map_generator_path)
	rts_world = get_node_or_null(rts_world_path)
	combat_system = get_node_or_null(combat_system_path)
	kon_vertical_slice = get_node_or_null(kon_vertical_slice_path)
	_build_ui()
	observer_vault = preload("res://scripts/ui/observer_vault.gd").new()
	add_child(observer_vault)
	if kon_vertical_slice != null and kon_vertical_slice.has_signal("defeat_triggered"):
		kon_vertical_slice.defeat_triggered.connect(func(reason: String) -> void:
			_start_defeat_return_countdown(reason)
		)
	if kon_vertical_slice != null and kon_vertical_slice.has_signal("objective_completed"):
		kon_vertical_slice.objective_completed.connect(func(reason: String) -> void:
			status_label.text = reason.capitalize()
			_start_victory_return_countdown()
		)
	if economy_manager != null:
		economy_manager.resources_changed.connect(_on_resources_changed)
	if wave_director != null:
		wave_director.phase_changed.connect(_on_phase_changed)
		wave_director.wave_spawned.connect(_on_wave_spawned)
		wave_director.boss_spawned.connect(func() -> void:
			phase_label.text = "Boss: Mycelium Matriarch"
			status_label.text = "THE MYCELIUM MATRIARCH HAS ARRIVED"
			_show_alert("THE MYCELIUM MATRIARCH HAS ARRIVED")
		)
		wave_director.boss_defeated.connect(func() -> void:
			phase_label.text = "Victory"
			status_label.text = "The Mycelium Matriarch has been defeated."
			_start_victory_return_countdown()
		)
		_setup_ai_test_controls()
	_setup_map_generator_controls()
	if build_system != null and build_system.has_signal("build_rejected"):
		build_system.build_rejected.connect(_on_build_rejected)
		if build_system.has_signal("module_installed"):
			build_system.module_installed.connect(func(_player_id: int, archetype: StringName) -> void:
				var name := str(UnitCatalog.get_definition(archetype).get("display_name", str(archetype)))
				status_label.text = "%s installed in the Observation Tower (%s of %s slots free)" % [
					name, build_system.call("module_slots_free", 1), build_system.call("module_slots_total", 1)]
				_update_selection_panel(true)
			)
		build_system.structure_placed.connect(func(_player_id: int, archetype: StringName, _cell: Vector2i) -> void:
			status_label.text = "Building %s" % UnitCatalog.get_definition(archetype).get("display_name", archetype)
		)
		build_system.structure_completed.connect(func(_player_id: int, archetype: StringName, _cell: Vector2i) -> void:
			status_label.text = "%s complete" % UnitCatalog.get_definition(archetype).get("display_name", archetype)
		)
		build_system.unit_training_queued.connect(func(_player_id: int, _producer: Node, archetype: StringName, queue_count: int) -> void:
			status_label.text = "Queued %s (%s waiting)" % [UnitCatalog.get_definition(archetype).get("display_name", archetype), queue_count]
		)
		build_system.unit_produced.connect(func(_player_id: int, archetype: StringName, _cell: Vector2i) -> void:
			status_label.text = "Produced %s" % UnitCatalog.get_definition(archetype).get("display_name", archetype)
		)
		build_system.upgrade_researched.connect(func(_player_id: int, upgrade_id: StringName) -> void:
			status_label.text = "Researched %s" % _upgrade_name(upgrade_id)
			_update_selection_panel(true)
		)
	var command_dispatcher := get_node_or_null(NodePath("../CommandDispatcher"))
	if command_dispatcher != null and command_dispatcher.has_signal("order_partially_refused"):
		command_dispatcher.order_partially_refused.connect(func(obeyed: int, refused: int, reason: String) -> void:
			if obeyed > 0:
				status_label.text = "%s obeyed, %s refused - %s" % [obeyed, refused, reason]
			else:
				status_label.text = "Order refused - %s" % reason
			_show_alert("ORDER REFUSED" if obeyed == 0 else "PARTIAL ORDER")
		)
	if selection_controller != null:
		selection_controller.selection_changed.connect(func(_selected: Array[Node]) -> void:
			_update_selection_panel(true)
			_open_selected_vault()
		)
		# Control-group counts refresh on the manager's own signal (assign /
		# add / recall / a grouped unit dying), never from _process. At
		# hundreds of units a polled version of this strip would be exactly
		# the per-frame HUD cost the 2026-08-23 regression was about.
		if selection_controller.control_groups != null:
			selection_controller.control_groups.groups_changed.connect(_refresh_control_group_label)
	_refresh_control_group_label()
	_refresh()

func _process(_delta: float) -> void:
	if selection_label == null:
		return
	if _victory_return_remaining >= 0.0:
		_update_victory_return_countdown(_delta)
		return
	if selection_controller != null:
		selection_label.text = "Selected: %s" % selection_controller.selected_units.size()
		_update_selection_panel(false)
	if wave_director != null and wave_director.has_method("is_ai_testing_ground") and bool(wave_director.call("is_ai_testing_ground")):
		phase_label.text = "Kon's Siege Arena" if wave_director.has_method("is_fortress_ai_arena") and bool(wave_director.call("is_fortress_ai_arena")) else "AI Testing Ground"
		_update_ai_telemetry(_delta)
	elif map_generator != null and str(map_generator.get("map_type_id")) == "plot_generator_test":
		phase_label.text = "Plot Generator Test"
	elif map_generator != null and str(map_generator.get("map_type_id")) == "build_sandbox":
		# Nothing is coming, so do not count down to it. The grace-period line
		# would otherwise promise a first wave that never arrives.
		phase_label.text = "Build Sandbox | nothing is coming"
	elif wave_director != null and wave_director.has_method("is_in_grace_period") and bool(wave_director.call("is_in_grace_period")):
		# The grace period is the most important thing on screen while it lasts:
		# it is the only time the player can build without pressure.
		var grace_remaining := int(wave_director.call("get_grace_seconds_remaining"))
		phase_label.text = "Grace period | First wave in %s" % _format_time(grace_remaining)
		if grace_remaining <= 10 and not _grace_warning_shown:
			_grace_warning_shown = true
			_show_alert("THE FIRST WAVE IS COMING")
	elif wave_director != null and not wave_director.boss_has_spawned:
		var boss_remaining := wave_director.get_boss_seconds_remaining()
		phase_label.text = "Phase: %s | Boss in %s" % [str(wave_director.phase).capitalize(), _format_time(boss_remaining)]
		if boss_remaining <= 30 and not _boss_warning_shown:
			_boss_warning_shown = true
			_show_alert("BOSS INCOMING")
	if alert_label != null and alert_label.visible and Time.get_ticks_msec() > _alert_until_msec:
		alert_label.visible = false

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = 16
	root.offset_top = 12
	root.offset_right = -16
	add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	root.add_child(row)

	resource_label = _make_label()
	phase_label = _make_label()
	selection_label = _make_label()
	control_group_label = _make_label()
	var commands := _make_label()
	commands.text = "%s attack-move | %s patrol | %s hold | %s stop | %s wizard | %s army | %s idle barracks | %s idle unit | %s filter type | Ctrl+1-9 group | Alt+1-9 reinforce" % [
		KeybindManager.get_key_label(KeybindManager.ACTION_ATTACK_MOVE),
		KeybindManager.get_key_label(KeybindManager.ACTION_PATROL),
		KeybindManager.get_key_label(KeybindManager.ACTION_HOLD),
		KeybindManager.get_key_label(KeybindManager.ACTION_STOP),
		KeybindManager.get_key_label(KeybindManager.ACTION_SELECT_HERO),
		KeybindManager.get_key_label(KeybindManager.ACTION_SELECT_ARMY),
		KeybindManager.get_key_label(KeybindManager.ACTION_CYCLE_IDLE_PRODUCTION),
		KeybindManager.get_key_label(KeybindManager.ACTION_CYCLE_IDLE_UNIT),
		KeybindManager.get_key_label(KeybindManager.ACTION_CYCLE_SUBGROUP),
	]
	commands.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(resource_label)
	row.add_child(phase_label)
	row.add_child(selection_label)
	row.add_child(control_group_label)
	row.add_child(commands)
	commands.visible = _is_testing_mode()
	selection_label.visible = _is_testing_mode()

	alert_label = _make_label()
	alert_label.visible = false
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_size_override("font_size", 34)
	alert_label.add_theme_color_override("font_color", Color("#E85A5A"))
	alert_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	alert_label.offset_top = 72
	alert_label.offset_bottom = 118
	add_child(alert_label)

	var bottom := PanelContainer.new()
	command_dock = bottom
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -154
	bottom.offset_bottom = -12
	add_child(bottom)
	bottom.theme = preload("res://scripts/ui/observer_theme.gd").make()

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 14)
	bottom.add_child(bottom_row)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(360, 112)
	bottom_row.add_child(details)

	detail_name_label = _make_label()
	detail_name_label.add_theme_font_size_override("font_size", 18)
	detail_body_label = _make_label()
	detail_meta_label = _make_label()
	evolution_bar = ProgressBar.new()
	evolution_bar.custom_minimum_size = Vector2(320, 12)
	evolution_bar.visible = false
	evolution_bar.show_percentage = false
	evolution_label = _make_label()
	evolution_label.visible = false
	details.add_child(detail_name_label)
	details.add_child(detail_body_label)
	details.add_child(detail_meta_label)
	details.add_child(evolution_bar)
	details.add_child(evolution_label)

	var command_column := VBoxContainer.new()
	command_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(command_column)

	command_container = HFlowContainer.new()
	command_container.add_theme_constant_override("separation", 8)
	command_column.add_child(command_container)

	status_label = _make_label()
	status_label.text = "Kon: build with Bio. Bio Absorbers must go on pale economy spaces."
	command_column.add_child(status_label)

	ai_test_container = HBoxContainer.new()
	ai_test_container.add_theme_constant_override("separation", 8)
	ai_test_container.visible = false
	command_column.add_child(ai_test_container)

	map_tool_container = HBoxContainer.new()
	map_tool_container.add_theme_constant_override("separation", 8)
	map_tool_container.visible = false
	command_column.add_child(map_tool_container)

	ai_telemetry_label = _make_label()
	ai_telemetry_label.visible = false
	ai_telemetry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	command_column.add_child(ai_telemetry_label)

func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("#D6C7AE"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(92, 44)
	# HUD buttons never take keyboard focus. Without this, clicking a build
	# button hands focus to it, and Godot's built-in ui_focus_next consumes
	# Tab before _unhandled_input ever sees it (and Space/Enter re-fire the
	# button). Both are the classic RTS-HUD input-stealing bug.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _setup_ai_test_controls() -> void:
	if ai_test_container == null or wave_director == null:
		return
	if not wave_director.has_method("is_ai_testing_ground") or not bool(wave_director.call("is_ai_testing_ground")):
		return
	ai_test_container.visible = true
	ai_spawn_button = _add_button(ai_test_container, "Spawn AI Wave", _spawn_ai_test_wave)
	_add_button(ai_test_container, "Target 500", func() -> void: _queue_ai_test_until(500))
	_add_button(ai_test_container, "Target 1000", func() -> void: _queue_ai_test_until(1000))
	_add_button(ai_test_container, "Target 1500", func() -> void: _queue_ai_test_until(1500))
	_add_button(ai_test_container, "Unit Stats / Spawn", _open_unit_stat_window)
	if ai_telemetry_label != null:
		ai_telemetry_label.visible = true
	status_label.text = "Neutral observer mode. Spawn mirrored armies to test AI, pathing, targeting, and performance."

func _setup_map_generator_controls() -> void:
	if map_tool_container == null or map_generator == null:
		return
	var map_type := str(map_generator.get("map_type_id"))
	# The fog toggle is useful on EVERY map type, so it is added before the
	# seed tools bail out for map types that have none.
	_add_fog_toggle_button()
	_add_sandbox_tools()
	if map_type != "seeded_grid_frontier" and map_type != "plot_generator_test":
		return
	map_tool_container.visible = true
	if map_type == "plot_generator_test":
		_add_button(map_tool_container, "Generate Plot", _regenerate_plot_generator_test_map)
	else:
		_add_button(map_tool_container, "Generate Map", _regenerate_seeded_grid_map)
	_add_button(map_tool_container, "Keep Seed", _copy_seed_to_status)
	_copy_seed_to_status()

# Reveals the whole map for testing. Toggling it back restores what the player
# had genuinely explored rather than leaving the map permanently lit.
# Sandbox-only tools. They exist to make testing possible, so they appear only
# where testing is the point.
func _add_sandbox_tools() -> void:
	if map_generator == null or str(map_generator.get("map_type_id")) != "build_sandbox":
		return
	map_tool_container.visible = true
	var button := _add_button(map_tool_container, "Spawn Dummy", _spawn_target_dummy)
	button.tooltip_text = "A stationary enemy that cannot die. For testing weapons, range and vantage buffs."

func _spawn_target_dummy() -> void:
	if wave_director == null or not wave_director.has_method("spawn_target_dummy"):
		return
	var wizard := _player_wizard()
	var origin: Vector2i = Vector2i.ZERO
	if wizard != null and map_generator != null:
		origin = map_generator.call("world_to_cell", (wizard as Node2D).global_position) + Vector2i(6, 0)
	var cell: Vector2i = map_generator.call("nearest_walkable_cell", origin, 12)
	var dummy: Node = wave_director.call("spawn_target_dummy", cell, get_parent())
	status_label.text = "Target dummy spawned at %s" % cell if dummy != null else "Could not spawn a target dummy"

func _add_fog_toggle_button() -> void:
	var fog: Node = get_node_or_null("/root/MainMap/FogOfWar")
	if fog == null:
		fog = _find_fog_node()
	if fog == null or not fog.has_method("set_reveal_all"):
		return
	map_tool_container.visible = true
	_fog_button = _add_button(map_tool_container, "Reveal Map", func() -> void:
		var revealed := not bool(fog.call("is_reveal_all"))
		fog.call("set_reveal_all", revealed)
		_fog_button.text = "Hide Map" if revealed else "Reveal Map"
		status_label.text = "Fog of war revealed (testing)" if revealed else "Fog of war restored"
	)
	_fog_button.tooltip_text = "Testing: reveal the whole map, including enemies"

func _find_fog_node() -> Node:
	var parent := get_parent()
	while parent != null:
		var candidate := parent.get_node_or_null("FogOfWar")
		if candidate != null:
			return candidate
		parent = parent.get_parent()
	return null

func _regenerate_seeded_grid_map() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("start_new_game"):
		session.call("start_new_game", "", str(session.get("wizard_class_id")), "seeded_grid_frontier")
	get_tree().reload_current_scene()

func _regenerate_plot_generator_test_map() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("start_new_game"):
		session.call("start_new_game", "", str(session.get("wizard_class_id")), "plot_generator_test")
	get_tree().reload_current_scene()

func _copy_seed_to_status() -> void:
	if map_generator == null:
		return
	var seed_text := str(map_generator.get("map_seed_text"))
	var seed_label := seed_text if not seed_text.strip_edges().is_empty() else str(map_generator.get("seed_value"))
	var action := "Generate Plot" if str(map_generator.get("map_type_id")) == "plot_generator_test" else "Generate Map"
	status_label.text = "Map seed: %s | Press %s to roll and preview a replacement." % [seed_label, action]

func _spawn_ai_test_wave() -> void:
	if wave_director == null or not wave_director.has_method("spawn_ai_test_wave"):
		return
	var result: Dictionary = wave_director.call("spawn_ai_test_wave")
	if bool(result.get("accepted", true)):
		status_label.text = "AI test wave %s queued: west %s vs east %s | pending %s" % [result.get("wave", 0), result.get("west", 0), result.get("east", 0), result.get("queued", 0)]
	else:
		var reason := str(result.get("reason", "spawn queue full"))
		status_label.text = "AI wave rejected: %s | pending %s" % [reason.capitalize(), result.get("queued", 0)]
	_update_ai_telemetry(999.0)

func _queue_ai_test_until(target_live_units: int) -> void:
	if wave_director == null or not wave_director.has_method("queue_ai_test_until"):
		return
	var result: Dictionary = wave_director.call("queue_ai_test_until", target_live_units)
	status_label.text = "Benchmark target %s: queued %s units in %s waves | pending %s" % [
		result.get("target", target_live_units),
		result.get("queued_units", 0),
		result.get("queued_waves", 0),
		result.get("queued", 0),
	]
	_update_ai_telemetry(999.0)

func _open_unit_stat_window() -> void:
	if unit_stat_window == null or not is_instance_valid(unit_stat_window):
		unit_stat_window = _build_unit_stat_window()
		add_child(unit_stat_window)
	unit_stat_window.popup_centered_ratio(0.82)

func _build_unit_stat_window() -> Window:
	var window := Window.new()
	window.title = "Unit Stat Sheets"
	window.size = Vector2i(1120, 720)
	window.unresizable = false
	window.close_requested.connect(func() -> void:
		window.hide()
	)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	window.add_child(margin)
	var layout := HSplitContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.split_offset = 300
	margin.add_child(layout)

	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size = Vector2(280, 0)
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(roster_scroll)

	var roster := VBoxContainer.new()
	roster.name = "UnitStatRoster"
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.add_theme_constant_override("separation", 8)
	roster_scroll.add_child(roster)

	var details := ScrollContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(details)

	var detail_body := VBoxContainer.new()
	detail_body.name = "UnitStatDetails"
	detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_body.add_theme_constant_override("separation", 12)
	details.add_child(detail_body)

	var entries := _catalog_entries(false)
	_add_stat_roster_section(roster, "Units", entries, detail_body)
	_add_stat_roster_section(roster, "Buildings", _catalog_entries(true), detail_body)
	if not entries.is_empty():
		_show_unit_stat_card(entries[0], detail_body)
	return window

const INTELLIGENCE_COLORS := {
	1: Color("#E85A5A"),
	2: Color("#E0A857"),
	3: Color("#7BC47F"),
}

func _intelligence_color(level: int) -> Color:
	return INTELLIGENCE_COLORS.get(level, Color("#D6C7AE"))

func _control_text(archetype: StringName) -> String:
	var level := UnitCatalog.intelligence_of(archetype)
	var aggro := UnitCatalog.aggro_range_cells(archetype)
	return "Intelligence %s (%s) - %s   |   Aggro range %s cells (%s px)" % [
		level,
		UnitCatalog.intelligence_label(level),
		UnitCatalog.intelligence_description(level, aggro),
		aggro,
		aggro * 64,
	]

func _build_card_portrait(archetype: StringName) -> Control:
	var path := UnitCatalog.card_portrait_path(archetype)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	var frame := PanelContainer.new()
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(132, 132)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(rect)
	return frame

func _build_tier_badge(archetype: StringName, definition: Dictionary) -> Control:
	if not definition.has("tier"):
		return null
	var tier := UnitCatalog.tier_of(archetype)
	var badge := _make_label()
	badge.text = str(TIER_LABELS.get(tier, "Tier %s" % tier))
	badge.add_theme_font_size_override("font_size", 14)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var locked := _tier_is_locked(archetype)
	badge.add_theme_color_override("font_color", Color("#8A7F70") if locked else _kon_theme_color(archetype))
	if locked:
		badge.text += "  [LOCKED]"
	return badge

func _tier_is_locked(archetype: StringName) -> bool:
	if build_system == null or not build_system.has_method("unlocked_tier"):
		return false
	var tier := UnitCatalog.tier_of(archetype)
	if tier <= UnitCatalog.TIER_1 or tier > UnitCatalog.MAX_TRAINABLE_TIER:
		return false
	return tier > int(build_system.call("unlocked_tier", 1))

# The parts of a unit card that only some units have: weapon modes, and where
# this unit sits in an evolution chain. Both are read straight off the catalog
# so a new unit gets them for free.
func _card_extra_text(archetype: StringName, definition: Dictionary) -> String:
	var parts: Array[String] = []
	var modes := UnitCatalog.weapon_modes(archetype)
	if not modes.is_empty():
		var mode_parts: Array[String] = []
		for key in modes.keys():
			var mode: Dictionary = modes[key]
			mode_parts.append("%s (%s dmg / %s rng)" % [
				str(mode.get("display_name", key)),
				mode.get("attack_damage", 0),
				mode.get("attack_range_cells", 0),
			])
		parts.append("Weapons: " + "  |  ".join(mode_parts))
	var evolves_to := StringName(definition.get("evolves_to", &""))
	if not str(evolves_to).is_empty():
		parts.append("Evolves into %s at %s XP" % [
			str(UnitCatalog.get_definition(evolves_to).get("display_name", evolves_to)),
			int(definition.get("evolution_xp_required", 0)),
		])
	var max_evolution := int(definition.get("max_evolution_level", 0))
	if max_evolution > 1:
		parts.append("Grows through %s evolution stages" % max_evolution)
	if bool(definition.get("uncontrollable", false)):
		parts.append("UNCONTROLLABLE -- obeys no player, attacks everything")
	return "\n".join(parts)

func _catalog_entries(structures: bool) -> Array[StringName]:
	var entries: Array[StringName] = []
	for key in UnitCatalog.DEFINITIONS.keys():
		var archetype := StringName(key)
		var definition := UnitCatalog.get_definition(archetype)
		var is_structure := definition.has("footprint") or definition.has("build_time_seconds") or definition.has("income_per_tick") or definition.has("production")
		if is_structure == structures:
			entries.append(archetype)
	entries.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(UnitCatalog.get_definition(a).get("display_name", a)) < str(UnitCatalog.get_definition(b).get("display_name", b))
	)
	return entries

func _add_stat_section(parent: VBoxContainer, title: String, entries: Array[StringName]) -> void:
	var title_label := _make_label()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("#7DDDE8") if title == "Units" else Color("#D6C7AE"))
	parent.add_child(title_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	for archetype in entries:
		grid.add_child(_build_stat_card(archetype))

func _add_stat_roster_section(parent: VBoxContainer, title: String, entries: Array[StringName], detail_body: VBoxContainer) -> void:
	if entries.is_empty():
		return
	var title_label := _make_label()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("#7DDDE8") if title == "Units" else Color("#D6C7AE"))
	parent.add_child(title_label)
	for archetype in entries:
		var definition := UnitCatalog.get_definition(archetype)
		var button := Button.new()
		button.name = "UnitStat_%s" % str(archetype)
		button.text = str(definition.get("display_name", archetype))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(240, 38)
		button.tooltip_text = str(archetype)
		button.pressed.connect(_show_unit_stat_card.bind(archetype, detail_body))
		parent.add_child(button)

# --- the observer's ledger --------------------------------------------------

const LEDGER_GAIN := Color("#7BC47F")
const LEDGER_LOSS := Color("#E0A857")
const LEDGER_MUTED := Color("#8A9AA6")
const LEDGER_LOCKED := Color("#E85A5A")

# One unit's record for THIS run: how far its numbers have moved, what moved
# them, what it turns into, and whether you can field it at all.
func _build_ledger_panel(ledger: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)

	var header := Label.new()
	header.text = "Observer's Ledger"
	header.add_theme_font_size_override("font_size", 20)
	body.add_child(header)

	var census := int(ledger.get("field", 0))
	var standing := Label.new()
	standing.add_theme_font_size_override("font_size", 14)
	# The census is the only line about right now rather than about the run.
	standing.text = "%d in the field" % census if census > 0 else "None in the field"
	standing.add_theme_color_override("font_color", LEDGER_MUTED)
	body.add_child(standing)

	var availability: Dictionary = ledger.get("availability", {})
	if not bool(availability.get("available", true)):
		var locked := Label.new()
		locked.text = "Unavailable -- %s" % str(availability.get("reason", ""))
		locked.add_theme_color_override("font_color", LEDGER_LOCKED)
		body.add_child(locked)

	body.add_child(_build_ledger_stats(ledger))

	var changes: Array = ledger.get("changes", [])
	if changes.is_empty():
		var untouched := Label.new()
		untouched.text = "Unmodified. Nothing this run has changed it yet."
		untouched.add_theme_color_override("font_color", LEDGER_MUTED)
		untouched.add_theme_font_size_override("font_size", 14)
		body.add_child(untouched)
	else:
		for change in changes:
			body.add_child(_build_ledger_change(change))

	var lineage_row := _build_ledger_lineage(ledger.get("lineage", {}), ledger)
	if lineage_row != null:
		body.add_child(lineage_row)
	return panel

# Base and current side by side, and only where they differ does anything shout.
func _build_ledger_stats(ledger: Dictionary) -> Control:
	var base: Dictionary = ledger.get("base", {})
	var live: Dictionary = ledger.get("live", {})
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	for row in [
		["Health", "max_health", false],
		["Damage", "attack_damage", false],
		["Regen/s", "regeneration_per_second", true],
	]:
		var key := str(row[1])
		var is_float := bool(row[2])
		var from_value := float(base.get(key, 0))
		var to_value := float(live.get(key, 0))
		if from_value == 0.0 and to_value == 0.0:
			continue
		var name_label := Label.new()
		name_label.text = str(row[0])
		name_label.add_theme_color_override("font_color", LEDGER_MUTED)
		grid.add_child(name_label)
		var value_label := Label.new()
		value_label.text = ("%.0f" % to_value) if not is_float else ("%.1f" % to_value)
		grid.add_child(value_label)
		var delta_label := Label.new()
		if is_equal_approx(from_value, to_value):
			delta_label.text = "-"
			delta_label.add_theme_color_override("font_color", LEDGER_MUTED)
		else:
			var delta := to_value - from_value
			delta_label.text = "%s%s from %s" % [
				"+" if delta > 0.0 else "",
				("%.0f" % delta) if not is_float else ("%.1f" % delta),
				("%.0f" % from_value) if not is_float else ("%.1f" % from_value)]
			delta_label.add_theme_color_override("font_color",
				LEDGER_GAIN if delta > 0.0 else LEDGER_LOSS)
		grid.add_child(delta_label)
	return grid

# Provenance. The point of the whole screen: not that it is stronger, but what
# made it stronger, so the next purchase is an informed one.
func _build_ledger_change(change: Dictionary) -> Control:
	var row := VBoxContainer.new()
	var title := Label.new()
	title.text = "%s   %s" % [str(change.get("label", "")), str(change.get("effect", ""))]
	title.add_theme_color_override("font_color", LEDGER_GAIN)
	row.add_child(title)
	var note := str(change.get("note", ""))
	if note != "":
		var flavour := Label.new()
		flavour.text = note
		flavour.add_theme_font_size_override("font_size", 13)
		flavour.add_theme_color_override("font_color", LEDGER_MUTED)
		row.add_child(flavour)
	return row

# What it was and what it becomes -- the arc of the run rather than of the unit.
func _build_ledger_lineage(lineage: Dictionary, ledger: Dictionary) -> Control:
	var came_from := StringName(lineage.get("from", &""))
	var becomes: Array = lineage.get("to", [])
	if came_from == &"" and becomes.is_empty():
		return null
	var chain: Array[String] = []
	if came_from != &"":
		chain.append(str(UnitCatalog.get_definition(came_from).get("display_name", str(came_from))))
	chain.append(str(ledger.get("display_name", "")))
	for step in becomes:
		chain.append(str(UnitCatalog.get_definition(step).get("display_name", str(step))))
	var label := Label.new()
	label.text = "Lineage:  " + "  ->  ".join(chain)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", LEDGER_MUTED)
	if bool(ledger.get("evolves_on_its_own", false)):
		label.text += "   (evolves on its own, every %ds)" % int(ledger.get("evolution_seconds", 0.0))
	return label

func _show_unit_stat_card(archetype: StringName, detail_body: VBoxContainer) -> void:
	for child in detail_body.get_children():
		detail_body.remove_child(child)
		child.queue_free()
	detail_body.add_child(_build_stat_card(archetype))
	# The run's own record, above the catalog sheet: what has happened to this
	# unit since the run started, and what caused it.
	var ledger := RosterLedger.entry_for(archetype, build_system, rts_world)
	if not ledger.is_empty():
		detail_body.add_child(_build_ledger_panel(ledger))
		detail_body.move_child(detail_body.get_child(detail_body.get_child_count() - 1), 0)
	if _is_testing_mode() and _is_spawnable_test_unit(archetype):
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		detail_body.add_child(actions)
		var spawn_button := _add_button(actions, "Spawn Test Unit", func() -> void:
			_spawn_ai_test_unit(archetype)
		)
		spawn_button.custom_minimum_size = Vector2(160, 44)
		var hint := _make_label()
		hint.text = "Spawns as neutral observer test faction near the arena center."
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		actions.add_child(hint)
	var definition := UnitCatalog.get_definition(archetype)
	var breakdown := _make_label()
	breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	breakdown.text = _unit_stat_breakdown(archetype, definition)
	detail_body.add_child(breakdown)

func _build_stat_card(archetype: StringName) -> Control:
	var definition := UnitCatalog.get_definition(archetype)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 156)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	card.add_child(card_row)
	var portrait := _build_card_portrait(archetype)
	if portrait != null:
		card_row.add_child(portrait)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	card_row.add_child(box)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	box.add_child(header_row)
	var header := _make_label()
	header.text = str(definition.get("display_name", archetype))
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", _stat_accent(archetype))
	header_row.add_child(header)
	var badge := _build_tier_badge(archetype, definition)
	if badge != null:
		header_row.add_child(badge)
	var blurb_text := str(definition.get("card_blurb", ""))
	if not blurb_text.is_empty():
		var blurb := _make_label()
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.add_theme_font_size_override("font_size", 14)
		blurb.add_theme_color_override("font_color", Color("#A79880"))
		blurb.text = blurb_text
		box.add_child(blurb)
	var meta := _make_label()
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.text = _stat_meta_text(archetype, definition)
	box.add_child(meta)
	var combat := _make_label()
	combat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat.text = _combat_text(archetype, definition)
	box.add_child(combat)
	# Intelligence and aggro range get their own line, above the flavour text.
	# Design doc section 38: a control level is a cost, and costs must be legible
	# before purchase.
	var control := _make_label()
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.add_theme_color_override("font_color", _intelligence_color(UnitCatalog.intelligence_of(archetype)))
	control.text = _control_text(archetype)
	box.add_child(control)
	var extra := _card_extra_text(archetype, definition)
	if not extra.is_empty():
		var extra_label := _make_label()
		extra_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		extra_label.add_theme_color_override("font_color", _kon_theme_color(archetype))
		extra_label.text = extra
		box.add_child(extra_label)
	var role := _make_label()
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.text = _role_text(archetype, definition)
	box.add_child(role)
	return card

func _stat_meta_text(archetype: StringName, definition: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("Archetype %s" % str(archetype))
	# Fielded HP, not the raw catalog number. An evolved form is created by
	# _evolve(), which applies a growth multiplier on top of its catalog entry --
	# so the card used to understate every evolved unit by ~24% HP.
	var fielded_hp := UnitCatalog.fielded_max_hp(archetype)
	if UnitCatalog.is_evolved_form(archetype):
		parts.append("HP %s (base %s +growth)" % [fielded_hp, int(definition.get("max_hp", 0))])
	else:
		parts.append("HP %s" % fielded_hp)
	if definition.has("armor") or definition.has("magic_armor"):
		parts.append("Armor %s" % int(definition.get("armor", 0)))
		parts.append("Magic %s" % int(definition.get("magic_armor", 0)))
	if definition.has("cost_bio"):
		parts.append("Cost %s Bio" % int(definition.get("cost_bio", 0)))
	if definition.has("train_time_seconds"):
		parts.append("Train %.1fs" % float(definition.get("train_time_seconds", 0.0)))
	if definition.has("build_time_seconds"):
		parts.append("Build %.1fs" % float(definition.get("build_time_seconds", 0.0)))
	if definition.has("footprint"):
		var footprint: Vector2i = definition.get("footprint")
		parts.append("Footprint %sx%s" % [footprint.x, footprint.y])
	return " | ".join(parts)

func _combat_text(archetype: StringName, definition: Dictionary) -> String:
	var weapon := WeaponCatalog.get_weapon(archetype)
	var range_cells := int(definition.get("attack_range_cells", 0))
	var cooldown := float(definition.get("attack_speed_seconds", float(definition.get("attack_cooldown_ticks", 0)) / 20.0))
	var parts: Array[String] = []
	var casts := int(weapon.get("casts", 1))
	var damage := UnitCatalog.fielded_attack_damage(archetype)
	parts.append("Type %s" % str(definition.get("attack_type", weapon.get("kind", &"none"))).replace("_", " ").capitalize())
	if UnitCatalog.is_evolved_form(archetype):
		parts.append("Damage %s (base %s +growth)" % [damage, int(definition.get("attack_damage", 0))])
	else:
		parts.append("Damage %s" % damage)
	parts.append("Range %s (%s px)" % [range_cells, range_cells * 64])
	if cooldown > 0.0:
		parts.append("Cooldown %.2fs" % cooldown)
		# Derived, because damage-per-hit alone hides that the blowpipe is half
		# the DPS of the spear, and that Kon's double cast doubles his output.
		parts.append("DPS %.1f" % (float(damage * maxi(1, casts)) / cooldown))
	if casts > 1:
		parts.append("Casts %s" % casts)
	if weapon.has("aoe_radius"):
		parts.append("AoE %s px" % int(weapon.get("aoe_radius", 0)))
	elif float(definition.get("attack_splash_radius_cells", 0.0)) > 0.0:
		parts.append("Splash %.1f cells" % float(definition.get("attack_splash_radius_cells", 0.0)))
	return " | ".join(parts)

func _unit_stat_breakdown(archetype: StringName, definition: Dictionary) -> String:
	var weapon := WeaponCatalog.get_weapon(archetype)
	var lines: Array[String] = []
	lines.append("Combat profile")
	lines.append("Damage: %s | Range: %s cells (%s px) | Cooldown: %.2fs | Weapon: %s" % [
		UnitCatalog.fielded_attack_damage(archetype),
		int(definition.get("attack_range_cells", 0)),
		int(definition.get("attack_range_cells", 0)) * 64,
		float(definition.get("attack_speed_seconds", float(definition.get("attack_cooldown_ticks", 0)) / 20.0)),
		str(definition.get("attack_type", weapon.get("kind", &"none"))).replace("_", " ").capitalize(),
	])
	lines.append("Durability: HP %s | Armor %s | Magic armor %s" % [
		UnitCatalog.fielded_max_hp(archetype),
		int(definition.get("armor", 0)),
		int(definition.get("magic_armor", 0)),
	])
	# Armour is flat subtraction with a floor of 1 (RTSUnit.take_damage), which
	# is by far the least obvious rule in the stat system -- Armor 5 removes 71%
	# of a 7-damage hit and 13% of a 38-damage one. Spelled out rather than left
	# for the player to reverse-engineer.
	lines.append("Control: %s" % _control_text(archetype))
	if int(definition.get("armor", 0)) > 0 or int(definition.get("magic_armor", 0)) > 0:
		lines.append("Armor subtracts flat damage per hit (minimum 1 gets through). Magic armor applies to poison and other magic damage only.")
	if weapon.has("projectile_speed"):
		lines.append("Projectile speed: %s" % int(weapon.get("projectile_speed", 0)))
	if weapon.has("aoe_radius"):
		lines.append("Area damage radius: %s px" % int(weapon.get("aoe_radius", 0)))
	lines.append("")
	lines.append("Economy and production")
	# "Bio value" used to read a `bio_value` catalog key that exists on no
	# archetype, so it always printed 0. Now the real salvage formula, shared
	# with RTSUnit.salvage_value().
	lines.append("Bio cost: %s | Salvage value: %s Bio" % [
		int(definition.get("cost_bio", 0)),
		UnitCatalog.salvage_value_for(archetype),
	])
	if definition.has("train_time_seconds"):
		lines.append("Train time: %.1fs" % float(definition.get("train_time_seconds", 0.0)))
	if definition.has("build_time_seconds"):
		lines.append("Build time: %.1fs" % float(definition.get("build_time_seconds", 0.0)))
	if definition.has("income_per_tick"):
		lines.append("Income per tick: %s Bio" % int(definition.get("income_per_tick", 0)))
	lines.append("")
	lines.append("Framework hooks")
	lines.append(_role_text(archetype, definition))
	if definition.has("animation_profile"):
		var profile: Dictionary = definition.get("animation_profile")
		var actions: Array[String] = []
		for action in profile.get("actions", []):
			actions.append(str(action))
		lines.append("Animation: %s px frames | %s directions | %s" % [
			str(profile.get("frame_size", Vector2i.ZERO)),
			int(profile.get("directions", 0)),
			", ".join(actions),
		])
	return "\n".join(lines)

func _role_text(_archetype: StringName, definition: Dictionary) -> String:
	var notes: Array[String] = []
	if definition.has("role"):
		notes.append(str(definition.get("role", "")))
	if definition.has("passives"):
		var passives: Array[String] = []
		for passive in definition.get("passives", []):
			passives.append(str(passive))
		if not passives.is_empty():
			notes.append("Passives: %s" % ", ".join(passives))
	if definition.has("actives"):
		var actives: Array[String] = []
		for active in definition.get("actives", []):
			actives.append(str(active))
		if not actives.is_empty():
			notes.append("Actives: %s" % ", ".join(actives))
	if definition.has("evolves_to"):
		var evolves_to := StringName(definition.get("evolves_to", &""))
		notes.append("Evolves to %s at %s XP" % [UnitCatalog.get_definition(evolves_to).get("display_name", evolves_to), int(definition.get("evolution_xp_required", 0))])
	if definition.has("heal_per_attack"):
		notes.append("Heals %s on attack" % int(definition.get("heal_per_attack", 0)))
	if definition.has("hunt_charge_seconds"):
		notes.append("Hunt charge every %.0fs: next attack x%.1f range and x%.1f damage" % [
			float(definition.get("hunt_charge_seconds", 0.0)),
			float(definition.get("hunt_range_multiplier", 1.0)),
			float(definition.get("hunt_damage_multiplier", 1.0)),
		])
	if definition.has("grapple_aoe_radius"):
		notes.append("Grapple roots nearby enemies in %s px" % int(definition.get("grapple_aoe_radius", 0.0)))
	if definition.has("consume_ally_heals"):
		notes.append("Consume Ally heals this unit")
	if definition.has("production"):
		var produced: Array[String] = []
		for item in definition.get("production", []):
			var produced_archetype := StringName(item)
			produced.append(str(UnitCatalog.get_definition(produced_archetype).get("display_name", produced_archetype)))
		notes.append("Produces %s" % ", ".join(produced))
	if definition.has("upgrade_choices"):
		var upgrade_names: Array[String] = []
		for upgrade in definition.get("upgrade_choices", []):
			upgrade_names.append(str(upgrade).capitalize())
		notes.append("Upgrade choice %s" % ", ".join(upgrade_names))
	if bool(definition.get("ignores_terrain", false)):
		notes.append("Ignores terrain")
	if notes.is_empty():
		return "Role framework: baseline combat unit/building."
	return " | ".join(notes)

# KoN's duo theme, from the roster doc: observer = silver, evolution = #67BED9
# with an #a95766 warm accent, and the Biospawner is the single crossover.
const KON_THEME_COLORS := {
	&"observer": Color("#C9CDD4"),
	&"evolution": Color("#67BED9"),
	&"crossover": Color("#A95766"),
}
const TIER_LABELS := {
	0: "Hero",
	1: "Tier 1",
	2: "Tier 2",
	3: "Tier 3",
	4: "Tier 4",
}

func _kon_theme_color(archetype: StringName) -> Color:
	return KON_THEME_COLORS.get(UnitCatalog.kon_theme(archetype), Color("#D6C7AE"))

func _stat_accent(archetype: StringName) -> Color:
	match archetype:
		&"life_wizard", &"horror", &"hunter", &"evangalion_wizard":
			return Color("#7DDDE8")
		&"fire_wizard", &"bloodcap_runner", &"vampire_mushroom_thrall", &"spore_spitter", &"bloodcap_brute":
			return Color("#E85A5A")
		&"deom_scout", &"deom_blade", &"deom_crosshirran", &"deom_hammer", &"deom_glaive", &"deom_odden":
			return Color("#F0D487")
		&"terrible_thing", &"gripper", &"awful_thing", &"apex", &"champion", &"apex_predator", &"spawner", &"winged_spawner", &"spawner_drone", &"stone_face_serpent", &"bio_absorber", &"vinewall", &"bio_launcher":
			return Color("#7BC47F")
	return Color("#D6C7AE")

func _update_ai_telemetry(delta: float) -> void:
	if ai_telemetry_label == null or not ai_telemetry_label.visible:
		return
	_telemetry_elapsed += delta
	if _telemetry_elapsed < 0.5:
		return
	_telemetry_elapsed = 0.0
	var world_stats: Dictionary = rts_world.get_observation_telemetry() if rts_world != null and rts_world.has_method("get_observation_telemetry") else {}
	var path_stats: Dictionary = map_generator.get_path_telemetry() if map_generator != null and map_generator.has_method("get_path_telemetry") else {}
	var spawn_stats: Dictionary = wave_director.get_ai_test_spawn_telemetry() if wave_director != null and wave_director.has_method("get_ai_test_spawn_telemetry") else {}
	var combat_stats: Dictionary = combat_system.get_combat_telemetry() if combat_system != null and combat_system.has_method("get_combat_telemetry") else {}
	var collision_stats: Dictionary = RTSUnit.get_mass_collision_telemetry()
	var owners: Dictionary = world_stats.get("owner_counts", {})
	var damage_by_owner: Dictionary = world_stats.get("damage_by_owner", {})
	var owner_2_units := int(owners.get(2, 0))
	var owner_3_units := int(owners.get(3, 0))
	var live_units := int(world_stats.get("units", 0))
	var mass_sim := live_units >= 120
	var owner_2_damage := int(damage_by_owner.get(2, 0))
	var owner_3_damage := int(damage_by_owner.get(3, 0))
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms := 1000.0 / maxf(1.0, fps)
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var pending_spawns := int(spawn_stats.get("spawn_queue", 0))
	if ai_spawn_button != null:
		ai_spawn_button.disabled = pending_spawns >= int(spawn_stats.get("spawn_queue_limit", 640))
		ai_spawn_button.text = "Queueing..." if pending_spawns > 0 else "Spawn AI Wave"
	ai_telemetry_label.text = "Live %s M:%s A:%s  |  Pending %s @ %s/%s frame %s/s  |  MassSim %s  |  West %s / East %s  |  Peak %s  |  Damage W:%s E:%s Total:%s  |  Proj %s active %s/s total %s  |  Combat %sms avgCand %.1f  |  Coll calls %s neigh %s  |  Paths %s/s total %s cache %s  |  FPS %.0f frame %.1fms process %.1fms physics %.1fms nodes %s" % [
		live_units,
		int(world_stats.get("moving_units", 0)),
		int(world_stats.get("attacking_units", 0)),
		pending_spawns,
		int(spawn_stats.get("effective_spawn_budget_per_frame", 0)),
		int(spawn_stats.get("spawn_budget_per_frame", 0)),
		int(spawn_stats.get("spawned_per_second", 0)),
		"ON" if mass_sim else "OFF",
		owner_2_units,
		owner_3_units,
		int(world_stats.get("peak_units", 0)),
		owner_2_damage,
		owner_3_damage,
		int(world_stats.get("damage_total", 0)),
		int(world_stats.get("active_projectiles", 0)),
		int(world_stats.get("projectiles_spawned_per_second", 0)),
		int(world_stats.get("projectiles_spawned", 0)),
		snapped(float(combat_stats.get("combat_tick_ms", 0.0)), 0.1),
		float(combat_stats.get("combat_avg_candidates", 0.0)),
		int(collision_stats.get("mass_collision_calls", 0)),
		int(collision_stats.get("mass_collision_neighbors", 0)),
		int(path_stats.get("path_requests_per_second", 0)),
		int(path_stats.get("path_requests", 0)),
		int(path_stats.get("path_cache_size", 0)),
		fps,
		frame_ms,
		process_ms,
		physics_ms,
		nodes,
	]

func _refresh_control_group_label() -> void:
	if control_group_label == null:
		return
	if selection_controller == null or selection_controller.control_groups == null:
		control_group_label.text = ""
		return
	var groups: ControlGroupManager = selection_controller.control_groups
	var reinforce := groups.reinforce_group()
	var parts: Array[String] = []
	for index in range(1, ControlGroupManager.GROUP_COUNT + 1):
		var size := groups.count(index)
		if size <= 0:
			continue
		parts.append("%s%s:%s" % [index, "*" if index == reinforce else "", size])
	if parts.is_empty():
		control_group_label.text = "Groups: none (Ctrl+1-9 to assign)"
		return
	control_group_label.text = "Groups: %s%s" % [
		"  ".join(parts),
		"   * = reinforce" if reinforce != ControlGroupManager.NO_REINFORCE_GROUP else "",
	]

func _clear_commands() -> void:
	if command_container == null:
		return
	for child in command_container.get_children():
		child.queue_free()

func _update_selection_panel(force_rebuild: bool) -> void:
	if selection_controller == null or detail_name_label == null:
		return
	var selected := _valid_selection()
	var signature := _selection_signature(selected)
	if force_rebuild or signature != _last_selection_signature:
		_last_selection_signature = signature
		_rebuild_context_commands(selected)
	_update_selection_details(selected)
	if get_node("/root/GameSession").wizard_class_id == "bad_kon_willow" and not _is_testing_mode():
		detail_body_label.hide()
		detail_meta_label.hide()
		evolution_bar.hide()
		evolution_label.hide()
		detail_name_label.get_parent().custom_minimum_size = Vector2(180, 0)
		command_dock.visible = not selected.is_empty()
		command_dock.offset_top = -maxf(78, command_dock.get_combined_minimum_size().y + 12)
		control_group_label.visible = not control_group_label.text.begins_with("Groups: none")
		map_tool_container.hide()
		ai_telemetry_label.hide()
		if selected.is_empty():
			detail_name_label.text = ""

func _open_selected_vault() -> void:
	if not is_instance_valid(observer_vault):
		return
	var selected := _valid_selection()
	if selected.size() == 1 and _archetype_for(selected[0]) == &"terrible_vault":
		observer_vault.open_archive(selected[0], build_system, rts_world)

func _valid_selection() -> Array[Node]:
	var selected: Array[Node] = []
	if selection_controller == null:
		return selected
	for node in selection_controller.selected_units:
		if is_instance_valid(node):
			selected.append(node)
	return selected

func _selection_signature(selected: Array[Node]) -> String:
	# Runs every frame for every selected unit -- must stay allocation/reflection-light.
	# _has_property()'s get_property_list() scan was here originally and is real,
	# measurable per-frame cost with a large selection; archetype is already computed
	# below and a wizard's archetype is one of exactly 3 known values, so a plain
	# string check plus a couple of safe (reflection-free) get() reads replaces it.
	var parts: Array[String] = []
	for node in selected:
		var archetype := _archetype_for(node)
		var extra := ""
		if archetype == &"life_wizard" or archetype == &"fire_wizard" or archetype == &"evangalion_wizard":
			extra = ":lvl%s:%s" % [str(node.get("wizard_level")), str(node.get("pending_level_up"))]
		parts.append("%s:%s%s" % [node.get_instance_id(), str(archetype), extra])
	return "|".join(parts)

func _update_selection_details(selected: Array[Node]) -> void:
	if selected.is_empty():
		detail_name_label.text = "No selection"
		detail_body_label.text = "Select units or buildings to inspect them."
		detail_meta_label.text = ""
		_set_evolution_bar(null)
		return
	if selected.size() > 1:
		detail_name_label.text = "%s selected" % selected.size()
		detail_body_label.text = _mixed_selection_summary(selected)
		detail_meta_label.text = "%s attack-move | %s patrol | %s hold | %s stop | %s filter by type | Ctrl+1-9 assign group" % [
			KeybindManager.get_key_label(KeybindManager.ACTION_ATTACK_MOVE),
			KeybindManager.get_key_label(KeybindManager.ACTION_PATROL),
			KeybindManager.get_key_label(KeybindManager.ACTION_HOLD),
			KeybindManager.get_key_label(KeybindManager.ACTION_STOP),
			KeybindManager.get_key_label(KeybindManager.ACTION_CYCLE_SUBGROUP),
		]
		_set_evolution_bar(null)
		return
	var node := selected[0]
	var archetype := _archetype_for(node)
	var definition := UnitCatalog.get_definition(archetype)
	var display_name := str(definition.get("display_name", str(archetype)))
	var max_hp := int(_property_or(node, "max_health", int(definition.get("max_hp", 0))))
	var hp := int(_property_or(node, "health", max_hp))
	var level := int(_property_or(node, "level", _property_or(node, "evolution_level", 1)))
	detail_name_label.text = "%s  Lv%s" % [display_name, level]
	if _is_structure(node):
		var complete := bool(node.get("complete"))
		var build_progress := float(node.get("build_progress"))
		var build_time := float(node.get("build_time"))
		var build_text := "Complete" if complete else "Building %.0f%%" % [100.0 * build_progress / maxf(build_time, 0.01)]
		var train_text := _training_text_for(node)
		detail_body_label.text = "HP %s/%s | %s | Footprint %sx%s%s" % [hp, max_hp, build_text, int(node.get("footprint").x), int(node.get("footprint").y), train_text]
		_set_evolution_bar(null)
	else:
		var state := str(node.get("unit_state")).capitalize()
		var armor := int(_property_or(node, "armor", int(definition.get("armor", 0))))
		var magic_armor := int(_property_or(node, "magic_armor", int(definition.get("magic_armor", 0))))
		var weapon_text := ""
		if node.has_method("has_weapon_modes") and bool(node.call("has_weapon_modes")):
			weapon_text = " | %s" % str(node.call("weapon_mode_display_name"))
		# Live value, not the catalog one -- research can have raised it.
		var live_intelligence := int(_property_or(node, "intelligence", UnitCatalog.intelligence_of(archetype)))
		weapon_text += " | Int %s (%s)" % [live_intelligence, UnitCatalog.intelligence_label(live_intelligence)]
		detail_body_label.text = "HP %s/%s | Armor %s | Magic %s | %s%s | Bio value %s" % [hp, max_hp, armor, magic_armor, state, weapon_text, _salvage_for(node)]
		_set_evolution_bar(node)
	var damage := int(definition.get("attack_damage", 0))
	var range := int(definition.get("attack_range_cells", 0))
	var cost := int(definition.get("cost_bio", 0))
	var speed := float(definition.get("attack_speed_seconds", float(definition.get("attack_cooldown_ticks", 0)) / 20.0))
	var attack_type := str(definition.get("attack_type", "none")).replace("_", " ").capitalize()
	if archetype in [&"mangler", &"winged_mangler"]:
		detail_meta_label.text = "Melee %s | Momentum %s/5 | Speed +%s%%%s" % [node.attack_damage, node.momentum_stacks, node.momentum_stacks*8, " | Leap %.1fs" % node.leap_remaining if archetype==&"winged_mangler" else ""]
		return
	if archetype == &"stone_face_serpent":
		var disarmed := bool(node.get("_stone_form_active"))
		var live_range := 0.0 if disarmed else float(node.get("attack_range"))/64.0
		detail_meta_label.text = "%s | Damage %s | Range %.2f | Speed %.2fs | Cost %s Bio" % ["Disarmed wall" if disarmed else "Poison melee",node.get("attack_damage"),live_range,speed,cost]
		return
	detail_meta_label.text = "%s | Damage %s | Range %s | Speed %.2fs | Cost %s Bio" % [attack_type, damage, range, speed, cost]

func _set_evolution_bar(node: Node) -> void:
	if evolution_bar == null or evolution_label == null:
		return
	if node == null or not is_instance_valid(node) or not node.has_method("get_evolution_progress"):
		evolution_bar.visible = false
		evolution_label.visible = false
		return
	var progress: Dictionary = node.call("get_evolution_progress")
	var needed := float(progress.get("needed", 0.0))
	if needed <= 0.0:
		evolution_bar.visible = false
		evolution_label.visible = false
		return
	var xp := float(progress.get("xp", 0.0))
	evolution_bar.visible = true
	evolution_label.visible = true
	evolution_bar.min_value = 0.0
	evolution_bar.max_value = needed
	evolution_bar.value = clampf(xp, 0.0, needed)
	var evolves_to := StringName(progress.get("evolves_to", &""))
	var target_name := str(UnitCatalog.get_definition(evolves_to).get("display_name", evolves_to)) if not str(evolves_to).is_empty() else "next mutation"
	evolution_label.text = "Evolution %.0f/%.0f -> %s" % [xp, needed, target_name]

func _mixed_selection_summary(selected: Array[Node]) -> String:
	var counts: Dictionary = {}
	var hp := 0
	var max_hp := 0
	for node in selected:
		var name := str(UnitCatalog.get_definition(_archetype_for(node)).get("display_name", str(_archetype_for(node))))
		counts[name] = int(counts.get(name, 0)) + 1
		if _has_property(node, "health"):
			hp += int(node.get("health"))
		if _has_property(node, "max_health"):
			max_hp += int(node.get("max_health"))
	var parts: Array[String] = []
	for key in counts.keys():
		parts.append("%sx %s" % [counts[key], key])
	return "%s | HP %s/%s" % [", ".join(parts), hp, max_hp]

func _training_text_for(node: Node) -> String:
	if not _has_property(node, "training_archetype"):
		return ""
	var training_archetype: StringName = node.get("training_archetype")
	var queue_count := int(_property_or(node, "production_queue_count", 0))
	if str(training_archetype).is_empty():
		return " | Queue %s" % queue_count if queue_count > 0 else ""
	var progress := float(_property_or(node, "training_progress", 0.0))
	var train_time := float(_property_or(node, "training_time", 0.0))
	var percent := int(100.0 * progress / maxf(train_time, 0.01))
	var name := str(UnitCatalog.get_definition(training_archetype).get("display_name", str(training_archetype)))
	return " | Training %s %s%% | Queue %s" % [name, percent, queue_count]

func _rebuild_context_commands(selected: Array[Node]) -> void:
	_clear_commands()
	if selected.is_empty():
		return
	if _add_wizard_level_up_buttons(selected):
		return
	if _selection_has_archetype(selected, &"life_wizard"):
		_add_button(command_container, "Observation Tower", func() -> void: _start_build(&"wizard_tower"))
		_add_button(command_container, "Bio Absorber", func() -> void: _start_build(&"bio_absorber"))
		_add_button(command_container, "Barracks", func() -> void: _start_build(&"barracks"))
		_add_button(command_container, "Vault", func() -> void: _start_build(&"terrible_vault"))
		_add_button(command_container, "Vinewall", func() -> void: _start_build(&"vinewall"))
		_add_button(command_container, "Bio Launcher", func() -> void: _start_build(&"bio_launcher"))
		_add_button(command_container, "Bio Mend", _bio_mend)
		_add_button(command_container, "Seal Away", _seal_away)
		var storm := _add_button(command_container, "Biostorm", func() -> void: _target_kon_spell(&"biostorm"))
		storm.tooltip_text = "60 Bio. Damages ALL units in the circle for 4 seconds, including Kon and allies."
		_add_button(command_container, "Observer Aura", func() -> void: _activate_selected("activate_observer_aura", "Observer Aura"))
		var unleash := _add_button(command_container, "Unleash", _unleash_forbidden)
		unleash.tooltip_text = "Tier 4: release The Forbidden. It obeys nobody and will attack you too."
		unleash.add_theme_color_override("font_color", Color("#E85A5A"))
	elif _selection_has_archetype(selected, &"wizard_tower"):
		_add_tower_module_buttons()
	elif _selection_has_archetype(selected, &"barracks"):
		_add_barracks_training_buttons()
	elif _selection_has_archetype(selected, &"bio_absorber"):
		_add_button(command_container, "Heal Aura", func() -> void: _absorber_upgrade(&"heal_aura"))
		_add_button(command_container, "Bio Turret", func() -> void: _absorber_upgrade(&"bio_launcher"))
	elif _selection_has_archetype(selected, &"terrible_vault"):
		_add_button(command_container, "Open the Vault", _open_selected_vault)
	elif _selection_has_archetype(selected, &"bio_launcher"):
		_add_launcher_buttons(selected)
	else:
		_add_weapon_mode_button(selected)
		_add_unit_active_buttons(selected)
		if _is_testing_mode() and _selection_has_evolvable_kon_unit(selected):
			_add_button(command_container, "Level Up", _debug_level_up_selected)
		_add_button(command_container, "Bio Mend", _bio_mend)
		_add_button(command_container, "Seal Away", _seal_away)

func _add_wizard_level_up_buttons(selected: Array[Node]) -> bool:
	var wizard: Node = null
	for node in selected:
		if is_instance_valid(node) and node.has_method("choose_wizard_upgrade") and bool(node.get("pending_level_up")):
			wizard = node
			break
	if wizard == null:
		return false
	var options: Array = wizard.call("wizard_upgrade_options")
	for option in options:
		var option_id := str(option)
		_add_button(command_container, option_id.capitalize(), func() -> void: _choose_wizard_upgrade(wizard, option_id))
	status_label.text = "Wizard reached level %s -- choose an upgrade" % str(wizard.get("wizard_level"))
	return true

func _choose_wizard_upgrade(wizard: Node, option: String) -> void:
	if not is_instance_valid(wizard):
		return
	if bool(wizard.call("choose_wizard_upgrade", option)):
		status_label.text = "Wizard upgraded: %s" % option.capitalize()
		_update_selection_panel(true)

func _selection_has_archetype(selected: Array[Node], archetype: StringName) -> bool:
	for node in selected:
		if _archetype_for(node) == archetype:
			return true
	return false

# The Observation Tower's command panel.
#
# Barracks and Vault are installed into tower slots rather than placed on the
# map, so there is no barracks or vault to select any more. Without this branch
# the player had no way to train a unit or research anything -- the buildings
# that used to carry those buttons no longer exist as selectable structures.
func _add_tower_module_buttons() -> void:
	if build_system == null:
		return
	var free_slots := int(build_system.call("module_slots_free", 1))
	var total_slots := int(build_system.call("module_slots_total", 1))
	var modules: Array = build_system.call("installed_modules", 1)
	var has_production := false
	var has_research := false
	for module in modules:
		var role := StringName(UnitCatalog.get_definition(module).get("module_role", &""))
		if role == &"production":
			has_production = true
		elif role == &"research" or module == &"terrible_vault":
			has_research = true
	if has_production:
		_add_barracks_training_buttons()
	if has_research:
		_add_research_button(&"tier_two_hybrids", "Tier 2 Hybrids")
		_add_research_button(&"tier_three_hybrids", "Tier 3 Hybrids")
		_add_research_button(&"observer_sight", "Observer Sight")
		_add_research_button(&"observer_command", "Observer Command")
		_add_research_button(&"observer_oversight", "Oversight")
		_add_research_button(&"thorned_vines", "Thorned Vines")
		_add_research_button(&"accelerated_evolution", "Fast Evolution")
		_add_research_button(&"hardened_horrors", "Harden Horrors")
		_add_research_button(&"launcher_bile", "Launcher Bile")
	if not has_production and not has_research:
		status_label.text = "Observation Tower -- %s of %s module slots free" % [free_slots, total_slots]
	else:
		status_label.text = "Observation Tower -- %s of %s module slots free" % [free_slots, total_slots]

# What a selected structure can train, including anything its modules add.
func _production_list_for_node(node: Node) -> Array:
	if build_system == null or not build_system.has_method("production_list_for"):
		return []
	for structure in build_system.get("structures"):
		if structure.get("node", null) == node:
			return build_system.call("production_list_for", structure)
	return []

func _add_barracks_training_buttons() -> void:
	var session := get_node_or_null("/root/GameSession")
	var wizard_class_id := str(session.get("wizard_class_id")) if session != null else ""
	# The Biospawner is where the player reads the roster, so its command panel
	# opens the unit cards directly rather than burying them in a debug menu.
	if _is_testing_mode():
		_add_button(command_container, "Debug Roster", _open_unit_stat_window)
	for entry in BARRACKS_UNIT_BUTTONS:
		var archetype: StringName = entry["archetype"]
		if not UnitCatalog.is_unit_allowed_for_class(archetype, wizard_class_id):
			continue
		var label := str(entry["label"])
		var locked := _tier_is_locked(archetype)
		if locked:
			label = "Sealed (T%s)" % UnitCatalog.tier_of(archetype)
		var button := _add_button(command_container, label, func() -> void: _produce_from_selected(archetype))
		button.disabled = locked
		button.tooltip_text = "Locked -- research Tier %s Hybrids at the Observer Vault" % UnitCatalog.tier_of(archetype) if locked else str(UnitCatalog.get_definition(archetype).get("role", ""))

func _archetype_for(node: Node) -> StringName:
	if _has_property(node, "unit_archetype"):
		return node.get("unit_archetype")
	if _has_property(node, "archetype"):
		return node.get("archetype")
	return &""

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _property_or(node: Node, property_name: String, fallback: Variant) -> Variant:
	if _has_property(node, property_name):
		return node.get(property_name)
	return fallback

func _is_structure(node: Node) -> bool:
	return node.has_method("get_selection_kind") and node.get_selection_kind() == &"structure"

func _is_testing_mode() -> bool:
	return wave_director != null and wave_director.has_method("is_ai_testing_ground") and bool(wave_director.call("is_ai_testing_ground"))

func _is_spawnable_test_unit(archetype: StringName) -> bool:
	if wave_director == null or not wave_director.has_method("spawn_ai_test_player_unit"):
		return false
	return archetype in [
		&"terrible_thing",
		&"oaven_spear",
		&"horror",
		&"apex",
		&"spawner",
		&"stone_face_serpent",
		&"deom_scout",
		&"deom_blade",
		&"deom_crosshirran",
		&"deom_hammer",
		&"deom_glaive",
		&"deom_odden",
	]

func _selection_has_evolvable_kon_unit(selected: Array[Node]) -> bool:
	for node in selected:
		if not is_instance_valid(node) or not node.has_method("debug_force_evolve"):
			continue
		var definition := UnitCatalog.get_definition(_archetype_for(node))
		if definition.get("unit_family", &"") in [&"terrible_thing", &"oaven", &"horror", &"apex", &"spawner", &"stone_face_serpent", &"mangler"]:
			var progress: Dictionary = node.get_evolution_progress() if node.has_method("get_evolution_progress") else {}
			if float(progress.get("needed", definition.get("evolution_xp_required", 0.0))) > 0.0:
				return true
	return false

func _salvage_for(node: Node) -> int:
	if node.has_method("salvage_value"):
		return int(node.salvage_value())
	return 0

func _refresh() -> void:
	if economy_manager != null:
		_on_resources_changed(1, economy_manager.get_resources(1))
	if wave_director != null:
		_on_phase_changed(wave_director.phase)
	selection_label.text = "Selected: 0"

func _on_resources_changed(_player_id: int, resources: Dictionary) -> void:
	resource_label.text = "Bio: %s  Essence: %s" % [
		int(resources.get(&"bio", 0)),
		int(resources.get(&"essence", 0)),
	]

func _on_phase_changed(phase: StringName) -> void:
	if wave_director != null and wave_director.has_method("is_ai_testing_ground") and bool(wave_director.call("is_ai_testing_ground")):
		phase_label.text = "Kon's Siege Arena" if wave_director.has_method("is_fortress_ai_arena") and bool(wave_director.call("is_fortress_ai_arena")) else "AI Testing Ground"
	elif map_generator != null and str(map_generator.get("map_type_id")) == "plot_generator_test":
		phase_label.text = "Plot Generator Test"
	elif wave_director != null and not wave_director.boss_has_spawned:
		phase_label.text = "Phase: %s | Boss in %s" % [str(phase).capitalize(), _format_time(wave_director.get_boss_seconds_remaining())]
	else:
		phase_label.text = "Phase: %s" % str(phase).capitalize()

func _on_wave_spawned(wave_index: int, count: int) -> void:
	if wave_director != null and wave_director.has_method("is_ai_testing_ground") and bool(wave_director.call("is_ai_testing_ground")):
		status_label.text = "AI test wave %s: %s total units spawned" % [wave_index, count]
	else:
		status_label.text = "Wave %s: %s enemies" % [wave_index, count]

func _show_alert(text: String) -> void:
	if alert_label == null:
		return
	alert_label.text = text
	alert_label.visible = true
	_alert_until_msec = Time.get_ticks_msec() + 7000

func _start_victory_return_countdown() -> void:
	_return_phase_title = "Victory"
	_return_alert_prefix = "VICTORY"
	_victory_return_remaining = VICTORY_RETURN_SECONDS
	_last_victory_second = -1
	_update_victory_return_countdown(0.0)

func _start_defeat_return_countdown(reason: String) -> void:
	_return_phase_title = "Defeat"
	_return_alert_prefix = "DEFEAT"
	status_label.text = reason.capitalize()
	_victory_return_remaining = VICTORY_RETURN_SECONDS
	_last_victory_second = -1
	_update_victory_return_countdown(0.0)

func _update_victory_return_countdown(delta: float) -> void:
	_victory_return_remaining -= delta
	var seconds_left := maxi(0, ceili(_victory_return_remaining))
	if seconds_left != _last_victory_second:
		_last_victory_second = seconds_left
		phase_label.text = _return_phase_title
		status_label.text = "Returning to main menu in %s" % seconds_left
		_show_alert("%s - RETURNING IN %s" % [_return_alert_prefix, seconds_left])
	if _victory_return_remaining <= 0.0:
		_victory_return_remaining = -1.0
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _format_time(seconds: int) -> String:
	var mins := seconds / 60
	var secs := seconds % 60
	return "%d:%02d" % [mins, secs]

func _start_build(archetype: StringName) -> void:
	if build_system == null or not build_system.has_method("start_placement"):
		return
	build_system.call("start_placement", archetype)
	var definition := UnitCatalog.get_definition(archetype)
	var name := str(definition.get("display_name", archetype))
	# Rotation is only mentioned for buildings it does anything to. Telling the
	# player they can rotate a 1x1 absorber is noise.
	if definition.has("block_structure"):
		status_label.text = "Place %s with left-click. R rotates. Right-click cancels." % name
	else:
		status_label.text = "Place %s with left-click. Right-click cancels." % name

func _produce(archetype: StringName) -> void:
	if build_system != null and build_system.has_method("produce_unit"):
		build_system.call("produce_unit", 1, archetype)

func _spawn_ai_test_unit(archetype: StringName) -> void:
	if wave_director == null or not wave_director.has_method("spawn_ai_test_player_unit"):
		return
	var result: Dictionary = wave_director.call("spawn_ai_test_player_unit", archetype)
	if bool(result.get("accepted", false)):
		status_label.text = "Spawned test %s as third faction" % UnitCatalog.get_definition(archetype).get("display_name", archetype)
	else:
		status_label.text = "Could not spawn test unit: %s" % str(result.get("reason", "unknown")).capitalize()

func _add_launcher_buttons(selected: Array[Node]) -> void:
	if build_system == null:
		return
	var launcher: Node = null
	for node in selected:
		if _archetype_for(node) == &"bio_launcher":
			launcher = node
			break
	if launcher == null:
		return
	var auto_on := bool(build_system.call("launcher_auto_fire", launcher)) if build_system.has_method("launcher_auto_fire") else true
	_add_button(command_container, "Auto: %s" % ("ON" if auto_on else "OFF"), func() -> void:
		if build_system.has_method("set_launcher_auto_fire"):
			build_system.call("set_launcher_auto_fire", launcher, not auto_on)
			status_label.text = "Bio Launcher auto-fire %s" % ("enabled" if not auto_on else "disabled")
			_update_selection_panel(true)
	)
	_add_button(command_container, "Attack Ground", func() -> void:
		if selection_controller != null and selection_controller.has_method("begin_launcher_attack_ground"):
			selection_controller.call("begin_launcher_attack_ground", launcher)
			status_label.text = "Pick a target point for the Bio Launcher"
	)

func _add_weapon_mode_button(selected: Array[Node]) -> bool:
	var swappable: Array[Node] = []
	for node in selected:
		if node.has_method("has_weapon_modes") and bool(node.call("has_weapon_modes")):
			swappable.append(node)
	if swappable.is_empty():
		return false
	var current := str(swappable[0].call("weapon_mode_display_name"))
	var button := _add_button(command_container, "Weapon: %s" % current, func() -> void:
		var switched := ""
		for node in swappable:
			if is_instance_valid(node) and node.has_method("toggle_weapon_mode"):
				node.call("toggle_weapon_mode")
				switched = str(node.call("weapon_mode_display_name"))
		if not switched.is_empty():
			status_label.text = "Switched %s to %s" % ["Oaven" if swappable.size() == 1 else "%s units" % swappable.size(), switched]
		_update_selection_panel(true)
	)
	button.tooltip_text = "Swap between the spear (melee) and the blowpipe (ranged)"
	return true

func _unleash_forbidden() -> void:
	if build_system == null or not build_system.has_method("unleash_forbidden"):
		return
	var unit = build_system.call("unleash_forbidden", 1)
	if unit != null:
		status_label.text = "THE FORBIDDEN IS LOOSE"
		_show_alert("THE FORBIDDEN IS LOOSE")

func _add_unit_active_buttons(selected: Array[Node]) -> void:
	if selected.is_empty():
		return
	var archetype := _archetype_for(selected[0])
	var definition := UnitCatalog.get_definition(archetype)
	for active in definition.get("actives", []):
		match str(active):
			"Leap Slam":
				var caster := selected[0]
				var leap_button := _add_button(command_container, "Leap Slam", func() -> void:
					if is_instance_valid(caster) and selection_controller != null:
						selection_controller.begin_mangler_leap(caster)
				)
				leap_button.tooltip_text = "Leap to clear ground: 65 damage and 1.5s stun to nearby enemies. 14s cooldown."
			"Charge":
				_add_button(command_container, "Charge", func() -> void: _activate_selected("activate_charge", "Charge"))
			"Taunt":
				_add_button(command_container, "Taunt", func() -> void: _activate_selected("activate_taunt", "Taunt"))
			"Flight":
				_add_button(command_container, "Flight", func() -> void: _activate_selected("activate_flight", "Flight"))
			"Grapple":
				_add_button(command_container, "Grapple", func() -> void: _activate_selected("activate_grapple", "Grapple"))
			"Eat ally":
				_add_button(command_container, "Eat Ally", func() -> void: _activate_selected("activate_eat_ally", "Eat Ally"))
			"Summon drone":
				_add_button(command_container, "Drone", func() -> void: _activate_selected("activate_summon_drone", "Summon Drone"))
			"Root":
				_add_button(command_container, "Root", func() -> void: _activate_selected("activate_root", "Root"))
			"Uproot":
				_add_button(command_container, "Uproot", func() -> void: _activate_selected("activate_uproot", "Uproot"))
			"Observer Aura":
				_add_button(command_container, "Observer Aura", func() -> void: _activate_selected("activate_observer_aura", "Observer Aura"))
			"Stone Form":
				_add_button(command_container, "Stone Form", func() -> void: _activate_selected("activate_stone_form", "Stone Form"))

func _activate_selected(method_name: String, label: String) -> void:
	if selection_controller == null:
		return
	var activated := 0
	for unit in selection_controller.selected_units:
		if is_instance_valid(unit) and unit.has_method(method_name) and bool(unit.call(method_name)):
			activated += 1
	if label == "Stone Form" and activated > 0:
		status_label.text = "Stone Form: click and drag to place the serpent wall"
	else:
		status_label.text = "%s activated on %s unit%s" % [label, activated, "" if activated == 1 else "s"]

func _debug_level_up_selected() -> void:
	if selection_controller == null:
		return
	var evolved := 0
	for unit in selection_controller.selected_units:
		if is_instance_valid(unit) and unit.has_method("debug_force_evolve") and bool(unit.call("debug_force_evolve")):
			evolved += 1
	status_label.text = "Debug level up applied to %s unit%s" % [evolved, "" if evolved == 1 else "s"]
	_update_selection_panel(true)

func _produce_from_selected(archetype: StringName) -> void:
	if build_system == null or selection_controller == null:
		return
	# Any selected structure that can train, not specifically a barracks. Once
	# the barracks became a tower module there was no barracks node to find, so
	# this always fell through to the error and nothing could be trained at all.
	var producer: Node = null
	for node in selection_controller.selected_units:
		if not is_instance_valid(node) or not _is_structure(node):
			continue
		if _production_list_for_node(node).has(archetype):
			producer = node
			break
	if producer == null:
		status_label.text = "Select a building that trains %s" % str(
			UnitCatalog.get_definition(archetype).get("display_name", str(archetype)))
		return
	if build_system.has_method("produce_unit_from_structure"):
		build_system.call("produce_unit_from_structure", 1, archetype, producer)

func _player_wizard() -> Node:
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1 and unit.has_method("wizard_upgrade_rank"):
			return unit
	return null

func _bio_mend() -> void:
	if selection_controller == null:
		return
	var wizard := _player_wizard()
	var rank := int(wizard.call("wizard_upgrade_rank", "bio_mend")) if wizard != null else 0
	var heal_amount := 45 + rank * 25
	var healed := 0
	for unit in selection_controller.selected_units:
		if is_instance_valid(unit) and unit.has_method("heal_damage"):
			unit.heal_damage(heal_amount)
			_spawn_spell_fx(unit, BIO_MEND_FX, Vector2(1.15, 1.15), Vector2(0, -10))
			healed += 1
	status_label.text = "Bio Mend healed %s selected allies for %s" % [healed, heal_amount]

func _seal_away() -> void:
	_target_kon_spell(&"seal_away")

func _target_kon_spell(action: StringName) -> void:
	if selection_controller==null: return
	var wizard := _player_wizard()
	if wizard==null or not wizard.has_method("cast_kon_spell"): return
	if not selection_controller.kon_spell_result.is_connected(_kon_spell_feedback):
		selection_controller.kon_spell_result.connect(_kon_spell_feedback)
	selection_controller.begin_kon_spell(wizard,action)
	status_label.text="Select the target circle. Allies are affected too. Right-click cancels."

func _kon_spell_feedback(message: String) -> void:
	status_label.text=message

func _spawn_spell_fx(target: Node, texture: Texture2D, visual_scale: Vector2, offset: Vector2) -> void:
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	var parent := (target as Node2D).get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var fx: Sprite2D = ONE_SHOT_SPRITE_FX.new()
	parent.add_child(fx)
	fx.global_position = (target as Node2D).global_position + offset
	fx.configure(texture, 4, 1, 0.46, visual_scale, Vector2(0, -10))

func _absorber_upgrade(upgrade_id: StringName) -> void:
	if build_system != null and build_system.has_method("apply_first_absorber_upgrade") and bool(build_system.call("apply_first_absorber_upgrade", upgrade_id)):
		status_label.text = "Bio Absorber upgrade selected: %s" % str(upgrade_id).capitalize()

func _add_research_button(upgrade_id: StringName, label: String) -> void:
	if build_system == null:
		return
	var rank := int(build_system.call("upgrade_rank", upgrade_id))
	var max_rank := int(build_system.call("upgrade_max_rank", upgrade_id))
	var text := "%s (%s/%s)" % [label, rank, max_rank] if max_rank > 1 else label
	var button := _add_button(command_container, text, func() -> void: _research_upgrade(upgrade_id))
	button.disabled = rank >= max_rank

func _research_upgrade(upgrade_id: StringName) -> void:
	if build_system != null and build_system.has_method("research_upgrade") and bool(build_system.call("research_upgrade", 1, upgrade_id)):
		var rank := int(build_system.call("upgrade_rank", upgrade_id))
		var max_rank := int(build_system.call("upgrade_max_rank", upgrade_id))
		status_label.text = "Researched %s (rank %s/%s)" % [_upgrade_name(upgrade_id), rank, max_rank]
		_update_selection_panel(true)

func _upgrade_name(upgrade_id: StringName) -> String:
	match upgrade_id:
		&"thorned_vines":
			return "Thorned Vines"
		&"accelerated_evolution":
			return "Accelerated Evolution"
		&"hardened_horrors":
			return "Hardened Horrors"
		&"launcher_bile":
			return "Launcher Bile"
		&"observer_sight":
			return "Observer Sight"
		&"observer_oversight":
			return "Observer Oversight"
		&"observer_command":
			return "Observer Command"
		&"tier_two_hybrids":
			return "Tier 2 Hybrids"
		&"tier_three_hybrids":
			return "Tier 3 Hybrids"
	return str(upgrade_id).capitalize()

func _on_build_rejected(reason: String) -> void:
	status_label.text = reason
