extends SceneTree

# Flow fields over the block lattice (experimental, 2026-09-04).
#
# The assertion that matters is AGREEMENT: a flow field and A* must reach the
# same conclusion about every start, or units routed by the cheap system would
# behave differently from units routed by the expensive one, which is the worst
# possible outcome -- a bug that only appears at wave scale.
#
# Run against the citadel because it is the first structure large enough for the
# difference to matter: 11427 nodes and 43 authored links.

const CITADEL := &"kons_arcane_citadel_01"
const SAMPLE_SIZE := 120

class FlatGround extends Node:
	var MAP_W := 116
	var MAP_H := 116
	func is_walkable_cell(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H
	func get_height(_cell: Vector2i) -> int:
		return 0
	func is_cliff_edge_cell(_cell: Vector2i) -> bool:
		return false

var _world: BlockNavWorld
var _origin := Vector2i(10, 10)

func _initialize() -> void:
	var library := BlockStructureLibrary.load_default()
	var definition := library.get_definition(CITADEL)
	if definition == null:
		_fail("Citadel missing -- run tools/blocks/convert_structures.py")
		return
	var ground := FlatGround.new()
	root.add_child(ground)
	_world = BlockNavWorld.new(library.unit_classes)
	_world.build_from_terrain(ground)
	for key in library.gate_defaults_for(CITADEL):
		_world.gate_states[key] = true
	_world.place_structure(definition, _origin, 0, CITADEL)

	if not _check_agreement():
		return
	if not _check_one_way_links_are_not_reversed():
		return
	if not _check_flying():
		return
	print("[BlockFlowFieldSmokeTest] the field agrees with A* on every sampled start, and respects one-way links")
	quit(0)

# A field and A* must agree, both on WHETHER a start can reach the goal and on
# where the route ends up. Costs may differ slightly -- A* stops at the goal
# while the field is exhaustive -- but reachability must be identical.
func _check_agreement() -> bool:
	var goal_cell := Vector2i(_origin.x + 48, _origin.y + 48)
	var goal_level := 40  # the keep roof, the deepest point in the castle
	var field := BlockFlowField.new()
	var started := Time.get_ticks_usec()
	if not field.build(_world, goal_cell, goal_level, &"infantry"):
		_fail("Flow field refused to build for the keep roof")
		return false
	var build_us := Time.get_ticks_usec() - started
	if field.covered_nodes() <= 0:
		_fail("Flow field covered no nodes")
		return false

	var starts := _sample_starts(&"infantry")
	if starts.size() < 10:
		_fail("Only %d sampled starts; the test would prove little" % starts.size())
		return false

	var astar_us := 0
	var checked := 0
	for start in starts:
		var astar_started := Time.get_ticks_usec()
		var astar := _world.find_path(Vector2i(start.x, start.z), start.y, goal_cell, goal_level, &"infantry")
		astar_us += Time.get_ticks_usec() - astar_started
		var field_reaches := field.is_reachable(_world, Vector2i(start.x, start.z), start.y)
		if field_reaches != (astar.size() >= 1):
			_fail("Disagreement at %s: A* %s, flow field %s" % [
				start, "reaches" if astar.size() >= 1 else "does not", field_reaches])
			return false
		if not field_reaches:
			continue
		var walked := field.path_from(_world, Vector2i(start.x, start.z), start.y)
		if walked.is_empty():
			_fail("Field said %s was reachable but produced no path" % start)
			return false
		if walked[walked.size() - 1] != Vector3i(goal_cell.x, goal_level, goal_cell.y):
			_fail("Field path from %s ended at %s, not the goal" % [start, walked[walked.size() - 1]])
			return false
		checked += 1
	print("[BlockFlowFieldSmokeTest] %d nodes covered, built in %.1f ms; %d starts: A* total %.1f ms vs one field" % [
		field.covered_nodes(), float(build_us) / 1000.0, checked, float(astar_us) / 1000.0])
	if build_us >= astar_us:
		# Not a hard failure -- machines differ -- but the whole point of the
		# field is that it beats N searches, so say so loudly if it does not.
		push_warning("Flow field build (%.1f ms) was not cheaper than %d A* runs (%.1f ms)"
			% [float(build_us) / 1000.0, checked, float(astar_us) / 1000.0])
	return true

# A field expands backwards. If it assumed edges were symmetric it would route
# units UP a one-way drop, so heavy -- which is barred from stairs -- must be
# unable to reach anything the stairs are the only way to.
func _check_one_way_links_are_not_reversed() -> bool:
	var goal_cell := Vector2i(_origin.x + 48, _origin.y + 48)
	var field := BlockFlowField.new()
	field.build(_world, goal_cell, 40, &"heavy")
	var courtyard := Vector3i(_origin.x + 48, 2, _origin.y + 24)
	if field.is_reachable(_world, Vector2i(courtyard.x, courtyard.z), courtyard.y):
		_fail("A heavy reached the keep roof through the flow field, but it cannot use stairs")
		return false
	return true

func _check_flying() -> bool:
	var field := BlockFlowField.new()
	var goal_cell := Vector2i(_origin.x + 48, _origin.y + 48)
	if not field.build(_world, goal_cell, 40, &"flying"):
		_fail("Flow field refused to build for a flying class")
		return false
	var start := Vector2i(_origin.x + 48, _origin.y + 2)
	if not field.is_reachable(_world, start, 2):
		_fail("Flying should reach the keep roof regardless of the walk graph")
		return false
	var path := field.path_from(_world, start, 2)
	if path.size() != 2:
		_fail("A flying route should be a single hop, got %d steps" % path.size())
		return false
	return true

func _sample_starts(unit_class: StringName) -> Array[Vector3i]:
	var starts: Array[Vector3i] = []
	var stride: int = 7
	for x in range(_origin.x, _origin.x + 96, stride):
		for z in range(_origin.y, _origin.y + 96, stride):
			var cell := Vector2i(x, z)
			for level in _world.levels_at(cell):
				if _world.can_occupy(_world.encode(cell, level), unit_class):
					starts.append(Vector3i(x, level, z))
					break
			if starts.size() >= SAMPLE_SIZE:
				return starts
	return starts

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
