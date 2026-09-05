extends SceneTree

# Guard for the Intelligence and Aggro Range stats added 2026-08-31
# (Master Design Doc section 38, Andrew's mechanic).
#
#   Intelligence 1 (Feral)   -- set behaviour only, player orders refused.
#   Intelligence 2 (Leashed) -- takes move orders, but only while no enemy is
#                               inside aggro range; reverts to its own
#                               behaviour once something closes.
#   Intelligence 3 (Bound)   -- fully micromanageable.
#
# Aggro range is how far an enemy can be before the unit engages on its own. It
# used to be an implicit max(attack_range * 1.5, 256px) buried in
# combat_system.gd; it is now an authored per-unit stat that both the simulation
# and the unit card read.
#
# The gate is applied on the PLAYER order path only. The AI/wave path issues
# orders directly on the unit, and this test pins that distinction, because
# breaking it would silently disable enemy waves.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check_catalog():
		return

	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "intelligence-smoke", "bad_kon_willow", "seeded_grid_frontier")
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
	for _i in 4:
		await process_frame

	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	var dispatcher: Node = scene.get_node_or_null("CommandDispatcher")
	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if dispatcher == null or build_system == null or economy == null or map_generator == null:
		_fail("Expected CommandDispatcher, BuildSystem, EconomyManager and MapGenerator")
		return
	# Spawn positions must be real walkable cells. RTSUnit._snap_to_walkable_terrain()
	# teleports anything placed off-map or on a blocker, which silently pulls a
	# test pair apart and makes an aggro assertion fail for the wrong reason.
	var pair_a := _cell_world(map_generator, Vector2i(20, 20))
	var pair_b := pair_a + Vector2(40, 0)
	var lone := _cell_world(map_generator, Vector2i(70, 20))
	var lone_intruder := lone + Vector2(100, 0)
	var far := _cell_world(map_generator, Vector2i(20, 70))

	# --- a Bound unit obeys with an enemy right next to it -----------------
	var bound := _spawn(scene, "res://scenes/units/oaven_spear.tscn", pair_a, 1)
	var enemy := _spawn(scene, "res://scenes/units/oaven_spear.tscn", pair_b, 2)
	# Aggro awareness comes from the combat tick, which is budgeted -- give it
	# frames to acquire rather than asserting on the spawn frame.
	for _i in 12:
		await process_frame
	if int(bound.get("intelligence")) != 3:
		_fail("The Oaven should be Intelligence 3, got %s" % bound.get("intelligence"))
		return
	if not bool(bound.call("has_enemy_in_aggro_range")):
		_fail("An enemy 40px away should be inside the Oaven's aggro range")
		return
	if not bool(bound.call("accepts_player_order", &"move")):
		_fail("A Bound unit must obey a move order even while engaged")
		return

	# --- a Leashed unit obeys only while nothing is in range ---------------
	var leashed := _spawn(scene, "res://scenes/units/spawner.tscn", lone, 1)
	for _i in 6:
		await process_frame
	if int(leashed.get("intelligence")) != 2:
		_fail("The Spawner should be Intelligence 2, got %s" % leashed.get("intelligence"))
		return
	if bool(leashed.call("has_enemy_in_aggro_range")):
		_fail("Nothing should be near the isolated Leashed unit yet")
		return
	if not bool(leashed.call("accepts_player_order", &"move")):
		_fail("A Leashed unit must obey a move order when no enemy is in range")
		return
	var intruder := _spawn(scene, "res://scenes/units/oaven_spear.tscn", lone_intruder, 2)
	for _i in 12:
		await process_frame
	if not bool(leashed.call("has_enemy_in_aggro_range")):
		_fail("The intruder should be inside the Spawner's aggro range")
		return
	if bool(leashed.call("accepts_player_order", &"move")):
		_fail("A Leashed unit must refuse a move order while an enemy is in aggro range")
		return
	# Stop is the deliberate exception -- refusing it would leave the player
	# unable to call anything off at all.
	if not bool(leashed.call("accepts_player_order", &"stop")):
		_fail("Stop must always be accepted, even by a Leashed unit under threat")
		return

	# --- the dispatcher filters and reports -------------------------------
	var report := [0, 0, ""]
	dispatcher.order_partially_refused.connect(func(obeyed: int, refused: int, reason: String) -> void:
		report[0] = obeyed
		report[1] = refused
		report[2] = reason
	)
	var before: Vector2 = leashed.global_position
	dispatcher.call("submit_move", [bound, leashed] as Array[Node], lone + Vector2(0, 600), [Vector2.ZERO, Vector2.ZERO] as Array[Vector2], [] as Array[Vector2])
	if int(report[1]) != 1:
		_fail("Expected exactly one unit to refuse the move order, got %s" % report[1])
		return
	if int(report[0]) != 1:
		_fail("Expected the Bound unit to still obey, got %s obeying" % report[0])
		return
	if str(report[2]).is_empty():
		_fail("A refusal should carry a human-readable reason for the HUD")
		return
	if bool(leashed.get("moving")):
		_fail("The refusing unit must not have taken the move order")
		return

	# --- Feral refuses everything -----------------------------------------
	var feral := _spawn(scene, "res://scenes/units/the_forbidden.tscn", far, 1)
	await process_frame
	if int(feral.get("intelligence")) != 1:
		_fail("The Forbidden should be Intelligence 1, got %s" % feral.get("intelligence"))
		return
	for kind in [&"move", &"attack_move", &"patrol", &"hold", &"attack_target"]:
		if bool(feral.call("accepts_player_order", kind)):
			_fail("A Feral unit must refuse every player order, accepted %s" % kind)
			return

	# --- the AI path is NOT gated -----------------------------------------
	# Wave units are Leashed or Feral too; if the gate leaked onto the direct
	# call path, enemy waves would stop moving entirely.
	var wave_unit := _spawn(scene, "res://scenes/units/spawner.tscn", lone_intruder + Vector2(80, 0), 2)
	await process_frame
	wave_unit.call("issue_attack_move_order", lone + Vector2(0, 600))
	if str(wave_unit.get("command_mode")) != "attack_move":
		_fail("Orders issued directly on a unit must bypass the intelligence gate (AI path), command_mode is %s" % wave_unit.get("command_mode"))
		return

	# --- Observer Command research raises intelligence --------------------
	economy.call("add_resource", 1, &"bio", 20000)
	var tower: Node = _find_structure(scene, "wizard_tower")
	var base_cell: Vector2i = scene.get_node("MapGenerator").call("world_to_cell", (tower as Node2D).global_position)
	build_system.call("add_free_structure", 1, &"terrible_vault", base_cell + Vector2i(-6, 6), "")
	await process_frame
	if not bool(build_system.call("research_upgrade", 1, &"observer_command")):
		_fail("Observer Command should be researchable at the Observer Vault")
		return
	build_system.call("_apply_upgrades_to_unit", leashed)
	if int(leashed.get("intelligence")) != 3:
		_fail("Observer Command rank 1 should raise the Leashed Spawner to 3, got %s" % leashed.get("intelligence"))
		return
	# Now it should obey even with the intruder still standing there.
	if not bool(leashed.call("accepts_player_order", &"move")):
		_fail("After Observer Command the Spawner should obey while engaged")
		return
	# And it must not exceed the cap, however many ranks are bought.
	build_system.call("research_upgrade", 1, &"observer_command")
	build_system.call("_apply_upgrades_to_unit", leashed)
	if int(leashed.get("intelligence")) > 3:
		_fail("Intelligence must cap at 3, got %s" % leashed.get("intelligence"))
		return
	# A Feral unit is raised too, but only by the rank bought -- 1 + 2 = 3.
	build_system.call("_apply_upgrades_to_unit", feral)
	if int(feral.get("intelligence")) != 3:
		_fail("Two ranks of Observer Command should bring a Feral unit to 3, got %s" % feral.get("intelligence"))
		return

	print("[IntelligenceStatSmokeTest] Feral/Leashed/Bound gating, aggro range, partial-order reporting, AI bypass and Observer Command all behave")
	quit(0)

func _check_catalog() -> bool:
	var expected := {
		&"oaven_spear": 3,
		&"stone_face_serpent": 2,
		&"spawner": 2,
		&"spawner_drone": 1,
		&"the_forbidden": 1,
		&"life_wizard": 3,
	}
	for archetype in expected.keys():
		if UnitCatalog.intelligence_of(archetype) != int(expected[archetype]):
			_fail("%s should be Intelligence %s, catalog says %s" % [archetype, expected[archetype], UnitCatalog.intelligence_of(archetype)])
			return false
		if UnitCatalog.aggro_range_cells(archetype) <= 0:
			_fail("%s has no aggro range" % archetype)
			return false
		if UnitCatalog.intelligence_label(UnitCatalog.intelligence_of(archetype)).is_empty():
			_fail("%s has no intelligence label for its card" % archetype)
			return false
	# The hero is always fully controllable -- a design doc rule.
	if UnitCatalog.intelligence_of(&"life_wizard") != UnitCatalog.INTELLIGENCE_BOUND:
		_fail("The wizard must always be fully controllable")
		return false
	# Unauthored archetypes fall back rather than reading 0.
	if UnitCatalog.intelligence_of(&"deom_scout") != UnitCatalog.DEFAULT_INTELLIGENCE:
		_fail("An unauthored unit should fall back to the default intelligence")
		return false
	if UnitCatalog.aggro_range_cells(&"deom_scout") < 4:
		_fail("An unauthored unit should fall back to a sane aggro range")
		return false
	return true

func _cell_world(map_generator: Node, cell: Vector2i) -> Vector2:
	return map_generator.call("cell_to_world", map_generator.call("nearest_walkable_cell", cell, 24))

func _find_structure(scene: Node, archetype: String) -> Node:
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == archetype:
			return structure
	return null

func _spawn(scene: Node, scene_path: String, position: Vector2, owner_id: int) -> Node:
	var unit: Node = (load(scene_path) as PackedScene).instantiate()
	unit.set("owner_player_id", owner_id)
	scene.add_child(unit)
	unit.global_position = position
	return unit

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
