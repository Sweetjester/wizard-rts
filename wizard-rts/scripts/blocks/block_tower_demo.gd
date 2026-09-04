extends Node3D

# Kon's Observation Wizard Tower, with a unit you drive.
#
#   Godot --path . res://scenes/blocks/block_tower_demo.tscn
#
# Controls
#   LEFT CLICK   send your unit there (it paths; it does not teleport)
#   C            change your unit's class -- infantry / archer / climber / heavy / flying
#   G            open and shut the main gate
#   N            show the cells your current class can stand on
#   L            show the authored traversal links
#   drag / wheel orbit and zoom
#   R            reset the unit to the south road
#
# The tower is 18x32x18 and built entirely from the authored YAML. What to watch:
# switch to HEAVY and the whole interior greys out -- a heavy can reach the
# gateway and nothing above it, because it cannot use stairs. Shut the gate and
# even that goes. Nothing here is scripted per-structure; it all falls out of the
# spec file.

const TOWER := &"kons_observation_wizard_tower_01"
const CLASSES: Array[StringName] = [&"infantry", &"archer", &"climber", &"heavy", &"flying"]
const CLASS_COLORS := {
	&"infantry": Color("#4ADE80"),
	&"archer": Color("#38BDF8"),
	&"climber": Color("#C084FC"),
	&"heavy": Color("#FB923C"),
	&"flying": Color("#F472B6"),
}
const GROUND := 40
const TOWER_ORIGIN := Vector2i(11, 11)
const MOVE_SPEED := 4.5

var library: BlockStructureLibrary
var definition: BlockStructureDefinition
var world: BlockNavWorld
var terrain: FlatGround

var _builder: BlockStructureBuilder
var _camera: Camera3D
var _pivot: Node3D
var _legend: Label
var _unit: MeshInstance3D
var _nav_marks: MultiMeshInstance3D
var _link_lines: MeshInstance3D
var _path_lines: MeshInstance3D

var _class_index := 0
var _node: Vector3i = Vector3i.ZERO
var _path: Array[Vector3i] = []
var _leg := 0
var _leg_t := 0.0
var _gate_open := false
var _show_nav := false
var _show_links := true
var _orbit := Vector2(-0.42, 0.62)
var _distance := 58.0
var _dragging := false
var _last_message := ""

# Flat ground for the tower to stand on. Implements only the three calls
# BlockNavWorld asks of a map, which is the whole terrain contract.
class FlatGround extends Node:
	const MAP_W := GROUND
	const MAP_H := GROUND
	func is_walkable_cell(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H
	func get_height(_cell: Vector2i) -> int:
		return 0
	func is_cliff_edge_cell(_cell: Vector2i) -> bool:
		return false

func _ready() -> void:
	library = BlockStructureLibrary.load_default()
	definition = library.get_definition(TOWER)
	if definition == null:
		push_error("Tower missing -- run: python tools/blocks/convert_structures.py")
		return
	_build_view()
	_build_world()

func _build_view() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0E1117")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#606A7C")
	env.ambient_light_energy = 0.95
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -36.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 900.0
	_camera.fov = 45.0
	_pivot.add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_legend = Label.new()
	_legend.position = Vector2(16, 12)
	_legend.add_theme_color_override("font_color", Color("#E6EAF0"))
	_legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_legend.add_theme_constant_override("outline_size", 5)
	layer.add_child(_legend)

func _build_world() -> void:
	terrain = FlatGround.new()
	terrain.name = "FlatGround"
	add_child(terrain)
	world = BlockNavWorld.new(library.unit_classes)
	world.build_from_terrain(terrain)
	# The structure's own declared default, not an assumption by this scene.
	world.gate_states = library.gate_defaults_for(TOWER).duplicate()
	_gate_open = bool(world.gate_states.get("main_gate_open", false))
	world.place_structure(definition, TOWER_ORIGIN, 0, TOWER)

	_draw_ground()
	_builder = BlockStructureBuilder.new()
	_builder.name = "Tower"
	add_child(_builder)
	_builder.build(definition)
	_builder.position = Vector3(float(TOWER_ORIGIN.x), 0.0, float(TOWER_ORIGIN.y))
	_builder.set_gate_open(&"main_gate_open", _gate_open)

	_build_unit()
	_build_overlays()
	_pivot.position = Vector3(float(TOWER_ORIGIN.x) + 9.0, 12.0, float(TOWER_ORIGIN.y) + 9.0)
	_apply_camera()
	_reset_unit()

func _draw_ground() -> void:
	var plane := MeshInstance3D.new()
	plane.name = "Ground"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND, GROUND)
	plane.mesh = mesh
	plane.position = Vector3(GROUND * 0.5, 0.0, GROUND * 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#39433A")
	material.roughness = 1.0
	plane.material_override = material
	add_child(plane)

func _build_unit() -> void:
	_unit = MeshInstance3D.new()
	_unit.name = "Unit"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.3
	_unit.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = CLASS_COLORS[CLASSES[_class_index]]
	_unit.material_override = material
	add_child(_unit)

func _build_overlays() -> void:
	_nav_marks = MultiMeshInstance3D.new()
	_nav_marks.name = "NavCells"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.8, 0.8)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	_nav_marks.multimesh = multimesh
	var nav_material := StandardMaterial3D.new()
	nav_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nav_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nav_material.vertex_color_use_as_albedo = true
	nav_material.no_depth_test = true
	_nav_marks.material_override = nav_material
	_nav_marks.visible = _show_nav
	add_child(_nav_marks)

	_link_lines = _make_line_node("Links", _show_links)
	_path_lines = _make_line_node("Path", true)
	_draw_links()

func _make_line_node(node_name: String, shown: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	node.material_override = material
	node.visible = shown
	add_child(node)
	return node

# --- unit -------------------------------------------------------------------

func _unit_class() -> StringName:
	return CLASSES[_class_index]

func _reset_unit() -> void:
	# The south road socket: where the spec expects an approach to arrive.
	var start := Vector3i(TOWER_ORIGIN.x + 8, 0, TOWER_ORIGIN.y + 0)
	if not world.can_occupy(world.encode(Vector2i(start.x, start.z), 0), _unit_class()):
		start = Vector3i(TOWER_ORIGIN.x + 8, 0, TOWER_ORIGIN.y - 3)
	_node = start
	_path.clear()
	_leg = 0
	_leg_t = 0.0
	_unit.position = _node_world(_node)
	_last_message = "reset to the south approach"
	_refresh()

func _node_world(node: Vector3i) -> Vector3:
	return Vector3(float(node.x) + 0.5, float(node.y) + 0.65, float(node.z) + 0.5)

func _process(delta: float) -> void:
	if _path.size() < 2 or _leg >= _path.size() - 1:
		return
	var from := _node_world(_path[_leg])
	var to := _node_world(_path[_leg + 1])
	var length: float = maxf(0.001, from.distance_to(to))
	_leg_t += delta * MOVE_SPEED / length
	while _leg_t >= 1.0 and _leg < _path.size() - 1:
		_leg_t -= 1.0
		_leg += 1
		_node = _path[_leg]
	if _leg >= _path.size() - 1:
		_unit.position = _node_world(_node)
		_path.clear()
		_leg = 0
		_leg_t = 0.0
		_refresh()
		return
	_unit.position = _node_world(_path[_leg]).lerp(_node_world(_path[_leg + 1]), clampf(_leg_t, 0.0, 1.0))
	_draw_path()

# Picks the standable node nearest the click, by projecting candidates to the
# screen. Deliberately not a physics raycast: a ray hits the OUTSIDE of the
# tower, and what the player means by clicking a tower is a floor inside it.
# Projecting nav nodes picks somewhere a unit can actually stand by definition.
func _pick_node(screen_position: Vector2) -> Vector3i:
	var best := Vector3i.MAX
	var best_score := 40.0
	for x in GROUND:
		for z in GROUND:
			var cell := Vector2i(x, z)
			for level in world.levels_at(cell):
				var node_id: int = world.encode(cell, level)
				if not world.can_occupy(node_id, _unit_class()):
					continue
				var point := _node_world(Vector3i(x, level, z))
				if _camera.is_position_behind(point):
					continue
				var distance := _camera.unproject_position(point).distance_to(screen_position)
				if distance > best_score:
					continue
				best_score = distance
				best = Vector3i(x, level, z)
	return best

func _order_to(node: Vector3i) -> void:
	var path := world.find_path(
		Vector2i(_node.x, _node.z), _node.y, Vector2i(node.x, node.z), node.y, _unit_class())
	if path.size() < 2:
		_last_message = "no route to %s as %s" % [node, _unit_class()]
		_path.clear()
		_refresh()
		return
	_path = path
	_leg = 0
	_leg_t = 0.0
	_last_message = "routed %d steps, %d -> %d" % [path.size(), path[0].y, path[path.size() - 1].y]
	_draw_path()
	_refresh()

# --- overlays ---------------------------------------------------------------

func _draw_nav_cells() -> void:
	var cells: Array[Vector3i] = []
	for x in GROUND:
		for z in GROUND:
			for level in world.levels_at(Vector2i(x, z)):
				if world.can_occupy(world.encode(Vector2i(x, z), level), _unit_class()):
					cells.append(Vector3i(x, level, z))
	var multimesh := _nav_marks.multimesh
	multimesh.instance_count = maxi(1, cells.size())
	for i in cells.size():
		multimesh.set_instance_transform(i,
			Transform3D(Basis.IDENTITY, Vector3(cells[i].x + 0.5, cells[i].y + 0.06, cells[i].z + 0.5)))
		multimesh.set_instance_color(i, Color(CLASS_COLORS[_unit_class()], 0.35))
	multimesh.visible_instance_count = cells.size()

func _draw_links() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var offset := Vector3(TOWER_ORIGIN.x, 0.0, TOWER_ORIGIN.y)
	for link in definition.links:
		var usable := world.rules.link_admits(link, _unit_class())
		var color := Color("#FB923C") if usable else Color("#4B5563")
		if link["type"] == &"FLOOR_LINK":
			color = Color("#F472B6") if usable else Color("#4B5563")
		var from := offset + Vector3(link["from"].x + 0.5, link["from"].y + 0.2, link["from"].z + 0.5)
		var to := offset + Vector3(link["to"].x + 0.5, link["to"].y + 0.2, link["to"].z + 0.5)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(from)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(to)
	mesh.surface_end()
	_link_lines.mesh = mesh

func _draw_path() -> void:
	var mesh := ImmediateMesh.new()
	if _path.size() >= 2:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(_path.size() - 1):
			mesh.surface_set_color(Color("#FDE68A"))
			mesh.surface_add_vertex(_node_world(_path[i]))
			mesh.surface_set_color(Color("#FDE68A"))
			mesh.surface_add_vertex(_node_world(_path[i + 1]))
		mesh.surface_end()
	_path_lines.mesh = mesh

func _refresh() -> void:
	(_unit.material_override as StandardMaterial3D).albedo_color = CLASS_COLORS[_unit_class()]
	if _show_nav:
		_draw_nav_cells()
	_draw_links()
	var standable := 0
	for x in GROUND:
		for z in GROUND:
			for level in world.levels_at(Vector2i(x, z)):
				if level > 0 and world.can_occupy(world.encode(Vector2i(x, z), level), _unit_class()):
					standable += 1
	_legend.text = "\n".join([
		"%s  --  %d solid blocks, %d nav cells, %d links, built from YAML" % [
			definition.display_name, definition.solid_cells.size(),
			definition.nav_cells.size(), definition.links.size()],
		"",
		"class: %s      gate: %s      your level: %d" % [
			_unit_class(), "OPEN" if _gate_open else "SHUT", _node.y],
		"cells above ground this class can stand on: %d" % standable,
		_last_message,
		"",
		"click to move   C class   G gate   N nav cells   L links   R reset",
	])

# --- input ------------------------------------------------------------------

func _apply_camera() -> void:
	var pitch := clampf(_orbit.x, -1.45, -0.05)
	var offset := Vector3(
		cos(pitch) * sin(_orbit.y), -sin(pitch), cos(pitch) * cos(_orbit.y)) * _distance
	_camera.look_at_from_position(_pivot.global_position + offset, _pivot.global_position, Vector3.UP)
	_camera.position = _camera.global_position - _pivot.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_start = event.position
			else:
				_dragging = false
				# A click, not a drag: orbiting should not also issue an order.
				if event.position.distance_to(_drag_start) < 6.0:
					var picked := _pick_node(event.position)
					if picked != Vector3i.MAX:
						_order_to(picked)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(8.0, _distance - 3.0)
			_apply_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(200.0, _distance + 3.0)
			_apply_camera()
	elif event is InputEventMouseMotion and _dragging:
		_orbit.y -= event.relative.x * 0.006
		_orbit.x -= event.relative.y * 0.005
		_apply_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_class_index = wrapi(_class_index + 1, 0, CLASSES.size())
				_path.clear()
				_draw_path()
				# A class that cannot stand where the last one did gets moved to
				# the ground rather than left floating inside a wall.
				if not world.can_occupy(world.encode(Vector2i(_node.x, _node.z), _node.y), _unit_class()):
					_reset_unit()
				else:
					_last_message = "switched class"
					_refresh()
			KEY_G:
				_gate_open = not _gate_open
				world.gate_states["main_gate_open"] = _gate_open
				_builder.set_gate_open(&"main_gate_open", _gate_open)
				_path.clear()
				_draw_path()
				_last_message = "gate %s" % ("opened" if _gate_open else "shut")
				_refresh()
			KEY_N:
				_show_nav = not _show_nav
				_nav_marks.visible = _show_nav
				if _show_nav:
					_draw_nav_cells()
			KEY_L:
				_show_links = not _show_links
				_link_lines.visible = _show_links
			KEY_R:
				_reset_unit()

var _drag_start := Vector2.ZERO
