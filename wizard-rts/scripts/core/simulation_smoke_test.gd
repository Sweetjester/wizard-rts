extends SceneTree

func _init() -> void:
	var hash_a := _run_case()
	var hash_b := _run_case()
	if hash_a != hash_b:
		push_error("Simulation hashes diverged: %s != %s" % [hash_a, hash_b])
		quit(1)
		return
	print("[SimulationSmokeTest] deterministic hash: ", hash_a)
	quit(0)

func _run_case() -> String:
	var state := SimulationState.new(12345)

	var spawn := RTSCommand.new()
	spawn.command_id = 1
	spawn.player_id = 1
	spawn.tick = 0
	spawn.type = RTSCommand.Type.SPAWN_ENTITY
	spawn.target_cell = Vector2i(4, 4)
	var spawn_commands: Array = [spawn]
	state.step(spawn_commands)

	var ids := state.get_entities_for_player(1)
	var move := RTSCommand.new()
	move.command_id = 2
	move.player_id = 1
	move.tick = 1
	move.type = RTSCommand.Type.MOVE_UNITS
	move.entity_ids = ids
	move.target_cell = Vector2i(8, 6)

	for i in 8:
		var commands: Array = [move] if i == 0 else []
		state.step(commands)

	return state.get_state_hash()
