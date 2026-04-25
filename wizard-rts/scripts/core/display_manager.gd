extends Node

const CONFIG_PATH := "user://display_settings.cfg"
const CONFIG_SECTION := "display"
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var resolution_index: int = 2
var fullscreen: bool = false
var performance_mode: bool = false

func _ready() -> void:
	_load_settings()
	_apply_settings()

func get_resolution_count() -> int:
	return RESOLUTIONS.size()

func get_resolution_label(index: int) -> String:
	var resolution: Vector2i = RESOLUTIONS[clampi(index, 0, RESOLUTIONS.size() - 1)]
	return "%d x %d" % [resolution.x, resolution.y]

func set_resolution_index(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	_apply_settings()
	_save_settings()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_settings()
	_save_settings()

func set_performance_mode(enabled: bool) -> void:
	performance_mode = enabled
	_apply_settings()
	_save_settings()

func _apply_settings() -> void:
	Engine.max_fps = 60
	var resolution: Vector2i = RESOLUTIONS[resolution_index]
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - resolution) / 2)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	resolution_index = int(config.get_value(CONFIG_SECTION, "resolution_index", resolution_index))
	fullscreen = bool(config.get_value(CONFIG_SECTION, "fullscreen", fullscreen))
	performance_mode = bool(config.get_value(CONFIG_SECTION, "performance_mode", performance_mode))
	resolution_index = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(CONFIG_SECTION, "resolution_index", resolution_index)
	config.set_value(CONFIG_SECTION, "fullscreen", fullscreen)
	config.set_value(CONFIG_SECTION, "performance_mode", performance_mode)
	config.save(CONFIG_PATH)
