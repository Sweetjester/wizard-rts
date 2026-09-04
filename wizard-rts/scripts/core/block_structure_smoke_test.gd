extends SceneTree

# Block-structure traversal (experimental, added 2026-09-04).
#
# Covers the test cases the pack itself specifies, A through G, plus the region
# expansion everything else depends on. Runs headlessly with no scene and no
# renderer: navigation is authored data, so proving it needs neither.
#
# Two structures are used deliberately:
#   * fortress_gatehouse_02_walkable -- the authored correction, where A-G can
#     actually be demonstrated.
#   * fortress_gatehouse_01 -- the ORIGINAL, asserted here to still have the gaps
#     found on 2026-09-04, so that if someone repairs the source data this test
#     tells them to update the correction rather than silently diverging.

const ORIGINAL := &"fortress_gatehouse_01"
const WALKABLE := &"fortress_gatehouse_02_walkable"

var _library: BlockStructureLibrary

func _initialize() -> void:
	_library = BlockStructureLibrary.load_default()
	if _library.structure_ids().is_empty():
		_fail("No structures loaded -- run tools/blocks/convert_structures.py")
		return
	if not _check_region_expansion():
		return
	if not _check_original_gaps():
		return
	if not _check_traversal_cases():
		return
	print("[BlockStructureSmokeTest] A-G hold on the corrected gatehouse; the original's authoring gaps are pinned")
	quit(0)

# Every range in the spec is INCLUSIVE. Off-by-one here would make every
# structure one cell short in each dimension and would not obviously look wrong.
func _check_region_expansion() -> bool:
	var cells := BlockStructureDefinition.expand_region({"x": [0, 2], "y": 1, "z": [5, 6]})
	if cells.size() != 3 * 1 * 2:
		_fail("Inclusive region [0,2]x[1]x[5,6] should expand to 6 cells, got %d" % cells.size())
		return false
	if not cells.has(Vector3i(2, 1, 6)):
		_fail("Inclusive expansion dropped its upper corner")
		return false
	return true

# Pins the finding rather than the assumption: the original's vertical links
# begin in cells no nav region declares, so nothing can use them.
func _check_original_gaps() -> bool:
	var definition := _library.get_definition(ORIGINAL)
	var nav := _library.navigation_for(ORIGINAL)
	nav.gate_states = {"gate_open": true}
	for link in definition.links:
		if link["type"] != &"STAIR":
			continue
		if not definition.nav_at(link["from"]).is_empty():
			_fail("%s: stair %s now has a declared bottom endpoint -- the source data was fixed, so %s should be revisited"
					% [ORIGINAL, link["id"], WALKABLE])
			return false
	if nav.can_reach_region(Vector3i(4, 0, 0), &"wall_walk", &"infantry"):
		_fail("%s: the wall-walk became reachable -- update this test and the correction" % ORIGINAL)
		return false
	return true

func _check_traversal_cases() -> bool:
	var nav := _library.navigation_for(WALKABLE)
	if nav == null:
		_fail("Corrected gatehouse %s not found" % WALKABLE)
		return false
	nav.gate_states = {"gate_open": true}
	var south := Vector3i(4, 0, 0)   # outside the gate
	# One cell in from the far edge on purpose: a 2x2 heavy standing at z=9 would
	# need z=10, which is outside the structure. That is correct footprint
	# behaviour, not a blocked route, so the target has to leave room for it.
	var north := Vector3i(4, 0, 8)   # through the structure, past the gate

	# A. infantry passes through an open gate.
	if not nav.can_reach(south, north, &"infantry"):
		_fail("A: infantry could not pass through the open gate")
		return false
	# B. infantry climbs to the wall-walk using stairs.
	if not nav.can_reach_region(south, &"wall_walk", &"infantry"):
		_fail("B: infantry could not reach the wall-walk by stairs")
		return false
	# C. heavy passes through the open gate.
	if not nav.can_reach(south, north, &"heavy"):
		_fail("C: heavy could not pass through the open gate")
		return false
	# D. heavy cannot use stairs. The load-bearing negative: heavy is barred by
	# its can_use_stairs flag, not by the geometry happening to be narrow.
	if nav.can_reach_region(south, &"wall_walk", &"heavy"):
		_fail("D: heavy reached the wall-walk, but heavy cannot use stairs")
		return false
	# E. climber uses a CLIMB_POINT where one is authored.
	if not nav.can_reach_region(south, &"left_tower_roof", &"climber"):
		_fail("E: climber could not reach the tower roof by its climb point")
		return false
	if nav.can_reach_region(south, &"left_tower_roof", &"infantry"):
		_fail("E: infantry used a climb point, which only climbers may use")
		return false
	# Archer inherits infantry, so it must behave exactly like it.
	if not nav.can_reach_region(south, &"wall_walk", &"archer"):
		_fail("archer inherits infantry and should reach the wall-walk too")
		return false

	# F. a closed gate blocks non-flying ground movement.
	nav.gate_states = {"gate_open": false}
	if nav.can_reach(south, north, &"infantry"):
		_fail("F: infantry passed a closed gate")
		return false
	if nav.can_reach(south, north, &"heavy"):
		_fail("F: heavy passed a closed gate")
		return false
	# An unset gate key must read as CLOSED, or a structure nobody configured
	# would be silently open.
	nav.gate_states = {}
	if nav.can_occupy(Vector3i(4, 0, 1), &"infantry"):
		_fail("F: an unconfigured gate must default to closed, not open")
		return false

	# G. flying ignores ground traversal entirely -- closed gate included.
	if not nav.can_reach(south, north, &"flying"):
		_fail("G: flying should ignore the closed gate")
		return false
	if not nav.can_reach_region(south, &"wall_walk", &"flying"):
		_fail("G: flying should reach the wall-walk without using stairs")
		return false

	# Footprint, not just permissions: siege is 3x3 and must be excluded from
	# the 1-cell stair links regardless of any allowed list.
	nav.gate_states = {"gate_open": true}
	if nav.can_reach_region(south, &"wall_walk", &"siege"):
		_fail("siege reached the wall-walk despite a 3x3 footprint on 1-wide stairs")
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
