extends SceneTree

# Regression guard for the WC3-style "creep camp item drop" relic system added
# 2026-08-23: destroying a required outpost or clearing a content plot now
# automatically grants the wizard a permanent upgrade (no player choice,
# unlike the level-up system) via KonVerticalSliceController._grant_wizard_relic().

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "wizard-relic-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var controller: Node = scene.get_node("KonVerticalSliceController")
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize")
		return

	var wizard: Node = null
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1 and str(unit.get("unit_archetype")) == "life_wizard":
			wizard = unit
			break
	if wizard == null:
		_fail("Expected a life_wizard KON unit to spawn")
		return

	var total_ranks_before := _total_ranks(wizard)

	# Outpost destruction should grant a relic.
	var outposts: Array = controller.get("_outposts")
	if outposts.is_empty():
		_fail("Expected at least one required outpost")
		return
	var first_outpost_node = outposts[0].get("node", null)
	if first_outpost_node == null or not is_instance_valid(first_outpost_node):
		_fail("Outpost node missing before destruction")
		return
	first_outpost_node.call("take_damage", 999999, null)
	await process_frame

	if _total_ranks(wizard) <= total_ranks_before:
		_fail("Expected outpost destruction to grant a wizard relic")
		return
	total_ranks_before = _total_ranks(wizard)

	# Content plot clear should also grant a relic. Content plots now have a
	# differentiated, per-archetype relic chance (see content_plot_reward_variety_smoke_test.gd)
	# rather than a guaranteed drop, so target a shrine/landmark plot specifically --
	# those are the two archetypes with a 100% relic_chance -- to keep this
	# deterministic instead of flaky on whatever plot happens to be first.
	var content_plots: Array = controller.get("_content_plots")
	if content_plots.is_empty():
		_fail("Expected at least one content plot")
		return
	var guaranteed_plot: Dictionary = {}
	for plot in content_plots:
		var archetype := str((plot as Dictionary).get("content_archetype", "")).to_lower()
		if archetype.contains("shrine") or archetype.contains("landmark"):
			guaranteed_plot = plot
			break
	if guaranteed_plot.is_empty():
		_fail("Expected at least one shrine or landmark content plot for a deterministic relic check")
		return
	var anchor: Vector2i = guaranteed_plot.get("anchor", Vector2i.ZERO)
	var map_generator: Node = scene.get_node("MapGenerator")
	wizard.global_position = map_generator.call("cell_to_world", anchor)
	controller.call("_check_content_clear")

	if _total_ranks(wizard) <= total_ranks_before:
		_fail("Expected content plot clear to grant a wizard relic")
		return

	print("[WizardRelicSmokeTest] outpost and content-clear relics both granted, total ranks now ", _total_ranks(wizard))
	quit(0)

func _total_ranks(wizard: Node) -> int:
	var ranks: Dictionary = wizard.get("wizard_upgrade_ranks")
	var total := 0
	for value in ranks.values():
		total += int(value)
	return total

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
