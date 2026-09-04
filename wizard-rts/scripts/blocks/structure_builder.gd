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
}

var definition: BlockStructureDefinition

var _blocks: MultiMeshInstance3D
var _collision: StaticBody3D

func build(structure: BlockStructureDefinition) -> void:
	definition = structure
	_clear()
	if definition == null:
		return
	_build_blocks()
	_build_collision()

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_blocks = null
	_collision = null

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
	for cell in definition.solid_cells:
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
