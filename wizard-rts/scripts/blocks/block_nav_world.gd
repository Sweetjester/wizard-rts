class_name BlockNavWorld
extends RefCounted

# The block elevation system: one navigation lattice for the whole map.
#
# THE IDEA. The game's terrain is already a block grid -- every cell stores an
# integer height, which is a column of blocks with one standable surface on top.
# This adds nothing new to terrain; it just stops pretending a column can only
# have ONE surface. A wall-walk over a gate passage is the same column with two
# standable levels, and once that is expressible, structures with interiors,
# bridges over roads and sunken temples all fall out of the same representation.
#
# A node is (cell.x, level, cell.z). Terrain contributes one node per walkable
# cell at that cell's height. A placed structure contributes extra nodes at its
# authored levels, plus the links that connect them.
#
# ELEVATION ONLY CHANGES THROUGH AN AUTHORED LINK. There is no implicit step-up
# anywhere in this file. On terrain the "link" is the existing ramp rule, which
# is delegated to MapGenerator rather than reimplemented -- a second opinion
# about whether a unit can walk up a cliff is precisely how vision and movement
# end up disagreeing.
#
# PERFORMANCE. Nodes are encoded as a single int rather than a Vector3i key.
# A 96x96 map is ~9000 terrain nodes before any structure, and this project has
# been bitten twice by per-cell costs (the 1221ms flow field, the 63ms fog), so
# the integer encoding and the flat-array heap in find_path() are deliberate
# from the start rather than a later rescue.

const LEVEL_MIN := -16
const LEVEL_MAX := 111
const LEVEL_SPAN := LEVEL_MAX - LEVEL_MIN + 1

# Terrain heights are small integers (0 low, 2 high in MapGenerator's encoding).
# Block levels are the same axis, so nothing needs converting.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var map_width: int = 0
var map_height: int = 0
var rules: BlockUnitRules

# Gate state by key. Missing reads as CLOSED -- an unconfigured gate should be
# shut, not silently open.
var gate_states: Dictionary = {}

# node id -> {"allowed": Array, "type": StringName, "state_key": StringName, "owner": StringName}
var _nodes: Dictionary = {}
# node id -> Array of link dictionaries leaving it. Indexed by endpoint rather
# than scanned: a map may hold dozens of structures, and walking every link for
# every expanded node would make pathfinding quadratic in structure count.
var _links_from: Dictionary = {}
# The same links indexed by DESTINATION. A flow field expands backwards from its
# goal and needs to know which nodes lead INTO a node -- which matters precisely
# where it is least obvious, at one-way drops.
var _links_to: Dictionary = {}
var _terrain: Node
var _placements: Array[Dictionary] = []
# Terrain height and cliff flags, flattened at build time.
#
# The ramp check ran up to four get_height() and two is_cliff_edge_cell() calls
# per expanded node, every one a cross-object call() into MapGenerator. At 11427
# nodes that dominated pathfinding -- A* measured 170-290ms on the citadel.
# MapGenerator learned this lesson once already; its own _height_edge_cache
# exists for the same reason.
var _terrain_height: PackedInt32Array = PackedInt32Array()
var _terrain_cliff: PackedByteArray = PackedByteArray()
# Vector2i -> sorted Array[int] of standable levels. See levels_at().
var _columns: Dictionary = {}

func _init(unit_classes: Dictionary) -> void:
	rules = BlockUnitRules.new(unit_classes)

# --- node identity ----------------------------------------------------------

func encode(cell: Vector2i, level: int) -> int:
	return ((level - LEVEL_MIN) * map_width + cell.x) * map_height + cell.y

func decode(node_id: int) -> Vector3i:
	var z: int = node_id % map_height
	var rest: int = node_id / map_height
	var x: int = rest % map_width
	var level: int = rest / map_width + LEVEL_MIN
	return Vector3i(x, level, z)

func node_cell(node_id: int) -> Vector2i:
	var decoded := decode(node_id)
	return Vector2i(decoded.x, decoded.z)

func node_level(node_id: int) -> int:
	return decode(node_id).y

func has_node(cell: Vector2i, level: int) -> bool:
	return _nodes.has(encode(cell, level))

func node_count() -> int:
	return _nodes.size()

# Every standable level in a column, low to high. This is the function that makes
# the whole thing worth doing: on flat ground it returns one level, under a
# wall-walk it returns two.
#
# Served from a per-column index rather than scanning the level range. Scanning
# was fine for a 12-cell gatehouse and quadratic nonsense for a 96x96 citadel:
# every click ran 110 x 110 x 128 level probes to find what a unit could stand
# on. The index is built as nodes are added and costs one dictionary lookup.
func levels_at(cell: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var stored: Variant = _columns.get(cell)
	if stored != null:
		# Copied through assign() rather than returned directly: a Dictionary
		# erases an array's element type on storage, so the stored value comes
		# back as an untyped Array and fails this function's own return type.
		out.assign(stored)
	return out

func _register_column(cell: Vector2i, level: int) -> void:
	if not _columns.has(cell):
		# Declared as a typed local before storing. `[] as Array[int]` yields an
		# UNTYPED array once it lands in a Dictionary, and levels_at() then fails
		# its own return type -- which is how this presented: a wall of
		# "expected Array[int]" errors and a demo that never drew.
		_columns[cell] = []
	var levels: Array = _columns[cell]
	if levels.has(level):
		return
	levels.append(level)
	levels.sort()

func _unregister_column(cell: Vector2i, level: int) -> void:
	if not _columns.has(cell):
		return
	var levels: Array = _columns[cell]
	levels.erase(level)
	if levels.is_empty():
		_columns.erase(cell)

# --- construction -----------------------------------------------------------

# One node per walkable terrain cell, at that cell's own height.
func build_from_terrain(terrain: Node) -> void:
	_terrain = terrain
	map_width = int(terrain.get("MAP_W"))
	map_height = int(terrain.get("MAP_H"))
	_nodes.clear()
	_links_from.clear()
	_links_to.clear()
	_columns.clear()
	_terrain_height.resize(map_width * map_height)
	_terrain_cliff.resize(map_width * map_height)
	for x in map_width:
		for y in map_height:
			var cell := Vector2i(x, y)
			if not bool(terrain.call("is_walkable_cell", cell)):
				continue
			var height: int = int(terrain.call("get_height", cell))
			var flat: int = x * map_height + y
			_terrain_height[flat] = height
			_terrain_cliff[flat] = 1 if bool(terrain.call("is_cliff_edge_cell", cell)) else 0
			_nodes[encode(cell, height)] = {
				"allowed": [],          # empty means every class
				"type": &"TERRAIN",
				"state_key": &"",
				"owner": &"terrain",
			}
			_register_column(cell, height)

# Stamps an authored structure into the lattice at a map cell.
#
# The structure's local (x, y, z) maps to world (origin.x + x, base_level + y,
# origin.y + z). Deliberately axis-aligned: rotation would need every authored
# link and region rotated with it, and getting that subtly wrong is worse than
# not offering it. Rotate the authored data instead, if a rotated variant is
# wanted.
func place_structure(definition: BlockStructureDefinition, origin: Vector2i, base_level: int, instance_id: StringName = &"") -> Dictionary:
	var placement := {
		"id": instance_id if instance_id != &"" else definition.id,
		"structure": definition.id,
		"origin": origin,
		"base_level": base_level,
		"nodes": [] as Array[int],
	}
	# Solid blocks remove the terrain surface they bury. Without this a unit
	# could stand on ground that now has a wall on top of it.
	for local in definition.solid_cells:
		var cell := origin + Vector2i(local.x, local.z)
		var level: int = base_level + local.y
		var buried: int = encode(cell, level)
		if _nodes.has(buried) and _nodes[buried]["owner"] == &"terrain":
			_nodes.erase(buried)
			_unregister_column(cell, level)

	for local in definition.nav_cells:
		var nav: Dictionary = definition.nav_cells[local]
		var cell := origin + Vector2i(local.x, local.z)
		if cell.x < 0 or cell.y < 0 or cell.x >= map_width or cell.y >= map_height:
			continue
		var node_level: int = base_level + local.y
		var node_id: int = encode(cell, node_level)
		_register_column(cell, node_level)
		_nodes[node_id] = {
			"allowed": nav.get("allowed", []),
			"type": nav.get("type", &"FLOOR"),
			"state_key": nav.get("state_key", &""),
			"owner": placement["id"],
		}
		(placement["nodes"] as Array[int]).append(node_id)

	for link in definition.links:
		var from_id: int = encode(origin + Vector2i(link["from"].x, link["from"].z), base_level + link["from"].y)
		var to_id: int = encode(origin + Vector2i(link["to"].x, link["to"].z), base_level + link["to"].y)
		var drop: int = absi(int(link["from"].y) - int(link["to"].y))
		_add_link(from_id, to_id, link, drop)
		# Bidirectional except one-way drops.
		if link["type"] != &"DROP_EDGE":
			_add_link(to_id, from_id, link, drop)

	_placements.append(placement)
	return placement

func _add_link(from_id: int, to_id: int, source: Dictionary, drop: int) -> void:
	if not _links_from.has(from_id):
		_links_from[from_id] = []
	if not _links_to.has(to_id):
		_links_to[to_id] = []
	_links_to[to_id].append({
		"to": from_id,
		"type": source["type"],
		"allowed": source.get("allowed", []),
		"width": int(source.get("width", 1)),
		"drop": drop,
	})
	_links_from[from_id].append({
		"to": to_id,
		"type": source["type"],
		"allowed": source.get("allowed", []),
		"width": int(source.get("width", 1)),
		"drop": drop,
	})

func placements() -> Array[Dictionary]:
	return _placements

# --- occupancy --------------------------------------------------------------

func node_admits(node_id: int, unit_class: StringName) -> bool:
	var node: Variant = _nodes.get(node_id)
	if node == null:
		return false
	var type: StringName = node["type"]
	if type == &"GATE":
		var key: StringName = node["state_key"]
		if key != &"" and not bool(gate_states.get(str(key), false)):
			return false
		if not rules.can_pass_open_gates(unit_class):
			return false
	elif type == &"LADDER" or type == &"CLIMB_POINT" or type == &"PORTAL" or type == &"BRIDGE_SOCKET":
		# Link endpoints and generation sockets are not standing room.
		return false
	var allowed: Array = node["allowed"]
	if not allowed.is_empty() and not allowed.has(str(unit_class)):
		return false
	return true

# Footprint included: a 2x2 heavy needs four contiguous admitting cells AT THE
# SAME LEVEL, which is what stops it walking a one-cell wall-walk without anyone
# authoring a rule against it.
func can_occupy(node_id: int, unit_class: StringName) -> bool:
	if rules.is_flying(unit_class):
		return _nodes.has(node_id)
	var footprint := rules.footprint_of(unit_class)
	if footprint == Vector2i.ONE:
		return node_admits(node_id, unit_class)
	var base := decode(node_id)
	for dx in footprint.x:
		for dz in footprint.y:
			if not node_admits(encode(Vector2i(base.x + dx, base.z + dz), base.y), unit_class):
				return false
	return true

# --- adjacency --------------------------------------------------------------

# Horizontal neighbours are same-level only. A change of elevation always goes
# through a link -- on terrain that is the ramp rule, delegated below.
func neighbours(node_id: int, unit_class: StringName, out: Array[int]) -> void:
	out.clear()
	var base := decode(node_id)
	var cell := Vector2i(base.x, base.z)
	for offset in NEIGHBOUR_OFFSETS:
		var next_cell := cell + offset
		var next_id: int = encode(next_cell, base.y)
		if not _nodes.has(next_id) or not can_occupy(next_id, unit_class):
			continue
		if not _terrain_step_allowed(node_id, next_id):
			continue
		out.append(next_id)
	# Terrain ramps: the one place a level change happens without an authored
	# structure link, because the terrain generator already authored it as a
	# ramp cell. Delegated to MapGenerator so movement and vision agree.
	_append_terrain_ramp_steps(base, cell, unit_class, out)
	for link in _links_from.get(node_id, []):
		if not rules.link_admits(link, unit_class):
			continue
		if not can_occupy(link["to"], unit_class):
			continue
		if not out.has(link["to"]):
			out.append(link["to"])

# Nodes that can step INTO `node_id`. Horizontal moves and terrain ramps are
# symmetric, so only links need the reverse index -- which is exactly where the
# asymmetry lives, at one-way drops.
func reverse_neighbours(node_id: int, unit_class: StringName, out: Array[int]) -> void:
	out.clear()
	var base := decode(node_id)
	var cell := Vector2i(base.x, base.z)
	for offset in NEIGHBOUR_OFFSETS:
		var previous_id: int = encode(cell + offset, base.y)
		if not _nodes.has(previous_id) or not can_occupy(previous_id, unit_class):
			continue
		out.append(previous_id)
	var scratch: Array[int] = []
	_append_terrain_ramp_steps(base, cell, unit_class, scratch)
	for candidate in scratch:
		if not out.has(candidate):
			out.append(candidate)
	for link in _links_to.get(node_id, []):
		if not rules.link_admits(link, unit_class):
			continue
		if not can_occupy(link["to"], unit_class):
			continue
		if not out.has(link["to"]):
			out.append(link["to"])

# The cost of one step. Shared by A* and the flow field so a route never
# disagrees with itself depending on which system found it.
func step_cost(from_id: int, to_id: int) -> float:
	return 1.0 + absf(float(node_level(to_id) - node_level(from_id))) * 1.5

# Two nodes owned by terrain must obey the terrain's own traversability rule.
# Structure nodes are governed by their authored regions instead.
func _terrain_step_allowed(from_id: int, to_id: int) -> bool:
	var from_node: Dictionary = _nodes[from_id]
	var to_node: Dictionary = _nodes[to_id]
	if from_node["owner"] != &"terrain" or to_node["owner"] != &"terrain":
		return true
	return true  # same level by construction; height changes go through ramps

# A terrain step that changes level, permitted only where MapGenerator says the
# height edge is ramped. is_cliff_edge_cell() IS that rule -- reusing it rather
# than reimplementing keeps one answer to "can a unit walk up here".
func _append_terrain_ramp_steps(base: Vector3i, cell: Vector2i, unit_class: StringName, out: Array[int]) -> void:
	if _terrain == null or not is_instance_valid(_terrain):
		return
	if not _nodes.has(encode(cell, base.y)) or _nodes[encode(cell, base.y)]["owner"] != &"terrain":
		return
	var here_flat: int = cell.x * map_height + cell.y
	if here_flat < 0 or here_flat >= _terrain_cliff.size() or _terrain_cliff[here_flat] == 1:
		return
	for offset in NEIGHBOUR_OFFSETS:
		var next_cell := cell + offset
		if next_cell.x < 0 or next_cell.y < 0 or next_cell.x >= map_width or next_cell.y >= map_height:
			continue
		var next_flat: int = next_cell.x * map_height + next_cell.y
		var next_height: int = _terrain_height[next_flat]
		if next_height == base.y:
			continue
		var next_id: int = encode(next_cell, next_height)
		if not _nodes.has(next_id) or _nodes[next_id]["owner"] != &"terrain":
			continue
		if _terrain_cliff[next_flat] == 1:
			continue
		if not can_occupy(next_id, unit_class):
			continue
		if not out.has(next_id):
			out.append(next_id)

# --- pathfinding ------------------------------------------------------------

# A* over the lattice. Returns world nodes as Vector3i(x, level, z), start and
# goal included, or an empty array when no route exists.
#
# The heap costs are float64 on purpose. The flow field looked twice as fast in
# float32 while silently reaching 3384 cells instead of 7017, and that lesson
# applies to any priority queue keyed on accumulated distance.
func find_path(from_cell: Vector2i, from_level: int, to_cell: Vector2i, to_level: int, unit_class: StringName) -> Array[Vector3i]:
	var start: int = encode(from_cell, from_level)
	var goal: int = encode(to_cell, to_level)
	var path: Array[Vector3i] = []
	if not _nodes.has(start) or not _nodes.has(goal):
		return path
	if not can_occupy(start, unit_class) or not can_occupy(goal, unit_class):
		return path
	if start == goal:
		path.append(decode(start))
		return path
	# Flying ignores ground navigation entirely, so its "path" is the direct
	# hop; asking A* to walk a graph it does not obey would be theatre.
	if rules.is_flying(unit_class):
		path.append(decode(start))
		path.append(decode(goal))
		return path

	var came_from := {}
	var cost_so_far := {start: 0.0}
	var heap_nodes := PackedInt32Array()
	var heap_costs := PackedFloat64Array()
	_heap_push(heap_nodes, heap_costs, start, 0.0)
	var scratch: Array[int] = []
	while heap_nodes.size() > 0:
		var current: int = _heap_pop(heap_nodes, heap_costs)
		if current == goal:
			break
		neighbours(current, unit_class, scratch)
		var current_cost: float = cost_so_far[current]
		for next in scratch:
			# Level changes cost more than a flat step, so a route that stays on
			# one floor is preferred over one that pointlessly climbs.
			var new_cost: float = current_cost + step_cost(current, next)
			if cost_so_far.has(next) and new_cost >= float(cost_so_far[next]):
				continue
			cost_so_far[next] = new_cost
			came_from[next] = current
			_heap_push(heap_nodes, heap_costs, next, new_cost + _heuristic(next, goal))
	if not came_from.has(goal):
		return path
	var node: int = goal
	while node != start:
		path.append(decode(node))
		node = came_from[node]
	path.append(decode(start))
	path.reverse()
	return path

func _heuristic(node_id: int, goal_id: int) -> float:
	var a := decode(node_id)
	var b := decode(goal_id)
	return float(absi(a.x - b.x) + absi(a.z - b.z) + absi(a.y - b.y))

func _heap_push(nodes: PackedInt32Array, costs: PackedFloat64Array, node_id: int, cost: float) -> void:
	nodes.append(node_id)
	costs.append(cost)
	var index := nodes.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if costs[parent] <= costs[index]:
			break
		_heap_swap(nodes, costs, index, parent)
		index = parent

func _heap_pop(nodes: PackedInt32Array, costs: PackedFloat64Array) -> int:
	var top: int = nodes[0]
	var last := nodes.size() - 1
	nodes[0] = nodes[last]
	costs[0] = costs[last]
	nodes.remove_at(last)
	costs.remove_at(last)
	var index := 0
	var size := nodes.size()
	while true:
		var left: int = index * 2 + 1
		var right: int = left + 1
		var smallest := index
		if left < size and costs[left] < costs[smallest]:
			smallest = left
		if right < size and costs[right] < costs[smallest]:
			smallest = right
		if smallest == index:
			break
		_heap_swap(nodes, costs, index, smallest)
		index = smallest
	return top

func _heap_swap(nodes: PackedInt32Array, costs: PackedFloat64Array, a: int, b: int) -> void:
	var node_tmp: int = nodes[a]
	nodes[a] = nodes[b]
	nodes[b] = node_tmp
	var cost_tmp: float = costs[a]
	costs[a] = costs[b]
	costs[b] = cost_tmp
