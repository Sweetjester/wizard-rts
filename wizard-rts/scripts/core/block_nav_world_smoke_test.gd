extends SceneTree

# The block elevation system: multi-level navigation over terrain plus placed
# structures (experimental, added 2026-09-04).
#
# Uses a STUB terrain rather than booting the real map, because the properties
# under test are exact -- "this column has two standable levels", "this cliff is
# impassable, that ramp is not" -- and a procedurally generated map cannot
# guarantee any particular cell is a cliff. The stub implements the same three
# calls BlockNavWorld makes of MapGenerator, and nothing else.
#
# The headline assertion is the one the whole system exists for: an infantry
# unit standing on open ground can path onto a wall-walk six levels up, and a
# heavy unit standing in the same spot cannot.

# 24x24 of flat ground at level 0, with two plateaus at level 2:
#   * RAMPED   -- reachable, because its edge cells are not cliff edges
#   * CLIFFED  -- not reachable on foot at all
class StubTerrain extends Node:
	const MAP_W := 24
	const MAP_H := 24
	const RAMPED := Rect2i(14, 3, 6, 6)
	const CLIFFED := Rect2i(3, 15, 5, 5)
	# The one column where the ramped plateau can actually be climbed.
	const RAMP_CELLS := [Vector2i(13, 5), Vector2i(14, 5), Vector2i(13, 6), Vector2i(14, 6)]

	func is_walkable_cell(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H

	func get_height(cell: Vector2i) -> int:
		if RAMPED.has_point(cell) or CLIFFED.has_point(cell):
			return 2
		return 0

	# MapGenerator's own rule: an unramped height edge. Anything bordering a
	# height change is a cliff unless it is one of the ramp cells.
	func is_cliff_edge_cell(cell: Vector2i) -> bool:
		if RAMP_CELLS.has(cell):
			return false
		var height := get_height(cell)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if get_height(cell + offset) != height:
				return true
		return false

const UNIT_CLASSES := {
	"infantry": {
		"footprint": [1, 1], "can_use_floor": true, "can_use_stairs": true,
		"can_use_ramps": true, "can_use_ladders": false, "can_use_climb_points": false,
		"can_use_portals": true, "can_pass_open_gates": true, "max_drop_blocks": 1,
	},
	"archer": {"inherits": "infantry"},
	"climber": {
		"footprint": [1, 1], "can_use_floor": true, "can_use_stairs": true,
		"can_use_ramps": true, "can_use_ladders": true, "can_use_climb_points": true,
		"can_use_portals": true, "can_pass_open_gates": true, "max_drop_blocks": 2,
	},
	"heavy": {
		"footprint": [2, 2], "can_use_floor": true, "can_use_stairs": false,
		"can_use_ramps": true, "can_use_ladders": false, "can_use_climb_points": false,
		"can_use_portals": false, "can_pass_open_gates": true, "max_drop_blocks": 0,
	},
	"flying": {"ignores_ground_navigation": true},
}

var _terrain: StubTerrain
var _world: BlockNavWorld
var _library: BlockStructureLibrary

func _initialize() -> void:
	_library = BlockStructureLibrary.load_default()
	_terrain = StubTerrain.new()
	root.add_child(_terrain)
	_world = BlockNavWorld.new(UNIT_CLASSES)
	_world.build_from_terrain(_terrain)

	if not _check_terrain_lattice():
		return
	if not _check_structure_adds_levels():
		return
	if not _check_vertical_pathing():
		return
	if not _check_gate_and_flight():
		return
	print("[BlockNavWorldSmokeTest] units path between elevations through authored links, and only where allowed")
	quit(0)

# Terrain is one standable level per column, and a height change is only
# crossable where the terrain says it is ramped.
func _check_terrain_lattice() -> bool:
	if _world.node_count() != StubTerrain.MAP_W * StubTerrain.MAP_H:
		_fail("Flat walkable terrain should give one node per cell, got %d" % _world.node_count())
		return false
	if _world.levels_at(Vector2i(2, 2)) != [0]:
		_fail("Open ground should have exactly one standable level, got %s" % [_world.levels_at(Vector2i(2, 2))])
		return false

	# Up the ramp: reachable.
	var up := _world.find_path(Vector2i(2, 5), 0, Vector2i(17, 5), 2, &"infantry")
	if up.is_empty():
		_fail("Infantry should be able to walk up a ramped plateau")
		return false
	if up[up.size() - 1] != Vector3i(17, 2, 5):
		_fail("Path should end on the plateau at level 2, ended %s" % [up[up.size() - 1]])
		return false
	# The path must actually change level somewhere, or it proves nothing.
	var climbed := false
	for step in up:
		if step.y == 2:
			climbed = true
	if not climbed:
		_fail("Path to the plateau never reached level 2")
		return false

	# Up the cliff: not reachable on foot.
	if not _world.find_path(Vector2i(2, 17), 0, Vector2i(5, 17), 2, &"infantry").is_empty():
		_fail("Infantry walked up an unramped cliff edge")
		return false
	return true

# The point of the whole system: a column can have more than one standable level.
func _check_structure_adds_levels() -> bool:
	var definition := _library.get_definition(&"fortress_gatehouse_02_walkable")
	if definition == null:
		_fail("Corrected gatehouse missing -- run tools/blocks/convert_structures.py")
		return false
	# Placed on flat ground so its base level matches the terrain it sits on.
	_world.place_structure(definition, Vector2i(4, 4), 0, &"gatehouse_a")
	_world.gate_states = {"gate_open": true}

	# Gatehouse-local (3,6,8) is the wall-walk; world column is (4+3, 4+8).
	var wall_column := Vector2i(7, 12)
	var levels := _world.levels_at(wall_column)
	if levels.size() < 2:
		_fail("A column under a wall-walk should have two standable levels, got %s" % [levels])
		return false
	if not levels.has(0) or not levels.has(6):
		_fail("Expected ground level 0 and wall-walk level 6, got %s" % [levels])
		return false
	return true

# The headline: same starting cell, same goal, different class, different answer.
func _check_vertical_pathing() -> bool:
	var ground := Vector2i(8, 5)     # open ground south of the gatehouse
	var wall_walk := Vector2i(7, 12) # on the wall-walk, six levels up

	var infantry := _world.find_path(ground, 0, wall_walk, 6, &"infantry")
	if infantry.is_empty():
		_fail("Infantry could not path from open ground up onto the wall-walk")
		return false
	if infantry[0] != Vector3i(8, 0, 5) or infantry[infantry.size() - 1] != Vector3i(7, 6, 12):
		_fail("Path should run ground -> wall-walk, got %s .. %s" % [infantry[0], infantry[infantry.size() - 1]])
		return false
	# It must pass through the gate to get inside, so a route exists at level 0
	# before it climbs. A path that teleported straight up would pass the
	# endpoint check above but not this one.
	var levels_used := {}
	for step in infantry:
		levels_used[step.y] = true
	if not levels_used.has(0) or not levels_used.has(6):
		_fail("Path should span level 0 and level 6, used %s" % [levels_used.keys()])
		return false

	# Heavy: same start, same goal, refused -- it cannot use stairs.
	if not _world.find_path(ground, 0, wall_walk, 6, &"heavy").is_empty():
		_fail("Heavy reached the wall-walk, but heavy cannot use stairs")
		return false
	# ...yet it can still get through the gate at ground level.
	if _world.find_path(ground, 0, Vector2i(8, 11), 0, &"heavy").is_empty():
		_fail("Heavy should still be able to walk through the open gate")
		return false
	# Archer inherits infantry and must behave identically.
	if _world.find_path(ground, 0, wall_walk, 6, &"archer").is_empty():
		_fail("Archer inherits infantry and should reach the wall-walk")
		return false
	return true

func _check_gate_and_flight() -> bool:
	var ground := Vector2i(8, 5)
	var inside := Vector2i(8, 11)
	_world.gate_states = {"gate_open": false}
	if not _world.find_path(ground, 0, inside, 0, &"infantry").is_empty():
		_fail("Infantry walked through a closed gate")
		return false
	# Flying ignores ground navigation, closed gate included.
	if _world.find_path(ground, 0, inside, 0, &"flying").is_empty():
		_fail("Flying should ignore a closed gate")
		return false
	_world.gate_states = {"gate_open": true}
	if _world.find_path(ground, 0, inside, 0, &"infantry").is_empty():
		_fail("Reopening the gate should restore the route")
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
