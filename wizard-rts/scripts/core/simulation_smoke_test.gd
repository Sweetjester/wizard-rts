extends SceneTree

func _init() -> void:
	var hash_a := _run_case()
	var hash_b := _run_case()
	if hash_a != hash_b:
		push_error("Simulation hashes diverged: %s != %s" % [hash_a, hash_b])
		quit(1)
		return
	if not _run_catalog_and_command_case():
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

func _run_catalog_and_command_case() -> bool:
	var state := SimulationState.new(9876)
	var wizard_id := state.spawn_entity(1, &"life_wizard", Vector2i(3, 3))
	var enemy_id := state.spawn_entity(2, &"vampire_mushroom_thrall", Vector2i(5, 3))
	if int(state.get_entity(wizard_id).get("max_hp", 0)) <= int(state.get_entity(enemy_id).get("max_hp", 0)):
		push_error("Expected catalog stats to give wizard more HP than thrall")
		return false
	var attack := RTSCommand.new()
	attack.command_id = 99
	attack.player_id = 1
	attack.tick = state.tick
	attack.type = RTSCommand.Type.ATTACK_TARGET
	attack.entity_ids = [wizard_id]
	attack.target_entity_id = enemy_id
	state.step([attack])
	if String(state.get_entity(wizard_id).get("state", "")) != "attacking":
		push_error("Expected attack command to put entity into attacking state")
		return false
	var build := RTSCommand.new()
	build.command_id = 100
	build.player_id = 1
	build.tick = state.tick
	build.type = RTSCommand.Type.BUILD_STRUCTURE
	build.target_cell = Vector2i(8, 8)
	build.payload = {"structure": "bio_absorber"}
	state.step([build])
	if state.entities.size() != 3:
		push_error("Expected build command to create a structure entity")
		return false
	return true
