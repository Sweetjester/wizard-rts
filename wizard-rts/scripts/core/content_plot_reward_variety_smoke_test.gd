extends SceneTree

# Regression guard for differentiated content-plot rewards added 2026-08-23
# (KonVerticalSliceController._content_reward_for_plot()). Previously every
# content plot paid the exact same flat Bio/Essence/relic reward regardless
# of its narrative-flavor archetype tag (ruin/shrine/cache/crossroad/camp/
# ambush/landmark/encounter) -- this reads that tag to vary the reward.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "content-reward-smoke", "bad_kon_willow", "seeded_grid_frontier")
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
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize")
		return

	# Unit-test the reward table directly: distinct archetypes must not all
	# collapse to the same reward, and the values must be internally sane.
	var landmark: Dictionary = controller.call("_content_reward_for_plot", "blank_large_landmark")
	var shrine: Dictionary = controller.call("_content_reward_for_plot", "blank_small_shrine")
	var cache: Dictionary = controller.call("_content_reward_for_plot", "blank_small_cache")
	var crossroad: Dictionary = controller.call("_content_reward_for_plot", "blank_medium_crossroad")
	var unknown: Dictionary = controller.call("_content_reward_for_plot", "some_future_archetype")

	if int(landmark["bio"]) <= int(cache["bio"]):
		_fail("Expected the landmark plot to pay more Bio than a cache plot")
		return
	if float(shrine["relic_chance"]) != 1.0:
		_fail("Expected a shrine to guarantee a relic")
		return
	if float(cache["relic_chance"]) != 0.0:
		_fail("Expected a cache (pure resource stash) to never grant a relic")
		return
	if float(crossroad["relic_chance"]) != 0.0 or int(crossroad["bio"]) >= int(landmark["bio"]):
		_fail("Expected a crossroad to be a minor waypoint reward, not landmark-tier")
		return
	if int(unknown["bio"]) != int(controller.get("content_reward_bio")):
		_fail("Expected an unrecognized archetype to fall back to the flat default reward")
		return

	# End-to-end: clearing a real content plot actually grants its differentiated reward.
	var content_plots: Array = controller.get("_content_plots")
	if content_plots.is_empty():
		_fail("Expected at least one content plot on the map")
		return
	var target_plot: Dictionary = content_plots[0] as Dictionary
	var expected: Dictionary = controller.call("_content_reward_for_plot", str(target_plot.get("content_archetype", "")))

	var wizard: Node = null
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1 and str(unit.get("unit_archetype")) == "life_wizard":
			wizard = unit
			break
	if wizard == null:
		_fail("Expected a life_wizard KON unit to spawn")
		return

	var map_generator: Node = scene.get_node("MapGenerator")
	var economy_manager: Node = scene.get_node("EconomyManager")
	var anchor: Vector2i = target_plot.get("anchor", Vector2i.ZERO)
	wizard.global_position = map_generator.call("cell_to_world", anchor)
	var bio_before := int(economy_manager.call("get_resources", 1).get(&"bio", 0))
	var essence_before := int(economy_manager.call("get_resources", 1).get(&"essence", 0))

	controller.call("_check_content_clear")

	var bio_after := int(economy_manager.call("get_resources", 1).get(&"bio", 0))
	var essence_after := int(economy_manager.call("get_resources", 1).get(&"essence", 0))
	if bio_after - bio_before != int(expected["bio"]):
		_fail("Expected clearing archetype %s to grant %s Bio, got %s" % [target_plot.get("content_archetype", ""), expected["bio"], bio_after - bio_before])
		return
	if essence_after - essence_before != int(expected["essence"]):
		_fail("Expected clearing archetype %s to grant %s Essence, got %s" % [target_plot.get("content_archetype", ""), expected["essence"], essence_after - essence_before])
		return

	print("[ContentPlotRewardVarietySmokeTest] landmark=", landmark, " shrine=", shrine, " cache=", cache,
		" | cleared archetype=", target_plot.get("content_archetype", ""), " bio_gained=", bio_after - bio_before, " essence_gained=", essence_after - essence_before)
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
