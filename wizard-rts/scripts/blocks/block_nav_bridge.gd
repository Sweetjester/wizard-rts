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

var world: BlockNavWorld
var terrain: Node
var library: BlockStructureLibrary

func _ready() -> void:
	terrain = get_node_or_null(map_path)
	library = BlockStructureLibrary.load_default()
	if terrain == null or library.unit_classes.is_empty():
		return
	rebuild()

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
