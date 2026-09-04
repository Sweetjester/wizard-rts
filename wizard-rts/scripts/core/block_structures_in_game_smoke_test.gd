extends SceneTree

# Block structures reaching an actual run (experimental, 2026-09-04).
#
# The two previous block tests prove the lattice and the unit wiring in
# isolation. This one proves the parts nobody had connected: that structures get
# placed onto the generated map at startup, that the 2D simulation is told about
# their walls, and that a right-click on a multi-level column routes through the
# lattice instead of the flat pathfinder.
#
# The most important assertion is the negative one. Almost every order in this
# game is to ordinary flat ground, and those must still go through the existing
# 2D path exactly as before -- so an order to open ground is asserted to carry
# no elevation data at all.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "block-in-game-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	# Placement is deferred until map generation settles, so this waits rather
	# than assuming it has happened by the first frame.
	for _i in 20:
		await process_frame

	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	var selection: Node = scene.get_node_or_null("SelectionController")
	if bridge == null or terrain == null or selection == null:
		_fail("Expected BlockNavBridge, MapGenerator and SelectionController in main_map.tscn")
		return
	var world = bridge.get("world")
	if world == null or world.node_count() <= 0:
		_fail("The bridge built no lattice from the live map")
		return

	var multi := _find_multi_level_column(bridge, terrain)
	if multi == Vector2i(-1, -1):
		_fail("No structure was placed on the generated map, so nothing has two levels")
		return
	if not _check_walls_block_2d(bridge, terrain):
		return
	if not _check_right_click_climbs(scene, terrain, bridge, selection, multi):
		return
	if not _check_flat_orders_untouched(scene, terrain, selection):
		return
	print("[BlockStructuresInGameSmokeTest] structures are placed on the live map, their walls block 2D, and right-click routes upward")
	scene.queue_free()
	quit(0)

func _find_multi_level_column(bridge: Node, terrain: Node) -> Vector2i:
	for x in int(terrain.get("MAP_W")):
		for y in int(terrain.get("MAP_H")):
			var cell := Vector2i(x, y)
			if bool(bridge.call("is_multi_level", cell)):
				return cell
	return Vector2i(-1, -1)

# The 2D pathfinder knows nothing about levels, so a structure's ground-floor
# walls have to be registered as blockers or ordinary units walk through them.
func _check_walls_block_2d(bridge: Node, terrain: Node) -> bool:
	var blocked := 0
	for placement in bridge.get("world").placements():
		var origin: Vector2i = placement["origin"]
		for dx in 12:
			for dy in 10:
				if not bool(terrain.call("is_walkable_cell", origin + Vector2i(dx, dy))):
					blocked += 1
	if blocked <= 0:
		_fail("A placed structure blocked no 2D cells -- units would walk through its walls")
		return false
	return true

# The headline: right-click a multi-level column and the unit is routed up it.
#
# Scans the multi-level columns rather than taking the first one, because not
# every raised surface is reachable on foot -- a gatehouse tower roof is only
# served by a CLIMB_POINT, which is climber-only, so an infantry order there
# correctly falls back to the ground floor. The assertion is that at least one
# column exists that infantry can genuinely be sent up, which is what a player
# right-clicking a wall-walk needs to be true.
func _check_right_click_climbs(scene: Node, terrain: Node, bridge: Node, selection: Node, _first: Vector2i) -> bool:
	var unit: Node2D = _spawn(scene, terrain)
	var climbed_at := Vector2i(-1, -1)
	var best_gain := 0
	for placement in bridge.get("world").placements():
		var origin: Vector2i = placement["origin"]
		for dx in 14:
			for dy in 12:
				var cell: Vector2i = origin + Vector2i(dx, dy)
				if not bool(bridge.call("is_multi_level", cell)):
					continue
				# Start outside the structure, on ground, every attempt.
				var start: Vector2i = terrain.call("nearest_walkable_cell", origin + Vector2i(4, -3), 12)
				unit.global_position = terrain.call("cell_to_world", start)
				unit.set("nav_level", 0)
				unit.set("path_levels", [] as Array[int])
				if not bool(selection.call("_try_block_move_order", terrain.call("cell_to_world", cell), [unit])):
					continue
				var levels: Array = unit.get("path_levels")
				if levels.is_empty():
					continue
				var gain: int = int(levels[levels.size() - 1]) - int(levels[0])
				if gain > best_gain:
					best_gain = gain
					climbed_at = cell
	if climbed_at == Vector2i(-1, -1):
		_fail("No placed structure had a raised surface infantry could be right-clicked onto")
		return false
	print("[BlockStructuresInGameSmokeTest] infantry routed %d levels up at %s" % [best_gain, climbed_at])
	unit.queue_free()
	return true

# Flat ground is almost every order in the game. It must not have changed.
func _check_flat_orders_untouched(scene: Node, terrain: Node, selection: Node) -> bool:
	var open_cell := Vector2i(-1, -1)
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	for x in range(4, int(terrain.get("MAP_W")) - 4, 3):
		for y in range(4, int(terrain.get("MAP_H")) - 4, 3):
			var cell := Vector2i(x, y)
			if bool(terrain.call("is_walkable_cell", cell)) and not bool(bridge.call("is_multi_level", cell)):
				open_cell = cell
				break
		if open_cell != Vector2i(-1, -1):
			break
	if open_cell == Vector2i(-1, -1):
		_fail("Found no ordinary single-level cell on the map")
		return false
	var unit: Node2D = _spawn(scene, terrain)
	unit.global_position = terrain.call("cell_to_world", terrain.call("nearest_walkable_cell", open_cell + Vector2i(6, 0), 10))
	if bool(selection.call("_try_block_move_order", terrain.call("cell_to_world", open_cell), [unit])):
		_fail("An order to ordinary ground was routed through the lattice; it should fall through to 2D")
		return false
	if not (unit.get("path_levels") as Array).is_empty():
		_fail("An order to ordinary ground attached elevation data")
		return false
	unit.queue_free()
	return true

func _spawn(scene: Node, terrain: Node) -> Node2D:
	var unit: Node2D = (load("res://scenes/units/oaven_spear.tscn") as PackedScene).instantiate()
	unit.set("owner_player_id", 1)
	scene.add_child(unit)
	return unit

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
