class_name SimulationRunner
extends Node

signal tick_advanced(tick: int, state_hash: String)
signal command_queued(command: RTSCommand)
signal desync_detected(tick: int, local_hash: String, remote_hash: String)

@export var tick_rate: int = 20
@export var command_lead_ticks: int = 3
@export var initial_seed: int = 20260425
@export var auto_start: bool = true

var state := SimulationState.new()
var running: bool = false
var local_player_id: int = 1

var _accumulator: float = 0.0
var _next_command_id: int = 1
var _queued_commands: Dictionary = {}

func _ready() -> void:
	reset(initial_seed)
	running = auto_start

func _process(delta: float) -> void:
	if not running or tick_rate <= 0:
		return
	_accumulator += delta
	var step_seconds := 1.0 / float(tick_rate)
	while _accumulator >= step_seconds:
		_accumulator -= step_seconds
		_step_once()

func reset(seed: int) -> void:
	_accumulator = 0.0
	_next_command_id = 1
	_queued_commands.clear()
	state.reset(seed)

func queue_command(command: RTSCommand) -> void:
	if command.tick < state.tick:
		push_warning("[SimulationRunner] Dropping late command for tick %s at local tick %s" % [command.tick, state.tick])
		return
	if not _queued_commands.has(command.tick):
		_queued_commands[command.tick] = []
	_queued_commands[command.tick].append(command)
	command_queued.emit(command)

func make_local_command(type: RTSCommand.Type, entity_ids: Array[int], target_cell: Vector2i, payload: Dictionary = {}) -> RTSCommand:
	var command := RTSCommand.new()
	command.command_id = _next_command_id
	_next_command_id += 1
	command.player_id = local_player_id
	command.tick = state.tick + command_lead_ticks
	command.type = type
	command.entity_ids = entity_ids.duplicate()
	command.target_cell = target_cell
	command.payload = payload.duplicate(true)
	return command

func queue_local_command(type: RTSCommand.Type, entity_ids: Array[int], target_cell: Vector2i, payload: Dictionary = {}) -> RTSCommand:
	var command := make_local_command(type, entity_ids, target_cell, payload)
	queue_command(command)
	return command

func queue_spawn(player_id: int, target_cell: Vector2i, archetype: StringName = &"worker") -> RTSCommand:
	var command := RTSCommand.new()
	command.command_id = _next_command_id
	_next_command_id += 1
	command.player_id = player_id
	command.tick = state.tick + command_lead_ticks
	command.type = RTSCommand.Type.SPAWN_ENTITY
	command.target_cell = target_cell
	command.archetype = archetype
	queue_command(command)
	return command

func receive_remote_command(command_data: Dictionary) -> void:
	queue_command(RTSCommand.from_dict(command_data))

func receive_remote_hash(remote_tick: int, remote_hash: String) -> void:
	if remote_tick == state.tick and remote_hash != state.get_state_hash():
		desync_detected.emit(remote_tick, state.get_state_hash(), remote_hash)

func _step_once() -> void:
	var due: Array[RTSCommand] = []
	if _queued_commands.has(state.tick):
		for command in _queued_commands[state.tick]:
			due.append(command)
		_queued_commands.erase(state.tick)
	state.step(due)
	tick_advanced.emit(state.tick, state.get_state_hash())
