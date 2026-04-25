extends Node

const DEFAULT_MAP_TYPE := "vampire_mushroom_forest"

var map_type_id: String = DEFAULT_MAP_TYPE
var map_seed_text: String = ""
var map_seed: int = 20260425
var new_game_requested: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func start_new_game(seed_text: String = "") -> void:
	map_type_id = DEFAULT_MAP_TYPE
	if seed_text.strip_edges().is_empty():
		map_seed_text = _make_random_seed_text()
	else:
		map_seed_text = seed_text
	new_game_requested = true
	print("[GameSession] New game seed: ", map_seed_text)

func use_default_game() -> void:
	map_type_id = DEFAULT_MAP_TYPE
	map_seed_text = ""
	new_game_requested = false

func _make_random_seed_text() -> String:
	return "run-%d-%d-%d" % [
		int(Time.get_unix_time_from_system() * 1000.0),
		Time.get_ticks_usec(),
		_rng.randi(),
	]
