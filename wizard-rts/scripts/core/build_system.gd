class_name BuildSystem
extends Node2D

signal structure_placed(player_id: int, archetype: StringName, cell: Vector2i)
signal structure_completed(player_id: int, archetype: StringName, cell: Vector2i)
signal build_rejected(reason: String)
signal unit_training_queued(player_id: int, producer: Node, archetype: StringName, queue_count: int)
signal unit_produced(player_id: int, archetype: StringName, cell: Vector2i)

@export var economy_manager_path: NodePath = NodePath("../EconomyManager")
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var simulation_runner_path: NodePath = NodePath("../SimulationRunner")
@export var terrible_thing_scene: PackedScene = preload("res://scenes/units/terrible_thing.tscn")
@export var horror_scene: PackedScene = preload("res://scenes/units/horror.tscn")
@export var apex_scene: PackedScene = preload("res://scenes/units/apex.tscn")

var economy_manager: EconomyManager
var map_generator: Node
var simulation_runner: SimulationRunner
var structures: Array[Dictionary] = []
var pending_archetype: StringName = &""
var _dragging_wall := false
var _wall_drag_start := Vector2i.ZERO
var _wall_drag_end := Vector2i.ZERO

func _ready() -> void:
	economy_manager = get_node_or_null(economy_manager_path)
	map_generator = get_node_or_null(map_generator_path)
	simulation_runner = get_node_or_null(simulation_runner_path)
	z_index = 120

func _process(delta: float) -> void:
	_update_construction(delta)
	_update_production(delta)
	_update_structure_evolution(delta)
	if pending_archetype == &"vinewall" and _dragging_wall:
		_wall_drag_end = map_generator.world_to_cell(get_global_mouse_position())
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if pending_archetype == &"":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = map_generator.world_to_cell(get_global_mouse_position())
		if pending_archetype == &"vinewall":
			if event.pressed:
				_dragging_wall = true
				_wall_drag_start = cell
				_wall_drag_end = cell
			else:
				_place_vinewall_drag(1, _wall_drag_start, cell)
				_dragging_wall = false
				pending_archetype = &""
		elif event.pressed:
			try_place_structure(1, pending_archetype, cell)
			pending_archetype = &""
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		pending_archetype = &""
		_dragging_wall = false
		queue_redraw()
		get_viewport().set_input_as_handled()

func start_placement(archetype: StringName) -> void:
	pending_archetype = archetype

func try_place_structure(player_id: int, archetype: StringName, cell: Vector2i) -> bool:
	var definition := UnitCatalog.get_definition(archetype)
	if definition.is_empty():
		build_rejected.emit("Unknown structure: %s" % archetype)
		return false
	var costs := {&"bio": int(definition.get("cost_bio", 0))}
	if economy_manager == null or not economy_manager.spend(player_id, costs):
		build_rejected.emit("Not enough Bio")
		return false
	if not _can_place(archetype, cell):
		economy_manager.add_resource(player_id, &"bio", int(costs[&"bio"]))
		build_rejected.emit("Invalid placement")
		return false
	var plot_id := _plot_id_for_cell(cell)
	if archetype == &"bio_absorber" and plot_id.is_empty():
		economy_manager.add_resource(player_id, &"bio", int(costs[&"bio"]))
		build_rejected.emit("Bio Absorber must be placed on an economy space")
		return false
	var structure := _make_structure_data(player_id, archetype, cell, plot_id, definition)
	structure["node"] = _create_structure_node(structure)
	structures.append(structure)
	_register_blockers(structure)
	if simulation_runner != null:
		var command := simulation_runner.make_local_command(RTSCommand.Type.BUILD_STRUCTURE, [], cell, {"structure": String(archetype)})
		simulation_runner.queue_command(command)
	structure_placed.emit(player_id, archetype, cell)
	queue_redraw()
	return true

func _make_structure_data(player_id: int, archetype: StringName, cell: Vector2i, plot_id: String, definition: Dictionary) -> Dictionary:
	var hp := int(definition.get("max_hp", 200))
	if definition.has("starts_at_hp_percent"):
		hp = int(float(hp) * float(definition["starts_at_hp_percent"]))
	var footprint: Vector2i = definition.get("footprint", Vector2i.ONE)
	var build_time := float(definition.get("build_time_seconds", 0.0))
	return {
		"player_id": player_id,
		"archetype": archetype,
		"cell": cell,
		"plot_id": plot_id,
		"hp": hp,
		"max_hp": int(definition.get("max_hp", 200)),
		"footprint": footprint,
		"blocked_cells": _footprint_cells(cell, footprint),
		"build_time": build_time,
		"build_progress": 0.0,
		"complete": build_time <= 0.0,
		"production_queue": [],
		"training_archetype": &"",
		"training_progress": 0.0,
		"training_time": 0.0,
		"evolution_xp": 0.0,
		"level": 1,
		"upgrade": "",
		"node": null,
	}

func add_free_structure(player_id: int, archetype: StringName, cell: Vector2i, plot_id: String = "") -> void:
	var definition := UnitCatalog.get_definition(archetype)
	var structure := _make_structure_data(player_id, archetype, cell, plot_id, definition)
	structure["build_progress"] = float(structure["build_time"])
	structure["complete"] = true
	structure["node"] = _create_structure_node(structure)
	structures.append(structure)
	_register_blockers(structure)
	structure_placed.emit(player_id, archetype, cell)
	queue_redraw()

func _place_vinewall_drag(player_id: int, start: Vector2i, end: Vector2i) -> void:
	var cells := _line_cells(start, end)
	if cells.is_empty():
		return
	var cost := UnitCatalog.cost_bio(&"vinewall") * cells.size()
	if economy_manager == null or not economy_manager.spend(player_id, {&"bio": cost}):
		build_rejected.emit("Not enough Bio for Vinewall")
		return
	var placed := 0
	for cell in cells:
		if not _can_place(&"vinewall", cell):
			continue
		var definition := UnitCatalog.get_definition(&"vinewall")
		var structure := _make_structure_data(player_id, &"vinewall", cell, "", definition)
		structure["node"] = _create_structure_node(structure)
		structures.append(structure)
		_register_blockers(structure)
		placed += 1
		structure_placed.emit(player_id, &"vinewall", cell)
	if placed < cells.size():
		var refund := UnitCatalog.cost_bio(&"vinewall") * (cells.size() - placed)
		economy_manager.add_resource(player_id, &"bio", refund)
	if placed == 0:
		build_rejected.emit("No valid Vinewall cells")
	queue_redraw()

func produce_unit(player_id: int, archetype: StringName) -> bool:
	var producer := _first_structure_with_production(archetype, player_id)
	if producer.is_empty():
		if _has_incomplete_structure_with_production(archetype, player_id):
			build_rejected.emit("Barracks is still building")
		else:
			build_rejected.emit("Requires completed Barracks")
		return false
	var costs := {&"bio": UnitCatalog.cost_bio(archetype)}
	if economy_manager == null or not economy_manager.spend(player_id, costs):
		build_rejected.emit("Not enough Bio")
		return false
	return _enqueue_unit_at_structure(player_id, archetype, producer)

func _spawn_trained_unit(player_id: int, archetype: StringName, producer: Dictionary) -> bool:
	var spawn_cell: Vector2i = map_generator.nearest_walkable_cell(producer["cell"] + Vector2i(2, 2), 8)
	var scene := _scene_for_unit(archetype)
	if scene != null:
		var unit := scene.instantiate()
		unit.set("owner_player_id", player_id)
		get_parent().add_child(unit)
		unit.global_position = map_generator.cell_to_world(spawn_cell)
		if simulation_runner != null:
			var entity_id := simulation_runner.state.spawn_entity(player_id, archetype, spawn_cell)
			unit.set("simulation_entity_id", entity_id)
	if simulation_runner != null:
		var command := simulation_runner.make_local_command(RTSCommand.Type.PRODUCE_UNIT, [], spawn_cell, {"unit": String(archetype)})
		simulation_runner.queue_command(command)
	unit_produced.emit(player_id, archetype, spawn_cell)
	return true

func _enqueue_unit_at_structure(player_id: int, archetype: StringName, producer: Dictionary) -> bool:
	var index := _structure_index_for_node(producer.get("node", null))
	if index < 0:
		build_rejected.emit("Production building was not found")
		return false
	var queue: Array = structures[index].get("production_queue", [])
	if queue.size() >= 5:
		build_rejected.emit("Training queue is full")
		return false
	queue.append(archetype)
	structures[index]["production_queue"] = queue
	_sync_training_node(index)
	unit_training_queued.emit(player_id, structures[index].get("node", null), archetype, queue.size())
	return true

func produce_unit_from_structure(player_id: int, archetype: StringName, producer_node: Node) -> bool:
	var producer := _structure_for_node(producer_node)
	if producer.is_empty():
		build_rejected.emit("Select a Barracks")
		return false
	if int(producer["player_id"]) != player_id:
		build_rejected.emit("That Barracks belongs to another player")
		return false
	if not bool(producer.get("complete", false)):
		build_rejected.emit("Barracks is still building")
		return false
	var definition := UnitCatalog.get_definition(producer["archetype"])
	if not definition.get("production", []).has(archetype):
		build_rejected.emit("This building cannot train that unit")
		return false
	var costs := {&"bio": UnitCatalog.cost_bio(archetype)}
	if economy_manager == null or not economy_manager.spend(player_id, costs):
		build_rejected.emit("Not enough Bio")
		return false
	return _enqueue_unit_at_structure(player_id, archetype, producer)

func apply_first_absorber_upgrade(upgrade_id: StringName) -> bool:
	for i in structures.size():
		if structures[i]["archetype"] == &"bio_absorber" and bool(structures[i].get("complete", false)) and int(structures[i]["level"]) >= 2 and String(structures[i]["upgrade"]).is_empty():
			structures[i]["upgrade"] = String(upgrade_id)
			queue_redraw()
			return true
	build_rejected.emit("Requires evolved Bio Absorber")
	return false

func get_structures() -> Array[Dictionary]:
	return structures.duplicate(true)

func _can_place(archetype: StringName, cell: Vector2i) -> bool:
	if map_generator == null or not map_generator.has_method("is_walkable_cell"):
		return false
	var definition := UnitCatalog.get_definition(archetype)
	var footprint: Vector2i = definition.get("footprint", Vector2i.ONE)
	for blocked_cell in _footprint_cells(cell, footprint):
		if not map_generator.is_walkable_cell(blocked_cell):
			return false
		for structure in structures:
			if structure.get("blocked_cells", []).has(blocked_cell):
				return false
	if archetype == &"bio_absorber":
		return not _plot_id_for_cell(cell).is_empty()
	return true

func _footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(origin.x, origin.x + footprint.x):
		for y in range(origin.y, origin.y + footprint.y):
			cells.append(Vector2i(x, y))
	return cells

func _register_blockers(structure: Dictionary) -> void:
	if map_generator != null and map_generator.has_method("add_dynamic_blockers"):
		map_generator.add_dynamic_blockers(structure.get("blocked_cells", []))

func _create_structure_node(structure: Dictionary) -> KonStructure:
	var node := KonStructure.new()
	var cell: Vector2i = structure["cell"]
	var footprint: Vector2i = structure.get("footprint", Vector2i.ONE)
	node.configure(structure["archetype"], cell, footprint)
	node.set_runtime_stats(int(structure["player_id"]), int(structure.get("hp", 1)), int(structure.get("max_hp", 1)), int(structure.get("level", 1)))
	node.global_position = map_generator.cell_to_world(cell)
	node.z_index = int(node.global_position.y) + 160
	node.set_construction_state(float(structure.get("build_progress", 0.0)), float(structure.get("build_time", 0.0)), bool(structure.get("complete", true)))
	get_parent().add_child(node)
	return node

func _line_cells(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := end - start
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps == 0:
		return [start]
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector2i(roundi(lerpf(float(start.x), float(end.x), t)), roundi(lerpf(float(start.y), float(end.y), t)))
		if not cells.has(cell):
			cells.append(cell)
	return cells

func _update_structure_evolution(delta: float) -> void:
	var changed := false
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if not bool(structure.get("complete", false)):
			continue
		var definition := UnitCatalog.get_definition(structure["archetype"])
		if not bool(definition.get("auto_evolves", false)):
			continue
		structure["evolution_xp"] = float(structure.get("evolution_xp", 0.0)) + delta
		var needed := float(definition.get("evolution_seconds", 90.0))
		var next_level := int(structure.get("level", 1)) + 1
		if float(structure["evolution_xp"]) >= needed and next_level <= 3:
			structure["level"] = next_level
			structure["evolution_xp"] = 0.0
			structure["max_hp"] = int(float(structure["max_hp"]) * 1.2)
			structure["hp"] = structure["max_hp"]
			var node: KonStructure = structure.get("node", null)
			if node != null and is_instance_valid(node):
				node.set_runtime_stats(int(structure["player_id"]), int(structure["hp"]), int(structure["max_hp"]), next_level)
				node.set_level(next_level)
			changed = true
		structures[i] = structure
	if changed:
		queue_redraw()

func _update_construction(delta: float) -> void:
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if bool(structure.get("complete", false)):
			continue
		var build_time := float(structure.get("build_time", 0.0))
		var build_progress := float(structure.get("build_progress", 0.0)) + delta
		var completed := build_time <= 0.0 or build_progress >= build_time
		structure["build_progress"] = minf(build_progress, build_time)
		structure["complete"] = completed
		var node: KonStructure = structure.get("node", null)
		if node != null and is_instance_valid(node):
			node.set_construction_state(float(structure["build_progress"]), build_time, completed)
		if completed:
			_activate_completed_structure(structure)
			structure_completed.emit(int(structure["player_id"]), structure["archetype"], structure["cell"])
		structures[i] = structure

func _update_production(delta: float) -> void:
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if not bool(structure.get("complete", false)):
			continue
		if StringName(structure.get("archetype", &"")) != &"barracks":
			continue
		var current := StringName(structure.get("training_archetype", &""))
		if String(current).is_empty():
			_start_next_training(i)
			structure = structures[i]
			current = StringName(structure.get("training_archetype", &""))
			if String(current).is_empty():
				continue
		var progress := float(structure.get("training_progress", 0.0)) + delta
		var train_time := float(structure.get("training_time", UnitCatalog.train_time(current)))
		structure["training_progress"] = minf(progress, train_time)
		structures[i] = structure
		_sync_training_node(i)
		if progress >= train_time:
			_spawn_trained_unit(int(structure["player_id"]), current, structure)
			structures[i]["training_archetype"] = &""
			structures[i]["training_progress"] = 0.0
			structures[i]["training_time"] = 0.0
			_start_next_training(i)
			_sync_training_node(i)

func _start_next_training(index: int) -> void:
	var queue: Array = structures[index].get("production_queue", [])
	if queue.is_empty():
		structures[index]["training_archetype"] = &""
		structures[index]["training_progress"] = 0.0
		structures[index]["training_time"] = 0.0
		return
	var next := StringName(queue.pop_front())
	structures[index]["production_queue"] = queue
	structures[index]["training_archetype"] = next
	structures[index]["training_progress"] = 0.0
	structures[index]["training_time"] = UnitCatalog.train_time(next)

func _sync_training_node(index: int) -> void:
	var node: KonStructure = structures[index].get("node", null)
	if node == null or not is_instance_valid(node):
		return
	var queue: Array = structures[index].get("production_queue", [])
	node.set_training_state(queue.size(), StringName(structures[index].get("training_archetype", &"")), float(structures[index].get("training_progress", 0.0)), float(structures[index].get("training_time", 0.0)))

func _activate_completed_structure(structure: Dictionary) -> void:
	if structure["archetype"] != &"bio_absorber" or economy_manager == null:
		return
	var player_id := int(structure["player_id"])
	var plot_id := String(structure.get("plot_id", ""))
	var cell: Vector2i = structure["cell"]
	if not economy_manager.register_economy_building(player_id, plot_id, cell, structure["archetype"]):
		build_rejected.emit("Bio Absorber could not attach to its economy space")

func _first_structure_with_production(unit_archetype: StringName, player_id: int) -> Dictionary:
	for structure in structures:
		if int(structure["player_id"]) != player_id:
			continue
		if not bool(structure.get("complete", false)):
			continue
		var definition := UnitCatalog.get_definition(structure["archetype"])
		if definition.get("production", []).has(unit_archetype):
			return structure
	return {}

func _structure_for_node(producer_node: Node) -> Dictionary:
	for structure in structures:
		var node: Node = structure.get("node", null)
		if node == producer_node:
			return structure
	return {}

func _structure_index_for_node(producer_node: Node) -> int:
	for i in structures.size():
		var node: Node = structures[i].get("node", null)
		if node == producer_node:
			return i
	return -1

func _has_incomplete_structure_with_production(unit_archetype: StringName, player_id: int) -> bool:
	for structure in structures:
		if int(structure["player_id"]) != player_id:
			continue
		if bool(structure.get("complete", false)):
			continue
		var definition := UnitCatalog.get_definition(structure["archetype"])
		if definition.get("production", []).has(unit_archetype):
			return true
	return false

func _scene_for_unit(archetype: StringName) -> PackedScene:
	match archetype:
		&"terrible_thing", &"awful_thing":
			return terrible_thing_scene
		&"horror":
			return horror_scene
		&"apex", &"apex_predator":
			return apex_scene
	return null

func _draw() -> void:
	if map_generator == null:
		return
	if pending_archetype == &"vinewall" and _dragging_wall:
		for cell in _line_cells(_wall_drag_start, _wall_drag_end):
			var pos: Vector2 = map_generator.cell_to_world(cell)
			draw_circle(pos, 20.0, Color("#2D5A3E", 0.32))
			draw_arc(pos, 22.0, 0, TAU, 20, Color("#7BC47F", 0.8), 2.0)
	elif pending_archetype != &"":
		var cell: Vector2i = map_generator.world_to_cell(get_global_mouse_position())
		var pos: Vector2 = map_generator.cell_to_world(cell)
		var color := Color("#7BC47F", 0.32) if _can_place(pending_archetype, cell) else Color("#C13030", 0.42)
		var footprint: Vector2i = UnitCatalog.get_definition(pending_archetype).get("footprint", Vector2i.ONE)
		draw_rect(Rect2(pos - Vector2(32, 24), Vector2(64 * footprint.x, 48 * footprint.y)), color, true)

func _structure_color(archetype: StringName) -> Color:
	match archetype:
		&"bio_absorber":
			return Color("#7BC47F")
		&"barracks":
			return Color("#8B1A1F")
		&"terrible_vault":
			return Color("#7DDDE8")
		&"vinewall":
			return Color("#2D5A3E")
		&"bio_launcher":
			return Color("#C13030")
	return Color("#8A7560")

func _plot_id_for_cell(cell: Vector2i) -> String:
	if map_generator == null or not map_generator.has_method("get_economy_zones"):
		return ""
	for zone in map_generator.get_economy_zones():
		for economy_cell in zone.get("economy_spaces", []):
			if economy_cell == cell:
				return String(zone.get("plot_id", ""))
	return ""
