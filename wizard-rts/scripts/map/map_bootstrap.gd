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
	var map_type_id := str(map_generator.get("map_type_id"))
	if map_type_id == "fortress_ai_arena":
		if not _spawn_ai_fortress_bases(map_generator):
			call_deferred("_spawn_if_ready")
			return
		_spawned = true
		print("[MapBootstrap] Siege arena: spawned mirrored AI forts, no player wizard")
		return
	if map_type_id == "ai_testing_ground":
		_spawned = true
		print("[MapBootstrap] Observation arena: no player wizard or HQ spawned")
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
	var archetype: StringName = wizard.get("unit_archetype")
	var entity_id := simulation_runner.state.spawn_entity(int(wizard.get("owner_player_id")), archetype, spawn_cell)
	wizard.set("simulation_entity_id", entity_id)

func _place_starting_hq(spawn_cell: Vector2i) -> void:
	var build_system := get_parent().get_node_or_null("BuildSystem")
	if build_system == null or not build_system.has_method("add_free_structure"):
		return
	build_system.call("add_free_structure", 1, &"wizard_tower", spawn_cell + Vector2i(2, 0), spawn_base_plot_id)

func _spawn_ai_fortress_bases(map_generator: Node) -> bool:
	var build_system := get_parent().get_node_or_null("BuildSystem")
	if build_system == null or not build_system.has_method("add_free_structure"):
		return false
	_place_fort(map_generator, build_system, 2, Rect2i(10, 28, 18, 20), true)
	_place_fort(map_generator, build_system, 3, Rect2i(68, 28, 18, 20), false)
	return true

func _place_fort(map_generator: Node, build_system: Node, player_id: int, rect: Rect2i, gate_on_right: bool) -> void:
	var gate_y1 := rect.position.y + 8
	var gate_y2 := rect.position.y + 11
	var wall_cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		wall_cells.append(Vector2i(x, rect.position.y))
		wall_cells.append(Vector2i(x, rect.end.y - 1))
	for y in range(rect.position.y + 1, rect.end.y - 1):
		var left_gate := not gate_on_right and y >= gate_y1 and y <= gate_y2
		var right_gate := gate_on_right and y >= gate_y1 and y <= gate_y2
		if not left_gate:
			wall_cells.append(Vector2i(rect.position.x, y))
		if not right_gate:
			wall_cells.append(Vector2i(rect.end.x - 1, y))
	_add_wall_blockers(map_generator, wall_cells, Color("#0A1612", 0.78) if player_id == 2 else Color("#142420", 0.78))

	if gate_on_right:
		_add_free_structure(build_system, player_id, &"wizard_tower", rect.position + Vector2i(3, 8), "fort_west_base")
		_add_free_structure(build_system, player_id, &"barracks", rect.position + Vector2i(7, 3), "fort_west_base")
		_add_free_structure(build_system, player_id, &"terrible_vault", rect.position + Vector2i(8, 15), "fort_west_base")
		_add_free_structure(build_system, player_id, &"bio_launcher", rect.position + Vector2i(13, 6), "fort_west_base")
		_add_free_structure(build_system, player_id, &"bio_launcher", rect.position + Vector2i(13, 12), "fort_west_base")
	else:
		_add_free_structure(build_system, player_id, &"wizard_tower", rect.position + Vector2i(14, 8), "fort_east_base")
		_add_free_structure(build_system, player_id, &"barracks", rect.position + Vector2i(8, 3), "fort_east_base")
		_add_free_structure(build_system, player_id, &"terrible_vault", rect.position + Vector2i(8, 15), "fort_east_base")
		_add_free_structure(build_system, player_id, &"bio_launcher", rect.position + Vector2i(3, 6), "fort_east_base")
		_add_free_structure(build_system, player_id, &"bio_launcher", rect.position + Vector2i(3, 12), "fort_east_base")

func _add_free_structure(build_system: Node, player_id: int, archetype: StringName, cell: Vector2i, plot_id: String = "") -> void:
	build_system.call("add_free_structure", player_id, archetype, cell, plot_id)

func _add_wall_blockers(map_generator: Node, cells: Array[Vector2i], color: Color) -> void:
	if map_generator != null and map_generator.has_method("add_dynamic_blockers"):
		map_generator.call("add_dynamic_blockers", cells)
	var visual := FortWallVisual.new()
	get_parent().add_child(visual)
	visual.configure(map_generator, cells, color)

func _find_spawn_cell(base_plots: Array, map_generator: Node) -> Vector2i:
	for plot in base_plots:
		if str(plot.get("id", "")) == spawn_base_plot_id:
			return map_generator.nearest_walkable_cell(plot["anchor"], 8)
	var fallback: Dictionary = base_plots[0]
	return map_generator.nearest_walkable_cell(fallback["anchor"], 8)
