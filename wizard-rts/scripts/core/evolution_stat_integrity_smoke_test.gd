extends SceneTree

# Guards three stat-pipeline bugs found 2026-08-31 while explaining the unit
# cards to Andrew. All three came from the same root shape: the catalog is
# design-time data that gets COPIED onto a node at spawn, and several later
# systems mutate the node without anything reconciling the two.
#
#   1. Evolution silently deleted researched upgrades. _evolve() calls
#      _apply_catalog_definition(), which resets max_health/attack_damage from
#      the catalog -- wiping anything Hardened Horrors had baked in. The
#      set_meta rank marker then stopped it ever being re-applied, so the
#      bonus was gone permanently.
#   2. Hardened Horrors was keyed on the archetype &"horror", so it also
#      stopped applying the moment a Horror became a Hunter -- an upgrade the
#      player paid for evaporating exactly when their unit improved.
#   3. The unit card showed raw catalog stats for evolved forms, but _evolve()
#      applies a growth multiplier on top of them. Every evolved unit on every
#      card was understated by ~24% HP and ~15% damage.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check_fielded_stats():
		return

	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "evolution-stat-smoke", "evangalion", "seeded_grid_frontier")
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

	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	if build_system == null or economy == null or map_generator == null:
		_fail("Expected BuildSystem, EconomyManager and MapGenerator")
		return
	economy.call("add_resource", 1, &"bio", 20000)

	# Hardened Horrors needs a completed Observer Vault.
	var tower: Node = _find_structure(scene, "wizard_tower")
	if tower == null:
		_fail("Expected the Observation Tower at run start")
		return
	var base_cell: Vector2i = map_generator.call("world_to_cell", (tower as Node2D).global_position)
	build_system.call("add_free_structure", 1, &"terrible_vault", base_cell + Vector2i(-6, 6), "")
	await process_frame
	if not bool(build_system.call("research_upgrade", 1, &"hardened_horrors")):
		_fail("Expected Hardened Horrors rank 1 to be researchable")
		return
	if not await _await_research(build_system):
		return

	# --- a researched Horror keeps its bonus through evolution -------------
	var horror := _spawn(scene, "res://scenes/units/horror.tscn", Vector2(3000, 3000))
	await process_frame
	build_system.call("_apply_upgrades_to_unit", horror)
	var catalog_horror_hp := UnitCatalog.max_hp(&"horror")
	var buffed_hp := int(horror.get("max_health"))
	if buffed_hp <= catalog_horror_hp:
		_fail("Hardened Horrors should raise a Horror's max HP above the catalog %s, got %s" % [catalog_horror_hp, buffed_hp])
		return
	var research_bonus := buffed_hp - catalog_horror_hp

	# Force the evolution the player would earn through combat.
	horror.call("force_evolution_for_testing") if horror.has_method("force_evolution_for_testing") else horror.call("_gain_evolution_xp", 100000.0)
	await process_frame
	if str(horror.get("unit_archetype")) != "hunter":
		_fail("Expected the Horror to evolve into a Hunter, got %s" % horror.get("unit_archetype"))
		return

	# The evolved unit must be at least its own fielded stats PLUS the research
	# bonus it was already carrying. Before the fix it dropped to exactly the
	# fielded value, silently losing what the player paid for.
	var fielded_hunter_hp := UnitCatalog.fielded_max_hp(&"hunter")
	var evolved_hp := int(horror.get("max_health"))
	if evolved_hp < fielded_hunter_hp + research_bonus:
		_fail("Evolution dropped the researched bonus: Hunter has %s HP, expected at least %s (fielded %s + research %s)" % [
			evolved_hp, fielded_hunter_hp + research_bonus, fielded_hunter_hp, research_bonus,
		])
		return

	# --- a Hunter trained after the research also gets it ------------------
	var hunter := _spawn(scene, "res://scenes/units/horror.tscn", Vector2(3200, 3000))
	hunter.set("unit_archetype", &"hunter")
	await process_frame
	var plain_hunter_hp := int(hunter.get("max_health"))
	build_system.call("_apply_upgrades_to_unit", hunter)
	if int(hunter.get("max_health")) <= plain_hunter_hp:
		_fail("Hardened Horrors should apply to the whole horror family, including the Hunter")
		return

	# --- applying twice must not double-count ------------------------------
	var once := int(hunter.get("max_health"))
	build_system.call("_apply_upgrades_to_unit", hunter)
	if int(hunter.get("max_health")) != once:
		_fail("Re-applying an already-applied upgrade rank must be idempotent (%s then %s)" % [once, hunter.get("max_health")])
		return

	print("[EvolutionStatIntegritySmokeTest] research survives evolution, applies across the family, stays idempotent, and card stats match what is fielded")
	quit(0)

func _check_fielded_stats() -> bool:
	# An evolved form's fielded stats must exceed its raw catalog entry, and a
	# base form's must equal it.
	for evolved in [&"hunter", &"gripper", &"champion", &"oaven_jumper", &"winged_spawner"]:
		if not UnitCatalog.is_evolved_form(evolved):
			_fail("%s should be tagged as an evolved form" % evolved)
			return false
		if UnitCatalog.fielded_max_hp(evolved) <= UnitCatalog.max_hp(evolved):
			_fail("%s fielded HP should exceed its catalog HP (evolution growth multiplier)" % evolved)
			return false
		if UnitCatalog.fielded_attack_damage(evolved) <= UnitCatalog.attack_damage(evolved):
			_fail("%s fielded damage should exceed its catalog damage" % evolved)
			return false
	for base in [&"horror", &"oaven_spear", &"spawner", &"stone_face_serpent", &"life_wizard"]:
		if UnitCatalog.fielded_max_hp(base) != UnitCatalog.max_hp(base):
			_fail("%s is not an evolved form, its fielded HP must equal its catalog HP" % base)
			return false
	# Families, which the upgrade gate now depends on.
	if UnitCatalog.family_of(&"hunter") != UnitCatalog.family_of(&"horror"):
		_fail("Horror and Hunter must share a unit family")
		return false
	# Salvage must be a real number, not the 0 the dead bio_value key produced.
	var salvage := UnitCatalog.salvage_value_for(&"oaven_spear")
	if salvage <= 0:
		_fail("Salvage value should be a real figure, got %s" % salvage)
		return false
	return true

func _find_structure(scene: Node, archetype: String) -> Node:
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == archetype:
			return structure
	return null

func _spawn(scene: Node, scene_path: String, position: Vector2) -> Node:
	var unit: Node = (load(scene_path) as PackedScene).instantiate()
	unit.set("owner_player_id", 1)
	scene.add_child(unit)
	unit.global_position = position
	return unit

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

# Research is no longer instant (2026-09-06): the Vault studies one upgrade at a
# time, over a duration derived from its cost, and Oavens stationed inside it
# make that faster. Ordering a study is still a single call that returns whether
# it was accepted -- this waits for the study to land before the rank is checked.
func _await_research(build_system: Node) -> bool:
	for _i in 2000:
		if not bool(build_system.call("is_researching")):
			return true
		await process_frame
	_fail("A study never finished")
	return false
