class_name RTSHud
extends CanvasLayer

const ONE_SHOT_SPRITE_FX := preload("res://scripts/fx/one_shot_sprite_fx.gd")
const BIO_MEND_FX: Texture2D = preload("res://assets/fx/kon/bio_mend_spell_sheet.png")
const SEAL_AWAY_FX: Texture2D = preload("res://assets/fx/kon/seal_away_spell_sheet.png")

@export var economy_manager_path: NodePath = NodePath("../EconomyManager")
@export var wave_director_path: NodePath = NodePath("../WaveDirector")
@export var selection_controller_path: NodePath = NodePath("../SelectionController")
@export var build_system_path: NodePath = NodePath("../BuildSystem")

var economy_manager: EconomyManager
var wave_director: WaveDirector
var selection_controller: SelectionController
var build_system: BuildSystem
var resource_label: Label
var phase_label: Label
var selection_label: Label
var status_label: Label
var detail_name_label: Label
var detail_body_label: Label
var detail_meta_label: Label
var command_container: HBoxContainer
var _last_selection_signature := ""

func _ready() -> void:
	layer = 50
	economy_manager = get_node_or_null(economy_manager_path)
	wave_director = get_node_or_null(wave_director_path)
	selection_controller = get_node_or_null(selection_controller_path)
	build_system = get_node_or_null(build_system_path)
	_build_ui()
	if economy_manager != null:
		economy_manager.resources_changed.connect(_on_resources_changed)
	if wave_director != null:
		wave_director.phase_changed.connect(_on_phase_changed)
		wave_director.wave_spawned.connect(_on_wave_spawned)
	if build_system != null:
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
	if selection_controller != null:
		selection_controller.selection_changed.connect(func(_selected: Array[Node]) -> void:
			_update_selection_panel(true)
		)
	_refresh()

func _process(_delta: float) -> void:
	if selection_controller != null:
		selection_label.text = "Selected: %s" % selection_controller.selected_units.size()
		_update_selection_panel(false)

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
	commands.text = "A attack-move | P patrol | H hold | S stop | Right-click move"

	row.add_child(resource_label)
	row.add_child(phase_label)
	row.add_child(selection_label)
	row.add_child(commands)

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

func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("#D6C7AE"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(92, 44)
	button.pressed.connect(callback)
	parent.add_child(button)

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
		parts.append("%s:%s" % [node.get_instance_id(), String(_archetype_for(node))])
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
	var display_name := String(definition.get("display_name", String(archetype)))
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
		var state := String(node.get("unit_state")).capitalize()
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
		var name := String(UnitCatalog.get_definition(_archetype_for(node)).get("display_name", String(_archetype_for(node))))
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
	var training_archetype := StringName(node.get("training_archetype"))
	var queue_count := int(_property_or(node, "production_queue_count", 0))
	if String(training_archetype).is_empty():
		return " | Queue %s" % queue_count if queue_count > 0 else ""
	var progress := float(_property_or(node, "training_progress", 0.0))
	var train_time := float(_property_or(node, "training_time", 0.0))
	var percent := int(100.0 * progress / maxf(train_time, 0.01))
	var name := String(UnitCatalog.get_definition(training_archetype).get("display_name", String(training_archetype)))
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
	elif _selection_has_archetype(selected, &"bio_absorber"):
		_add_button(command_container, "Heal Aura", func() -> void: _absorber_upgrade(&"heal_aura"))
		_add_button(command_container, "Bio Turret", func() -> void: _absorber_upgrade(&"bio_launcher"))
	else:
		_add_button(command_container, "Bio Mend", _bio_mend)
		_add_button(command_container, "Seal Away", _seal_away)

func _selection_has_archetype(selected: Array[Node], archetype: StringName) -> bool:
	for node in selected:
		if _archetype_for(node) == archetype:
			return true
	return false

func _archetype_for(node: Node) -> StringName:
	if _has_property(node, "unit_archetype"):
		return StringName(node.get("unit_archetype"))
	if _has_property(node, "archetype"):
		return StringName(node.get("archetype"))
	return &""

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if String(property.get("name", "")) == property_name:
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
	phase_label.text = "Phase: %s" % String(phase).capitalize()

func _on_wave_spawned(wave_index: int, count: int) -> void:
	phase_label.text = "Wave %s: %s enemies" % [wave_index, count]

func _start_build(archetype: StringName) -> void:
	if build_system == null:
		return
	build_system.start_placement(archetype)
	status_label.text = "Place %s with left-click. Right-click cancels." % UnitCatalog.get_definition(archetype).get("display_name", archetype)

func _produce(archetype: StringName) -> void:
	if build_system != null:
		build_system.produce_unit(1, archetype)

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
	build_system.produce_unit_from_structure(1, archetype, producer)

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
	if build_system != null and build_system.apply_first_absorber_upgrade(upgrade_id):
		status_label.text = "Bio Absorber upgrade selected: %s" % String(upgrade_id).capitalize()

func _on_build_rejected(reason: String) -> void:
	status_label.text = reason
