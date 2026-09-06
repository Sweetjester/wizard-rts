extends SceneTree

# Research takes time, and Oavens stationed in the Vault shorten it.
#
# NOTE ON A DELIBERATE BEHAVIOUR CHANGE (2026-09-06): research used to complete
# the instant it was bought. research_upgrade() charged the Bio and wrote the
# rank on the same line. That made "Oavens in the Vault research faster"
# impossible to implement -- there was no duration to shorten -- so the Vault now
# studies one upgrade at a time over a duration derived from its cost.
#
# What that changed, and what this pins:
#
#   * the Bio is taken when the study is ORDERED, so a study cannot be started
#     and abandoned for free, and cannot be queued unaffordably
#   * the rank appears only when the study COMPLETES
#   * one study at a time, or the crew bonus would be meaningless (you would
#     start everything and wait)
#   * losing the Vault mid-study loses the study
#
# The last one is the one worth arguing about and is easy to change: it is a
# single branch in _update_research.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "vault-research-smoke", "bad_kon_willow", "build_sandbox")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 400:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame

	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var garrison: Node = scene.get_node_or_null("StructureGarrisonEffects")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	if build_system == null or garrison == null:
		_fail("Expected BuildSystem and StructureGarrisonEffects")
		return
	economy.call("add_resource", 1, &"bio", 999999)

	# --- research needs a Vault ----------------------------------------------
	if bool(build_system.call("research_upgrade", 1, &"observer_sight")):
		_fail("Research was accepted with no Vault built")
		return

	var origin := Vector2i(40, 40)
	if not bool(build_system.call("try_place_structure", 1, &"terrible_vault", origin)):
		_fail("Could not raise an Observer Vault")
		return
	for _i in 6:
		await process_frame
	_complete_structures(build_system)
	var vault := _structure_at(build_system, &"terrible_vault")
	var instance: StringName = StringName(vault.get("block_instance", &""))
	if instance == &"":
		_fail("The Vault has no block instance")
		return

	# --- it is a study, not a purchase ---------------------------------------
	var bio_before := int(economy.call("get_resources", 1).get(&"bio", 0))
	if not bool(build_system.call("research_upgrade", 1, &"observer_sight")):
		_fail("Research was rejected at a completed Vault with plenty of Bio")
		return
	if int(economy.call("get_resources", 1).get(&"bio", 0)) >= bio_before:
		_fail("Ordering a study cost nothing; the Bio must be taken up front")
		return
	if int(build_system.call("upgrade_rank", &"observer_sight")) != 0:
		_fail("The rank was granted immediately -- research is supposed to take time now")
		return
	if not bool(build_system.call("is_researching")):
		_fail("Nothing is being studied after research was accepted")
		return
	if float(build_system.call("research_seconds_remaining")) <= 0.0:
		_fail("The study has no duration")
		return

	# --- one at a time --------------------------------------------------------
	if bool(build_system.call("research_upgrade", 1, &"observer_oversight")):
		_fail("A second study was accepted while the first was still running")
		return

	# --- a crew makes it faster ----------------------------------------------
	#
	# Measured as progress over a fixed number of frames, twice, the same way
	# the production test does it -- reading the multiplier back would not prove
	# it reaches the research clock.
	var uncrewed := await _research_progress_over(build_system, 40)
	if uncrewed <= 0.0:
		_fail("An un-crewed Vault made no research progress at all")
		return

	var inside := _interior_cell(bridge, instance, origin)
	if inside.is_empty():
		_fail("The Observer Vault has no interior floor cell to stand on")
		return
	var oaven: Node2D = wave_director.call("_spawn_enemy", &"oaven_spear", origin + Vector2i(-4, -4), scene, Vector2.ZERO)
	oaven.set("owner_player_id", 1)
	# _spawn_enemy DEFERS an attack-move order, so stopping the unit on the same
	# frame it was created is undone a frame later. Let the order land first,
	# then station it -- the same ordering trap the citadel garrison hit.
	for _i in 10:
		await process_frame
	oaven.global_position = map.call("cell_to_world", inside["cell"])
	oaven.set("nav_level", int(inside["level"]))
	oaven.call("issue_stop_order")
	for _i in 20:
		await process_frame
	if int(garrison.call("workers_in", instance)) != 1:
		_fail("An Oaven stationed in the Vault was not counted, got %s" % garrison.call("workers_in", instance))
		return
	var crewed := await _research_progress_over(build_system, 40)
	if not (crewed > uncrewed * 1.05):
		_fail("A crewed Vault studied at %s and an empty one at %s -- the crew is not reaching the research clock" % [
			crewed, uncrewed])
		return

	# --- and it finishes, granting the rank -----------------------------------
	for _i in 900:
		if not bool(build_system.call("is_researching")):
			break
		await process_frame
	if bool(build_system.call("is_researching")):
		_fail("The study never finished")
		return
	if int(build_system.call("upgrade_rank", &"observer_sight")) != 1:
		_fail("The study completed without granting the rank")
		return

	# --- losing the Vault loses the study -------------------------------------
	if not bool(build_system.call("research_upgrade", 1, &"observer_oversight")):
		_fail("Could not start a second study after the first completed")
		return
	var node = vault.get("node", null)
	if node != null and is_instance_valid(node):
		node.call("take_damage", 999999, null)
	for _i in 20:
		await process_frame
	if bool(build_system.call("is_researching")):
		_fail("A study kept running after the Vault it was being done in was destroyed")
		return

	print("[VaultResearchSmokeTest] research takes time, costs its Bio up front, runs one study at a time, goes faster with Oavens stationed in the Vault, and dies with the building")
	scene.queue_free()
	quit(0)

# --- helpers ----------------------------------------------------------------

func _structure_at(build_system: Node, archetype: StringName) -> Dictionary:
	for structure in build_system.get("structures"):
		if StringName(structure.get("archetype", &"")) == archetype:
			return structure
	return {}

func _complete_structures(build_system: Node) -> void:
	var structures: Array = build_system.get("structures")
	for i in structures.size():
		structures[i]["complete"] = true
		structures[i]["build_progress"] = float(structures[i].get("build_time", 0.0))
		var node = structures[i].get("node", null)
		if node != null and is_instance_valid(node):
			node.set("complete", true)

func _interior_cell(bridge: Node, instance: StringName, origin: Vector2i) -> Dictionary:
	for radius in range(0, 14):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var cell := origin + Vector2i(dx, dz)
				for level in range(0, 8):
					if StringName(bridge.call("structure_instance_at", cell, level)) == instance:
						return {"cell": cell, "level": level}
	return {}

func _research_progress_over(build_system: Node, frames: int) -> float:
	var before := float(build_system.call("research_progress_ratio"))
	for _i in frames:
		await process_frame
	return float(build_system.call("research_progress_ratio")) - before

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
