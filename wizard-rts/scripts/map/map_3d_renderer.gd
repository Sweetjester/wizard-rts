extends Node3D

const MapGeneratorScript := preload("res://scripts/map/map_generator.gd")
const AssetRegistryScript := preload("res://scripts/assets/asset_registry.gd")
const AssetPackConfigScript := preload("res://scripts/assets/asset_pack_config.gd")
const TERRAIN_TILESET: TileSet = preload("res://resources/tilesets/tiny_swords_plot_tileset.tres")
const ACTIVE_ASSET_PACK_CONFIG_PATH := "res://resources/asset_packs/tiny_swords_asset_pack.json"
const DARK_FOREST_V2_ASSET_PACK_CONFIG_PATH := "res://resources/asset_packs/dark_forest_frontier_v2_asset_pack.json"

const TILE_SIZE := 1.0
const LOW_HEIGHT := 0.0
const HIGH_HEIGHT := 1.0
const RAMP_MID_HEIGHT := 0.5
const WATER_HEIGHT := -0.22
const GROUND_THICKNESS := 0.08
const ROAD_THICKNESS := 0.035
const ROAD_SURFACE_OFFSET := 0.052
const ROAD_DEBUG_WIDTH := 0.82
const ROAD_BIOME_WIDTH := 1.16
const PLOT_MARKER_THICKNESS := 0.045
const BLOCKER_HEIGHT := 1.25
const RAMP_VISUAL_WIDTH := 1.16
const RAMP_TOP_LANDING := 0.48
const RAMP_BOTTOM_LANDING := 0.48

const CAMERA_PAN_SPEED := 24.0
const CAMERA_ROTATE_SPEED := 1.8
const CAMERA_ZOOM_STEP := 5.5
const CAMERA_MIN_DISTANCE := 16.0
const CAMERA_MAX_DISTANCE := 112.0
const CAMERA_PITCH_DEGREES := -52.0
const UNIT_SPEED := 5.4
const UNIT_RADIUS := 1.05
const UNIT_HEIGHT := 2.6
const UNIT_SURFACE_OFFSET := 0.16
const PATH_DEBUG_HEIGHT := 0.18
const DRAG_SELECT_THRESHOLD := 6.0
const UNIT_SCREEN_SELECT_PADDING := 64.0
const PRESENTATION_DEBUG := "DEBUG"
const PRESENTATION_BIOME := "BIOME"
const PRESENTATION_READABILITY := "READABILITY"
const STRUCTURE_VIEW_EXTERIOR := "EXTERIOR"
const STRUCTURE_VIEW_INTERIOR_CUTAWAY := "INTERIOR_CUTAWAY"
const STRUCTURE_VIEW_DEBUG_FLOORS := "DEBUG_FLOORS"

const CAT_LOW_GROUND_TILE := &"LOW_GROUND_TILE"
const CAT_HIGH_GROUND_TILE := &"HIGH_GROUND_TILE"
const CAT_ROAD_TILE := &"ROAD_TILE"
const CAT_WATER_TILE := &"WATER_TILE"
const CAT_CLIFF_SIDE := &"CLIFF_SIDE"
const CAT_CLIFF_CORNER := &"CLIFF_CORNER"
const CAT_RAMP_MESH := &"RAMP_MESH"
const CAT_TREE_BLOCKER := &"TREE_BLOCKER"
const CAT_ROCK_BLOCKER := &"ROCK_BLOCKER"
const CAT_MUSHROOM_BLOCKER := &"MUSHROOM_BLOCKER"
const CAT_ROOT_BLOCKER := &"ROOT_BLOCKER"
const CAT_RUIN_PROP := &"RUIN_PROP"
const CAT_SHRINE_PROP := &"SHRINE_PROP"
const CAT_TORCH_PROP := &"TORCH_PROP"
const CAT_ROAD_DECOR := &"ROAD_DECOR"
const CAT_WATER_EDGE_DECOR := &"WATER_EDGE_DECOR"
const CAT_BASE_PLOT_MARKER := &"BASE_PLOT_MARKER"
const CAT_CONTENT_PLOT_MARKER := &"CONTENT_PLOT_MARKER"
const CAT_OUTPOST_MARKER := &"OUTPOST_MARKER"
const CAT_ANCIENT_TREE_BLOCKER := &"ANCIENT_TREE_BLOCKER"
const CAT_TWISTED_ROOT_BLOCKER := &"TWISTED_ROOT_BLOCKER"
const CAT_DEAD_TREE_SPIKE := &"DEAD_TREE_SPIKE"
const CAT_MUSHROOM_CLUSTER_SMALL := &"MUSHROOM_CLUSTER_SMALL"
const CAT_MUSHROOM_CLUSTER_LARGE := &"MUSHROOM_CLUSTER_LARGE"
const CAT_ROCK_MOSS_CLUSTER := &"ROCK_MOSS_CLUSTER"
const CAT_ROOT_WALL_BLOCKER := &"ROOT_WALL_BLOCKER"
const CAT_RUINED_SHRINE := &"RUINED_SHRINE"
const CAT_CORRUPTED_ALTAR := &"CORRUPTED_ALTAR"
const CAT_BROKEN_STONE_ARCH := &"BROKEN_STONE_ARCH"
const CAT_GLOWING_MUSHROOM_RING := &"GLOWING_MUSHROOM_RING"
const CAT_TORCH_OR_SOUL_LIGHT := &"TORCH_OR_SOUL_LIGHT"
const CAT_BONE_DECOR := &"BONE_DECOR"
const CAT_ROAD_EDGE_ROOTS := &"ROAD_EDGE_ROOTS"
const CAT_LANTERN_TREE_BLOCKER := &"LANTERN_TREE_BLOCKER"

@export var seed := 20260425
@export_file("*.json", "*.tres") var asset_pack_config_path := ACTIVE_ASSET_PACK_CONFIG_PATH
@export var biome_name := "PROTOTYPE_DEFAULT"
@export var use_biome_mesh_assets := false
@export var use_biome_fog_and_lighting := false
@export var show_gameplay_probe := true
@export var use_monolith_test_map := false
@export_range(12, 20, 4) var monolith_footprint_size := 16
@export_range(1, 3, 1) var monolith_floor_count := 3
@export var monolith_floor_height := 1.8
@export_range(0.0, 1.0, 0.05) var monolith_room_density := 0.45
@export_range(0.0, 0.14, 0.005) var monolith_gap_density := 0.035
@export_range(0.0, 1.0, 0.05) var monolith_decor_density := 0.35
@export_enum("DEBUG", "BIOME", "READABILITY") var presentation_mode := PRESENTATION_DEBUG

# --- Embedded mode (added 2026-08-31) --------------------------------------
# This script is, and remains, a preview/prototyping tool: left to itself it
# builds its own MapGenerator, runs its own toy unit probe, and owns its own
# camera, UI and input. Building gameplay against that is the mistake this
# project has already made twice (see PROJECT_BRIEF's repo-layout section and
# the 2026-08-19 Decisions Log entry).
#
# Embedded mode is a narrow, additive API for the 3D game mode: the real 2D
# simulation stays authoritative and simply hands this script its live
# MapGenerator to draw. In embedded mode the script creates no generator, no
# camera, no UI, no probe, and consumes no input -- it is terrain geometry and
# nothing else.
var embedded_mode := false
var _map_generator: Node
var _map_width := 0
var _map_height := 0
var _grid: Array = []
var _feature_grid: Array = []
var _road_cells: Dictionary = {}
var _plots: Array = []
var _landmarks: Array = []
var _content_structures: Array = []
var _current_floor_focus := 0
var _visible_floors := {}
var _show_structure_debug := true
var _structure_view_mode := STRUCTURE_VIEW_EXTERIOR
var _structure_helpers_visible := true
var _rendered_floor_cell_count := 0

var _data_root: Node
var _visual_root: Node3D
var _terrain_root: Node3D
var _road_root: Node3D
var _ramp_root: Node3D
var _blocker_root: Node3D
var _plot_root: Node3D
var _readability_root: Node3D
var _structure_root: Node3D
var _gameplay_root: Node3D
var _path_root: Node3D
var _camera_rig: Node3D
var _camera_yaw: Node3D
var _camera: Camera3D
var _input_capture: Control
var _selection_rect: ColorRect
var _probe_screen_marker: Control
var _status_label: Label
var _floor_status_label: Label

var _show_plots := true
var _show_roads := true
var _show_ramps := true
var _show_blockers := true
var _show_path_debug := true
var _camera_distance := 58.0
var _yaw_radians := -PI * 0.25

var _materials := {}
var _tree_textures: Array[Texture2D] = []
var _rock_textures: Array[Texture2D] = []
var _mesh_assets := {}
var _asset_defs := {}
var _category_materials := {}
var _biome_asset_counts := {}
var _missing_asset_tags: Array[StringName] = []
var _missing_3d_categories: Array[StringName] = []
var _fallback_counts := {}
var _blocker_count := 0
var _biome_blocker_mesh_count := 0
var _biome_decor_count := 0
var _debug_overlay_count := 0
var _readability_overlay_count := 0
var _road_render_mode := "per_cell"
var _road_mesh_count := 0
var _ramp_visual_count := 0
var _ramp_debug_records: Array[String] = []
var _ramp_opening_carve_count := 0
var _ramps_missing_high_ground := 0
var _scene_instance_counts := {}
var _prop_scale_total := 0.0
var _prop_scale_count := 0
var _probe_unit: Node3D
var _selection_ring: MeshInstance3D
var _unit_label: Label3D
var _unit_beacon: MeshInstance3D
var _unit_selected := false
var _drag_selecting := false
var _drag_start := Vector2.ZERO
var _drag_current := Vector2.ZERO
var _unit_cell := Vector2i(-1, -1)
var _unit_path: Array[Vector2i] = []
var _unit_path_index := 0
var _unit_structure_id := ""
var _unit_floor := -1
var _unit_local_cell := Vector2i(-1, -1)
var _unit_interior_path: Array[Dictionary] = []
var _pending_enter_structure_id := ""
var _pending_enter_local_cell := Vector2i(-1, -1)
var _pending_stair_link: Dictionary = {}
var _probe_debug_visible := true
var _probe_missing_error_printed := false
var _probe_hidden_warning_printed := false
var _probe_invalid_position_warning_printed := false


func _ready() -> void:
	_create_materials()
	_apply_presentation_defaults()
	_load_registry_assets()
	if embedded_mode:
		# The host scene owns the camera, the lighting and the input. Terrain is
		# drawn on demand via render_live_map().
		return
	_create_camera()
	_create_light()
	_create_ui()
	_regenerate_map()


# Draw the terrain for an already-generated, live MapGenerator instead of
# building a private one. The generator is NOT reparented or modified -- this
# only reads its public grid/feature/road/plot data, exactly as _regenerate_map()
# does for its own.
func render_live_map(generator: Node) -> void:
	if generator == null or not is_instance_valid(generator):
		push_error("[Map3DRenderer] render_live_map called without a generator")
		return
	embedded_mode = true
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
		_visual_root = null
	_map_generator = generator
	_read_map_data(generator)
	_render_map()


# World-space conversion between the 2D simulation and this 3D view. The 2D game
# is 64px per cell; this renderer is TILE_SIZE per cell, so the two differ by a
# constant factor and a Y/Z swap. Everything that has to agree between the
# simulation and the view goes through these two functions.
const SIM_PIXELS_PER_CELL := 64.0

func sim_to_world_3d(sim_position: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(
		sim_position.x / SIM_PIXELS_PER_CELL * TILE_SIZE,
		height,
		sim_position.y / SIM_PIXELS_PER_CELL * TILE_SIZE
	)

func world_3d_to_sim(world_position: Vector3) -> Vector2:
	return Vector2(
		world_position.x / TILE_SIZE * SIM_PIXELS_PER_CELL,
		world_position.z / TILE_SIZE * SIM_PIXELS_PER_CELL
	)


# Size of the map this renderer actually drew, in cells. Used by the host view
# to frame the camera on the geometry rather than on the simulation's world
# bounds, which cover only the playable rect and leave the drawn map off-centre.
func rendered_map_size() -> Vector2i:
	return Vector2i(_map_width, _map_height)

func surface_height_at_cell(cell: Vector2i) -> float:
	if _grid.is_empty() or cell.x < 0 or cell.y < 0 or cell.x >= _map_width or cell.y >= _map_height:
		return LOW_HEIGHT
	var value: int = _grid[cell.x][cell.y]
	if value == MapGenerator.E_HIGH:
		return HIGH_HEIGHT
	if value == MapGenerator.E_RAMP:
		return RAMP_MID_HEIGHT
	if value == MapGenerator.E_WATER:
		return WATER_HEIGHT
	return LOW_HEIGHT


func _process(delta: float) -> void:
	if embedded_mode:
		return
	_update_camera_motion(delta)
	_update_probe_unit(delta)
	_update_probe_screen_marker()
	_validate_probe_runtime()


func _input(event: InputEvent) -> void:
	if embedded_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				seed = int(Time.get_ticks_msec() & 0x7fffffff)
				_regenerate_map()
			KEY_1:
				_set_plots_visible(not _show_plots)
			KEY_2:
				_set_roads_visible(not _show_roads)
			KEY_3:
				_set_ramps_visible(not _show_ramps)
			KEY_4:
				_set_blockers_visible(not _show_blockers)
			KEY_5:
				_set_path_debug_visible(not _show_path_debug)
			KEY_M:
				_toggle_presentation_mode()
			KEY_F:
				_focus_camera_on_probe()
			KEY_T:
				_teleport_probe_to_camera_center()
			KEY_V:
				_toggle_structure_helpers_visible()
			KEY_G:
				_spawn_or_reposition_probe_at_camera_center()
			KEY_C:
				_toggle_structure_cutaway_mode()
			KEY_BRACKETLEFT:
				_adjust_monolith_footprint(-1)
			KEY_BRACKETRIGHT:
				_adjust_monolith_footprint(1)
			KEY_PAGEUP:
				_cycle_floor_focus(1)
			KEY_PAGEDOWN:
				_cycle_floor_focus(-1)
			KEY_TAB:
				_cycle_occupied_floor_focus()
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_camera_distance = maxf(CAMERA_MIN_DISTANCE, _camera_distance - CAMERA_ZOOM_STEP)
				if _unit_floor >= 0:
					_set_floor_focus(_unit_floor)
				_update_camera_transform()
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera_distance = minf(CAMERA_MAX_DISTANCE, _camera_distance + CAMERA_ZOOM_STEP)
				if _content_structures.size() > 0 and _camera_distance > 62.0:
					_set_floor_focus(maxi(0, _current_floor_focus - 1))
				_update_camera_transform()


func _create_materials() -> void:
	if _uses_biome_presentation():
		_materials["low"] = _material(Color("#214C31"))
		_materials["high"] = _material(Color("#183B35"))
		_materials["high_side"] = _material(Color("#111A18"))
		_materials["ramp"] = _material(Color("#5A4930"))
		_materials["road"] = _material(Color("#4A3524"))
		_materials["water"] = _material(Color("#082A31"))
		_materials["blocker"] = _material(Color("#151A16"))
		_materials["base_plot"] = _material(Color(1.0, 0.84, 0.22, 0.08))
		_materials["content_plot"] = _material(Color(0.55, 0.24, 0.85, 0.08))
		_materials["ramp_carve_debug"] = _material(Color(0.7, 0.6, 0.25, 0.0))
		_materials["road_readability"] = _material(Color(0.78, 0.58, 0.34, 0.34 if _is_readability_mode() else 0.13))
		_materials["ramp_readability"] = _material(Color(0.95, 0.72, 0.38, 0.42 if _is_readability_mode() else 0.16))
		_materials["cliff_readability"] = _material(Color(0.5, 0.72, 0.72, 0.42 if _is_readability_mode() else 0.2))
	else:
		_materials["low"] = _material(Color("#58A95A"))
		_materials["high"] = _material(Color("#2E713F"))
		_materials["high_side"] = _material(Color("#244D2D"))
		_materials["ramp"] = _material(Color("#E8892E"))
		_materials["road"] = _material(Color("#A8432B"))
		_materials["water"] = _material(Color("#287BC1"))
		_materials["blocker"] = _material(Color("#27302A"))
		_materials["base_plot"] = _material(Color(1.0, 0.86, 0.12, 0.36))
		_materials["content_plot"] = _material(Color(0.67, 0.24, 1.0, 0.36))
		_materials["ramp_carve_debug"] = _material(Color(1.0, 0.95, 0.18, 0.48))
		_materials["road_readability"] = _material(Color(1.0, 0.1, 0.04, 0.45))
		_materials["ramp_readability"] = _material(Color(1.0, 0.55, 0.05, 0.5))
		_materials["cliff_readability"] = _material(Color(0.2, 0.9, 1.0, 0.45))
	_materials["content_reservation_outline"] = _material(Color(0.15, 0.95, 1.0, 0.82))
	_materials["content_debug_outline"] = _material(Color(1.0, 0.35, 1.0, 0.9))
	_materials["content_fallback_outline"] = _material(Color(1.0, 0.2, 0.08, 0.95))
	_materials["probe_unit"] = _material(Color("#00DFFF"))
	_materials["probe_unit_selected"] = _material(Color(1.0, 1.0, 1.0, 0.96))
	_materials["probe_path"] = _material(Color(0.2, 0.8, 1.0, 0.95))
	_materials["probe_beacon"] = _material(Color(1.0, 0.1, 0.78, 0.72))
	_materials["structure_floor"] = _material(Color(0.22, 0.25, 0.26, 0.88))
	_materials["structure_floor_active"] = _material(Color(0.42, 0.46, 0.48, 0.96))
	_materials["structure_floor_faint"] = _material(Color(0.22, 0.25, 0.26, 0.22))
	_materials["structure_wall"] = _material(Color(0.06, 0.075, 0.085, 0.96))
	_materials["structure_tower"] = _material(Color(0.06, 0.075, 0.085, 0.94 if _uses_biome_presentation() else 0.28))
	_materials["structure_tower_cutaway"] = _material(Color(0.06, 0.075, 0.085, 0.16))
	_materials["structure_blocker"] = _material(Color(0.11, 0.08, 0.12, 0.9))
	_materials["structure_gap"] = _material(Color(0.0, 0.0, 0.0, 0.48))
	_materials["structure_stair"] = _material(Color(0.95, 0.55, 0.18, 0.92))
	_materials["structure_room"] = _material(Color(0.7, 0.25, 1.0, 0.22))
	_materials["structure_rune"] = _material(Color(0.76, 0.11, 0.14, 0.95))
	_make_material_emissive(_materials["probe_unit"], Color("#00DFFF"), 0.8)
	_make_material_emissive(_materials["probe_beacon"], Color("#FF28B7"), 1.15)
	_make_material_emissive(_materials["structure_rune"], Color("#C13030"), 1.35)
	_make_material_no_depth(_materials["probe_unit"])
	_make_material_no_depth(_materials["probe_unit_selected"])
	_make_material_no_depth(_materials["probe_beacon"])
	_make_material_no_depth(_materials["probe_path"])


func _is_readability_mode() -> bool:
	return presentation_mode == PRESENTATION_READABILITY


func _uses_biome_presentation() -> bool:
	return presentation_mode == PRESENTATION_BIOME or presentation_mode == PRESENTATION_READABILITY


func _apply_presentation_defaults() -> void:
	if _uses_biome_presentation():
		asset_pack_config_path = DARK_FOREST_V2_ASSET_PACK_CONFIG_PATH
		biome_name = "DARK_FOREST_FRONTIER_V2"
		use_biome_mesh_assets = true
		use_biome_fog_and_lighting = true
		_show_plots = false
		_show_roads = true
		_show_ramps = true
		_show_blockers = true
		_show_path_debug = false
		_show_structure_debug = false
	else:
		_show_plots = true
		_show_roads = true
		_show_ramps = true
		_show_blockers = true
		_show_path_debug = true
		_show_structure_debug = true


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_material_emissive(material: Material, color: Color, energy: float) -> void:
	var standard := material as StandardMaterial3D
	if standard == null:
		return
	standard.emission_enabled = true
	standard.emission = color
	standard.emission_energy_multiplier = energy


func _make_material_no_depth(material: Material) -> void:
	var standard := material as StandardMaterial3D
	if standard == null:
		return
	standard.no_depth_test = true
	standard.render_priority = 8


func _load_registry_assets() -> void:
	var registry: Node = AssetRegistryScript.new()
	if not bool(registry.call("load_asset_pack", asset_pack_config_path)):
		return
	_tree_textures = _load_textures_from_paths(registry.call("list_prop_assets", AssetPackConfigScript.TREE))
	_rock_textures = _load_textures_from_paths(registry.call("list_prop_assets", AssetPackConfigScript.ROCK))
	_mesh_assets.clear()
	_asset_defs.clear()
	_category_materials.clear()
	_biome_asset_counts.clear()
	_missing_asset_tags.clear()
	_missing_3d_categories.clear()
	_fallback_counts.clear()
	for category in _replacement_categories():
		_load_3d_category(registry, category)
	_apply_category_materials()
	for tag in [
		AssetPackConfigScript.CLIFF_EDGE,
		AssetPackConfigScript.RAMP,
		AssetPackConfigScript.TREE,
		AssetPackConfigScript.ROCK,
		AssetPackConfigScript.RUIN,
		AssetPackConfigScript.DECOR,
	]:
		var scenes := _load_scenes_from_paths(registry.call("list_mesh_assets", tag))
		_mesh_assets[tag] = scenes
		_biome_asset_counts[str(tag)] = scenes.size()
		if scenes.is_empty() and use_biome_mesh_assets:
			_missing_asset_tags.append(tag)


func _replacement_categories() -> Array[StringName]:
	return [
		CAT_LOW_GROUND_TILE,
		CAT_HIGH_GROUND_TILE,
		CAT_ROAD_TILE,
		CAT_WATER_TILE,
		CAT_CLIFF_SIDE,
		CAT_CLIFF_CORNER,
		CAT_RAMP_MESH,
		CAT_TREE_BLOCKER,
		CAT_ROCK_BLOCKER,
		CAT_MUSHROOM_BLOCKER,
		CAT_ROOT_BLOCKER,
		CAT_RUIN_PROP,
		CAT_SHRINE_PROP,
		CAT_TORCH_PROP,
		CAT_ROAD_DECOR,
		CAT_WATER_EDGE_DECOR,
		CAT_BASE_PLOT_MARKER,
		CAT_CONTENT_PLOT_MARKER,
		CAT_OUTPOST_MARKER,
		CAT_ANCIENT_TREE_BLOCKER,
		CAT_TWISTED_ROOT_BLOCKER,
		CAT_DEAD_TREE_SPIKE,
		CAT_MUSHROOM_CLUSTER_SMALL,
		CAT_MUSHROOM_CLUSTER_LARGE,
		CAT_ROCK_MOSS_CLUSTER,
		CAT_ROOT_WALL_BLOCKER,
		CAT_RUINED_SHRINE,
		CAT_CORRUPTED_ALTAR,
		CAT_BROKEN_STONE_ARCH,
		CAT_GLOWING_MUSHROOM_RING,
		CAT_TORCH_OR_SOUL_LIGHT,
		CAT_BONE_DECOR,
		CAT_ROAD_EDGE_ROOTS,
		CAT_LANTERN_TREE_BLOCKER,
	]


func _load_3d_category(registry: Node, category: StringName) -> void:
	var defs: Array = registry.call("get_3d_category_asset_defs", category)
	var loaded_defs: Array[Dictionary] = []
	for def_value in defs:
		var definition: Dictionary = def_value
		var path := str(definition.get("path", ""))
		if path != "":
			var scene := load(path) as PackedScene
			if scene != null:
				var item := definition.duplicate(true)
				item["scene"] = scene
				loaded_defs.append(item)
	var material: Material = registry.call("load_3d_category_material", category)
	if material != null:
		_category_materials[category] = material
	_asset_defs[category] = loaded_defs
	_biome_asset_counts[str(category)] = loaded_defs.size() + (1 if material != null else 0)
	if loaded_defs.is_empty() and material == null:
		_missing_3d_categories.append(category)


func _apply_category_materials() -> void:
	if not _uses_biome_presentation():
		return
	_apply_category_material(CAT_LOW_GROUND_TILE, "low")
	_apply_category_material(CAT_HIGH_GROUND_TILE, "high")
	_apply_category_material(CAT_ROAD_TILE, "road")
	_apply_category_material(CAT_WATER_TILE, "water")
	_apply_category_material(CAT_BASE_PLOT_MARKER, "base_plot")
	_apply_category_material(CAT_CONTENT_PLOT_MARKER, "content_plot")


func _has_category_visual(category: StringName) -> bool:
	if _category_materials.has(category):
		return true
	var defs: Array = _asset_defs.get(category, [])
	return not defs.is_empty()


func _first_available_category(categories: Array[StringName]) -> StringName:
	for category in categories:
		if _has_category_visual(category):
			return category
	return categories[0] if not categories.is_empty() else StringName()


func _apply_category_material(category: StringName, material_key: String) -> void:
	var material: Material = _category_materials.get(category, null)
	if material != null:
		_materials[material_key] = material


func _load_scenes_from_paths(paths: Array) -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	for path_value in paths:
		var scene := load(str(path_value)) as PackedScene
		if scene != null:
			scenes.append(scene)
	return scenes


func _load_textures_from_paths(paths: Array) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for path_value in paths:
		var texture := load(str(path_value)) as Texture2D
		if texture != null:
			textures.append(texture)
	return textures


func _create_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	add_child(_camera_rig)

	_camera_yaw = Node3D.new()
	_camera_yaw.name = "Yaw"
	_camera_rig.add_child(_camera_yaw)

	_camera = Camera3D.new()
	_camera.name = "RTSCamera"
	_camera.current = true
	_camera.fov = 43.0
	_camera_yaw.add_child(_camera)
	_update_camera_transform()


func _update_camera_motion(delta: float) -> void:
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
		var basis := Basis(Vector3.UP, _yaw_radians)
		_camera_rig.position += basis * input.normalized() * CAMERA_PAN_SPEED * delta
	if Input.is_key_pressed(KEY_Q):
		_yaw_radians += CAMERA_ROTATE_SPEED * delta
		_update_camera_transform()
	if Input.is_key_pressed(KEY_E):
		_yaw_radians -= CAMERA_ROTATE_SPEED * delta
		_update_camera_transform()


func _update_camera_transform() -> void:
	if _camera == null or _camera_yaw == null:
		return
	_camera_yaw.rotation.y = _yaw_radians
	if _uses_biome_presentation():
		_camera.position = Vector3(0.0, _camera_distance * 0.68, _camera_distance * 0.82)
		_camera.rotation_degrees = Vector3(-46.0, 0.0, 0.0)
	else:
		_camera.position = Vector3(0.0, _camera_distance * 0.78, _camera_distance * 0.72)
		_camera.rotation_degrees = Vector3(CAMERA_PITCH_DEGREES, 0.0, 0.0)


func _create_light() -> void:
	for node_name in ["PrototypeSun", "MoonKey", "WorldEnvironment"]:
		var existing := get_node_or_null(node_name)
		if existing != null:
			remove_child(existing)
			existing.queue_free()
	var light := DirectionalLight3D.new()
	light.name = "MoonKey" if _uses_biome_presentation() else "PrototypeSun"
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0) if _uses_biome_presentation() else Vector3(-58.0, -36.0, 0.0)
	light.light_color = Color("#C8DEFF") if _uses_biome_presentation() else Color.WHITE
	light.light_energy = 1.45 if _uses_biome_presentation() else 1.7
	light.shadow_enabled = _uses_biome_presentation()
	add_child(light)

	var ambient := WorldEnvironment.new()
	ambient.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#10201C") if _uses_biome_presentation() else Color("#202A27")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#4A6358") if _uses_biome_presentation() else Color("#B2C2AD")
	environment.ambient_light_energy = 0.58 if _uses_biome_presentation() else 0.72
	if _uses_biome_presentation():
		environment.fog_enabled = true
		environment.fog_light_color = Color("#233A34")
		environment.fog_density = 0.011
		environment.fog_sky_affect = 0.42
	ambient.environment = environment
	add_child(ambient)


func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PrototypeUI"
	add_child(canvas)

	_input_capture = Control.new()
	_input_capture.name = "PrototypeInputCapture"
	_input_capture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_capture.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_capture.gui_input.connect(_on_input_capture_gui_input)
	canvas.add_child(_input_capture)

	_selection_rect = ColorRect.new()
	_selection_rect.name = "DragSelectionRect"
	_selection_rect.color = Color(0.2, 0.75, 1.0, 0.18)
	_selection_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_rect.visible = false
	canvas.add_child(_selection_rect)

	_probe_screen_marker = _make_probe_screen_marker()
	canvas.add_child(_probe_screen_marker)

	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.offset_left = 16
	controls.offset_top = 16
	controls.add_theme_constant_override("separation", 8)
	canvas.add_child(controls)

	var regenerate := Button.new()
	regenerate.text = "Regenerate"
	regenerate.tooltip_text = "Generate a new map seed (R)"
	regenerate.pressed.connect(_on_regenerate_pressed)
	controls.add_child(regenerate)

	controls.add_child(_make_toggle("Biome", _uses_biome_presentation(), _on_biome_mode_toggled))
	var readability := Button.new()
	readability.text = "Readability"
	readability.tooltip_text = "Highlight terrain language without full debug colors"
	readability.pressed.connect(func(): _set_presentation_mode(PRESENTATION_READABILITY))
	controls.add_child(readability)
	controls.add_child(_make_toggle("Plots", _show_plots, _set_plots_visible))
	controls.add_child(_make_toggle("Roads", _show_roads, _set_roads_visible))
	controls.add_child(_make_toggle("Ramps", _show_ramps, _set_ramps_visible))
	controls.add_child(_make_toggle("Blockers", _show_blockers, _set_blockers_visible))
	controls.add_child(_make_toggle("Path", _show_path_debug, _set_path_debug_visible))

	_status_label = Label.new()
	_status_label.text = "Mode %s | C cutaway | PageUp/PageDown floors | Tab probe floor | F focus probe | V floor helpers | [ ] monolith size" % presentation_mode
	controls.add_child(_status_label)

	_floor_status_label = Label.new()
	_floor_status_label.name = "FloorStatus"
	_floor_status_label.offset_left = 16
	_floor_status_label.offset_top = 52
	_floor_status_label.add_theme_font_size_override("font_size", 18)
	_floor_status_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	_floor_status_label.add_theme_color_override("font_shadow_color", Color("#000000"))
	_floor_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_floor_status_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_floor_status_label)
	_update_floor_status_ui()


func _make_probe_screen_marker() -> Control:
	var marker := Control.new()
	marker.name = "ProbeScreenMarker"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.custom_minimum_size = Vector2(92.0, 54.0)
	marker.size = marker.custom_minimum_size

	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.color = Color(0.0, 0.85, 1.0, 0.88)
	dot.position = Vector2(31.0, 0.0)
	dot.size = Vector2(30.0, 30.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(dot)

	var label := Label.new()
	label.name = "Label"
	label.text = "PROBE"
	label.position = Vector2(0.0, 28.0)
	label.size = Vector2(92.0, 26.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
	return marker


func _make_toggle(label: String, pressed: bool, callback: Callable) -> CheckBox:
	var toggle := CheckBox.new()
	toggle.text = label
	toggle.button_pressed = pressed
	toggle.toggled.connect(callback)
	return toggle


func _on_regenerate_pressed() -> void:
	seed = int(Time.get_ticks_msec() & 0x7fffffff)
	_regenerate_map()


func _on_biome_mode_toggled(enabled: bool) -> void:
	_set_presentation_mode(PRESENTATION_BIOME if enabled else PRESENTATION_DEBUG)


func _toggle_presentation_mode() -> void:
	match presentation_mode:
		PRESENTATION_DEBUG:
			_set_presentation_mode(PRESENTATION_BIOME)
		PRESENTATION_BIOME:
			_set_presentation_mode(PRESENTATION_READABILITY)
		_:
			_set_presentation_mode(PRESENTATION_DEBUG)


func _set_presentation_mode(mode: String) -> void:
	if presentation_mode == mode:
		return
	presentation_mode = mode
	_create_materials()
	_apply_presentation_defaults()
	_load_registry_assets()
	_apply_category_materials()
	_update_camera_transform()
	_create_light()
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
	if _gameplay_root != null and is_instance_valid(_gameplay_root):
		_gameplay_root.queue_free()
	if _map_width > 0 and _map_height > 0:
		_render_map()
		if show_gameplay_probe:
			_create_gameplay_probe()


func _regenerate_map() -> void:
	if _data_root != null and is_instance_valid(_data_root):
		_data_root.queue_free()
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
	if _gameplay_root != null and is_instance_valid(_gameplay_root):
		_gameplay_root.queue_free()

	if use_monolith_test_map:
		_regenerate_monolith_test_map()
		return

	_data_root = Node.new()
	_data_root.name = "GeneratedLogicalMapData"
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
	generator.set("map_seed", seed)
	generator.set("map_seed_text", "")
	generator.set("show_elevation_debug", false)
	generator.set("show_visual_props", false)
	_data_root.add_child(generator)

	if session != null and previous_session_request != null:
		session.set("new_game_requested", previous_session_request)

	_map_generator = generator
	_read_map_data(generator)
	_render_map()
	if show_gameplay_probe:
		_create_gameplay_probe()


func _regenerate_monolith_test_map() -> void:
	_data_root = Node.new()
	_data_root.name = "MonolithTestLogicalData"
	add_child(_data_root)
	_map_generator = null
	_map_width = 32
	_map_height = 32
	_grid.clear()
	_feature_grid.clear()
	_road_cells.clear()
	_plots.clear()
	_landmarks.clear()
	_content_structures.clear()
	for x in range(_map_width):
		var grid_col: Array[int] = []
		var feature_col: Array[String] = []
		for y in range(_map_height):
			grid_col.append(MapGenerator.E_LOW)
			feature_col.append("frontier_canvas")
		_grid.append(grid_col)
		_feature_grid.append(feature_col)
	var footprint := _allowed_monolith_footprint(monolith_footprint_size)
	monolith_footprint_size = footprint
	monolith_floor_count = clampi(monolith_floor_count, 1, 3)
	monolith_floor_height = maxf(1.0, monolith_floor_height)
	var structure_rect := Rect2i(Vector2i((_map_width - footprint) / 2, (_map_height - footprint) / 2 - 1), Vector2i(footprint, footprint))
	var generator = preload("res://scripts/map/content_structures/ContentStructureGenerator.gd").new()
	var structure: Dictionary = generator.generate_abandoned_wizard_monolith(
		"test_abandoned_wizard_monolith",
		structure_rect,
		seed,
		_monolith_generation_options()
	)
	var plot_rect := _expanded_rect_local(structure_rect, 1)
	var plot := {
		"id": "test_monolith_plot",
		"name": "Abandoned Wizard Monolith Test Plot",
		"kind": "content_blank",
		"content_size": "large",
		"content_archetype": "abandoned_wizard_monolith",
		"rect": plot_rect,
		"debug_render_rect": plot_rect,
		"reservation_rect": _expanded_rect_local(plot_rect, 2),
		"has_interior": true,
		"structure_type": "ABANDONED_WIZARD_MONOLITH",
		"structure_id": structure["id"],
		"structure_rect": structure_rect,
		"footprint_size": structure["footprint_size"],
		"floor_count": structure["floor_count"],
		"entrance_cells": structure["entrance_cells"],
		"stair_links": structure["stair_links"],
		"discovered_floors": structure["discovered_floors"],
		"occupied_floors": structure["occupied_floors"],
		"content_structure": structure,
		"anchor": structure["entrance_cells"][0],
		"road_anchor": structure["entrance_cells"][0] + Vector2i(0, 3),
	}
	_plots.append(plot)
	_content_structures.append(structure)
	for x in range(structure_rect.position.x, structure_rect.end.x):
		for y in range(structure_rect.position.y, structure_rect.end.y):
			_grid[x][y] = MapGenerator.E_LOW
			_feature_grid[x][y] = "content_structure_exterior"
			var edge := x == structure_rect.position.x or x == structure_rect.end.x - 1 or y == structure_rect.position.y or y == structure_rect.end.y - 1
			if edge:
				_grid[x][y] = MapGenerator.E_BLOCKED
				_feature_grid[x][y] = "content_structure_wall"
	var entrance: Vector2i = structure["entrance_cells"][0]
	for cell in [entrance, entrance + Vector2i(-1, 0), entrance + Vector2i(1, 0), entrance + Vector2i(0, 1), entrance + Vector2i(0, 2), entrance + Vector2i(0, 3)]:
		if _is_in_generated_bounds(cell):
			_grid[cell.x][cell.y] = MapGenerator.E_LOW
			_feature_grid[cell.x][cell.y] = "content_structure_entrance"
			_road_cells[cell] = true
	print("[Map3DPrototype] Monolith test map generated structure=", structure.get("id", ""),
		" footprint=", structure.get("footprint_size", Vector2i.ZERO),
		" floor_count=", structure.get("floor_count", 0),
		" floor_height=", structure.get("floor_height", 0.0),
		" room_density=", structure.get("room_density", 0.0),
		" gap_density=", structure.get("gap_density", 0.0),
		" decor_density=", structure.get("decor_density", 0.0),
		" validation=", structure.get("validation", {}),
		" entrance=", entrance)
	_render_map()
	if show_gameplay_probe:
		_create_gameplay_probe()


func _expanded_rect_local(rect: Rect2i, margin: int) -> Rect2i:
	return Rect2i(rect.position - Vector2i(margin, margin), rect.size + Vector2i(margin * 2, margin * 2))


func _monolith_generation_options() -> Dictionary:
	return {
		"footprint_size": _allowed_monolith_footprint(monolith_footprint_size),
		"floor_count": clampi(monolith_floor_count, 1, 3),
		"floor_height": maxf(1.0, monolith_floor_height),
		"room_density": clampf(monolith_room_density, 0.0, 1.0),
		"gap_density": clampf(monolith_gap_density, 0.0, 0.14),
		"decor_density": clampf(monolith_decor_density, 0.0, 1.0),
	}


func _allowed_monolith_footprint(value: int) -> int:
	var allowed: Array[int] = [12, 16, 20]
	var best: int = allowed[0]
	var best_distance := absi(value - best)
	for candidate: int in allowed:
		var distance := absi(value - candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


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
	_landmarks = generator.get("landmarks")
	_content_structures.clear()
	for plot in _plots:
		if bool(plot.get("has_interior", false)):
			var structure: Dictionary = plot.get("content_structure", {})
			if not structure.is_empty():
				_content_structures.append(structure)
	_map_width = _grid.size()
	_map_height = _grid[0].size() if _map_width > 0 else 0
	if _status_label != null:
		_status_label.text = "Mode %s | Structure %s | Floor %s | Seed %s | C cutaway | PageUp/PageDown | F probe" % [
			presentation_mode,
			_structure_view_mode,
			_current_floor_focus,
			str(generator.call("get_seed_value")),
		]
	_update_floor_status_ui()
	print("[Map3DPrototype] seed=", generator.call("get_seed_value"), " size=", _map_width, "x", _map_height, " plots=", _plots.size(), " roads=", _road_cells.size(), " landmarks=", _landmarks.size(), " structures=", _content_structures.size())


func _render_map() -> void:
	_debug_overlay_count = 0
	_readability_overlay_count = 0
	_road_render_mode = "combined_overlap" if _uses_biome_presentation() else "combined_debug_overlay"
	_road_mesh_count = 0
	_ramp_visual_count = 0
	_ramp_debug_records.clear()
	_ramp_opening_carve_count = 0
	_ramps_missing_high_ground = 0
	_rendered_floor_cell_count = 0
	_scene_instance_counts.clear()
	_prop_scale_total = 0.0
	_prop_scale_count = 0
	_visual_root = Node3D.new()
	_visual_root.name = "PrototypeGeometry"
	add_child(_visual_root)

	_terrain_root = _add_root("Terrain", true)
	_road_root = _add_root("Roads", _show_roads)
	_ramp_root = _add_root("Ramps", _show_ramps)
	_blocker_root = _add_root("Blockers", _show_blockers)
	_plot_root = _add_root("PlotMarkers", _show_plots)
	_readability_root = _add_root("TerrainReadability", _uses_biome_presentation())
	_structure_root = _add_root("ContentStructures", true)

	var low_cells: Array[Vector2i] = []
	var high_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	var blocker_cells: Array[Vector2i] = []
	var cliff_edge_cells: Array[Vector2i] = []
	var ramp_cells: Array[Vector2i] = []
	var road_cells_flat: Array[Vector2i] = []
	var road_cells_ramp: Array[Vector2i] = []
	var ramp_carve_debug_cells: Array[Vector2i] = []

	for x in range(_map_width):
		for y in range(_map_height):
			var cell := Vector2i(x, y)
			var elevation := int(_grid[x][y])
			match elevation:
				MapGenerator.E_WATER:
					water_cells.append(cell)
				MapGenerator.E_BLOCKED:
					blocker_cells.append(cell)
					low_cells.append(cell)
				MapGenerator.E_RAMP:
					ramp_cells.append(cell)
				MapGenerator.E_HIGH, MapGenerator.E_MID:
					high_cells.append(cell)
					if _is_cliff_edge_cell(cell):
						cliff_edge_cells.append(cell)
				_:
					low_cells.append(cell)
			if _is_road_cell(cell):
				if elevation == MapGenerator.E_RAMP:
					road_cells_ramp.append(cell)
				elif elevation != MapGenerator.E_WATER:
					road_cells_flat.append(cell)
			if _is_ramp_carve_debug_cell(cell):
				ramp_carve_debug_cells.append(cell)

	_add_multimesh(_terrain_root, "Water", water_cells, _box_mesh(Vector3(0.98, GROUND_THICKNESS, 0.98)), _materials["water"], WATER_HEIGHT - GROUND_THICKNESS * 0.5)
	_add_multimesh(_terrain_root, "LowGround", low_cells, _box_mesh(Vector3(0.98, GROUND_THICKNESS, 0.98)), _materials["low"], LOW_HEIGHT - GROUND_THICKNESS * 0.5)
	_add_multimesh(_terrain_root, "HighPlateaus", high_cells, _box_mesh(Vector3(0.98, HIGH_HEIGHT, 0.98)), _materials["high"], HIGH_HEIGHT * 0.5)
	_add_biome_cliff_edges(cliff_edge_cells)
	_add_road_surface(road_cells_flat)
	if not _uses_biome_presentation():
		_add_multimesh(_terrain_root, "RampCarveDebug", ramp_carve_debug_cells, _box_mesh(Vector3(0.92, 0.05, 0.92)), _materials["ramp_carve_debug"], 0.0, true)
		_debug_overlay_count += ramp_carve_debug_cells.size()
	_add_ramps(ramp_cells)
	_add_ramp_roads(road_cells_ramp)
	_add_terrain_readability_overlays(road_cells_flat, ramp_cells, cliff_edge_cells)
	_add_blockers(blocker_cells)
	_add_biome_decor()
	_add_landmark_visuals()
	_add_content_structures()
	_add_plot_markers()
	_center_camera()
	_print_biome_debug(cliff_edge_cells.size())


func _add_root(root_name: String, visible: bool) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	root.visible = visible
	_visual_root.add_child(root)
	return root


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _add_multimesh(parent: Node3D, node_name: String, cells: Array[Vector2i], mesh: Mesh, material: Material, y_position: float, use_surface_height := false) -> void:
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
			y = _surface_height_for_cell(cell) + ROAD_THICKNESS * 0.5 + 0.018
		multi_mesh.set_instance_transform(i, Transform3D(Basis(), _cell_to_world(cell, y)))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi_mesh
	instance.material_override = material
	parent.add_child(instance)


func _add_road_surface(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var mesh := _road_surface_mesh(cells, ROAD_BIOME_WIDTH if _uses_biome_presentation() else ROAD_DEBUG_WIDTH)
	var instance := MeshInstance3D.new()
	instance.name = "RoadSurface"
	instance.mesh = mesh
	instance.material_override = _materials["road"]
	_road_root.add_child(instance)
	_road_mesh_count = 1


func _road_surface_mesh(cells: Array[Vector2i], width: float) -> ArrayMesh:
	var half := width * 0.5
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for cell in cells:
		var center := _cell_to_world(cell, _surface_height_for_cell(cell) + ROAD_SURFACE_OFFSET)
		var base := verts.size()
		verts.append(center + Vector3(-half, 0.0, -half))
		verts.append(center + Vector3(half, 0.0, -half))
		verts.append(center + Vector3(half, 0.0, half))
		verts.append(center + Vector3(-half, 0.0, half))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_terrain_readability_overlays(road_cells: Array[Vector2i], ramp_cells: Array[Vector2i], cliff_cells: Array[Vector2i]) -> void:
	if not _uses_biome_presentation() or _readability_root == null:
		return
	_add_readability_road_overlay(road_cells)
	_add_readability_ramp_overlays(ramp_cells)
	_add_cliff_rim_overlays(cliff_cells)


func _add_readability_road_overlay(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var instance := MeshInstance3D.new()
	instance.name = "ReadableRoadHighlight"
	instance.mesh = _road_surface_mesh(cells, ROAD_BIOME_WIDTH * (1.03 if _is_readability_mode() else 0.92))
	instance.material_override = _materials["road_readability"]
	_readability_root.add_child(instance)
	_readability_overlay_count += 1


func _add_readability_ramp_overlays(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var uphill := _find_high_neighbor_direction(cell)
		if uphill == Vector2i.ZERO:
			uphill = Vector2i(0, -1)
		var instance := MeshInstance3D.new()
		instance.name = "ReadableRamp_%s_%s" % [cell.x, cell.y]
		instance.mesh = _embedded_ramp_mesh_for_cell(cell, uphill, RAMP_VISUAL_WIDTH * 1.04, 0.064)
		instance.material_override = _materials["ramp_readability"]
		_readability_root.add_child(instance)
		_readability_overlay_count += 1


func _add_cliff_rim_overlays(cells: Array[Vector2i]) -> void:
	var rim_cells: Array[Vector2i] = []
	for cell in cells:
		if _hash_cell(cell, 319) % (1 if _is_readability_mode() else 2) == 0:
			rim_cells.append(cell)
	if rim_cells.is_empty():
		return
	_add_multimesh(_readability_root, "ReadableCliffRims", rim_cells, _box_mesh(Vector3(0.98, 0.055, 0.98)), _materials["cliff_readability"], HIGH_HEIGHT + 0.055)
	_readability_overlay_count += rim_cells.size()


func _add_ramps(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var uphill := _find_high_neighbor_direction(cell)
		if uphill == Vector2i.ZERO:
			_ramps_missing_high_ground += 1
			uphill = Vector2i(0, -1)
		else:
			_ramp_opening_carve_count += 1
		var ramp := MeshInstance3D.new()
		ramp.name = "Ramp_%s_%s" % [cell.x, cell.y]
		ramp.mesh = _embedded_ramp_mesh_for_cell(cell, uphill, RAMP_VISUAL_WIDTH, 0.034)
		ramp.material_override = _materials["ramp"]
		_ramp_root.add_child(ramp)
		_ramp_visual_count += 1
		# Procedural ramp mesh stays the ground truth for slope/collision; RAMP_MESH is a
		# stone-step/rubble accent laid on top of the low end, same pattern as cliff edges.
		_try_add_category_scene(CAT_RAMP_MESH, _ramp_root, cell, LOW_HEIGHT, _rotation_for_direction(uphill))
		_ramp_debug_records.append("%s dir=%s top=%.2f bottom=%.2f missing_high=%s" % [str(cell), str(uphill), HIGH_HEIGHT, LOW_HEIGHT, str(_find_high_neighbor_direction(cell) == Vector2i.ZERO)])


func _add_ramp_roads(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var uphill := _find_high_neighbor_direction(cell)
		if uphill == Vector2i.ZERO:
			uphill = Vector2i(0, -1)
		var road := MeshInstance3D.new()
		road.name = "RampRoad_%s_%s" % [cell.x, cell.y]
		road.mesh = _embedded_ramp_mesh_for_cell(cell, uphill, ROAD_BIOME_WIDTH * 0.72, ROAD_SURFACE_OFFSET + 0.018)
		road.material_override = _materials["road"]
		_road_root.add_child(road)
		_road_mesh_count += 1


func _ramp_mesh_for_cell(cell: Vector2i, width: float, y_offset: float) -> ArrayMesh:
	var uphill := _find_high_neighbor_direction(cell)
	if uphill == Vector2i.ZERO:
		uphill = Vector2i(0, -1)
	var high_sign := Vector2(float(uphill.x), float(uphill.y)).normalized()
	var half := width * 0.5
	var corners := [
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	]
	var verts := PackedVector3Array()
	for corner in corners:
		var projection: float = corner.dot(high_sign) / maxf(half, 0.001)
		var t := clampf((projection + 1.0) * 0.5, 0.0, 1.0)
		verts.append(Vector3(corner.x, lerpf(LOW_HEIGHT, HIGH_HEIGHT, t) + y_offset, corner.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _embedded_ramp_mesh_for_cell(cell: Vector2i, uphill: Vector2i, width: float, y_offset: float) -> ArrayMesh:
	var high_dir := Vector2(float(uphill.x), float(uphill.y)).normalized()
	if high_dir == Vector2.ZERO:
		high_dir = Vector2(0.0, -1.0)
	var side := Vector2(-high_dir.y, high_dir.x)
	var center := _cell_to_world(cell, 0.0)
	var half_width := width * 0.5
	var along_points := [
		-0.5 - RAMP_BOTTOM_LANDING,
		-0.5,
		0.5,
		0.5 + RAMP_TOP_LANDING,
	]
	var heights := [
		LOW_HEIGHT + y_offset,
		LOW_HEIGHT + y_offset,
		HIGH_HEIGHT + y_offset,
		HIGH_HEIGHT + y_offset,
	]
	var verts := PackedVector3Array()
	for i in range(along_points.size()):
		var along: float = along_points[i]
		var left := center + Vector3(high_dir.x * along + side.x * -half_width, heights[i], high_dir.y * along + side.y * -half_width)
		var right := center + Vector3(high_dir.x * along + side.x * half_width, heights[i], high_dir.y * along + side.y * half_width)
		verts.append(left)
		verts.append(right)
	var indices := PackedInt32Array()
	for segment in range(along_points.size() - 1):
		var base := segment * 2
		indices.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _find_high_neighbor_direction(cell: Vector2i) -> Vector2i:
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var neighbor: Vector2i = cell + direction
		if _is_in_generated_bounds(neighbor):
			var elevation := int(_grid[neighbor.x][neighbor.y])
			if elevation == MapGenerator.E_HIGH or elevation == MapGenerator.E_MID:
				return direction
	for distance in range(2, 5):
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var neighbor: Vector2i = cell + direction * distance
			if _is_in_generated_bounds(neighbor):
				var elevation := int(_grid[neighbor.x][neighbor.y])
				if elevation == MapGenerator.E_HIGH or elevation == MapGenerator.E_MID:
					return direction
	return Vector2i.ZERO


func _add_blockers(cells: Array[Vector2i]) -> void:
	_blocker_count = cells.size()
	_biome_blocker_mesh_count = 0
	var cube_cells: Array[Vector2i] = []
	for cell in cells:
		if use_biome_mesh_assets:
			var category := _blocker_category_for_cell(cell)
			if _try_add_category_scene(category, _blocker_root, cell, _surface_height_for_cell(cell)):
				_biome_blocker_mesh_count += 1
				_add_blocker_cluster_props(cell, category)
				continue
		if _try_add_billboard_blocker(cell):
			continue
		cube_cells.append(cell)
	_add_multimesh(_blocker_root, "PlaceholderBlockers", cube_cells, _box_mesh(Vector3(0.72, BLOCKER_HEIGHT, 0.72)), _materials["blocker"], BLOCKER_HEIGHT * 0.5)


func _add_blocker_cluster_props(center: Vector2i, primary_category: StringName) -> void:
	if not _uses_biome_presentation():
		return
	var offsets: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, -1),
		Vector2i(-1, -1),
	]
	var placed := 0
	var target := 1 + (_hash_cell(center, 211) % 3)
	for offset in offsets:
		if placed >= target:
			return
		var roll_cell := center + offset
		if not _can_place_cluster_prop(roll_cell):
			continue
		if _hash_cell(roll_cell, 213) % 5 < 2:
			continue
		var category := _cluster_category_for_cell(roll_cell, primary_category)
		if _try_add_category_scene(category, _blocker_root, roll_cell, _surface_height_for_cell(roll_cell)):
			_biome_blocker_mesh_count += 1
			placed += 1


func _can_place_cluster_prop(cell: Vector2i) -> bool:
	if not _is_in_generated_bounds(cell):
		return false
	if _is_road_cell(cell):
		return false
	var elevation := int(_grid[cell.x][cell.y])
	return elevation == MapGenerator.E_LOW or elevation == MapGenerator.E_HIGH or elevation == MapGenerator.E_MID or elevation == MapGenerator.E_BLOCKED


func _cluster_category_for_cell(cell: Vector2i, primary_category: StringName) -> StringName:
	var roll := _hash_cell(cell, 217) % 10
	if primary_category == CAT_ROCK_BLOCKER or primary_category == CAT_ROCK_MOSS_CLUSTER:
		return _first_available_category([CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER]) if roll < 4 else _first_available_category([CAT_ROCK_MOSS_CLUSTER, CAT_ROCK_BLOCKER])
	if roll < 4:
		return _first_available_category([CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER])
	if roll < 7:
		return _first_available_category([CAT_MUSHROOM_CLUSTER_SMALL, CAT_MUSHROOM_BLOCKER])
	if roll == 9:
		return _first_available_category([CAT_LANTERN_TREE_BLOCKER, CAT_ANCIENT_TREE_BLOCKER, CAT_TREE_BLOCKER])
	return _first_available_category([CAT_ANCIENT_TREE_BLOCKER, CAT_TREE_BLOCKER])


func _add_biome_cliff_edges(cells: Array[Vector2i]) -> void:
	if not use_biome_mesh_assets:
		return
	for cell in cells:
		if _is_ramp_opening_cliff_cell(cell):
			_ramp_opening_carve_count += 1
			continue
		var direction := _first_low_neighbor_direction(cell)
		var category := CAT_CLIFF_CORNER if _is_cliff_corner_cell(cell) else CAT_CLIFF_SIDE
		_try_add_category_scene(category, _terrain_root, cell, LOW_HEIGHT, _rotation_for_direction(direction))


func _add_biome_decor() -> void:
	_biome_decor_count = 0
	if not use_biome_mesh_assets:
		return
	for plot in _plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
		var plot_kind := str(plot.get("kind", ""))
		var marker_cell := _clamp_cell(center)
		if plot_kind == "base":
			if _try_add_category_scene(CAT_BASE_PLOT_MARKER, _blocker_root, marker_cell, _surface_height_for_cell(marker_cell)):
				_biome_decor_count += 1
		elif plot_kind == "content_blank":
			var content_archetype := str(plot.get("content_archetype", ""))
			var is_hostile_archetype := content_archetype.contains("outpost") or content_archetype.contains("camp") or content_archetype.contains("ambush")
			var marker_category := CAT_OUTPOST_MARKER if is_hostile_archetype else CAT_CONTENT_PLOT_MARKER
			# Offset from the plot center: the center cell is where _add_biome_decor below
			# places a standing shrine/altar/arch prop, which would otherwise fully occlude
			# this flat, low-profile marker if both landed on the same cell.
			var content_marker_cell := _clamp_cell(center + Vector2i(-3, 3))
			if _try_add_category_scene(marker_category, _blocker_root, content_marker_cell, _surface_height_for_cell(content_marker_cell)):
				_biome_decor_count += 1
		if str(plot.get("kind", "")) == "content_blank":
			var prop_roll := _hash_cell(center, 140) % 4
			var prop_category := _first_available_category([CAT_RUINED_SHRINE, CAT_RUIN_PROP])
			if prop_roll == 1:
				prop_category = _first_available_category([CAT_CORRUPTED_ALTAR, CAT_SHRINE_PROP])
			elif prop_roll == 2:
				prop_category = _first_available_category([CAT_BROKEN_STONE_ARCH, CAT_RUIN_PROP])
			elif prop_roll == 3:
				prop_category = _first_available_category([CAT_GLOWING_MUSHROOM_RING, CAT_MUSHROOM_BLOCKER])
			if _try_add_category_scene(prop_category, _blocker_root, _clamp_cell(center), _surface_height_for_cell(_clamp_cell(center))):
				_biome_decor_count += 1
			_add_content_plot_decor(center)
		var torch_cell := _clamp_cell(center + Vector2i(2, 1))
		if _is_walkable_cell(torch_cell) and _hash_cell(torch_cell, 99) % 2 == 0:
			if _try_add_category_scene(_first_available_category([CAT_TORCH_OR_SOUL_LIGHT, CAT_TORCH_PROP]), _blocker_root, torch_cell, _surface_height_for_cell(torch_cell)):
				_biome_decor_count += 1
	for road_cell in _road_cells.keys():
		var cell: Vector2i = road_cell
		if _hash_cell(cell, 150) % (145 if _uses_biome_presentation() else 420) == 0:
			if _try_add_category_scene(_first_available_category([CAT_ROAD_EDGE_ROOTS, CAT_ROAD_DECOR]), _blocker_root, cell, _surface_height_for_cell(cell)):
				_biome_decor_count += 1
	for x in range(_map_width):
		for y in range(_map_height):
			var cell := Vector2i(x, y)
			if int(_grid[x][y]) == MapGenerator.E_WATER and _is_water_edge_cell(cell) and _hash_cell(cell, 151) % 20 == 0:
				if _try_add_category_scene(_first_available_category([CAT_MUSHROOM_CLUSTER_SMALL, CAT_WATER_EDGE_DECOR]), _blocker_root, cell, WATER_HEIGHT):
					_biome_decor_count += 1


func _add_landmark_visuals() -> void:
	if not use_biome_mesh_assets:
		return
	for landmark in _landmarks:
		var center: Vector2i = _clamp_cell(landmark.get("center", Vector2i.ZERO))
		var kind := str(landmark.get("kind", ""))
		match kind:
			"giant_corrupted_tree":
				_add_landmark_category_scene(_first_available_category([CAT_ANCIENT_TREE_BLOCKER, CAT_TREE_BLOCKER]), center, 2.9)
				_add_landmark_category_scene(_first_available_category([CAT_ROOT_WALL_BLOCKER, CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER]), center + Vector2i(3, 0), 1.9)
				_add_landmark_category_scene(_first_available_category([CAT_ROOT_WALL_BLOCKER, CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER]), center + Vector2i(-3, 1), 1.8)
				_add_landmark_category_scene(_first_available_category([CAT_ROOT_WALL_BLOCKER, CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER]), center + Vector2i(0, -3), 1.75)
				_add_landmark_category_scene(_first_available_category([CAT_MUSHROOM_CLUSTER_LARGE, CAT_GLOWING_MUSHROOM_RING, CAT_MUSHROOM_BLOCKER]), center + Vector2i(2, 4), 1.45)
			"elevated_shrine_plateau":
				_add_landmark_category_scene(_first_available_category([CAT_RUINED_SHRINE, CAT_SHRINE_PROP]), center, 1.8)
				_add_landmark_category_scene(_first_available_category([CAT_CORRUPTED_ALTAR, CAT_GLOWING_MUSHROOM_RING]), center + Vector2i(1, 0), 1.35)
				_add_landmark_category_scene(_first_available_category([CAT_TORCH_OR_SOUL_LIGHT, CAT_TORCH_PROP]), center + Vector2i(-2, 1), 1.15)
			"dead_root_canyon", "dead_root_maze":
				for offset in [Vector2i(-5, -2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(5, 2), Vector2i(0, 0)]:
					_add_landmark_category_scene(_first_available_category([CAT_ROOT_WALL_BLOCKER, CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER]), center + offset, 1.75)
			"mushroom_ritual_basin", "mushroom_ritual_circle":
				_add_landmark_category_scene(_first_available_category([CAT_GLOWING_MUSHROOM_RING, CAT_MUSHROOM_CLUSTER_LARGE]), center, 2.1)
				for offset in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(3, 3), Vector2i(-3, -3)]:
					_add_landmark_category_scene(_first_available_category([CAT_MUSHROOM_CLUSTER_LARGE, CAT_MUSHROOM_BLOCKER]), center + offset, 1.4)
			"cliff_ridge_barrier", "cliff_wall_barrier":
				for offset in [Vector2i(-6, 0), Vector2i(-3, 0), Vector2i(0, 0), Vector2i(3, 0), Vector2i(6, 0)]:
					_add_landmark_category_scene(_first_available_category([CAT_CLIFF_SIDE, CAT_ROCK_MOSS_CLUSTER, CAT_ROCK_BLOCKER]), center + offset, 1.45)
				_add_landmark_category_scene(_first_available_category([CAT_ROOT_WALL_BLOCKER, CAT_ROOT_BLOCKER]), center + Vector2i(0, 1), 1.5)
			"ancient_ruin_cluster", "broken_ruin_cluster":
				_add_landmark_category_scene(_first_available_category([CAT_BROKEN_STONE_ARCH, CAT_RUIN_PROP]), center, 1.8)
				_add_landmark_category_scene(_first_available_category([CAT_RUINED_SHRINE, CAT_RUIN_PROP]), center + Vector2i(3, 1), 1.35)
				_add_landmark_category_scene(_first_available_category([CAT_BROKEN_STONE_ARCH, CAT_RUIN_PROP]), center + Vector2i(-3, -1), 1.3)
				_add_landmark_category_scene(_first_available_category([CAT_BONE_DECOR, CAT_ROAD_EDGE_ROOTS]), center + Vector2i(-2, -1), 1.2)
			"swamp_depression", "swamp_basin":
				for offset in [Vector2i(5, 0), Vector2i(-5, 1), Vector2i(0, 4), Vector2i(2, -4), Vector2i(-3, -3)]:
					_add_landmark_category_scene(_first_available_category([CAT_MUSHROOM_CLUSTER_LARGE, CAT_MUSHROOM_BLOCKER, CAT_WATER_EDGE_DECOR]), center + offset, 1.35)
				_add_landmark_category_scene(_first_available_category([CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER]), center + Vector2i(-2, 2), 1.45)
			_:
				_add_landmark_category_scene(_first_available_category([CAT_RUINED_SHRINE, CAT_RUIN_PROP]), center, 1.2)
		_add_landmark_debug_label(landmark)


func _add_landmark_category_scene(category: StringName, cell: Vector2i, scale_multiplier: float) -> bool:
	cell = _clamp_cell(cell)
	var defs: Array = _asset_defs.get(category, [])
	if defs.is_empty():
		_note_fallback(category)
		return false
	var definition: Dictionary = defs[_hash_cell(cell, int(hash(str(category))) & 0xffff) % defs.size()]
	var scene := definition.get("scene", null) as PackedScene
	if scene == null:
		_note_fallback(category)
		return false
	var instance := scene.instantiate() as Node3D
	if instance == null:
		_note_fallback(category)
		return false
	instance.name = "Landmark_%s_%s_%s" % [str(category), cell.x, cell.y]
	instance.position = _cell_to_world(cell, _surface_height_for_cell(cell) + float(definition.get("height_offset", 0.0)))
	instance.rotation.y = _category_rotation(category, cell, definition, INF)
	var scale_value := _category_scale(category, cell, definition) * scale_multiplier
	instance.scale = Vector3.ONE * scale_value
	_blocker_root.add_child(instance)
	_scene_instance_counts[str(category)] = int(_scene_instance_counts.get(str(category), 0)) + 1
	_prop_scale_total += scale_value
	_prop_scale_count += 1
	_biome_decor_count += 1
	if _is_magical_glow_category(category) and _uses_biome_presentation():
		_add_corruption_glow(_blocker_root, instance.position)
	return true


func _add_landmark_debug_label(landmark: Dictionary) -> void:
	if _uses_biome_presentation() and not _is_readability_mode():
		return
	var center: Vector2i = _clamp_cell(landmark.get("center", Vector2i.ZERO))
	var label := Label3D.new()
	label.name = "LandmarkLabel_%s" % str(landmark.get("id", "unknown"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 18
	label.modulate = Color("#FFD05C")
	label.text = "%s\n%s %s | %s cells | choke %s\n%s" % [
		str(landmark.get("label", landmark.get("kind", "LANDMARK"))).to_upper(),
		str(landmark.get("rarity", "")),
		str(landmark.get("scale_class", "")),
		str(landmark.get("footprint_size", 0)),
		str(landmark.get("chokepoint_score", "")),
		str(landmark.get("navigation_role", "")),
	]
	label.position = _cell_to_world(center, _surface_height_for_cell(center) + 2.8)
	_plot_root.add_child(label)
	_debug_overlay_count += 1


func _add_content_structures() -> void:
	if _structure_root == null:
		return
	for child in _structure_root.get_children():
		child.queue_free()
	_visible_floors.clear()
	for structure in _content_structures:
		_add_content_structure(structure)
	_print_structure_debug()
	_update_floor_status_ui()


func _add_content_structure(structure: Dictionary) -> void:
	if not _validate_structure_for_render(structure):
		return
	_add_monolith_tower_exterior(structure)
	var floors: Array = structure.get("floors", [])
	var discovered: Array = structure.get("discovered_floors", [0])
	for floor_value in floors:
		var floor_data: Dictionary = floor_value
		var floor_index := int(floor_data.get("floor_index", 0))
		var visibility := _floor_visibility_state(floor_index, discovered)
		_visible_floors[floor_index] = visibility
		if visibility == "hidden":
			continue
		var floor_root := Node3D.new()
		floor_root.name = "%s_Floor_%s_%s" % [str(structure.get("id", "structure")), floor_index, visibility]
		_structure_root.add_child(floor_root)
		var y := _structure_floor_y(structure, floor_index)
		var floor_material: Material = _materials["structure_floor_active"] if visibility == "active" else _materials["structure_floor_faint"]
		var floor_size := Vector3(0.96, 0.075, 0.96) if visibility == "active" else Vector3(0.86, 0.04, 0.86)
		_rendered_floor_cell_count += _add_structure_cells(floor_root, structure, floor_data.get("walkable_cells", []), y, floor_size, floor_material, "Walkable")
		_rendered_floor_cell_count += _add_structure_cells(floor_root, structure, floor_data.get("wall_cells", []), y + 0.36, Vector3(0.94, 0.72, 0.94), _materials["structure_wall"], "Walls")
		_rendered_floor_cell_count += _add_structure_cells(floor_root, structure, floor_data.get("blocker_cells", []), y + 0.25, Vector3(0.66, 0.52, 0.66), _materials["structure_blocker"], "Blockers")
		_rendered_floor_cell_count += _add_structure_cells(floor_root, structure, floor_data.get("gap_cells", []), y - 0.04, Vector3(0.82, 0.04, 0.82), _materials["structure_gap"], "Gaps")
		_rendered_floor_cell_count += _add_structure_cells(floor_root, structure, floor_data.get("stair_cells", []), y + 0.14, Vector3(0.9, 0.22, 0.9), _materials["structure_stair"], "Stairs")
		if _structure_helpers_visible:
			_add_structure_room_overlays(floor_root, structure, floor_data, y + 0.075)
			_add_structure_floor_label(floor_root, structure, floor_data, y + 1.1, visibility)
		if visibility == "active":
			_add_active_floor_banner(floor_root, structure, floor_data, y + 2.0)


func _validate_structure_for_render(structure: Dictionary) -> bool:
	if structure.is_empty():
		print("[Map3DPrototype][ERROR] Structure render skipped: empty structure data.")
		return false
	var floors: Array = structure.get("floors", [])
	var floor_count := int(structure.get("floor_count", floors.size()))
	if floor_count <= 0 or floors.size() != floor_count:
		print("[Map3DPrototype][ERROR] Structure render skipped id=", structure.get("id", "?"), " invalid floor count floors=", floors.size(), " declared=", floor_count)
		return false
	var entrances: Array = structure.get("entrance_cells", [])
	if entrances.is_empty():
		print("[Map3DPrototype][ERROR] Structure render skipped id=", structure.get("id", "?"), " missing entrance cells.")
		return false
	for entrance_value in entrances:
		var entrance: Vector2i = entrance_value
		if not _is_in_generated_bounds(entrance):
			print("[Map3DPrototype][ERROR] Structure render skipped id=", structure.get("id", "?"), " entrance outside map=", entrance)
			return false
		if not _is_walkable_cell(entrance):
			print("[Map3DPrototype][ERROR] Structure render skipped id=", structure.get("id", "?"), " entrance is not exterior-walkable=", entrance)
			return false
	for link_value in structure.get("stair_links", []):
		var link: Dictionary = link_value
		var from_floor := int(link.get("from_floor", -1))
		var to_floor := int(link.get("to_floor", -1))
		if from_floor < 0 or from_floor >= floor_count or to_floor < 0 or to_floor >= floor_count:
			print("[Map3DPrototype][ERROR] Structure render skipped id=", structure.get("id", "?"), " invalid stair link=", link)
			return false
		if not _is_structure_walkable(structure, from_floor, link.get("from_cell", Vector2i(-1, -1))):
			print("[Map3DPrototype][ERROR] Structure render skipped id=", structure.get("id", "?"), " stair from cell invalid=", link)
			return false
		if not _is_structure_walkable(structure, to_floor, link.get("to_cell", Vector2i(-1, -1))):
			print("[Map3DPrototype][ERROR] Structure render skipped id=", structure.get("id", "?"), " stair to cell invalid=", link)
	return true


func _add_monolith_tower_exterior(structure: Dictionary) -> void:
	var rect: Rect2i = structure.get("exterior_rect", Rect2i())
	if rect.size == Vector2i.ZERO:
		return
	var center_cell := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
	var base_y := _surface_height_for_cell(_clamp_cell(center_cell))
	var tower_height := 7.2
	if _structure_view_mode == STRUCTURE_VIEW_INTERIOR_CUTAWAY:
		tower_height = _structure_floor_y(structure, _current_floor_focus) + 1.2
	elif _structure_view_mode == STRUCTURE_VIEW_DEBUG_FLOORS:
		tower_height = 1.1
	var tower := MeshInstance3D.new()
	tower.name = "AbandonedWizardMonolithTower_%s" % str(structure.get("id", "structure"))
	tower.mesh = _box_mesh(Vector3(float(rect.size.x) * 0.72, tower_height, float(rect.size.y) * 0.72))
	tower.material_override = _materials["structure_tower_cutaway"] if _structure_view_mode != STRUCTURE_VIEW_EXTERIOR else _materials["structure_tower"]
	tower.position = _cell_to_world(center_cell, base_y + tower_height * 0.5)
	_structure_root.add_child(tower)
	if _structure_view_mode == STRUCTURE_VIEW_INTERIOR_CUTAWAY:
		_add_cutaway_wall_outline(structure, _structure_floor_y(structure, _current_floor_focus) + 0.62)
	for offset in [Vector2i(0, -4), Vector2i(0, 4), Vector2i(-4, 0), Vector2i(4, 0)]:
		if _structure_view_mode != STRUCTURE_VIEW_EXTERIOR:
			continue
		var slit := MeshInstance3D.new()
		slit.name = "MonolithWindowSlit"
		slit.mesh = _box_mesh(Vector3(0.18 if offset.x == 0 else 0.58, 1.25, 0.58 if offset.x == 0 else 0.18))
		slit.material_override = _materials["structure_gap"]
		slit.position = _cell_to_world(center_cell + offset, base_y + 4.2)
		_structure_root.add_child(slit)
	for rune_offset in [Vector2i(-2, -3), Vector2i(2, -2), Vector2i(3, 2), Vector2i(-3, 3)]:
		if _structure_view_mode != STRUCTURE_VIEW_EXTERIOR:
			continue
		var rune := MeshInstance3D.new()
		rune.name = "MonolithPinkRune"
		rune.mesh = _box_mesh(Vector3(0.16, 2.4, 0.16))
		rune.material_override = _materials["structure_rune"]
		rune.position = _cell_to_world(center_cell + rune_offset, base_y + 4.0)
		_structure_root.add_child(rune)
	var entrance_cells: Array = structure.get("entrance_cells", [])
	if not entrance_cells.is_empty():
		var entrance: Vector2i = entrance_cells[0]
		var marker := MeshInstance3D.new()
		marker.name = "MonolithEntranceMarker"
		marker.mesh = _box_mesh(Vector3(2.4, 0.12, 1.15))
		marker.material_override = _materials["structure_stair"]
		marker.position = _cell_to_world(entrance, base_y + 0.12)
		_structure_root.add_child(marker)


func _add_cutaway_wall_outline(structure: Dictionary, y: float) -> void:
	var rect: Rect2i = structure.get("exterior_rect", Rect2i())
	var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
	var wall_thickness := 0.18
	var wall_height := 0.72
	var w := float(rect.size.x) * 0.98
	var d := float(rect.size.y) * 0.98
	for item in [
		{"offset": Vector2i(0, -rect.size.y / 2), "size": Vector3(w, wall_height, wall_thickness)},
		{"offset": Vector2i(0, rect.size.y / 2), "size": Vector3(w, wall_height, wall_thickness)},
		{"offset": Vector2i(-rect.size.x / 2, 0), "size": Vector3(wall_thickness, wall_height, d)},
		{"offset": Vector2i(rect.size.x / 2, 0), "size": Vector3(wall_thickness, wall_height, d)},
	]:
		var wall := MeshInstance3D.new()
		wall.name = "CutawayWallOutline"
		wall.mesh = _box_mesh(item["size"])
		wall.material_override = _materials["structure_wall"]
		wall.position = _cell_to_world(center + item["offset"], y)
		_structure_root.add_child(wall)


func _floor_visibility_state(floor_index: int, discovered: Array) -> String:
	match _structure_view_mode:
		STRUCTURE_VIEW_EXTERIOR:
			return "hidden"
		STRUCTURE_VIEW_DEBUG_FLOORS:
			return "active" if floor_index == _current_floor_focus else "faint"
	if floor_index == _current_floor_focus:
		return "active"
	if not discovered.has(floor_index):
		return "hidden"
	if floor_index < _current_floor_focus:
		return "faint"
	return "hidden"


func _structure_floor_y(structure: Dictionary, floor_index: int) -> float:
	return float(floor_index) * float(structure.get("floor_height", 1.5)) + 0.12


func _add_structure_cells(parent: Node3D, structure: Dictionary, cells: Array, y: float, size: Vector3, material: Material, label: String) -> int:
	if cells.is_empty():
		return 0
	var mesh := _box_mesh(size)
	for cell_value in cells:
		var local_cell: Vector2i = cell_value
		var instance := MeshInstance3D.new()
		instance.name = "%s_%s_%s" % [label, local_cell.x, local_cell.y]
		instance.mesh = mesh
		instance.material_override = material
		instance.position = _structure_cell_to_world(structure, local_cell, y)
		parent.add_child(instance)
	return cells.size()


func _add_structure_room_overlays(parent: Node3D, structure: Dictionary, floor_data: Dictionary, y: float) -> void:
	for room_value in floor_data.get("rooms", []):
		var room: Dictionary = room_value
		var rect: Rect2i = room.get("rect", Rect2i())
		if rect.size == Vector2i.ZERO:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "Room_%s" % str(room.get("id", "room"))
		instance.mesh = _box_mesh(Vector3(float(rect.size.x) * 0.92, 0.035, float(rect.size.y) * 0.92))
		instance.material_override = _materials["structure_room"]
		instance.position = _structure_local_rect_center_to_world(structure, rect, y)
		parent.add_child(instance)


func _add_structure_floor_label(parent: Node3D, structure: Dictionary, floor_data: Dictionary, y: float, visibility: String) -> void:
	var label := Label3D.new()
	label.name = "FloorLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 24 if visibility == "active" else 16
	label.modulate = Color("#FFFFFF") if visibility == "active" else Color(0.8, 0.82, 0.86, 0.45)
	label.text = "F%s %s" % [int(floor_data.get("floor_index", 0)), str(floor_data.get("label", ""))]
	var rect: Rect2i = structure.get("exterior_rect", Rect2i())
	label.position = _cell_to_world(rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2), y)
	parent.add_child(label)


func _add_active_floor_banner(parent: Node3D, structure: Dictionary, floor_data: Dictionary, y: float) -> void:
	if not _structure_helpers_visible:
		return
	var label := Label3D.new()
	label.name = "ActiveFloorBanner"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 34
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 8
	label.text = "MONOLITH FLOOR %s" % int(floor_data.get("floor_index", 0))
	var rect: Rect2i = structure.get("exterior_rect", Rect2i())
	label.position = _cell_to_world(rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2), y)
	parent.add_child(label)


func _structure_cell_to_world(structure: Dictionary, local_cell: Vector2i, y: float) -> Vector3:
	var rect: Rect2i = structure.get("exterior_rect", Rect2i())
	return _cell_to_world(rect.position + local_cell, y)


func _structure_local_rect_center_to_world(structure: Dictionary, rect: Rect2i, y: float) -> Vector3:
	var exterior: Rect2i = structure.get("exterior_rect", Rect2i())
	var center := exterior.position + rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
	return _cell_to_world(center, y)


func _set_floor_focus(floor_index: int) -> void:
	var clamped := clampi(floor_index, 0, _max_structure_floor())
	if clamped == _current_floor_focus:
		_print_floor_focus_debug()
		return
	_current_floor_focus = clamped
	if _structure_view_mode == STRUCTURE_VIEW_EXTERIOR:
		_structure_view_mode = STRUCTURE_VIEW_INTERIOR_CUTAWAY
	_add_content_structures()
	_snap_camera_to_focused_structure()
	_update_floor_status_ui()
	_print_floor_focus_debug()


func _cycle_floor_focus(delta: int) -> void:
	_set_floor_focus(_current_floor_focus + delta)


func _cycle_occupied_floor_focus() -> void:
	var occupied := _occupied_floors()
	if occupied.is_empty():
		print("[Map3DPrototype] No occupied interior floors to cycle.")
		return
	var next_index := 0
	for i in range(occupied.size()):
		if int(occupied[i]) == _current_floor_focus:
			next_index = (i + 1) % occupied.size()
			break
	_set_floor_focus(int(occupied[next_index]))


func _toggle_structure_cutaway_mode() -> void:
	if _structure_view_mode == STRUCTURE_VIEW_EXTERIOR:
		_structure_view_mode = STRUCTURE_VIEW_INTERIOR_CUTAWAY
	else:
		_structure_view_mode = STRUCTURE_VIEW_EXTERIOR
	_add_content_structures()
	_snap_camera_to_focused_structure()
	_update_floor_status_ui()
	_print_floor_focus_debug()


func _toggle_structure_helpers_visible() -> void:
	if _structure_view_mode == STRUCTURE_VIEW_DEBUG_FLOORS:
		_structure_view_mode = STRUCTURE_VIEW_INTERIOR_CUTAWAY
	elif _structure_view_mode == STRUCTURE_VIEW_EXTERIOR:
		_structure_view_mode = STRUCTURE_VIEW_INTERIOR_CUTAWAY
		_structure_helpers_visible = true
	else:
		_structure_view_mode = STRUCTURE_VIEW_DEBUG_FLOORS
		_structure_helpers_visible = true
	_add_content_structures()
	_snap_camera_to_focused_structure()
	_update_floor_status_ui()
	print("[Map3DPrototype] Floor helpers visible=", _structure_helpers_visible, " view_mode=", _structure_view_mode)


func _set_structure_view_debug_floors() -> void:
	_structure_view_mode = STRUCTURE_VIEW_DEBUG_FLOORS
	_structure_helpers_visible = true
	_add_content_structures()
	_snap_camera_to_focused_structure()
	_update_floor_status_ui()
	_print_floor_focus_debug()


func _snap_camera_to_focused_structure() -> void:
	if _camera_rig == null or _content_structures.is_empty():
		return
	var structure: Dictionary = _content_structures[0]
	var rect: Rect2i = structure.get("exterior_rect", Rect2i())
	if rect.size == Vector2i.ZERO:
		return
	var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
	_camera_rig.position = _cell_to_world(center, _structure_floor_y(structure, _current_floor_focus))
	_camera_distance = clampf(34.0 + float(rect.size.x) * 0.9, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	_update_camera_transform()


func _print_floor_focus_debug() -> void:
	var structure: Dictionary = _content_structures[0] if not _content_structures.is_empty() else {}
	print("[Map3DPrototype] Floor focus current_floor_focus=", _current_floor_focus,
		" visible_floors=", _visible_floors,
		" probe_floor=", _unit_floor,
		" discovered_floors=", structure.get("discovered_floors", []),
		" current_mode=", _structure_view_mode,
		" rendered_floor_cells=", _rendered_floor_cell_count)


func _update_floor_status_ui() -> void:
	if _floor_status_label == null:
		return
	var structure: Dictionary = _content_structures[0] if not _content_structures.is_empty() else {}
	var structure_id := str(structure.get("id", "none"))
	var discovered: Array = structure.get("discovered_floors", [])
	_floor_status_label.text = "Structure: %s\nView: %s | Floor: %s | Probe floor: %s | Discovered: %s\nC cutaway/exterior | PageUp/PageDown floor | Tab probe floor | V debug floors | F focus probe" % [
		structure_id,
		_structure_view_mode,
		_current_floor_focus,
		_unit_floor,
		str(discovered),
	]


func _max_structure_floor() -> int:
	var max_floor := 0
	for structure in _content_structures:
		max_floor = maxi(max_floor, int(structure.get("floor_count", 1)) - 1)
	return max_floor


func _occupied_floors() -> Array[int]:
	var floors: Array[int] = []
	if _unit_floor >= 0:
		floors.append(_unit_floor)
	return floors


func _print_structure_debug() -> void:
	for structure in _content_structures:
		var validation: Dictionary = structure.get("validation", {})
		print("[Map3DPrototype] Structure id=", structure.get("id", "?"),
			" type=", structure.get("structure_type", "?"),
			" footprint=", structure.get("footprint_size", Vector2i.ZERO),
			" floors=", structure.get("floor_count", 0),
			" floor_height=", structure.get("floor_height", 0.0),
			" room_density=", structure.get("room_density", 0.0),
			" gap_density=", structure.get("gap_density", 0.0),
			" decor_density=", structure.get("decor_density", 0.0),
			" walkable_counts=", validation.get("walkable_counts", []),
			" stair_count=", validation.get("stair_count", 0),
			" current_floor_focus=", _current_floor_focus,
			" visible_floors=", _visible_floors,
			" occupied_floors=", _occupied_floors(),
			" validation=", validation)


func _add_content_plot_decor(center: Vector2i) -> void:
	var offsets: Array[Vector2i] = [Vector2i(2, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(-1, -2)]
	for offset in offsets:
		var cell := _clamp_cell(center + offset)
		if not _can_place_cluster_prop(cell):
			continue
		var category := _first_available_category([CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER]) if _hash_cell(cell, 223) % 2 == 0 else _first_available_category([CAT_BONE_DECOR, CAT_ROAD_EDGE_ROOTS, CAT_ROAD_DECOR])
		if _try_add_category_scene(category, _blocker_root, cell, _surface_height_for_cell(cell)):
			_biome_decor_count += 1


func _blocker_category_for_cell(cell: Vector2i) -> StringName:
	var feature := str(_feature_grid[cell.x][cell.y])
	if feature == "landmark_giant_tree":
		return _first_available_category([CAT_ANCIENT_TREE_BLOCKER, CAT_TREE_BLOCKER])
	if feature == "landmark_root_wall" or feature == "landmark_swamp_root":
		return _first_available_category([CAT_ROOT_WALL_BLOCKER, CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER])
	if feature == "landmark_mushroom_circle" or feature == "landmark_mushroom_glow":
		return _first_available_category([CAT_MUSHROOM_CLUSTER_LARGE, CAT_GLOWING_MUSHROOM_RING, CAT_MUSHROOM_BLOCKER])
	if feature == "landmark_ruin":
		return _first_available_category([CAT_BROKEN_STONE_ARCH, CAT_RUIN_PROP])
	if feature == "landmark_cliff_wall":
		return _first_available_category([CAT_CLIFF_SIDE, CAT_ROCK_MOSS_CLUSTER, CAT_ROCK_BLOCKER])
	if feature != "forest_blocker":
		return _first_available_category([CAT_ROCK_MOSS_CLUSTER, CAT_ROCK_BLOCKER])
	var roll := _hash_cell(cell, 133) % 10
	if roll < 3:
		return _first_available_category([CAT_ANCIENT_TREE_BLOCKER, CAT_TREE_BLOCKER])
	if roll < 5:
		return _first_available_category([CAT_ROOT_WALL_BLOCKER, CAT_ROOT_BLOCKER])
	if roll < 7:
		return _first_available_category([CAT_MUSHROOM_CLUSTER_LARGE, CAT_MUSHROOM_BLOCKER])
	if roll < 8:
		return _first_available_category([CAT_DEAD_TREE_SPIKE, CAT_TREE_BLOCKER])
	if roll < 9:
		return _first_available_category([CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_BLOCKER])
	return _first_available_category([CAT_ROCK_MOSS_CLUSTER, CAT_ROCK_BLOCKER])


func _try_add_category_scene(category: StringName, parent: Node3D, cell: Vector2i, y: float, rotation_y: float = INF) -> bool:
	if not use_biome_mesh_assets:
		return false
	var defs: Array = _asset_defs.get(category, [])
	if defs.is_empty():
		_note_fallback(category)
		return false
	var definition: Dictionary = defs[_hash_cell(cell, int(hash(str(category))) & 0xffff) % defs.size()]
	var scene := definition.get("scene", null) as PackedScene
	if scene == null:
		_note_fallback(category)
		return false
	var instance := scene.instantiate() as Node3D
	if instance == null:
		_note_fallback(category)
		return false
	instance.name = "%s_%s_%s" % [str(category), cell.x, cell.y]
	instance.position = _cell_to_world(cell, y + float(definition.get("height_offset", 0.0)))
	instance.rotation.y = _category_rotation(category, cell, definition, rotation_y)
	var scale_value := _category_scale(category, cell, definition)
	instance.scale = Vector3.ONE * scale_value
	parent.add_child(instance)
	_scene_instance_counts[str(category)] = int(_scene_instance_counts.get(str(category), 0)) + 1
	if _is_prop_category(category):
		_prop_scale_total += scale_value
		_prop_scale_count += 1
	if (category == CAT_TORCH_PROP or category == CAT_TORCH_OR_SOUL_LIGHT) and _uses_biome_presentation():
		_add_torch_glow(parent, instance.position)
	elif _is_magical_glow_category(category) and _uses_biome_presentation():
		_add_corruption_glow(parent, instance.position)
	return true


func _category_rotation(category: StringName, cell: Vector2i, definition: Dictionary, requested: float) -> float:
	if requested != INF:
		return requested
	var base := deg_to_rad(float(definition.get("rotation_degrees", 0.0)))
	if bool(definition.get("rotation_random", true)):
		base += float(_hash_cell(cell, 187) % 4) * PI * 0.5
	return base


func _category_scale(category: StringName, cell: Vector2i, definition: Dictionary) -> float:
	var base := float(definition.get("scale", 1.0))
	var random_range: Array = definition.get("scale_random", [])
	if random_range.size() >= 2:
		var t := float(_hash_cell(cell, 191) % 1000) / 999.0
		base = lerpf(float(random_range[0]), float(random_range[1]), t)
	if _uses_biome_presentation():
		match category:
			CAT_TREE_BLOCKER, CAT_ANCIENT_TREE_BLOCKER:
				base *= 1.45
			CAT_DEAD_TREE_SPIKE:
				base *= 1.25
			CAT_ROOT_BLOCKER, CAT_TWISTED_ROOT_BLOCKER, CAT_ROOT_WALL_BLOCKER:
				base *= 1.28
			CAT_MUSHROOM_BLOCKER, CAT_MUSHROOM_CLUSTER_SMALL, CAT_MUSHROOM_CLUSTER_LARGE, CAT_GLOWING_MUSHROOM_RING:
				base *= 1.18
			CAT_ROCK_BLOCKER, CAT_ROCK_MOSS_CLUSTER:
				base *= 1.12
	return base


func _is_prop_category(category: StringName) -> bool:
	return category == CAT_TREE_BLOCKER \
		or category == CAT_ROCK_BLOCKER \
		or category == CAT_MUSHROOM_BLOCKER \
		or category == CAT_ROOT_BLOCKER \
		or category == CAT_RUIN_PROP \
		or category == CAT_SHRINE_PROP \
		or category == CAT_TORCH_PROP \
		or category == CAT_ROAD_DECOR \
		or category == CAT_WATER_EDGE_DECOR \
		or category == CAT_ANCIENT_TREE_BLOCKER \
		or category == CAT_TWISTED_ROOT_BLOCKER \
		or category == CAT_DEAD_TREE_SPIKE \
		or category == CAT_MUSHROOM_CLUSTER_SMALL \
		or category == CAT_MUSHROOM_CLUSTER_LARGE \
		or category == CAT_ROCK_MOSS_CLUSTER \
		or category == CAT_ROOT_WALL_BLOCKER \
		or category == CAT_RUINED_SHRINE \
		or category == CAT_CORRUPTED_ALTAR \
		or category == CAT_BROKEN_STONE_ARCH \
		or category == CAT_GLOWING_MUSHROOM_RING \
		or category == CAT_TORCH_OR_SOUL_LIGHT \
		or category == CAT_BONE_DECOR \
		or category == CAT_ROAD_EDGE_ROOTS


func _add_torch_glow(parent: Node3D, position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "TorchGlow"
	light.position = position + Vector3(0.0, 0.8, 0.0)
	light.light_color = Color("#D9502A")
	light.light_energy = 0.65
	light.omni_range = 4.25
	light.shadow_enabled = false
	parent.add_child(light)


func _is_magical_glow_category(category: StringName) -> bool:
	return category == CAT_MUSHROOM_CLUSTER_SMALL \
		or category == CAT_MUSHROOM_CLUSTER_LARGE \
		or category == CAT_MUSHROOM_BLOCKER \
		or category == CAT_GLOWING_MUSHROOM_RING \
		or category == CAT_CORRUPTED_ALTAR \
		or category == CAT_RUINED_SHRINE \
		or category == CAT_SHRINE_PROP


func _add_corruption_glow(parent: Node3D, position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "MushroomOrRuinGlow"
	light.position = position + Vector3(0.0, 0.72, 0.0)
	light.light_color = Color("#C13030")
	light.light_energy = 0.32
	light.omni_range = 2.55
	light.shadow_enabled = false
	parent.add_child(light)


func _note_fallback(category: StringName) -> void:
	_fallback_counts[str(category)] = int(_fallback_counts.get(str(category), 0)) + 1


func _try_add_biome_scene(tag: StringName, parent: Node3D, cell: Vector2i, y: float, rotation_y: float, scale_value: float) -> bool:
	var scenes: Array = _mesh_assets.get(tag, [])
	if scenes.is_empty():
		return false
	var scene: PackedScene = scenes[_hash_cell(cell, int(hash(str(tag))) & 0xffff) % scenes.size()]
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return false
	instance.name = "%s_%s_%s" % [str(tag), cell.x, cell.y]
	instance.position = _cell_to_world(cell, y)
	instance.rotation.y = rotation_y
	instance.scale = Vector3.ONE * scale_value
	parent.add_child(instance)
	return true


func _try_add_billboard_blocker(cell: Vector2i) -> bool:
	var textures := _tree_textures if str(_feature_grid[cell.x][cell.y]) == "forest_blocker" else _rock_textures
	if textures.is_empty():
		return false
	var sprite := Sprite3D.new()
	sprite.name = "Blocker_%s_%s" % [cell.x, cell.y]
	sprite.texture = textures[_hash_cell(cell, 41) % textures.size()]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.012
	sprite.position = _cell_to_world(cell, _surface_height_for_cell(cell) + 0.55)
	_blocker_root.add_child(sprite)
	return true


func _add_plot_markers() -> void:
	for plot in _plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var kind := str(plot.get("kind", ""))
		var marker := MeshInstance3D.new()
		marker.name = "BasePlot_%s" % str(plot.get("id", "plot")) if kind == "base" else "ContentPlot_%s" % str(plot.get("id", "plot"))
		marker.mesh = _box_mesh(Vector3(float(rect.size.x), PLOT_MARKER_THICKNESS, float(rect.size.y)))
		marker.material_override = _materials["base_plot"] if kind == "base" else _materials["content_plot"]
		var center_world := _rect_center_to_world(rect)
		var center_cell := _clamp_cell(Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2))
		center_world.y = _surface_height_for_cell(center_cell) + PLOT_MARKER_THICKNESS * 0.5 + 0.1
		marker.position = center_world
		_plot_root.add_child(marker)
		_debug_overlay_count += 1
		if kind == "base" and not _uses_biome_presentation():
			_add_base_debug_label(plot, center_world)
		elif kind == "content_blank":
			if not _uses_biome_presentation():
				_add_content_debug_outlines(plot)


func _add_base_debug_label(plot: Dictionary, center_world: Vector3) -> void:
	var label := Label3D.new()
	label.name = "BaseLabel_%s" % str(plot.get("id", "base"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 38
	label.modulate = Color("#FFF3A6")
	label.outline_modulate = Color("#1B150A")
	label.outline_size = 8
	label.text = "%s\nres %s | def %.2f | eco %.2f | ramps %s/%s" % [
		_base_archetype_short_name(str(plot.get("base_archetype", "BASE"))),
		int(plot.get("resource_node_count", plot.get("economy_count", 0))),
		float(plot.get("defence_score", plot.get("defensibility", 0.0))),
		float(plot.get("economy_score", 0.0)),
		int(plot.get("validated_ramp_count", plot.get("actual_ramp_count", 0))),
		int(plot.get("target_ramp_count", 0)),
	]
	label.position = center_world + Vector3(0.0, 1.15, 0.0)
	_plot_root.add_child(label)
	_debug_overlay_count += 1


func _base_archetype_short_name(archetype: String) -> String:
	match archetype:
		"FORTRESS_BASE":
			return "FORTRESS"
		"HOLDFAST_BASE":
			return "HOLDFAST"
		"EXPANSION_BASE":
			return "EXPANSION"
	return archetype


func _add_content_debug_outlines(plot: Dictionary) -> void:
	var reservation_rect: Rect2i = plot.get("reservation_rect", plot.get("rect", Rect2i()))
	var debug_rect: Rect2i = plot.get("debug_render_rect", plot.get("rect", Rect2i()))
	var fallback := bool(plot.get("fallback_used", false))
	var outline_material: Material = _materials["content_fallback_outline"] if fallback else _materials["content_reservation_outline"]
	_add_rect_outline("Reserved_%s" % str(plot.get("id", "content")), reservation_rect, outline_material, 0.16)
	_add_rect_outline("Rendered_%s" % str(plot.get("id", "content")), debug_rect, _materials["content_debug_outline"], 0.24)
	_debug_overlay_count += 8


func _add_rect_outline(node_name: String, rect: Rect2i, material: Material, y_offset: float) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var thickness := 0.08
	var y := _surface_height_for_cell(_clamp_cell(rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2))) + y_offset
	var top := MeshInstance3D.new()
	top.name = node_name + "_Top"
	top.mesh = _box_mesh(Vector3(float(rect.size.x), thickness, thickness))
	top.material_override = material
	top.position = _rect_edge_center_to_world(rect, Vector2(0.5, 0.0), y)
	_plot_root.add_child(top)
	var bottom := MeshInstance3D.new()
	bottom.name = node_name + "_Bottom"
	bottom.mesh = _box_mesh(Vector3(float(rect.size.x), thickness, thickness))
	bottom.material_override = material
	bottom.position = _rect_edge_center_to_world(rect, Vector2(0.5, 1.0), y)
	_plot_root.add_child(bottom)
	var left := MeshInstance3D.new()
	left.name = node_name + "_Left"
	left.mesh = _box_mesh(Vector3(thickness, thickness, float(rect.size.y)))
	left.material_override = material
	left.position = _rect_edge_center_to_world(rect, Vector2(0.0, 0.5), y)
	_plot_root.add_child(left)
	var right := MeshInstance3D.new()
	right.name = node_name + "_Right"
	right.mesh = _box_mesh(Vector3(thickness, thickness, float(rect.size.y)))
	right.material_override = material
	right.position = _rect_edge_center_to_world(rect, Vector2(1.0, 0.5), y)
	_plot_root.add_child(right)


func _rect_edge_center_to_world(rect: Rect2i, normalized: Vector2, y: float) -> Vector3:
	return Vector3(
		(float(rect.position.x) + float(rect.size.x) * normalized.x - float(_map_width) * 0.5) * TILE_SIZE,
		y,
		(float(rect.position.y) + float(rect.size.y) * normalized.y - float(_map_height) * 0.5) * TILE_SIZE
	)


func _set_plots_visible(visible: bool) -> void:
	_show_plots = visible
	if _plot_root != null and is_instance_valid(_plot_root):
		_plot_root.visible = visible


func _set_roads_visible(visible: bool) -> void:
	_show_roads = visible
	if _road_root != null and is_instance_valid(_road_root):
		_road_root.visible = visible


func _set_ramps_visible(visible: bool) -> void:
	_show_ramps = visible
	if _ramp_root != null and is_instance_valid(_ramp_root):
		_ramp_root.visible = visible


func _set_blockers_visible(visible: bool) -> void:
	_show_blockers = visible
	if _blocker_root != null and is_instance_valid(_blocker_root):
		_blocker_root.visible = visible


func _set_path_debug_visible(visible: bool) -> void:
	_show_path_debug = visible
	if _path_root != null and is_instance_valid(_path_root):
		_path_root.visible = visible


func _create_gameplay_probe() -> void:
	if _gameplay_root != null and is_instance_valid(_gameplay_root):
		_gameplay_root.queue_free()
	_gameplay_root = Node3D.new()
	_gameplay_root.name = "GameplayProbe"
	add_child(_gameplay_root)

	_path_root = Node3D.new()
	_path_root.name = "PathDebug"
	_path_root.visible = _show_path_debug
	_gameplay_root.add_child(_path_root)

	var spawn_cell := _probe_spawn_cell()
	if not _is_walkable_cell(spawn_cell):
		print("[Map3DPrototype][ERROR] Probe spawn invalid; no walkable spawn found near monolith/base. Requested=", spawn_cell)
		return
	_probe_missing_error_printed = false
	_probe_hidden_warning_printed = false
	_probe_invalid_position_warning_printed = false
	_unit_cell = spawn_cell
	_unit_path.clear()
	_unit_path_index = 0
	_unit_structure_id = ""
	_unit_floor = -1
	_unit_local_cell = Vector2i(-1, -1)
	_unit_interior_path.clear()
	_pending_enter_structure_id = ""
	_pending_enter_local_cell = Vector2i(-1, -1)
	_pending_stair_link.clear()
	_unit_selected = false

	_probe_unit = Node3D.new()
	_probe_unit.name = "ProbeUnit"
	_probe_unit.position = _cell_to_unit_world(spawn_cell)
	_gameplay_root.add_child(_probe_unit)

	_unit_beacon = MeshInstance3D.new()
	_unit_beacon.name = "Beacon"
	_unit_beacon.mesh = _box_mesh(Vector3(0.62, 9.5, 0.62))
	_unit_beacon.material_override = _materials["probe_beacon"]
	_unit_beacon.position = Vector3(0.0, 4.85, 0.0)
	_probe_unit.add_child(_unit_beacon)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = UNIT_RADIUS
	body_mesh.height = UNIT_HEIGHT
	body.mesh = body_mesh
	body.material_override = _materials["probe_unit"]
	body.position = Vector3(0.0, UNIT_HEIGHT * 0.5, 0.0)
	_probe_unit.add_child(body)

	_selection_ring = MeshInstance3D.new()
	_selection_ring.name = "SelectionRing"
	_selection_ring.mesh = _box_mesh(Vector3(UNIT_RADIUS * 4.4, 0.065, UNIT_RADIUS * 4.4))
	_selection_ring.material_override = _materials["probe_unit_selected"]
	_selection_ring.position = Vector3(0.0, 0.035, 0.0)
	_selection_ring.visible = true
	_probe_unit.add_child(_selection_ring)

	_unit_label = Label3D.new()
	_unit_label.name = "ProbeLabel"
	_unit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_unit_label.no_depth_test = true
	_unit_label.font_size = 36
	_unit_label.modulate = Color.WHITE
	_unit_label.outline_modulate = Color("#00131A")
	_unit_label.outline_size = 10
	_unit_label.text = "PROBE"
	_unit_label.position = Vector3(0.0, UNIT_HEIGHT + 1.4, 0.0)
	_probe_unit.add_child(_unit_label)

	_set_probe_selected(true)
	_set_probe_debug_visible(_probe_debug_visible)
	_camera_rig.position = _probe_unit.position
	_update_camera_transform()
	_update_probe_screen_marker()
	_print_probe_spawn_info("spawn")


func _print_probe_spawn_info(reason: String) -> void:
	var node_path := NodePath("")
	if _probe_unit != null and is_instance_valid(_probe_unit):
		node_path = _probe_unit.get_path()
	print("[Map3DPrototype] Probe ", reason,
		" scene=", name,
		" node_path=", node_path,
		" world_position=", _probe_unit.global_position if _probe_unit != null else Vector3.ZERO,
		" grid_cell=", _unit_cell,
		" floor=", _unit_floor,
		" structure_id=", _unit_structure_id,
		" visible=", _probe_unit.visible if _probe_unit != null else false,
		" collision_layer=none",
		" collision_mask=none",
		" selectable=", _probe_unit != null and is_instance_valid(_probe_unit),
		" movement_state=", "moving" if _unit_path_index < _unit_path.size() or not _unit_interior_path.is_empty() else "idle")


func _probe_spawn_cell() -> Vector2i:
	for structure in _content_structures:
		if not _validate_structure_for_probe(structure):
			continue
		var entrance: Vector2i = structure.get("entrance_cells", [Vector2i(_map_width / 2, _map_height / 2)])[0]
		var candidates: Array[Vector2i] = [
			entrance + Vector2i(0, 2),
			entrance + Vector2i(0, 3),
			entrance + Vector2i(-1, 2),
			entrance + Vector2i(1, 2),
			entrance + Vector2i(-2, 2),
			entrance + Vector2i(2, 2),
			entrance,
		]
		for candidate in candidates:
			if _is_walkable_cell(candidate):
				print("[Map3DPrototype] Probe spawn selected near structure=", structure.get("id", ""), " entrance=", entrance, " spawn=", candidate)
				return candidate
		var nearest := _nearest_local_walkable_cell(entrance + Vector2i(0, 2), 12)
		if _is_walkable_cell(nearest):
			print("[Map3DPrototype] Probe spawn nearest fallback near structure=", structure.get("id", ""), " entrance=", entrance, " spawn=", nearest)
			return nearest
	if _map_generator == null:
		return _nearest_local_walkable_cell(Vector2i(_map_width / 2, _map_height / 2), 32)
	var center_spawn: Vector2i = _map_generator.call("nearest_walkable_cell", Vector2i(_map_width / 2, _map_height / 2), 36)
	if _is_in_generated_bounds(center_spawn) and _is_walkable_cell(center_spawn):
		return center_spawn
	for plot in _plots:
		if str(plot.get("kind", "")) != "base":
			continue
		var rect: Rect2i = plot.get("rect", Rect2i())
		var anchor: Vector2i = plot.get("anchor", rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2))
		var spawn: Vector2i = _map_generator.call("nearest_walkable_cell", anchor, 12)
		if _is_in_generated_bounds(spawn) and _is_walkable_cell(spawn):
			return spawn
	return _nearest_local_walkable_cell(Vector2i(_map_width / 2, _map_height / 2), 48)


func _validate_structure_for_probe(structure: Dictionary) -> bool:
	if not _validate_structure_for_render(structure):
		return false
	var entrance_local_cells: Array = structure.get("entrance_local_cells", [])
	if entrance_local_cells.is_empty():
		print("[Map3DPrototype][ERROR] Probe structure invalid id=", structure.get("id", "?"), " missing entrance local cell.")
		return false
	if not _is_structure_walkable(structure, 0, entrance_local_cells[0]):
		print("[Map3DPrototype][ERROR] Probe structure invalid id=", structure.get("id", "?"), " entrance local cell not walkable=", entrance_local_cells[0])
		return false
	return true


func _nearest_local_walkable_cell(origin: Vector2i, max_radius: int) -> Vector2i:
	if _is_walkable_cell(origin):
		return origin
	for radius in range(1, max_radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				var cell := Vector2i(x, y)
				if _is_walkable_cell(cell):
					return cell
	return _clamp_cell(origin)


func _handle_left_click(screen_position: Vector2) -> void:
	if _screen_selects_probe(screen_position):
		_set_probe_selected(true)
		print("[Map3DPrototype] Probe selected by direct click screen=", screen_position, " unit_cell=", _unit_cell)
		return
	var pick := _pick_map_cell(screen_position)
	if pick.is_empty():
		print("[Map3DPrototype] Selection failed screen=", screen_position, " reason=no_map_pick probe_under_cursor=", _screen_selects_probe(screen_position))
		return
	if pick.has("structure"):
		print("[Map3DPrototype] Structure pick id=", pick.get("structure_id", ""),
			" floor=", pick.get("floor", -1),
			" local_cell=", pick.get("local_cell", Vector2i.ZERO),
			" walkable=", _is_structure_walkable(pick["structure"], int(pick["floor"]), pick["local_cell"]))
		if _screen_selects_probe(screen_position):
			_set_probe_selected(true)
		else:
			print("[Map3DPrototype] Probe selection failed screen=", screen_position, " reason=structure_pick_not_probe")
		return
	var cell: Vector2i = pick["cell"]
	_print_pick_debug(cell)
	if _probe_unit != null and _click_selects_probe(cell, pick["world"]):
		_set_probe_selected(true)
		print("[Map3DPrototype] Probe selected cell=", _unit_cell)
	else:
		_set_probe_selected(false)
		print("[Map3DPrototype] Probe selection failed screen=", screen_position,
			" reason=terrain_click_not_probe picked_cell=", cell,
			" unit_cell=", _unit_cell,
			" screen_rect=", _probe_unit_screen_rect())


func _handle_right_click(screen_position: Vector2) -> void:
	var pick := _pick_map_cell(screen_position)
	if pick.is_empty():
		return
	if pick.has("structure"):
		_handle_structure_right_click(pick)
		return
	var target_cell: Vector2i = pick["cell"]
	_print_pick_debug(target_cell)
	if not _unit_selected:
		print("[Map3DPrototype] Move ignored; probe unit is not selected.")
		return
	if _unit_floor >= 0:
		print("[Map3DPrototype] Exterior move ignored; probe is inside structure=", _unit_structure_id, " floor=", _unit_floor)
		return
	if not _is_walkable_cell(target_cell):
		_unit_path.clear()
		_unit_path_index = 0
		_redraw_path_debug()
		print("[Map3DPrototype] Move rejected target=", target_cell, " walkable=false")
		return
	_issue_probe_move(target_cell)


func _on_input_capture_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_begin_drag_select(event.position)
				_input_capture.accept_event()
			MOUSE_BUTTON_RIGHT:
				_handle_right_click(event.position)
				_input_capture.accept_event()
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_drag_select(event.position)
		_input_capture.accept_event()
	if event is InputEventMouseMotion and _drag_selecting:
		_update_drag_select(event.position)
		_input_capture.accept_event()


func _begin_drag_select(screen_position: Vector2) -> void:
	_drag_selecting = true
	_drag_start = screen_position
	_drag_current = screen_position
	_update_selection_rect()


func _update_drag_select(screen_position: Vector2) -> void:
	_drag_current = screen_position
	_update_selection_rect()


func _end_drag_select(screen_position: Vector2) -> void:
	if not _drag_selecting:
		return
	_drag_selecting = false
	_drag_current = screen_position
	if _selection_rect != null:
		_selection_rect.visible = false
	if _drag_start.distance_to(_drag_current) < DRAG_SELECT_THRESHOLD:
		_handle_left_click(screen_position)
		return
	var rect := _drag_rect()
	var selected := _probe_unit_inside_screen_rect(rect)
	_set_probe_selected(selected)
	print("[Map3DPrototype] Drag select rect=", rect,
		" selected_probe=", selected,
		" unit_cell=", _unit_cell,
		" reason=", "intersects_probe_screen_rect" if selected else _probe_drag_selection_failure_reason(rect))


func _update_selection_rect() -> void:
	if _selection_rect == null:
		return
	var rect := _drag_rect()
	_selection_rect.position = rect.position
	_selection_rect.size = rect.size
	_selection_rect.visible = rect.size.x >= DRAG_SELECT_THRESHOLD or rect.size.y >= DRAG_SELECT_THRESHOLD


func _drag_rect() -> Rect2:
	var min_point := Vector2(minf(_drag_start.x, _drag_current.x), minf(_drag_start.y, _drag_current.y))
	var max_point := Vector2(maxf(_drag_start.x, _drag_current.x), maxf(_drag_start.y, _drag_current.y))
	return Rect2(min_point, max_point - min_point)


func _probe_unit_inside_screen_rect(rect: Rect2) -> bool:
	if _camera == null or _probe_unit == null:
		return false
	var unit_rect := _probe_unit_screen_rect()
	return rect.intersects(unit_rect) or rect.encloses(unit_rect) or unit_rect.encloses(rect)


func _screen_selects_probe(screen_position: Vector2) -> bool:
	if _camera == null or _probe_unit == null or not is_instance_valid(_probe_unit):
		return false
	if _camera.is_position_behind(_probe_unit.global_position):
		return false
	return _probe_unit_screen_rect().has_point(screen_position)


func _probe_drag_selection_failure_reason(rect: Rect2) -> String:
	if _probe_unit == null or not is_instance_valid(_probe_unit):
		return "probe_missing"
	if _camera == null:
		return "camera_missing"
	if _camera.is_position_behind(_probe_unit.global_position):
		return "probe_behind_camera"
	return "drag_rect_missed_probe probe_screen_rect=%s" % [_probe_unit_screen_rect()]


func _probe_unit_screen_rect() -> Rect2:
	if _camera == null or _probe_unit == null:
		return Rect2()
	if _camera.is_position_behind(_probe_unit.global_position):
		return Rect2()
	var points: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, UNIT_HEIGHT, 0.0),
		Vector3(-UNIT_RADIUS, UNIT_HEIGHT * 0.5, 0.0),
		Vector3(UNIT_RADIUS, UNIT_HEIGHT * 0.5, 0.0),
		Vector3(0.0, UNIT_HEIGHT * 0.5, -UNIT_RADIUS),
		Vector3(0.0, UNIT_HEIGHT * 0.5, UNIT_RADIUS),
		Vector3(0.0, UNIT_HEIGHT + 3.2, 0.0),
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in points:
		var screen_position := _camera.unproject_position(_probe_unit.global_position + point)
		min_point.x = minf(min_point.x, screen_position.x)
		min_point.y = minf(min_point.y, screen_position.y)
		max_point.x = maxf(max_point.x, screen_position.x)
		max_point.y = maxf(max_point.y, screen_position.y)
	var rect := Rect2(min_point, max_point - min_point)
	return rect.grow(UNIT_SCREEN_SELECT_PADDING)


func _set_probe_selected(selected: bool) -> void:
	_unit_selected = selected
	if _selection_ring != null:
		_selection_ring.visible = selected
	if _probe_screen_marker != null:
		_probe_screen_marker.modulate = Color(1.0, 0.94, 0.18, 1.0) if selected else Color.WHITE
	print("[Map3DPrototype] Probe selected=", _unit_selected,
		" current_cell=", _unit_cell,
		" current_floor=", _unit_floor,
		" current_structure=", _unit_structure_id,
		" movement_state=", "moving" if _unit_path_index < _unit_path.size() or not _unit_interior_path.is_empty() else "idle")


func _update_probe_screen_marker() -> void:
	if _probe_screen_marker == null or _camera == null or _probe_unit == null:
		return
	var screen_position := _camera.unproject_position(_probe_unit.global_position + Vector3(0.0, UNIT_HEIGHT + 0.35, 0.0))
	_probe_screen_marker.position = screen_position - _probe_screen_marker.size * 0.5
	_probe_screen_marker.visible = _probe_debug_visible and not _camera.is_position_behind(_probe_unit.global_position)


func _click_selects_probe(cell: Vector2i, world: Vector3) -> bool:
	if _probe_unit == null:
		return false
	if cell == _unit_cell:
		return true
	var probe_position := _probe_unit.global_position
	var flat_delta := Vector2(world.x - probe_position.x, world.z - probe_position.z)
	return flat_delta.length() <= UNIT_RADIUS * 1.9


func _issue_probe_move(target_cell: Vector2i) -> void:
	if _probe_unit == null:
		print("[Map3DPrototype][ERROR] Move failed; probe unit node is missing.")
		return
	if not _is_in_generated_bounds(target_cell):
		print("[Map3DPrototype] Move rejected target=", target_cell, " reason=outside_map selected=", _unit_selected)
		return
	if not _is_walkable_cell(target_cell):
		print("[Map3DPrototype] Move rejected target=", target_cell, " reason=blocked_or_water selected=", _unit_selected)
		return
	if not _is_walkable_cell(_unit_cell):
		_unit_cell = _world_to_cell(_probe_unit.position)
	if not _is_walkable_cell(_unit_cell):
		print("[Map3DPrototype] Move failed start=", _unit_cell, " reason=current_cell_not_walkable")
		return
	var path: Array = []
	if _map_generator != null and _map_generator.has_method("find_path_cells"):
		path = _map_generator.call("find_path_cells", _unit_cell, target_cell)
	else:
		path = _find_local_grid_path(_unit_cell, target_cell)
	_unit_path.clear()
	for path_cell in path:
		var cell: Vector2i = path_cell
		if _is_walkable_cell(cell):
			_unit_path.append(cell)
	_unit_path_index = 0
	_set_path_debug_visible(true)
	_redraw_path_debug()
	if _unit_path.is_empty() and _unit_cell != target_cell:
		print("[Map3DPrototype] Move failed start=", _unit_cell,
			" target=", target_cell,
			" target_walkable=", _is_walkable_cell(target_cell),
			" path_length=0 movement_state=failed_no_path")
		return
	print("[Map3DPrototype] Move command start=", _unit_cell,
		" target=", target_cell,
		" target_cell=", target_cell,
		" path_length=", _unit_path.size(),
		" current_floor=", _unit_floor,
		" target_walkable=", _is_walkable_cell(target_cell),
		" movement_state=", "idle_already_there" if _unit_path.is_empty() else "moving")


func _find_local_grid_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if start == target:
		return result
	if not _is_walkable_cell(start) or not _is_walkable_cell(target):
		return result
	var visited := {}
	var came_from := {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == target:
			break
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next_cell: Vector2i = cell + offset
			if visited.has(next_cell) or not _is_walkable_cell(next_cell):
				continue
			visited[next_cell] = true
			came_from[next_cell] = cell
			queue.append(next_cell)
	if not visited.has(target):
		return result
	var current := target
	while current != start:
		result.push_front(current)
		current = came_from[current]
	return result


func _handle_structure_right_click(pick: Dictionary) -> void:
	if not _unit_selected:
		print("[Map3DPrototype] Interior move ignored; probe unit is not selected.")
		return
	if not pick.has("structure") or not pick.has("floor") or not pick.has("local_cell"):
		print("[Map3DPrototype][ERROR] Interior move ignored; malformed structure pick=", pick)
		return
	var structure: Dictionary = pick["structure"]
	if not _validate_structure_for_probe(structure):
		print("[Map3DPrototype][ERROR] Interior move ignored; structure validation failed.")
		return
	var structure_id := str(structure.get("id", ""))
	var floor_index := int(pick["floor"])
	var local_cell: Vector2i = pick["local_cell"]
	print("[Map3DPrototype] Interior click structure=", structure_id, " floor=", floor_index, " local=", local_cell, " walkable=", _is_structure_walkable(structure, floor_index, local_cell))
	if _unit_floor < 0:
		var entrance: Vector2i = structure.get("entrance_cells", [pick["cell"]])[0]
		if not _is_walkable_cell(entrance):
			print("[Map3DPrototype] Structure entry failed structure=", structure_id, " entrance=", entrance, " reason=entrance_not_walkable")
			return
		_pending_enter_structure_id = structure_id
		_pending_enter_local_cell = structure.get("entrance_local_cells", [local_cell])[0]
		_issue_probe_move(entrance)
		print("[Map3DPrototype] Probe moving to structure entrance for ", structure_id, " entrance=", entrance)
		return
	if _unit_structure_id != structure_id:
		print("[Map3DPrototype] Probe is inside ", _unit_structure_id, "; exit traversal is not implemented yet.")
		return
	if _unit_floor != floor_index:
		print("[Map3DPrototype] Clicked floor ", floor_index, " but probe is on floor ", _unit_floor, ". Use stairs/PageUp/PageDown focus.")
		return
	if not _is_structure_walkable(structure, floor_index, local_cell):
		_unit_interior_path.clear()
		_pending_stair_link.clear()
		_redraw_path_debug()
		print("[Map3DPrototype] Interior move rejected; target is blocked/gap/wall.")
		return
	_unit_interior_path = _find_structure_path(structure, floor_index, _unit_local_cell, local_cell)
	_pending_stair_link = _stair_link_from_cell(structure, floor_index, local_cell)
	_set_path_debug_visible(true)
	_redraw_path_debug()
	if _unit_interior_path.is_empty() and _unit_local_cell != local_cell:
		print("[Map3DPrototype] Interior move failed structure=", structure_id,
			" floor=", floor_index,
			" from=", _unit_local_cell,
			" target=", local_cell,
			" path_length=0 movement_state=failed_no_path")
		return
	print("[Map3DPrototype] Interior move command structure=", structure_id,
		" floor=", floor_index,
		" from=", _unit_local_cell,
		" target=", local_cell,
		" target_cell=", local_cell,
		" path_length=", _unit_interior_path.size(),
		" current_floor=", _unit_floor,
		" movement_state=", "idle_already_there" if _unit_interior_path.is_empty() else "moving",
		" stair_link=", _pending_stair_link)


func _make_straight_probe_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cell := start
	var guard := 0
	while cell != target and guard < _map_width + _map_height:
		var delta := target - cell
		cell += Vector2i(_step_sign(delta.x), _step_sign(delta.y))
		if not _is_walkable_cell(cell):
			return []
		path.append(cell)
		guard += 1
	return path


func _step_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func _update_probe_unit(delta: float) -> void:
	if _probe_unit != null and not _unit_interior_path.is_empty():
		_update_probe_interior(delta)
		return
	if _probe_unit == null or _unit_path_index >= _unit_path.size():
		return
	var target_cell: Vector2i = _unit_path[_unit_path_index]
	var target_position := _cell_to_unit_world(target_cell)
	var current := _probe_unit.position
	var to_target := target_position - current
	var step := UNIT_SPEED * delta
	if to_target.length() <= step:
		_probe_unit.position = target_position
		_unit_cell = target_cell
		_unit_path_index += 1
		if _unit_path_index >= _unit_path.size():
			_unit_path.clear()
			_unit_path_index = 0
			_redraw_path_debug()
			print("[Map3DPrototype] Probe move complete selected=", _unit_selected,
				" current_cell=", _unit_cell,
				" current_floor=", _unit_floor,
				" target_cell=", target_cell,
				" path_length=0 movement_state=idle")
			if _pending_enter_structure_id != "":
				_enter_pending_structure()
		return
	_probe_unit.position = current + to_target.normalized() * step


func _update_probe_interior(delta: float) -> void:
	if _probe_unit == null or _unit_interior_path.is_empty():
		return
	var target: Dictionary = _unit_interior_path[0]
	var structure := _structure_by_id(str(target.get("structure_id", _unit_structure_id)))
	if structure.is_empty():
		_unit_interior_path.clear()
		print("[Map3DPrototype][ERROR] Probe interior move aborted; structure missing id=", target.get("structure_id", _unit_structure_id))
		return
	var target_floor := int(target.get("floor", _unit_floor))
	var target_cell: Vector2i = target.get("local_cell", _unit_local_cell)
	var target_position := _structure_cell_to_world(structure, target_cell, _structure_floor_y(structure, target_floor) + UNIT_SURFACE_OFFSET)
	var current := _probe_unit.position
	var to_target := target_position - current
	var step := UNIT_SPEED * delta
	if to_target.length() <= step:
		_probe_unit.position = target_position
		_unit_floor = target_floor
		_unit_local_cell = target_cell
		_unit_interior_path.pop_front()
		if _unit_interior_path.is_empty():
			if not _pending_stair_link.is_empty():
				_traverse_pending_stair(structure)
			_redraw_path_debug()
			print("[Map3DPrototype] Probe interior move complete structure=", _unit_structure_id,
				" floor=", _unit_floor,
				" cell=", _unit_local_cell,
				" current_grid_cell=", _unit_cell,
				" path_length=0 movement_state=idle")
		return
	_probe_unit.position = current + to_target.normalized() * step


func _enter_pending_structure() -> void:
	var structure := _structure_by_id(_pending_enter_structure_id)
	if structure.is_empty():
		print("[Map3DPrototype][ERROR] Probe entry failed; pending structure missing id=", _pending_enter_structure_id)
		_pending_enter_structure_id = ""
		return
	if not _validate_structure_for_probe(structure):
		print("[Map3DPrototype][ERROR] Probe entry failed; invalid structure id=", _pending_enter_structure_id)
		_pending_enter_structure_id = ""
		_pending_enter_local_cell = Vector2i(-1, -1)
		return
	_unit_structure_id = _pending_enter_structure_id
	_unit_floor = 0
	_unit_local_cell = _pending_enter_local_cell
	_structure_view_mode = STRUCTURE_VIEW_INTERIOR_CUTAWAY
	_pending_enter_structure_id = ""
	_pending_enter_local_cell = Vector2i(-1, -1)
	_mark_floor_discovered(structure, 0)
	_set_floor_focus(0)
	_probe_unit.position = _structure_cell_to_world(structure, _unit_local_cell, _structure_floor_y(structure, 0) + UNIT_SURFACE_OFFSET)
	_redraw_path_debug()
	print("[Map3DPrototype] Probe entered structure=", _unit_structure_id,
		" current_floor=", _unit_floor,
		" current_cell=", _unit_cell,
		" local_cell=", _unit_local_cell,
		" movement_state=idle")


func _traverse_pending_stair(structure: Dictionary) -> void:
	if not _validate_structure_for_probe(structure):
		print("[Map3DPrototype][ERROR] Stair traversal failed; invalid structure id=", structure.get("id", "?"))
		_pending_stair_link.clear()
		return
	var to_floor := int(_pending_stair_link.get("to_floor", _unit_floor))
	var to_cell: Vector2i = _pending_stair_link.get("to_cell", _unit_local_cell)
	if not _is_structure_walkable(structure, to_floor, to_cell):
		print("[Map3DPrototype][ERROR] Stair traversal failed; destination blocked floor=", to_floor, " cell=", to_cell)
		_pending_stair_link.clear()
		return
	_unit_floor = to_floor
	_unit_local_cell = to_cell
	_structure_view_mode = STRUCTURE_VIEW_INTERIOR_CUTAWAY
	_mark_floor_discovered(structure, to_floor)
	_set_floor_focus(to_floor)
	_probe_unit.position = _structure_cell_to_world(structure, _unit_local_cell, _structure_floor_y(structure, to_floor) + UNIT_SURFACE_OFFSET)
	print("[Map3DPrototype] Probe used stairs structure=", _unit_structure_id,
		" current_floor=", _unit_floor,
		" local_cell=", _unit_local_cell,
		" movement_state=idle")
	_pending_stair_link.clear()


func _structure_by_id(structure_id: String) -> Dictionary:
	for structure in _content_structures:
		if str(structure.get("id", "")) == structure_id:
			return structure
	return {}


func _mark_floor_discovered(structure: Dictionary, floor_index: int) -> void:
	var discovered: Array = structure.get("discovered_floors", [])
	if not discovered.has(floor_index):
		discovered.append(floor_index)
	structure["discovered_floors"] = discovered


func _floor_data(structure: Dictionary, floor_index: int) -> Dictionary:
	for floor_value in structure.get("floors", []):
		var floor: Dictionary = floor_value
		if int(floor.get("floor_index", -1)) == floor_index:
			return floor
	return {}


func _is_structure_walkable(structure: Dictionary, floor_index: int, local_cell: Vector2i) -> bool:
	var floor := _floor_data(structure, floor_index)
	if floor.is_empty():
		return false
	return floor.get("walkable_cells", []).has(local_cell) \
		and not floor.get("wall_cells", []).has(local_cell) \
		and not floor.get("gap_cells", []).has(local_cell) \
		and not floor.get("blocker_cells", []).has(local_cell)


func _find_structure_path(structure: Dictionary, floor_index: int, start: Vector2i, target: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _is_structure_walkable(structure, floor_index, start) or not _is_structure_walkable(structure, floor_index, target):
		return result
	var visited := {}
	var came_from := {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == target:
			break
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next_cell: Vector2i = cell + offset
			if visited.has(next_cell) or not _is_structure_walkable(structure, floor_index, next_cell):
				continue
			visited[next_cell] = true
			came_from[next_cell] = cell
			queue.append(next_cell)
	if not visited.has(target):
		return result
	var cells: Array[Vector2i] = []
	var current: Vector2i = target
	while current != start:
		cells.push_front(current)
		current = came_from[current]
	for cell in cells:
		result.append({"structure_id": structure.get("id", ""), "floor": floor_index, "local_cell": cell})
	return result


func _stair_link_from_cell(structure: Dictionary, floor_index: int, local_cell: Vector2i) -> Dictionary:
	for link_value in structure.get("stair_links", []):
		var link: Dictionary = link_value
		var from_cell: Vector2i = link.get("from_cell", Vector2i(-1, -1))
		var to_cell: Vector2i = link.get("to_cell", Vector2i(-1, -1))
		if int(link.get("from_floor", -1)) == floor_index and from_cell == local_cell:
			return link
		if int(link.get("to_floor", -1)) == floor_index and to_cell == local_cell:
			return {
				"from_floor": floor_index,
				"from_cell": local_cell,
				"to_floor": int(link.get("from_floor", floor_index)),
				"to_cell": from_cell,
			}
	return {}


func _redraw_path_debug() -> void:
	if _path_root == null or not is_instance_valid(_path_root):
		return
	for child in _path_root.get_children():
		child.queue_free()
	if not _unit_interior_path.is_empty():
		var structure := _structure_by_id(_unit_structure_id)
		if structure.is_empty():
			return
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		mesh.surface_set_color(Color(1.0, 0.62, 0.16, 0.95))
		mesh.surface_add_vertex(_structure_cell_to_world(structure, _unit_local_cell, _structure_floor_y(structure, _unit_floor) + PATH_DEBUG_HEIGHT))
		for point in _unit_interior_path:
			var floor_index := int(point.get("floor", _unit_floor))
			var local_cell: Vector2i = point.get("local_cell", _unit_local_cell)
			mesh.surface_add_vertex(_structure_cell_to_world(structure, local_cell, _structure_floor_y(structure, floor_index) + PATH_DEBUG_HEIGHT))
		mesh.surface_end()
		var instance := MeshInstance3D.new()
		instance.name = "ProbeInteriorPath"
		instance.mesh = mesh
		instance.material_override = _materials["probe_path"]
		_path_root.add_child(instance)
		return
	if _unit_path.is_empty():
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_set_color(Color(0.2, 0.8, 1.0, 0.95))
	mesh.surface_add_vertex(_cell_to_path_world(_unit_cell))
	for cell in _unit_path:
		mesh.surface_add_vertex(_cell_to_path_world(cell))
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.name = "ProbePath"
	instance.mesh = mesh
	instance.material_override = _materials["probe_path"]
	_path_root.add_child(instance)


func _cell_to_unit_world(cell: Vector2i) -> Vector3:
	return _cell_to_world(cell, _surface_height_for_cell(cell) + UNIT_SURFACE_OFFSET)


func _cell_to_path_world(cell: Vector2i) -> Vector3:
	return _cell_to_world(cell, _surface_height_for_cell(cell) + PATH_DEBUG_HEIGHT)


func _is_walkable_cell(cell: Vector2i) -> bool:
	if not _is_in_generated_bounds(cell):
		return false
	if _map_generator != null and _map_generator.has_method("is_walkable_cell"):
		return bool(_map_generator.call("is_walkable_cell", cell))
	var elevation := int(_grid[cell.x][cell.y])
	return elevation != MapGenerator.E_WATER and elevation != MapGenerator.E_BLOCKED


func _pick_map_cell(screen_position: Vector2) -> Dictionary:
	if _camera == null or _map_width <= 0 or _map_height <= 0:
		return {}
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.001:
		return {}
	var structure_pick := _pick_structure_floor(origin, direction)
	if not structure_pick.is_empty():
		return structure_pick
	var t := (LOW_HEIGHT - origin.y) / direction.y
	if t < 0.0:
		return {}
	var world := origin + direction * t
	var cell := _world_to_cell(world)
	if not _is_in_generated_bounds(cell):
		print("[Map3DPrototype] Pick outside map world=", world)
		return {}
	return {
		"cell": cell,
		"world": world,
	}


func _pick_structure_floor(origin: Vector3, direction: Vector3) -> Dictionary:
	if _content_structures.is_empty() or not _visible_floors.has(_current_floor_focus):
		return {}
	if str(_visible_floors.get(_current_floor_focus, "hidden")) == "hidden":
		return {}
	for structure in _content_structures:
		if not _validate_structure_for_render(structure):
			continue
		var y := _structure_floor_y(structure, _current_floor_focus)
		if absf(direction.y) < 0.001:
			continue
		var t := (y - origin.y) / direction.y
		if t < 0.0:
			continue
		var world := origin + direction * t
		var cell := _world_to_cell(world)
		var rect: Rect2i = structure.get("exterior_rect", Rect2i())
		if rect.size == Vector2i.ZERO:
			continue
		if not rect.has_point(cell):
			continue
		var local_cell := cell - rect.position
		return {
			"cell": cell,
			"world": world,
			"structure": structure,
			"structure_id": structure.get("id", ""),
			"floor": _current_floor_focus,
			"local_cell": local_cell,
		}
	return {}


func _print_pick_debug(cell: Vector2i) -> void:
	if not _is_in_generated_bounds(cell):
		return
	var elevation := int(_grid[cell.x][cell.y])
	var feature := str(_feature_grid[cell.x][cell.y])
	var plot_info := _plot_info_for_cell(cell)
	print("[Map3DPrototype] Pick cell=", cell,
		" terrain=", _cell_type_name(cell, elevation, feature),
		" elevation=", _surface_height_for_cell(cell),
		" walkable=", _is_walkable_cell(cell),
		" raw=", elevation,
		" feature=", feature,
		" plot=", plot_info)


func _center_camera() -> void:
	if _camera_rig == null:
		return
	_camera_rig.position = Vector3.ZERO
	_update_camera_transform()


func _focus_camera_on_probe() -> void:
	if _probe_unit == null or not is_instance_valid(_probe_unit):
		print("[Map3DPrototype] Probe focus failed reason=probe_missing")
		return
	if _camera_rig == null:
		print("[Map3DPrototype] Probe focus failed reason=camera_rig_missing")
		return
	_camera_rig.position = _probe_unit.global_position
	_update_camera_transform()
	print("[Map3DPrototype] Probe focus camera world_position=", _probe_unit.global_position, " grid_cell=", _unit_cell, " floor=", _unit_floor)


func _teleport_probe_to_camera_center() -> void:
	var target := _nearest_walkable_cell_to_camera_center()
	if not _is_walkable_cell(target):
		print("[Map3DPrototype] Probe teleport failed reason=no_walkable_cell_near_camera target=", target)
		return
	_teleport_probe_to_cell(target, "keyboard_T")


func _spawn_or_reposition_probe_at_camera_center() -> void:
	if _probe_unit == null or not is_instance_valid(_probe_unit):
		print("[Map3DPrototype] Probe respawn requested with missing probe; recreating.")
		_create_gameplay_probe()
	var target := _nearest_walkable_cell_to_camera_center()
	if not _is_walkable_cell(target):
		print("[Map3DPrototype] Probe respawn failed reason=no_walkable_cell_near_camera target=", target)
		return
	_teleport_probe_to_cell(target, "keyboard_G")


func _nearest_walkable_cell_to_camera_center() -> Vector2i:
	if _camera_rig == null:
		return _probe_spawn_cell()
	var center_cell := _world_to_cell(_camera_rig.global_position)
	if _map_generator != null and _map_generator.has_method("nearest_walkable_cell"):
		var generated: Vector2i = _map_generator.call("nearest_walkable_cell", center_cell, 48)
		if _is_walkable_cell(generated):
			return generated
	return _nearest_local_walkable_cell(center_cell, 48)


func _teleport_probe_to_cell(target: Vector2i, reason: String) -> void:
	if _probe_unit == null or not is_instance_valid(_probe_unit):
		_create_gameplay_probe()
	if _probe_unit == null or not is_instance_valid(_probe_unit):
		print("[Map3DPrototype] Probe teleport failed reason=probe_create_failed")
		return
	if not _is_walkable_cell(target):
		print("[Map3DPrototype] Probe teleport failed reason=target_not_walkable target=", target)
		return
	_unit_cell = target
	_unit_path.clear()
	_unit_path_index = 0
	_unit_structure_id = ""
	_unit_floor = -1
	_unit_local_cell = Vector2i(-1, -1)
	_unit_interior_path.clear()
	_pending_enter_structure_id = ""
	_pending_enter_local_cell = Vector2i(-1, -1)
	_pending_stair_link.clear()
	_probe_unit.position = _cell_to_unit_world(target)
	_set_probe_selected(true)
	_set_probe_debug_visible(true)
	_redraw_path_debug()
	_update_probe_screen_marker()
	print("[Map3DPrototype] Probe teleported reason=", reason,
		" world_position=", _probe_unit.global_position,
		" grid_cell=", _unit_cell,
		" floor=", _unit_floor,
		" walkable=", _is_walkable_cell(_unit_cell))


func _set_probe_debug_visible(visible: bool) -> void:
	_probe_debug_visible = visible
	if _probe_unit != null and is_instance_valid(_probe_unit):
		_probe_unit.visible = visible
	if _probe_screen_marker != null:
		_probe_screen_marker.visible = visible
	print("[Map3DPrototype] Probe debug visible=", visible,
		" node_path=", _probe_unit.get_path() if _probe_unit != null and is_instance_valid(_probe_unit) else NodePath(""),
		" selectable=", visible and _probe_unit != null and is_instance_valid(_probe_unit))


func _validate_probe_runtime() -> void:
	if not show_gameplay_probe:
		return
	if _probe_unit == null or not is_instance_valid(_probe_unit):
		if not _probe_missing_error_printed:
			_probe_missing_error_printed = true
			print("[Map3DPrototype][ERROR] Probe runtime validation failed reason=probe_missing scene=", name)
		return
	if not _probe_unit.visible:
		if not _probe_hidden_warning_printed:
			_probe_hidden_warning_printed = true
			print("[Map3DPrototype][WARN] Probe runtime validation warning reason=probe_hidden scene=", name, " toggle_with_V=true")
	else:
		_probe_hidden_warning_printed = false
	if _unit_floor >= 0:
		return
	var world_cell := _world_to_cell(_probe_unit.global_position)
	var moving := _unit_path_index < _unit_path.size() or not _unit_interior_path.is_empty()
	if not moving and world_cell != _unit_cell and _is_walkable_cell(world_cell):
		_unit_cell = world_cell
	if not moving and not _is_walkable_cell(_unit_cell):
		var repaired := _nearest_local_walkable_cell(_unit_cell, 24)
		if _is_walkable_cell(repaired):
			if not _probe_invalid_position_warning_printed:
				print("[Map3DPrototype][WARN] Probe repaired invalid cell old=", _unit_cell, " new=", repaired, " reason=inside_blocker_water_or_wall")
				_probe_invalid_position_warning_printed = true
			_teleport_probe_to_cell(repaired, "runtime_repair")
		return
	var terrain_y := _surface_height_for_cell(_unit_cell) + UNIT_SURFACE_OFFSET
	if _probe_unit.global_position.y < terrain_y - 0.2:
		_probe_unit.global_position.y = terrain_y
		if not _probe_invalid_position_warning_printed:
			print("[Map3DPrototype][WARN] Probe lifted above terrain cell=", _unit_cell, " y=", terrain_y)
			_probe_invalid_position_warning_printed = true


func _adjust_monolith_footprint(delta: int) -> void:
	if not use_monolith_test_map:
		print("[Map3DPrototype] Monolith footprint shortcut ignored; use monolith_structure_test.tscn for live footprint resizing.")
		return
	var allowed: Array[int] = [12, 16, 20]
	var current := _allowed_monolith_footprint(monolith_footprint_size)
	var index := allowed.find(current)
	if index < 0:
		index = 1
	index = clampi(index + delta, 0, allowed.size() - 1)
	monolith_footprint_size = allowed[index]
	_current_floor_focus = 0
	print("[Map3DPrototype] Monolith footprint changed to ", monolith_footprint_size, " regenerating test scene.")
	_regenerate_map()


func _cell_to_world(cell: Vector2i, y: float) -> Vector3:
	return Vector3(
		(float(cell.x) - float(_map_width) * 0.5 + 0.5) * TILE_SIZE,
		y,
		(float(cell.y) - float(_map_height) * 0.5 + 0.5) * TILE_SIZE
	)


func _rect_center_to_world(rect: Rect2i) -> Vector3:
	return Vector3(
		(float(rect.position.x) + float(rect.size.x) * 0.5 - float(_map_width) * 0.5) * TILE_SIZE,
		0.0,
		(float(rect.position.y) + float(rect.size.y) * 0.5 - float(_map_height) * 0.5) * TILE_SIZE
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
		MapGenerator.E_HIGH, MapGenerator.E_MID:
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


func _is_ramp_carve_debug_cell(cell: Vector2i) -> bool:
	if not _is_in_generated_bounds(cell):
		return false
	var feature := str(_feature_grid[cell.x][cell.y])
	return feature == "ramp_carve" or feature == "ramp_soft_edge" or feature == "ramp_top_landing" or feature == "ramp_bottom_landing"


func _is_cliff_edge_cell(cell: Vector2i) -> bool:
	if _is_ramp_opening_cliff_cell(cell):
		return false
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var neighbor: Vector2i = cell + direction
		if not _is_in_generated_bounds(neighbor):
			continue
		var elevation := int(_grid[neighbor.x][neighbor.y])
		if elevation == MapGenerator.E_LOW or elevation == MapGenerator.E_WATER or elevation == MapGenerator.E_RAMP:
			return true
	return false


func _is_ramp_opening_cliff_cell(cell: Vector2i) -> bool:
	if not _is_in_generated_bounds(cell):
		return false
	var elevation := int(_grid[cell.x][cell.y])
	if elevation != MapGenerator.E_HIGH and elevation != MapGenerator.E_MID:
		return false
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var ramp_cell := cell - direction
		if not _is_in_generated_bounds(ramp_cell):
			continue
		if int(_grid[ramp_cell.x][ramp_cell.y]) == MapGenerator.E_RAMP and _find_high_neighbor_direction(ramp_cell) == direction:
			return true
	return false


func _is_cliff_corner_cell(cell: Vector2i) -> bool:
	var low_dirs := 0
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var neighbor: Vector2i = cell + direction
		if not _is_in_generated_bounds(neighbor):
			continue
		var elevation := int(_grid[neighbor.x][neighbor.y])
		if elevation == MapGenerator.E_LOW or elevation == MapGenerator.E_WATER or elevation == MapGenerator.E_RAMP:
			low_dirs += 1
	return low_dirs >= 2


func _is_water_edge_cell(cell: Vector2i) -> bool:
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var neighbor: Vector2i = cell + direction
		if _is_in_generated_bounds(neighbor) and int(_grid[neighbor.x][neighbor.y]) != MapGenerator.E_WATER:
			return true
	return false


func _first_low_neighbor_direction(cell: Vector2i) -> Vector2i:
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var neighbor: Vector2i = cell + direction
		if not _is_in_generated_bounds(neighbor):
			continue
		var elevation := int(_grid[neighbor.x][neighbor.y])
		if elevation == MapGenerator.E_LOW or elevation == MapGenerator.E_WATER or elevation == MapGenerator.E_RAMP:
			return direction
	return Vector2i.DOWN


func _rotation_for_direction(direction: Vector2i) -> float:
	if direction == Vector2i.RIGHT:
		return -PI * 0.5
	if direction == Vector2i.LEFT:
		return PI * 0.5
	if direction == Vector2i.UP:
		return PI
	return 0.0


func _print_biome_debug(cliff_edge_count: int) -> void:
	var plateau_count := _estimate_plateau_count()
	print("[Map3DPrototype] Biome=", biome_name,
		" mode=", presentation_mode,
		" asset_pack=", asset_pack_config_path,
		" material_pack=", asset_pack_config_path,
		" use_meshes=", use_biome_mesh_assets,
		" loaded_category_count=", _loaded_category_count(),
		" asset_count_per_category=", _biome_asset_counts,
		" missing_categories=", _missing_3d_categories,
		" missing_legacy_tags=", _missing_asset_tags,
		" fallback_count=", _fallback_counts,
		" prop_count_by_type=", _scene_instance_counts,
		" average_prop_scale=%.2f" % _average_prop_scale(),
		" visible_overlay_count=", _visible_overlay_count(),
		" readability_overlay_count=", _readability_overlay_count,
		" landmark_count=", _landmarks.size(),
		" landmarks=", _landmark_debug_summary(),
		" road_render_mode=", _road_render_mode,
		" road_mesh_count=", _road_mesh_count,
		" ramp_count=", _ramp_visual_count,
		" ramp_cells=", _ramp_debug_records,
		" ramp_top_height=", HIGH_HEIGHT,
		" ramp_bottom_height=", LOW_HEIGHT,
		" ramp_openings_carved=", _ramp_opening_carve_count,
		" ramps_missing_adjacent_high=", _ramps_missing_high_ground,
		" blocker_density=%.3f" % (float(_blocker_count) / maxf(1.0, float(_map_width * _map_height))),
		" blocker_meshes=", _biome_blocker_mesh_count,
		" decor_meshes=", _biome_decor_count,
		" plateau_count=", plateau_count,
		" cliff_edge_cells=", cliff_edge_count)


func _landmark_debug_summary() -> Array[String]:
	var summary: Array[String] = []
	for landmark in _landmarks:
		summary.append("%s:%s@%s rarity=%s scale=%s hierarchy=%s footprint=%s blockers=%s water=%s road_anchor=%s road_behavior=%s validation=%s" % [
			str(landmark.get("id", "?")),
			str(landmark.get("kind", "?")),
			str(landmark.get("center", Vector2i.ZERO)),
			str(landmark.get("rarity", "?")),
			str(landmark.get("scale_class", "?")),
			str(landmark.get("terrain_hierarchy", "?")),
			str(landmark.get("footprint_size", 0)),
			str(landmark.get("blocked_count", 0)),
			str(landmark.get("water_count", 0)),
			str(landmark.get("road_anchor", Vector2i.ZERO)),
			str(landmark.get("road_behavior", "")),
			str(landmark.get("validation", "")),
		])
	return summary


func _loaded_category_count() -> int:
	var count := 0
	for value in _biome_asset_counts.values():
		if int(value) > 0:
			count += 1
	return count


func _average_prop_scale() -> float:
	if _prop_scale_count <= 0:
		return 0.0
	return _prop_scale_total / float(_prop_scale_count)


func _visible_overlay_count() -> int:
	var count := 0
	if _plot_root != null and is_instance_valid(_plot_root) and _plot_root.visible:
		count += _debug_overlay_count
	if _path_root != null and is_instance_valid(_path_root) and _path_root.visible:
		count += _path_root.get_child_count()
	if _readability_root != null and is_instance_valid(_readability_root) and _readability_root.visible:
		count += _readability_overlay_count
	return count


func _estimate_plateau_count() -> int:
	var visited := {}
	var count := 0
	for x in range(_map_width):
		for y in range(_map_height):
			var cell := Vector2i(x, y)
			if visited.has(cell):
				continue
			if int(_grid[x][y]) != MapGenerator.E_HIGH:
				continue
			count += 1
			var frontier: Array[Vector2i] = [cell]
			visited[cell] = true
			while not frontier.is_empty():
				var current: Vector2i = frontier.pop_back()
				for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var next: Vector2i = current + direction
					if not _is_in_generated_bounds(next) or visited.has(next):
						continue
					if int(_grid[next.x][next.y]) == MapGenerator.E_HIGH:
						visited[next] = true
						frontier.append(next)
	return count


func _is_in_generated_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _map_width and cell.y < _map_height


func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, max(0, _map_width - 1)), clampi(cell.y, 0, max(0, _map_height - 1)))


func _print_cell_under_mouse(screen_position: Vector2) -> void:
	if _camera == null or _map_width <= 0 or _map_height <= 0:
		return
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.001:
		return
	var t := (LOW_HEIGHT - origin.y) / direction.y
	if t < 0.0:
		return
	var world := origin + direction * t
	var cell := _world_to_cell(world)
	if not _is_in_generated_bounds(cell):
		print("[Map3DPrototype] Pick outside map world=", world)
		return
	var elevation := int(_grid[cell.x][cell.y])
	var feature := str(_feature_grid[cell.x][cell.y])
	var plot_info := _plot_info_for_cell(cell)
	print("[Map3DPrototype] Pick cell=", cell,
		" terrain=", _cell_type_name(cell, elevation, feature),
		" elevation=", _surface_height_for_cell(cell),
		" raw=", elevation,
		" feature=", feature,
		" plot=", plot_info)


func _cell_type_name(cell: Vector2i, elevation: int, feature: String) -> String:
	if _is_road_cell(cell):
		return "ROAD"
	if feature == "ramp_carve" or feature == "ramp_soft_edge":
		return "RAMP_CARVE"
	if feature == "ramp_top_landing":
		return "RAMP_TOP_LANDING"
	if feature == "ramp_bottom_landing":
		return "RAMP_BOTTOM_LANDING"
	if feature == "base_floor" or feature == "economy_space":
		return "BASE_PLOT"
	if feature == "content_plot_blank" or feature == "objective" or feature == "tower_floor" or feature == "bandit_floor":
		return "CONTENT_PLOT"
	match elevation:
		MapGenerator.E_WATER:
			return "WATER"
		MapGenerator.E_BLOCKED:
			return "BLOCKER"
		MapGenerator.E_RAMP:
			return "RAMP"
		MapGenerator.E_HIGH, MapGenerator.E_MID:
			return "HIGH"
	return "LOW"


func _plot_info_for_cell(cell: Vector2i) -> String:
	for plot in _plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.has_point(cell):
			return "%s/%s" % [str(plot.get("kind", "plot")), str(plot.get("id", ""))]
	return "none"


func _hash_cell(cell: Vector2i, salt: int) -> int:
	return int(abs((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)))
