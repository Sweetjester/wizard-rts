class_name SimulationState
extends RefCounted

const DEFAULT_MAX_HP := 40
const DEFAULT_MOVE_SPEED_CELLS := 1

var tick: int = 0
var seed: int = 1
var next_entity_id: int = 1
var entities: Dictionary = {}
var rng: DeterministicRng

func _init(initial_seed: int = 1) -> void:
	reset(initial_seed)

func reset(initial_seed: int = 1) -> void:
	tick = 0
	seed = initial_seed
	next_entity_id = 1
	entities.clear()
	rng = DeterministicRng.new(seed)

func step(commands: Array) -> void:
	commands.sort_custom(func(a: RTSCommand, b: RTSCommand) -> bool:
		return RTSCommand.sort_key(a) < RTSCommand.sort_key(b)
	)
	for command: RTSCommand in commands:
		_apply_command(command)
	_update_entities()
	tick += 1

func spawn_entity(player_id: int, archetype: StringName, cell: Vector2i) -> int:
	var id := next_entity_id
	next_entity_id += 1
	entities[id] = {
		"id": id,
		"player_id": player_id,
		"archetype": archetype,
		"cell": cell,
		"max_hp": DEFAULT_MAX_HP,
		"hp": DEFAULT_MAX_HP,
		"speed_cells": DEFAULT_MOVE_SPEED_CELLS,
		"path": [],
		"command_target": cell,
	}
	return id

func get_entity(entity_id: int) -> Dictionary:
	if not entities.has(entity_id):
		return {}
	return entities[entity_id].duplicate(true)

func get_entities_for_player(player_id: int) -> Array[int]:
	var ids: Array[int] = []
	for id in entities.keys():
		if int(entities[id]["player_id"]) == player_id:
			ids.append(int(id))
	ids.sort()
	return ids

func get_state_hash() -> String:
	var snapshot: Array = []
	var ids := entities.keys()
	ids.sort()
	for id in ids:
		var entity: Dictionary = entities[id]
		var cell: Vector2i = entity["cell"]
		var target: Vector2i = entity["command_target"]
		snapshot.append([
			int(id),
			int(entity["player_id"]),
			String(entity["archetype"]),
			cell.x,
			cell.y,
			int(entity["hp"]),
			target.x,
			target.y,
		])
	return JSON.stringify({
		"tick": tick,
		"seed": seed,
		"next_entity_id": next_entity_id,
		"rng": rng.get_state(),
		"entities": snapshot,
	})

func _apply_command(command: RTSCommand) -> void:
	match command.type:
		RTSCommand.Type.SPAWN_ENTITY:
			spawn_entity(command.player_id, command.archetype, command.target_cell)
		RTSCommand.Type.MOVE_UNITS, RTSCommand.Type.ATTACK_MOVE:
			_set_move_targets(command)
		RTSCommand.Type.STOP_UNITS:
			_stop_units(command)

func _set_move_targets(command: RTSCommand) -> void:
	for entity_id in command.entity_ids:
		if not entities.has(entity_id):
			continue
		var entity: Dictionary = entities[entity_id]
		if int(entity["player_id"]) != command.player_id:
			continue
		var path := _make_straight_grid_path(entity["cell"], command.target_cell)
		entity["path"] = path
		entity["command_target"] = command.target_cell

func _stop_units(command: RTSCommand) -> void:
	for entity_id in command.entity_ids:
		if not entities.has(entity_id):
			continue
		var entity: Dictionary = entities[entity_id]
		if int(entity["player_id"]) != command.player_id:
			continue
		entity["path"] = []
		entity["command_target"] = entity["cell"]

func _update_entities() -> void:
	var ids := entities.keys()
	ids.sort()
	for id in ids:
		var entity: Dictionary = entities[id]
		var speed := int(entity.get("speed_cells", DEFAULT_MOVE_SPEED_CELLS))
		for _i in speed:
			var path: Array = entity["path"]
			if path.is_empty():
				break
			entity["cell"] = path.pop_front()

func _make_straight_grid_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cell := start
	while cell != target:
		cell.x += signi(target.x - cell.x)
		cell.y += signi(target.y - cell.y)
		path.append(cell)
	return path

func signi(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0
