extends SceneTree

# A unit that goes up a floor has to come back down the same way.
#
# THE BUG: order a unit onto an upper floor and then order it to open ground.
# _try_block_move_order() decided whether to use the navigation lattice from the
# DESTINATION alone -- open grass has one level, so the lattice was skipped and
# the unit got an ordinary 2D path. A 2D path knows nothing about floors, and
# nothing ever reset nav_level, so the unit kept the storey height it was
# standing at and walked out through the wall, in the air, permanently.
#
# What is asserted, in order of how much each one matters:
#
#   1. THE INVARIANT, sampled every frame for the whole journey: a MOVING unit
#      with no lattice path must be at the terrain height under it. That is the
#      definition of flying and it is checked continuously rather than at the
#      end, because a unit that flies for two seconds and lands on arrival would
#      pass any before/after comparison while looking exactly like the bug.
#
#   2. It leaves LEGALLY. Inside the building it must be on a lattice path --
#      the thing that knows where the stairs and the door are. This assertion
#      exists because without it the test could not tell the real fix from the
#      safety net: grounding nav_level alone also stops the flying, by dropping
#      the unit through the floor to walk out through a wall. Both look identical
#      to a height check and only one is a unit leaving a building.
#
#   3. It actually leaves. Refusing the order would also stop the flying, and
#      would be a different bug: a unit stuck in a building forever.
#
#   4. It is genuinely elevated first. Without this the test could pass against
#      a build where units never get up a floor at all.
#
# A garrison HOLDING an upper floor is deliberately not affected -- it has no
# path and is not moving, so the invariant does not apply to it. That case is
# checked too, because grounding it would empty every tower in the game.

const TRAVEL_FRAMES := 1600

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "leave-building-smoke", "bad_kon_willow", "build_sandbox")
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
	var selection: Node = scene.get_node_or_null("SelectionController")
	var director: Node = scene.get_node_or_null("WaveDirector")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if build_system == null or bridge == null or selection == null or director == null:
		_fail("Expected BuildSystem, BlockNavBridge, SelectionController and WaveDirector")
		return
	if economy != null:
		economy.call("add_resource", 1, &"bio", 999999)

	# --- something with an upstairs -------------------------------------------
	var origin := Vector2i(40, 40)
	if not bool(build_system.call("try_place_structure", 1, &"wizard_tower", origin)):
		_fail("Could not raise a building with floors")
		return
	for _i in 8:
		await process_frame

	var upstairs := _upper_floor_cell(bridge, map, origin)
	if upstairs.is_empty():
		_fail("The building has no floor above ground to stand on")
		return

	# --- a unit, sent up ------------------------------------------------------
	var unit: Node2D = director.call("_spawn_enemy", &"oaven_spear", origin + Vector2i(-5, 0), scene, Vector2.ZERO)
	if unit == null or not is_instance_valid(unit):
		_fail("Could not spawn a unit")
		return
	unit.set("owner_player_id", 1)
	for _i in 10:
		await process_frame
	unit.call("issue_stop_order")

	if not bool(bridge.call("order_to", unit, upstairs["cell"], int(upstairs["level"]), &"infantry")):
		_fail("The lattice would not route a unit up to %s" % upstairs)
		return
	var arrived := false
	for _i in 900:
		await process_frame
		if int(unit.get("nav_level")) == int(upstairs["level"]) and not bool(unit.get("moving")):
			arrived = true
			break
	if not arrived:
		_fail("The unit never reached the upper floor (level %s, got %s)" % [
			upstairs["level"], unit.get("nav_level")])
		return
	var ground_here := int(map.call("get_height", map.call("world_to_cell", unit.global_position)))
	if int(unit.get("nav_level")) <= ground_here:
		_fail("The unit is not actually elevated: nav_level %s, terrain %s" % [unit.get("nav_level"), ground_here])
		return

	# --- a garrison holding an upper floor stays up there ----------------------
	for _i in 60:
		await process_frame
	if int(unit.get("nav_level")) <= ground_here:
		_fail("A unit standing still on an upper floor was dropped to the ground")
		return

	# --- and now: told to walk to open grass ----------------------------------
	var target_cell: Vector2i = map.call("nearest_walkable_cell", origin + Vector2i(-22, 0), 12)
	var target_world: Vector2 = map.call("cell_to_world", target_cell)
	var chosen: Array[Node] = [unit as Node]
	selection.call("_apply_selection", chosen)
	selection.call("_order_selected_units", target_world)

	var flew_at := -1
	var worst_height := 0
	var walked_through_wall_at := -1
	for frame in TRAVEL_FRAMES:
		await process_frame
		if not is_instance_valid(unit):
			_fail("The unit was freed mid-journey")
			return
		var cell: Vector2i = map.call("world_to_cell", unit.global_position)
		var terrain_level := int(map.call("get_height", cell))
		var level := int(unit.get("nav_level"))
		var on_lattice: bool = not (unit.get("path_levels") as Array).is_empty()
		# THE assertion. Moving, no lattice path, above the ground = flying.
		if bool(unit.get("moving")) and not on_lattice and level > terrain_level:
			if flew_at < 0:
				flew_at = frame
			worst_height = maxi(worst_height, level - terrain_level)
		# Still inside the building, moving, and not following the lattice: it is
		# crossing the structure without using its floors or its door.
		if bool(unit.get("moving")) and not on_lattice and bool(bridge.call("unit_is_in_structure", unit)):
			if walked_through_wall_at < 0:
				walked_through_wall_at = frame
		if not bool(unit.get("moving")) and cell.distance_to(target_cell) <= 3:
			break

	if flew_at >= 0:
		_fail("The unit flew: %s levels above the terrain while moving on an ordinary path, first seen at frame %d" % [
			worst_height, flew_at])
		return
	if walked_through_wall_at >= 0:
		_fail("The unit left the building on an ordinary 2D path (frame %d) instead of routing through its floors and door -- it did not leave legally, it walked out through the structure" % walked_through_wall_at)
		return

	# --- it left, and it is on the ground -------------------------------------
	var final_cell: Vector2i = map.call("world_to_cell", unit.global_position)
	if bool(bridge.call("unit_is_in_structure", unit)):
		_fail("The unit is still inside the building at %s; it was ordered out and never left" % final_cell)
		return
	var final_terrain := int(map.call("get_height", final_cell))
	if int(unit.get("nav_level")) != final_terrain:
		_fail("The unit finished at nav_level %s over terrain %s -- it is standing in the air" % [
			unit.get("nav_level"), final_terrain])
		return
	if final_cell.distance_to(target_cell) > 8:
		_fail("The unit stopped %s cells from where it was sent; it did not leave the building legally" % [
			final_cell.distance_to(target_cell)])
		return

	print("[LeaveBuildingSmokeTest] a unit sent upstairs walks back down and out on the ground, never above the terrain, and a garrison holding a floor is left where it is")
	scene.queue_free()
	quit(0)

# --- helpers ----------------------------------------------------------------

# A floor cell this structure owns that is ABOVE the terrain under it.
func _upper_floor_cell(bridge: Node, map: Node, origin: Vector2i) -> Dictionary:
	var best := {}
	var best_level := -1
	for radius in range(0, 16):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var cell := origin + Vector2i(dx, dz)
				if not bool(map.call("is_in_bounds", cell)):
					continue
				var ground := int(map.call("get_height", cell))
				for level in range(ground + 1, ground + 8):
					if StringName(bridge.call("structure_instance_at", cell, level)) == &"":
						continue
					if level > best_level:
						best_level = level
						best = {"cell": cell, "level": level}
	return best

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
