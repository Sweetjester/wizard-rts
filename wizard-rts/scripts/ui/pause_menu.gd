class_name PauseMenu
extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var overlay: Control
var volume_slider: HSlider
var mute_check: CheckBox
var resolution_option: OptionButton
var fullscreen_check: CheckBox
var performance_check: CheckBox
var keybind_rows: Dictionary = {}
var waiting_for_action := ""
var hint_label: Label
var telemetry_logger: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	telemetry_logger = get_node_or_null("../TelemetryLogger")
	_build_ui()
	_sync_controls()
	hide_menu()

func _unhandled_input(event: InputEvent) -> void:
	if waiting_for_action != "" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			KeybindManager.set_keycode(waiting_for_action, event.physical_keycode)
			waiting_for_action = ""
			_refresh_keybind_rows()
			hint_label.text = "Key binding updated."
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if overlay.visible:
			hide_menu()
		else:
			show_menu()
		get_viewport().set_input_as_handled()

func show_menu() -> void:
	waiting_for_action = ""
	_sync_controls()
	overlay.show()
	get_tree().paused = true

func hide_menu() -> void:
	waiting_for_action = ""
	overlay.hide()
	get_tree().paused = false

func _build_ui() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.035, 0.78)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 680)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_top = -340
	panel.offset_right = 380
	panel.offset_bottom = 340
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := _label("Game Menu", 34)
	box.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)

	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_display_tab())
	tabs.add_child(_build_keybind_tab())
	tabs.add_child(_build_quit_tab())

	hint_label = _label("Escape resumes the game.", 15)
	box.add_child(hint_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	box.add_child(bottom)
	_add_button(bottom, "Resume", hide_menu)
	_add_button(bottom, "Export Data", _export_telemetry_now)
	_add_button(bottom, "Restart", _restart_run)
	_add_button(bottom, "Main Menu", _quit_to_main_menu)
	_add_button(bottom, "Quit Desktop", _quit_desktop)

func _build_audio_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Audio"
	tab.add_theme_constant_override("separation", 10)
	tab.add_child(_label("Music Volume", 18))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value_changed.connect(func(value: float) -> void:
		AudioManager.set_music_volume(value)
	)
	tab.add_child(volume_slider)
	mute_check = CheckBox.new()
	mute_check.text = "Mute music"
	mute_check.toggled.connect(func(value: bool) -> void:
		AudioManager.set_music_muted(value)
	)
	tab.add_child(mute_check)
	return tab

func _build_display_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Display"
	tab.add_theme_constant_override("separation", 10)
	tab.add_child(_label("Resolution", 18))
	resolution_option = OptionButton.new()
	for i in DisplayManager.get_resolution_count():
		resolution_option.add_item(DisplayManager.get_resolution_label(i), i)
	resolution_option.item_selected.connect(func(index: int) -> void:
		DisplayManager.set_resolution_index(index)
		_sync_controls()
	)
	tab.add_child(resolution_option)
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.toggled.connect(func(value: bool) -> void:
		DisplayManager.set_fullscreen(value)
		_sync_controls()
	)
	tab.add_child(fullscreen_check)
	performance_check = CheckBox.new()
	performance_check.text = "Performance mode"
	performance_check.toggled.connect(func(value: bool) -> void:
		DisplayManager.set_performance_mode(value)
	)
	tab.add_child(performance_check)
	return tab

func _build_keybind_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Key Binds"
	tab.add_theme_constant_override("separation", 8)
	keybind_rows.clear()
	for action in KeybindManager.get_actions():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(KeybindManager.get_action_display_name(action), 17)
		name_label.custom_minimum_size = Vector2(220, 34)
		row.add_child(name_label)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(180, 36)
		bind_button.pressed.connect(func(bound_action := action) -> void:
			waiting_for_action = bound_action
			hint_label.text = "Press a key for %s. Escape cancels." % KeybindManager.get_action_display_name(bound_action)
			_refresh_keybind_rows()
		)
		row.add_child(bind_button)
		keybind_rows[action] = bind_button
		tab.add_child(row)
	var right_click := _label("Right-click: Move / smart command  (fixed)", 16)
	tab.add_child(right_click)
	_add_button(tab, "Reset Defaults", func() -> void:
		KeybindManager.reset_to_defaults()
		waiting_for_action = ""
		hint_label.text = "Key bindings reset."
		_refresh_keybind_rows()
	)
	return tab

func _build_quit_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Quit"
	tab.add_theme_constant_override("separation", 12)
	tab.add_child(_label("Run Options", 20))
	tab.add_child(_label("Restart reloads the current run. Main Menu leaves the current game.", 16))
	_add_button(tab, "Export Test Data Now", _export_telemetry_now)
	_add_button(tab, "Restart Current Run", _restart_run)
	_add_button(tab, "Return to Main Menu", _quit_to_main_menu)
	_add_button(tab, "Quit to Desktop", _quit_desktop)
	return tab

func _sync_controls() -> void:
	if volume_slider != null:
		volume_slider.value = AudioManager.music_volume
	if mute_check != null:
		mute_check.button_pressed = AudioManager.music_muted
	if resolution_option != null:
		resolution_option.select(DisplayManager.resolution_index)
		resolution_option.disabled = DisplayManager.fullscreen
	if fullscreen_check != null:
		fullscreen_check.button_pressed = DisplayManager.fullscreen
	if performance_check != null:
		performance_check.button_pressed = DisplayManager.performance_mode
	_refresh_keybind_rows()

func _refresh_keybind_rows() -> void:
	for action in keybind_rows.keys():
		var button: Button = keybind_rows[action]
		if waiting_for_action == action:
			button.text = "Press key..."
		else:
			button.text = KeybindManager.get_key_label(action)

func _restart_run() -> void:
	_finalize_telemetry("restart")
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit_to_main_menu() -> void:
	_finalize_telemetry("main_menu")
	get_tree().paused = false
	AudioManager.play_map_music()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _quit_desktop() -> void:
	_finalize_telemetry("quit_desktop")
	get_tree().paused = false
	get_tree().quit()

func _export_telemetry_now() -> void:
	if telemetry_logger == null or not telemetry_logger.has_method("capture_sample"):
		hint_label.text = "No telemetry logger found."
		return
	telemetry_logger.call("capture_sample")
	var paths: Dictionary = telemetry_logger.call("get_export_paths") if telemetry_logger.has_method("get_export_paths") else {}
	hint_label.text = "Data exported: %s" % str(paths.get("folder", "session folder"))

func _finalize_telemetry(reason: String) -> void:
	if telemetry_logger != null and telemetry_logger.has_method("finalize"):
		telemetry_logger.call("finalize", reason)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#D6C7AE"))
	return label

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 42)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
