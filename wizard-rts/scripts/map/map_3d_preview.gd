extends Node3D

const MapGeneratorScript := preload("res://scripts/map/map_generator.gd")
const TERRAIN_TILESET: TileSet = preload("res://resources/tilesets/tiny_swords_plot_tileset.tres")

const TILE_SIZE := 1.0
const LOW_HEIGHT := 0.0
const HIGH_HEIGHT := 1.0
const RAMP_MID_HEIGHT := 0.5
const WATER_HEIGHT := -0.18
const SLAB_THICKNESS := 0.06
const ROAD_THICKNESS := 0.035
const PLOT_MARKER_THICKNESS := 0.04
const CAMERA_PAN_SPEED := 24.0
const CAMERA_ZOOM_STEP := 6.0
const CAMERA_MIN_DISTANCE := 20.0
const CAMERA_MAX_DISTANCE := 110.0

var _seed := 20260425
var _map_width := 0
var _map_height := 0
var _grid: Array = []
var _feature_grid: Array = []
var _road_cells: Dictionary = {}
var _plots: Array = []

var _data_root: Node
var _visual_root: Node3D
var _plot_overlay_root: Node3D
var _camera_rig: Node3D
var _camera: Camera3D
var _status_label: Label
var _show_plot_overlays := true
var _camera_distance := 58.0

var _materials := {}


func _ready() -> void:
	_create_materials()
	_create_camera()
	_create_light()
	_create_ui()
	_regenerate_map()


func _process(delta: float) -> void:
	if _camera_rig == null:
		return
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if input.length_squared() > 0.0:
		_camera_rig.position += input.normalized() * CAMERA_PAN_SPEED * delta
		_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_seed = int(Time.get_ticks_msec() & 0x7fffffff)
			_regenerate_map()
		elif event.keycode == KEY_P:
			_toggle_plot_overlays()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(CAMERA_MIN_DISTANCE, _camera_distance - CAMERA_ZOOM_STEP)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(CAMERA_MAX_DISTANCE, _camera_distance + CAMERA_ZOOM_STEP)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_print_cell_under_mouse(event.position)


func _create_materials() -> void:
	_materials["low"] = _material(Color("#56B35E"))
	_materials["high"] = _material(Color("#1E5F35"))
	_materials["ramp"] = _material(Color("#E3842A"))
	_materials["road"] = _material(Color("#9E3F2D"))
	_materials["water"] = _material(Color("#2C84C8"))
	_materials["blocker"] = _material(Color("#151718"))
	_materials["base_plot"] = _material(Color(1.0, 0.88, 0.16, 0.35))
	_materials["content_plot"] = _material(Color(0.72, 0.25, 1.0, 0.35))
	_materials["grid_line"] = _material(Color(0.1, 0.25, 0.2, 0.18))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _create_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	add_child(_camera_rig)

	_camera = Camera3D.new()
	_camera.name = "RTSCamera"
	_camera.current = true
	_camera.fov = 45.0
	_camera_rig.add_child(_camera)
	_update_camera_transform()


func _update_camera_transform() -> void:
	if _camera == null or _camera_rig == null:
		return
	_camera.position = Vector3(0.0, _camera_distance * 0.82, _camera_distance * 0.72)
	_camera.look_at(_camera_rig.global_position, Vector3.UP)


func _create_light() -> void:
	var light := DirectionalLight3D.new()
	light.name = "DebugSun"
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.7
	add_child(light)

	var ambient := WorldEnvironment.new()
	ambient.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#26302D")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9DB2A7")
	environment.ambient_light_energy = 0.65
	ambient.environment = environment
	add_child(ambient)


func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PreviewUI"
	add_child(canvas)

	var panel := HBoxContainer.new()
	panel.name = "Controls"
	panel.offset_left = 16
	panel.offset_top = 16
	panel.add_theme_constant_override("separation", 8)
	canvas.add_child(panel)

	var generate := Button.new()
	generate.text = "Regenerate (R)"
	generate.pressed.connect(_on_generate_pressed)
	panel.add_child(generate)

	var plots := Button.new()
	plots.text = "Toggle plots (P)"
	plots.pressed.connect(_toggle_plot_overlays)
	panel.add_child(plots)

	_status_label = Label.new()
	_status_label.text = "WASD pan | mouse wheel zoom | left click inspect"
	panel.add_child(_status_label)


func _on_generate_pressed() -> void:
	_seed = int(Time.get_ticks_msec() & 0x7fffffff)
	_regenerate_map()


func _regenerate_map() -> void:
	if _data_root != null and is_instance_valid(_data_root):
		_data_root.queue_free()
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()

	_data_root = Node.new()
	_data_root.name = "Generated2DData"
	add_child(_data_root)
	_add_hidden_tile_layers(_data_root)

	var previous_session_request = null
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		previous_session_request = session.get("new_game_requested")
		session.set("new_game_requested", false)

	var generator: Node = MapGeneratorScript.new()
	generator.name = "MapGenerator"
	generator.set("map_type_id", MapGenerator.MAP_TYPE_SEEDED_GRID_FRONTIER)
	generator.set("map_seed", _seed)
	generator.set("map_seed_text", "")
	generator.set("show_elevation_debug", false)
	_data_root.add_child(generator)

	if session != null and previous_session_request != null:
		session.set("new_game_requested", previous_session_request)

	# Generation is spread across frames now, so the grid is empty on the frame
	# the generator is added. Reading it here indexed _grid[0] on an empty array.
	if not bool(generator.get("generation_complete")):
		await generator.map_generated
	_read_map_data(generator)
	_render_map()


func _add_hidden_tile_layers(parent: Node) -> void:
	for layer_name in ["TileMapLow", "TileMapMid", "TileMapHigh"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = TERRAIN_TILESET
		layer.visible = false
		parent.add_child(layer)


func _read_map_data(generator: Node) -> void:
	_grid = generator.get("grid")
	_feature_grid = generator.get("feature_grid")
	_road_cells = generator.get("road_cells")
	_plots = generator.get("plots")
	_map_width = _grid.size()
	_map_height = _grid[0].size() if _map_width > 0 else 0
	if _status_label != null:
		_status_label.text = "Seed %s | %sx%s | plots %s | roads %s | P plots | R regen | click inspect" % [
			str(generator.call("get_seed_value")),
			_map_width,
			_map_height,
			_plots.size(),
			_road_cells.size()
		]
	print("[Map3DPreview] seed=", generator.call("get_seed_value"), " size=", _map_width, "x", _map_height, " plots=", _plots.size(), " road_cells=", _road_cells.size())


func _render_map() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "PreviewGeometry"
	add_child(_visual_root)

	var low_cells: Array[Vector2i] = []
	var high_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	var blocker_cells: Array[Vector2i] = []
	var road_overlay_cells: Array[Vector2i] = []
	var ramp_cells: Array[Vector2i] = []

	for x in range(_map_width):
		for y in range(_map_height):
			var cell := Vector2i(x, y)
			var elevation := int(_grid[x][y])
			match elevation:
				MapGenerator.E_WATER:
					water_cells.append(cell)
				MapGenerator.E_BLOCKED:
					blocker_cells.append(cell)
				MapGenerator.E_RAMP:
					ramp_cells.append(cell)
				MapGenerator.E_HIGH:
					high_cells.append(cell)
				_:
					low_cells.append(cell)
			if _is_road_cell(cell) and elevation != MapGenerator.E_RAMP:
				road_overlay_cells.append(cell)

	_add_multimesh("Water", water_cells, _box_mesh(Vector3(0.98, SLAB_THICKNESS, 0.98)), _materials["water"], WATER_HEIGHT)
	_add_multimesh("LowGround", low_cells, _box_mesh(Vector3(0.98, SLAB_THICKNESS, 0.98)), _materials["low"], LOW_HEIGHT - SLAB_THICKNESS * 0.5)
	_add_multimesh("HighGround", high_cells, _box_mesh(Vector3(0.98, HIGH_HEIGHT, 0.98)), _materials["high"], HIGH_HEIGHT * 0.5)
	_add_multimesh("RoadOverlay", road_overlay_cells, _box_mesh(Vector3(0.88, ROAD_THICKNESS, 0.88)), _materials["road"], 0.0, true)
	_add_multimesh("Blockers", blocker_cells, _box_mesh(Vector3(0.96, 1.35, 0.96)), _materials["blocker"], 0.675)
	_add_ramps(ramp_cells)
	_add_plot_markers()
	_center_camera()


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _add_multimesh(node_name: String, cells: Array[Vector2i], mesh: Mesh, material: Material, y_position: float, use_surface_height := false) -> void:
	if cells.is_empty():
		return
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = cells.size()
	for i in range(cells.size()):
		var cell := cells[i]
		var y := y_position
		if use_surface_height:
			y = _surface_height_for_cell(cell) + ROAD_THICKNESS * 0.5 + 0.015
		multi_mesh.set_instance_transform(i, Transform3D(Basis(), _cell_to_world(cell, y)))

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi_mesh
	instance.material_override = material
	_visual_root.add_child(instance)


func _add_ramps(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var ramp := MeshInstance3D.new()
		ramp.name = "Ramp_%s_%s" % [cell.x, cell.y]
		ramp.mesh = _ramp_mesh_for_cell(cell)
		ramp.material_override = _materials["ramp"]
		ramp.position = _cell_to_world(cell, 0.0)
		_visual_root.add_child(ramp)


func _ramp_mesh_for_cell(cell: Vector2i) -> ArrayMesh:
	var uphill := _find_high_neighbor_direction(cell)
	if uphill == Vector2i.ZERO:
		uphill = Vector2i(0, -1)
	var uphill_vector := Vector2(float(uphill.x), float(uphill.y)).normalized()
	var half := TILE_SIZE * 0.49
	var corners := [
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	]
	var verts := PackedVector3Array()
	for corner in corners:
		var projection: float = corner.normalized().dot(uphill_vector) if corner.length_squared() > 0.0 else 0.0
		var t := clampf((projection + 1.0) * 0.5, 0.0, 1.0)
		verts.append(Vector3(corner.x, lerpf(LOW_HEIGHT + 0.035, HIGH_HEIGHT + 0.035, t), corner.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _find_high_neighbor_direction(cell: Vector2i) -> Vector2i:
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var neighbor: Vector2i = cell + direction
		if _is_in_generated_bounds(neighbor) and int(_grid[neighbor.x][neighbor.y]) == MapGenerator.E_HIGH:
			return direction
	return Vector2i.ZERO


func _add_plot_markers() -> void:
	_plot_overlay_root = Node3D.new()
	_plot_overlay_root.name = "PlotOverlays"
	_plot_overlay_root.visible = _show_plot_overlays
	_visual_root.add_child(_plot_overlay_root)
	for plot in _plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var kind := str(plot.get("kind", ""))
		var marker := MeshInstance3D.new()
		marker.name = "Plot_%s" % str(plot.get("id", "plot"))
		marker.mesh = _box_mesh(Vector3(float(rect.size.x), PLOT_MARKER_THICKNESS, float(rect.size.y)))
		marker.material_override = _materials["base_plot"] if kind == "base" else _materials["content_plot"]
		var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
		marker.position = _cell_to_world(center, _surface_height_for_cell(center) + PLOT_MARKER_THICKNESS * 0.5 + 0.08)
		_plot_overlay_root.add_child(marker)


func _toggle_plot_overlays() -> void:
	_show_plot_overlays = not _show_plot_overlays
	if _plot_overlay_root != null and is_instance_valid(_plot_overlay_root):
		_plot_overlay_root.visible = _show_plot_overlays


func _center_camera() -> void:
	if _camera_rig == null:
		return
	_camera_rig.position = Vector3.ZERO
	_update_camera_transform()


func _cell_to_world(cell: Vector2i, y: float) -> Vector3:
	return Vector3(
		(float(cell.x) - float(_map_width) * 0.5 + 0.5) * TILE_SIZE,
		y,
		(float(cell.y) - float(_map_height) * 0.5 + 0.5) * TILE_SIZE
	)


func _world_to_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_position.x / TILE_SIZE + float(_map_width) * 0.5)),
		int(floor(world_position.z / TILE_SIZE + float(_map_height) * 0.5))
	)


func _surface_height_for_cell(cell: Vector2i) -> float:
	if not _is_in_generated_bounds(cell):
		return LOW_HEIGHT
	var elevation := int(_grid[cell.x][cell.y])
	match elevation:
		MapGenerator.E_HIGH:
			return HIGH_HEIGHT
		MapGenerator.E_RAMP:
			return RAMP_MID_HEIGHT
		MapGenerator.E_WATER:
			return WATER_HEIGHT
	return LOW_HEIGHT


func _is_road_cell(cell: Vector2i) -> bool:
	if _road_cells.has(cell):
		return true
	if _is_in_generated_bounds(cell):
		return str(_feature_grid[cell.x][cell.y]) == "path"
	return false


func _is_in_generated_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _map_width and cell.y < _map_height


func _print_cell_under_mouse(screen_position: Vector2) -> void:
	if _camera == null or _map_width <= 0 or _map_height <= 0:
		return
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.001:
		return
	var t := (0.0 - origin.y) / direction.y
	if t < 0.0:
		return
	var world := origin + direction * t
	var cell := _world_to_cell(world)
	if not _is_in_generated_bounds(cell):
		print("[Map3DPreview] Pick outside map at world=", world)
		return
	var elevation := int(_grid[cell.x][cell.y])
	var feature := str(_feature_grid[cell.x][cell.y])
	var type_name := _cell_type_name(cell, elevation, feature)
	print("[Map3DPreview] Pick cell=", cell, " type=", type_name, " elevation=", elevation, " feature=", feature, " road=", _is_road_cell(cell))


func _cell_type_name(cell: Vector2i, elevation: int, feature: String) -> String:
	if _is_road_cell(cell):
		return "ROAD"
	if feature == "base_floor" or feature == "economy_space":
		return "BASE_PLOT"
	if feature == "content_plot_blank":
		return "CONTENT_PLOT"
	match elevation:
		MapGenerator.E_WATER:
			return "WATER"
		MapGenerator.E_BLOCKED:
			return "BLOCKER"
		MapGenerator.E_RAMP:
			return "RAMP"
		MapGenerator.E_HIGH:
			return "HIGH"
	return "LOW"
