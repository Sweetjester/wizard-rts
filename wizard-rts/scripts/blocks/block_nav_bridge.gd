class_name BlockNavBridge
extends Node

# Connects the block elevation lattice to the live game's units.
#
# The lattice speaks in nodes -- (cell.x, level, cell.z). RTSUnit speaks in
# world positions. This is the only place those two vocabularies meet, which
# keeps BlockNavWorld free of any dependency on the game's units and keeps
# RTSUnit free of any dependency on the lattice. Delete this node and both sides
# still work; they just stop talking.
#
# The terrain contract turned out to be three calls -- is_walkable_cell,
# get_height, is_cliff_edge_cell -- all of which MapGenerator already implements.
# So this points at the real map rather than a special one.

@export var map_path: NodePath = NodePath("../MapGenerator")
# Structures dropped onto the generated map at startup. Experimental: this is
# how block structures reach a real run at all today, standing in for proper
# procedural placement inside MapGenerator.
@export var auto_place: Array[StringName] = [
	&"fortress_gatehouse_02_walkable",
	&"broken_watchfort_01",
]

signal structures_placed(placements: Array)

# Far enough from the wizard tower not to sit inside the player's build radius
# (14 cells), close enough that they are found rather than theoretical.
const MIN_DISTANCE_FROM_BASE := 16.0

var world: BlockNavWorld
var terrain: Node
var library: BlockStructureLibrary

var _build_attempts := 0

func _ready() -> void:
	terrain = get_node_or_null(map_path)
	library = BlockStructureLibrary.load_default()
	if terrain == null or library.unit_classes.is_empty():
		return
	# Map generation finishes after _ready in some boot paths, and a lattice
	# built from an empty grid would be silently empty rather than wrong-looking.
	# Retried deferred, the way ImpassableOverlay handles the same ordering.
	call_deferred("_build_when_map_ready")

func _build_when_map_ready() -> void:
	if terrain == null or not is_instance_valid(terrain):
		return
	var grid: Variant = terrain.get("grid")
	if grid == null or (grid is Array and (grid as Array).is_empty()):
		_build_attempts += 1
		if _build_attempts < 240:
			call_deferred("_build_when_map_ready")
		return
	rebuild()
	_auto_place()

func _auto_place() -> void:
	if world == null or auto_place.is_empty():
		return
	var taken: Array[Rect2i] = []
	var placed: Array = []
	for structure_id in auto_place:
		var definition := library.get_definition(structure_id)
		if definition == null:
			continue
		var size := Vector2i(definition.dimensions.x, definition.dimensions.z)
		var origin := find_flat_site(size, taken)
		if origin == Vector2i(-1, -1):
			push_warning("[BlockNavBridge] no flat site for %s on this map" % structure_id)
			continue
		if place_and_block(structure_id, origin, structure_id):
			taken.append(Rect2i(origin - Vector2i(1, 1), size + Vector2i(2, 2)))
			placed.append({"id": structure_id, "origin": origin,
				"base_level": int(terrain.call("get_height", origin))})
	if not placed.is_empty():
		structures_placed.emit(placed)

# Rebuilt from terrain, then structures are stamped in. Called once at startup
# and again if the map regenerates -- not per frame; the lattice is static
# except when a structure is placed or destroyed.
func rebuild() -> void:
	if terrain == null or not is_instance_valid(terrain):
		return
	world = BlockNavWorld.new(library.unit_classes)
	world.build_from_terrain(terrain)
	world.gate_states = {"gate_open": true}

func place(structure_id: StringName, origin: Vector2i, instance_id: StringName = &"") -> bool:
	if world == null:
		return false
	var definition := library.get_definition(structure_id)
	if definition == null:
		return false
	# Base level from the terrain under the origin, so a structure sits ON the
	# ground rather than being pinned to level 0 and half-buried where it rises.
	var base_level: int = int(terrain.call("get_height", origin))
	world.place_structure(definition, origin, base_level, instance_id)
	return true

# --- orders -----------------------------------------------------------------

# The level a unit is currently on. Falls back to the terrain height under it,
# which is correct for any unit that has never been given a lattice path.
func level_of(unit: Node2D) -> int:
	var stored: Variant = unit.get("nav_level")
	if stored != null and int(stored) != 0:
		return int(stored)
	return int(terrain.call("get_height", terrain.call("world_to_cell", unit.global_position)))

# Routes a unit to a goal cell and level, and hands it the path. Returns false
# when no route exists -- a heavy asked to reach a wall-walk, or anything asked
# to cross a closed gate -- so the caller can say so rather than watching a unit
# stand still for no visible reason.
func order_to(unit: Node2D, goal_cell: Vector2i, goal_level: int, unit_class: StringName) -> bool:
	if world == null or not unit.has_method("follow_block_path"):
		return false
	var from_cell: Vector2i = terrain.call("world_to_cell", unit.global_position)
	var nodes := world.find_path(from_cell, level_of(unit), goal_cell, goal_level, unit_class)
	if nodes.size() < 2:
		return false
	var points: Array[Vector2] = []
	var levels: Array[int] = []
	for node in nodes:
		points.append(terrain.call("cell_to_world", Vector2i(node.x, node.z)))
		levels.append(node.y)
	unit.call("follow_block_path", points, levels)
	return true

func can_reach(unit: Node2D, goal_cell: Vector2i, goal_level: int, unit_class: StringName) -> bool:
	if world == null:
		return false
	var from_cell: Vector2i = terrain.call("world_to_cell", unit.global_position)
	return world.find_path(from_cell, level_of(unit), goal_cell, goal_level, unit_class).size() >= 2

# Standable levels in a column, for a caller deciding where to send something.
func levels_at(cell: Vector2i) -> Array[int]:
	return [] if world == null else world.levels_at(cell)

# Whether a column is worth routing through the lattice at all. One level is
# ordinary ground, and ordinary ground is what the existing 2D pathfinder is
# for -- so this is the check that keeps flat-map movement completely untouched.
func is_multi_level(cell: Vector2i) -> bool:
	return levels_at(cell).size() > 1

# Which block class a game unit moves as.
#
# Deliberately crude: the game's units have no block class of their own, and
# inventing a full mapping before anything depends on it would be guessing. A
# unit that ignores terrain flies; everything else walks as infantry. When the
# roster needs heavies and climbers this is the one function to extend.
func class_for(unit: Node2D) -> StringName:
	if bool(unit.get("ignores_terrain")):
		return &"flying"
	return &"infantry"

# Right-click behaviour for a multi-level column: send the unit to the HIGHEST
# level there that it can both stand on and reach, falling back down the stack.
#
# That makes clicking a gatehouse send a unit up onto it, which is the point of
# the system being visible at all. It does mean you cannot click the ground
# *underneath* a wall-walk, which is a real limitation and wants a proper
# level-picking gesture (a modifier, or picking from the camera ray) before this
# is anything more than demo-grade.
func order_to_column(unit: Node2D, cell: Vector2i) -> bool:
	if world == null:
		return false
	var unit_class := class_for(unit)
	var levels := levels_at(cell)
	levels.reverse()
	for level in levels:
		if not world.can_occupy(world.encode(cell, level), unit_class):
			continue
		if order_to(unit, cell, level, unit_class):
			return true
	return false

# --- placement into a live map ----------------------------------------------

# Finds a flat, walkable, unoccupied site big enough for a structure. Returns
# Vector2i(-1, -1) when the generated map has nowhere to put one, which is a
# normal outcome on a cramped map rather than an error.
func find_flat_site(size: Vector2i, taken: Array[Rect2i]) -> Vector2i:
	if terrain == null:
		return Vector2i(-1, -1)
	var width := int(terrain.get("MAP_W"))
	var height := int(terrain.get("MAP_H"))
	# Searched outward from the PLAYER'S BASE, not from (2, 2) and not from the
	# map centre. Scanning from the origin put structures in the far corner;
	# scanning from the centre put them 50 cells away in permanent fog. Either
	# way nothing ever walks past them, which for a landmark system is the one
	# outcome that makes it pointless.
	#
	# A minimum distance keeps them off the base itself -- close enough to reach
	# and to matter, far enough not to be part of the player's build space.
	var centre := _player_anchor_cell(Vector2i(width / 2, height / 2))
	var candidates: Array[Vector2i] = []
	for x in range(2, width - size.x - 2, 2):
		for y in range(2, height - size.y - 2, 2):
			candidates.append(Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - centre).length_squared() < (b - centre).length_squared())
	for origin in candidates:
		if (origin + size / 2 - centre).length() < MIN_DISTANCE_FROM_BASE:
			continue
		var rect := Rect2i(origin - Vector2i(1, 1), size + Vector2i(2, 2))
		var overlaps := false
		for other in taken:
			if rect.intersects(other):
				overlaps = true
				break
		if overlaps:
			continue
		if _is_flat_site(origin, size):
			return origin
	return Vector2i(-1, -1)

# The player's tower, if one exists yet. Structures are placed relative to it so
# they sit in the part of the map the player actually moves through.
func _player_anchor_cell(fallback: Vector2i) -> Vector2i:
	if not is_inside_tree():
		return fallback
	for structure in get_tree().get_nodes_in_group("structures"):
		if not is_instance_valid(structure) or not (structure is Node2D):
			continue
		if str(structure.get("archetype")) != "wizard_tower":
			continue
		if int(structure.get("owner_player_id")) != 1:
			continue
		return terrain.call("world_to_cell", (structure as Node2D).global_position)
	return fallback

func _is_flat_site(origin: Vector2i, size: Vector2i) -> bool:
	var level: int = int(terrain.call("get_height", origin))
	for dx in size.x:
		for dy in size.y:
			var cell := origin + Vector2i(dx, dy)
			if not bool(terrain.call("is_walkable_cell", cell)):
				return false
			if int(terrain.call("get_height", cell)) != level:
				return false
	return true

# Places a structure and tells the 2D simulation about it.
#
# The second half matters as much as the first: the 2D pathfinder knows nothing
# about levels, so without registering the ground-level footprint as a dynamic
# blocker, ordinary 2D units would walk straight through the walls of a building
# that is solid in the lattice. Only the ground level is registered -- a
# wall-walk six levels up must not block anything on the floor.
func place_and_block(structure_id: StringName, origin: Vector2i, instance_id: StringName = &"") -> bool:
	if not place(structure_id, origin, instance_id):
		return false
	var definition := library.get_definition(structure_id)
	var base_level: int = int(terrain.call("get_height", origin))
	var ground_cells: Array[Vector2i] = []
	for local in definition.solid_cells:
		if base_level + local.y != base_level:
			continue
		var cell := origin + Vector2i(local.x, local.z)
		# A cell the structure also declares as standable at ground level is a
		# doorway, not a wall -- blocking it would seal the gate passage shut.
		if world.node_admits(world.encode(cell, base_level), &"infantry"):
			continue
		if not ground_cells.has(cell):
			ground_cells.append(cell)
	if terrain.has_method("add_dynamic_blockers"):
		terrain.call("add_dynamic_blockers", ground_cells)
	return true
