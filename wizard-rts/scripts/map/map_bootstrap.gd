extends Node

@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var wizard_scene: PackedScene = preload("res://wizard.tscn")
@export var spawn_base_plot_id: String = "base_plot_1"
@export var simulation_runner_path: NodePath = NodePath("../SimulationRunner")

var _spawned := false

func _ready() -> void:
	var map_generator = get_node_or_null(map_generator_path)
	if map_generator == null:
		push_error("[MapBootstrap] Missing MapGenerator")
		return
	if map_generator.has_signal("map_generated"):
		map_generator.map_generated.connect(_on_map_generated)
	call_deferred("_spawn_if_ready")

func _on_map_generated(_summary: Dictionary) -> void:
	_spawn_if_ready()

func _spawn_if_ready() -> void:
	if _spawned:
		return
	var map_generator = get_node_or_null(map_generator_path)
	if map_generator == null or not map_generator.has_method("get_base_plots"):
		return
	var base_plots: Array = map_generator.get_base_plots()
	if base_plots.is_empty():
		call_deferred("_spawn_if_ready")
		return

	var spawn_cell := _find_spawn_cell(base_plots, map_generator)
	var wizard := wizard_scene.instantiate()
	wizard.name = "Wizard"
	wizard.global_position = map_generator.cell_to_world(spawn_cell)
	get_parent().add_child(wizard)
	_register_simulation_entity(wizard, spawn_cell)
	_place_starting_hq(spawn_cell)
	_spawned = true
	print("[MapBootstrap] Wizard spawned at ", spawn_cell)

func _register_simulation_entity(wizard: Node, spawn_cell: Vector2i) -> void:
	var simulation_runner: SimulationRunner = get_node_or_null(simulation_runner_path)
	if simulation_runner == null:
		return
	var archetype := StringName(wizard.get("unit_archetype"))
	var entity_id := simulation_runner.state.spawn_entity(int(wizard.get("owner_player_id")), archetype, spawn_cell)
	wizard.set("simulation_entity_id", entity_id)

func _place_starting_hq(spawn_cell: Vector2i) -> void:
	var build_system: BuildSystem = get_parent().get_node_or_null("BuildSystem")
	if build_system == null:
		return
	build_system.add_free_structure(1, &"wizard_tower", spawn_cell + Vector2i(2, 0), spawn_base_plot_id)

func _find_spawn_cell(base_plots: Array, map_generator: Node) -> Vector2i:
	for plot in base_plots:
		if String(plot.get("id", "")) == spawn_base_plot_id:
			return map_generator.nearest_walkable_cell(plot["anchor"], 8)
	var fallback: Dictionary = base_plots[0]
	return map_generator.nearest_walkable_cell(fallback["anchor"], 8)
