class_name RTSHud
extends CanvasLayer

const ONE_SHOT_SPRITE_FX := preload("res://scripts/fx/one_shot_sprite_fx.gd")
const BIO_MEND_FX: Texture2D = preload("res://assets/fx/kon/bio_mend_spell_sheet.png")
const SEAL_AWAY_FX: Texture2D = preload("res://assets/fx/kon/seal_away_spell_sheet.png")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const VICTORY_RETURN_SECONDS := 5.0

@export var economy_manager_path: NodePath = NodePath("../EconomyManager")
@export var wave_director_path: NodePath = NodePath("../WaveDirector")
@export var selection_controller_path: NodePath = NodePath("../SelectionController")
@export var build_system_path: NodePath = NodePath("../BuildSystem")
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var combat_system_path: NodePath = NodePath("../CombatSystem")

var economy_manager: EconomyManager
var wave_director: WaveDirector
var selection_controller: SelectionController
var build_system: Node
var map_generator: Node
var rts_world: RTSWorld
var combat_system: Node
var resource_label: Label
var phase_label: Label
var selection_label: Label
var status_label: Label
var detail_name_label: Label
var detail_body_label: Label
var detail_meta_label: Label
var alert_label: Label
var command_container: HBoxContainer
var ai_test_container: HBoxContainer
var map_tool_container: HBoxContainer
var ai_telemetry_label: Label
var ai_spawn_button: Button
var unit_stat_window: Window
var _last_selection_signature := ""
var _alert_until_msec: int = 0
var _boss_warning_shown := false
var _victory_return_remaining := -1.0
var _last_victory_second := -1
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
	_build_ui()
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
	if selection_controller != null:
		selection_controller.selection_changed.connect(func(_selected: Array[Node]) -> void:
			_update_selection_panel(true)
		)
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
	var commands := _make_label()
	commands.text = "%s attack-move | %s patrol | %s hold | %s stop | Right-click move" % [
		KeybindManager.get_key_label(KeybindManager.ACTION_ATTACK_MOVE),
		KeybindManager.get_key_label(KeybindManager.ACTION_PATROL),
		KeybindManager.get_key_label(KeybindManager.ACTION_HOLD),
		KeybindManager.get_key_label(KeybindManager.ACTION_STOP),
	]

	row.add_child(resource_label)
	row.add_child(phase_label)
	row.add_child(selection_label)
	row.add_child(commands)

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
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -154
	bottom.offset_bottom = -12
	add_child(bottom)

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
	details.add_child(detail_name_label)
	details.add_child(detail_body_label)
	details.add_child(detail_meta_label)

	var command_column := VBoxContainer.new()
	command_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(command_column)

	command_container = HBoxContainer.new()
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
	_add_button(ai_test_container, "Test Thing", func() -> void: _spawn_ai_test_unit(&"terrible_thing"))
	_add_button(ai_test_container, "Test Horror", func() -> void: _spawn_ai_test_unit(&"horror"))
	_add_button(ai_test_container, "Test Apex", func() -> void: _spawn_ai_test_unit(&"apex"))
	_add_button(ai_test_container, "Test Spawner", func() -> void: _spawn_ai_test_unit(&"spawner"))
	_add_button(ai_test_container, "Unit Stats", _open_unit_stat_window)
	if ai_telemetry_label != null:
		ai_telemetry_label.visible = true
	status_label.text = "Neutral observer mode. Spawn mirrored armies to test AI, pathing, targeting, and performance."

func _setup_map_generator_controls() -> void:
	if map_tool_container == null or map_generator == null:
		return
	if str(map_generator.get("map_type_id")) != "seeded_grid_frontier":
		return
	map_tool_container.visible = true
	_add_button(map_tool_container, "Generate Map", _regenerate_seeded_grid_map)
	_add_button(map_tool_container, "Keep Seed", _copy_seed_to_status)
	_copy_seed_to_status()

func _regenerate_seeded_grid_map() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("start_new_game"):
		session.call("start_new_game", "", str(session.get("wizard_class_id")), "seeded_grid_frontier")
	get_tree().reload_current_scene()

func _copy_seed_to_status() -> void:
	if map_generator == null:
		return
	var seed_text := str(map_generator.get("map_seed_text"))
	var seed_label := seed_text if not seed_text.strip_edges().is_empty() else str(map_generator.get("seed_value"))
	status_label.text = "Map seed: %s | Press Generate Map to roll and preview a replacement." % seed_label

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

func _show_unit_stat_card(archetype: StringName, detail_body: VBoxContainer) -> void:
	for child in detail_body.get_children():
		detail_body.remove_child(child)
		child.queue_free()
	detail_body.add_child(_build_stat_card(archetype))
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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var header := _make_label()
	header.text = str(definition.get("display_name", archetype))
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", _stat_accent(archetype))
	box.add_child(header)
	var meta := _make_label()
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.text = _stat_meta_text(archetype, definition)
	box.add_child(meta)
	var combat := _make_label()
	combat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat.text = _combat_text(archetype, definition)
	box.add_child(combat)
	var role := _make_label()
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.text = _role_text(archetype, definition)
	box.add_child(role)
	return card

func _stat_meta_text(archetype: StringName, definition: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("Archetype %s" % str(archetype))
	parts.append("HP %s" % int(definition.get("max_hp", 0)))
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
	var cooldown := float(definition.get("attack_cooldown_ticks", 0)) / 20.0
	var parts: Array[String] = []
	parts.append("Weapon %s" % str(weapon.get("kind", &"none")).capitalize())
	parts.append("Damage %s" % int(definition.get("attack_damage", weapon.get("damage", 0))))
	parts.append("Range %s" % range_cells)
	if cooldown > 0.0:
		parts.append("Cooldown %.2fs" % cooldown)
	if int(weapon.get("casts", 1)) > 1:
		parts.append("Casts %s" % int(weapon.get("casts", 1)))
	if weapon.has("aoe_radius"):
		parts.append("AoE %s px" % int(weapon.get("aoe_radius", 0)))
	return " | ".join(parts)

func _unit_stat_breakdown(archetype: StringName, definition: Dictionary) -> String:
	var weapon := WeaponCatalog.get_weapon(archetype)
	var lines: Array[String] = []
	lines.append("Combat profile")
	lines.append("Damage: %s | Range: %s cells | Cooldown: %.2fs | Weapon: %s" % [
		int(definition.get("attack_damage", weapon.get("damage", 0))),
		int(definition.get("attack_range_cells", 0)),
		float(definition.get("attack_cooldown_ticks", 0)) / 20.0,
		str(weapon.get("kind", &"none")).capitalize(),
	])
	if weapon.has("projectile_speed"):
		lines.append("Projectile speed: %s" % int(weapon.get("projectile_speed", 0)))
	if weapon.has("aoe_radius"):
		lines.append("Area damage radius: %s px" % int(weapon.get("aoe_radius", 0)))
	lines.append("")
	lines.append("Economy and production")
	lines.append("Bio cost: %s | Bio value: %s" % [
		int(definition.get("cost_bio", 0)),
		int(definition.get("bio_value", 0)),
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

func _stat_accent(archetype: StringName) -> Color:
	match archetype:
		&"life_wizard", &"horror", &"evangalion_wizard":
			return Color("#7DDDE8")
		&"fire_wizard", &"bloodcap_runner", &"vampire_mushroom_thrall", &"spore_spitter", &"bloodcap_brute":
			return Color("#E85A5A")
		&"terrible_thing", &"awful_thing", &"apex", &"apex_predator", &"spawner", &"spawner_drone", &"bio_absorber", &"vinewall", &"bio_launcher":
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

func _valid_selection() -> Array[Node]:
	var selected: Array[Node] = []
	if selection_controller == null:
		return selected
	for node in selection_controller.selected_units:
		if is_instance_valid(node):
			selected.append(node)
	return selected

func _selection_signature(selected: Array[Node]) -> String:
	var parts: Array[String] = []
	for node in selected:
		parts.append("%s:%s" % [node.get_instance_id(), str(_archetype_for(node))])
	return "|".join(parts)

func _update_selection_details(selected: Array[Node]) -> void:
	if selected.is_empty():
		detail_name_label.text = "No selection"
		detail_body_label.text = "Select units or buildings to inspect them."
		detail_meta_label.text = ""
		return
	if selected.size() > 1:
		detail_name_label.text = "%s selected" % selected.size()
		detail_body_label.text = _mixed_selection_summary(selected)
		detail_meta_label.text = "A attack-move | P patrol | H hold | S stop"
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
	else:
		var state := str(node.get("unit_state")).capitalize()
		detail_body_label.text = "HP %s/%s | %s | Bio value %s" % [hp, max_hp, state, _salvage_for(node)]
	var damage := int(definition.get("attack_damage", 0))
	var range := int(definition.get("attack_range_cells", 0))
	var cost := int(definition.get("cost_bio", 0))
	detail_meta_label.text = "Damage %s | Range %s | Cost %s Bio" % [damage, range, cost]

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
	if _selection_has_archetype(selected, &"life_wizard"):
		_add_button(command_container, "Bio Absorber", func() -> void: _start_build(&"bio_absorber"))
		_add_button(command_container, "Barracks", func() -> void: _start_build(&"barracks"))
		_add_button(command_container, "Vault", func() -> void: _start_build(&"terrible_vault"))
		_add_button(command_container, "Vinewall", func() -> void: _start_build(&"vinewall"))
		_add_button(command_container, "Bio Launcher", func() -> void: _start_build(&"bio_launcher"))
		_add_button(command_container, "Bio Mend", _bio_mend)
		_add_button(command_container, "Seal Away", _seal_away)
	elif _selection_has_archetype(selected, &"barracks"):
		_add_button(command_container, "Thing", func() -> void: _produce_from_selected(&"terrible_thing"))
		_add_button(command_container, "Horror", func() -> void: _produce_from_selected(&"horror"))
		_add_button(command_container, "Apex", func() -> void: _produce_from_selected(&"apex"))
		_add_button(command_container, "Spawner", func() -> void: _produce_from_selected(&"spawner"))
	elif _selection_has_archetype(selected, &"bio_absorber"):
		_add_button(command_container, "Heal Aura", func() -> void: _absorber_upgrade(&"heal_aura"))
		_add_button(command_container, "Bio Turret", func() -> void: _absorber_upgrade(&"bio_launcher"))
	elif _selection_has_archetype(selected, &"terrible_vault"):
		_add_button(command_container, "Thorned Vines", func() -> void: _research_upgrade(&"thorned_vines"))
		_add_button(command_container, "Fast Evolution", func() -> void: _research_upgrade(&"accelerated_evolution"))
		_add_button(command_container, "Harden Horrors", func() -> void: _research_upgrade(&"hardened_horrors"))
		_add_button(command_container, "Launcher Bile", func() -> void: _research_upgrade(&"launcher_bile"))
	else:
		_add_unit_active_buttons(selected)
		_add_button(command_container, "Bio Mend", _bio_mend)
		_add_button(command_container, "Seal Away", _seal_away)

func _selection_has_archetype(selected: Array[Node], archetype: StringName) -> bool:
	for node in selected:
		if _archetype_for(node) == archetype:
			return true
	return false

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
	_victory_return_remaining = VICTORY_RETURN_SECONDS
	_last_victory_second = -1
	_update_victory_return_countdown(0.0)

func _update_victory_return_countdown(delta: float) -> void:
	_victory_return_remaining -= delta
	var seconds_left := maxi(0, ceili(_victory_return_remaining))
	if seconds_left != _last_victory_second:
		_last_victory_second = seconds_left
		phase_label.text = "Victory"
		status_label.text = "Returning to main menu in %s" % seconds_left
		_show_alert("VICTORY - RETURNING IN %s" % seconds_left)
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
	status_label.text = "Place %s with left-click. Right-click cancels." % UnitCatalog.get_definition(archetype).get("display_name", archetype)

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

func _add_unit_active_buttons(selected: Array[Node]) -> void:
	if selected.is_empty():
		return
	var archetype := _archetype_for(selected[0])
	var definition := UnitCatalog.get_definition(archetype)
	for active in definition.get("actives", []):
		match str(active):
			"Charge":
				_add_button(command_container, "Charge", func() -> void: _activate_selected("activate_charge", "Charge"))
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

func _activate_selected(method_name: String, label: String) -> void:
	if selection_controller == null:
		return
	var activated := 0
	for unit in selection_controller.selected_units:
		if is_instance_valid(unit) and unit.has_method(method_name) and bool(unit.call(method_name)):
			activated += 1
	status_label.text = "%s activated on %s unit%s" % [label, activated, "" if activated == 1 else "s"]

func _produce_from_selected(archetype: StringName) -> void:
	if build_system == null or selection_controller == null:
		return
	var producer: Node = null
	for node in selection_controller.selected_units:
		if is_instance_valid(node) and _archetype_for(node) == &"barracks":
			producer = node
			break
	if producer == null:
		status_label.text = "Select a Barracks to train units"
		return
	if build_system.has_method("produce_unit_from_structure"):
		build_system.call("produce_unit_from_structure", 1, archetype, producer)

func _bio_mend() -> void:
	if selection_controller == null:
		return
	var healed := 0
	for unit in selection_controller.selected_units:
		if is_instance_valid(unit) and unit.has_method("heal_damage"):
			unit.heal_damage(45)
			_spawn_spell_fx(unit, BIO_MEND_FX, Vector2(1.15, 1.15), Vector2(0, -10))
			healed += 1
	status_label.text = "Bio Mend healed %s selected allies" % healed

func _seal_away() -> void:
	if selection_controller == null or economy_manager == null:
		return
	var refunded := 0
	var stunned := 0
	for unit in selection_controller.selected_units.duplicate():
		if not is_instance_valid(unit):
			continue
		if int(unit.get("owner_player_id")) != 1:
			if unit.has_method("stun_for_seconds"):
				unit.stun_for_seconds(6.0)
				_spawn_spell_fx(unit, SEAL_AWAY_FX, Vector2(1.25, 1.25), Vector2(0, -12))
				stunned += 1
			continue
		if unit.get("unit_archetype") == &"life_wizard":
			continue
		if unit.has_method("salvage_value"):
			refunded += int(unit.salvage_value())
			_spawn_spell_fx(unit, SEAL_AWAY_FX, Vector2(1.35, 1.35), Vector2(0, -14))
			unit.queue_free()
	if refunded > 0:
		economy_manager.add_resource(1, &"bio", refunded)
	status_label.text = "Seal Away returned %s Bio and stunned %s enemies" % [refunded, stunned]

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

func _research_upgrade(upgrade_id: StringName) -> void:
	if build_system != null and build_system.has_method("research_upgrade") and bool(build_system.call("research_upgrade", 1, upgrade_id)):
		status_label.text = "Researching complete: %s" % _upgrade_name(upgrade_id)

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
	return str(upgrade_id).capitalize()

func _on_build_rejected(reason: String) -> void:
	status_label.text = reason
