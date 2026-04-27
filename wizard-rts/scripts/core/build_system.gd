class_name BuildSystem
extends Node2D

const STRUCTURE_PREVIEW_TEXTURES := {
	&"wizard_tower": preload("res://assets/buildings/kon/wizard_tower.png"),
	&"bio_absorber": preload("res://assets/buildings/kon/bio_absorber.png"),
	&"barracks": preload("res://assets/buildings/kon/barracks.png"),
	&"terrible_vault": preload("res://assets/buildings/kon/terrible_vault.png"),
	&"vinewall": preload("res://assets/buildings/kon/vinewall_segment.png"),
	&"bio_launcher": preload("res://assets/buildings/kon/bio_launcher_rooted.png"),
}
const USE_PLACEHOLDER_BUILDING_PREVIEWS := true

signal structure_placed(player_id: int, archetype: StringName, cell: Vector2i)
signal structure_completed(player_id: int, archetype: StringName, cell: Vector2i)
signal build_rejected(reason: String)
signal unit_training_queued(player_id: int, producer: Node, archetype: StringName, queue_count: int)
signal unit_produced(player_id: int, archetype: StringName, cell: Vector2i)
signal upgrade_researched(player_id: int, upgrade_id: StringName)

@export var economy_manager_path: NodePath = NodePath("../EconomyManager")
@export var map_generator_path: NodePath = NodePath("../MapGenerator")
@export var simulation_runner_path: NodePath = NodePath("../SimulationRunner")
@export var rts_world_path: NodePath = NodePath("../RTSWorld")
@export var terrible_thing_scene: PackedScene = preload("res://scenes/units/terrible_thing.tscn")
@export var horror_scene: PackedScene = preload("res://scenes/units/horror.tscn")
@export var apex_scene: PackedScene = preload("res://scenes/units/apex.tscn")

var economy_manager: EconomyManager
var map_generator: Node
var simulation_runner: SimulationRunner
var rts_world: RTSWorld
var structures: Array[Dictionary] = []
var pending_archetype: StringName = &""
var _dragging_wall := false
var _wall_drag_start := Vector2i.ZERO
var _wall_drag_end := Vector2i.ZERO
var researched_upgrades: Dictionary = {}
var _launcher_elapsed := 0.0

func _ready() -> void:
	economy_manager = get_node_or_null(economy_manager_path)
	map_generator = get_node_or_null(map_generator_path)
	simulation_runner = get_node_or_null(simulation_runner_path)
	rts_world = get_node_or_null(rts_world_path)
	z_index = 120

func _process(delta: float) -> void:
	_sync_structure_damage_and_cleanup()
	_update_construction(delta)
	_update_production(delta)
	_update_structure_evolution(delta)
	_update_structure_regeneration(delta)
	_update_bio_launchers(delta)
	if pending_archetype == &"vinewall" and _dragging_wall:
		_wall_drag_end = map_generator.world_to_cell(get_global_mouse_position())
		queue_redraw()
	elif pending_archetype != &"":
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

func set_rally_point_for_structure(producer_node: Node, world_pos: Vector2) -> bool:
	var index := _structure_index_for_node(producer_node)
	if index < 0:
		return false
	if structures[index]["archetype"] != &"barracks":
		return false
	structures[index]["rally_point"] = world_pos
	var node: KonStructure = structures[index].get("node", null)
	if node != null and is_instance_valid(node):
		node.set_rally_point(world_pos)
	return true

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
		var command := simulation_runner.make_local_command(RTSCommand.Type.BUILD_STRUCTURE, [], cell, {"structure": str(archetype)})
		simulation_runner.queue_command(command)
	structure_placed.emit(player_id, archetype, cell)
	queue_redraw()
	return true

func research_upgrade(player_id: int, upgrade_id: StringName) -> bool:
	if researched_upgrades.has(upgrade_id):
		build_rejected.emit("Upgrade already researched")
		return false
	if not _has_completed_structure(player_id, &"terrible_vault"):
		build_rejected.emit("Requires completed Terrible Vault")
		return false
	var cost := _upgrade_cost(upgrade_id)
	if economy_manager == null or not economy_manager.spend(player_id, {&"bio": cost}):
		build_rejected.emit("Not enough Bio")
		return false
	researched_upgrades[upgrade_id] = true
	_apply_upgrade_to_existing_units(upgrade_id)
	upgrade_researched.emit(player_id, upgrade_id)
	return true

func has_upgrade(upgrade_id: StringName) -> bool:
	return researched_upgrades.has(upgrade_id)

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
		_apply_upgrades_to_unit(unit)
		var rally: Vector2 = producer.get("rally_point", Vector2.ZERO)
		if rally != Vector2.ZERO and unit.has_method("issue_move_order"):
			unit.call_deferred("issue_move_order", rally)
		if simulation_runner != null:
			var entity_id := simulation_runner.state.spawn_entity(player_id, archetype, spawn_cell)
			unit.set("simulation_entity_id", entity_id)
	if simulation_runner != null:
		var command := simulation_runner.make_local_command(RTSCommand.Type.PRODUCE_UNIT, [], spawn_cell, {"unit": str(archetype)})
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
		if structures[i]["archetype"] == &"bio_absorber" and bool(structures[i].get("complete", false)) and int(structures[i]["level"]) >= 2 and str(structures[i]["upgrade"]).is_empty():
			structures[i]["upgrade"] = str(upgrade_id)
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
		if not _is_placement_cell_free(blocked_cell):
			return false
	if archetype == &"bio_absorber":
		return not _plot_id_for_cell(cell).is_empty()
	return true

func _is_placement_cell_free(cell: Vector2i) -> bool:
	if map_generator == null or not map_generator.has_method("is_walkable_cell"):
		return false
	if not map_generator.is_walkable_cell(cell):
		return false
	for structure in structures:
		if structure.get("blocked_cells", []).has(cell):
			return false
	return true

func get_placement_cells(archetype: StringName, cell: Vector2i) -> Array[Vector2i]:
	var definition := UnitCatalog.get_definition(archetype)
	var footprint: Vector2i = definition.get("footprint", Vector2i.ONE)
	return _footprint_cells(cell, footprint)

func _footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(origin.x, origin.x + footprint.x):
		for y in range(origin.y, origin.y + footprint.y):
			cells.append(Vector2i(x, y))
	return cells

func _register_blockers(structure: Dictionary) -> void:
	if map_generator != null and map_generator.has_method("add_dynamic_blockers"):
		map_generator.add_dynamic_blockers(structure.get("blocked_cells", []))

func _unregister_blockers(structure: Dictionary) -> void:
	if map_generator != null and map_generator.has_method("remove_dynamic_blockers"):
		map_generator.remove_dynamic_blockers(structure.get("blocked_cells", []))

func _sync_structure_damage_and_cleanup() -> void:
	for i in range(structures.size() - 1, -1, -1):
		var structure: Dictionary = structures[i]
		var node = structure.get("node", null)
		if node == null or not is_instance_valid(node):
			_unregister_blockers(structure)
			structures.remove_at(i)
			continue
		if node is KonStructure:
			structure["hp"] = int(node.health)
			if int(structure["hp"]) <= 0:
				_unregister_blockers(structure)
				structures.remove_at(i)
				continue
			structures[i] = structure

func _create_structure_node(structure: Dictionary) -> KonStructure:
	var node := KonStructure.new()
	var cell: Vector2i = structure["cell"]
	var footprint: Vector2i = structure.get("footprint", Vector2i.ONE)
	node.configure(structure["archetype"], cell, footprint)
	node.set_runtime_stats(int(structure["player_id"]), int(structure.get("hp", 1)), int(structure.get("max_hp", 1)), int(structure.get("level", 1)))
	node.global_position = _footprint_center_world(cell, footprint)
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
			if structure["archetype"] == &"vinewall":
				structure["max_hp"] = int(float(structure["max_hp"]) * 1.15)
				structure["hp"] = structure["max_hp"]
			var node: KonStructure = structure.get("node", null)
			if node != null and is_instance_valid(node):
				node.set_runtime_stats(int(structure["player_id"]), int(structure["hp"]), int(structure["max_hp"]), next_level)
				node.set_level(next_level)
			changed = true
		structures[i] = structure
	if changed:
		queue_redraw()

func _update_structure_regeneration(delta: float) -> void:
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if not bool(structure.get("complete", false)):
			continue
		var definition := UnitCatalog.get_definition(structure["archetype"])
		var regen := float(definition.get("regeneration_per_second", 0.0))
		if researched_upgrades.has(&"thorned_vines") and structure["archetype"] == &"vinewall":
			regen += 3.0
		if regen <= 0.0:
			continue
		structure["hp"] = mini(int(structure["max_hp"]), int(float(structure["hp"]) + regen * delta))
		var node: KonStructure = structure.get("node", null)
		if node != null and is_instance_valid(node):
			node.set_runtime_stats(int(structure["player_id"]), int(structure["hp"]), int(structure["max_hp"]), int(structure.get("level", 1)))
		structures[i] = structure

func _update_bio_launchers(delta: float) -> void:
	_launcher_elapsed += delta
	if _launcher_elapsed < 0.25:
		return
	var step := _launcher_elapsed
	_launcher_elapsed = 0.0
	if rts_world != null:
		rts_world.rebuild_spatial()
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if structure["archetype"] != &"bio_launcher" or not bool(structure.get("complete", false)):
			continue
		var cooldown := float(UnitCatalog.get_definition(&"bio_launcher").get("attack_cooldown_ticks", 40)) / 20.0
		structure["attack_elapsed"] = float(structure.get("attack_elapsed", 0.0)) + step
		if float(structure["attack_elapsed"]) < cooldown:
			structures[i] = structure
			continue
		var target := _find_launcher_target(structure)
		if target == null:
			structures[i] = structure
			continue
		var shot_cost := int(UnitCatalog.get_definition(&"bio_launcher").get("shot_cost_bio", 3))
		if economy_manager != null and not economy_manager.spend(int(structure["player_id"]), {&"bio": shot_cost}):
			structures[i] = structure
			continue
		_fire_bio_launcher(structure, target)
		structure["attack_elapsed"] = 0.0
		structure["evolution_xp"] = float(structure.get("evolution_xp", 0.0)) + 18.0
		structures[i] = structure

func _find_launcher_target(structure: Dictionary) -> Node2D:
	var raw_node = structure.get("node", null)
	if raw_node == null or not is_instance_valid(raw_node) or not (raw_node is Node2D):
		return null
	var node := raw_node as Node2D
	var range := float(UnitCatalog.get_definition(&"bio_launcher").get("attack_range_cells", 9)) * 64.0
	var best: Node2D = null
	var best_distance := INF
	var candidates: Array[Node2D] = rts_world.query_enemy_units(node.global_position, range, int(structure["player_id"])) if rts_world != null else _fallback_unit_nodes()
	for unit in candidates:
		if not is_instance_valid(unit) or not (unit is Node2D):
			continue
		if int(unit.get("owner_player_id")) == int(structure["player_id"]):
			continue
		if not unit.has_method("take_damage"):
			continue
		var unit_node := unit as Node2D
		var distance := node.global_position.distance_squared_to(unit_node.global_position)
		if distance <= range * range and distance < best_distance:
			best = unit_node
			best_distance = distance
	return best

func _fire_bio_launcher(structure: Dictionary, target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var definition := UnitCatalog.get_definition(&"bio_launcher")
	var damage := int(definition.get("attack_damage", 24))
	var radius := float(definition.get("aoe_radius", 92.0))
	if researched_upgrades.has(&"launcher_bile"):
		damage += 8
		radius += 34.0
	var raw_source = structure.get("node", null)
	var source_node: Node = raw_source if raw_source != null and is_instance_valid(raw_source) and raw_source is Node else null
	if rts_world != null and source_node is Node2D:
		var weapon := WeaponCatalog.get_weapon(&"bio_launcher")
		var projectile := rts_world.spawn_projectile(source_node as Node2D, target, damage, weapon.get("color", Color("#8B1A1F")), float(weapon.get("speed", 420.0)), (source_node as Node2D).global_position + Vector2(0, -40))
		projectile.set_aoe_radius(radius)
		return
	var candidates: Array[Node2D] = _fallback_unit_nodes()
	for unit in candidates:
		if not is_instance_valid(unit) or not (unit is Node2D) or not unit.has_method("take_damage"):
			continue
		if int(unit.get("owner_player_id")) == int(structure["player_id"]):
			continue
		var unit_node := unit as Node2D
		if target == null or not is_instance_valid(target):
			return
		var distance: float = unit_node.global_position.distance_to(target.global_position)
		if distance <= radius:
			unit.take_damage(maxi(1, int(float(damage) * (1.0 - distance / (radius * 1.6)))), source_node)
	_draw_launcher_burst(target.global_position, radius)

func _fallback_unit_nodes() -> Array[Node2D]:
	var units: Array[Node2D] = []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit is Node2D:
			units.append(unit)
	return units

func _draw_launcher_burst(pos: Vector2, radius: float) -> void:
	var fx := Node2D.new()
	fx.set_script(preload("res://scripts/fx/aoe_burst_fx.gd"))
	get_parent().add_child(fx)
	fx.global_position = pos
	fx.call("configure", radius, Color("#7BC47F"), Color("#8B1A1F"))

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
		var structure_archetype: StringName = structure.get("archetype", &"")
		if structure_archetype != &"barracks":
			continue
		var current: StringName = structure.get("training_archetype", &"")
		if str(current).is_empty():
			_start_next_training(i)
			structure = structures[i]
			current = structure.get("training_archetype", &"")
			if str(current).is_empty():
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
	var next: StringName = queue.pop_front()
	structures[index]["production_queue"] = queue
	structures[index]["training_archetype"] = next
	structures[index]["training_progress"] = 0.0
	structures[index]["training_time"] = UnitCatalog.train_time(next)

func _sync_training_node(index: int) -> void:
	var node: KonStructure = structures[index].get("node", null)
	if node == null or not is_instance_valid(node):
		return
	var queue: Array = structures[index].get("production_queue", [])
	var training_archetype: StringName = structures[index].get("training_archetype", &"")
	node.set_training_state(queue.size(), training_archetype, float(structures[index].get("training_progress", 0.0)), float(structures[index].get("training_time", 0.0)))

func _activate_completed_structure(structure: Dictionary) -> void:
	if structure["archetype"] != &"bio_absorber" or economy_manager == null:
		return
	var player_id := int(structure["player_id"])
	var plot_id := str(structure.get("plot_id", ""))
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

func _has_completed_structure(player_id: int, archetype: StringName) -> bool:
	for structure in structures:
		if int(structure.get("player_id", -1)) == player_id and structure.get("archetype", &"") == archetype and bool(structure.get("complete", false)):
			return true
	return false

func _upgrade_cost(upgrade_id: StringName) -> int:
	match upgrade_id:
		&"thorned_vines":
			return 120
		&"accelerated_evolution":
			return 150
		&"hardened_horrors":
			return 140
		&"launcher_bile":
			return 160
	return 99999

func _apply_upgrade_to_existing_units(upgrade_id: StringName) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			_apply_upgrades_to_unit(unit)
	for i in structures.size():
		var structure: Dictionary = structures[i]
		if upgrade_id == &"thorned_vines" and structure.get("archetype", &"") == &"vinewall":
			structure["max_hp"] = int(float(structure.get("max_hp", 1)) * 1.18)
			structure["hp"] = mini(int(structure["max_hp"]), int(structure.get("hp", 1)) + 45)
			var node: KonStructure = structure.get("node", null)
			if node != null and is_instance_valid(node):
				node.set_runtime_stats(int(structure["player_id"]), int(structure["hp"]), int(structure["max_hp"]), int(structure.get("level", 1)))
		structures[i] = structure

func _apply_upgrades_to_unit(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _node_has_property(unit, "unit_archetype"):
		return
	var archetype: StringName = unit.get("unit_archetype")
	if researched_upgrades.has(&"hardened_horrors") and archetype == &"horror" and not bool(unit.get_meta("hardened_horrors_applied", false)):
		unit.set("max_health", int(unit.get("max_health")) + 20)
		unit.set("health", int(unit.get("health")) + 20)
		unit.set("attack_damage", int(unit.get("attack_damage")) + 2)
		unit.set_meta("hardened_horrors_applied", true)
	if researched_upgrades.has(&"accelerated_evolution") and _node_has_property(unit, "evolution_xp") and not bool(unit.get_meta("accelerated_evolution_applied", false)):
		unit.set("evolution_xp", float(unit.get("evolution_xp")) + 28.0)
		unit.set_meta("accelerated_evolution_applied", true)

func _node_has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
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
			_draw_cell_preview(cell, _can_place(&"vinewall", cell), _is_placement_cell_free(cell))
	elif pending_archetype != &"":
		var cell: Vector2i = map_generator.world_to_cell(get_global_mouse_position())
		var valid := _can_place(pending_archetype, cell)
		var cells := get_placement_cells(pending_archetype, cell)
		_draw_footprint_pad(cells, valid, true)
		_draw_structure_preview(pending_archetype, cells, valid)

func _draw_cell_preview(cell: Vector2i, placement_valid: bool, cell_valid: bool) -> void:
	var valid := placement_valid and cell_valid
	var fill := Color("#7BC47F", 0.22) if valid else Color("#C13030", 0.36)
	var line := Color("#7BC47F", 0.96) if valid else Color("#E85A5A", 0.98)
	var points := _cell_polygon(cell)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_colored_polygon(points, fill)
	draw_polyline(outline, line, 2.0)

func _draw_structure_preview(archetype: StringName, cells: Array[Vector2i], valid: bool) -> void:
	if cells.is_empty():
		return
	if USE_PLACEHOLDER_BUILDING_PREVIEWS:
		_draw_placeholder_structure_preview(archetype, cells, valid)
		return
	if not STRUCTURE_PREVIEW_TEXTURES.has(archetype):
		return
	var texture: Texture2D = STRUCTURE_PREVIEW_TEXTURES[archetype]
	var footprint := _footprint_extents(cells)
	var center := _footprint_center_world(cells[0], footprint)
	var tile_size := _grid_cell_size()
	var target_width := maxf(58.0, float(footprint.x + footprint.y) * tile_size.x * 0.31)
	var scale := target_width / maxf(1.0, float(texture.get_width()))
	var size := Vector2(texture.get_width(), texture.get_height()) * scale
	var tint := Color(1, 1, 1, 0.62) if valid else Color("#E85A5A", 0.52)
	var base_bottom := _footprint_bottom_y(cells)
	draw_texture_rect(texture, Rect2(Vector2(center.x - size.x * 0.5, base_bottom - size.y + 6.0), size), false, tint)

func _draw_placeholder_structure_preview(archetype: StringName, cells: Array[Vector2i], valid: bool) -> void:
	var color := _structure_color(archetype)
	if not valid:
		color = Color("#C13030")
	var top_offset := Vector2(0, -24.0)
	for cell in cells:
		var base := _cell_polygon(cell)
		var top := PackedVector2Array()
		for point in base:
			top.append(point + top_offset)
		draw_colored_polygon(base, Color(color.darkened(0.45), 0.58))
		draw_colored_polygon(top, Color(color, 0.72))
		for i in base.size():
			var next := (i + 1) % base.size()
			draw_line(base[i], top[i], Color(color.darkened(0.35), 0.72), 1.5)
			draw_line(top[i], top[next], Color(color.lightened(0.15), 0.86), 2.0)

func _draw_footprint_outline(cells: Array[Vector2i], valid: bool) -> void:
	if cells.is_empty():
		return
	var color := Color("#7BC47F", 1.0) if valid else Color("#E85A5A", 1.0)
	for cell in cells:
		var points := _cell_polygon(cell)
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, color, 3.0)

func _draw_footprint_pad(cells: Array[Vector2i], valid: bool, show_cell_lines: bool) -> void:
	if cells.is_empty():
		return
	var fill := Color("#7BC47F", 0.22) if valid else Color("#C13030", 0.34)
	var edge := Color("#7BC47F", 0.95) if valid else Color("#E85A5A", 0.95)
	for cell in cells:
		draw_colored_polygon(_cell_polygon(cell), fill)
	if show_cell_lines:
		for cell in cells:
			var points := _cell_polygon(cell)
			var outline := PackedVector2Array(points)
			outline.append(points[0])
			draw_polyline(outline, edge, 2.6)

func _footprint_bottom_y(cells: Array[Vector2i]) -> float:
	var bottom := -INF
	for cell in cells:
		for point in _cell_polygon(cell):
			bottom = maxf(bottom, point.y)
	return bottom

func _footprint_boundary_segments(cells: Array[Vector2i]) -> Array[Array]:
	var occupied := {}
	for cell in cells:
		occupied[cell] = true
	var segments: Array[Array] = []
	for cell in cells:
		var points := _cell_polygon(cell)
		if not occupied.has(cell + Vector2i(0, -1)):
			segments.append([points[0], points[1]])
		if not occupied.has(cell + Vector2i(1, 0)):
			segments.append([points[1], points[2]])
		if not occupied.has(cell + Vector2i(0, 1)):
			segments.append([points[2], points[3]])
		if not occupied.has(cell + Vector2i(-1, 0)):
			segments.append([points[3], points[0]])
	return segments

func _footprint_center_world(origin: Vector2i, footprint: Vector2i) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for cell in _footprint_cells(origin, footprint):
		sum += map_generator.cell_to_world(cell)
		count += 1
	if count <= 0:
		return map_generator.cell_to_world(origin)
	return sum / float(count)

func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = map_generator.cell_to_world(cell)
	var size := _grid_cell_size()
	if _uses_square_test_grid():
		var half := size * 0.5
		return PackedVector2Array([
			center + Vector2(-half.x, -half.y),
			center + Vector2(half.x, -half.y),
			center + Vector2(half.x, half.y),
			center + Vector2(-half.x, half.y),
		])
	var half_width := size.x * 0.5
	var half_height := size.y * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half_height),
		center + Vector2(half_width, 0),
		center + Vector2(0, half_height),
		center + Vector2(-half_width, 0),
	])

func _grid_cell_size() -> Vector2:
	if _uses_square_test_grid():
		return Vector2(64, 64)
	var layer = map_generator.get("layer_low")
	if layer != null and is_instance_valid(layer) and layer.get("tile_set") != null:
		return Vector2(layer.get("tile_set").tile_size)
	return Vector2(111, 55)

func _uses_square_test_grid() -> bool:
	if map_generator == null:
		return false
	var map_type := str(map_generator.get("map_type_id"))
	return map_type == "grid_test_canvas" or map_type == "ai_testing_ground"

func _footprint_extents(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ONE
	var min_cell: Vector2i = cells[0]
	var max_cell: Vector2i = cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return max_cell - min_cell + Vector2i.ONE

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
				return str(zone.get("plot_id", ""))
	return ""
