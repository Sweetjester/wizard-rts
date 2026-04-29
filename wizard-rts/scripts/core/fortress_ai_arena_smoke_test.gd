extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "fortress-ai-smoke", "bad_kon_willow", "fortress_ai_arena")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 4:
		await process_frame
		await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	if str(map.get("map_type_id")) != "fortress_ai_arena":
		push_error("Expected fortress_ai_arena, got %s" % map.get("map_type_id"))
		quit(1)
		return
	if int(map.get_base_plots().size()) != 2:
		push_error("Fortress arena should create two base plots")
		quit(1)
		return
	if not map.is_walkable_cell(Vector2i(29, 38)) or not map.is_walkable_cell(Vector2i(66, 38)):
		push_error("Fortress arena gates should remain walkable")
		quit(1)
		return

	var structures := get_nodes_in_group("structures")
	var owner_two_structures := _count_structures_for_owner(2)
	var owner_three_structures := _count_structures_for_owner(3)
	if owner_two_structures < 5 or owner_three_structures < 5:
		push_error("Fortress arena did not spawn mirrored fort structures")
		quit(1)
		return
	if _count_structures_for_archetype(2, &"wizard_tower") != 1 or _count_structures_for_archetype(3, &"wizard_tower") != 1:
		push_error("Each fortress should have one wizard tower objective")
		quit(1)
		return

	var rts_world: Node = scene.get_node("RTSWorld")
	rts_world.call("rebuild_spatial")
	var attackables: Array = rts_world.call("query_attackables", map.cell_to_world(Vector2i(29, 38)), 900.0, -1, 80)
	if attackables.size() <= 0:
		push_error("RTSWorld did not expose fortress structures as attackable targets")
		quit(1)
		return

	var wave_director: Node = scene.get_node("WaveDirector")
	if not wave_director.has_method("is_fortress_ai_arena") or not bool(wave_director.call("is_fortress_ai_arena")):
		push_error("WaveDirector did not enter fortress AI mode")
		quit(1)
		return
	var result: Dictionary = wave_director.call("spawn_ai_test_wave")
	for _i in 12:
		await process_frame
		await physics_frame
	if int(result.get("west", 0)) <= 0 or int(result.get("east", 0)) <= 0:
		push_error("Fortress arena wave did not queue both factions")
		quit(1)
		return
	if _count_units_for_owner(2) <= owner_two_structures or _count_units_for_owner(3) <= owner_three_structures:
		push_error("Fortress arena wave units were not spawned for both factions")
		quit(1)
		return
	var fog := scene.get_node("FogOfWar")
	if fog.visible:
		push_error("Fortress AI arena should disable fog of war")
		quit(1)
		return
	print("[FortressAIArenaSmokeTest] structures=", structures.size(), " wave=", result.get("wave", 0), " west=", result.get("west", 0), " east=", result.get("east", 0))
	quit(0)

func _count_units_for_owner(owner: int) -> int:
	var count := 0
	for unit in get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == owner:
			count += 1
	return count

func _count_structures_for_owner(owner: int) -> int:
	var count := 0
	for structure in get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == owner:
			count += 1
	return count

func _count_structures_for_archetype(owner: int, archetype: StringName) -> int:
	var count := 0
	for structure in get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == owner and StringName(structure.get("archetype")) == archetype:
			count += 1
	return count
