class_name BlockStructureBuilder
extends Node3D

# Turns a BlockStructureDefinition into visible geometry and collision.
#
# This is the VISUAL layer and nothing else. It reads the same authored
# definition the navigation layer reads, but nothing reads it back -- that
# one-way direction is what keeps the spec's rule true: navigation is never
# inferred from rendered geometry. Deleting this node leaves traversal exactly
# as correct as it was.
#
# Blocks are a single MultiMesh with per-instance colour rather than a node per
# cell. A mid-sized structure is 400-1000 cells and the ziggurat is 680; that is
# a lot of nodes to spawn for something the player mostly sees as a silhouette.
#
# Collision is one StaticBody3D with a box shape per solid cell. Deliberately
# not merged into a convex hull: the cells ARE the authored truth, and a merged
# hull would quietly round off the carved gate passage.

# Primitive colours for readability, not art. Final art is explicitly out of
# scope for this system -- the point is to see the structure, not to dress it.
const MATERIAL_COLORS := {
	&"STONE_BRICK": Color("#8C8F96"),
	&"MOSSY_STONE": Color("#6E8B62"),
	&"BLACK_STONE": Color("#3A3B45"),
	&"TIMBER": Color("#8A6038"),
	&"BONE": Color("#D8CFB4"),
	&"METAL_GATE": Color("#B5763A"),
	&"RUIN_STONE": Color("#7A7466"),
	&"MAGIC_STONE": Color("#6A5AA8"),
	&"VOID_DECOR": Color("#202028"),
	# Schema 1.1 materials.
	&"TOWER_STONE": Color("#A8A79B"),
	&"DARK_STONE": Color("#4A4C55"),
	&"GLASS": Color("#5FD0E0"),
	&"METAL": Color("#3C4048"),
	&"GATE": Color("#7A5230"),
	&"EMPTY": Color("#202028"),
}

# Stair treads are drawn a shade lighter than the stone around them, because
# their job is to be READ as circulation from an RTS camera, not to blend in.
const STAIR_COLOR := Color("#C4B896")
const RAMP_COLOR := Color("#B9A87E")

var definition: BlockStructureDefinition

var _blocks: MultiMeshInstance3D
var _collision: StaticBody3D
# state_key -> the node holding that gate's leaf, so it can be hidden when the
# gate opens. Collision and navigation already switch together; this is the
# visual half, without which an open gate still looks shut.
var _gate_meshes: Dictionary = {}

func build(structure: BlockStructureDefinition) -> void:
	definition = structure
	_clear()
	if definition == null:
		return
	_build_blocks()
	_build_stairs()
	_build_gates()
	_build_collision()

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_blocks = null
	_collision = null
	_gate_meshes.clear()

func _build_blocks() -> void:
	_blocks = MultiMeshInstance3D.new()
	_blocks.name = "Blocks"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = maxi(1, definition.solid_cells.size())
	var index := 0
	var gated := _all_gate_cells()
	for cell in definition.solid_cells:
		if gated.has(cell):
			continue
		var material: StringName = definition.solid_cells[cell]
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, cell_centre(cell)))
		multimesh.set_instance_color(index, MATERIAL_COLORS.get(material, Color("#9AA0A6")))
		index += 1
	multimesh.visible_instance_count = index
	_blocks.multimesh = multimesh
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.roughness = 0.95
	_blocks.material_override = surface
	add_child(_blocks)

func _all_gate_cells() -> Dictionary:
	var cells := {}
	for state_key in definition.gate_cells:
		for cell in definition.gate_cells[state_key]:
			cells[cell] = state_key
	return cells

func _build_gates() -> void:
	for state_key in definition.gate_cells:
		var cells: Array = definition.gate_cells[state_key]
		if cells.is_empty():
			continue
		var instance := MultiMeshInstance3D.new()
		instance.name = "Gate_%s" % state_key
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = cells.size()
		for i in cells.size():
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_centre(cells[i])))
			multimesh.set_instance_color(i, MATERIAL_COLORS.get(&"GATE", Color("#7A5230")))
		multimesh.visible_instance_count = cells.size()
		instance.multimesh = multimesh
		var surface := StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		instance.material_override = surface
		add_child(instance)
		_gate_meshes[state_key] = instance

# Hides the leaf of an open gate, so what you see matches what units can walk
# through. The spec asks for collision and navigation to switch together; this
# is the visual half of that.
func set_gate_open(state_key: StringName, open: bool) -> void:
	if _gate_meshes.has(state_key):
		(_gate_meshes[state_key] as Node3D).visible = not open

# Generates visible step geometry along every STAIR and RAMP link.
#
# The spec is explicit that stairs must be built as block steps rather than
# existing only as invisible links, and it is right to insist: a tower whose
# floors are connected by nothing you can see reads as a stack of disconnected
# platforms. This is the one place geometry is DERIVED rather than authored --
# and it derives from the authored LINK, never the other way round. Navigation
# still comes from the link; these blocks are decoration that happens to be
# honest about where the link goes.
func _build_stairs() -> void:
	var treads: Array[Dictionary] = []
	for link in definition.links:
		var type: StringName = link["type"]
		if type != &"STAIR" and type != &"RAMP":
			continue
		treads.append_array(_tread_cells(link))
	if treads.is_empty():
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = "Stairs"
	var mesh := BoxMesh.new()
	# Slightly under a full block so each tread reads as a separate step rather
	# than merging into a smooth ramp.
	mesh.size = Vector3(0.96, 0.9, 0.96)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = treads.size()
	for i in treads.size():
		var tread: Dictionary = treads[i]
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_centre(tread["cell"])))
		multimesh.set_instance_color(i, tread["color"])
	multimesh.visible_instance_count = treads.size()
	instance.multimesh = multimesh
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.roughness = 0.9
	instance.material_override = surface
	add_child(instance)

# One tread per step along the link, widened across the direction of travel.
# The tread sits one block BELOW the walking line, because a unit stands on a
# step rather than inside it.
func _tread_cells(link: Dictionary) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var from: Vector3i = link["from"]
	var to: Vector3i = link["to"]
	var delta := to - from
	var steps: int = maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.z))
	if steps <= 0:
		return cells
	var color: Color = STAIR_COLOR if link["type"] == &"STAIR" else RAMP_COLOR
	# Widen perpendicular to the dominant horizontal direction.
	var across := Vector3i(0, 0, 1) if absi(delta.x) >= absi(delta.z) else Vector3i(1, 0, 0)
	var width: int = maxi(1, int(link.get("width", 1)))
	var seen := {}
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var point := Vector3i(
			from.x + roundi(float(delta.x) * t),
			from.y + roundi(float(delta.y) * t),
			from.z + roundi(float(delta.z) * t))
		for w in width:
			var cell: Vector3i = point + across * w + Vector3i(0, -1, 0)
			if seen.has(cell):
				continue
			# Never overwrite authored structure: a tread that lands inside a
			# wall would poke a lighter block through it.
			if definition.is_solid(cell):
				continue
			seen[cell] = true
			cells.append({"cell": cell, "color": color})
	return cells

func _build_collision() -> void:
	_collision = StaticBody3D.new()
	_collision.name = "Collision"
	add_child(_collision)
	for cell in definition.solid_cells:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE
		shape.shape = box
		shape.position = cell_centre(cell)
		_collision.add_child(shape)

func set_blocks_visible(value: bool) -> void:
	if _blocks != null and is_instance_valid(_blocks):
		_blocks.visible = value

# A cell's centre in local space. Cell (0,0,0) occupies the unit cube from the
# origin, so its centre is half a block along each axis.
static func cell_centre(cell: Vector3i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, float(cell.y) + 0.5, float(cell.z) + 0.5)

# The floor of a cell -- where a nav marker or a standing unit belongs.
static func cell_floor(cell: Vector3i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, float(cell.y), float(cell.z) + 0.5)
