class_name RTSHud
extends CanvasLayer

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
		build_system.unit_produced.connect(func(_player_id: int, archetype: StringName, _cell: Vector2i) -> void:
			status_label.text = "Produced %s" % UnitCatalog.get_definition(archetype).get("display_name", archetype)
		)
	_refresh()

func _process(_delta: float) -> void:
	if selection_controller != null:
		selection_label.text = "Selected: %s" % selection_controller.selected_units.size()

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
	commands.text = "S stop | Right-click move | Drag Vinewall to chain"

	row.add_child(resource_label)
	row.add_child(phase_label)
	row.add_child(selection_label)
	row.add_child(commands)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -126
	bottom.offset_bottom = -12
	add_child(bottom)

	var command_row := HBoxContainer.new()
	command_row.add_theme_constant_override("separation", 8)
	bottom.add_child(command_row)

	_add_button(command_row, "Bio Absorber", func() -> void: _start_build(&"bio_absorber"))
	_add_button(command_row, "Barracks", func() -> void: _start_build(&"barracks"))
	_add_button(command_row, "Vault", func() -> void: _start_build(&"terrible_vault"))
	_add_button(command_row, "Vinewall", func() -> void: _start_build(&"vinewall"))
	_add_button(command_row, "Bio Launcher", func() -> void: _start_build(&"bio_launcher"))
	_add_button(command_row, "Thing", func() -> void: _produce(&"terrible_thing"))
	_add_button(command_row, "Horror", func() -> void: _produce(&"horror"))
	_add_button(command_row, "Apex", func() -> void: _produce(&"apex"))
	_add_button(command_row, "Bio Mend", _bio_mend)
	_add_button(command_row, "Seal Away", _seal_away)
	_add_button(command_row, "Heal Aura", func() -> void: _absorber_upgrade(&"heal_aura"))
	_add_button(command_row, "Bio Turret", func() -> void: _absorber_upgrade(&"bio_launcher"))

	status_label = _make_label()
	status_label.text = "Kon: build with Bio. Bio Absorbers must go on pale economy spaces."
	command_row.add_child(status_label)

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

func _bio_mend() -> void:
	if selection_controller == null:
		return
	var healed := 0
	for unit in selection_controller.selected_units:
		if is_instance_valid(unit) and unit.has_method("heal_damage"):
			unit.heal_damage(45)
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
				stunned += 1
			continue
		if unit.get("unit_archetype") == &"life_wizard":
			continue
		if unit.has_method("salvage_value"):
			refunded += int(unit.salvage_value())
			unit.queue_free()
	if refunded > 0:
		economy_manager.add_resource(1, &"bio", refunded)
	status_label.text = "Seal Away returned %s Bio and stunned %s enemies" % [refunded, stunned]

func _absorber_upgrade(upgrade_id: StringName) -> void:
	if build_system != null and build_system.apply_first_absorber_upgrade(upgrade_id):
		status_label.text = "Bio Absorber upgrade selected: %s" % String(upgrade_id).capitalize()

func _on_build_rejected(reason: String) -> void:
	status_label.text = reason
