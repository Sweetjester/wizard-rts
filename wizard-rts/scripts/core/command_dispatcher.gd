class_name CommandDispatcher
extends Node

signal command_submitted(command: RTSCommand)

@export var simulation_runner_path: NodePath = NodePath("../SimulationRunner")
@export var multiplayer_session_path: NodePath = NodePath("../MultiplayerSession")
@export var map_generator_path: NodePath = NodePath("../MapGenerator")

var simulation_runner: SimulationRunner
var multiplayer_session: MultiplayerSession
var map_generator: Node

func _ready() -> void:
	simulation_runner = get_node_or_null(simulation_runner_path)
	multiplayer_session = get_node_or_null(multiplayer_session_path)
	map_generator = get_node_or_null(map_generator_path)

func submit_move(units: Array[Node], target_world: Vector2, offsets: Array[Vector2], shared_path: Array[Vector2]) -> void:
	var ids := _entity_ids(units)
	if simulation_runner != null and map_generator != null:
		var target_cell: Vector2i = map_generator.world_to_cell(target_world)
		_submit_command(simulation_runner.make_local_command(RTSCommand.Type.MOVE_UNITS, ids, target_cell))
	for i in units.size():
		var unit: Node = units[i]
		if not is_instance_valid(unit):
			continue
		if not shared_path.is_empty() and unit.has_method("issue_shared_path_order"):
			unit.issue_shared_path_order(shared_path, offsets[i])
		elif unit.has_method("issue_move_order_offset"):
			unit.issue_move_order_offset(target_world, offsets[i])

func submit_attack_move(units: Array[Node], target_world: Vector2) -> void:
	var ids := _entity_ids(units)
	if simulation_runner != null and map_generator != null:
		_submit_command(simulation_runner.make_local_command(RTSCommand.Type.ATTACK_MOVE, ids, map_generator.world_to_cell(target_world)))
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("issue_attack_move_order"):
			unit.issue_attack_move_order(target_world)

func submit_stop(units: Array[Node]) -> void:
	var ids := _entity_ids(units)
	if simulation_runner != null:
		_submit_command(simulation_runner.make_local_command(RTSCommand.Type.STOP_UNITS, ids, Vector2i.ZERO))
	for unit in units:
		if is_instance_valid(unit):
			unit.set("path", [])
			unit.set("moving", false)

func _submit_command(command: RTSCommand) -> void:
	if multiplayer_session != null and multiplayer_session.multiplayer.multiplayer_peer != null:
		multiplayer_session.submit_command(command)
	elif simulation_runner != null:
		simulation_runner.queue_command(command)
	command_submitted.emit(command)

func _entity_ids(units: Array[Node]) -> Array[int]:
	var ids: Array[int] = []
	for unit in units:
		if is_instance_valid(unit):
			var id := int(unit.get("simulation_entity_id"))
			if id > 0:
				ids.append(id)
	return ids
