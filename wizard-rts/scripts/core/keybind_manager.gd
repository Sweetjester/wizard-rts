extends Node

const CONFIG_PATH := "user://keybind_settings.cfg"
const CONFIG_SECTION := "keybinds"

const ACTION_ATTACK_MOVE := "attack_move"
const ACTION_PATROL := "patrol"
const ACTION_HOLD := "hold"
const ACTION_STOP := "stop"
# Army-management bindings (2026-08-31). F1/F2 follow the SC2 convention
# players already have in their fingers; Tab follows WC3's subgroup cycling,
# which is this project's standing tiebreaker for ambiguous design calls.
const ACTION_SELECT_HERO := "select_hero"
const ACTION_SELECT_ARMY := "select_army"
const ACTION_CYCLE_IDLE_PRODUCTION := "cycle_idle_production"
const ACTION_CYCLE_IDLE_UNIT := "cycle_idle_unit"
const ACTION_CYCLE_SUBGROUP := "cycle_subgroup"

var _defaults := {
	ACTION_ATTACK_MOVE: KEY_A,
	ACTION_PATROL: KEY_P,
	ACTION_HOLD: KEY_H,
	ACTION_STOP: KEY_S,
	ACTION_SELECT_HERO: KEY_F1,
	ACTION_SELECT_ARMY: KEY_F2,
	ACTION_CYCLE_IDLE_PRODUCTION: KEY_F3,
	ACTION_CYCLE_IDLE_UNIT: KEY_F4,
	ACTION_CYCLE_SUBGROUP: KEY_TAB,
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
	return [
		ACTION_ATTACK_MOVE,
		ACTION_PATROL,
		ACTION_HOLD,
		ACTION_STOP,
		ACTION_SELECT_HERO,
		ACTION_SELECT_ARMY,
		ACTION_CYCLE_IDLE_PRODUCTION,
		ACTION_CYCLE_IDLE_UNIT,
		ACTION_CYCLE_SUBGROUP,
	]

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
		ACTION_SELECT_HERO:
			return "Select Wizard"
		ACTION_SELECT_ARMY:
			return "Select Army"
		ACTION_CYCLE_IDLE_PRODUCTION:
			return "Cycle Idle Barracks"
		ACTION_CYCLE_IDLE_UNIT:
			return "Cycle Idle Unit"
		ACTION_CYCLE_SUBGROUP:
			return "Filter Selection By Type"
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
