extends SceneTree

# Regression guard for the per-class unit roster gate added 2026-08-23
# (scripts/core/unit_catalog.gd CLASS_UNIT_ROSTERS, enforced in build_system.gd
# produce_unit()/produce_unit_from_structure()). Before this, every wizard class
# trained from the same shared KON roster with zero differentiation.
#
# Updated 2026-08-31: Bad Kon Willow's roster is now the KoN faction doc's own
# (Oaven / Stone-Faced Serpent / Spawner / The Forbidden), so this test asserts
# on oaven_spear rather than apex. apex was never in the faction doc -- the old
# assertion encoded a placeholder roster, not intended design.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_class_roster("bad_kon_willow", &"oaven_spear", &"terrible_thing"):
		return
	if not await _check_class_roster("hellfire_baby", &"terrible_thing", &"apex"):
		return
	if not await _check_class_roster("evangalion", &"horror", &"spawner"):
		return
	print("[ClassUnitRosterSmokeTest] all three wizard classes correctly gated")
	quit(0)

func _check_class_roster(character_id: String, allowed_archetype: StringName, disallowed_archetype: StringName) -> bool:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "class-roster-smoke", character_id, "seeded_grid_frontier")
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

	var build_system: Node = scene.get_node("BuildSystem")
	var economy_manager: Node = scene.get_node("EconomyManager")
	var map_generator: Node = scene.get_node("MapGenerator")
	if build_system == null or economy_manager == null or map_generator == null:
		_fail("Expected BuildSystem, EconomyManager, and MapGenerator")
		return false

	var tower: Node = null
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == "wizard_tower":
			tower = structure
			break
	if tower == null:
		_fail("Expected a wizard tower to exist (%s)" % character_id)
		return false

	var barracks_cell: Vector2i = map_generator.call("world_to_cell", (tower as Node2D).global_position) + Vector2i(6, 6)
	build_system.call("add_free_structure", 1, &"barracks", barracks_cell, "")
	economy_manager.call("add_resource", 1, &"bio", 5000)
	await process_frame

	var rejected_reason_box := [""]
	var queued_box := [false]
	build_system.build_rejected.connect(func(reason: String) -> void:
		rejected_reason_box[0] = reason
	)
	build_system.unit_training_queued.connect(func(_player_id: int, _producer: Node, _archetype: StringName, _queue_count: int) -> void:
		queued_box[0] = true
	)

	var allowed_ok: bool = bool(build_system.call("produce_unit", 1, allowed_archetype))
	if not allowed_ok or not bool(queued_box[0]):
		_fail("%s: expected in-roster unit %s to be trainable" % [character_id, allowed_archetype])
		await _teardown(scene)
		return false

	queued_box[0] = false
	var disallowed_ok: bool = bool(build_system.call("produce_unit", 1, disallowed_archetype))
	if disallowed_ok or bool(queued_box[0]):
		_fail("%s: expected out-of-roster unit %s to be rejected" % [character_id, disallowed_archetype])
		await _teardown(scene)
		return false
	if str(rejected_reason_box[0]).is_empty():
		_fail("%s: expected build_rejected to fire for out-of-roster unit %s" % [character_id, disallowed_archetype])
		await _teardown(scene)
		return false

	await _teardown(scene)
	return true

func _teardown(scene: Node) -> void:
	scene.queue_free()
	await process_frame
	await process_frame

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
