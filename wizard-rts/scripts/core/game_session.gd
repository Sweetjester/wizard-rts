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
# Renders the same game mode with a 3D map instead of the 2D tilemap. This is a
# PRESENTATION choice only -- the simulation, the map data, the units and every
# system are identical either way. See scripts/map/map_3d_view.gd.
var render_3d: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func start_new_game(seed_text: String = "", selected_wizard_class_id: String = "bad_kon_willow", selected_map_type_id: String = DEFAULT_MAP_TYPE, selected_objective_id: String = "", use_3d_view: bool = false) -> void:
	render_3d = use_3d_view
	map_type_id = selected_map_type_id
	wizard_class_id = selected_wizard_class_id
	objective_id = selected_objective_id if OBJECTIVE_IDS.has(selected_objective_id) else OBJECTIVE_IDS[_rng.randi() % OBJECTIVE_IDS.size()]
	if seed_text.strip_edges().is_empty():
		map_seed_text = _make_random_seed_text()
	else:
		map_seed_text = seed_text
	new_game_requested = true
	print("[GameSession] New game seed: ", map_seed_text, " objective: ", objective_id, " view: ", "3D" if render_3d else "2D")

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
