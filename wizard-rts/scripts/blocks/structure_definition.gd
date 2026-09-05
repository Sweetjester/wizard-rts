class_name BlockStructureDefinition
extends RefCounted

# One authored block structure, expanded from the spec into cells.
#
# The spec's non-negotiable rule is that navigation is NEVER inferred from
# rendered geometry. This class is what makes that true: it expands the authored
# regions into three INDEPENDENT sets, and nothing downstream reads a mesh.
#
#   solid_cells  -- collision. What a block physically occupies.
#   nav_cells    -- navigation. Cells a unit may stand in, with the classes
#                   allowed there and the gate state (if any) that governs them.
#   links        -- authored transitions between elevations or disconnected
#                   regions: stairs, ramps, ladders, climb points, portals, drops.
#
# Coordinates are Vector3i in the structure's LOCAL space, x east, y up, z north,
# origin at the minimum corner. Every range in the spec is inclusive.
#
# Blocks carve COLLISION; nav_regions declare where units may STAND. A block's
# own `nav` field is kept as `open_cells` (headroom, carved volume) but never
# creates walkable ground -- see the note in from_data() for why, and what the
# debug view showed when it did.
#
# Later blocks override earlier ones, which is how the gatehouse carves its
# VOID_DECOR passage through a solid wall.

var id: StringName = &""
var display_name: String = ""
var dimensions: Vector3i = Vector3i.ZERO
var purpose: Array = []
var runtime_profile: bool = false
var art: Dictionary = {}
var source_data: Dictionary = {}
var rotation_steps: int = 0

# Vector3i -> material StringName. Only cells whose material actually collides.
var solid_cells: Dictionary = {}
# Vector3i -> {"type": StringName, "allowed": Array, "state_key": StringName, "region_id": StringName}
var nav_cells: Dictionary = {}
# Array of {"id", "type", "from": Vector3i, "to": Vector3i, "allowed": Array, "width": int}
var links: Array[Dictionary] = []
# Array of {"id", "type", "position": Vector3i, "facing": String, "width": int}
var sockets: Array[Dictionary] = []
# Vector3i -> nav type declared on a BLOCK. Headroom and carved volume, kept for
# clearance checks and debug, never treated as standable ground.
var open_cells: Dictionary = {}
# state_key -> Array[Vector3i] the gate leaf occupies. The builder uses this to
# hide the leaf when the gate opens, so collision and navigation switch together
# rather than leaving a visible door units walk through.
var gate_cells: Dictionary = {}
# The authored block volumes, kept as boxes. Collision is built from these
# rather than from expanded cells: a cell-per-shape body is 2432 nodes for the
# observation tower and 104220 for the citadel, which never finishes loading.
# Roughly one box per authored block instead.
var block_boxes: Array[Dictionary] = []

static func from_data(structure_id: StringName, data: Dictionary, materials: Dictionary) -> BlockStructureDefinition:
	var definition := BlockStructureDefinition.new()
	definition.id = structure_id
	definition.display_name = str(data.get("display_name", structure_id))
	var dims: Array = data.get("dimensions", [0, 0, 0])
	definition.dimensions = Vector3i(int(dims[0]), int(dims[1]), int(dims[2]))
	definition.purpose = data.get("purpose", [])
	definition.runtime_profile = bool(data.get("compact_runtime", false))
	definition.art = data.get("art", {})
	definition.source_data = data

	# Blocks, in authored order. Later entries override earlier ones so a
	# VOID_DECOR volume can be carved through a solid wall -- that is exactly how
	# the fortress gatehouse gets its gate passage.
	for block in data.get("blocks", []):
		var material := StringName(block.get("material", &"STONE_BRICK"))
		var collision := str(materials.get(str(material), {}).get("collision", "solid"))
		var nav_type := StringName(block.get("nav", &"SOLID"))
		var bounds := _region_bounds(block.get("region", {}))
		if collision != "none" and bounds.size.x > 0.0:
			definition.block_boxes.append({"min": bounds.position, "size": bounds.size})
		for cell in expand_region(block.get("region", {})):
			if collision == "none":
				definition.solid_cells.erase(cell)
			else:
				definition.solid_cells[cell] = material
			# A block's `nav` field is recorded but does NOT create walkable
			# cells. The spec is explicit that nav_regions define occupiable
			# cells (rule 4), and taking blocks as floor too is wrong in a way
			# the debug view made obvious: a gatehouse's carved passage is four
			# blocks tall, so treating the whole volume as FLOOR produced four
			# stacked levels of walkable ground, three of them in mid-air.
			#
			# Inferring support instead ("floor where the cell below is solid")
			# would be deriving navigation from block layout, which is the one
			# thing the spec forbids. So blocks carve collision; regions declare
			# where units may stand.
			if nav_type != &"SOLID":
				definition.open_cells[cell] = nav_type

	# Authored nav regions are authoritative over anything a block implied.
	for region in data.get("nav_regions", []):
		var entry := {
			"type": StringName(region.get("type", &"FLOOR")),
			"allowed": region.get("allowed", []),
			"state_key": StringName(region.get("state_key", &"")),
			"region_id": StringName(region.get("id", &"region")),
		}
		for cell in expand_region(region.get("region", {})):
			definition.nav_cells[cell] = entry.duplicate()

	# Gates (schema 1.1). A gate declares a `passage_region` -- the strip units
	# walk through -- and a `block_region`, which is what the leaf physically
	# occupies. Only the block_region is conditional.
	#
	# Gating the whole passage instead is too coarse and was wrong in a way the
	# structure's own tests caught: a unit standing on the apron in FRONT of a
	# shut gate is not blocked by it, and treating the apron as gated made a
	# heavy unable to even approach the door.
	for gate in data.get("gates", []):
		var state_key := StringName(gate.get("state_key", &""))
		var blocked := {}
		for cell in expand_region(gate.get("block_region", {})):
			blocked[cell] = true
		# Anything in the passage but outside the leaf is ordinary floor.
		for cell in expand_region(gate.get("passage_region", {})):
			if not definition.nav_cells.has(cell):
				continue
			if blocked.has(cell):
				continue
			definition.nav_cells[cell] = definition.nav_cells[cell].duplicate()
			definition.nav_cells[cell]["type"] = &"FLOOR"
			definition.nav_cells[cell]["state_key"] = &""
		# And the leaf's own cells are gated, whatever region they fell in.
		for cell in blocked:
			if not definition.nav_cells.has(cell):
				continue
			definition.nav_cells[cell] = definition.nav_cells[cell].duplicate()
			definition.nav_cells[cell]["type"] = &"GATE"
			definition.nav_cells[cell]["state_key"] = state_key
		# One switch can control several leaves (the citadel's outer/inner gates).
		var all_leaves: Array = definition.gate_cells.get(state_key, [])
		for cell in blocked:
			if not all_leaves.has(cell):
				all_leaves.append(cell)
		definition.gate_cells[state_key] = all_leaves

	for link in data.get("links", []):
		definition.links.append({
			"id": StringName(link.get("id", &"link")),
			"type": StringName(link.get("type", &"STAIR")),
			"from": _to_cell(link.get("from", [0, 0, 0])),
			"to": _to_cell(link.get("to", [0, 0, 0])),
			"allowed": link.get("allowed", []),
			"width": int(link.get("width", 1)),
		})

	for socket in data.get("sockets", []):
		definition.sockets.append({
			"id": StringName(socket.get("id", &"socket")),
			"type": StringName(socket.get("type", &"BRIDGE_SOCKET")),
			"position": _to_cell(socket.get("position", [0, 0, 0])),
			"facing": str(socket.get("facing", "north")),
			"width": int(socket.get("width", 1)),
		})
	return definition

# Every range in the spec is INCLUSIVE, and a bare int is a range of one. Getting
# this wrong silently produces structures one cell too small in every dimension,
# so it is the one piece of parsing with its own assertion in the smoke test.
static func expand_region(region: Dictionary) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if region.is_empty():
		return cells
	var rx := _to_range(region.get("x", 0))
	var ry := _to_range(region.get("y", 0))
	var rz := _to_range(region.get("z", 0))
	for x in range(rx.x, rx.y + 1):
		for y in range(ry.x, ry.y + 1):
			for z in range(rz.x, rz.y + 1):
				cells.append(Vector3i(x, y, z))
	return cells

# Inclusive region -> an AABB in cells.
static func _region_bounds(region: Dictionary) -> AABB:
	if region.is_empty():
		return AABB()
	var rx := _to_range(region.get("x", 0))
	var ry := _to_range(region.get("y", 0))
	var rz := _to_range(region.get("z", 0))
	return AABB(Vector3(rx.x, ry.x, rz.x),
		Vector3(rx.y - rx.x + 1, ry.y - ry.x + 1, rz.y - rz.x + 1))

static func _to_range(value: Variant) -> Vector2i:
	if value is Array:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(int(value), int(value))

static func _to_cell(value: Variant) -> Vector3i:
	if value is Array and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return Vector3i.ZERO

func is_solid(cell: Vector3i) -> bool:
	return solid_cells.has(cell)

func nav_at(cell: Vector3i) -> Dictionary:
	return nav_cells.get(cell, {})

# --- rotation ---------------------------------------------------------------

# A copy of this structure turned in 90-degree steps about its own vertical axis.
#
# Rotating the DEFINITION once, rather than threading a rotation through the
# lattice, the builder, the collision boxes and the 2D blockers, means every
# consumer downstream keeps working on plain local coordinates and none of them
# has to know rotation exists. It also guarantees they cannot disagree: the
# walls, the walkable floor, the doorway sockets and the visible mesh are all
# derived from the same rotated cells.
#
# Heights are untouched -- a building turned on its side is a different problem.
const FACING_ORDER := ["north", "east", "south", "west"]

func rotated(steps: int) -> BlockStructureDefinition:
	var turns := ((steps % 4) + 4) % 4
	if turns == 0:
		return self
	var out := BlockStructureDefinition.new()
	out.id = id
	out.display_name = display_name
	out.purpose = purpose
	out.runtime_profile = runtime_profile
	out.art = art
	out.source_data = source_data
	out.rotation_steps = (rotation_steps + turns) % 4
	# A quarter turn swaps the footprint; a half turn leaves it.
	out.dimensions = Vector3i(dimensions.z, dimensions.y, dimensions.x) if turns % 2 == 1 else dimensions
	for cell in solid_cells:
		out.solid_cells[_turn_cell(cell, turns)] = solid_cells[cell]
	for cell in nav_cells:
		out.nav_cells[_turn_cell(cell, turns)] = nav_cells[cell]
	for cell in open_cells:
		out.open_cells[_turn_cell(cell, turns)] = open_cells[cell]
	# gate_cells is keyed by STATE KEY, with the leaf's cells as the value -- so
	# the key is carried across untouched and the cells inside it are turned.
	for state_key in gate_cells:
		var turned_leaves: Array[Vector3i] = []
		for cell in gate_cells[state_key]:
			turned_leaves.append(_turn_cell(cell, turns))
		out.gate_cells[state_key] = turned_leaves
	for link in links:
		var turned := link.duplicate()
		turned["from"] = _turn_cell(link["from"], turns)
		turned["to"] = _turn_cell(link["to"], turns)
		out.links.append(turned)
	for socket in sockets:
		var turned_socket := socket.duplicate()
		turned_socket["position"] = _turn_cell(socket["position"], turns)
		turned_socket["facing"] = _turn_facing(str(socket.get("facing", "north")), turns)
		out.sockets.append(turned_socket)
	# Boxes are rebuilt from their two opposite corners, because rotating an
	# origin alone would leave the box hanging off the wrong side of it.
	for box in block_boxes:
		var box_min: Vector3i = box["min"]
		var box_size: Vector3i = box["size"]
		var a := _turn_cell(box_min, turns)
		var b := _turn_cell(box_min + box_size - Vector3i(1, 1, 1), turns)
		out.block_boxes.append({
			"min": Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z)),
			"size": Vector3i(absi(b.x - a.x) + 1, absi(b.y - a.y) + 1, absi(b.z - a.z) + 1),
		})
	return out

func _turn_cell(cell: Vector3i, turns: int) -> Vector3i:
	var width := dimensions.x
	var depth := dimensions.z
	match turns:
		1:
			return Vector3i(depth - 1 - cell.z, cell.y, cell.x)
		2:
			return Vector3i(width - 1 - cell.x, cell.y, depth - 1 - cell.z)
		3:
			return Vector3i(cell.z, cell.y, width - 1 - cell.x)
	return cell

# Turned to match _turn_cell, which is the whole point: a door that moves to the
# east face must SAY east. One step of _turn_cell sends the south edge (z = 0) to
# the maximum-x edge, so the facing steps backwards through the compass, not
# forwards. Getting this the wrong way round is quiet and expensive -- the
# geometry rotates correctly and only the doorway link goes to the wrong side,
# leaving a building that looks right and cannot be entered.
func _turn_facing(facing: String, turns: int) -> String:
	var index := FACING_ORDER.find(facing)
	if index < 0:
		return facing
	return FACING_ORDER[((index - turns) % 4 + 4) % 4]

# --- downsampling -----------------------------------------------------------

# A copy of this structure at 1/factor the size in EVERY axis.
#
# The authored structures are drawn at a resolution where a wall is several
# blocks thick and a hall is thirty across. That is the right resolution to
# author at -- it is where the detail lives -- and the wrong one to play at: one
# block is one map cell, so a 34x20x28 laboratory covered 952 cells and stood
# twenty high, which is a district rather than a building.
#
# Squashing the height was tried first and was simply wrong: it flattened the
# building instead of shrinking it, leaving the same floor area under a lower
# roof. Downsampling reduces all three axes together, so a 20x20x20 becomes a
# 5x5x5 that looks like the same building seen from further away.
#
# THE RULE, which is the whole difficulty: each output cell covers factor^3
# input cells and they will not agree. NAV WINS -- a cell comes out solid only
# if nothing walkable fell inside it.
#
# Solid winning was tried first and is catastrophic: a floor is solid blocks
# with the walkable air directly above them, so almost every group contains
# some solid and the whole building fuses into a brick. Measured on the
# laboratory at quarter size: solid-wins left 0 nav cells, a 25% threshold left
# 14, a 50% threshold 51, and nav-wins 60 with 116 solid -- the only rule that
# keeps both a building and a way through it.
#
# The cost is that walls thinner than the sample window dissolve, which is
# unavoidable: you cannot keep one-block detail while dividing by four. Walls
# authored thick enough to survive their own group still read as walls.
func downsampled(factor: int) -> BlockStructureDefinition:
	if factor <= 1:
		return self
	var out := BlockStructureDefinition.new()
	out.id = id
	out.display_name = display_name
	out.purpose = purpose
	out.dimensions = Vector3i(
		maxi(1, int(ceil(float(dimensions.x) / float(factor)))),
		maxi(1, int(ceil(float(dimensions.y) / float(factor)))),
		maxi(1, int(ceil(float(dimensions.z) / float(factor)))))
	for cell in solid_cells:
		out.solid_cells[_shrink_cell(cell, factor)] = solid_cells[cell]
	# Applied after solid, and erasing it: anything walkable stays walkable.
	for cell in nav_cells:
		var shrunk := _shrink_cell(cell, factor)
		out.nav_cells[shrunk] = nav_cells[cell]
		out.solid_cells.erase(shrunk)
	for cell in open_cells:
		var open_shrunk := _shrink_cell(cell, factor)
		if not out.solid_cells.has(open_shrunk):
			out.open_cells[open_shrunk] = open_cells[cell]
	for state_key in gate_cells:
		var leaves: Array[Vector3i] = []
		for cell in gate_cells[state_key]:
			var leaf := _shrink_cell(cell, factor)
			if not leaves.has(leaf):
				leaves.append(leaf)
		out.gate_cells[state_key] = leaves
	for link in links:
		var turned := link.duplicate()
		turned["from"] = _shrink_cell(link["from"], factor)
		turned["to"] = _shrink_cell(link["to"], factor)
		if turned["from"] != turned["to"]:
			out.links.append(turned)
	for socket in sockets:
		var shrunk_socket := socket.duplicate()
		shrunk_socket["position"] = _shrink_cell(socket["position"], factor)
		shrunk_socket["width"] = maxi(1, int(socket.get("width", 1)) / factor)
		out.sockets.append(shrunk_socket)
	for box in block_boxes:
		var box_min: Vector3i = box["min"]
		var box_size: Vector3i = box["size"]
		var a := _shrink_cell(box_min, factor)
		var b := _shrink_cell(box_min + box_size - Vector3i(1, 1, 1), factor)
		out.block_boxes.append({
			"min": a,
			"size": Vector3i(b.x - a.x + 1, b.y - a.y + 1, b.z - a.z + 1),
		})
	return out

func _shrink_cell(cell: Vector3i, factor: int) -> Vector3i:
	# Floor division, so a socket authored just outside the footprint at -1
	# stays outside rather than rounding onto the wall.
	return Vector3i(
		int(floor(float(cell.x) / float(factor))),
		int(floor(float(cell.y) / float(factor))),
		int(floor(float(cell.z) / float(factor))))
