extends Node

const CONFIG_PATH := "user://keybind_settings.cfg"
const CONFIG_SECTION := "keybinds"

const ACTION_ATTACK_MOVE := "attack_move"
const ACTION_PATROL := "patrol"
const ACTION_HOLD := "hold"
const ACTION_STOP := "stop"

var _defaults := {
	ACTION_ATTACK_MOVE: KEY_A,
	ACTION_PATROL: KEY_P,
	ACTION_HOLD: KEY_H,
	ACTION_STOP: KEY_S,
}
var _bindings := {}

func _ready() -> void:
	reset_to_defaults(false)
	_load_settings()

func is_action(event: InputEventKey, action: String) -> bool:
	return event.physical_keycode == int(_bindings.get(action, _defaults.get(action, 0)))

func get_keycode(action: String) -> int:
	return int(_bindings.get(action, _defaults.get(action, 0)))

func get_key_label(action: String) -> String:
	return OS.get_keycode_string(get_keycode(action))

func set_keycode(action: String, keycode: int) -> void:
	if not _defaults.has(action):
		return
	_bindings[action] = keycode
	_save_settings()

func reset_to_defaults(save: bool = true) -> void:
	_bindings.clear()
	for action in _defaults.keys():
		_bindings[action] = int(_defaults[action])
	if save:
		_save_settings()

func get_actions() -> Array[String]:
	return [ACTION_ATTACK_MOVE, ACTION_PATROL, ACTION_HOLD, ACTION_STOP]

func get_action_display_name(action: String) -> String:
	match action:
		ACTION_ATTACK_MOVE:
			return "Attack Move"
		ACTION_PATROL:
			return "Patrol"
		ACTION_HOLD:
			return "Hold Position"
		ACTION_STOP:
			return "Stop"
	return action.capitalize()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for action in _defaults.keys():
		_bindings[action] = int(config.get_value(CONFIG_SECTION, action, _bindings[action]))

func _save_settings() -> void:
	var config := ConfigFile.new()
	for action in _defaults.keys():
		config.set_value(CONFIG_SECTION, action, int(_bindings[action]))
	config.save(CONFIG_PATH)
