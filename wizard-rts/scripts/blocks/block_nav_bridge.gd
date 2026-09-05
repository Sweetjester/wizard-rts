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
# Structures dropped onto the generated map at startup, in ADDITION to any a
# plot asks for by name.
#
# Empty by default. This used to carry two test structures, which meant every
# real game -- every map type, every seed -- had a gatehouse and a ruined
# watchfort dropped into it by a debug affordance that was never meant to ship.
# They landed wherever find_flat_site happened to like, unrelated to the plots
# the map generator had actually laid out, which is why the map read as having
# random buildings scattered through it.
#
# Structures now reach a map the way everything else does: a plot asks for one.
@export var auto_place: Array[StringName] = []

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
	# Waits for generation to SAY it is finished.
	#
	# This used to poll for `grid` being non-empty. That was fine when the whole
	# map was built inside one _ready(), but generation is spread across frames
	# now: the grid exists from phase 3 while terrain HEIGHTS are not computed
	# until phase 16. Polling the grid therefore built the lattice from
	# half-initialised height arrays and segfaulted the engine outright -- not a
	# script error, a hard crash.
	if terrain.has_signal("map_generated"):
		terrain.map_generated.connect(func(_summary: Dictionary) -> void:
			_build_when_map_ready()
		)
	call_deferred("_build_when_map_ready")

var _built := false

func _build_when_map_ready() -> void:
	if _built or terrain == null or not is_instance_valid(terrain):
		return
	# generation_complete is set only after the final phase, unlike the grid,
	# which appears at phase 3 with no heights behind it.
	# No self-deferred retry: map_generated calls this when the map is real, and
	# a deferred call that re-defers itself spins inside one frame's flush.
	if not bool(terrain.get("generation_complete")):
		return
	_built = true
	rebuild()
	_auto_place()

func _auto_place() -> void:
	if world == null:
		return
	var taken: Array[Rect2i] = []
	var placed: Array = []
	# Plots that ASK for a block structure are honoured first and exactly.
	#
	# A map-generated plot has already reserved its ground, routed roads to it
	# and kept other content clear of it. Searching for a flat site instead
	# would put the structure somewhere the map knows nothing about, which is
	# the difference between a landmark the level is built around and a building
	# dropped on top of one.
	for plot in terrain.get("plots"):
		var structure_id := StringName(plot.get("block_structure", &""))
		if structure_id == &"":
			continue
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.size.x <= 0:
			continue
		if place_and_block(structure_id, rect.position, structure_id):
			taken.append(_expanded(rect, 2))
			placed.append({"id": structure_id, "origin": rect.position,
				"base_level": int(terrain.call("get_height", rect.position))})
	if auto_place.is_empty():
		if not placed.is_empty():
			structures_placed.emit(placed)
		return
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
	# Each structure names its own gate state keys and says which start open.
	#
	# This used to be the single hardcoded key {"gate_open": true}, so every
	# authored key read as absent -- and absent means closed. The laboratory
	# declares lab_entry_open with default TRUE and its front door was shut
	# anyway: units could reach the service yard round the side but not the
	# muster hall, which looks like broken pathfinding and is actually a locked
	# door. structure_library already exposed these defaults; nothing read them.
	world.gate_states = {"gate_open": true}
	for structure_id in library.structure_ids():
		for key in library.gate_defaults_for(structure_id):
			world.gate_states[str(key)] = bool(library.gate_defaults_for(structure_id)[key])

func place(structure_id: StringName, origin: Vector2i, instance_id: StringName = &"", rotation_steps: int = 0) -> bool:
	if world == null:
		return false
	var definition := library.get_definition(structure_id)
	if definition == null:
		return false
	# Base level from the terrain under the origin, so a structure sits ON the
	# ground rather than being pinned to level 0 and half-buried where it rises.
	var base_level: int = int(terrain.call("get_height", origin))
	world.place_structure(definition, origin, base_level, instance_id, rotation_steps)
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
# Whether an order to this column has to go through the lattice.
#
# The test used to be is_multi_level() -- "does this column have more than one
# floor". That misses the most ordinary case there is: the inside of a building.
# A structure buries the terrain node under its footprint, so its interior floor
# is the ONLY level in that column, and a single-level column looked exactly
# like open ground. Right-clicking into the laboratory therefore fell through to
# the flat 2D pathfinder, which has no idea the floor is a level up -- the demo
# worked only because it calls the lattice directly and never asks this.
#
# So the question is "is this ordinary ground?" rather than "how many floors?".
# A column is ordinary if it has exactly one standable level and that level is
# the terrain surface. Anything else -- stacked floors, or a single floor raised
# onto a plinth -- is the lattice's business.
func needs_block_routing(cell: Vector2i) -> bool:
	if world == null or terrain == null:
		return false
	var levels := levels_at(cell)
	if levels.is_empty():
		return false
	if levels.size() > 1:
		return true
	return int(levels[0]) != int(terrain.call("get_height", cell))

# What a unit is standing on, for gameplay rather than for pathing.
#
# Returns {} on open ground, or {region, structure, height} when the unit is on
# a structure. `height` is how far above the terrain the cell sits, which is the
# thing that makes a position a VANTAGE: a gate tunnel at ground level is inside
# a building but is not a firing position; a wall-walk eighteen levels up is.
#
# Deliberately derived from elevation rather than from an authored "is_vantage"
# flag. Every structure already says where its floors are and how high they are;
# asking authors to also label which of them count would be a second source of
# truth that can disagree with the first.
func vantage_at(cell: Vector2i, level: int) -> Dictionary:
	if world == null or terrain == null:
		return {}
	if not world.is_structure_node(cell, level):
		return {}
	var ground: int = int(terrain.call("get_height", cell))
	return {
		"region": world.region_at(cell, level),
		"height": maxi(0, level - ground),
	}

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
func _expanded(rect: Rect2i, margin: int) -> Rect2i:
	return Rect2i(rect.position - Vector2i(margin, margin), rect.size + Vector2i(margin, margin) * 2)

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

# Places a structure DURING PLAY, as opposed to during map generation.
#
# Announces it on the same signal map placement uses, so everything that listens
# -- the 3D view builds its geometry, the garrison inspects it -- reacts to a
# building the player raised exactly as it reacts to one the map came with.
# Without the announcement the structure exists in the lattice and in 2D
# collision but is invisible, which is a uniquely confusing way to be wrong.
func place_runtime_structure(structure_id: StringName, origin: Vector2i, instance_id: StringName = &"", rotation_steps: int = 0) -> bool:
	if not place_and_block(structure_id, origin, instance_id, rotation_steps):
		return false
	# A building the player just paid for has its doors open.
	#
	# Authored gate defaults describe a structure FOUND on the map -- the
	# citadel's gate is shut because a garrison shut it, and the observation
	# tower's is shut because it is a ruin until someone opens it. Those defaults
	# are exactly wrong for something you constructed: the tower built fine, sat
	# there looking finished, and only 2 of its 15 rooms could be walked to,
	# because its own front door was locked against its owner.
	for key in library.gate_defaults_for(structure_id):
		world.gate_states[str(key)] = true
	structures_placed.emit([{
		"id": structure_id,
		"origin": origin,
		"base_level": int(terrain.call("get_height", origin)),
		"rotation_steps": rotation_steps,
	}])
	return true

# Places a structure and tells the 2D simulation about it.
#
# The second half matters as much as the first: the 2D pathfinder knows nothing
# about levels, so without registering the ground-level footprint as a dynamic
# blocker, ordinary 2D units would walk straight through the walls of a building
# that is solid in the lattice. Only the ground level is registered -- a
# wall-walk six levels up must not block anything on the floor.
func place_and_block(structure_id: StringName, origin: Vector2i, instance_id: StringName = &"", rotation_steps: int = 0) -> bool:
	if not place(structure_id, origin, instance_id, rotation_steps):
		return false
	# Blockers come from the ROTATED definition, or a turned building would keep
	# the walls of its unturned self.
	var definition := library.get_definition(structure_id).rotated(rotation_steps)
	var ground_cells := _ground_blocker_columns(definition)
	for i in ground_cells.size():
		ground_cells[i] = origin + ground_cells[i]
	if terrain.has_method("add_dynamic_blockers"):
		terrain.call("add_dynamic_blockers", ground_cells)
	return true

# Which columns of a structure are walls to a 2D unit, and which are floor.
#
# The old rule was "any column with a block at local level 0", on the assumption
# that level 0 is where a structure meets the ground. That holds for a gatehouse
# sitting directly on the terrain. It is badly wrong for anything built on a
# plinth: the citadel rests on a two-block foundation slab that spans its whole
# 96x96 footprint, so EVERY column has a block at level 0 and the entire
# fortress -- courtyards, wards, and the gate tunnel itself -- was registered as
# solid. A quarter of the march was a brick that no 2D unit could enter or path
# around sensibly, which is what "pathing is weird" actually was.
#
# So the question is asked at the structure's OWN ground floor: the lowest level
# it declares as standable. At that level a wall has mass and a courtyard has
# nav, which is exactly the distinction wanted. Columns with neither -- the
# apron of bare slab outside the walls -- stay walkable, because you should be
# able to walk up to a fortress.
#
# Verified not to change the structures that were already correct: the gatehouse
# and watchfort block the same 42 and 40 columns as before.
func _ground_blocker_columns(definition: BlockStructureDefinition) -> Array[Vector2i]:
	var ground_level := 2147483647
	for local in definition.nav_cells:
		ground_level = mini(ground_level, local.y)
	if ground_level == 2147483647:
		# No declared standing room anywhere: a solid prop, not a building.
		ground_level = 0
	# The ground STOREY, not a single level: the lowest standable level and the
	# one directly above it. The splicing laboratory's lowest nav is a road strip
	# at level 0 while its whole interior is at level 1, so asking only about the
	# lowest level walled off the entire building -- 73% of its footprint solid,
	# with the muster hall and the aisles on the wrong side of it. A one-level
	# band opens that up (73% -> 24%) and leaves the structures that were already
	# correct untouched: the gatehouse and the watchfort block the same 42 and 40
	# columns either way. Two levels would be too generous -- it starts letting
	# upper floors count as ground.
	var floor_columns := {}
	for local in definition.nav_cells:
		if local.y >= ground_level and local.y <= ground_level + 1:
			floor_columns[Vector2i(local.x, local.z)] = true
	# Dictionary rather than Array.has() -- this runs over 104,544 cells for the
	# citadel, and the linear membership test made it quadratic.
	var blocked := {}
	for local in definition.solid_cells:
		if local.y < ground_level or local.y > ground_level + 1:
			continue
		var column := Vector2i(local.x, local.z)
		if floor_columns.has(column):
			continue
		blocked[column] = true
	var out: Array[Vector2i] = []
	for column in blocked:
		out.append(column)
	return out
