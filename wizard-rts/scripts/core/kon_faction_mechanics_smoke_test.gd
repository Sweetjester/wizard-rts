extends SceneTree

# Regression guard for the KoN faction pass of 2026-08-31, which brought the
# live game in line with the KoN roster doc. Each block below maps to a line in
# that doc that previously had no implementation behind it:
#
#   * tier gating       -- "Kon gets access to [Oaven] straight away", tier 2
#                          "through evolution on his buildings or finding
#                          upgrades on the map", tier 3 "through great effort"
#   * Oaven weapon swap -- "can switch between either a spear or a blowpipe"
#   * Bio Absorber heal -- "will naturally slowly heal units and buildings in a
#                          large radius"
#   * Bio Launcher      -- "can be set to attack ground for manual firing ...
#                          and can be set to fire automatically"
#   * The Forbidden     -- "will not obey Kon and will turn it's wrath on all"
#   * unit cards        -- portraits and tier metadata the Biospawner shows

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check_catalog_shape():
		return

	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "kon-faction-smoke", "bad_kon_willow", "seeded_grid_frontier")
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

	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	if build_system == null or economy == null or map_generator == null:
		_fail("Expected BuildSystem, EconomyManager and MapGenerator")
		return
	economy.call("add_resource", 1, &"bio", 20000)

	# --- tier gating -------------------------------------------------------
	if int(build_system.call("unlocked_tier", 1)) != 1:
		_fail("A run should start with only tier 1 unlocked, got %s" % build_system.call("unlocked_tier", 1))
		return
	var tower: Node = _find_structure(scene, "wizard_tower")
	if tower == null:
		_fail("Expected the Observation Tower to exist at run start")
		return
	var base_cell: Vector2i = map_generator.call("world_to_cell", (tower as Node2D).global_position)
	build_system.call("add_free_structure", 1, &"barracks", base_cell + Vector2i(6, 6), "")
	build_system.call("add_free_structure", 1, &"terrible_vault", base_cell + Vector2i(-6, 6), "")
	await process_frame

	if not bool(build_system.call("produce_unit", 1, &"oaven_spear")):
		_fail("Tier 1 Oaven should be trainable from the first minute")
		return
	if bool(build_system.call("produce_unit", 1, &"stone_face_serpent")):
		_fail("Tier 2 Serpent should be locked before Tier 2 Hybrids research")
		return
	if bool(build_system.call("produce_unit", 1, &"spawner")):
		_fail("Tier 3 Spawner should be locked before Tier 3 Hybrids research")
		return
	# Tier 3 research must not be reachable before tier 2.
	if bool(build_system.call("research_upgrade", 1, &"tier_three_hybrids")):
		_fail("Tier 3 Hybrids should require Tier 2 Hybrids first")
		return
	if not bool(build_system.call("research_upgrade", 1, &"tier_two_hybrids")):
		_fail("Tier 2 Hybrids research should succeed with a Vault and enough Bio")
		return
	if int(build_system.call("unlocked_tier", 1)) != 2:
		_fail("Researching Tier 2 Hybrids should unlock tier 2")
		return
	if not bool(build_system.call("produce_unit", 1, &"stone_face_serpent")):
		_fail("Serpent should be trainable once tier 2 is unlocked")
		return
	if bool(build_system.call("produce_unit", 1, &"spawner")):
		_fail("Spawner should still be locked at tier 2")
		return
	if not bool(build_system.call("research_upgrade", 1, &"tier_three_hybrids")):
		_fail("Tier 3 Hybrids should be researchable once tier 2 is done")
		return
	if not bool(build_system.call("produce_unit", 1, &"spawner")):
		_fail("Spawner should be trainable once tier 3 is unlocked")
		return
	# The Forbidden is tier 4 and must never be trainable at a Biospawner.
	if bool(build_system.call("produce_unit", 1, &"the_forbidden")):
		_fail("The Forbidden must not be trainable -- it is unleashed, not produced")
		return

	# Map discovery is the doc's other route to a tier, and must be idempotent.
	var fresh_grant: bool = bool(build_system.call("grant_tier_unlock", 1, 2))
	if fresh_grant:
		_fail("grant_tier_unlock should report false for a tier already unlocked")
		return

	# --- Oaven weapon swap -------------------------------------------------
	var oaven := _spawn(scene, "res://scenes/units/oaven_spear.tscn", Vector2(3000, 3000))
	await process_frame
	if not bool(oaven.call("has_weapon_modes")):
		_fail("The Oaven should have weapon modes")
		return
	if str(oaven.call("current_weapon_mode")) != "spear":
		_fail("The Oaven should default to its spear, got %s" % oaven.call("current_weapon_mode"))
		return
	var spear_range := float(oaven.get("attack_range"))
	oaven.call("toggle_weapon_mode")
	if str(oaven.call("current_weapon_mode")) != "blowpipe":
		_fail("Toggling should move the Oaven to its blowpipe")
		return
	if float(oaven.get("attack_range")) <= spear_range:
		_fail("The blowpipe should outrange the spear (%s vs %s)" % [oaven.get("attack_range"), spear_range])
		return
	if str(oaven.get("attack_type")) != "ranged_single":
		_fail("The blowpipe should be a ranged attack, got %s" % oaven.get("attack_type"))
		return
	if not bool(oaven.call("is_swapping_weapon")):
		_fail("A weapon swap should cost a moment of uptime")
		return
	oaven.call("toggle_weapon_mode")
	if str(oaven.call("current_weapon_mode")) != "spear":
		_fail("Toggling again should return to the spear")
		return

	# --- Bio Absorber heal aura -------------------------------------------
	var absorber_cell: Vector2i = map_generator.call("nearest_walkable_cell", base_cell + Vector2i(3, -5), 10)
	build_system.call("add_free_structure", 1, &"bio_absorber", absorber_cell, "")
	await process_frame
	var absorber := _find_structure(scene, "bio_absorber")
	if absorber == null:
		_fail("Expected the test Bio Absorber to exist")
		return
	var patient := _spawn(scene, "res://scenes/units/oaven_spear.tscn", (absorber as Node2D).global_position + Vector2(64, 0))
	await process_frame
	patient.set("health", 10)
	# Drive a full aura tick directly rather than waiting a real second.
	build_system.call("_update_absorber_heal_auras", 2.0)
	if int(patient.get("health")) <= 10:
		_fail("A Bio Absorber should passively mend nearby friendly units, health stayed at %s" % patient.get("health"))
		return
	# Out of radius, nothing should happen.
	var distant := _spawn(scene, "res://scenes/units/oaven_spear.tscn", (absorber as Node2D).global_position + Vector2(4000, 0))
	await process_frame
	distant.set("health", 10)
	build_system.call("_update_absorber_heal_auras", 2.0)
	if int(distant.get("health")) != 10:
		_fail("A unit outside the heal radius should not be mended")
		return

	# --- Bio Launcher auto-fire toggle and manual attack-ground ------------
	var launcher_cell: Vector2i = map_generator.call("nearest_walkable_cell", base_cell + Vector2i(-4, -4), 10)
	build_system.call("add_free_structure", 1, &"bio_launcher", launcher_cell, "")
	await process_frame
	var launcher := _find_structure(scene, "bio_launcher")
	if launcher == null:
		_fail("Expected the test Bio Launcher to exist")
		return
	if not bool(build_system.call("launcher_auto_fire", launcher)):
		_fail("Bio Launchers should default to firing automatically")
		return
	if not bool(build_system.call("set_launcher_auto_fire", launcher, false)):
		_fail("Auto-fire should be switchable off")
		return
	if bool(build_system.call("launcher_auto_fire", launcher)):
		_fail("Auto-fire should read back as off after being disabled")
		return
	var in_range: Vector2 = (launcher as Node2D).global_position + Vector2(96, 0)
	if not bool(build_system.call("order_launcher_attack_ground", launcher, in_range)):
		_fail("A manual attack-ground order inside range should be accepted")
		return
	var out_of_range: Vector2 = (launcher as Node2D).global_position + Vector2(6000, 0)
	if bool(build_system.call("order_launcher_attack_ground", launcher, out_of_range)):
		_fail("A manual attack-ground order beyond range should be rejected")
		return

	# --- The Forbidden -----------------------------------------------------
	var forbidden = build_system.call("unleash_forbidden", 1)
	if forbidden == null or not is_instance_valid(forbidden):
		_fail("Unleashing the Forbidden should spawn a unit")
		return
	if str(forbidden.get("unit_archetype")) != "the_forbidden":
		_fail("The unleashed unit should be the_forbidden, got %s" % forbidden.get("unit_archetype"))
		return
	# The whole point: it belongs to nobody, so the player who paid for it is
	# just another enemy. Every hostility check in the codebase is an owner-id
	# comparison, so owner 0 is hostile to player 1 and to the Deom Legion alike.
	if int(forbidden.get("owner_player_id")) == 1:
		_fail("The Forbidden must not be owned by the player who unleashed it")
		return
	if int(forbidden.get("max_health")) < 1000:
		_fail("The Forbidden should carry its own catalog stats, max_health was %s" % forbidden.get("max_health"))
		return
	if str(forbidden.get("command_mode")) != "attack_move":
		_fail("The Forbidden should march on its own without orders")
		return

	# --- unit cards actually build --------------------------------------
	# Asserting the catalog has portrait paths is not enough: the card builder
	# has to survive being run for every archetype, including the ones with no
	# portrait, no tier and no weapon modes.
	var hud: Node = scene.get_node_or_null("RTSHud")
	if hud == null:
		_fail("Expected the RTSHud")
		return
	var cards_with_portraits := 0
	for archetype in [&"life_wizard", &"oaven_spear", &"oaven_jumper", &"stone_face_serpent", &"spawner", &"winged_spawner", &"the_forbidden", &"barracks", &"bio_absorber", &"deom_scout"]:
		var card = hud.call("_build_stat_card", archetype)
		if card == null:
			_fail("The unit card builder returned nothing for %s" % archetype)
			return
		if _card_has_portrait(card):
			cards_with_portraits += 1
		card.queue_free()
	if cards_with_portraits < 4:
		_fail("Expected at least the 4 concept-art portraits to render on their cards, got %s" % cards_with_portraits)
		return

	print("[KonFactionMechanicsSmokeTest] tier gates, weapon swap, heal aura, launcher control, the Forbidden and unit cards all behave")
	quit(0)

func _check_catalog_shape() -> bool:
	# Bad Kon Willow's roster must be the faction doc's, not the old placeholder.
	var roster: Array = UnitCatalog.CLASS_UNIT_ROSTERS.get("bad_kon_willow", [])
	for required in [&"oaven_spear", &"stone_face_serpent", &"spawner", &"the_forbidden"]:
		if not roster.has(required):
			_fail("Bad Kon Willow's roster is missing %s" % required)
			return false
	if roster.has(&"apex"):
		_fail("apex is not in the KoN faction doc and should be off Kon's roster")
		return false
	# Tiers, so the unit card and the gate agree on what sits where.
	var expected_tiers := {
		&"oaven_spear": 1,
		&"oaven_jumper": 1,
		&"stone_face_serpent": 2,
		&"spawner": 3,
		&"winged_spawner": 3,
		&"the_forbidden": 4,
	}
	for archetype in expected_tiers.keys():
		if UnitCatalog.tier_of(archetype) != int(expected_tiers[archetype]):
			_fail("%s should be tier %s, catalog says %s" % [archetype, expected_tiers[archetype], UnitCatalog.tier_of(archetype)])
			return false
	# Unit-card portraits must actually resolve, or the Biospawner card is blank.
	for archetype in [&"life_wizard", &"oaven_spear", &"stone_face_serpent", &"spawner"]:
		var path := UnitCatalog.card_portrait_path(archetype)
		if path.is_empty():
			_fail("%s has no unit-card portrait" % archetype)
			return false
		if not ResourceLoader.exists(path):
			_fail("%s's unit-card portrait is missing on disk: %s" % [archetype, path])
			return false
	# The doc's duo theme: observer for Kon and his tower/vault, evolution for
	# the hybrids, and the Biospawner as the single crossover building.
	if UnitCatalog.kon_theme(&"life_wizard") != &"observer":
		_fail("Kon himself should carry the observer theme")
		return false
	if UnitCatalog.kon_theme(&"oaven_spear") != &"evolution":
		_fail("The Oaven should carry the evolution theme")
		return false
	if UnitCatalog.kon_theme(&"barracks") != &"crossover":
		_fail("The Biospawner is the one building where both themes cross over")
		return false
	if str(UnitCatalog.get_definition(&"barracks").get("display_name", "")) != "Biospawner":
		_fail("The production building should be named Biospawner")
		return false
	if str(UnitCatalog.get_definition(&"terrible_vault").get("display_name", "")) != "Observer Vault":
		_fail("The research building should be named Observer Vault")
		return false
	if str(UnitCatalog.get_definition(&"wizard_tower").get("display_name", "")) != "Observation Tower":
		_fail("The HQ should be named Observation Tower")
		return false
	return true

func _card_has_portrait(node: Node) -> bool:
	if node is TextureRect and (node as TextureRect).texture != null:
		return true
	for child in node.get_children():
		if _card_has_portrait(child):
			return true
	return false

func _find_structure(scene: Node, archetype: String) -> Node:
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == archetype:
			return structure
	return null

func _spawn(scene: Node, scene_path: String, position: Vector2) -> Node:
	var packed: PackedScene = load(scene_path)
	var unit: Node = packed.instantiate()
	unit.set("owner_player_id", 1)
	scene.add_child(unit)
	unit.global_position = position
	return unit

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
