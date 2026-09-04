class_name BlockStructureDebugDraw
extends Node3D

# The debug visualisation the spec asks for: solid collision, walkable nav
# cells, stair/ramp links, portal links, climb/ladder links, gate state and
# bridge sockets.
#
# The layer that earns its place is REACHABILITY. Drawing nav cells only tells
# you where the floor is; colouring them by whether the selected unit class can
# actually get there tells you *why* a heavy is stuck at the bottom of the
# stairs. That is the question this system exists to answer, so it is the
# default view rather than an extra.
#
# Everything drawn here is read from the authored definition and the navigation
# graph. Nothing is measured off the rendered blocks.

enum Layer { NAV, LINKS, SOCKETS, SOLID }

# Reachability palette. Deliberately three states, not two: "can stand here but
# cannot get here" is the interesting one, and a two-colour view hides it.
const COLOR_REACHABLE := Color("#4ADE80", 0.55)      # reachable by this class
const COLOR_STRANDED := Color("#FACC15", 0.50)       # standable, unreachable
const COLOR_BLOCKED := Color("#64748B", 0.22)        # not standable at all
const COLOR_GATE_OPEN := Color("#38BDF8", 0.55)
const COLOR_GATE_SHUT := Color("#F87171", 0.60)

const LINK_COLORS := {
	&"STAIR": Color("#FB923C"),
	&"RAMP": Color("#FBBF24"),
	&"LADDER": Color("#C084FC"),
	&"CLIMB_POINT": Color("#A78BFA"),
	&"PORTAL": Color("#F472B6"),
	&"DROP_EDGE": Color("#EF4444"),
}
const COLOR_SOCKET := Color("#E2E8F0")
const COLOR_LINK_DISABLED := Color("#475569")

var definition: BlockStructureDefinition
var navigation: BlockStructureNavigation
var unit_class: StringName = &"infantry"

var _nav_marks: MultiMeshInstance3D
var _link_lines: MeshInstance3D
var _socket_marks: MultiMeshInstance3D
var _layer_visible := {Layer.NAV: true, Layer.LINKS: true, Layer.SOCKETS: true, Layer.SOLID: true}

func setup(structure: BlockStructureDefinition, nav: BlockStructureNavigation) -> void:
	definition = structure
	navigation = nav
	for child in get_children():
		child.queue_free()
	_nav_marks = null
	_link_lines = null
	_socket_marks = null
	refresh()

# Rebuilt wholesale rather than diffed. This runs on a key press, never per
# frame, and a structure is a few hundred cells -- the simplicity is worth more
# than the microseconds.
func refresh() -> void:
	if definition == null or navigation == null:
		return
	_draw_nav_cells()
	_draw_links()
	_draw_sockets()

func set_unit_class(value: StringName) -> void:
	unit_class = value
	refresh()

func set_layer_visible(layer: Layer, value: bool) -> void:
	_layer_visible[layer] = value
	match layer:
		Layer.NAV:
			if _nav_marks != null and is_instance_valid(_nav_marks):
				_nav_marks.visible = value
		Layer.LINKS:
			if _link_lines != null and is_instance_valid(_link_lines):
				_link_lines.visible = value
		Layer.SOCKETS:
			if _socket_marks != null and is_instance_valid(_socket_marks):
				_socket_marks.visible = value

func layer_visible(layer: Layer) -> bool:
	return bool(_layer_visible.get(layer, true))

# --- nav cells --------------------------------------------------------------

func _draw_nav_cells() -> void:
	if _nav_marks == null or not is_instance_valid(_nav_marks):
		_nav_marks = MultiMeshInstance3D.new()
		_nav_marks.name = "NavCells"
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(0.86, 0.86)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		_nav_marks.multimesh = multimesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		# Drawn on top of the blocks it sits on. Without this the markers z-fight
		# with the block faces and flicker as the camera moves.
		material.no_depth_test = false
		material.render_priority = 1
		_nav_marks.material_override = material
		_nav_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_nav_marks.visible = layer_visible(Layer.NAV)
		add_child(_nav_marks)

	# Reachability is computed from a real entry point rather than from "anywhere
	# the class could stand", because standable-but-unreachable is exactly the
	# state worth seeing.
	var reached := {}
	var entry: Variant = _entry_cell()
	if entry != null:
		reached = navigation.reachable_from(entry, unit_class)

	var cells: Array = definition.nav_cells.keys()
	var multimesh := _nav_marks.multimesh
	multimesh.instance_count = maxi(1, cells.size())
	var index := 0
	for cell in cells:
		var nav: Dictionary = definition.nav_cells[cell]
		var color := COLOR_BLOCKED
		if reached.has(cell):
			color = COLOR_REACHABLE
		elif navigation.can_occupy(cell, unit_class):
			color = COLOR_STRANDED
		# Gate cells report their own state regardless, since "why is this shut"
		# is the other question people ask of a gatehouse.
		if StringName(nav.get("type", &"")) == &"GATE":
			var key := StringName(nav.get("state_key", &""))
			var open := key != &"" and bool(navigation.gate_states.get(str(key), false))
			color = COLOR_GATE_OPEN if open else COLOR_GATE_SHUT
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY, BlockStructureBuilder.cell_floor(cell) + Vector3(0.0, 0.03, 0.0)))
		multimesh.set_instance_color(index, color)
		index += 1
	multimesh.visible_instance_count = index

# A sensible place to measure reachability from: the lowest, most southerly nav
# cell the class can actually stand in. For the gatehouse that is the ground
# outside the gate, which is where an attacker would arrive.
func _entry_cell() -> Variant:
	var best: Variant = null
	for cell in definition.nav_cells:
		if not navigation.can_occupy(cell, unit_class):
			continue
		if best == null or cell.y < best.y or (cell.y == best.y and cell.z < best.z):
			best = cell
	return best

# --- links ------------------------------------------------------------------

func _draw_links() -> void:
	if _link_lines == null or not is_instance_valid(_link_lines):
		_link_lines = MeshInstance3D.new()
		_link_lines.name = "Links"
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		# Links are the thing you most want to see, and they run through solid
		# stone by nature -- a stair is inside the wall it climbs. Drawing them
		# through geometry is the point, not a mistake.
		material.no_depth_test = true
		material.render_priority = 2
		_link_lines.material_override = material
		_link_lines.visible = layer_visible(Layer.LINKS)
		add_child(_link_lines)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for link in definition.links:
		var usable := navigation.link_admits(link, unit_class)
		var color: Color = LINK_COLORS.get(link["type"], Color.WHITE)
		if not usable:
			color = COLOR_LINK_DISABLED
		var from := BlockStructureBuilder.cell_floor(link["from"]) + Vector3(0.0, 0.15, 0.0)
		var to := BlockStructureBuilder.cell_floor(link["to"]) + Vector3(0.0, 0.15, 0.0)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(from)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(to)
		# A short upright tick at each end, so an endpoint buried in stone is
		# still visible. That matters here: in the original pack data every
		# link's bottom endpoint is inside a solid block.
		for point in [from, to]:
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(point)
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(point + Vector3(0.0, 0.6, 0.0))
	mesh.surface_end()
	_link_lines.mesh = mesh

# --- sockets ----------------------------------------------------------------

func _draw_sockets() -> void:
	if _socket_marks == null or not is_instance_valid(_socket_marks):
		_socket_marks = MultiMeshInstance3D.new()
		_socket_marks.name = "Sockets"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 1.4, 0.5)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		_socket_marks.multimesh = multimesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.no_depth_test = true
		material.render_priority = 2
		_socket_marks.material_override = material
		_socket_marks.visible = layer_visible(Layer.SOCKETS)
		add_child(_socket_marks)
	var multimesh := _socket_marks.multimesh
	multimesh.instance_count = maxi(1, definition.sockets.size())
	var index := 0
	for socket in definition.sockets:
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY, BlockStructureBuilder.cell_floor(socket["position"]) + Vector3(0.0, 0.7, 0.0)))
		multimesh.set_instance_color(index, Color(COLOR_SOCKET, 0.5))
		index += 1
	multimesh.visible_instance_count = index
