class_name BlockFlowField
extends RefCounted

# One shared route to a goal, for every unit of a class.
#
# WHY. A* answers "how do I get from here to there" for one unit. A wave of
# three hundred units heading for the same gate asks that same question three
# hundred times, and each answer costs a full search. A flow field inverts it:
# expand once BACKWARDS from the goal, and every node in the lattice records
# which neighbour to step to. After that a unit's move is a dictionary lookup.
#
# This is the same trade the 2D game already made for wave movement (see the
# 2026-08-09 flow-field entry in the Decisions Log). The lattice version differs
# in one respect worth stating: it expands over reverse_neighbours() rather than
# assuming edges are symmetric, because authored links need not be. A one-way
# drop is walkable downward and not upward, and a field built on the assumption
# of symmetry would happily route units up a cliff they can only fall down.
#
# COST. One Dijkstra over the reachable set, cut off by `max_cost`. Rebuild when
# the goal moves or the lattice changes (a gate opening changes reachability);
# a field is otherwise valid indefinitely, because the lattice is static.
#
# The heap costs are PackedFloat64Array on purpose. Float32 made the 2D flow
# field look twice as fast while silently reaching 3384 cells instead of 7017,
# and accumulated path cost is exactly the quantity that exposes it.

var goal: int = -1
var unit_class: StringName = &"infantry"
# node id -> the neighbour to step to next. Absent means unreachable.
var _next: Dictionary = {}
# node id -> accumulated cost to the goal, for callers that want to compare
# routes without walking them.
var _cost: Dictionary = {}

func build(world: BlockNavWorld, goal_cell: Vector2i, goal_level: int,
		field_class: StringName, max_cost: float = 1e9) -> bool:
	unit_class = field_class
	_next.clear()
	_cost.clear()
	goal = world.encode(goal_cell, goal_level)
	if not world.has_node(goal_cell, goal_level):
		return false
	if not world.can_occupy(goal, unit_class):
		return false
	# Flying ignores ground navigation, so a field over the walk graph would
	# describe a route it does not take. Callers get a single-hop answer instead.
	if world.rules.is_flying(unit_class):
		return true

	_cost[goal] = 0.0
	var heap_nodes := PackedInt32Array()
	var heap_costs := PackedFloat64Array()
	_push(heap_nodes, heap_costs, goal, 0.0)
	var scratch: Array[int] = []
	while heap_nodes.size() > 0:
		var current_cost: float = heap_costs[0]
		var current: int = _pop(heap_nodes, heap_costs)
		# A stale heap entry, superseded by a cheaper route found later.
		if current_cost > float(_cost.get(current, 1e30)):
			continue
		if current_cost > max_cost:
			continue
		world.reverse_neighbours(current, unit_class, scratch)
		for previous in scratch:
			var next_cost: float = current_cost + world.step_cost(previous, current)
			if next_cost >= float(_cost.get(previous, 1e30)):
				continue
			_cost[previous] = next_cost
			# `previous` steps to `current` to make progress toward the goal.
			_next[previous] = current
			_push(heap_nodes, heap_costs, previous, next_cost)
	return true

func is_reachable(world: BlockNavWorld, cell: Vector2i, level: int) -> bool:
	if world.rules.is_flying(unit_class):
		return world.has_node(cell, level)
	var node: int = world.encode(cell, level)
	return node == goal or _next.has(node)

func cost_at(world: BlockNavWorld, cell: Vector2i, level: int) -> float:
	return float(_cost.get(world.encode(cell, level), INF))

# The next node a unit at this position should step to, or -1 when it is at the
# goal or cannot reach it.
func next_node(world: BlockNavWorld, cell: Vector2i, level: int) -> int:
	if world.rules.is_flying(unit_class):
		var here: int = world.encode(cell, level)
		return -1 if here == goal else goal
	return int(_next.get(world.encode(cell, level), -1))

# Walks the field to produce a concrete path, for callers that want one -- unit
# movement, or a debug line. Guarded against cycles, which a correct field
# cannot contain but a stale one could.
func path_from(world: BlockNavWorld, cell: Vector2i, level: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var node: int = world.encode(cell, level)
	if world.rules.is_flying(unit_class):
		path.append(world.decode(node))
		if node != goal:
			path.append(world.decode(goal))
		return path
	if node != goal and not _next.has(node):
		return path
	path.append(world.decode(node))
	var guard := 0
	while node != goal:
		var step: int = int(_next.get(node, -1))
		if step < 0:
			return [] as Array[Vector3i]
		node = step
		path.append(world.decode(node))
		guard += 1
		if guard > _next.size() + 4:
			push_error("BlockFlowField.path_from walked a cycle -- the field is stale")
			return [] as Array[Vector3i]
	return path

func covered_nodes() -> int:
	return _next.size()

# --- heap -------------------------------------------------------------------

func _push(nodes: PackedInt32Array, costs: PackedFloat64Array, node_id: int, cost: float) -> void:
	nodes.append(node_id)
	costs.append(cost)
	var index := nodes.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if costs[parent] <= costs[index]:
			break
		_swap(nodes, costs, index, parent)
		index = parent

func _pop(nodes: PackedInt32Array, costs: PackedFloat64Array) -> int:
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
		_swap(nodes, costs, index, smallest)
		index = smallest
	return top

func _swap(nodes: PackedInt32Array, costs: PackedFloat64Array, a: int, b: int) -> void:
	var node_tmp: int = nodes[a]
	nodes[a] = nodes[b]
	nodes[b] = node_tmp
	var cost_tmp: float = costs[a]
	costs[a] = costs[b]
	costs[b] = cost_tmp
