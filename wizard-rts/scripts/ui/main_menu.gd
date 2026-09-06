extends Control

const GAME_SCENE := "res://scripts/map/main_map.tscn"
const MAP_EDITOR_SCENE := "res://scenes/map/map_editor.tscn"
const MenuSkin := preload("res://scripts/ui/observer_menu_skin.gd")

@onready var main_panel: VBoxContainer = %MainPanel
@onready var audio_panel: VBoxContainer = %AudioPanel
@onready var display_panel: VBoxContainer = %DisplayPanel
@onready var character_panel: VBoxContainer = %CharacterPanel
@onready var map_panel: VBoxContainer = %MapPanel
# The map entries live in here once _ensure_map_scroll() has run. The title and
# the Back/Begin row stay outside it so they are always on screen.
var map_list: VBoxContainer = null
@onready var bad_kon_card: Button = %BadKonCard
@onready var hellfire_baby_card: Button = %HellfireBabyCard
@onready var evangalion_card: Button = %EvangalionCard
@onready var character_continue_button: Button = %CharacterContinueButton
@onready var begin_button: Button = %BeginButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var mute_check: CheckBox = %MuteCheck
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var performance_check: CheckBox = %PerformanceCheck

var selected_character_id := ""
var _starting_game := false
var selected_map_type_id := ""
# Presentation only. The map, the systems and the rules are identical either
# way -- see scripts/map/map_3d_view.gd.
var use_3d_view := true

func _ready() -> void:
	AudioManager.play_map_music()
	volume_slider.value = AudioManager.music_volume
	mute_check.button_pressed = AudioManager.music_muted
	_setup_display_controls()
	_add_map_editor_button()
	_add_plot_generator_test_button()
	_add_seeded_grid_map_button()
	_add_citadel_march_button()
	_add_build_sandbox_button()
	_add_lantern_tree_button()
	_add_fortress_map_button()
	_add_kon_arena_2_button()
	_prepare_map_card_click_targets()
	_show_main()
	MenuSkin.install(self)
	get_node("RootMargin/Layout/MainPanel/StartButton").grab_focus()

func _on_start_pressed() -> void:
	selected_character_id = ""
	selected_map_type_id = ""
	_update_character_card_state()
	character_continue_button.disabled = true
	begin_button.disabled = true
	AudioManager.play_map_music()
	_show_character()

func _on_bad_kon_pressed() -> void:
	selected_character_id = "bad_kon_willow"
	character_continue_button.disabled = false
	_update_character_card_state()
	AudioManager.play_life_wizard_music()

func _on_hellfire_baby_pressed() -> void:
	selected_character_id = "hellfire_baby"
	character_continue_button.disabled = false
	_update_character_card_state()
	AudioManager.play_fire_wizard_music()

func _on_evangalion_pressed() -> void:
	selected_character_id = "evangalion"
	character_continue_button.disabled = false
	_update_character_card_state()
	AudioManager.play_evangalion_music()

func _on_character_continue_pressed() -> void:
	if selected_character_id.is_empty():
		return
	_show_map()

func _on_vampire_map_pressed() -> void:
	_select_map_and_begin(GameSession.DEFAULT_MAP_TYPE)

func _on_lantern_tree_pressed() -> void:
	_select_map_and_begin("lantern_tree")

func _on_build_sandbox_pressed() -> void:
	_select_map_and_begin("build_sandbox")

func _on_citadel_march_pressed() -> void:
	_select_map_and_begin("citadel_march")

func _on_seeded_grid_frontier_pressed() -> void:
	_select_map_and_begin("seeded_grid_frontier")

func _on_grid_test_map_pressed() -> void:
	_select_map_and_begin("grid_test_canvas")

func _on_ai_testing_ground_pressed() -> void:
	_select_map_and_begin("ai_testing_ground")

func _on_fortress_ai_arena_pressed() -> void:
	_select_map_and_begin("fortress_ai_arena")

func _on_kon_arena_2_pressed() -> void:
	_select_map_and_begin("kon_arena_2")

func _on_plot_generator_test_pressed() -> void:
	_select_map_and_begin("plot_generator_test")

func _select_map_and_begin(map_type_id: String) -> void:
	selected_map_type_id = map_type_id
	begin_button.disabled = false
	_on_begin_pressed()

func _on_begin_pressed() -> void:
	if _starting_game:
		return
	if selected_character_id.is_empty():
		return
	if selected_map_type_id.is_empty():
		return
	_starting_game = true
	begin_button.disabled = true
	GameSession.start_new_game("", selected_character_id, selected_map_type_id, "", use_3d_view)
	AudioManager.play_map_music()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_audio_pressed() -> void:
	_show_audio()

func _on_display_pressed() -> void:
	_sync_display_controls()
	_show_display()

func _on_back_pressed() -> void:
	_show_main()
	AudioManager.play_map_music()

func _on_character_back_pressed() -> void:
	selected_character_id = ""
	selected_map_type_id = ""
	_update_character_card_state()
	character_continue_button.disabled = true
	begin_button.disabled = true
	AudioManager.play_map_music()
	_show_main()

func _on_map_back_pressed() -> void:
	selected_map_type_id = ""
	begin_button.disabled = true
	_show_character()

func _on_volume_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_mute_check_toggled(toggled_on: bool) -> void:
	AudioManager.set_music_muted(toggled_on)

func _on_resolution_option_item_selected(index: int) -> void:
	DisplayManager.set_resolution_index(index)

func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	DisplayManager.set_fullscreen(toggled_on)
	_sync_display_controls()

func _on_performance_check_toggled(toggled_on: bool) -> void:
	DisplayManager.set_performance_mode(toggled_on)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_map_editor_pressed() -> void:
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)

func _show_main() -> void:
	main_panel.show()
	audio_panel.hide()
	display_panel.hide()
	character_panel.hide()
	map_panel.hide()
	MenuSkin.layout(self)

func _show_audio() -> void:
	main_panel.hide()
	audio_panel.show()
	display_panel.hide()
	character_panel.hide()
	map_panel.hide()
	MenuSkin.layout(self)

func _show_display() -> void:
	main_panel.hide()
	audio_panel.hide()
	display_panel.show()
	character_panel.hide()
	map_panel.hide()
	MenuSkin.layout(self)

func _show_character() -> void:
	main_panel.hide()
	audio_panel.hide()
	display_panel.hide()
	character_panel.show()
	map_panel.hide()
	MenuSkin.layout(self)

func _show_map() -> void:
	main_panel.hide()
	audio_panel.hide()
	display_panel.hide()
	character_panel.hide()
	map_panel.show()
	MenuSkin.layout(self)

func _prepare_map_card_click_targets() -> void:
	if map_panel == null:
		return
	for child in map_panel.get_children():
		if child is Button:
			for descendant in child.get_children():
				_set_descendants_mouse_ignore(descendant)

func _set_descendants_mouse_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_descendants_mouse_ignore(child)

func _update_character_card_state() -> void:
	if bad_kon_card != null:
		bad_kon_card.button_pressed = selected_character_id == "bad_kon_willow"
	if hellfire_baby_card != null:
		hellfire_baby_card.button_pressed = selected_character_id == "hellfire_baby"
	if evangalion_card != null:
		evangalion_card.button_pressed = selected_character_id == "evangalion"

func _setup_display_controls() -> void:
	resolution_option.clear()
	for i in DisplayManager.get_resolution_count():
		resolution_option.add_item(DisplayManager.get_resolution_label(i), i)
	_sync_display_controls()

func _sync_display_controls() -> void:
	resolution_option.select(DisplayManager.resolution_index)
	fullscreen_check.button_pressed = DisplayManager.fullscreen
	performance_check.button_pressed = DisplayManager.performance_mode
	resolution_option.disabled = DisplayManager.fullscreen

# Kon's Arena 2.0.
func _add_kon_arena_2_button() -> void:
	if map_panel == null:
		return
	_ensure_map_scroll()
	if _map_container().has_node("KonArena2Button"):
		return
	var button := Button.new()
	button.name = "KonArena2Button"
	button.custom_minimum_size = Vector2(680, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.pressed.connect(_on_kon_arena_2_pressed)

	var layout := VBoxContainer.new()
	layout.name = "KonArena2Layout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 12.0
	layout.offset_right = -18.0
	layout.offset_bottom = -12.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var name_label := Label.new()
	name_label.text = "Kon's Arena 2.0"
	name_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = "Kon's creations against the Steel Force. Waves collide in the middle."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#E0C36A"))
	layout.add_child(subtitle)

	var description := RichTextLabel.new()
	description.custom_minimum_size = Vector2(620, 52)
	description.fit_content = true
	description.bbcode_enabled = false
	description.text = "You watch; neither army is yours. Both sides are ordered to the same central killing field, so every wave meets in the same place -- and the compositions thicken together, so wave five has a Mounted Knight in it and a Serpent facing it. For testing the AI, the roster and how many units a frame can carry."
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(description)

	_map_container().add_child(button)

func _add_fortress_map_button() -> void:
	if map_panel == null:
		return
	_ensure_map_scroll()
	if _map_container().has_node("FortressAiArenaButton"):
		return
	var button := Button.new()
	button.name = "FortressAiArenaButton"
	button.custom_minimum_size = Vector2(680, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.pressed.connect(_on_fortress_ai_arena_pressed)

	var layout := VBoxContainer.new()
	layout.name = "FortressAiArenaLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 12.0
	layout.offset_right = -18.0
	layout.offset_bottom = -12.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var name_label := Label.new()
	name_label.text = "Kon's Siege Arena"
	name_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = "Symmetrical fort assault arena for pathing, target priority, and base-destruction AI."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#7DDDE8"))
	layout.add_child(subtitle)

	var description := RichTextLabel.new()
	description.custom_minimum_size = Vector2(620, 52)
	description.bbcode_enabled = true
	description.fit_content = true
	description.scroll_active = false
	description.text = "Loads two mirrored forts with real wall blockers, keep buildings, and no fog of war. Spawn waves to test whether armies fight units first, then break the enemy base."
	layout.add_child(description)

	var insert_index := maxi(0, _map_container().get_child_count())
	_map_container().add_child(button)
	_map_container().move_child(button, insert_index)

func _add_map_editor_button() -> void:
	if main_panel == null or main_panel.has_node("MapEditorButton"):
		return
	var button := Button.new()
	button.name = "MapEditorButton"
	button.text = "Map Editor"
	button.custom_minimum_size = Vector2(280, 54)
	button.pressed.connect(_on_map_editor_pressed)
	var insert_index := maxi(0, main_panel.get_child_count() - 2)
	main_panel.add_child(button)
	main_panel.move_child(button, insert_index)

# The map list did not scroll, and grew past the screen.
#
# MapPanel is a plain VBoxContainer, unlike CharacterPanel which was given a
# CharacterScroll for exactly this reason. With seven map entries the panel is
# 1361px of content in a 1080px viewport, so the bottom of the list -- and the
# Back/Begin row under it -- simply had nowhere to be drawn. Adding the Citadel
# March made it 150px worse, which is what made it noticeable.
#
# The title and the button row stay outside the scroll so they never move; only
# the entries scroll. The 3D view toggle is pinned directly under the title for
# the same reason -- it is a setting, not a map, and it should not be something
# you have to scroll to find.
func _ensure_map_scroll() -> void:
	if map_panel == null or map_list != null:
		return
	var scroll := ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.name = "MapList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var entries: Array[Node] = []
	for child in map_panel.get_children():
		if str(child.name) == "MapTitle" or str(child.name) == "MapButtons":
			continue
		entries.append(child)
	# The panel used to size itself to its children, which is how it grew past
	# the screen. Now it fills the column and the scroll takes what is left.
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(scroll)
	map_panel.move_child(scroll, 1)
	for child in entries:
		map_panel.remove_child(child)
		list.add_child(child)
	map_list = list

# Where a map entry goes. Falls back to the panel itself if the scroll has not
# been built yet, so nothing depends on call order.
func _map_container() -> Node:
	return map_list if map_list != null else map_panel

func _add_view_mode_toggle() -> void:
	if map_panel == null or map_panel.has_node("ViewModeToggle"):
		return
	var toggle := CheckBox.new()
	toggle.name = "ViewModeToggle"
	toggle.text = "3D world"
	toggle.button_pressed = use_3d_view
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.toggled.connect(func(pressed: bool) -> void:
		use_3d_view = pressed
	)
	map_panel.add_child(toggle)
	# Directly under the title and outside the scrolling list, so it is always
	# visible rather than being the first thing pushed off the top.
	map_panel.move_child(toggle, 1)

func _add_seeded_grid_map_button() -> void:
	if map_panel == null:
		return
	_ensure_map_scroll()
	if _map_container().has_node("SeededGridFrontierButton"):
		return
	_add_view_mode_toggle()
	var insert_index := maxi(0, _map_container().get_child_count())
	var button := Button.new()
	button.name = "SeededGridFrontierButton"
	button.custom_minimum_size = Vector2(680, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.pressed.connect(_on_seeded_grid_frontier_pressed)

	var layout := VBoxContainer.new()
	layout.name = "SeededGridFrontierLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 12.0
	layout.offset_right = -18.0
	layout.offset_bottom = -12.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var name_label := Label.new()
	name_label.text = "Seeded Grid Frontier"
	name_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = "New production map generator: connected roads, high-ground base plots, ramps, content plots, water, forests, and mountains."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#7BC47F"))
	layout.add_child(subtitle)

	var description := RichTextLabel.new()
	description.custom_minimum_size = Vector2(620, 52)
	description.fit_content = true
	description.bbcode_enabled = false
	description.text = "Uses the successful square-grid test canvas as the foundation. Every new game rolls a fresh seed; regenerate in-game to preview another map."
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(description)

	_map_container().add_child(button)
	_map_container().move_child(button, insert_index)

# The citadel march. Built as a map type and wired into generation, but never
# given a menu entry -- so it was unreachable from the game itself and only
# startable from a test harness.
func _add_lantern_tree_button() -> void:
	if map_panel == null:
		return
	_ensure_map_scroll()
	if _map_container().has_node("LanternTreeButton"):
		return
	var insert_index := maxi(0, _map_container().get_child_count())
	var button := Button.new()
	button.name = "LanternTreeButton"
	button.custom_minimum_size = Vector2(680, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.pressed.connect(_on_lantern_tree_pressed)

	var layout := VBoxContainer.new()
	layout.name = "LanternTreeLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 12.0
	layout.offset_right = -18.0
	layout.offset_bottom = -12.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var name_label := Label.new()
	name_label.text = "The Lantern Tree"
	name_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = "192x192. The road network is a tree: citadel at the roots, bases in the canopy."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#9BD4A0"))
	layout.add_child(subtitle)

	var description := RichTextLabel.new()
	description.custom_minimum_size = Vector2(620, 52)
	description.fit_content = true
	description.bbcode_enabled = false
	description.text = "One trunk rises from Kon's citadel and forks into boughs, with a content plot hanging at every fork and tip like a lantern. A tree has no loops, so every branch is a commitment and the trunk is where everyone ends up -- the map carries its own risk gradient."
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(description)

	_map_container().add_child(button)
	_map_container().move_child(button, insert_index)

# Somewhere to lay buildings out without the map arguing.
func _add_build_sandbox_button() -> void:
	if map_panel == null:
		return
	_ensure_map_scroll()
	if _map_container().has_node("BuildSandboxButton"):
		return
	var insert_index := maxi(0, _map_container().get_child_count())
	var button := Button.new()
	button.name = "BuildSandboxButton"
	button.custom_minimum_size = Vector2(680, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.pressed.connect(_on_build_sandbox_pressed)

	var layout := VBoxContainer.new()
	layout.name = "BuildSandboxLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 12.0
	layout.offset_right = -18.0
	layout.offset_bottom = -12.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var name_label := Label.new()
	name_label.text = "Build Sandbox"
	name_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = "160x160 of flat ground. No cliffs, no water, no enemies, no waves."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#E0C36A"))
	layout.add_child(subtitle)

	var description := RichTextLabel.new()
	description.custom_minimum_size = Vector2(620, 52)
	description.fit_content = true
	description.bbcode_enabled = false
	description.text = "Kon's buildings are walkable structures -- the Splicing Laboratory alone is 34x28 -- so this is room to put several down next to each other and see what a town reads like. One central base, generous economy, and nothing that fights back."
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(description)

	_map_container().add_child(button)
	_map_container().move_child(button, insert_index)

func _add_citadel_march_button() -> void:
	if map_panel == null:
		return
	_ensure_map_scroll()
	if _map_container().has_node("CitadelMarchButton"):
		return
	var insert_index := maxi(0, _map_container().get_child_count())
	var button := Button.new()
	button.name = "CitadelMarchButton"
	button.custom_minimum_size = Vector2(680, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.pressed.connect(_on_citadel_march_pressed)

	var layout := VBoxContainer.new()
	layout.name = "CitadelMarchLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 12.0
	layout.offset_right = -18.0
	layout.offset_bottom = -12.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var name_label := Label.new()
	name_label.text = "The Citadel March"
	name_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = "192x192. Twice the frontier, with Kon's Arcane Citadel held as a guaranteed content plot."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#4FE3DC"))
	layout.add_child(subtitle)

	var description := RichTextLabel.new()
	description.custom_minimum_size = Vector2(620, 52)
	description.fit_content = true
	description.bbcode_enabled = false
	description.text = "A garrisoned fortress sits in its own quarter of the map: walls, a gatehouse choke, wall-walks and a keep. Take it early and you can re-summon your Observation Tower onto the keep plinth -- but the tower is your run, so moving it is the largest bet the game offers."
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(description)

	_map_container().add_child(button)
	_map_container().move_child(button, insert_index)

func _add_plot_generator_test_button() -> void:
	if map_panel == null:
		return
	_ensure_map_scroll()
	if _map_container().has_node("PlotGeneratorTestButton"):
		return
	var insert_index := maxi(0, _map_container().get_child_count())
	var button := Button.new()
	button.name = "PlotGeneratorTestButton"
	button.custom_minimum_size = Vector2(680, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.pressed.connect(_on_plot_generator_test_pressed)

	var layout := VBoxContainer.new()
	layout.name = "PlotGeneratorTestLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 12.0
	layout.offset_right = -18.0
	layout.offset_bottom = -12.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)

	var name_label := Label.new()
	name_label.text = "Plot Generator Test"
	name_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = "Tiny Swords island generator: coastlines, cliffs, foam, decoration, and road anchors."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#7DDDE8"))
	layout.add_child(subtitle)

	var description := RichTextLabel.new()
	description.custom_minimum_size = Vector2(620, 52)
	description.fit_content = true
	description.bbcode_enabled = false
	description.scroll_active = false
	description.text = "Focused mode for testing one procedural content plot in isolation. Reroll seeds in-game and keep good ones for the future world generator."
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(description)

	_map_container().add_child(button)
	_map_container().move_child(button, insert_index)
