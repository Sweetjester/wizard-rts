extends Control

const GAME_SCENE := "res://scripts/map/main_map.tscn"

@onready var main_panel: VBoxContainer = %MainPanel
@onready var audio_panel: VBoxContainer = %AudioPanel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var mute_check: CheckBox = %MuteCheck

func _ready() -> void:
	AudioManager.play_music()
	volume_slider.value = AudioManager.music_volume
	mute_check.button_pressed = AudioManager.music_muted
	audio_panel.hide()

func _on_start_pressed() -> void:
	GameSession.start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_audio_pressed() -> void:
	main_panel.hide()
	audio_panel.show()

func _on_back_pressed() -> void:
	audio_panel.hide()
	main_panel.show()

func _on_volume_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_mute_check_toggled(toggled_on: bool) -> void:
	AudioManager.set_music_muted(toggled_on)

func _on_quit_pressed() -> void:
	get_tree().quit()
