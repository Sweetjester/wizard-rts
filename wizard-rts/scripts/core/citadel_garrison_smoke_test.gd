extends SceneTree

# The citadel's garrison, its capture, and the reward (master doc section 40).
#
# The point of the garrison is that an empty fortress is a free quarter of the
# map, which inverts the risk the march exists to create. So the assertions are
# about the defence being REAL: enough of it, on the citadel's own authored
# ground, holding rather than wandering off to the player's base.
#
# The last assertion is the one that would hurt most if it broke: re-summoning
# the tower must not trip the defeat check. Section 11 ends the run when the
# player has no tower, and the defeat check scans every frame -- so a reward
# that removed the old tower before building the new one would lose the player
# their run at the exact moment they earned it.

const PLAYER_ID := 1
const ENEMY_ID := 2

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "garrison-smoke", "bad_kon_willow", "citadel_march")
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
	for _i in 70:
		await process_frame

	var garrison: Node = scene.get_node_or_null("CitadelGarrison")
	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var slice: Node = scene.get_node_or_null("KonVerticalSliceController")
	if garrison == null or build_system == null:
		_fail("Expected CitadelGarrison and BuildSystem in main_map.tscn")
		return

	if not _check_defence_is_real(scene, garrison):
		return
	if not await _check_capture_and_reward(scene, garrison, build_system, slice):
		return
	print("[CitadelGarrisonSmokeTest] the citadel is held on its own ground, and capturing it moves the tower without losing the run")
	scene.queue_free()
	quit(0)

func _check_defence_is_real(scene: Node, garrison: Node) -> bool:
	var count: int = int(garrison.call("defenders_remaining"))
	if count < 12:
		_fail("Only %d defenders; an under-garrisoned citadel is a free quarter of the map" % count)
		return false
	if bool(garrison.call("is_captured")):
		_fail("The citadel reported captured before anyone fought for it")
		return false

	# Posted on the structure's OWN levels, not milling about on the ground
	# outside. Wall-walks are the expensive part of taking it.
	var levels := {}
	var holding := 0
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or int(unit.get("owner_player_id")) != ENEMY_ID:
			continue
		levels[int(unit.get("nav_level"))] = true
		if StringName(str(unit.get("command_mode"))) == &"hold":
			holding += 1
	if levels.size() < 2:
		_fail("The garrison stands on one level (%s); it should hold walls, gate and keep" % [levels.keys()])
		return false
	var elevated := false
	var definition := BlockStructureLibrary.load_default().get_definition(&"kons_arcane_citadel_01")
	var wall_level := -1
	for cell in definition.nav_cells:
		if definition.nav_at(cell).get("region_id", &"") == &"wall_walk_outer_ring_nav":
			wall_level = cell.y
			break
	for level in levels:
		if wall_level > 0 and int(level) >= wall_level:
			elevated = true
	if not elevated:
		_fail("Nobody is on the wall-walks; levels held were %s" % [levels.keys()])
		return false
	if holding <= 0:
		_fail("No defender is on hold -- the garrison will walk out and empty the fortress")
		return false
	return true

func _check_capture_and_reward(scene: Node, garrison: Node, build_system: Node, slice: Node) -> bool:
	# Re-summoning must be refused while the citadel is still held.
	if bool(build_system.call("resummon_tower_to_citadel", PLAYER_ID)):
		_fail("The tower was re-summoned into a citadel that is still garrisoned")
		return false

	var plinth: Vector2i = garrison.call("keep_plinth_cell")
	if plinth.x < 0:
		_fail("The garrison could not find the keep plinth to summon onto")
		return false

	# Clear the garrison, the way a player would.
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and int(unit.get("owner_player_id")) == ENEMY_ID:
			unit.queue_free()
	for _i in 6:
		await process_frame
	if not bool(garrison.call("is_captured")):
		_fail("Clearing every defender did not capture the citadel")
		return false

	if not bool(build_system.call("resummon_tower_to_citadel", PLAYER_ID)):
		_fail("Re-summoning was refused after the citadel was captured")
		return false

	# The tower moved, and there is exactly one.
	var towers: Array = []
	for structure in build_system.call("get_structures"):
		if structure.get("archetype", &"") == &"wizard_tower" \
				and int(structure.get("player_id", -1)) == PLAYER_ID:
			towers.append(structure)
	if towers.size() != 1:
		_fail("Expected exactly one player tower after re-summoning, found %d" % towers.size())
		return false
	if towers[0].get("cell", Vector2i.ZERO) != plinth:
		_fail("The tower ended at %s, not the keep plinth %s" % [towers[0].get("cell"), plinth])
		return false

	# And the run is still alive. This is the assertion that matters.
	for _i in 6:
		await process_frame
	if slice != null and bool(slice.get("_defeat")):
		_fail("Re-summoning the tower triggered defeat -- the old tower was removed before the new one existed")
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
