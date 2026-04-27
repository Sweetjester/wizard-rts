extends Control

const GAME_SCENE := "res://scripts/map/main_map.tscn"

@onready var main_panel: VBoxContainer = %MainPanel
@onready var audio_panel: VBoxContainer = %AudioPanel
@onready var display_panel: VBoxContainer = %DisplayPanel
@onready var character_panel: VBoxContainer = %CharacterPanel
@onready var map_panel: VBoxContainer = %MapPanel
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
var selected_map_type_id := ""

func _ready() -> void:
	AudioManager.play_map_music()
	volume_slider.value = AudioManager.music_volume
	mute_check.button_pressed = AudioManager.music_muted
	_setup_display_controls()
	_show_main()

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
	selected_map_type_id = GameSession.DEFAULT_MAP_TYPE
	begin_button.disabled = false

func _on_grid_test_map_pressed() -> void:
	selected_map_type_id = "grid_test_canvas"
	begin_button.disabled = false

func _on_ai_testing_ground_pressed() -> void:
	selected_map_type_id = "ai_testing_ground"
	begin_button.disabled = false

func _on_begin_pressed() -> void:
	if selected_character_id.is_empty():
		return
	if selected_map_type_id.is_empty():
		return
	GameSession.start_new_game("", selected_character_id, selected_map_type_id)
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

func _show_main() -> void:
	main_panel.show()
	audio_panel.hide()
	display_panel.hide()
	character_panel.hide()
	map_panel.hide()

func _show_audio() -> void:
	main_panel.hide()
	audio_panel.show()
	display_panel.hide()
	character_panel.hide()
	map_panel.hide()

func _show_display() -> void:
	main_panel.hide()
	audio_panel.hide()
	display_panel.show()
	character_panel.hide()
	map_panel.hide()

func _show_character() -> void:
	main_panel.hide()
	audio_panel.hide()
	display_panel.hide()
	character_panel.show()
	map_panel.hide()

func _show_map() -> void:
	main_panel.hide()
	audio_panel.hide()
	display_panel.hide()
	character_panel.hide()
	map_panel.show()

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
