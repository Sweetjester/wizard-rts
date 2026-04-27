extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "ai-test-smoke", "bad_kon_willow", "ai_testing_ground")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	if str(map.get("map_type_id")) != "ai_testing_ground":
		push_error("Expected ai_testing_ground, got %s" % map.get("map_type_id"))
		quit(1)
		return
	if int(map.get_base_plots().size()) != 2:
		push_error("AI testing ground should create two faction base plots")
		quit(1)
		return
	if map.is_walkable_cell(Vector2i(48, 24)):
		push_error("AI testing divider should block the closed lane")
		quit(1)
		return
	if not map.is_walkable_cell(Vector2i(48, 37)):
		push_error("AI testing divider should leave the central arena gap open")
		quit(1)
		return

	var wave_director: Node = scene.get_node("WaveDirector")
	if not wave_director.has_method("is_ai_testing_ground") or not bool(wave_director.call("is_ai_testing_ground")):
		push_error("WaveDirector did not enter AI testing mode")
		quit(1)
		return
	var result: Dictionary = wave_director.call("spawn_ai_test_wave")
	await process_frame
	await physics_frame
	if int(result.get("west", 0)) <= 0 or int(result.get("east", 0)) <= 0:
		push_error("AI testing wave did not spawn both factions")
		quit(1)
		return
	var owner_one := _count_units_for_owner(1)
	var owner_two := _count_units_for_owner(2)
	var owner_three := _count_units_for_owner(3)
	if owner_one != 0:
		push_error("AI testing ground should not spawn player-owned observer units")
		quit(1)
		return
	if owner_two < int(result.get("west", 0)) or owner_three < int(result.get("east", 0)):
		push_error("Spawned AI testing units were not registered in the scene")
		quit(1)
		return
	var fog := scene.get_node("FogOfWar")
	if fog.visible:
		push_error("AI testing ground should disable fog of war")
		quit(1)
		return
	var rts_world: Node = scene.get_node("RTSWorld")
	var telemetry: Dictionary = rts_world.call("get_observation_telemetry")
	if int(telemetry.get("units", 0)) < int(result.get("west", 0)) + int(result.get("east", 0)):
		push_error("Observation telemetry did not report the live arena units")
		quit(1)
		return
	print("[AITestingGroundSmokeTest] wave=", result.get("wave", 0), " west=", result.get("west", 0), " east=", result.get("east", 0))
	quit(0)

func _count_units_for_owner(owner: int) -> int:
	var count := 0
	for unit in get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == owner:
			count += 1
	return count
