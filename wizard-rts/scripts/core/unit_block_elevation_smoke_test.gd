extends SceneTree

# A real RTSUnit moving on the block elevation lattice (experimental, 2026-09-04).
#
# The other block tests prove the lattice in isolation. This one proves the
# wiring: an actual game unit, with its actual movement tick, ordered onto a
# wall-walk six levels above the ground it started on, ending up there with the
# right nav_level.
#
# It also pins the property that makes the wiring safe to have landed at all:
# a unit given an ordinary 2D order must behave exactly as it did before, with
# no elevation data attached.

const UNIT_SCENE := "res://scenes/units/oaven_spear.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "block-elevation-smoke", "bad_kon_willow", "seeded_grid_frontier")
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

	var terrain: Node = scene.get_node_or_null("MapGenerator")
	if terrain == null:
		_fail("Expected MapGenerator in main_map.tscn")
		return

	# The bridge attaches to the REAL map. That it needs nothing special from it
	# is the point worth asserting: the terrain contract is three calls.
	var bridge := BlockNavBridge.new()
	bridge.name = "BlockNavBridge"
	bridge.map_path = NodePath("")
	scene.add_child(bridge)
	bridge.terrain = terrain
	bridge.library = BlockStructureLibrary.load_default()
	bridge.rebuild()
	if bridge.world == null or bridge.world.node_count() <= 0:
		_fail("Bridge built no lattice from the live map")
		return

	if not _check_plain_orders_unchanged(scene, terrain):
		return
	if not _check_unit_climbs(scene, terrain, bridge):
		return
	print("[UnitBlockElevationSmokeTest] a live RTSUnit walks from ground onto a wall-walk, and plain orders are untouched")
	scene.queue_free()
	quit(0)

# A normal move order must carry no elevation data at all. If this ever fails,
# the lattice has started affecting units nobody put on it.
func _check_plain_orders_unchanged(scene: Node, terrain: Node) -> bool:
	var unit: Node2D = _spawn(scene, terrain, Vector2i(20, 20))
	if unit == null:
		return false
	var goal: Vector2 = terrain.call("cell_to_world", terrain.call("nearest_walkable_cell", Vector2i(24, 20), 8))
	unit.call("issue_move_order", goal)
	if not (unit.get("path_levels") as Array).is_empty():
		_fail("A plain move order attached elevation data: %s" % [unit.get("path_levels")])
		return false
	unit.queue_free()
	return true

# The headline. Place a gatehouse on flat ground, stand a unit outside it, and
# order it onto the wall-walk. The unit has to walk in through the gate and up
# the stairs to get there -- the goal is six levels above where it started.
func _check_unit_climbs(scene: Node, terrain: Node, bridge: BlockNavBridge) -> bool:
	var origin := _flat_area(terrain)
	if origin == Vector2i(-1, -1):
		_fail("Found no flat 14x12 area on the generated map to place a gatehouse")
		return false
	if not bridge.place(&"fortress_gatehouse_02_walkable", origin, &"test_gatehouse"):
		_fail("Bridge refused to place the gatehouse")
		return false

	# Gatehouse-local (3,6,8) is on the wall-walk.
	var wall_cell := origin + Vector2i(3, 8)
	var base_level: int = int(terrain.call("get_height", origin))
	var wall_level: int = base_level + 6
	if not bridge.levels_at(wall_cell).has(wall_level):
		_fail("Expected a standable level %d at %s, got %s" % [wall_level, wall_cell, bridge.levels_at(wall_cell)])
		return false

	var start_cell := origin + Vector2i(4, 0)
	var unit: Node2D = _spawn(scene, terrain, start_cell)
	if unit == null:
		return false
	if not bridge.order_to(unit, wall_cell, wall_level, &"infantry"):
		_fail("Bridge could not route a unit from %s to the wall-walk at %s" % [start_cell, wall_cell])
		return false
	var levels: Array = unit.get("path_levels")
	if levels.is_empty():
		_fail("The unit was given a path with no elevation data")
		return false
	if int(levels[levels.size() - 1]) != wall_level:
		_fail("Path should end at level %d, ends at %d" % [wall_level, int(levels[levels.size() - 1])])
		return false

	# Let it actually walk. This is the part that exercises RTSUnit's own
	# movement tick and the pop-in-lockstep helper, not just the path handoff.
	for _i in 900:
		unit.call("rts_movement_tick", 1.0 / 30.0)
		if (unit.get("path") as Array).is_empty():
			break
	if not (unit.get("path") as Array).is_empty():
		_fail("The unit did not finish its route: %d points left" % (unit.get("path") as Array).size())
		return false
	if int(unit.get("nav_level")) != wall_level:
		_fail("The unit finished at level %d, expected %d" % [int(unit.get("nav_level")), wall_level])
		return false

	# And a heavy is refused the same order, because it cannot use stairs. The
	# negative is what proves the class rules survived the wiring.
	var heavy: Node2D = _spawn(scene, terrain, start_cell)
	if bridge.order_to(heavy, wall_cell, wall_level, &"heavy"):
		_fail("A heavy was routed onto the wall-walk, but heavy cannot use stairs")
		return false
	return true

# A 14x12 patch at one height with nothing blocking it. The map is procedural,
# so the test finds a site rather than assuming one exists at a fixed cell.
func _flat_area(terrain: Node) -> Vector2i:
	for x in range(4, int(terrain.get("MAP_W")) - 16, 2):
		for y in range(4, int(terrain.get("MAP_H")) - 14, 2):
			var origin := Vector2i(x, y)
			var height: int = int(terrain.call("get_height", origin))
			var flat := true
			for dx in 14:
				for dy in 12:
					var cell := origin + Vector2i(dx, dy)
					if not bool(terrain.call("is_walkable_cell", cell)) \
							or int(terrain.call("get_height", cell)) != height:
						flat = false
						break
				if not flat:
					break
			if flat:
				return origin
	return Vector2i(-1, -1)

func _spawn(scene: Node, terrain: Node, cell: Vector2i) -> Node2D:
	var unit: Node2D = (load(UNIT_SCENE) as PackedScene).instantiate()
	unit.set("owner_player_id", 1)
	scene.add_child(unit)
	unit.global_position = terrain.call("cell_to_world", cell)
	return unit

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
