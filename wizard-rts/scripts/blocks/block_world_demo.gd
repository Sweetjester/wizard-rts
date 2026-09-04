extends Node3D

# A walkable block world: terrain with elevation, structures placed on it, and
# agents that actually path through and into them.
#
# Run with:
#   Godot --path . res://scenes/blocks/block_world_demo.tscn
#
# Controls
#   Space   re-roll every agent's destination
#   P       show / hide the paths agents are following
#   N       show / hide nav cells for the selected class
#   C       cycle the class whose nav cells are shown
#   R       rebuild the world
#   drag / wheel   orbit and zoom
#
# What to look for: infantry and climbers walking up ramps onto plateaus and up
# stairs onto the gatehouse wall-walk, while heavies stay on the ground floor
# because they cannot use stairs. Every elevation change you see is an authored
# link, never an inferred step-up.

const AGENT_CLASSES: Array[StringName] = [&"infantry", &"infantry", &"archer", &"climber", &"heavy"]
const AGENT_COLORS := {
	&"infantry": Color("#4ADE80"),
	&"archer": Color("#38BDF8"),
	&"climber": Color("#C084FC"),
	&"heavy": Color("#FB923C"),
	&"flying": Color("#F472B6"),
}
const AGENT_COUNT := 18
const AGENT_SPEED := 3.4

# Origins are chosen not to overlap each other, the pond, or a plateau edge.
# The watchfort deliberately sits ON the south-west plateau: a structure's base
# level comes from the terrain under it, so the two elevation sources compose
# rather than fighting. An earlier version pinned every structure to level 0 and
# left them half-buried where the ground rose.
const STRUCTURE_PLACEMENTS := [
	{"id": &"fortress_gatehouse_02_walkable", "origin": Vector2i(4, 4)},
	{"id": &"hollowspire_tower_01", "origin": Vector2i(20, 4)},
	{"id": &"witchfire_ziggurat_01", "origin": Vector2i(4, 16)},
	{"id": &"broken_watchfort_01", "origin": Vector2i(4, 32)},
]

var terrain: Node
var library: BlockStructureLibrary
var world: BlockNavWorld

var _camera: Camera3D
var _pivot: Node3D
var _legend: Label
var _agents: Array[Dictionary] = []
var _agent_meshes: MultiMeshInstance3D
var _path_lines: MeshInstance3D
var _nav_marks: MultiMeshInstance3D

var _orbit := Vector2(-0.70, 0.75)
var _distance := 62.0
var _dragging := false
var _show_paths := true
var _show_nav := false
var _nav_class_index := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	library = BlockStructureLibrary.load_default()
	if library.structure_ids().is_empty():
		push_error("No block structures -- run tools/blocks/convert_structures.py")
		return
	_build_view()
	_build_world()

func _build_view() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#10131A")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#5C6474")
	env.ambient_light_energy = 0.85
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54.0, -40.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 900.0
	_camera.fov = 42.0
	_pivot.add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_legend = Label.new()
	_legend.position = Vector2(16, 12)
	_legend.add_theme_color_override("font_color", Color("#E2E8F0"))
	_legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_legend.add_theme_constant_override("outline_size", 5)
	layer.add_child(_legend)

func _build_world() -> void:
	for child in get_children():
		if child.name.begins_with("World"):
			child.queue_free()
	var root := Node3D.new()
	root.name = "WorldRoot"
	add_child(root)

	terrain = load("res://scripts/blocks/demo_block_terrain.gd").new()
	terrain.name = "DemoTerrain"
	add_child(terrain)

	world = BlockNavWorld.new(library.unit_classes)
	world.build_from_terrain(terrain)
	# Gates open, so the gatehouse reads as a route rather than a wall on first
	# look. Press G in the structure viewer to see the closed case.
	world.gate_states = {"gate_open": true}

	_draw_terrain(root)
	for placement in STRUCTURE_PLACEMENTS:
		var definition := library.get_definition(placement["id"])
		if definition == null:
			continue
		var base_level: int = int(terrain.call("get_height", placement["origin"]))
		world.place_structure(definition, placement["origin"], base_level, placement["id"])
		var builder := BlockStructureBuilder.new()
		builder.name = "Structure_%s" % placement["id"]
		root.add_child(builder)
		builder.build(definition)
		builder.position = Vector3(
			float(placement["origin"].x), float(base_level), float(placement["origin"].y))

	_pivot.position = Vector3(float(terrain.MAP_W) * 0.5, 2.0, float(terrain.MAP_H) * 0.5)
	_apply_camera()
	_spawn_agents(root)
	_build_overlays(root)
	_refresh_legend()

func _draw_terrain(root: Node3D) -> void:
	var blocks := terrain.call("column_blocks") as Array[Vector3i]
	var instance := MultiMeshInstance3D.new()
	instance.name = "Terrain"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = maxi(1, blocks.size())
	var index := 0
	for cell in blocks:
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY, Vector3(float(cell.x) + 0.5, float(cell.y) - 0.5, float(cell.z) + 0.5)))
		# Tinted by level so elevation reads without needing the debug overlay.
		var tint := Color("#3E4A38").lerp(Color("#8FA07E"), clampf(float(cell.y) / 4.0, 0.0, 1.0))
		multimesh.set_instance_color(index, tint)
		index += 1
	multimesh.visible_instance_count = index
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	instance.material_override = material
	root.add_child(instance)

# --- agents -----------------------------------------------------------------

func _spawn_agents(root: Node3D) -> void:
	_agents.clear()
	_agent_meshes = MultiMeshInstance3D.new()
	_agent_meshes.name = "Agents"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 1.1, 0.55)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = AGENT_COUNT
	_agent_meshes.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	_agent_meshes.material_override = material
	root.add_child(_agent_meshes)

	for i in AGENT_COUNT:
		var unit_class: StringName = AGENT_CLASSES[i % AGENT_CLASSES.size()]
		var start := _random_standable(unit_class)
		if start == Vector3i.MAX:
			continue
		_agents.append({
			"class": unit_class,
			"node": start,
			"path": [] as Array[Vector3i],
			"leg": 0,
			"t": 0.0,
			"position": _node_world(start),
		})
	_assign_destinations()

# A cell this class can actually stand in. Rejection-sampled rather than scanned,
# because the lattice is ~2500 nodes and most of them are fine.
#
# `prefer_elevated` biases toward anything above ground level -- plateaus, wall
# walks, upper floors. Without it most random destinations land on open ground
# and the demo mostly shows units walking about on the flat, which is exactly
# the behaviour this system was built NOT to be limited to.
func _random_standable(unit_class: StringName, prefer_elevated: bool = false) -> Vector3i:
	for attempt in 500:
		var cell := Vector2i(_rng.randi_range(0, terrain.MAP_W - 1), _rng.randi_range(0, terrain.MAP_H - 1))
		var levels := world.levels_at(cell)
		if levels.is_empty():
			continue
		var level: int = levels[_rng.randi_range(0, levels.size() - 1)]
		# Give up the preference near the end of the budget rather than
		# returning nothing: a heavy unit has no elevated cells it may stand on
		# at all, and it should still get somewhere to walk to.
		if prefer_elevated and attempt < 400 and level <= 0:
			continue
		if world.can_occupy(world.encode(cell, level), unit_class):
			return Vector3i(cell.x, level, cell.y)
	return Vector3i.MAX

func _assign_destinations() -> void:
	for agent in _agents:
		# Most agents look for somewhere high, so the interesting behaviour is
		# what you see rather than what you wait for.
		var prefer_elevated := _rng.randf() < 0.7
		for _attempt in 12:
			var goal := _random_standable(agent["class"], prefer_elevated)
			if goal == Vector3i.MAX or goal == agent["node"]:
				continue
			var from: Vector3i = agent["node"]
			var path := world.find_path(
				Vector2i(from.x, from.z), from.y, Vector2i(goal.x, goal.z), goal.y, agent["class"])
			if path.size() > 1:
				agent["path"] = path
				agent["leg"] = 0
				agent["t"] = 0.0
				break

func _process(delta: float) -> void:
	if _agents.is_empty():
		return
	var multimesh := _agent_meshes.multimesh
	var idle := 0
	for i in _agents.size():
		var agent: Dictionary = _agents[i]
		var path: Array = agent["path"]
		if path.size() > 1 and int(agent["leg"]) < path.size() - 1:
			var from := _node_world(path[int(agent["leg"])])
			var to := _node_world(path[int(agent["leg"]) + 1])
			var leg_length: float = maxf(0.001, from.distance_to(to))
			agent["t"] = float(agent["t"]) + delta * AGENT_SPEED / leg_length
			while float(agent["t"]) >= 1.0 and int(agent["leg"]) < path.size() - 1:
				agent["t"] = float(agent["t"]) - 1.0
				agent["leg"] = int(agent["leg"]) + 1
				agent["node"] = path[int(agent["leg"])]
				if int(agent["leg"]) >= path.size() - 1:
					agent["path"] = [] as Array[Vector3i]
					agent["t"] = 0.0
					break
			var current_path: Array = agent["path"]
			if current_path.size() > 1 and int(agent["leg"]) < current_path.size() - 1:
				agent["position"] = _node_world(current_path[int(agent["leg"])]).lerp(
					_node_world(current_path[int(agent["leg"]) + 1]), clampf(float(agent["t"]), 0.0, 1.0))
			else:
				agent["position"] = _node_world(agent["node"])
		else:
			idle += 1
			agent["position"] = _node_world(agent["node"])
		_agents[i] = agent
		multimesh.set_instance_transform(i,
			Transform3D(Basis.IDENTITY, agent["position"] + Vector3(0.0, 0.55, 0.0)))
		multimesh.set_instance_color(i, AGENT_COLORS.get(agent["class"], Color.WHITE))
	# Agents that arrived pick somewhere new, so the demo keeps moving without
	# anyone pressing anything.
	if idle >= _agents.size():
		_assign_destinations()
	if _show_paths:
		_draw_paths()

func _node_world(node: Vector3i) -> Vector3:
	return Vector3(float(node.x) + 0.5, float(node.y), float(node.z) + 0.5)

# --- overlays ---------------------------------------------------------------

func _build_overlays(root: Node3D) -> void:
	_path_lines = MeshInstance3D.new()
	_path_lines.name = "Paths"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	_path_lines.material_override = material
	_path_lines.visible = _show_paths
	root.add_child(_path_lines)

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
	_nav_marks.material_override = nav_material
	_nav_marks.visible = _show_nav
	root.add_child(_nav_marks)

func _draw_paths() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for agent in _agents:
		var path: Array = agent["path"]
		if path.size() < 2:
			continue
		var color: Color = AGENT_COLORS.get(agent["class"], Color.WHITE)
		for i in range(path.size() - 1):
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(_node_world(path[i]) + Vector3(0.0, 0.12, 0.0))
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(_node_world(path[i + 1]) + Vector3(0.0, 0.12, 0.0))
	mesh.surface_end()
	_path_lines.mesh = mesh

func _draw_nav_cells() -> void:
	var unit_class: Array = AGENT_COLORS.keys()
	var selected: StringName = unit_class[_nav_class_index % unit_class.size()]
	var multimesh := _nav_marks.multimesh
	var cells: Array[Vector3i] = []
	for x in terrain.MAP_W:
		for y in terrain.MAP_H:
			for level in world.levels_at(Vector2i(x, y)):
				if world.can_occupy(world.encode(Vector2i(x, y), level), selected):
					cells.append(Vector3i(x, level, y))
	multimesh.instance_count = maxi(1, cells.size())
	for i in cells.size():
		multimesh.set_instance_transform(i,
			Transform3D(Basis.IDENTITY, _node_world(cells[i]) + Vector3(0.0, 0.05, 0.0)))
		multimesh.set_instance_color(i, Color(AGENT_COLORS.get(selected, Color.WHITE), 0.35))
	multimesh.visible_instance_count = cells.size()

func _refresh_legend() -> void:
	var classes: Array = AGENT_COLORS.keys()
	var selected: StringName = classes[_nav_class_index % classes.size()]
	_legend.text = "\n".join([
		"Block world demo -- %d nav nodes across %d columns" % [world.node_count(), terrain.MAP_W * terrain.MAP_H],
		"%d agents  |  structures: %d" % [_agents.size(), world.placements().size()],
		"",
		"green infantry   blue archer   purple climber   orange heavy",
		"nav overlay class: %s  %s" % [selected, "(shown)" if _show_nav else "(hidden)"],
		"",
		"Space re-roll destinations   P paths   N nav cells   C class   R rebuild",
	])

# --- input ------------------------------------------------------------------

func _apply_camera() -> void:
	var pitch := clampf(_orbit.x, -1.45, -0.08)
	var offset := Vector3(
		cos(pitch) * sin(_orbit.y), -sin(pitch), cos(pitch) * cos(_orbit.y)) * _distance
	_camera.look_at_from_position(_pivot.global_position + offset, _pivot.global_position, Vector3.UP)
	_camera.position = _camera.global_position - _pivot.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(10.0, _distance - 3.0)
			_apply_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(300.0, _distance + 3.0)
			_apply_camera()
	elif event is InputEventMouseMotion and _dragging:
		_orbit.y -= event.relative.x * 0.006
		_orbit.x -= event.relative.y * 0.005
		_apply_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_assign_destinations()
			KEY_P:
				_show_paths = not _show_paths
				_path_lines.visible = _show_paths
			KEY_N:
				_show_nav = not _show_nav
				_nav_marks.visible = _show_nav
				if _show_nav:
					_draw_nav_cells()
				_refresh_legend()
			KEY_C:
				_nav_class_index += 1
				if _show_nav:
					_draw_nav_cells()
				_refresh_legend()
			KEY_R:
				_build_world()
