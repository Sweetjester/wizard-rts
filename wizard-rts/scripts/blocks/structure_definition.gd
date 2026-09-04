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
		definition.gate_cells[state_key] = blocked.keys()

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
