extends SceneTree

# Kon learns to field the Steel Force by taking one apart.
#
# Steel Conscription is one rank per Steel Force unit, in BuildSystem's
# RECRUITMENT_ORDER. Each rank needs a felled specimen of the unit it unlocks --
# Kon is an observer, and the roguelike already keeps that record for the
# Vault's enemy cards, so the research reuses it rather than counting again.
#
# NOTHING BELOW NAMES THE UNITS. The first version of this test listed the three
# that existed when it was written, and when a fourth (the Mounted Knight) was
# added to the faction the test kept passing while Kon had no way to recruit it.
# So the ladder is read from RECRUITMENT_ORDER, and the first check asserts that
# order covers every unit the Steel Force actually fields -- which is the
# assertion that would have caught it.
#
# The assertions that carry the weight are the ones about things NOT being
# available, because the failure mode of a recruitment unlock is a live button
# with nothing behind it:
#
#   * un-conscripted recruits must be locked even though the Poorper is TIER 1,
#     so the ordinary tier ladder would call it unlocked
#   * a rank must be refused before its specimen is felled
#   * rank 1 must not quietly unlock rank 2's unit
#   * the HUD's lock, the training gate and the Vault card must give the SAME
#     answer -- three places asking the question, one rule answering it
#
# That last one is the whole reason can_recruit() exists as one function.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "steel-conscription-smoke", "bad_kon_willow", "build_sandbox")
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
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if build_system == null or economy == null:
		_fail("Expected BuildSystem and EconomyManager")
		return
	economy.call("add_resource", 1, &"bio", 999999)

	var order: Array = BuildSystem.RECRUITMENT_ORDER
	if not _check_ladder_covers_the_faction(scene, build_system, order):
		return

	# --- nothing is conscripted at the start ---------------------------------
	for archetype in order:
		if bool(build_system.call("can_recruit", archetype)):
			_fail("%s was recruitable before any research" % archetype)
			return
	# The Poorper is tier 1, so the ordinary tier ladder would wave it through.
	# This is the assertion that catches a recruit being gated by the wrong rule.
	if UnitCatalog.tier_of(&"poorper") != 1:
		_fail("This test assumes the Poorper is tier 1; it is tier %s" % UnitCatalog.tier_of(&"poorper"))
		return
	if bool(build_system.call("produce_unit", 1, &"poorper")):
		_fail("A Poorper was trainable with no Conscription, because it is tier 1")
		return

	# --- and it is on Kon's roster, so the card and button exist --------------
	if not UnitCatalog.is_unit_allowed_for_class(&"poorper", "bad_kon_willow"):
		_fail("The Poorper is not on Kon's roster, so no button or card would ever appear")
		return

	# --- research needs a Vault ----------------------------------------------
	var origin := Vector2i(40, 40)
	build_system.call("add_free_structure", 1, &"terrible_vault", origin, "")
	build_system.call("add_free_structure", 1, &"barracks", origin + Vector2i(10, 0), "")
	# The conscripts muster at their own hall now, so the ladder cannot be walked
	# without one standing.
	build_system.call("add_free_structure", 1, &"steel_musterhouse", origin + Vector2i(26, 0), "")
	for _i in 6:
		await process_frame
	_complete_structures(build_system)

	# --- one rank at a time, each paid for with a specimen ---------------------
	for rank in order.size():
		var subject: StringName = order[rank]
		var display := str(UnitCatalog.get_definition(subject).get("display_name", str(subject)))

		if bool(build_system.call("research_upgrade", 1, &"steel_conscription")):
			_fail("Conscription %d was accepted before a %s had been felled" % [rank + 1, display])
			return
		session.call("record_felled", subject, 2, 1)
		if not bool(build_system.call("research_upgrade", 1, &"steel_conscription")):
			_fail("Conscription %d was refused after a %s had been felled" % [rank + 1, display])
			return
		if not await _await_research(build_system):
			return
		if int(build_system.call("upgrade_rank", &"steel_conscription")) != rank + 1:
			_fail("Conscription did not reach rank %d" % [rank + 1])
			return

		# Exactly the units up to this rank, and no further. A rank that unlocked
		# two units, or that unlocked the wrong one, passes every check above.
		for i in order.size():
			var expected := i <= rank
			if bool(build_system.call("can_recruit", order[i])) != expected:
				_fail("At Conscription %d, %s recruitable=%s (expected %s)" % [
					rank + 1, order[i], build_system.call("can_recruit", order[i]), expected])
				return

		# And the newly unlocked unit actually arrives out of the lab. Checked
		# for every rank rather than once, because each has its own scene and
		# its own cost, and a missing scene is silent until something asks.
		if not await _check_trainable(scene, build_system, subject):
			return

	if int(build_system.call("upgrade_max_rank", &"steel_conscription")) != order.size():
		_fail("Conscription has %s ranks for %s units" % [
			build_system.call("upgrade_max_rank", &"steel_conscription"), order.size()])
		return

	# --- the three places that ask must agree ---------------------------------
	#
	# The Vault card, the HUD button and the training gate each ask "can Kon
	# build this". They read one function; if that ever stops being true, the
	# player is told two different things about the same unit.
	var hud: Node = scene.get_node_or_null("RTSHud")
	for archetype in order:
		var recruitable: bool = build_system.call("can_recruit", archetype)
		var button_locked: bool = hud.call("_tier_is_locked", archetype)
		if button_locked == recruitable:
			_fail("%s: can_recruit says %s and the HUD button lock says %s" % [
				archetype, recruitable, button_locked])
			return
		var entry: Dictionary = RosterLedger.entry_for(archetype, build_system, scene.get_node_or_null("RTSWorld"))
		if bool(entry["availability"]["available"]) != recruitable:
			_fail("%s: can_recruit says %s and its Vault card says %s" % [
				archetype, recruitable, entry["availability"]])
			return
		if not recruitable and str(entry["availability"]["reason"]).is_empty():
			_fail("%s is locked with no reason given, so the card cannot tell the player what to do" % archetype)
			return

	print("[SteelConscriptionSmokeTest] Kon conscripts the Steel Force one unit at a time, only after felling one to study, and the button, the card and the training gate all agree about it")
	scene.queue_free()
	quit(0)

# --- helpers ----------------------------------------------------------------

# Every unit the Steel Force fields must be somewhere on Kon's ladder, and every
# unit on the ladder must be reachable from Kon's side.
#
# This is the check that was missing. GPT added the Mounted Knight to the
# faction -- catalog entry, scene, wave composition -- and nothing said that
# Kon's conscription had not been told about it, because the test named its
# three units by hand.
func _check_ladder_covers_the_faction(scene: Node, build_system: Node, order: Array) -> bool:
	var director: Node = scene.get_node_or_null("WaveDirector")
	if director == null or not director.has_method("enemy_roster"):
		_fail("No WaveDirector to ask what the Steel Force fields")
		return false
	director.set("enemy_faction", "steel_force")
	for archetype in director.call("enemy_roster"):
		if not order.has(archetype):
			_fail("The Steel Force fields %s and Kon has no Conscription rank for it" % archetype)
			return false
	for archetype in order:
		if not UnitCatalog.is_unit_allowed_for_class(archetype, "bad_kon_willow"):
			_fail("%s is on the Conscription ladder but not on Kon's class roster, so no card or button would appear" % archetype)
			return false
		# SOME building must be able to make it. This named the Biospawner until
		# the Steel Force got its own Musterhouse; asking "which building" would
		# have to be rewritten again the next time production moves, while
		# "somewhere" is the thing that actually has to be true.
		if _producer_for(archetype) == &"":
			_fail("%s is on the Conscription ladder and no building can produce it" % archetype)
			return false
		var found := false
		for entry in _barracks_buttons(scene):
			if StringName(entry["archetype"]) == archetype:
				found = true
		if not found:
			_fail("%s is on the Conscription ladder with no training button, so it can never be clicked" % archetype)
			return false
	return true

# The button table, read off the LIVE HUD's script rather than through the
# RTSHud class name.
#
# A static `RTSHud.BARRACKS_UNIT_BUTTONS` forces rts_hud.gd to compile while this
# test script is being parsed -- before the autoloads exist -- and it refers to
# the KeybindManager autoload, so the whole test fails to load with an error
# pointing at an identifier it never mentions. Reading it off the instance also
# checks the script the running game is actually using.
func _barracks_buttons(scene: Node) -> Array:
	var hud: Node = scene.get_node_or_null("RTSHud")
	if hud == null or hud.get_script() == null:
		return []
	return hud.get_script().get_script_constant_map().get("BARRACKS_UNIT_BUTTONS", [])

# The building that produces an archetype, or "" if none does.
func _producer_for(archetype: StringName) -> StringName:
	for candidate in UnitCatalog.DEFINITIONS:
		var production: Array = UnitCatalog.DEFINITIONS[candidate].get("production", [])
		if production.has(archetype):
			return StringName(candidate)
	return &""

# Trains one and waits for it to walk out.
func _check_trainable(scene: Node, build_system: Node, archetype: StringName) -> bool:
	var before := _count_owned(scene, archetype)
	if not bool(build_system.call("produce_unit", 1, archetype)):
		_fail("A conscripted %s could not be trained at the Splicing Laboratory" % archetype)
		return false
	for _i in 2000:
		if _count_owned(scene, archetype) > before:
			return true
		await process_frame
	_fail("The %s was queued but never arrived, so the lab cannot actually build it" % archetype)
	return false

func _complete_structures(build_system: Node) -> void:
	var structures: Array = build_system.get("structures")
	for i in structures.size():
		structures[i]["complete"] = true
		structures[i]["build_progress"] = float(structures[i].get("build_time", 0.0))
		var node = structures[i].get("node", null)
		if node != null and is_instance_valid(node):
			node.set("complete", true)

func _count_owned(scene: Node, archetype: StringName) -> int:
	var count := 0
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("unit_archetype") == null:
			continue
		if StringName(unit.get("unit_archetype")) == archetype and int(unit.get("owner_player_id")) == 1:
			count += 1
	return count

func _await_research(build_system: Node) -> bool:
	for _i in 3000:
		if not bool(build_system.call("is_researching")):
			return true
		await process_frame
	_fail("A study never finished")
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
