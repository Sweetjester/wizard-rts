class_name RTSCommand
extends RefCounted

enum Type {
	NONE,
	SPAWN_ENTITY,
	MOVE_UNITS,
	STOP_UNITS,
	ATTACK_MOVE
}

var command_id: int = 0
var player_id: int = 0
var tick: int = 0
var type: Type = Type.NONE
var entity_ids: Array[int] = []
var target_cell: Vector2i = Vector2i.ZERO
var archetype: StringName = &"worker"
var payload: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"command_id": command_id,
		"player_id": player_id,
		"tick": tick,
		"type": int(type),
		"entity_ids": entity_ids.duplicate(),
		"target_cell": [target_cell.x, target_cell.y],
		"archetype": String(archetype),
		"payload": payload.duplicate(true),
	}

static func from_dict(data: Dictionary) -> RTSCommand:
	var command := RTSCommand.new()
	command.command_id = int(data.get("command_id", 0))
	command.player_id = int(data.get("player_id", 0))
	command.tick = int(data.get("tick", 0))
	command.type = int(data.get("type", Type.NONE))
	for entity_id in data.get("entity_ids", []):
		command.entity_ids.append(int(entity_id))
	var target = data.get("target_cell", [0, 0])
	if target is Array and target.size() >= 2:
		command.target_cell = Vector2i(int(target[0]), int(target[1]))
	command.archetype = StringName(data.get("archetype", "worker"))
	command.payload = data.get("payload", {}).duplicate(true)
	return command

static func sort_key(command: RTSCommand) -> String:
	return "%010d:%010d:%010d" % [command.tick, command.player_id, command.command_id]
