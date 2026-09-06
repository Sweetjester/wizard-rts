extends SceneTree

# The Observer Vault's codex reports the RUN, not the catalog.
#
# The assertion that carries the weight is the last one: the ledger's idea of
# what an upgrade does must match what BuildSystem actually does to a unit. The
# ledger cannot call BuildSystem._apply_upgrades_to_unit(), because that mutates
# a live node and a card describes a type that may have none on the field -- so
# the effect is written down twice, and two copies of a rule drift. This test is
# what stops them: it researches an upgrade, spawns a real unit, and insists the
# card's number and the creature's number are the same.
#
# Without that, the failure mode is the worst kind for a roguelike: a screen
# whose whole job is to tell you what your units became, confidently telling you
# something that is not true.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "roster-ledger-smoke", "bad_kon_willow", "build_sandbox")
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
	var rts_world: Node = scene.get_node_or_null("RTSWorld")
	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	if build_system == null or wave_director == null:
		_fail("Expected BuildSystem and WaveDirector")
		return

	# --- an untouched roster reports itself untouched -------------------------
	var before: Dictionary = RosterLedger.entry_for(&"horror", build_system, rts_world)
	if before.is_empty():
		_fail("The ledger had nothing to say about a Horror")
		return
	if int(before["base"]["max_health"]) != int(before["live"]["max_health"]):
		_fail("With no research bought, live stats must equal base stats")
		return
	for change in before["changes"]:
		if str(change.get("label", "")).begins_with("Hardened"):
			_fail("Reported a Hardened Horrors rank nobody has bought")
			return

	# --- research shows up, with its name on it -------------------------------
	build_system.set("researched_upgrade_ranks", {&"hardened_horrors": 2})
	var after: Dictionary = RosterLedger.entry_for(&"horror", build_system, rts_world)
	var gained: int = int(after["live"]["max_health"]) - int(after["base"]["max_health"])
	if gained <= 0:
		_fail("Hardened Horrors II moved no health on the card")
		return
	var named := false
	for change in after["changes"]:
		if str(change.get("label", "")) == "Hardened Horrors II":
			named = true
	if not named:
		_fail("The card showed a bigger number without saying what caused it, which is the one thing it exists to do")
		return

	# --- a unit the upgrade does not touch is left alone ----------------------
	var bystander: Dictionary = RosterLedger.entry_for(&"oaven_spear", build_system, rts_world)
	if int(bystander["live"]["max_health"]) != int(bystander["base"]["max_health"]):
		_fail("A Horror upgrade changed an Oaven's card")
		return

	# --- lineage, so the roguelike arc is visible -----------------------------
	if (after["lineage"]["to"] as Array).is_empty():
		_fail("A Horror should show what it evolves into")
		return

	# --- and the number on the card is the number on the creature -------------
	#
	# The whole point. If these disagree the codex is lying, and it is lying
	# about the thing the player is using it to decide.
	var spawned: Node2D = wave_director.call("_spawn_enemy", &"horror",
		Vector2i(40, 40), scene, Vector2.ZERO)
	if spawned == null or not is_instance_valid(spawned):
		_fail("Could not spawn a Horror to check the card against")
		return
	spawned.set("owner_player_id", 1)
	build_system.call("_apply_upgrades_to_unit", spawned)
	for _i in 5:
		await process_frame
	var on_the_card: int = int(after["live"]["max_health"])
	var on_the_creature: int = int(spawned.get("max_health"))
	if on_the_card != on_the_creature:
		_fail("The codex says %d max HP and the actual Horror has %d -- the ledger has drifted from BuildSystem" % [
			on_the_card, on_the_creature])
		return

	print("[RosterLedgerSmokeTest] the codex reports the run's own changes, names their causes, and agrees with the units on the field")
	scene.queue_free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
