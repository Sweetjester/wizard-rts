extends Node

const DEFAULT_MAP_TYPE := "seeded_grid_frontier"
const DEFAULT_OBJECTIVE_ID := "defeat_boss"
const OBJECTIVE_IDS := ["defeat_boss", "destroy_outposts", "survive_siege"]

var map_type_id: String = DEFAULT_MAP_TYPE
var map_seed_text: String = ""
var map_seed: int = 20260425
var wizard_class_id: String = "bad_kon_willow"
var objective_id: String = DEFAULT_OBJECTIVE_ID
var new_game_requested: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func start_new_game(seed_text: String = "", selected_wizard_class_id: String = "bad_kon_willow", selected_map_type_id: String = DEFAULT_MAP_TYPE, selected_objective_id: String = "") -> void:
	map_type_id = selected_map_type_id
	wizard_class_id = selected_wizard_class_id
	objective_id = selected_objective_id if OBJECTIVE_IDS.has(selected_objective_id) else OBJECTIVE_IDS[_rng.randi() % OBJECTIVE_IDS.size()]
	if seed_text.strip_edges().is_empty():
		map_seed_text = _make_random_seed_text()
	else:
		map_seed_text = seed_text
	new_game_requested = true
	print("[GameSession] New game seed: ", map_seed_text, " objective: ", objective_id)

func use_default_game() -> void:
	map_type_id = DEFAULT_MAP_TYPE
	map_seed_text = ""
	wizard_class_id = "bad_kon_willow"
	objective_id = DEFAULT_OBJECTIVE_ID
	new_game_requested = false

func _make_random_seed_text() -> String:
	return "run-%d-%d-%d" % [
		int(Time.get_unix_time_from_system() * 1000.0),
		Time.get_ticks_usec(),
		_rng.randi(),
	]
