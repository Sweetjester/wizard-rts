extends SceneTree

# Guard for the vision/terrain rules added 2026-09-02:
#
#  1. BUILDINGS SEE. Structures reveal fog like units do -- a base used to be a
#     blind spot that revealed nothing around itself.
#  2. NO SIGHT UP CLIFFS, for the player AND the enemy AI. Sight travels level
#     or downhill and is blocked by higher ground. A unit cannot engage a target
#     above it unless it, or a nearby ally, actually has line of sight -- the
#     spotter rule. This runs inside the shared combat tick, so both sides obey
#     it by construction rather than by two matching implementations.
#  3. IMPASSABLE TERRAIN IS MARKED, so the player can read a cliff before
#     walking into it.
#
# Line of sight lives on MapGenerator precisely so fog and weapons cannot
# disagree; this test pins that they are the same function.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "vision-terrain-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 8:
		await process_frame

	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	var fog: Node = scene.get_node_or_null("FogOfWar")
	var overlay: Node = scene.get_node_or_null("ImpassableOverlay")
	if map_generator == null or fog == null or overlay == null:
		_fail("Expected MapGenerator, FogOfWar and ImpassableOverlay")
		return

	# --- terrain line of sight ---------------------------------------------
	# Find a real height transition on the generated map rather than assuming
	# one: a low cell orthogonally adjacent to a high cell.
	var low_cell := Vector2i(-1, -1)
	var high_cell := Vector2i(-1, -1)
	for x in range(2, int(map_generator.MAP_W) - 2):
		for y in range(2, int(map_generator.MAP_H) - 2):
			var here := Vector2i(x, y)
			if int(map_generator.call("get_height", here)) != 0:
				continue
			if not bool(map_generator.call("is_walkable_cell", here)):
				continue
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbour: Vector2i = here + offset
				if int(map_generator.call("get_height", neighbour)) > 0 and bool(map_generator.call("is_walkable_cell", neighbour)):
					low_cell = here
					high_cell = neighbour
					break
			if high_cell.x >= 0:
				break
		if high_cell.x >= 0:
			break
	if high_cell.x < 0:
		_fail("The generated map has no height transition to test against")
		return

	# Looking UP is blocked; looking DOWN from the same pair is not.
	if bool(map_generator.call("has_line_of_sight", low_cell, high_cell, 0)):
		_fail("A viewer on low ground should not see up onto high ground (%s -> %s)" % [low_cell, high_cell])
		return
	var high_height: int = int(map_generator.call("get_height", high_cell))
	if not bool(map_generator.call("has_line_of_sight", high_cell, low_cell, high_height)):
		_fail("A viewer on high ground should see down onto low ground")
		return
	# A viewer standing on the high cell can see it trivially.
	if not bool(map_generator.call("has_line_of_sight", high_cell, high_cell, high_height)):
		_fail("A cell should always see itself")
		return

	# --- combat obeys the same rule, and so does the AI ---------------------
	var low_unit := _spawn(scene, map_generator.call("cell_to_world", low_cell), 1)
	var high_unit := _spawn(scene, map_generator.call("cell_to_world", high_cell), 2)
	for _i in 4:
		await process_frame
	if bool(low_unit.call("can_engage_target", high_unit)):
		_fail("A unit below a cliff must not be able to engage one above it unaided")
		return
	# Downhill always works, which is what stops this becoming a stalemate.
	if not bool(high_unit.call("can_engage_target", low_unit)):
		_fail("A unit above a cliff should always be able to engage one below")
		return
	# The rule is symmetric for the enemy AI: swap owners and it still holds.
	low_unit.set("owner_player_id", 2)
	high_unit.set("owner_player_id", 1)
	if bool(low_unit.call("can_engage_target", high_unit)):
		_fail("The no-sight-uphill rule must apply to the enemy AI too, not just the player")
		return
	low_unit.set("owner_player_id", 1)
	high_unit.set("owner_player_id", 2)

	# --- a spotter unlocks it ----------------------------------------------
	# An ally standing level with the target can see it, which lets the unit
	# below engage. This is the mechanic the whole rule exists to create.
	var spotter := _spawn(scene, map_generator.call("cell_to_world", high_cell), 1)
	(spotter as Node2D).global_position = (high_unit as Node2D).global_position + Vector2(48.0, 0.0)
	# _ally_spots() reads RTSWorld's spatial buckets, which are rebuilt by the
	# combat tick -- so the spotter is not findable until that has run. Same
	# cadence dependency the heal aura and the aggro check both hit.
	for _i in 24:
		await process_frame
	if not bool(low_unit.call("can_engage_target", high_unit)):
		_fail("An ally with line of sight should let a unit below the cliff engage")
		return

	# --- buildings reveal fog ----------------------------------------------
	var revealers: Array = fog.call("_vision_revealers")
	var has_structure := false
	for node in revealers:
		if is_instance_valid(node) and node.get("archetype") != null:
			has_structure = true
			break
	if not has_structure:
		_fail("Structures must be fog revealers -- a base should not be a blind spot")
		return
	# And the tower's own cell should be lit by it.
	var tower: Node2D = null
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == "wizard_tower":
			tower = structure
			break
	if tower == null:
		_fail("Expected the player's tower")
		return
	for _i in 12:
		fog.call("_update_visibility")
	if not bool(fog.call("is_world_position_visible", tower.global_position)):
		_fail("A player structure should reveal its own position")
		return

	# --- impassable terrain is marked --------------------------------------
	if not overlay.visible:
		_fail("The impassable overlay should be active on the square-grid map")
		return
	var texture: Texture2D = overlay.get("overlay_texture")
	if texture == null:
		_fail("The impassable overlay should bake a texture")
		return
	if texture.get_width() != int(map_generator.MAP_W):
		_fail("The overlay should be one texel per cell")
		return
	# Something on the map must actually be marked, or the overlay is a no-op.
	var image := texture.get_image()
	var marked := 0
	for x in range(0, image.get_width(), 2):
		for y in range(0, image.get_height(), 2):
			if image.get_pixel(x, y).a > 0.05:
				marked += 1
	if marked <= 0:
		_fail("The impassable overlay marked nothing at all")
		return

	print("[VisionAndTerrainSmokeTest] no sight uphill for either side, spotters unlock it, buildings reveal, impassable terrain marked (%s sampled cells)" % marked)
	quit(0)

func _spawn(scene: Node, position: Vector2, owner_id: int) -> Node:
	var unit: Node = (load("res://scenes/units/oaven_spear.tscn") as PackedScene).instantiate()
	unit.set("owner_player_id", owner_id)
	scene.add_child(unit)
	unit.global_position = position
	return unit

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
