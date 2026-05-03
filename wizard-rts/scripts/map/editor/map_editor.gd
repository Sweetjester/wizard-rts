class_name MapEditor
extends Node2D

const TILE_SIZE := Vector2i(64, 64)
const MAP_SIZE := Vector2i(64, 40)
const SAVE_PATH := "user://map_editor/current_map.json"
const EXPORT_DIR := "user://map_editor/exports"
const CONTENT_PLOT_PATH := "user://map_editor/content_plots/current_content_plot.json"
const CONTENT_PLOT_EXPORT_DIR := "user://map_editor/content_plots/exports"
const CONTENT_PLOT_ORIGIN := Vector2i(8, 7)

const WATER_SOURCE := 0
const TERRAIN_SOURCE_START := 10
const FOAM_SOURCE := 20
const BUSH_SOURCE_START := 30
const ROCK_SOURCE_START := 40
const WATER_ROCK_SOURCE_START := 50
const DYNAMIC_SOURCE_START := 1000
const MAP_ASSET_ROOTS := [
	"res://Tiny Swords/Tiny Swords (Free Pack)/Terrain",
	"res://Tiny Swords/Tiny Swords (Free Pack)/Buildings",
	"res://assets/tiles",
]
const MAX_SCANNED_ASSET_BRUSHES := 1200

const WATER_TEXTURE := preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Water Background color.png")
const FOAM_TEXTURE := preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Water Foam.png")
const TERRAIN_TEXTURES := [
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color2.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color3.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color4.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color5.png"),
]
const BUSH_TEXTURES := [
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe1.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe2.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe3.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe4.png"),
]
const ROCK_TEXTURES := [
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock1.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock2.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock3.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock4.png"),
]
const WATER_ROCK_TEXTURES := [
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_01.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_02.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_03.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_04.png"),
]

var water_layer: TileMapLayer
var ground_layer: TileMapLayer
var cliff_layer: TileMapLayer
var detail_layer: TileMapLayer
var marker_layer: TileMapLayer
var plot_bounds_layer: TileMapLayer
var preview_layer: TileMapLayer
var camera: Camera2D
var status_label: Label
var brush_label: Label
var terrain_label: Label
var coord_label: Label
var mode_label: Label
var metadata_panel: RichTextLabel
var palette_grid: GridContainer
var selected_preview: TextureRect

var _tile_set: TileSet
var _brushes: Array[Dictionary] = []
var _brush_index := 0
var _terrain_kind := "low"
var _next_dynamic_source_id := DYNAMIC_SOURCE_START
var _asset_brush_count := 0
var _editing_content_plot := false
var _content_plot_label := ""
var _content_plot_size := Vector2i.ZERO
var _content_plot_bounds := Rect2i()
var _cell_metadata: Dictionary = {}
var _dragging := false
var _panning := false
var _pan_origin := Vector2.ZERO
var _camera_origin := Vector2.ZERO

func _ready() -> void:
	_tile_set = _build_tileset()
	_build_layers()
	_build_ui()
	_build_brushes()
	_build_palette()
	_fill_water()
	_select_brush(0)
	_update_metadata_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)

func _process(_delta: float) -> void:
	var cell := _mouse_cell()
	coord_label.text = "Cell %s | %s" % [cell, _cell_metadata.get(cell, "unmarked")]

func _build_layers() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(MAP_SIZE * TILE_SIZE) * 0.5
	camera.zoom = Vector2(0.72, 0.72)
	camera.enabled = true
	add_child(camera)
	water_layer = _make_layer("Water", 0)
	ground_layer = _make_layer("Ground", 1)
	cliff_layer = _make_layer("CliffsAndRamps", 2)
	detail_layer = _make_layer("Decoration", 3)
	marker_layer = _make_layer("TerrainMarkers", 4)
	plot_bounds_layer = _make_layer("ContentPlotBounds", 5)
	preview_layer = _make_layer("BrushPreview", 6)

func _make_layer(layer_name: String, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = _tile_set
	layer.z_index = z
	if layer_name == "TerrainMarkers":
		layer.modulate = Color(1, 1, 1, 0.32)
	elif layer_name == "ContentPlotBounds":
		layer.modulate = Color(1.0, 0.78, 0.22, 0.42)
	elif layer_name == "BrushPreview":
		layer.modulate = Color(1.0, 1.0, 1.0, 0.62)
	add_child(layer)
	return layer

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(370, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	panel.add_child(side)

	var title := _make_label("Map Editor", 26, Color("#E9F4E1"))
	side.add_child(title)
	side.add_child(_make_label("Paint Tiny Swords terrain and declare gameplay meaning per cell.", 13, Color("#B8CDB9")))
	mode_label = _make_label("Mode: Full map", 15, Color("#9FD88A"))
	side.add_child(mode_label)

	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	side.add_child(tool_row)
	_add_button(tool_row, "Save", _save_map)
	_add_button(tool_row, "Load", _load_map)
	_add_button(tool_row, "Export", _export_map)
	_add_button(tool_row, "Clear", _clear_map)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	side.add_child(nav_row)
	_add_button(nav_row, "Menu", func() -> void: get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	_add_button(nav_row, "Fill Water", _fill_water)
	_add_button(nav_row, "Erase", func() -> void: _select_brush(_find_brush_index("erase")))

	side.add_child(_make_label("Content Plot Templates", 16, Color("#E0B84F")))
	var plot_row := GridContainer.new()
	plot_row.columns = 3
	plot_row.add_theme_constant_override("h_separation", 6)
	plot_row.add_theme_constant_override("v_separation", 6)
	side.add_child(plot_row)
	_add_button(plot_row, "Small 5x5", func() -> void: create_content_plot("small"))
	_add_button(plot_row, "Medium 10x10", func() -> void: create_content_plot("medium"))
	_add_button(plot_row, "Large 20x20", func() -> void: create_content_plot("large"))
	_add_button(plot_row, "Save Plot", _save_content_plot)
	_add_button(plot_row, "Load Plot", _load_content_plot)
	_add_button(plot_row, "Full Map", _switch_to_full_map_mode)

	side.add_child(_make_label("Terrain Declaration", 16, Color("#7DDDE8")))
	var terrain_row := GridContainer.new()
	terrain_row.columns = 3
	terrain_row.add_theme_constant_override("h_separation", 6)
	terrain_row.add_theme_constant_override("v_separation", 6)
	side.add_child(terrain_row)
	for terrain in ["low", "high", "ramp", "water", "blocked", "road", "plot", "anchor", "decor"]:
		var terrain_name: String = terrain
		_add_button(terrain_row, terrain_name.capitalize(), func(kind: String = terrain_name) -> void: _set_terrain_kind(kind))

	brush_label = _make_label("", 15, Color("#D6C7AE"))
	terrain_label = _make_label("", 15, Color("#D6C7AE"))
	coord_label = _make_label("", 13, Color("#9FD88A"))
	side.add_child(brush_label)
	side.add_child(terrain_label)
	side.add_child(coord_label)

	side.add_child(_make_label("Asset Palette", 16, Color("#7DDDE8")))
	selected_preview = TextureRect.new()
	selected_preview.custom_minimum_size = Vector2(330, 118)
	selected_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	selected_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	side.add_child(selected_preview)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	palette_grid = GridContainer.new()
	palette_grid.columns = 2
	palette_grid.add_theme_constant_override("h_separation", 6)
	palette_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(palette_grid)

	metadata_panel = RichTextLabel.new()
	metadata_panel.custom_minimum_size = Vector2(330, 150)
	metadata_panel.fit_content = false
	metadata_panel.scroll_active = false
	metadata_panel.bbcode_enabled = true
	side.add_child(metadata_panel)

	status_label = _make_label("Left paint | Right erase | Middle drag pan | Wheel zoom", 13, Color("#D6C7AE"))
	side.add_child(status_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 38)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_brushes() -> void:
	_brushes = [
		{"id": "erase", "name": "Erase", "layer": "all", "source": -1, "atlas": Vector2i.ZERO},
		{"id": "grass_mid", "name": "Grass Mid", "layer": "ground", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(1, 1)},
		{"id": "grass_light", "name": "Grass Light", "layer": "ground", "source": TERRAIN_SOURCE_START + 1, "atlas": Vector2i(1, 1)},
		{"id": "grass_dark", "name": "Grass Dark", "layer": "ground", "source": TERRAIN_SOURCE_START + 2, "atlas": Vector2i(1, 1)},
		{"id": "coast_top", "name": "Coast Top", "layer": "ground", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(1, 0)},
		{"id": "coast_bottom", "name": "Coast Bottom", "layer": "ground", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(1, 2)},
		{"id": "coast_left", "name": "Coast Left", "layer": "ground", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(0, 1)},
		{"id": "coast_right", "name": "Coast Right", "layer": "ground", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(2, 1)},
		{"id": "cliff_face", "name": "Cliff Face", "layer": "cliff", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(6, 4)},
		{"id": "cliff_face_alt", "name": "Cliff Face Alt", "layer": "cliff", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(7, 4)},
		{"id": "ramp_left", "name": "Ramp Left", "layer": "cliff", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(0, 4), "terrain": "ramp"},
		{"id": "ramp_right", "name": "Ramp Right", "layer": "cliff", "source": TERRAIN_SOURCE_START, "atlas": Vector2i(3, 4), "terrain": "ramp"},
		{"id": "foam", "name": "Water Foam", "layer": "detail", "source": FOAM_SOURCE, "atlas": Vector2i(0, 0), "terrain": "water"},
		{"id": "bush", "name": "Bush", "layer": "detail", "source": BUSH_SOURCE_START, "atlas": Vector2i(0, 0), "terrain": "decor"},
		{"id": "rock", "name": "Rock", "layer": "detail", "source": ROCK_SOURCE_START, "atlas": Vector2i.ZERO, "terrain": "blocked"},
		{"id": "water_rock", "name": "Water Rock", "layer": "detail", "source": WATER_ROCK_SOURCE_START, "atlas": Vector2i(0, 0), "terrain": "water"},
	]
	_add_scanned_asset_brushes()

func _add_scanned_asset_brushes() -> void:
	_asset_brush_count = 0
	var seen_paths := {}
	for root_path in MAP_ASSET_ROOTS:
		_scan_asset_folder(root_path, seen_paths)
	status_label.text = "Loaded %s map asset brushes." % _asset_brush_count

func _scan_asset_folder(folder_path: String, seen_paths: Dictionary) -> void:
	if _asset_brush_count >= MAX_SCANNED_ASSET_BRUSHES:
		return
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var child_path := "%s/%s" % [folder_path, file_name]
		if dir.current_is_dir():
			_scan_asset_folder(child_path, seen_paths)
		elif file_name.get_extension().to_lower() == "png" and not seen_paths.has(child_path):
			seen_paths[child_path] = true
			_add_texture_asset_brushes(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _add_texture_asset_brushes(texture_path: String) -> void:
	if _asset_brush_count >= MAX_SCANNED_ASSET_BRUSHES:
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var layer_name := _asset_layer_for_path(texture_path)
	var terrain_kind := _asset_terrain_for_path(texture_path)
	var source_id := _next_dynamic_source_id
	_next_dynamic_source_id += 1
	var region_size := _region_size_for_texture(texture)
	_tile_set.add_source(_atlas_source(texture, region_size), source_id)
	var atlas_size := Vector2i(maxi(1, texture.get_width() / region_size.x), maxi(1, texture.get_height() / region_size.y))
	var base_name := _asset_display_name(texture_path)
	for y in atlas_size.y:
		for x in atlas_size.x:
			if _asset_brush_count >= MAX_SCANNED_ASSET_BRUSHES:
				return
			var atlas := Vector2i(x, y)
			var suffix := "" if atlas_size == Vector2i.ONE else " %s,%s" % [x, y]
			_brushes.append({
				"id": "asset_%s_%s_%s" % [source_id, x, y],
				"name": "%s%s" % [base_name, suffix],
				"layer": layer_name,
				"source": source_id,
				"atlas": atlas,
				"terrain": terrain_kind,
				"texture": texture,
				"region_size": region_size,
				"asset_path": texture_path,
			})
			_asset_brush_count += 1

func _asset_layer_for_path(path: String) -> String:
	var lower := path.to_lower()
	if lower.contains("/decorations/") or lower.contains("/resources/") or lower.contains("rock") or lower.contains("tree") or lower.contains("bush"):
		return "detail"
	if lower.contains("cliff") or lower.contains("ramp") or lower.contains("wall") or lower.contains("castle") or lower.contains("building"):
		return "cliff"
	return "ground"

func _asset_terrain_for_path(path: String) -> String:
	var lower := path.to_lower()
	if lower.contains("water"):
		return "water"
	if lower.contains("road") or lower.contains("bridge"):
		return "road"
	if lower.contains("ramp"):
		return "ramp"
	if lower.contains("cliff") or lower.contains("wall") or lower.contains("rock") or lower.contains("tree") or lower.contains("building") or lower.contains("castle"):
		return "blocked"
	if lower.contains("bush") or lower.contains("decorations"):
		return "decor"
	return "low"

func _asset_display_name(path: String) -> String:
	var file_name := path.get_file().get_basename()
	file_name = file_name.replace("_", " ").replace("-", " ")
	return file_name.capitalize()

func _region_size_for_texture(texture: Texture2D) -> Vector2i:
	if texture.get_width() >= TILE_SIZE.x and texture.get_height() >= TILE_SIZE.y:
		if texture.get_width() % TILE_SIZE.x == 0 and texture.get_height() % TILE_SIZE.y == 0:
			return TILE_SIZE
	return Vector2i(texture.get_width(), texture.get_height())

func _build_palette() -> void:
	for child in palette_grid.get_children():
		child.queue_free()
	for i in _brushes.size():
		var brush := _brushes[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(164, 76)
		button.text = str(brush.get("name", brush.get("id", "Brush")))
		button.icon = _brush_preview_texture(brush)
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "%s\n%s" % [brush.get("name", ""), brush.get("asset_path", "Built-in brush")]
		button.pressed.connect(_select_brush.bind(i))
		palette_grid.add_child(button)

func _select_brush(index: int) -> void:
	_brush_index = clampi(index, 0, _brushes.size() - 1)
	var brush := _current_brush()
	if brush.has("terrain"):
		_terrain_kind = str(brush["terrain"])
	brush_label.text = "Brush: %s" % brush.get("name", "Unknown")
	terrain_label.text = "Declares: %s" % _terrain_kind.capitalize()
	if selected_preview != null:
		selected_preview.texture = _brush_preview_texture(brush)
	status_label.text = "Selected %s. Move over the grid to preview; left-click paints." % brush.get("name", "brush")

func _set_terrain_kind(kind: String) -> void:
	_terrain_kind = kind
	terrain_label.text = "Declares: %s" % _terrain_kind.capitalize()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		camera.zoom *= 0.9
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		camera.zoom *= 1.1
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
		_pan_origin = event.position
		_camera_origin = camera.position
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_paint_cell(_mouse_cell(), false)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_paint_cell(_mouse_cell(), true)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		camera.position = _camera_origin - (event.position - _pan_origin) / camera.zoom
	elif _dragging:
		_paint_cell(_mouse_cell(), false)
	else:
		_update_grid_preview()

func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_1:
			_select_brush(1)
		KEY_2:
			_select_brush(2)
		KEY_3:
			_select_brush(8)
		KEY_4:
			_select_brush(10)
		KEY_5:
			_select_brush(13)
		KEY_S:
			if event.ctrl_pressed:
				_save_map()
		KEY_L:
			if event.ctrl_pressed:
				_load_map()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _paint_cell(cell: Vector2i, erase: bool) -> void:
	if not _in_bounds(cell):
		return
	if _editing_content_plot and not _content_plot_bounds.has_point(cell):
		status_label.text = "Paint inside the %sx%s content plot bounds." % [_content_plot_size.x, _content_plot_size.y]
		return
	if erase:
		_erase_cell(cell)
		return
	var brush := _current_brush()
	if str(brush.get("id", "")) == "erase":
		_erase_cell(cell)
		return
	var layer := _layer_for(str(brush.get("layer", "ground")))
	if layer == null:
		return
	layer.set_cell(cell, int(brush["source"]), brush["atlas"])
	_cell_metadata[cell] = _terrain_kind
	_paint_marker(cell)
	_update_grid_preview()
	_update_metadata_panel()

func _erase_cell(cell: Vector2i) -> void:
	ground_layer.erase_cell(cell)
	cliff_layer.erase_cell(cell)
	detail_layer.erase_cell(cell)
	marker_layer.erase_cell(cell)
	preview_layer.erase_cell(cell)
	_cell_metadata.erase(cell)
	_update_metadata_panel()

func _paint_marker(cell: Vector2i) -> void:
	marker_layer.erase_cell(cell)
	match _terrain_kind:
		"water":
			marker_layer.set_cell(cell, WATER_SOURCE, Vector2i.ZERO)
		"blocked":
			marker_layer.set_cell(cell, TERRAIN_SOURCE_START + 3, Vector2i(6, 4))
		"ramp":
			marker_layer.set_cell(cell, TERRAIN_SOURCE_START + 4, Vector2i(3, 4))

func _fill_water() -> void:
	water_layer.clear()
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			water_layer.set_cell(Vector2i(x, y), WATER_SOURCE, Vector2i.ZERO)
	status_label.text = "Water base filled."

func _clear_map() -> void:
	ground_layer.clear()
	cliff_layer.clear()
	detail_layer.clear()
	marker_layer.clear()
	plot_bounds_layer.clear()
	preview_layer.clear()
	_cell_metadata.clear()
	_editing_content_plot = false
	_content_plot_label = ""
	_content_plot_size = Vector2i.ZERO
	_content_plot_bounds = Rect2i()
	_update_mode_label()
	_fill_water()
	_update_metadata_panel()
	status_label.text = "Cleared editable layers."

func _save_map() -> void:
	var data := _serialize_map()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://map_editor"))
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		status_label.text = "Save failed: %s" % FileAccess.get_open_error()
		return
	file.store_string(JSON.stringify(data, "\t"))
	status_label.text = "Saved to %s" % SAVE_PATH

func _load_map() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		status_label.text = "No saved editor map yet."
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		status_label.text = "Load failed: %s" % FileAccess.get_open_error()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "Load failed: invalid JSON."
		return
	_apply_map_data(parsed)
	status_label.text = "Loaded %s" % SAVE_PATH

func _export_map() -> void:
	var absolute_dir := ProjectSettings.globalize_path(EXPORT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := "%s/map_editor_export_%s.json" % [EXPORT_DIR, Time.get_unix_time_from_system()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status_label.text = "Export failed: %s" % FileAccess.get_open_error()
		return
	file.store_string(JSON.stringify(_serialize_map(), "\t"))
	status_label.text = "Exported to %s" % path

func _serialize_map() -> Dictionary:
	return {
		"version": 1,
		"kind": "content_plot_template" if _editing_content_plot else "map",
		"size": [MAP_SIZE.x, MAP_SIZE.y],
		"content_plot": _content_plot_data(),
		"cells": _layer_cells(),
		"terrain": _metadata_cells(),
	}

func _layer_cells() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	_collect_layer_cells(records, "ground", ground_layer)
	_collect_layer_cells(records, "cliff", cliff_layer)
	_collect_layer_cells(records, "detail", detail_layer)
	return records

func _collect_layer_cells(records: Array[Dictionary], layer_name: String, layer: TileMapLayer) -> void:
	for cell in layer.get_used_cells():
		records.append({
			"layer": layer_name,
			"x": cell.x,
			"y": cell.y,
			"source": layer.get_cell_source_id(cell),
			"atlas": [layer.get_cell_atlas_coords(cell).x, layer.get_cell_atlas_coords(cell).y],
		})

func _metadata_cells() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for cell in _cell_metadata.keys():
		records.append({"x": cell.x, "y": cell.y, "kind": _cell_metadata[cell]})
	return records

func _apply_map_data(data: Dictionary) -> void:
	_clear_map()
	var plot_data: Dictionary = data.get("content_plot", {})
	if str(data.get("kind", "")) == "content_plot_template" and not plot_data.is_empty():
		var size_data: Array = plot_data.get("size", [10, 10])
		var origin_data: Array = plot_data.get("origin", [CONTENT_PLOT_ORIGIN.x, CONTENT_PLOT_ORIGIN.y])
		_editing_content_plot = true
		_content_plot_label = str(plot_data.get("label", "Content Plot"))
		_content_plot_size = Vector2i(int(size_data[0]), int(size_data[1]))
		_content_plot_bounds = Rect2i(Vector2i(int(origin_data[0]), int(origin_data[1])), _content_plot_size)
	for record in data.get("cells", []):
		var cell := Vector2i(int(record.get("x", 0)), int(record.get("y", 0)))
		var atlas_data: Array = record.get("atlas", [0, 0])
		var layer := _layer_for(str(record.get("layer", "ground")))
		if layer != null:
			layer.set_cell(cell, int(record.get("source", -1)), Vector2i(int(atlas_data[0]), int(atlas_data[1])))
	for record in data.get("terrain", []):
		var cell := Vector2i(int(record.get("x", 0)), int(record.get("y", 0)))
		_cell_metadata[cell] = str(record.get("kind", "low"))
		_paint_marker(cell)
	_redraw_content_plot_bounds()
	_update_mode_label()
	_update_metadata_panel()

func _update_metadata_panel() -> void:
	if metadata_panel == null:
		return
	var counts := {}
	for kind in _cell_metadata.values():
		counts[kind] = int(counts.get(kind, 0)) + 1
	var lines := ["[b]Terrain counts[/b]"]
	if _editing_content_plot:
		lines.append("[color=#E0B84F]%s %sx%s[/color]" % [_content_plot_label, _content_plot_size.x, _content_plot_size.y])
		lines.append("Template rule: world roads branch to this plot using road/anchor cells.")
		lines.append("")
	for key in counts.keys():
		lines.append("%s: %s" % [str(key).capitalize(), counts[key]])
	lines.append("")
	lines.append("[b]Shortcuts[/b]")
	lines.append("1 grass | 2 light grass | 3 cliff | 4 ramp | 5 bush")
	lines.append("Ctrl+S save | Ctrl+L load | Esc menu")
	metadata_panel.text = "\n".join(lines)

func create_content_plot(size_name: String) -> void:
	match size_name:
		"small":
			_begin_content_plot("Small content plot", Vector2i(5, 5))
		"medium":
			_begin_content_plot("Medium content plot", Vector2i(10, 10))
		"large":
			_begin_content_plot("Large content plot", Vector2i(20, 20))
		_:
			_begin_content_plot("Medium content plot", Vector2i(10, 10))

func _begin_content_plot(label: String, plot_size: Vector2i) -> void:
	ground_layer.clear()
	cliff_layer.clear()
	detail_layer.clear()
	marker_layer.clear()
	plot_bounds_layer.clear()
	_cell_metadata.clear()
	_fill_water()
	_editing_content_plot = true
	_content_plot_label = label
	_content_plot_size = plot_size
	_content_plot_bounds = Rect2i(CONTENT_PLOT_ORIGIN, plot_size)
	for x in range(_content_plot_bounds.position.x, _content_plot_bounds.end.x):
		for y in range(_content_plot_bounds.position.y, _content_plot_bounds.end.y):
			var cell := Vector2i(x, y)
			ground_layer.set_cell(cell, TERRAIN_SOURCE_START, Vector2i(1, 1))
			_cell_metadata[cell] = "plot"
	_redraw_content_plot_bounds()
	_update_mode_label()
	_update_metadata_panel()
	camera.position = Vector2(_content_plot_bounds.get_center()) * Vector2(TILE_SIZE)
	camera.zoom = Vector2(1.0, 1.0)
	status_label.text = "%s created. Paint inside the gold bounds, then Save Plot." % label

func _switch_to_full_map_mode() -> void:
	_editing_content_plot = false
	_content_plot_label = ""
	_content_plot_size = Vector2i.ZERO
	_content_plot_bounds = Rect2i()
	plot_bounds_layer.clear()
	_update_mode_label()
	_update_metadata_panel()
	status_label.text = "Switched to full-map editing. Current painted cells were kept."

func _save_content_plot() -> void:
	if not _editing_content_plot:
		status_label.text = "Choose Small, Medium, or Large before saving a content plot."
		return
	var data := _serialize_map()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://map_editor/content_plots"))
	var file := FileAccess.open(CONTENT_PLOT_PATH, FileAccess.WRITE)
	if file == null:
		status_label.text = "Plot save failed: %s" % FileAccess.get_open_error()
		return
	file.store_string(JSON.stringify(data, "\t"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTENT_PLOT_EXPORT_DIR))
	var export_path := "%s/%s_%sx%s_%s.json" % [
		CONTENT_PLOT_EXPORT_DIR,
		_content_plot_label.to_snake_case(),
		_content_plot_size.x,
		_content_plot_size.y,
		Time.get_unix_time_from_system(),
	]
	var export_file := FileAccess.open(export_path, FileAccess.WRITE)
	if export_file != null:
		export_file.store_string(JSON.stringify(data, "\t"))
	status_label.text = "Saved plot to %s and exported a timestamped copy." % CONTENT_PLOT_PATH

func _load_content_plot() -> void:
	if not FileAccess.file_exists(CONTENT_PLOT_PATH):
		status_label.text = "No saved content plot yet."
		return
	var file := FileAccess.open(CONTENT_PLOT_PATH, FileAccess.READ)
	if file == null:
		status_label.text = "Plot load failed: %s" % FileAccess.get_open_error()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "Plot load failed: invalid JSON."
		return
	_apply_map_data(parsed)
	status_label.text = "Loaded content plot from %s" % CONTENT_PLOT_PATH

func _content_plot_data() -> Dictionary:
	if not _editing_content_plot:
		return {}
	return {
		"label": _content_plot_label,
		"size": [_content_plot_size.x, _content_plot_size.y],
		"origin": [_content_plot_bounds.position.x, _content_plot_bounds.position.y],
		"road_connection_policy": "branch_from_road",
		"stamp_rule": "World generator should place this template beside a road branch and align road/anchor cells to the branch endpoint.",
	}

func _redraw_content_plot_bounds() -> void:
	plot_bounds_layer.clear()
	if not _editing_content_plot:
		return
	for x in range(_content_plot_bounds.position.x, _content_plot_bounds.end.x):
		for y in range(_content_plot_bounds.position.y, _content_plot_bounds.end.y):
			var cell := Vector2i(x, y)
			if x == _content_plot_bounds.position.x or y == _content_plot_bounds.position.y or x == _content_plot_bounds.end.x - 1 or y == _content_plot_bounds.end.y - 1:
				plot_bounds_layer.set_cell(cell, TERRAIN_SOURCE_START + 4, Vector2i(1, 1))

func _update_mode_label() -> void:
	if mode_label == null:
		return
	if _editing_content_plot:
		mode_label.text = "Mode: %s (%sx%s)" % [_content_plot_label, _content_plot_size.x, _content_plot_size.y]
	else:
		mode_label.text = "Mode: Full map"

func _current_brush() -> Dictionary:
	return _brushes[_brush_index]

func _find_brush_index(id: String) -> int:
	for i in _brushes.size():
		if str(_brushes[i].get("id", "")) == id:
			return i
	return 0

func _layer_for(layer_name: String) -> TileMapLayer:
	match layer_name:
		"ground":
			return ground_layer
		"cliff":
			return cliff_layer
		"detail":
			return detail_layer
	return null

func _update_grid_preview() -> void:
	if preview_layer == null:
		return
	preview_layer.clear()
	var cell := _mouse_cell()
	if not _in_bounds(cell):
		return
	if _editing_content_plot and not _content_plot_bounds.has_point(cell):
		return
	var brush := _current_brush()
	if int(brush.get("source", -1)) < 0:
		return
	preview_layer.set_cell(cell, int(brush["source"]), brush["atlas"])

func _brush_preview_texture(brush: Dictionary) -> Texture2D:
	if brush.has("texture") and brush["texture"] is Texture2D:
		var texture: Texture2D = brush["texture"]
		var region_size: Vector2i = brush.get("region_size", TILE_SIZE)
		var atlas: Vector2i = brush.get("atlas", Vector2i.ZERO)
		if region_size.x < texture.get_width() or region_size.y < texture.get_height():
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = texture
			atlas_texture.region = Rect2(Vector2(atlas * region_size), Vector2(region_size))
			return atlas_texture
		return texture
	var source_id := int(brush.get("source", -1))
	if source_id < 0 or _tile_set == null or not _tile_set.has_source(source_id):
		return null
	var source := _tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or source.texture == null:
		return null
	var region := source.texture_region_size
	var atlas_coords: Vector2i = brush.get("atlas", Vector2i.ZERO)
	if region.x < source.texture.get_width() or region.y < source.texture.get_height():
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = source.texture
		atlas_texture.region = Rect2(Vector2(atlas_coords * region), Vector2(region))
		return atlas_texture
	return source.texture

func _mouse_cell() -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(get_global_mouse_position()))

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y

func _build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_source(_single_tile_source(WATER_TEXTURE), WATER_SOURCE)
	for i in TERRAIN_TEXTURES.size():
		tile_set.add_source(_atlas_source(TERRAIN_TEXTURES[i], TILE_SIZE), TERRAIN_SOURCE_START + i)
	tile_set.add_source(_atlas_source(FOAM_TEXTURE, TILE_SIZE), FOAM_SOURCE)
	for i in BUSH_TEXTURES.size():
		tile_set.add_source(_atlas_source(BUSH_TEXTURES[i], TILE_SIZE), BUSH_SOURCE_START + i)
	for i in ROCK_TEXTURES.size():
		tile_set.add_source(_single_tile_source(ROCK_TEXTURES[i]), ROCK_SOURCE_START + i)
	for i in WATER_ROCK_TEXTURES.size():
		tile_set.add_source(_atlas_source(WATER_ROCK_TEXTURES[i], TILE_SIZE), WATER_ROCK_SOURCE_START + i)
	return tile_set

func _single_tile_source(texture: Texture2D) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
	source.create_tile(Vector2i.ZERO)
	return source

func _atlas_source(texture: Texture2D, region_size: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = region_size
	var atlas_size := Vector2i(texture.get_width() / region_size.x, texture.get_height() / region_size.y)
	for x in atlas_size.x:
		for y in atlas_size.y:
			source.create_tile(Vector2i(x, y))
	return source
