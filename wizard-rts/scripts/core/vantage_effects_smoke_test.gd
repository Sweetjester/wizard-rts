extends SceneTree

# Height inside a structure is worth something, and stops being worth something
# when you come down.
#
# The reverting half is the one that matters. A buff that applies is easy; a buff
# that is applied by mutating a unit's stats is very hard to take away again,
# because every other system that touches those stats would have to know it was
# there. So the range bonus is read from state at query time rather than written
# into attack_range, and the weapon swap remembers what it replaced. This test
# walks an Oaven up and back down and insists the numbers return exactly.
#
# It also guards the trigger itself: ground level inside a building is NOT a
# vantage. A gate tunnel is indoors and is not a firing step, and if that ever
# stops being true then every unit standing in a doorway quietly gets a rifle.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "vantage-smoke", "bad_kon_willow", "build_sandbox")
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
	var wave_director: Node = scene.get_node_or_null("WaveDirector")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if build_system == null or bridge == null or wave_director == null:
		_fail("Expected BuildSystem, BlockNavBridge and WaveDirector")
		return
	if scene.get_node_or_null("VantageEffects") == null:
		_fail("main_map.tscn has no VantageEffects node, so nothing applies the buff")
		return
	if economy != null:
		economy.call("add_resource", 1, &"bio", 999999)

	var origin := Vector2i(40, 40)
	if not bool(build_system.call("try_place_structure", 1, &"wizard_tower", origin)):
		_fail("Could not raise an Observation Tower to stand on")
		return
	await process_frame

	var oaven: Node2D = wave_director.call("_spawn_enemy", &"oaven_spear", origin + Vector2i(-3, 2), scene, Vector2.ZERO)
	if oaven == null or not is_instance_valid(oaven):
		_fail("Could not spawn an Oaven")
		return
	oaven.set("owner_player_id", 1)
	oaven.call("set_weapon_mode", &"blowpipe")
	for _i in 25:
		await process_frame

	var ground_mode: StringName = StringName(oaven.get("weapon_mode"))
	var ground_range: float = float(oaven.get("attack_range"))
	var ground_damage: int = int(oaven.get("attack_damage"))
	if int(oaven.get("vantage_height")) != 0:
		_fail("An Oaven standing on open ground reported a vantage")
		return

	var definition = bridge.get("library").get_definition(&"kons_observation_wizard_tower_01")
	var highest := Vector3i.ZERO
	var ground_floor := Vector3i(-1, -1, -1)
	for cell in definition.nav_cells:
		if cell.y > highest.y:
			highest = cell
		if cell.y == 0 and ground_floor.x < 0:
			ground_floor = cell
	if highest.y < 2:
		_fail("The tower has no floor high enough to be a vantage")
		return

	# --- up ------------------------------------------------------------------
	oaven.global_position = map.call("cell_to_world", origin + Vector2i(highest.x, highest.z))
	oaven.set("nav_level", highest.y)
	for _i in 30:
		await process_frame
	if int(oaven.get("vantage_height")) <= 0:
		_fail("An Oaven on the tower's highest floor got no vantage")
		return
	var high_mode: StringName = StringName(oaven.get("weapon_mode"))
	if high_mode == ground_mode:
		_fail("The Oaven kept its skirmishing blowpipe on a firing step; expected the heavy one")
		return
	if int(oaven.get("attack_damage")) <= ground_damage:
		_fail("The heavy blowpipe should hit harder: %s -> %s" % [ground_damage, oaven.get("attack_damage")])
		return
	if float(oaven.get("attack_range")) <= ground_range:
		_fail("The heavy blowpipe should reach further: %s -> %s" % [ground_range, oaven.get("attack_range")])
		return
	# The trade, without which this is a straight upgrade rather than a choice.
	if float(oaven.get("attack_cooldown")) <= 1.05:
		_fail("The heavy blowpipe should fire more slowly, got %s" % oaven.get("attack_cooldown"))
		return

	# --- ground floor inside the building is NOT a vantage --------------------
	if ground_floor.x >= 0:
		oaven.global_position = map.call("cell_to_world", origin + Vector2i(ground_floor.x, ground_floor.z))
		oaven.set("nav_level", 0)
		for _i in 30:
			await process_frame
		if int(oaven.get("vantage_height")) != 0:
			_fail("Standing on the tower's ground floor counted as a vantage; a doorway is not a firing step")
			return

	# --- and back down -------------------------------------------------------
	oaven.global_position = map.call("cell_to_world", origin + Vector2i(-3, 2))
	oaven.set("nav_level", 0)
	for _i in 30:
		await process_frame
	if StringName(oaven.get("weapon_mode")) != ground_mode:
		_fail("Coming down did not restore the original weapon: %s" % oaven.get("weapon_mode"))
		return
	if not is_equal_approx(float(oaven.get("attack_range")), ground_range):
		_fail("Range did not return to %s, got %s" % [ground_range, oaven.get("attack_range")])
		return
	if int(oaven.get("attack_damage")) != ground_damage:
		_fail("Damage did not return to %s, got %s" % [ground_damage, oaven.get("attack_damage")])
		return

	print("[VantageEffectsSmokeTest] height inside a structure arms the heavy blowpipe, and coming down puts it away again")
	scene.queue_free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
