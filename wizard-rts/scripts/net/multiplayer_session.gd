class_name MultiplayerSession
extends Node

signal hosting_started(port: int)
signal joined_server(address: String, port: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal session_error(message: String)

@export var default_port: int = 24580
@export var max_players: int = 8
@export var simulation_runner_path: NodePath

var simulation_runner: SimulationRunner

func _ready() -> void:
	if not simulation_runner_path.is_empty():
		simulation_runner = get_node_or_null(simulation_runner_path)
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_connected.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))

func host(port: int = -1) -> bool:
	if port < 0:
		port = default_port
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, max_players)
	if result != OK:
		session_error.emit("Failed to host on port %s: %s" % [port, result])
		return false
	multiplayer.multiplayer_peer = peer
	hosting_started.emit(port)
	return true

func join(address: String, port: int = -1) -> bool:
	if port < 0:
		port = default_port
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port)
	if result != OK:
		session_error.emit("Failed to join %s:%s: %s" % [address, port, result])
		return false
	multiplayer.multiplayer_peer = peer
	joined_server.emit(address, port)
	return true

func close() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func submit_command(command: RTSCommand) -> void:
	if simulation_runner == null:
		session_error.emit("No SimulationRunner configured")
		return
	if multiplayer.is_server():
		_broadcast_command(command.to_dict())
	else:
		_submit_command_to_server.rpc_id(1, command.to_dict())

@rpc("any_peer", "reliable")
func _submit_command_to_server(command_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_broadcast_command(command_data)

@rpc("authority", "reliable")
func _receive_command(command_data: Dictionary) -> void:
	if simulation_runner != null:
		simulation_runner.receive_remote_command(command_data)

func _broadcast_command(command_data: Dictionary) -> void:
	if simulation_runner != null:
		simulation_runner.receive_remote_command(command_data)
	_receive_command.rpc(command_data)
