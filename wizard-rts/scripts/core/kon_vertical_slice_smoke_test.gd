extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "kon-vertical-slice-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	# Map generation is spread across frames now, so the scene is not playable
	# the instant it is added. Waits for the generator to say it is finished
	# rather than for a fixed frame count -- a count that happened to be long
	# enough on a 96x96 map is not a guarantee, it is a coincidence.
	for _gen_wait in 400:
		var _gen := scene.get_node_or_null("MapGenerator")
		if _gen == null or bool(_gen.get("generation_complete")):
			break
		await process_frame
	await process_frame
	await process_frame
	await process_frame

	var map: Node = scene.get_node("MapGenerator")
	if str(map.get("map_type_id")) != "seeded_grid_frontier":
		_fail("Expected seeded_grid_frontier map")
		return
	if map.get_base_plots().size() < 4:
		_fail("Expected defensible/risky base plot choices")
		return
	if map.get_plots().size() < 9:
		_fail("Expected content plot coverage")
		return

	var controller: Node = scene.get_node("KonVerticalSliceController")
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize")
		return
	if int(controller.call("_required_outposts_total")) < 1:
		_fail("Expected at least one required outpost")
		return

	var wave: WaveDirector = scene.get_node("WaveDirector")
	if wave == null or not wave.enabled:
		_fail("Expected active WaveDirector")
		return
	if wave.boss_arrival_seconds < 9999.0:
		_fail("Expected boss timer to be gated by slice objectives")
		return

	var build_system: BuildSystem = scene.get_node("BuildSystem")
	var economy: EconomyManager = scene.get_node("EconomyManager")
	if build_system == null or economy == null:
		_fail("Expected build and economy systems")
		return
	if build_system.get_structures().is_empty():
		_fail("Expected MapBootstrap to place starting HQ")
		return

	var simulation_runner: SimulationRunner = scene.get_node("SimulationRunner")
	if simulation_runner == null:
		_fail("Expected SimulationRunner")
		return
	if simulation_runner.running:
		_fail("SimulationRunner should stay stopped in single-player")
		return
	if simulation_runner.get_steps_processed() != 0:
		_fail("SimulationRunner processed ticks in single-player")
		return

	var player_units := 0
	var first_player_unit: Node = null
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1:
			player_units += 1
			if first_player_unit == null:
				first_player_unit = unit
	if player_units < 1:
		_fail("Expected KON player unit to spawn")
		return
	if first_player_unit == null or not (first_player_unit is Node2D):
		_fail("Expected a commandable player unit")
		return

	var command_dispatcher: CommandDispatcher = scene.get_node("CommandDispatcher")
	if command_dispatcher == null:
		_fail("Expected CommandDispatcher")
		return
	var command_target := (first_player_unit as Node2D).global_position + Vector2(96.0, 0.0)
	command_dispatcher.submit_move([first_player_unit], command_target, [Vector2.ZERO], [])
	command_dispatcher.submit_attack_move([first_player_unit], command_target + Vector2(64.0, 0.0))
	await process_frame
	if simulation_runner.running:
		_fail("SimulationRunner started after single-player commands")
		return
	if simulation_runner.get_steps_processed() != 0:
		_fail("SimulationRunner processed ticks after single-player commands")
		return
	if simulation_runner.get_queued_command_count() != 0:
		_fail("SimulationRunner retained queued commands while stopped")
		return

	print("[KonVerticalSliceSmokeTest] map=", map.get_seed_value(),
		" base_plots=", map.get_base_plots().size(),
		" plots=", map.get_plots().size(),
		" outposts=", controller.call("_required_outposts_total"),
		" wave_enabled=", wave.enabled)
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
