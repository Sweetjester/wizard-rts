class_name BlockStructureNavigation
extends RefCounted

# Traversal over an authored block structure, per unit class.
#
# Nothing here reads geometry. Reachability is decided by three authored things
# and nothing else: which cells are nav cells, which classes each nav region and
# link permits, and the class's own capability flags. That is the spec's
# non-negotiable rule, and it is what makes a heavy unit's inability to use
# stairs a design decision rather than an emergent accident.
#
# Movement comes in two kinds:
#   * WALKING -- between orthogonally adjacent nav cells on the same level.
#   * LINKS   -- authored transitions: stairs, ramps, ladders, climb points,
#     portals and one-way drops. A link is the ONLY way to change elevation.
#     There is no implicit step-up, because an implicit rule is exactly the kind
#     of geometry-derived navigation the spec forbids.
#
# Footprint matters: a 2x2 heavy or 3x3 siege unit needs that many contiguous
# permitted cells to stand anywhere, so a corridor one cell wide excludes them
# without anyone authoring a rule against it.

const NEIGHBOURS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var definition: BlockStructureDefinition
var unit_classes: Dictionary = {}
var nav_types: Dictionary = {}
# Class capabilities come from BlockUnitRules rather than being resolved here,
# so this and BlockNavWorld cannot drift apart. A unit that could climb a
# structure's stairs in isolation but not once it was placed on a map would be
# a genuinely horrible bug to track down.
var rules: BlockUnitRules
# Gate state by key, e.g. {"gate_open": true}. Missing keys read as closed, so a
# structure with an unset gate is secure rather than accidentally open.
var gate_states: Dictionary = {}

func _init(structure: BlockStructureDefinition, classes: Dictionary, types: Dictionary) -> void:
	definition = structure
	unit_classes = classes
	nav_types = types
	rules = BlockUnitRules.new(classes)

func class_data(unit_class: StringName) -> Dictionary:
	return rules.data_for(unit_class)

func is_flying(unit_class: StringName) -> bool:
	return rules.is_flying(unit_class)

func footprint_of(unit_class: StringName) -> Vector2i:
	return rules.footprint_of(unit_class)

# --- occupancy --------------------------------------------------------------

# Whether a single cell admits the class, ignoring footprint. A GATE cell is
# conditional on its state key: closing the gate removes the connection rather
# than merely hiding it, which is the behaviour the spec calls for.
func cell_admits(cell: Vector3i, unit_class: StringName) -> bool:
	var nav := definition.nav_at(cell)
	if nav.is_empty():
		return false
	var type := StringName(nav.get("type", &"FLOOR"))
	var type_data: Dictionary = nav_types.get(str(type), {})
	# Link-only cells (ladders, climb points, portals) are endpoints, never
	# standing room, and generation sockets are attachment points rather than
	# floor -- spec rule 9.
	if bool(type_data.get("link_only", false)) or bool(type_data.get("generation_socket", false)):
		return false
	if type_data.has("conditional_walkable"):
		var state_key := StringName(nav.get("state_key", &""))
		if state_key != &"" and not bool(gate_states.get(str(state_key), false)):
			return false
		if not bool(class_data(unit_class).get("can_pass_open_gates", true)):
			return false
	elif not bool(type_data.get("walkable", false)):
		return false
	var allowed: Array = nav.get("allowed", [])
	# An empty allowed list means the cell came from a block's own nav type
	# rather than an authored region, so no class restriction was expressed.
	if not allowed.is_empty() and not allowed.has(str(unit_class)):
		return false
	return true

# Whether the class can actually STAND here, footprint included. Spec rule 8:
# heavy and siege need enough contiguous width and depth to traverse.
func can_occupy(cell: Vector3i, unit_class: StringName) -> bool:
	if is_flying(unit_class):
		return true
	var footprint := footprint_of(unit_class)
	for dx in footprint.x:
		for dz in footprint.y:
			if not cell_admits(cell + Vector3i(dx, 0, dz), unit_class):
				return false
	return true

# --- links ------------------------------------------------------------------

func link_admits(link: Dictionary, unit_class: StringName) -> bool:
	return rules.link_admits(link, unit_class)

# --- reachability -----------------------------------------------------------

# Breadth-first over walk steps and authored links. Returns the set of cells the
# class can reach from `start`, as a Dictionary used as a set.
func reachable_from(start: Vector3i, unit_class: StringName) -> Dictionary:
	var seen := {}
	if is_flying(unit_class):
		# Flying ignores ground navigation entirely (spec rule: flying units
		# ignore all ground traversal), so every nav cell is reachable and the
		# walk graph is irrelevant.
		for cell in definition.nav_cells:
			seen[cell] = true
		seen[start] = true
		return seen
	if not can_occupy(start, unit_class):
		return seen
	var frontier: Array[Vector3i] = [start]
	seen[start] = true
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_back()
		for offset in NEIGHBOURS:
			var next: Vector3i = cell + offset
			if seen.has(next) or not can_occupy(next, unit_class):
				continue
			seen[next] = true
			frontier.append(next)
		for link in definition.links:
			if not link_admits(link, unit_class):
				continue
			# Links are bidirectional except one-way drops.
			if link["from"] == cell and not seen.has(link["to"]) and can_occupy(link["to"], unit_class):
				seen[link["to"]] = true
				frontier.append(link["to"])
			elif link["to"] == cell and link["type"] != &"DROP_EDGE" \
					and not seen.has(link["from"]) and can_occupy(link["from"], unit_class):
				seen[link["from"]] = true
				frontier.append(link["from"])
	return seen

func can_reach(start: Vector3i, goal: Vector3i, unit_class: StringName) -> bool:
	return reachable_from(start, unit_class).has(goal)

# Any cell of the named nav region -- the readable way for a test or a game
# system to ask "can this unit get onto the wall-walk" without hardcoding a cell.
func region_cells(region_id: StringName) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for cell in definition.nav_cells:
		if definition.nav_cells[cell].get("region_id", &"") == region_id:
			cells.append(cell)
	cells.sort()
	return cells

func can_reach_region(start: Vector3i, region_id: StringName, unit_class: StringName) -> bool:
	var reached := reachable_from(start, unit_class)
	for cell in region_cells(region_id):
		if reached.has(cell):
			return true
	return false
