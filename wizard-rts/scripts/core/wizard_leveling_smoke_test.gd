extends SceneTree

# Regression guard for the WC3-style wizard hero-leveling system added 2026-08-23
# (wizard.gd: wizard_level/wizard_xp/pending_level_up/wizard_upgrade_ranks,
# and the generic damage-dealt XP hook in rts_unit.gd's take_damage()).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_life_wizard_spell_choice():
		return
	if not await _check_fire_wizard_stat_choice():
		return
	print("[WizardLevelingSmokeTest] spell-class and stat-class leveling both pass")
	quit(0)

func _boot_scene(character_id: String) -> Node:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "wizard-leveling-smoke", character_id, "seeded_grid_frontier")
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
	return scene

func _find_wizard(scene: Node, archetype: String) -> Node:
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == 1 and str(unit.get("unit_archetype")) == archetype:
			return unit
	return null

func _check_life_wizard_spell_choice() -> bool:
	var scene: Node = await _boot_scene("bad_kon_willow")
	var wizard := _find_wizard(scene, "life_wizard")
	if wizard == null:
		_fail("Expected a life_wizard to spawn")
		return false

	if int(wizard.get("wizard_level")) != 1 or bool(wizard.get("pending_level_up")):
		_fail("Wizard should start at level 1 with no pending choice")
		return false

	# Exercise the real combat hook (rts_unit.gd take_damage crediting the source),
	# not just the direct call, so a regression in that wiring would be caught too.
	var wave_director: Node = scene.get_node("WaveDirector")
	var xp_before := float(wizard.get("wizard_xp"))
	var dummy: Node = wave_director.call("_spawn_enemy", &"deom_blade", Vector2i(0, 0), scene, wizard.global_position)
	if dummy == null or not is_instance_valid(dummy):
		_fail("Expected a spawnable Deom enemy unit for the combat-hook check")
		return false
	dummy.call("take_damage", 50, wizard)
	if float(wizard.get("wizard_xp")) <= xp_before:
		_fail("Expected wizard_xp to increase from the take_damage combat hook")
		dummy.queue_free()
		return false
	dummy.queue_free()

	wizard.call("_gain_wizard_xp", 100000.0)
	if not bool(wizard.get("pending_level_up")) or int(wizard.get("wizard_level")) < 2:
		_fail("Expected a large XP grant to trigger a level-up")
		return false

	var options: Array = wizard.call("wizard_upgrade_options")
	if options != ["bio_mend", "seal_away", "observer_aura"]:
		_fail("Expected the life_wizard's upgrade pool to be its named spells, got %s" % str(options))
		return false

	if not bool(wizard.call("choose_wizard_upgrade", "bio_mend")):
		_fail("choose_wizard_upgrade should accept an offered option")
		return false
	if bool(wizard.get("pending_level_up")):
		_fail("pending_level_up should clear after a choice is made")
		return false
	if int(wizard.call("wizard_upgrade_rank", "bio_mend")) != 1:
		_fail("Expected bio_mend rank to be 1 after choosing it once")
		return false
	if bool(wizard.call("choose_wizard_upgrade", "seal_away")):
		_fail("choose_wizard_upgrade should reject a choice when no level-up is pending")
		return false

	await _teardown(scene)
	return true

func _check_fire_wizard_stat_choice() -> bool:
	var scene: Node = await _boot_scene("hellfire_baby")
	var wizard := _find_wizard(scene, "fire_wizard")
	if wizard == null:
		_fail("Expected a fire_wizard to spawn")
		return false

	var damage_before := int(wizard.get("attack_damage"))
	wizard.call("_gain_wizard_xp", 100000.0)
	if not bool(wizard.get("pending_level_up")):
		_fail("Expected a large XP grant to trigger a level-up (fire wizard)")
		return false

	var options: Array = wizard.call("wizard_upgrade_options")
	if options != ["power", "vitality", "swiftness"]:
		_fail("Expected the fire_wizard's upgrade pool to be generic stats (no named spells exist for it), got %s" % str(options))
		return false

	if not bool(wizard.call("choose_wizard_upgrade", "power")):
		_fail("choose_wizard_upgrade should accept 'power' for a stat-only class")
		return false
	if int(wizard.get("attack_damage")) <= damage_before:
		_fail("Expected attack_damage to increase after choosing 'power'")
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
