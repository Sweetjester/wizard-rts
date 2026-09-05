extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[KonOutpostCombatSmokeTest] starting")
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "kon-outpost-combat-smoke", "bad_kon_willow", "seeded_grid_frontier")
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

	var controller: Node = scene.get_node("KonVerticalSliceController")
	var wave_director: WaveDirector = scene.get_node("WaveDirector")
	var rts_world: RTSWorld = scene.get_node("RTSWorld")
	var outpost := _first_enemy_outpost(scene)
	var kon := _first_player_combat_unit(scene)
	var enemy := _first_enemy_unit(scene)
	if controller == null:
		_fail("Missing KonVerticalSliceController")
		return
	if wave_director == null or rts_world == null:
		_fail("Missing WaveDirector or RTSWorld")
		return
	if outpost == null:
		_fail("Expected vertical-slice enemy outpost")
		return
	if kon == null:
		_fail("Expected KON combat unit")
		return
	var spawned: Node = wave_director.call("_spawn_enemy", &"deom_blade", scene.get_node("MapGenerator").nearest_walkable_cell(scene.get_node("MapGenerator").world_to_cell(kon.global_position) + Vector2i(3, 0), 8), scene, kon.global_position)
	if spawned == null or not is_instance_valid(spawned):
		_fail("WaveDirector failed to spawn test enemy")
		return
	if int(spawned.get("owner_player_id")) != 2:
		_fail("WaveDirector spawned enemy without owner_player_id=2")
		return
	if not rts_world.all_units().has(spawned):
		_fail("WaveDirector spawned enemy was not registered in RTSWorld")
		return
	enemy = spawned as Node2D
	enemy.global_position = kon.global_position + Vector2(72, 0)
	var kon_hp_before := int(kon.get("health")) if _has_property(kon, "health") else 0
	if enemy.has_method("issue_attack_target"):
		enemy.issue_attack_target(kon)
	for _i in 90:
		await process_frame
		if _has_property(kon, "health") and int(kon.get("health")) < kon_hp_before:
			break
	if _has_property(kon, "health") and int(kon.get("health")) >= kon_hp_before:
		_fail("Enemy unit did not damage KON unit")
		return

	var enemy_hp_before := int(enemy.get("health"))
	kon.global_position = enemy.global_position + Vector2(-96, 0)
	kon.issue_attack_target(enemy)
	for _i in 90:
		await process_frame
		if not is_instance_valid(enemy):
			break
	if is_instance_valid(enemy) and int(enemy.get("health")) >= enemy_hp_before:
		_fail("KON unit did not damage enemy unit")
		return

	outpost.set("health", 18)
	outpost.set("max_health", 18)
	kon.global_position = outpost.global_position + Vector2(-160, 0)
	if kon.has_method("issue_attack_target"):
		kon.issue_attack_target(outpost)
	else:
		_fail("KON unit cannot receive attack target command")
		return

	var damaged := false
	for _i in 160:
		await process_frame
		if not is_instance_valid(outpost):
			print("[KonOutpostCombatSmokeTest] outpost destroyed by real combat")
			damaged = true
			break
		if int(outpost.get("health")) < 18:
			damaged = true
	if not damaged:
		_fail("Outpost did not take combat damage")
		return
	if is_instance_valid(outpost):
		_fail("Outpost took damage but did not die")
		return
	if int(controller.call("_outposts_remaining")) >= int(controller.call("_required_outposts_total")):
		_fail("Outpost destroyed signal did not update vertical slice objective count")
		return
	if bool(wave_director.get("boss_has_spawned")):
		_fail("Boss triggered without content clear and all real outpost destruction")
		return
	print("[KonOutpostCombatSmokeTest] combat wiring passed")
	quit(0)

func _first_enemy_outpost(scene: Node) -> KonStructure:
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and structure is KonStructure and int(structure.get("owner_player_id")) == 2 and str(structure.get("archetype")) == "enemy_outpost":
			return structure
	return null

func _first_player_combat_unit(scene: Node) -> Node2D:
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == 1 and unit.has_method("issue_attack_target"):
			return unit
	return null

func _first_enemy_unit(scene: Node) -> Node2D:
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == 2 and unit.has_method("issue_attack_move_order"):
			return unit
	return null

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
