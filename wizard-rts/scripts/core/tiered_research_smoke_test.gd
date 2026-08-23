extends SceneTree

# Regression guard for the WC3-style tiered research upgrades added 2026-08-23
# (build_system.gd: researched_upgrade_ranks/UPGRADE_MAX_RANK, replacing the old
# one-shot researched_upgrades boolean dict). hardened_horrors/thorned_vines/
# launcher_bile are now 3-rank upgrades with escalating cost and effect;
# accelerated_evolution stays a single-rank upgrade.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "tiered-research-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var build_system: Node = scene.get_node("BuildSystem")
	var economy_manager: Node = scene.get_node("EconomyManager")
	var map_generator: Node = scene.get_node("MapGenerator")
	if build_system == null or economy_manager == null or map_generator == null:
		_fail("Expected BuildSystem, EconomyManager, and MapGenerator")
		return

	var tower: Node = null
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == "wizard_tower":
			tower = structure
			break
	if tower == null:
		_fail("Expected a wizard tower to exist")
		return

	var vault_cell: Vector2i = map_generator.call("world_to_cell", (tower as Node2D).global_position) + Vector2i(6, 6)
	build_system.call("add_free_structure", 1, &"terrible_vault", vault_cell, "")
	economy_manager.call("add_resource", 1, &"bio", 50000)
	await process_frame

	var costs: Array = []
	for expected_rank in [1, 2, 3]:
		var bio_before := int(economy_manager.call("get_resources", 1).get(&"bio", 0))
		if not bool(build_system.call("research_upgrade", 1, &"hardened_horrors")):
			_fail("Expected hardened_horrors research to succeed for rank %s" % expected_rank)
			return
		if int(build_system.call("upgrade_rank", &"hardened_horrors")) != expected_rank:
			_fail("Expected hardened_horrors rank to be %s after researching" % expected_rank)
			return
		var bio_after := int(economy_manager.call("get_resources", 1).get(&"bio", 0))
		costs.append(bio_before - bio_after)

	if not (costs[1] > costs[0] and costs[2] > costs[1]):
		_fail("Expected each rank of hardened_horrors to cost more than the last, got %s" % str(costs))
		return
	if bool(build_system.call("research_upgrade", 1, &"hardened_horrors")):
		_fail("Expected hardened_horrors research to be rejected past max rank")
		return

	# accelerated_evolution should still be a single-rank (WC3-style one-shot) upgrade.
	if int(build_system.call("upgrade_max_rank", &"accelerated_evolution")) != 1:
		_fail("Expected accelerated_evolution to remain a single-rank upgrade")
		return
	if not bool(build_system.call("research_upgrade", 1, &"accelerated_evolution")):
		_fail("Expected accelerated_evolution research to succeed once")
		return
	if bool(build_system.call("research_upgrade", 1, &"accelerated_evolution")):
		_fail("Expected accelerated_evolution research to be rejected on a second attempt")
		return

	# hardened_horrors (now at rank 3) should apply its full bonus exactly once, not per rank purchased.
	var horror_scene: PackedScene = load("res://scenes/units/horror.tscn")
	var horror: Node = horror_scene.instantiate()
	horror.set("owner_player_id", 1)
	scene.add_child(horror)
	horror.global_position = (tower as Node2D).global_position
	await process_frame
	var base_hp := int(horror.get("max_health"))
	build_system.call("_apply_upgrades_to_unit", horror)
	build_system.call("_apply_upgrades_to_unit", horror)
	var expected_hp := base_hp + 20 * 3
	if int(horror.get("max_health")) != expected_hp:
		_fail("Expected rank-3 hardened_horrors to add exactly +60 max_hp once (not per call), got %s from base %s" % [horror.get("max_health"), base_hp])
		return

	print("[TieredResearchSmokeTest] hardened_horrors ranks=1,2,3 costs=", costs, " horror_max_hp=", horror.get("max_health"), " (base ", base_hp, ")")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
