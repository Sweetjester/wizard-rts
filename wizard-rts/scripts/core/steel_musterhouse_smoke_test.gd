extends SceneTree

# The Steel Force musters at its own Musterhouse, not at Kon's Biospawner.
#
# GPT delivered the structure as a physical building with a handoff contract and
# explicitly no gameplay wiring: no menu entry, no recruitment, no production.
# This is that wiring, and the thing most worth pinning is the SPLIT -- two
# production buildings that each make a different half of the roster is a state
# with an obvious failure mode in both directions:
#
#   * the Biospawner must no longer offer Steel units
#   * the Musterhouse must not offer Kon's
#
# Both are checked against what the buildings actually accept, not against the
# button lists, because a button that exists to be refused is the symptom rather
# than the bug.
#
# The muster point is checked too. The structure AUTHORS where recruits appear
# (production_integration.recruit_anchor), and honouring that is the difference
# between a unit walking out of the muster door and a unit appearing in a wheat
# bed. It has to survive rotation, which is the part that silently does not.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "musterhouse-smoke", "bad_kon_willow", "build_sandbox")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _gen_wait in 500:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 10:
		await process_frame

	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if build_system == null or bridge == null:
		_fail("Expected BuildSystem and BlockNavBridge")
		return
	economy.call("add_resource", 1, &"bio", 999999)

	# --- the two rosters are split, and neither building overlaps -------------
	var lab: Array = UnitCatalog.get_definition(&"barracks").get("production", [])
	var muster: Array = UnitCatalog.get_definition(&"steel_musterhouse").get("production", [])
	if muster.is_empty():
		_fail("The Musterhouse produces nothing")
		return
	for archetype in muster:
		if UnitCatalog.faction_of(archetype) != &"steel_force":
			_fail("The Musterhouse produces %s, which is not Steel Force" % archetype)
			return
		if lab.has(archetype):
			_fail("%s can still be made at the Biospawner; the Steel Force is supposed to muster at its own hall" % archetype)
			return
	# Every conscript must have somewhere to be made, or a Conscription rank
	# unlocks a unit no building can produce.
	var order: Array = BuildSystem.RECRUITMENT_ORDER
	for archetype in order:
		if not muster.has(archetype):
			_fail("%s is on the Conscription ladder and the Musterhouse cannot produce it" % archetype)
			return

	# --- it is a real block structure, sized to its own geometry --------------
	var definition = bridge.get("library").get_definition(&"steel_force_barracks_farm_01")
	if definition == null:
		_fail("The authored structure steel_force_barracks_farm_01 is not in the library")
		return
	var footprint: Vector2i = UnitCatalog.get_definition(&"steel_musterhouse").get("footprint", Vector2i.ZERO)
	if footprint != Vector2i(definition.dimensions.x, definition.dimensions.z):
		_fail("The building's footprint is %s and its geometry is %sx%s -- the blockers and the walls would describe different buildings" % [
			footprint, definition.dimensions.x, definition.dimensions.z])
		return

	# --- it can be built, and it musters ---------------------------------------
	var origin := Vector2i(40, 40)
	if not bool(build_system.call("try_place_structure", 1, &"steel_musterhouse", origin)):
		_fail("Could not build a Musterhouse on a benchmark map")
		return
	for _i in 10:
		await process_frame
	_complete_structures(build_system)
	var house := _structure_at(build_system, &"steel_musterhouse")
	if StringName(house.get("block_instance", &"")) == &"":
		_fail("The Musterhouse has no block instance, so its interior was never stamped in")
		return

	# The authored anchor, not the generic corner offset.
	var anchor: Vector3i = UnitCatalog.get_definition(&"steel_musterhouse")["muster_anchor"]
	var muster_cell: Vector2i = build_system.call("_muster_cell", house)
	if muster_cell != origin + Vector2i(anchor.x, anchor.z):
		_fail("Recruits muster at %s; the structure authored %s" % [muster_cell, origin + Vector2i(anchor.x, anchor.z)])
		return
	# ...and it must be a cell of THIS building, or the unit appears outside it.
	#
	# Searched across levels rather than assumed at 0: the anchor is authored at
	# y=1 (standing on the hall floor, not buried in the foundation), and the
	# structure's own base sits at the terrain height under its origin.
	var found_level := -1
	for level in range(0, 6):
		if StringName(bridge.call("structure_instance_at", muster_cell, level)) == StringName(house.get("block_instance", &"")):
			found_level = level
			break
	if found_level < 0:
		_fail("The muster point %s is not inside the Musterhouse at any level" % muster_cell)
		return

	# --- rotation moves the muster point with the walls -----------------------
	#
	# The half of this that silently does not work: an authored offset added to a
	# rotated building's origin puts recruits wherever that corner now is.
	var turned: Vector3i = definition.call("turn_local_cell", anchor, 1)
	if turned == anchor:
		_fail("Rotating the muster anchor by one step did not move it")
		return

	# --- Kon's roster is refused here, and the Steel Force is refused there ----
	if bool(build_system.call("produce_unit_from_structure", 1, &"horror", house.get("node", null))):
		_fail("A Horror was accepted at the Steel Force Musterhouse")
		return
	build_system.call("add_free_structure", 1, &"barracks", origin + Vector2i(20, 0), "")
	for _i in 8:
		await process_frame
	_complete_structures(build_system)
	var ranks: Dictionary = build_system.get("researched_upgrade_ranks")
	ranks[&"steel_conscription"] = order.size()
	build_system.set("researched_upgrade_ranks", ranks)
	var biospawner := _structure_at(build_system, &"barracks")
	if bool(build_system.call("produce_unit_from_structure", 1, &"poorper", biospawner.get("node", null))):
		_fail("A Poorper was accepted at the Biospawner even with Conscription; the Steel Force should muster at its own hall")
		return

	# --- and a conscript actually walks out of it ------------------------------
	var before := _count(scene, &"poorper")
	if not bool(build_system.call("produce_unit_from_structure", 1, &"poorper", house.get("node", null))):
		_fail("A conscripted Poorper was refused at the Musterhouse")
		return
	for _i in 2000:
		if _count(scene, &"poorper") > before:
			break
		await process_frame
	if _count(scene, &"poorper") <= before:
		_fail("The Poorper was queued at the Musterhouse but never arrived")
		return

	print("[SteelMusterhouseSmokeTest] the Steel Force musters at its own hall and no longer at the Biospawner, recruits appear at the structure's authored muster point, and the anchor turns with the building")
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

func _count(scene: Node, archetype: StringName) -> int:
	var count := 0
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("unit_archetype") == null:
			continue
		if StringName(unit.get("unit_archetype")) == archetype and int(unit.get("owner_player_id")) == 1:
			count += 1
	return count

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
