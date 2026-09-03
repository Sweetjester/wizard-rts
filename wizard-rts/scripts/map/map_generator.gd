class_name MapGenerator
extends Node

signal map_generated(summary: Dictionary)

# ── CONFIG ─────────────────────────────────────────────────────────────────────
const MAP_W = 96
const MAP_H = 96

const E_BLOCKED = -2
const E_WATER = -1
const E_LOW   =  0
const E_MID   =  1
const E_HIGH  =  2
const E_RAMP  =  3
const BLOCK_SIZE = 5

# Platform definitions
const HG_X1 = 17
const HG_X2 = 33
const HG_Y1 =  4
const HG_Y2 = 17
const CP_X1 = 22
const CP_X2 = 28
const CP_Y  = 17
const RAMP_Y = 18
const MG_X1 =  8
const MG_X2 = 42
const MG_Y1 = 14
const MG_Y2 = 40
const LK_CX = 25
const LK_CY = 29
const LK_RX =  7
const LK_RY =  5

const MAP_TYPE_VAMPIRE_MUSHROOM_FOREST := "vampire_mushroom_forest"
const MAP_TYPE_SEEDED_GRID_FRONTIER := "seeded_grid_frontier"
const MAP_TYPE_GRID_TEST_CANVAS := "grid_test_canvas"
const MAP_TYPE_AI_TESTING_GROUND := "ai_testing_ground"
const MAP_TYPE_FORTRESS_AI_ARENA := "fortress_ai_arena"
const MAP_TYPE_PLOT_GENERATOR_TEST := "plot_generator_test"
const GRID_TEST_CELL_SIZE := 64
const FRONTIER_MAIN_ROAD_X := 48
const FRONTIER_MAIN_ROAD_Y := 48
const FRONTIER_ROAD_SPINES := [12, 48, 84]
const AssetRegistryScript := preload("res://scripts/assets/asset_registry.gd")
const AssetPackConfigScript := preload("res://scripts/assets/asset_pack_config.gd")
const ContentStructureGeneratorScript := preload("res://scripts/map/content_structures/ContentStructureGenerator.gd")
const MapPlotConfigResource := preload("res://scripts/map/plots/MapPlotConfig.gd")
const PlotGeneratorResource := preload("res://scripts/map/plots/PlotGenerator.gd")
const ACTIVE_ASSET_PACK_CONFIG_PATH := "res://resources/asset_packs/tiny_swords_asset_pack.json"
const RUNTIME_TERRAIN_TILESET_PATH := "res://resources/tilesets/tiny_swords_plot_tileset.tres"
const TERRAIN_SET_GRASS := 0
const TERRAIN_ID_GRASS := 0
const TERRAIN_SET_ROAD := 3
const TERRAIN_ID_ROAD := 0
const TINY_WATER_SOURCE_ID := 0
const TINY_WATER_ATLAS := Vector2i(0, 0)
const ELEVATION_HIGH := "HIGH"
const ELEVATION_LOW := "LOW"
const BASE_ARCHETYPE_FORTRESS := "FORTRESS_BASE"
const BASE_ARCHETYPE_HOLDFAST := "HOLDFAST_BASE"
const BASE_ARCHETYPE_EXPANSION := "EXPANSION_BASE"
const ROAD_MODE_GRID_ARTERIES := "grid_arteries"
const ROAD_MODE_ORGANIC_SPINE_AND_BRANCHES := "organic_spine_and_branches"
const BIOME_DARK_FOREST_FRONTIER_V2 := "DARK_FOREST_FRONTIER_V2"
const LANDMARK_GIANT_CORRUPTED_TREE := "giant_corrupted_tree"
const LANDMARK_DEAD_ROOT_CANYON := "dead_root_canyon"
const LANDMARK_ELEVATED_SHRINE_PLATEAU := "elevated_shrine_plateau"
const LANDMARK_DEAD_ROOT_MAZE := "dead_root_maze"
const LANDMARK_MUSHROOM_RITUAL_BASIN := "mushroom_ritual_basin"
const LANDMARK_MUSHROOM_RITUAL_CIRCLE := "mushroom_ritual_circle"
const LANDMARK_CLIFF_RIDGE_BARRIER := "cliff_ridge_barrier"
const LANDMARK_CLIFF_WALL_BARRIER := "cliff_wall_barrier"
const LANDMARK_ANCIENT_RUIN_CLUSTER := "ancient_ruin_cluster"
const LANDMARK_BROKEN_RUIN_CLUSTER := "broken_ruin_cluster"
const LANDMARK_SWAMP_DEPRESSION := "swamp_depression"
const LANDMARK_SWAMP_BASIN := "swamp_basin"
const FRONTIER_MAIN_SPINE_ROAD_WIDTH := 3
const FRONTIER_BRANCH_ROAD_WIDTH := 2
const FRONTIER_PLOT_APPROACH_ROAD_WIDTH := 2
const FRONTIER_MAX_JUNCTION_SIZE := 4
const ElevationDebugOverlayScript := preload("res://scripts/map/elevation_debug_overlay.gd")

# ── STATE ──────────────────────────────────────────────────────────────────────
var layer_low:  TileMapLayer
var layer_mid:  TileMapLayer
var layer_high: TileMapLayer
var T: Dictionary = {}
var grid: Array = []
var feature_grid: Array = []
var height_map: Array = []
var movement_costs: Array = []
@export var map_type_id: String = MAP_TYPE_SEEDED_GRID_FRONTIER
@export var map_seed: int = 20260425
@export var map_seed_text: String = ""
@export var show_elevation_debug: bool = true
@export var show_visual_props: bool = true
@export_enum("organic_spine_and_branches", "grid_arteries") var frontier_road_layout_mode: String = ROAD_MODE_ORGANIC_SPINE_AND_BRANCHES
var _rng := DeterministicRng.new()
var _pathfinder := AStarGrid2D.new()
var seed_value: int = 20260425

var hg_x1 := HG_X1
var hg_x2 := HG_X2
var hg_y1 := HG_Y1
var hg_y2 := HG_Y2
var cp_x1 := CP_X1
var cp_x2 := CP_X2
var cp_y := CP_Y
var ramp_y := RAMP_Y
var mg_x1 := MG_X1
var mg_x2 := MG_X2
var mg_y1 := MG_Y1
var mg_y2 := MG_Y2
var lk_cx := LK_CX
var lk_cy := LK_CY
var lk_rx := LK_RX
var lk_ry := LK_RY
var lakes: Array[Dictionary] = []
var ramps: Array[Rect2i] = []
var landmarks: Array[Dictionary] = []
var road_cells: Dictionary = {}
var dynamic_blocked_cells: Dictionary = {}
var _path_cache: Dictionary = {}
var _path_cache_version: int = 0
var _flow_field_cache: Dictionary = {}
# Both of these hold the STATIC half of pathfinding -- terrain shape only, with
# runtime blockers deliberately excluded. That is what lets them survive
# building placement, which is the whole point: a Vinewall going down used to
# throw away every cached traversability answer on the map and force a full
# recompute inside the physics frame. They are cleared only when the map itself
# is regenerated.
var _traversable_cache: Dictionary = {}
var _flow_neighbors_cache: Dictionary = {}
# Memo for the *static* half of traversability: whether a cell is an unramped
# height edge. This depends only on the generated map (height map, ramps,
# plots, feature grid), never on runtime blockers, so unlike the two caches
# above it survives building placement and is only cleared when the map itself
# is regenerated.
var _height_edge_cache: Dictionary = {}
const PATH_CACHE_LIMIT := 768
var path_requests_total := 0
var path_cache_hits_total := 0
var flow_field_recomputes_total := 0
var units_using_flow_field_total := 0
var _path_requests_this_second := 0
var _path_cache_hits_this_second := 0
var _flow_field_recomputes_this_second := 0
var _units_using_flow_field_this_second := 0
var _path_requests_per_second := 0
var _path_cache_hits_per_second := 0
var _flow_field_recomputes_per_second := 0
var _units_using_flow_field_per_second := 0
var _path_meter_elapsed := 0.0

var spawn_positions: Array = []
var enemy_spawns:    Array = []
var chokepoints:     Array = []
var economy_zones:   Array = []
var plots: Array[Dictionary] = []
var base_plots: Array[Dictionary] = []
var _plot_test_bounds := Rect2i()
var _elevation_debug_overlay: Node2D
var _frontier_plateaus: Array[Dictionary] = []
var _frontier_road_debug := {}
var _asset_registry: Node
var _active_asset_pack_id := "<fallback>"
var _active_asset_pack_tileset_path := RUNTIME_TERRAIN_TILESET_PATH
var _low_ground_mapping: Dictionary = {}
var _road_mapping: Dictionary = {}
var _water_mapping: Dictionary = {}
var _low_ground_fallback_used := true
var _road_fallback_used := true
var _water_fallback_used := true
var _low_ground_terrain_set_id := TERRAIN_SET_GRASS
var _low_ground_terrain_id := TERRAIN_ID_GRASS
var _road_terrain_set_id := TERRAIN_SET_ROAD
var _road_terrain_id := TERRAIN_ID_ROAD
var _water_source_id := TINY_WATER_SOURCE_ID
var _water_atlas := TINY_WATER_ATLAS
var _prop_visual_root: Node2D
var _prop_textures := {}
var _visual_prop_counts := {}

# ── INIT ───────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer_low  = get_parent().get_node("TileMapLow")
	layer_mid  = get_parent().get_node("TileMapMid")
	layer_high = get_parent().get_node("TileMapHigh")
	_apply_session_settings()
	seed_value = _resolve_seed()
	_rng = DeterministicRng.new(seed_value)
	_configure_map_type()
	if map_type_id == MAP_TYPE_PLOT_GENERATOR_TEST:
		_build_plot_generator_test_map()
		print("[MapGenerator] ", get_map_type_name(), " seed=", seed_value, " complete")
		print("[MapGenerator] Plot test spawns:", spawn_positions.size(), " | Anchors:", chokepoints.size())
		map_generated.emit(get_map_summary())
		return
	_configure_seeded_layout()
	_load_tiles()
	_build_grid()
	_build_plots()
	_assign_plot_elevations()
	_build_elevation_zones()
	_stamp_plots_into_grid()
	_flatten_tiny_high_fragments()
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		_build_landmarks()
	_build_roads()
	_flatten_tiny_high_fragments()
	_validate_frontier_elevation_layout(true)
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		_build_landmarks()
	_validate_frontier_landmarks(true)
	_validate_content_structures(true)
	_build_height_and_cost_maps()
	_build_pathfinder()
	_paint()
	_register_zones()
	_debug_print_elevation_summary()
	print("[MapGenerator] ", get_map_type_name(), " seed=", seed_value, " complete")
	print("[MapGenerator] Spawns:", spawn_positions.size(),
		" | Enemies:", enemy_spawns.size(),
		" | Chokepoints:", chokepoints.size(),
		" | Plots:", plots.size())
	map_generated.emit(get_map_summary())

func _process(delta: float) -> void:
	_path_meter_elapsed += delta
	if _path_meter_elapsed < 1.0:
		return
	_path_requests_per_second = _path_requests_this_second
	_path_cache_hits_per_second = _path_cache_hits_this_second
	_flow_field_recomputes_per_second = _flow_field_recomputes_this_second
	_units_using_flow_field_per_second = _units_using_flow_field_this_second
	_path_requests_this_second = 0
	_path_cache_hits_this_second = 0
	_flow_field_recomputes_this_second = 0
	_units_using_flow_field_this_second = 0
	_path_meter_elapsed = 0.0

func _apply_session_settings() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	if bool(session.get("new_game_requested")):
		map_type_id = str(session.get("map_type_id"))
		map_seed_text = str(session.get("map_seed_text"))

func get_map_type_name() -> String:
	match map_type_id:
		MAP_TYPE_SEEDED_GRID_FRONTIER:
			return "Seeded Grid Frontier"
		MAP_TYPE_VAMPIRE_MUSHROOM_FOREST:
			return "Vampiric Mushroom Forest"
		MAP_TYPE_GRID_TEST_CANVAS:
			return "Grid Test Canvas"
		MAP_TYPE_AI_TESTING_GROUND:
			return "Kon's Observation Arena"
		MAP_TYPE_FORTRESS_AI_ARENA:
			return "Kon's Siege Arena"
		MAP_TYPE_PLOT_GENERATOR_TEST:
			return "Plot Generator Test"
	return map_type_id

func get_map_type_data() -> Dictionary:
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		return {
			"id": MAP_TYPE_SEEDED_GRID_FRONTIER,
			"name": "Seeded Grid Frontier",
			"art_style": "Clean square-grid RTS terrain with readable roads, high-ground bases, ramps, lakes, forests, and mountains.",
			"story_theme": "A neutral procedural frontier framework built to receive future art themes without changing gameplay rules.",
			"terrain_design": "Large connected road network linking high-ground base plots, 10x10 content plots, blocked terrain, water, and expansion routes.",
			"plot_rule": "Plots are reserved first, then connected by roads, then blockers and water are stamped around the network without breaking connectivity.",
		}
	if map_type_id == MAP_TYPE_FORTRESS_AI_ARENA:
		return {
			"id": MAP_TYPE_FORTRESS_AI_ARENA,
			"name": "Kon's Siege Arena",
			"art_style": "Flat square-grid siege lane with mirrored forts, blockers, and clear base footprints.",
			"story_theme": "Kon observes two controlled factions assaulting fortified bases until one keep falls.",
			"terrain_design": "Small symmetrical pathing test map with west and east forts, wall gaps, internal buildings, and open lanes.",
			"plot_rule": "Two fort plots are stamped onto a clean arena; runtime structures create the actual impassible walls and keeps.",
		}
	if map_type_id == MAP_TYPE_AI_TESTING_GROUND:
		return {
			"id": MAP_TYPE_AI_TESTING_GROUND,
			"name": "Kon's Observation Arena",
			"art_style": "Flat green RTS arena with always-visible square grid and clean blocker lanes.",
			"story_theme": "A sterile combat proving ground for faction AI, pathing, waves, and stress testing.",
			"terrain_design": "Small arena with two opposing staging areas, open center lanes, and square-grid blockers.",
			"plot_rule": "Two faction bases and a central arena are stamped directly onto the grid.",
		}
	if map_type_id == MAP_TYPE_GRID_TEST_CANVAS:
		return {
			"id": MAP_TYPE_GRID_TEST_CANVAS,
			"name": "Grid Test Canvas",
			"art_style": "Flat green debug canvas with a visible isometric grid.",
			"story_theme": "A systems proving ground for RTS footprints, pathing, blockers, and economy plots.",
			"terrain_design": "Single-height flat terrain with no decorative clutter, made to test building placement and unit movement.",
			"plot_rule": "Simple rectangular base plots with economy spaces are stamped directly onto the grid.",
		}
	if map_type_id == MAP_TYPE_PLOT_GENERATOR_TEST:
		return {
			"id": MAP_TYPE_PLOT_GENERATOR_TEST,
			"name": "Plot Generator Test",
			"art_style": "Tiny Swords island plots with water, organic coastlines, multi-level grass cliffs, foam, rocks, bushes, and overhang decoration.",
			"story_theme": "A focused island laboratory for validating content-plot generation before it is stamped into full RTS worlds.",
			"terrain_design": "One procedural island plot generated through logical tile layers: water, foam, grass landmass, cliff faces, cliff tops, overhangs, and decoration.",
			"plot_rule": "The plot exposes walkable cells and road connection anchors so a future world generator can stamp it at any offset.",
		}
	return {
		"id": MAP_TYPE_VAMPIRE_MUSHROOM_FOREST,
		"name": "Vampiric Mushroom Forest",
		"art_style": "Dark forest greens, meaningful blood reds, rare cyan bioluminescence, bone-white fungi.",
		"story_theme": "A sealed Life Wizard ecosystem where evolution learned to drink blood through fungal colonies.",
		"terrain_design": "WC3/SC2-style readable low, middle, and high ground with water, impassable fungal growth, ramps, open build spaces, and natural bottlenecks.",
		"plot_rule": "Hand-authored plot templates are placed into seeded terrain: base candidates, quest locations, enemy outposts, and objectives.",
	}

func get_seed_value() -> int:
	return seed_value

func _resolve_seed() -> int:
	if not map_seed_text.strip_edges().is_empty():
		return _hash_seed_text(map_seed_text)
	return map_seed

func _hash_seed_text(text: String) -> int:
	var hash := 2166136261
	for i in text.length():
		hash = int((hash ^ text.unicode_at(i)) & 0xffffffff)
		hash = int((hash * 16777619) & 0xffffffff)
	if hash == 0:
		hash = 1
	return hash

func _configure_map_type() -> void:
	if _uses_square_grid_map():
		return
	if map_type_id != MAP_TYPE_VAMPIRE_MUSHROOM_FOREST:
		push_warning("[MapGenerator] Unknown map type '%s', using Seeded Grid Frontier rules" % map_type_id)
		map_type_id = MAP_TYPE_SEEDED_GRID_FRONTIER

func _configure_seeded_layout() -> void:
	if _uses_square_grid_map():
		ramps.clear()
		lakes.clear()
		landmarks.clear()
		hg_x1 = 0
		hg_x2 = 0
		hg_y1 = 0
		hg_y2 = 0
		mg_x1 = 0
		mg_x2 = 0
		mg_y1 = 0
		mg_y2 = 0
		return
	var high_shift := _rng.range_int(-10, 10)
	var mid_shift := _rng.range_int(-8, 8)

	hg_x1 = clampi(36 + high_shift, 22, 48)
	hg_x2 = clampi(hg_x1 + _rng.range_int(24, 33), hg_x1 + 18, MAP_W - 9)
	hg_y1 = clampi(8 + _rng.range_int(-3, 5), 5, 18)
	hg_y2 = clampi(hg_y1 + _rng.range_int(20, 28), hg_y1 + 16, MAP_H - 44)
	cp_x1 = clampi(hg_x1 + _rng.range_int(5, 12), hg_x1 + 2, hg_x2 - 8)
	cp_x2 = cp_x1 + _rng.range_int(7, 11)
	cp_y = hg_y2
	ramp_y = cp_y + _rng.range_int(5, 8)

	mg_x1 = clampi(10 + mid_shift, 5, 24)
	mg_x2 = clampi(MAP_W - 12 + mid_shift, 68, MAP_W - 5)
	mg_y1 = clampi(22 + _rng.range_int(-5, 5), 14, 34)
	mg_y2 = clampi(MAP_H - 18 + _rng.range_int(-5, 4), 66, MAP_H - 8)

	ramps.clear()
	ramps.append(Rect2i(cp_x1, cp_y, cp_x2 - cp_x1 + 1, ramp_y - cp_y + 1))
	ramps.append(Rect2i(clampi(hg_x1 - 8, 5, MAP_W - 14), clampi(hg_y1 + 7, 5, MAP_H - 10), 9, 6))
	ramps.append(Rect2i(clampi(hg_x2 - 2, 5, MAP_W - 14), clampi(hg_y1 + 12, 5, MAP_H - 10), 9, 6))
	ramps.append(Rect2i(clampi(_rng.range_int(mg_x1 + 8, mg_x2 - 16), 5, MAP_W - 14), clampi(_rng.range_int(mg_y1 + 10, mg_y2 - 12), 5, MAP_H - 10), 10, 5))
	ramps.append(Rect2i(clampi(_rng.range_int(12, MAP_W - 22), 5, MAP_W - 14), clampi(_rng.range_int(50, MAP_H - 16), 5, MAP_H - 10), 8, 7))

	lakes.clear()
	var lake_count := _rng.range_int(4, 6)
	for i in range(lake_count):
		lakes.append({
			"center": Vector2i(_rng.range_int(12, MAP_W - 13), _rng.range_int(16, MAP_H - 13)),
			"radius": Vector2i(_rng.range_int(5, 12), _rng.range_int(4, 8)),
		})
	var primary_lake: Dictionary = lakes[0]
	lk_cx = primary_lake["center"].x
	lk_cy = primary_lake["center"].y
	lk_rx = primary_lake["radius"].x
	lk_ry = primary_lake["radius"].y

func _load_tiles() -> void:
	var ts = layer_low.tile_set
	if not ts: push_error("[MapGenerator] No TileSet on TileMapLow"); return
	_load_asset_registry()
	_log_runtime_tileset(ts)
	for i in ts.get_source_count():
		var sid = ts.get_source_id(i)
		var src = ts.get_source(sid)
		if not src or not src.texture: continue
		var fname = src.texture.resource_path.get_file().replace(".png","")
		if not src.has_tile(Vector2i(0,0)):
			src.create_tile(Vector2i(0,0))
		var parts = fname.split("_")
		if parts.size() >= 2:
			var terrain = "_".join(parts.slice(0, parts.size()-1))
			if not T.has(terrain): T[terrain] = []
			T[terrain].append(sid)
	T["water"] = [TINY_WATER_SOURCE_ID]
	_register_tiny_swords_nonterrain_sources(ts)
	print("[MapGenerator] Loaded", T.size(), "terrain types")

func _load_asset_registry() -> void:
	_asset_registry = AssetRegistryScript.new()
	var loaded: bool = _asset_registry.call("load_asset_pack", ACTIVE_ASSET_PACK_CONFIG_PATH)
	if not loaded:
		push_warning("[MapGenerator] Asset pack could not load: %s. Using terrain rendering fallbacks." % ACTIVE_ASSET_PACK_CONFIG_PATH)
		_print_asset_registry_debug()
		return
	var pack: Resource = _asset_registry.call("get_active_pack")
	if pack == null:
		push_warning("[MapGenerator] Asset pack loaded with no active pack. Using terrain rendering fallbacks.")
		_print_asset_registry_debug()
		return
	_active_asset_pack_id = str(pack.get("pack_id"))
	_active_asset_pack_tileset_path = str(pack.get("runtime_tileset_path"))
	if _active_asset_pack_tileset_path == "":
		push_warning("[MapGenerator] Asset pack '%s' has no TileSet path. Using existing TileMapLow TileSet." % _active_asset_pack_id)

	_low_ground_mapping = _asset_registry.call("resolve_terrain", AssetPackConfigScript.LOW_GROUND)
	_road_mapping = _asset_registry.call("resolve_terrain", AssetPackConfigScript.ROAD)
	_water_mapping = _asset_registry.call("resolve_visual_tag", AssetPackConfigScript.WATER)

	_apply_low_ground_mapping()
	_apply_road_mapping()
	_apply_water_mapping()
	_load_visual_prop_assets()
	_print_asset_registry_debug()

func _apply_low_ground_mapping() -> void:
	_low_ground_fallback_used = true
	if _low_ground_mapping.is_empty():
		push_warning("[MapGenerator] LOW_GROUND terrain mapping missing. Using fallback terrain_set_id=%s terrain_id=%s." % [TERRAIN_SET_GRASS, TERRAIN_ID_GRASS])
		return
	_low_ground_terrain_set_id = int(_low_ground_mapping.get("terrain_set_id", TERRAIN_SET_GRASS))
	_low_ground_terrain_id = int(_low_ground_mapping.get("terrain_id", TERRAIN_ID_GRASS))
	_low_ground_fallback_used = false

func _apply_road_mapping() -> void:
	_road_fallback_used = true
	if _road_mapping.is_empty():
		push_warning("[MapGenerator] ROAD terrain mapping missing. Using fallback terrain_set_id=%s terrain_id=%s." % [TERRAIN_SET_ROAD, TERRAIN_ID_ROAD])
		return
	_road_terrain_set_id = int(_road_mapping.get("terrain_set_id", TERRAIN_SET_ROAD))
	_road_terrain_id = int(_road_mapping.get("terrain_id", TERRAIN_ID_ROAD))
	_road_fallback_used = false

func _apply_water_mapping() -> void:
	_water_fallback_used = true
	if _water_mapping.is_empty():
		push_warning("[MapGenerator] WATER mapping missing. Using fallback source_id=%s atlas=%s." % [TINY_WATER_SOURCE_ID, TINY_WATER_ATLAS])
		return
	var kind := str(_water_mapping.get("kind", ""))
	if kind != "atlas":
		push_warning("[MapGenerator] WATER mapping kind '%s' is not supported by the current renderer. Using atlas fallback." % kind)
		return
	_water_source_id = int(_water_mapping.get("source_id", TINY_WATER_SOURCE_ID))
	_water_atlas = _mapping_vector2i(_water_mapping.get("atlas_coords", TINY_WATER_ATLAS), TINY_WATER_ATLAS)
	_water_fallback_used = false

func _mapping_vector2i(value, fallback: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func _print_asset_registry_debug() -> void:
	print("[MapGenerator] Asset pack id=", _active_asset_pack_id,
		" tileset=", _active_asset_pack_tileset_path,
		" LOW_GROUND=", _low_ground_mapping,
		" ROAD=", _road_mapping,
		" WATER=", _water_mapping,
		" fallback_low=", _low_ground_fallback_used,
		" fallback_road=", _road_fallback_used,
		" fallback_water=", _water_fallback_used)

func _load_visual_prop_assets() -> void:
	_prop_textures.clear()
	if _asset_registry == null:
		return
	for tag in AssetPackConfigScript.prop_category_tags():
		var texture_paths: Array[String] = _asset_registry.call("list_prop_assets", tag)
		var textures: Array[Texture2D] = []
		for texture_path in texture_paths:
			var texture := load(texture_path) as Texture2D
			if texture != null:
				textures.append(texture)
		_prop_textures[tag] = textures
	print("[MapGenerator] Visual prop assets TREE=", _prop_textures.get(AssetPackConfigScript.TREE, []).size(),
		" ROCK=", _prop_textures.get(AssetPackConfigScript.ROCK, []).size(),
		" RUIN=", _prop_textures.get(AssetPackConfigScript.RUIN, []).size(),
		" DECOR=", _prop_textures.get(AssetPackConfigScript.DECOR, []).size())

func _log_runtime_tileset(tile_set: TileSet) -> void:
	var resource_path := tile_set.resource_path
	print("[MapGenerator] Runtime TileSet path: ", resource_path)
	var expected_tileset_path := _active_asset_pack_tileset_path if _active_asset_pack_tileset_path != "" else RUNTIME_TERRAIN_TILESET_PATH
	if resource_path != expected_tileset_path:
		push_warning("[MapGenerator] Expected runtime terrain TileSet '%s' but TileMapLow has '%s'" % [expected_tileset_path, resource_path])

func _register_tiny_swords_nonterrain_sources(tile_set: TileSet) -> void:
	var expected_tileset_path := _active_asset_pack_tileset_path if _active_asset_pack_tileset_path != "" else RUNTIME_TERRAIN_TILESET_PATH
	if tile_set.resource_path != expected_tileset_path:
		return
	T["foliage"] = _existing_source_ids(tile_set, [10, 11, 12, 13])
	T["decoration"] = T["foliage"]
	T["corrupted"] = T["foliage"]
	T["economy_plot"] = _existing_source_ids(tile_set, [20, 21, 22, 23])
	T["giant_mushroom"] = T["foliage"]

func _existing_source_ids(tile_set: TileSet, source_ids: Array[int]) -> Array[int]:
	var valid: Array[int] = []
	for source_id in source_ids:
		if tile_set.has_source(source_id):
			valid.append(source_id)
	return valid

func pick(terrain: String) -> int:
	var themed := "%s_vm" % terrain
	if T.has(themed) and not T[themed].is_empty():
		return T[themed][_rng.range_int(0, T[themed].size() - 1)]
	if T.has(terrain) and not T[terrain].is_empty():
		return T[terrain][_rng.range_int(0, T[terrain].size() - 1)]
	return T.get("low_ground", [0])[0]

# ── GRID ───────────────────────────────────────────────────────────────────────
func _build_grid() -> void:
	grid.clear()
	feature_grid.clear()
	for x in MAP_W:
		grid.append([])
		feature_grid.append([])
		for y in MAP_H:
			var cell := Vector2i(x, y)
			if map_type_id == MAP_TYPE_AI_TESTING_GROUND:
				var arena_bounds := Rect2i(6, 18, 84, 42)
				var divider_gap := cell.y >= 31 and cell.y <= 45
				var divider_cell := cell.x == 48 and not divider_gap
				if not arena_bounds.has_point(cell) or divider_cell:
					grid[x].append(E_BLOCKED)
					feature_grid[x].append("ai_wall")
				else:
					grid[x].append(E_LOW)
					feature_grid[x].append("ai_arena")
			elif map_type_id == MAP_TYPE_FORTRESS_AI_ARENA:
				var siege_bounds := Rect2i(5, 20, 86, 40)
				var center_rock := (cell.x >= 45 and cell.x <= 50 and (cell.y <= 31 or cell.y >= 49))
				var lane_edge := cell.y == 20 or cell.y == 59
				if not siege_bounds.has_point(cell) or center_rock:
					grid[x].append(E_BLOCKED)
					feature_grid[x].append("ai_wall")
				else:
					grid[x].append(E_LOW)
					feature_grid[x].append("siege_lane" if lane_edge else "ai_arena")
			elif map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
				if cell.x <= 1 or cell.x >= MAP_W - 2 or cell.y <= 1 or cell.y >= MAP_H - 2:
					grid[x].append(E_BLOCKED)
					feature_grid[x].append("map_border")
				else:
					grid[x].append(E_LOW)
					feature_grid[x].append("frontier_canvas")
			elif _uses_square_grid_map():
				grid[x].append(E_LOW)
				feature_grid[x].append("test_canvas")
			else:
				grid[x].append(_generate_cell_elevation(cell))
				feature_grid[x].append("")

func _uses_square_grid_map() -> bool:
	return map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER or map_type_id == MAP_TYPE_GRID_TEST_CANVAS or map_type_id == MAP_TYPE_AI_TESTING_GROUND or map_type_id == MAP_TYPE_FORTRESS_AI_ARENA or map_type_id == MAP_TYPE_PLOT_GENERATOR_TEST

func _build_plot_generator_test_map() -> void:
	layer_low.clear()
	layer_mid.clear()
	layer_high.clear()
	layer_low.modulate = Color.WHITE
	layer_mid.modulate = Color.WHITE
	layer_high.modulate = Color.WHITE
	_clear_plot_generator_children()
	_init_plot_test_grid()
	var config: Resource = MapPlotConfigResource.new()
	config.seed = seed_value
	config.size = Vector2i(42, 28)
	config.landmass_radius = 0.82
	config.landmass_roughness = 0.42
	config.smoothing_passes = 4
	config.cliff_count = 6
	config.cliff_min_size = 8
	config.cliff_max_size = 34
	config.bush_density = 0.045
	config.rock_density = 0.025
	config.water_rock_density = 0.018
	var offset := Vector2i((MAP_W - config.size.x) / 2, (MAP_H - config.size.y) / 2 - 8)
	_plot_test_bounds = Rect2i(offset, config.size)
	var plot_generator: Node = PlotGeneratorResource.new()
	plot_generator.name = "RuntimePlotGenerator"
	add_child(plot_generator)
	plot_generator.call("generate", config, offset)
	_import_plot_generator_cells(plot_generator)
	_build_height_and_cost_maps()
	_build_pathfinder()
	_register_plot_generator_test_zones(plot_generator)

func _clear_plot_generator_children() -> void:
	for child in get_children():
		if child.name == "RuntimePlotGenerator":
			remove_child(child)
			child.queue_free()

func _init_plot_test_grid() -> void:
	grid.clear()
	feature_grid.clear()
	height_map.clear()
	movement_costs.clear()
	road_cells.clear()
	dynamic_blocked_cells.clear()
	_path_cache.clear()
	_flow_field_cache.clear()
	_traversable_cache.clear()
	_flow_neighbors_cache.clear()
	_height_edge_cache.clear()
	spawn_positions.clear()
	enemy_spawns.clear()
	chokepoints.clear()
	economy_zones.clear()
	plots.clear()
	base_plots.clear()
	ramps.clear()
	lakes.clear()
	landmarks.clear()
	for x in MAP_W:
		grid.append([])
		feature_grid.append([])
		for y in MAP_H:
			grid[x].append(E_WATER)
			feature_grid[x].append("plot_test_water")

func _import_plot_generator_cells(plot_generator: Node) -> void:
	for cell in plot_generator.call("get_walkable_cells"):
		if not is_in_bounds(cell):
			continue
		var elevation := int(plot_generator.call("get_elevation_at", cell))
		grid[cell.x][cell.y] = E_MID if elevation > 0 else E_LOW
		feature_grid[cell.x][cell.y] = "plot_cliff" if elevation > 0 else "plot_grass"
	if plot_generator.has_method("get_ramp_cells"):
		for value in plot_generator.call("get_ramp_cells"):
			var ramp_cell: Vector2i = value
			if not is_in_bounds(ramp_cell):
				continue
			grid[ramp_cell.x][ramp_cell.y] = E_RAMP
			feature_grid[ramp_cell.x][ramp_cell.y] = "plot_ramp"
			ramps.append(Rect2i(ramp_cell, Vector2i.ONE))

func _register_plot_generator_test_zones(plot_generator: Node) -> void:
	var walkable: Array = plot_generator.call("get_walkable_cells")
	var flat_cells: Array[Vector2i] = []
	for value in walkable:
		var cell: Vector2i = value
		if is_in_bounds(cell) and grid[cell.x][cell.y] == E_LOW:
			flat_cells.append(cell)
	var center := _plot_test_bounds.position + Vector2i(_plot_test_bounds.size.x / 2, _plot_test_bounds.size.y / 2)
	flat_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center)
	)
	if not flat_cells.is_empty():
		spawn_positions.append(flat_cells[0])
	var anchors: Array = plot_generator.call("get_connection_anchors")
	for value in anchors:
		var anchor: Vector2i = value
		chokepoints.append(anchor)
	plots.append({
		"id": "tiny_swords_island_plot",
		"kind": "content_plot",
		"name": "Tiny Swords island plot",
		"rect": _plot_test_bounds,
		"anchor": center,
		"connection_anchors": anchors.duplicate(),
		"economy_spaces": [],
	})

func _generate_cell_elevation(cell: Vector2i) -> int:
	if cell.x <= 1 or cell.x >= MAP_W - 2 or cell.y <= 1 or cell.y >= MAP_H - 2:
		return E_BLOCKED

	if _is_lake_cell(cell):
		return E_WATER

	if _is_ramp_cell(cell):
		return E_RAMP

	if cell.x >= hg_x1 and cell.x <= hg_x2 and cell.y >= hg_y1 and cell.y <= hg_y2:
		return E_HIGH

	var high_island := Vector2i(clampi(hg_x1 - 18, 8, MAP_W - 22), clampi(hg_y2 + 17, 18, MAP_H - 26))
	var high_dx := float(cell.x - high_island.x) / 12.0
	var high_dy := float(cell.y - high_island.y) / 8.0
	var high_island_distance := high_dx * high_dx + high_dy * high_dy
	if high_island_distance < 1.0:
		return E_HIGH

	if cell.x >= mg_x1 and cell.x <= mg_x2 and cell.y >= mg_y1 and cell.y <= mg_y2:
		return E_MID

	var east_mid_center := Vector2i(MAP_W - 24, 30)
	var east_dx := float(cell.x - east_mid_center.x) / 17.0
	var east_dy := float(cell.y - east_mid_center.y) / 14.0
	if east_dx * east_dx + east_dy * east_dy < 1.0:
		return E_MID

	var south_mid_center := Vector2i(34, MAP_H - 24)
	var south_dx := float(cell.x - south_mid_center.x) / 18.0
	var south_dy := float(cell.y - south_mid_center.y) / 10.0
	if south_dx * south_dx + south_dy * south_dy < 1.0:
		return E_MID

	var block := Vector2i(cell.x / BLOCK_SIZE, cell.y / BLOCK_SIZE)
	var block_roll := _hash_cell(block, 41) % 1000
	if block_roll < 34 and not _is_near_any_plateau(cell, 3):
		return E_BLOCKED
	if block_roll >= 72 and block_roll < 98:
		return E_WATER

	var ridge_roll := _hash_cell(block, 73) % 1000
	if ridge_roll < 70 and cell.y < MAP_H - 10:
		return E_MID
	return E_LOW

func _is_main_high_plateau_edge(cell: Vector2i) -> bool:
	if cell.x < hg_x1 or cell.x > hg_x2 or cell.y < hg_y1 or cell.y > hg_y2:
		return false
	if _is_near_ramp_cell(cell, 2):
		return false
	var edge_distance: int = min(min(cell.x - hg_x1, hg_x2 - cell.x), min(cell.y - hg_y1, hg_y2 - cell.y))
	return edge_distance <= 1

func _is_main_mid_plateau_edge(cell: Vector2i) -> bool:
	if cell.x < mg_x1 or cell.x > mg_x2 or cell.y < mg_y1 or cell.y > mg_y2:
		return false
	if _is_near_ramp_cell(cell, 2):
		return false
	var edge_distance: int = min(min(cell.x - mg_x1, mg_x2 - cell.x), min(cell.y - mg_y1, mg_y2 - cell.y))
	if edge_distance > 1:
		return false
	return _hash_cell(cell, 151) % 1000 < 760

func _is_near_ramp_cell(cell: Vector2i, margin: int) -> bool:
	for ramp in ramps:
		var expanded := Rect2i(ramp.position - Vector2i(margin, margin), ramp.size + Vector2i(margin * 2, margin * 2))
		if expanded.has_point(cell):
			return true
	return false

func _is_near_any_plateau(cell: Vector2i, margin: int) -> bool:
	var high_rect := Rect2i(Vector2i(hg_x1, hg_y1) - Vector2i(margin, margin), Vector2i(hg_x2 - hg_x1 + 1, hg_y2 - hg_y1 + 1) + Vector2i(margin * 2, margin * 2))
	var mid_rect := Rect2i(Vector2i(mg_x1, mg_y1) - Vector2i(margin, margin), Vector2i(mg_x2 - mg_x1 + 1, mg_y2 - mg_y1 + 1) + Vector2i(margin * 2, margin * 2))
	return high_rect.has_point(cell) or mid_rect.has_point(cell)

func _is_lake_cell(cell: Vector2i) -> bool:
	for lake in lakes:
		var center: Vector2i = lake["center"]
		var radius: Vector2i = lake["radius"]
		var lake_dx := float(cell.x - center.x)
		var lake_dy := float(cell.y - center.y)
		if (lake_dx * lake_dx) / float(radius.x * radius.x) + (lake_dy * lake_dy) / float(radius.y * radius.y) <= 1.0:
			return true
	return false

func _is_ramp_cell(cell: Vector2i) -> bool:
	for ramp in ramps:
		if ramp.has_point(cell):
			return true
	return false

func _build_height_and_cost_maps() -> void:
	height_map.clear()
	movement_costs.clear()
	for x in MAP_W:
		height_map.append([])
		movement_costs.append([])
		for y in MAP_H:
			var cell := Vector2i(x, y)
			var elevation: int = grid[x][y]
			height_map[x].append(_height_for_cell(cell, elevation))
			movement_costs[x].append(_movement_cost_for_cell(cell, elevation))

func _calc_elev(x: int, y: int) -> int:
	if x <= 1 or x >= MAP_W-2 or y <= 1 or y >= MAP_H-2:
		return E_WATER
	var cell := Vector2i(x, y)
	if _is_lake_cell(cell):
		return E_WATER
	if _is_ramp_cell(cell):
		return E_RAMP
	if x >= hg_x1 and x <= hg_x2 and y >= hg_y1 and y <= hg_y2:
		if y == hg_y2 and x >= cp_x1 and x <= cp_x2:
			return E_MID
		return E_HIGH
	if x >= mg_x1 and x <= mg_x2 and y >= mg_y1 and y <= mg_y2:
		return E_MID
	return E_LOW

func g(x: int, y: int) -> int:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H: return E_LOW
	return grid[x][y]

func get_height(cell: Vector2i) -> int:
	if not is_in_bounds(cell):
		return 0
	return int(height_map[cell.x][cell.y])

# Terrain line of sight, shared by fog of war and by combat targeting.
#
# It lives here because it is a question about TERRAIN, and because having two
# implementations of "can this see that" would let vision and weapons disagree
# -- a unit could shoot something the fog says it cannot see.
#
# The rule: sight travels level or downhill freely, and is blocked by anything
# standing higher than the viewer. That is what stops units seeing (and
# shooting) up a cliff.
#
# Allocation-free by design: this is called from the combat tick as well as from
# fog updates, so it walks the line in place rather than building a cell array.
func has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, viewer_height: int) -> bool:
	if from_cell == to_cell:
		return true
	var delta := to_cell - from_cell
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		return true
	var previous := from_cell
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector2i(
			roundi(lerpf(float(from_cell.x), float(to_cell.x), t)),
			roundi(lerpf(float(from_cell.y), float(to_cell.y), t))
		)
		if cell == previous:
			continue
		previous = cell
		if not is_in_bounds(cell):
			return false
		if cell != to_cell and not is_walkable_cell(cell):
			return false
		if get_height(cell) > viewer_height:
			return false
	return true

# True when nothing can walk here: water, hard blockers, and cliff edges that
# have no ramp. This is what the 2D impassable overlay paints orange.
func is_impassable_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return true
	return not _is_static_path_traversable_cell(cell)

# Impassable specifically because of a height transition, rather than because of
# water or a blocker. Drawn differently so a cliff reads as a cliff.
func is_cliff_edge_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if not _is_static_walkable_cell(cell):
		return false
	return _is_unramped_height_edge(cell)

func get_movement_cost(cell: Vector2i) -> float:
	if not is_in_bounds(cell):
		return INF
	return float(movement_costs[cell.x][cell.y])

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_W and cell.y >= 0 and cell.y < MAP_H

func is_walkable_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if dynamic_blocked_cells.has(cell):
		return false
	return grid[cell.x][cell.y] != E_WATER and grid[cell.x][cell.y] != E_BLOCKED

func add_dynamic_blockers(cells: Array[Vector2i]) -> void:
	var changed := false
	for cell in cells:
		if is_in_bounds(cell):
			dynamic_blocked_cells[cell] = true
			if _pathfinder.is_in_boundsv(cell):
				_pathfinder.set_point_solid(cell, true)
			changed = true
	if changed:
		_invalidate_path_cache()

func remove_dynamic_blockers(cells: Array[Vector2i]) -> void:
	var changed := false
	for cell in cells:
		dynamic_blocked_cells.erase(cell)
		if is_in_bounds(cell) and _pathfinder.is_in_boundsv(cell):
			_pathfinder.set_point_solid(cell, not is_walkable_cell(cell))
			changed = true
	if changed:
		_invalidate_path_cache()

func world_to_cell(world_position: Vector2) -> Vector2i:
	if _uses_square_grid_map():
		return Vector2i(floori(world_position.x / float(GRID_TEST_CELL_SIZE)), floori(world_position.y / float(GRID_TEST_CELL_SIZE)))
	return layer_low.local_to_map(layer_low.to_local(world_position))

func cell_to_world(cell: Vector2i) -> Vector2:
	if _uses_square_grid_map():
		return Vector2(float(cell.x) * float(GRID_TEST_CELL_SIZE) + float(GRID_TEST_CELL_SIZE) * 0.5, float(cell.y) * float(GRID_TEST_CELL_SIZE) + float(GRID_TEST_CELL_SIZE) * 0.5)
	return layer_low.to_global(layer_low.map_to_local(cell))

func get_world_bounds() -> Rect2:
	if _uses_square_grid_map():
		if map_type_id == MAP_TYPE_PLOT_GENERATOR_TEST and _plot_test_bounds.size != Vector2i.ZERO:
			return Rect2(
				Vector2(_plot_test_bounds.position) * float(GRID_TEST_CELL_SIZE),
				Vector2(_plot_test_bounds.size) * float(GRID_TEST_CELL_SIZE)
			).grow(float(GRID_TEST_CELL_SIZE) * 2.0)
		return Rect2(Vector2.ZERO, Vector2(float(MAP_W * GRID_TEST_CELL_SIZE), float(MAP_H * GRID_TEST_CELL_SIZE)))
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for x in MAP_W:
		for y in MAP_H:
			var point := cell_to_world(Vector2i(x, y))
			min_point.x = minf(min_point.x, point.x)
			min_point.y = minf(min_point.y, point.y)
			max_point.x = maxf(max_point.x, point.x)
			max_point.y = maxf(max_point.y, point.y)
	var tile_margin := Vector2(256.0, 192.0)
	return Rect2(min_point - tile_margin, (max_point - min_point) + tile_margin * 2.0)

func nearest_walkable_cell(origin: Vector2i, max_radius: int = 8) -> Vector2i:
	if is_walkable_cell(origin):
		return origin
	for radius in range(1, max_radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if is_walkable_cell(cell):
					return cell
	return Vector2i(-1, -1)

func find_path_cells(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	path_requests_total += 1
	_path_requests_this_second += 1
	var original_start := start
	var original_target := target
	var path: Array[Vector2i] = []
	if not is_walkable_cell(start):
		start = nearest_walkable_cell(start)
	if not is_walkable_cell(target):
		target = nearest_walkable_cell(target)
	if not is_walkable_cell(start) or not is_walkable_cell(target):
		return path
	var cache_key := "%s:%s:%s:%s:%s" % [_path_cache_version, original_start.x, original_start.y, original_target.x, original_target.y]
	if _path_cache.has(cache_key):
		path_cache_hits_total += 1
		_path_cache_hits_this_second += 1
		var cached: Array[Vector2i] = []
		for cell in _path_cache[cache_key]:
			cached.append(cell)
		return cached
	for point in _pathfinder.get_id_path(start, target):
		path.append(point)
	if not path.is_empty() and path[0] == start:
		path.pop_front()
	var smoothed := _smooth_path_cells(start, path)
	_remember_path(cache_key, smoothed)
	return smoothed.duplicate()

func find_path_world(start_world: Vector2, target_world: Vector2) -> Array[Vector2]:
	var world_path: Array[Vector2] = []
	for cell in find_path_cells(world_to_cell(start_world), world_to_cell(target_world)):
		world_path.append(cell_to_world(cell))
	return world_path

func get_flow_field_waypoints_world(start_world: Vector2, target_world: Vector2, max_steps: int = 5) -> Array[Vector2]:
	var waypoints: Array[Vector2] = []
	var start_cell := world_to_cell(start_world)
	var target_cell := world_to_cell(target_world)
	if not is_walkable_cell(start_cell):
		start_cell = nearest_walkable_cell(start_cell, 4)
	if not is_walkable_cell(target_cell):
		target_cell = nearest_walkable_cell(target_cell, 16)
	if not is_walkable_cell(start_cell) or not is_walkable_cell(target_cell):
		return waypoints
	var field := _flow_field_for_target_cell(target_cell)
	var next_cells: Dictionary = field.get("next_cells", {})
	if next_cells.is_empty() or (start_cell != target_cell and not next_cells.has(start_cell)):
		return waypoints
	var current := start_cell
	for _i in range(maxi(1, max_steps)):
		if current == target_cell:
			break
		if not next_cells.has(current):
			break
		var next_cell: Vector2i = next_cells[current]
		if next_cell == current or not is_walkable_cell(next_cell):
			break
		waypoints.append(cell_to_world(next_cell))
		current = next_cell
	if not waypoints.is_empty():
		units_using_flow_field_total += 1
		_units_using_flow_field_this_second += 1
	return waypoints

func has_flow_field_route_world(start_world: Vector2, target_world: Vector2) -> bool:
	var start_cell := world_to_cell(start_world)
	var target_cell := world_to_cell(target_world)
	if not is_walkable_cell(start_cell):
		start_cell = nearest_walkable_cell(start_cell, 4)
	if not is_walkable_cell(target_cell):
		target_cell = nearest_walkable_cell(target_cell, 16)
	if not is_walkable_cell(start_cell) or not is_walkable_cell(target_cell):
		return false
	if start_cell == target_cell:
		return true
	var field := _flow_field_for_target_cell(target_cell)
	var next_cells: Dictionary = field.get("next_cells", {})
	return next_cells.has(start_cell)

func _flow_field_for_target_cell(target_cell: Vector2i) -> Dictionary:
	var cache_key := "%s:%s:%s" % [_path_cache_version, target_cell.x, target_cell.y]
	if _flow_field_cache.has(cache_key):
		return _flow_field_cache[cache_key]
	var field := _build_flow_field(target_cell)
	_flow_field_cache[cache_key] = field
	return field

# Dijkstra over the walkable grid, producing a next-cell field enemy waves
# steer along.
#
# PERFORMANCE, 2026-08-31: this used to hold its frontier in a linear-insert
# sorted `Array[Dictionary]`. Every relaxation did an O(n) scan plus an O(n)
# `Array.insert()` memmove, and allocated a fresh Dictionary per queue entry --
# so the whole build cost ~1220ms on the live 96x96 map, blocking the physics
# frame. Andrew's 386-second play session recorded 25 of these, every one a
# ~1.3s hard freeze, at unit counts as low as 23. The frontier is now a binary
# min-heap over two parallel arrays (cells + PackedFloat64Array costs) with no
# per-entry allocation. Same field, same output, same cache semantics.
#
# The cost is independent of unit count -- it scales with map area -- so this
# was never going to show up in a unit-scaling stress test.
func _build_flow_field(target_cell: Vector2i) -> Dictionary:
	flow_field_recomputes_total += 1
	_flow_field_recomputes_this_second += 1
	var next_cells: Dictionary = {}
	if not _is_path_traversable_cell(target_cell):
		return {"target": target_cell, "next_cells": next_cells, "cells_reached": 0}
	# Costs live in a flat PackedFloat64Array indexed by x * MAP_H + y rather
	# than a Vector2i-keyed Dictionary. Dijkstra touches this several times per
	# edge, and hashing a Vector2i Variant on every touch was a large share of
	# what remained after the traversability and neighbour memos landed.
	var costs := PackedFloat64Array()
	costs.resize(MAP_W * MAP_H)
	costs.fill(INF)
	var target_index := target_cell.x * MAP_H + target_cell.y
	costs[target_index] = 0.0
	var heap_index := PackedInt32Array([target_index])
	var heap_costs := PackedFloat64Array([0.0])
	var has_blockers := not dynamic_blocked_cells.is_empty()
	var reached := 1
	while not heap_index.is_empty():
		var current_index := heap_index[0]
		var current_cost := heap_costs[0]
		_flow_heap_pop(heap_index, heap_costs)
		# Stale heap entry: this cell was already reached more cheaply.
		if current_cost > costs[current_index]:
			continue
		var current := Vector2i(current_index / MAP_H, current_index % MAP_H)
		for neighbor in _flow_field_neighbors(current):
			if has_blockers and _flow_edge_blocked(current, neighbor):
				continue
			var neighbor_index: int = neighbor.x * MAP_H + neighbor.y
			var new_cost: float = current_cost + current.distance_to(neighbor) * get_movement_cost(neighbor)
			if new_cost >= costs[neighbor_index]:
				continue
			if is_inf(costs[neighbor_index]):
				reached += 1
			costs[neighbor_index] = new_cost
			next_cells[neighbor] = current
			_flow_heap_push(heap_index, heap_costs, neighbor_index, new_cost)
	return {"target": target_cell, "next_cells": next_cells, "cells_reached": reached}

# --- Binary min-heap used by the flow field ---------------------------------
# Two parallel arrays rather than an array of Dictionaries, so a push costs one
# append to each plus a sift, and never allocates an object.

func _flow_heap_push(heap_index: PackedInt32Array, heap_costs: PackedFloat64Array, cell_index: int, cost: float) -> void:
	heap_index.append(cell_index)
	heap_costs.append(cost)
	var index := heap_index.size() - 1
	while index > 0:
		var parent := (index - 1) >> 1
		if heap_costs[parent] <= heap_costs[index]:
			break
		_flow_heap_swap(heap_index, heap_costs, parent, index)
		index = parent

func _flow_heap_pop(heap_index: PackedInt32Array, heap_costs: PackedFloat64Array) -> void:
	var last := heap_index.size() - 1
	if last < 0:
		return
	heap_index[0] = heap_index[last]
	heap_costs[0] = heap_costs[last]
	heap_index.remove_at(last)
	heap_costs.remove_at(last)
	var size := heap_index.size()
	var index := 0
	while true:
		var left := index * 2 + 1
		if left >= size:
			break
		var smallest := left
		var right := left + 1
		if right < size and heap_costs[right] < heap_costs[left]:
			smallest = right
		if heap_costs[index] <= heap_costs[smallest]:
			break
		_flow_heap_swap(heap_index, heap_costs, index, smallest)
		index = smallest

func _flow_heap_swap(heap_index: PackedInt32Array, heap_costs: PackedFloat64Array, a: int, b: int) -> void:
	var cell_index := heap_index[a]
	heap_index[a] = heap_index[b]
	heap_index[b] = cell_index
	var cost := heap_costs[a]
	heap_costs[a] = heap_costs[b]
	heap_costs[b] = cost

# The terrain-only neighbour set for a cell: same diagonal corner-cutting rule
# and same ramp rule as the original _can_step_between() logic, but ignoring
# runtime blockers so the answer can be memoised for the life of the map.
# _build_flow_field() re-applies blockers per edge, which is one dictionary
# lookup instead of a full re-expansion.
func _flow_field_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var cached: Variant = _flow_neighbors_cache.get(cell)
	if cached != null:
		return cached
	var result: Array[Vector2i] = []
	var from_height := int(height_map[cell.x][cell.y])
	var from_is_ramp: bool = grid[cell.x][cell.y] == E_RAMP
	for offset in FLOW_NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = cell + offset
		if not _is_static_path_traversable_cell(neighbor):
			continue
		if not _flow_can_step_to(from_height, from_is_ramp, neighbor):
			continue
		if offset.x != 0 and offset.y != 0:
			var side_x := Vector2i(neighbor.x, cell.y)
			var side_y := Vector2i(cell.x, neighbor.y)
			if not _is_static_path_traversable_cell(side_x) or not _is_static_path_traversable_cell(side_y):
				continue
			if not _flow_can_step_to(from_height, from_is_ramp, side_x):
				continue
			if not _flow_can_step_to(from_height, from_is_ramp, side_y):
				continue
		result.append(neighbor)
	_flow_neighbors_cache[cell] = result
	return result

# Re-applies runtime blockers to a cached static edge. Skipped entirely when
# nothing is blocked, which is the common case on a fresh map.
func _flow_edge_blocked(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if dynamic_blocked_cells.has(to_cell):
		return true
	if from_cell.x == to_cell.x or from_cell.y == to_cell.y:
		return false
	# Diagonal: a blocker on either side cell closes the corner, matching the
	# terrain rule above.
	return dynamic_blocked_cells.has(Vector2i(to_cell.x, from_cell.y)) \
		or dynamic_blocked_cells.has(Vector2i(from_cell.x, to_cell.y))

func _smooth_path_cells(start: Vector2i, raw_path: Array[Vector2i]) -> Array[Vector2i]:
	if raw_path.size() <= 2:
		return raw_path
	var smoothed: Array[Vector2i] = []
	var anchor := start
	var index := 0
	while index < raw_path.size():
		var best_index := index
		var lookahead_limit: int = mini(raw_path.size() - 1, index + 14)
		for candidate_index in range(lookahead_limit, index - 1, -1):
			if _has_clear_path_segment(anchor, raw_path[candidate_index]):
				best_index = candidate_index
				break
		var next_cell := raw_path[best_index]
		smoothed.append(next_cell)
		anchor = next_cell
		index = best_index + 1
	return smoothed

func _has_clear_path_segment(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if from_cell == to_cell:
		return true
	var cells := _line_cells(from_cell, to_cell)
	var previous := from_cell
	for i in range(1, cells.size()):
		var cell: Vector2i = cells[i]
		if not _is_path_traversable_cell(cell):
			return false
		if not _can_step_between(previous, cell):
			return false
		if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER and not _frontier_step_has_clearance(previous, cell):
			return false
		previous = cell
	return true

func _frontier_step_has_clearance(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var delta := to_cell - from_cell
	if delta.x != 0 and delta.y != 0:
		var side_a := Vector2i(from_cell.x + clampi(delta.x, -1, 1), from_cell.y)
		var side_b := Vector2i(from_cell.x, from_cell.y + clampi(delta.y, -1, 1))
		if not _is_path_traversable_cell(side_a) or not _is_path_traversable_cell(side_b):
			return false
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var check: Vector2i = to_cell + offset
		if not is_in_bounds(check):
			return false
		if grid[check.x][check.y] == E_BLOCKED or grid[check.x][check.y] == E_WATER:
			return false
	return true

# PERFORMANCE, 2026-08-31: this is the hottest function in the pathfinding
# layer and it used to be recomputed from scratch on every call.
# `_is_unramped_height_edge` behind it loops every ramp rect (twice, at margins
# 1 and 4) and every plot rect, then checks four neighbours -- roughly 40
# operations with Rect2i allocations. `_flow_field_neighbors()` calls this up to
# 16 times per expanded cell (8 neighbours plus both side cells of every
# diagonal), so one flow field over ~7000 reachable cells was doing millions of
# them, and Andrew's play session recorded that as ~1.3s hard freezes.
#
# It is now split: the terrain-shape half is memoised permanently, and the only
# per-call work is one dictionary lookup for a runtime blocker. That split is
# what matters -- a memo that still had to be dropped every time a building went
# down only moved the cost, it did not remove it.
func _is_path_traversable_cell(cell: Vector2i) -> bool:
	if dynamic_blocked_cells.has(cell):
		return false
	return _is_static_path_traversable_cell(cell)

func _is_static_path_traversable_cell(cell: Vector2i) -> bool:
	var cached: Variant = _traversable_cache.get(cell)
	if cached != null:
		return bool(cached)
	var result: bool = _is_static_walkable_cell(cell) and not _is_unramped_height_edge(cell)
	_traversable_cache[cell] = result
	return result

const FLOW_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

# Height/ramp half of _can_step_between(), for callers that have already
# established both cells are in bounds and traversable. Skipping those repeated
# bounds and dynamic-blocker checks is most of what this saves -- the full
# _can_step_between() was being called up to 24 times per expanded cell.
func _flow_can_step_to(from_height: int, from_is_ramp: bool, to_cell: Vector2i) -> bool:
	var to_height := int(height_map[to_cell.x][to_cell.y])
	if from_height == to_height:
		return true
	return from_is_ramp or grid[to_cell.x][to_cell.y] == E_RAMP

func _can_step_between(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not is_in_bounds(from_cell) or not is_in_bounds(to_cell):
		return false
	if not is_walkable_cell(from_cell) or not is_walkable_cell(to_cell):
		return false
	var from_height := int(height_map[from_cell.x][from_cell.y])
	var to_height := int(height_map[to_cell.x][to_cell.y])
	if from_height == to_height:
		return true
	return grid[from_cell.x][from_cell.y] == E_RAMP or grid[to_cell.x][to_cell.y] == E_RAMP

func _line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := to_cell - from_cell
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		return [from_cell]
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector2i(roundi(lerpf(float(from_cell.x), float(to_cell.x), t)), roundi(lerpf(float(from_cell.y), float(to_cell.y), t)))
		if cells.is_empty() or cells[cells.size() - 1] != cell:
			cells.append(cell)
	return cells

func _build_pathfinder() -> void:
	_pathfinder.region = Rect2i(0, 0, MAP_W, MAP_H)
	_pathfinder.cell_size = Vector2.ONE
	_pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_pathfinder.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_pathfinder.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_pathfinder.update()
	for x in MAP_W:
		for y in MAP_H:
			var cell := Vector2i(x, y)
			_pathfinder.set_point_solid(cell, not is_walkable_cell(cell) or _is_unramped_height_edge(cell))
			if is_walkable_cell(cell):
				_pathfinder.set_point_weight_scale(cell, get_movement_cost(cell))
	_invalidate_path_cache()

func _remember_path(cache_key: String, path: Array[Vector2i]) -> void:
	if _path_cache.size() >= PATH_CACHE_LIMIT:
		_path_cache.clear()
	_path_cache[cache_key] = path.duplicate()

func _invalidate_path_cache() -> void:
	_path_cache_version += 1
	_path_cache.clear()
	# _traversable_cache / _flow_neighbors_cache / _height_edge_cache are NOT
	# cleared here on purpose -- they hold terrain shape, which a building does
	# not change. Blockers are re-applied per lookup instead.
	_flow_field_cache.clear()

# PERFORMANCE, 2026-08-31: memoised, because this is the expensive half of
# _is_path_traversable_cell() -- it loops every ramp rect twice (margins 1 and
# 4) and every plot rect, allocating a Rect2i each time.
#
# It now tests _is_static_walkable_cell() rather than is_walkable_cell(), so the
# answer depends only on the generated map and the memo can outlive building
# placement. That is also a small correctness fix: previously, dropping a
# Vinewall on the cell beside a cliff edge made the neighbour loop skip that
# cell and could report the edge as *not* an edge -- i.e. putting a wall next to
# a cliff could make the cliff walkable. Terrain shape does not change because
# something was built on it.
func _is_unramped_height_edge(cell: Vector2i) -> bool:
	var cached: Variant = _height_edge_cache.get(cell)
	if cached != null:
		return bool(cached)
	var result := _compute_unramped_height_edge(cell)
	_height_edge_cache[cell] = result
	return result

func _is_static_walkable_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	return grid[cell.x][cell.y] != E_WATER and grid[cell.x][cell.y] != E_BLOCKED

func _compute_unramped_height_edge(cell: Vector2i) -> bool:
	if not _is_static_walkable_cell(cell) or grid[cell.x][cell.y] == E_RAMP:
		return false
	if _is_near_ramp_cell(cell, 1):
		return false
	if feature_grid[cell.x][cell.y] == "path" and _is_near_ramp_cell(cell, 4):
		return false
	if feature_grid[cell.x][cell.y] == "high_access":
		return false
	if _is_inside_plot_rect(cell):
		return false
	var height := int(height_map[cell.x][cell.y])
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if not _is_static_walkable_cell(neighbor):
			continue
		if grid[neighbor.x][neighbor.y] == E_RAMP:
			continue
		if abs(int(height_map[neighbor.x][neighbor.y]) - height) > 0:
			return true
	return false

func _height_for_cell(cell: Vector2i, elevation: int) -> int:
	match elevation:
		E_BLOCKED:
			return 0
		E_WATER:
			return -1
		E_LOW:
			return 0
		E_MID:
			return 1
		E_HIGH:
			return 2
		E_RAMP:
			var ramp := _ramp_for_cell(cell)
			var ramp_progress := 0.0
			if ramp.size.y >= ramp.size.x:
				ramp_progress = clampf(float(cell.y - ramp.position.y) / max(1.0, float(ramp.size.y - 1)), 0.0, 1.0)
			else:
				ramp_progress = clampf(float(cell.x - ramp.position.x) / max(1.0, float(ramp.size.x - 1)), 0.0, 1.0)
			return 1 if ramp_progress < 0.5 else 2
	return 0

func _ramp_for_cell(cell: Vector2i) -> Rect2i:
	for ramp in ramps:
		if ramp.has_point(cell):
			return ramp
	return Rect2i(cp_x1, cp_y, cp_x2 - cp_x1 + 1, max(1, ramp_y - cp_y + 1))

func _is_inside_plot_rect(cell: Vector2i) -> bool:
	for plot in plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.has_point(cell):
			return true
	return false

func _movement_cost_for_cell(cell: Vector2i, elevation: int) -> float:
	match elevation:
		E_BLOCKED:
			return INF
		E_WATER:
			return INF
		E_LOW:
			return 1.0
		E_MID:
			return 1.08
		E_HIGH:
			return 1.16
		E_RAMP:
			return 0.92
	if _is_choke_cell(cell):
		return 0.95
	return 1.0

func _is_choke_cell(cell: Vector2i) -> bool:
	for ramp in ramps:
		if ramp.has_point(cell):
			return true
	return false

func _hash_cell(cell: Vector2i, salt: int) -> int:
	var value := int(seed_value)
	value = int((value ^ (cell.x * 73856093)) & 0x7fffffff)
	value = int((value ^ (cell.y * 19349663)) & 0x7fffffff)
	value = int((value ^ (salt * 83492791)) & 0x7fffffff)
	return value

func _build_plots() -> void:
	plots.clear()
	base_plots.clear()
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		_build_seeded_grid_frontier_plots()
		return
	if map_type_id == MAP_TYPE_FORTRESS_AI_ARENA:
		_build_fortress_ai_arena_plots()
		return
	if map_type_id == MAP_TYPE_AI_TESTING_GROUND:
		_build_ai_testing_ground_plots()
		return
	if map_type_id == MAP_TYPE_GRID_TEST_CANVAS:
		_build_grid_test_plots()
		return
	var reserved_rects: Array[Rect2i] = []

	var base_1_rect := _find_plot_rect(Vector2i(10, 8), [E_HIGH, E_MID], reserved_rects, 360, Vector2(0.18, 0.20))
	var base_1 := _make_base_plot(
		"base_plot_1",
		"Base plot 1",
		base_1_rect,
		_make_economy_spaces(base_1_rect, 1),
		0.25,
		0.92,
		"Very defensible high-ground base with one economy plot and one obvious ramp approach."
	)
	reserved_rects.append(base_1_rect)
	var base_2_rect := _find_plot_rect(Vector2i(14, 10), [E_MID, E_LOW], reserved_rects, 360, Vector2(0.25, 0.63))
	var base_2 := _make_base_plot(
		"base_plot_2",
		"Base plot 2",
		base_2_rect,
		_make_economy_spaces(base_2_rect, 2),
		0.62,
		0.58,
		"Average defensibility mid-ground base with two economy plots and several attack angles."
	)
	reserved_rects.append(base_2_rect)
	var base_3_rect := _find_plot_rect(Vector2i(17, 10), [E_LOW, E_MID], reserved_rects, 400, Vector2(0.72, 0.76))
	var base_3 := _make_base_plot(
		"base_plot_3",
		"Base plot 3",
		base_3_rect,
		_make_economy_spaces(base_3_rect, 3),
		0.9,
		0.22,
		"Not very defensible low-ground greed base with three economy plots and poor natural chokes."
	)
	reserved_rects.append(base_3_rect)

	for plot in [base_1, base_2, base_3]:
		_register_plot(plot)

	var tower_rect := _find_plot_rect(Vector2i(10, 10), [E_HIGH, E_MID, E_LOW], reserved_rects, 260, Vector2(0.67, 0.25))
	reserved_rects.append(tower_rect)
	_register_plot({
		"id": "abandoned_wizard_tower",
		"name": "Abandoned wizard tower",
		"kind": "quest",
		"rect": tower_rect,
		"anchor": tower_rect.position + Vector2i(5, 5),
		"economy_spaces": [],
		"difficulty": 0.5,
		"defensibility": 0.7,
		"story": "A broken tower from the sealed Life Wizard expedition, suitable for a quest giver.",
	})
	var bandit_rect := _find_plot_rect(Vector2i(10, 10), [E_LOW, E_MID], reserved_rects, 260, Vector2(0.82, 0.48))
	reserved_rects.append(bandit_rect)
	_register_plot({
		"id": "bandit_outpost",
		"name": "Bandit outpost",
		"kind": "enemy_outpost",
		"rect": bandit_rect,
		"anchor": bandit_rect.position + Vector2i(5, 5),
		"economy_spaces": [],
		"difficulty": 0.75,
		"defensibility": 0.35,
		"story": "A fortified bandit camp feeding off the vampire mushroom forest.",
	})

	var tower_2_rect := _find_plot_rect(Vector2i(10, 10), [E_HIGH, E_MID], reserved_rects, 320, Vector2(0.35, 0.42))
	reserved_rects.append(tower_2_rect)
	_register_plot({
		"id": "sealed_evolution_lab",
		"name": "Sealed evolution lab",
		"kind": "quest",
		"rect": tower_2_rect,
		"anchor": tower_2_rect.position + Vector2i(5, 5),
		"economy_spaces": [],
		"difficulty": 0.65,
		"defensibility": 0.55,
		"story": "A ruined Life Wizard laboratory where the first fungal horrors escaped containment.",
	})

	var bandit_2_rect := _find_plot_rect(Vector2i(12, 10), [E_LOW, E_MID], reserved_rects, 320, Vector2(0.58, 0.70))
	reserved_rects.append(bandit_2_rect)
	_register_plot({
		"id": "bloodcap_raider_camp",
		"name": "Bloodcap raider camp",
		"kind": "enemy_outpost",
		"rect": bandit_2_rect,
		"anchor": bandit_2_rect.position + Vector2i(6, 5),
		"economy_spaces": [],
		"difficulty": 0.82,
		"defensibility": 0.42,
		"story": "A larger camp occupying the road between the best economy plots and the boss approach.",
	})

	var objective_rect := _find_plot_rect(Vector2i(15, 12), [E_HIGH, E_MID], reserved_rects, 380, Vector2(0.73, 0.18))
	reserved_rects.append(objective_rect)
	_register_plot({
		"id": "heart_of_the_mycelium",
		"name": "Heart of the mycelium",
		"kind": "objective",
		"rect": objective_rect,
		"anchor": objective_rect.position + Vector2i(7, 6),
		"economy_spaces": [],
		"difficulty": 1.0,
		"defensibility": 0.78,
		"story": "A high-ground objective wrapped in vampire roots and huge bloodcap mushrooms.",
	})

func _build_grid_test_plots() -> void:
	var base_1_rect := Rect2i(10, 10, 12, 10)
	var base_2_rect := Rect2i(38, 28, 16, 12)
	var base_3_rect := Rect2i(66, 58, 18, 12)
	for plot in [
		_make_base_plot("base_plot_1", "Base plot 1", base_1_rect, _make_economy_spaces(base_1_rect, 1), 0.2, 0.9, "One-economy test base."),
		_make_base_plot("base_plot_2", "Base plot 2", base_2_rect, _make_economy_spaces(base_2_rect, 2), 0.55, 0.55, "Two-economy test base."),
		_make_base_plot("base_plot_3", "Base plot 3", base_3_rect, _make_economy_spaces(base_3_rect, 3), 0.9, 0.2, "Three-economy test base."),
	]:
		_register_plot(plot)
	_register_plot({
		"id": "test_enemy_outpost",
		"name": "Test enemy outpost",
		"kind": "enemy_outpost",
		"rect": Rect2i(64, 18, 10, 10),
		"anchor": Vector2i(69, 23),
		"economy_spaces": [],
		"difficulty": 0.5,
		"defensibility": 0.5,
		"story": "Flat-grid outpost for blocker and pathing tests.",
	})

func _build_seeded_grid_frontier_plots() -> void:
	var reserved_rects: Array[Rect2i] = []
	var base_specs: Array[Dictionary] = [
		{"archetype": BASE_ARCHETYPE_FORTRESS, "target": Vector2(0.20, 0.22)},
		{"archetype": BASE_ARCHETYPE_HOLDFAST, "target": Vector2(0.76, 0.23)},
		{"archetype": BASE_ARCHETYPE_EXPANSION, "target": Vector2(0.24, 0.73)},
		{"archetype": BASE_ARCHETYPE_HOLDFAST, "target": Vector2(0.72, 0.70)},
	]
	for i in range(base_specs.size()):
		var spec: Dictionary = base_specs[i]
		var archetype := str(spec["archetype"])
		var archetype_data := _base_archetype_data(archetype)
		var target: Vector2 = spec["target"]
		var plot_size: Vector2i = archetype_data["size"]
		var rect := _find_open_frontier_rect(plot_size, reserved_rects, target, 260)
		reserved_rects.append(_expanded_rect(rect, 8))
		var resource_count := int(archetype_data["resource_node_count"])
		var plot := _make_base_plot(
			"base_plot_%s" % (i + 1),
			"%s base plot %s" % [str(archetype_data["label"]).capitalize(), i + 1],
			rect,
			_make_economy_spaces(rect, resource_count),
			float(archetype_data["difficulty"]),
			float(archetype_data["defence_score"]),
			str(archetype_data["story"])
		)
		_apply_base_archetype(plot, archetype)
		_register_plot(plot)

	_build_blank_frontier_content_plots(reserved_rects)

func _base_archetype_data(archetype: String) -> Dictionary:
	match archetype:
		BASE_ARCHETYPE_FORTRESS:
			return {
				"label": "fortress",
				"size": Vector2i(12, 11),
				"resource_node_count": 1,
				"target_ramp_count": 1,
				"ramp_width": 1,
				"defence_score": 0.92,
				"economy_score": 0.22,
				"difficulty": 0.22,
				"plot_size_class": "small",
				"elevation": ELEVATION_HIGH,
				"story": "Small high-ground base with one resource node and one narrow ramp.",
			}
		BASE_ARCHETYPE_HOLDFAST:
			return {
				"label": "holdfast",
				"size": Vector2i(15, 14),
				"resource_node_count": 2,
				"target_ramp_count": 2,
				"ramp_width": 2,
				"defence_score": 0.62,
				"economy_score": 0.58,
				"difficulty": 0.48,
				"plot_size_class": "medium",
				"elevation": ELEVATION_HIGH,
				"story": "Medium base with two resources and two readable ramp entrances.",
			}
		BASE_ARCHETYPE_EXPANSION:
			return {
				"label": "expansion",
				"size": Vector2i(19, 16),
				"resource_node_count": 3,
				"target_ramp_count": 3,
				"ramp_width": 3,
				"defence_score": 0.24,
				"economy_score": 0.88,
				"difficulty": 0.78,
				"plot_size_class": "large",
				"elevation": ELEVATION_LOW,
				"story": "Large exposed expansion with three resources and several broad entrances.",
			}
	return _base_archetype_data(BASE_ARCHETYPE_HOLDFAST)

func _apply_base_archetype(plot: Dictionary, archetype: String) -> void:
	var data := _base_archetype_data(archetype)
	plot["base_archetype"] = archetype
	plot["resource_node_count"] = int(data["resource_node_count"])
	plot["target_ramp_count"] = int(data["target_ramp_count"])
	plot["ramp_width"] = int(data["ramp_width"])
	plot["defence_score"] = float(data["defence_score"])
	plot["economy_score"] = float(data["economy_score"])
	plot["plot_size_class"] = str(data["plot_size_class"])
	plot["defensibility"] = float(data["defence_score"])
	plot["economy_count"] = int(data["resource_node_count"])
	plot["elevation"] = str(data["elevation"])

func _build_blank_frontier_content_plots(reserved_rects: Array[Rect2i]) -> void:
	var content_specs := _frontier_content_specs()
	var index_by_size := {"small": 0, "medium": 0, "large": 0}
	for spec in content_specs:
		var size_label := str(spec["label"])
		index_by_size[size_label] = int(index_by_size[size_label]) + 1
		var size: Vector2i = spec["size"]
		var target: Vector2 = spec["target"]
		var placement := _find_open_frontier_rect_debug(size, reserved_rects, target, 320)
		var rect: Rect2i = placement["rect"]
		var reservation_rect := _expanded_rect(rect, 4)
		reserved_rects.append(reservation_rect)
		var serial := int(index_by_size[size_label])
		var plot := {
			"id": "blank_%s_content_plot_%s" % [size_label, serial],
			"name": "%s blank content plot %s" % [size_label.capitalize(), serial],
			"kind": "content_blank",
			"content_archetype": str(spec.get("archetype", "blank_%s" % size_label)),
			"content_size": size_label,
			"requested_size": size,
			"final_footprint_size": rect.size,
			"rect": rect,
			"reservation_rect": reservation_rect,
			"debug_render_rect": rect,
			"candidate_count": int(placement["candidate_count"]),
			"chosen_candidate_index": int(placement["chosen_candidate_index"]),
			"fallback_used": bool(placement["fallback_used"]),
			"anchor": rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2),
			"road_anchor": Vector2i(rect.position.x + rect.size.x / 2, rect.end.y + 1),
			"economy_spaces": [],
			"difficulty": 0.25 + float(serial) * 0.15,
			"defensibility": 0.35,
			"story": "Blank %sx%s content reservation. Future generation will stamp authored content here from the branch road." % [rect.size.x, rect.size.y],
		}
		if size_label == "large" and serial == 1:
			_attach_abandoned_wizard_monolith(plot)
		_register_plot(plot)
		_log_content_plot_debug(plot)

func _attach_abandoned_wizard_monolith(plot: Dictionary) -> void:
	var plot_rect: Rect2i = plot.get("rect", Rect2i())
	var footprint := Vector2i(16, 16)
	var structure_rect := Rect2i(
		plot_rect.position + Vector2i(maxi(0, (plot_rect.size.x - footprint.x) / 2), maxi(0, (plot_rect.size.y - footprint.y) / 2)),
		footprint
	)
	var generator = ContentStructureGeneratorScript.new()
	var structure: Dictionary = generator.generate_abandoned_wizard_monolith(
		"%s_monolith" % str(plot.get("id", "content")),
		structure_rect,
		seed_value + int(_hash_cell(plot_rect.position, 1107)),
		{
			"footprint_size": footprint.x,
			"floor_count": 3,
			"floor_height": 1.8,
			"room_density": 0.45,
			"gap_density": 0.035,
			"decor_density": 0.35,
		}
	)
	plot["has_interior"] = true
	plot["structure_type"] = "ABANDONED_WIZARD_MONOLITH"
	plot["structure_id"] = structure["id"]
	plot["structure_rect"] = structure_rect
	plot["footprint_size"] = structure["footprint_size"]
	plot["floor_count"] = int(structure["floor_count"])
	plot["entrance_cells"] = structure["entrance_cells"]
	plot["stair_links"] = structure["stair_links"]
	plot["discovered_floors"] = structure["discovered_floors"]
	plot["occupied_floors"] = structure["occupied_floors"]
	plot["content_structure"] = structure
	var entrance: Vector2i = structure["entrance_cells"][0]
	plot["anchor"] = entrance
	plot["road_anchor"] = entrance + Vector2i(0, 2)
	print("[MapGenerator] Content structure id=", structure["id"],
		" type=", structure["structure_type"],
		" rect=", structure_rect,
		" floors=", structure["floor_count"],
		" walkable_counts=", structure["validation"].get("walkable_counts", []),
		" stairs=", structure["validation"].get("stair_count", 0),
		" validation=", structure["validation"])

func _frontier_content_specs() -> Array[Dictionary]:
	var large_targets: Array[Vector2] = [
		Vector2(0.42, 0.34),
		Vector2(0.58, 0.36),
		Vector2(0.40, 0.62),
		Vector2(0.62, 0.62),
	]
	var large_target := large_targets[_rng.range_int(0, large_targets.size() - 1)]
	return [
		{"label": "medium", "archetype": "blank_medium_outpost", "size": Vector2i(10, 10), "target": Vector2(0.24, 0.62)},
		{"label": "small", "archetype": "blank_small_encounter", "size": Vector2i(5, 5), "target": Vector2(0.38, 0.24)},
		{"label": "large", "archetype": "blank_large_landmark", "size": Vector2i(14, 14), "target": large_target},
		{"label": "medium", "archetype": "blank_medium_ruin", "size": Vector2i(10, 10), "target": Vector2(0.76, 0.40)},
		{"label": "small", "archetype": "blank_small_cache", "size": Vector2i(5, 5), "target": Vector2(0.62, 0.76)},
		{"label": "medium", "archetype": "blank_medium_crossroad", "size": Vector2i(10, 10), "target": Vector2(0.50, 0.58)},
		{"label": "small", "archetype": "blank_small_shrine", "size": Vector2i(5, 5), "target": Vector2(0.78, 0.62)},
		{"label": "medium", "archetype": "blank_medium_camp", "size": Vector2i(10, 10), "target": Vector2(0.34, 0.78)},
		{"label": "small", "archetype": "blank_small_ambush", "size": Vector2i(5, 5), "target": Vector2(0.52, 0.24)},
	]

func _log_content_plot_debug(plot: Dictionary) -> void:
	var rect: Rect2i = plot.get("rect", Rect2i())
	print("[MapGenerator] Content plot id=", plot.get("id", ""),
		" archetype=", plot.get("content_archetype", ""),
		" requested=", plot.get("requested_size", Vector2i.ZERO),
		" footprint=", plot.get("final_footprint_size", Vector2i.ZERO),
		" candidates=", plot.get("candidate_count", 0),
		" chosen_index=", plot.get("chosen_candidate_index", -1),
		" position=", rect.position,
		" fallback=", plot.get("fallback_used", false),
		" reservation=", plot.get("reservation_rect", Rect2i()),
		" debug_rect=", plot.get("debug_render_rect", Rect2i()))

func _find_open_frontier_rect(size: Vector2i, reserved_rects: Array[Rect2i], preferred_normalized_position: Vector2, attempts: int) -> Rect2i:
	return _find_open_frontier_rect_debug(size, reserved_rects, preferred_normalized_position, attempts)["rect"]

func _find_open_frontier_rect_debug(size: Vector2i, reserved_rects: Array[Rect2i], preferred_normalized_position: Vector2, attempts: int) -> Dictionary:
	var best_rect := _clamped_rect(Vector2i(int(preferred_normalized_position.x * MAP_W), int(preferred_normalized_position.y * MAP_H)), size)
	var best_score := -INF
	var found_candidate := false
	var candidate_count := 0
	var chosen_candidate_index := -1
	var preferred_pos := Vector2(preferred_normalized_position.x * MAP_W, preferred_normalized_position.y * MAP_H)
	for i in range(attempts):
		var candidate := _clamped_rect(Vector2i(
			_rng.range_int(5, MAP_W - size.x - 5),
			_rng.range_int(5, MAP_H - size.y - 5)
		), size)
		if _rect_conflicts_reserved(candidate, reserved_rects, 2):
			continue
		if _frontier_rect_blocks_core_roads(candidate):
			continue
		candidate_count += 1
		var center := Vector2(candidate.position.x + candidate.size.x * 0.5, candidate.position.y + candidate.size.y * 0.5)
		var edge_penalty := 0.0
		edge_penalty += maxf(0.0, 18.0 - float(candidate.position.x)) * 5.0
		edge_penalty += maxf(0.0, 18.0 - float(candidate.position.y)) * 5.0
		edge_penalty += maxf(0.0, 18.0 - float(MAP_W - candidate.end.x)) * 5.0
		edge_penalty += maxf(0.0, 18.0 - float(MAP_H - candidate.end.y)) * 5.0
		var score := -center.distance_to(preferred_pos) - edge_penalty + float(_rng.range_int(0, 80))
		if score > best_score:
			best_score = score
			best_rect = candidate
			found_candidate = true
			chosen_candidate_index = i
	if found_candidate:
		return {
			"rect": best_rect,
			"candidate_count": candidate_count,
			"chosen_candidate_index": chosen_candidate_index,
			"fallback_used": false,
		}
	var fallback := _fallback_frontier_rect_debug(size, reserved_rects, preferred_normalized_position)
	fallback["candidate_count"] = candidate_count
	return fallback

func _fallback_frontier_rect(size: Vector2i, reserved_rects: Array[Rect2i], preferred_normalized_position := Vector2(0.5, 0.5)) -> Rect2i:
	return _fallback_frontier_rect_debug(size, reserved_rects, preferred_normalized_position)["rect"]

func _fallback_frontier_rect_debug(size: Vector2i, reserved_rects: Array[Rect2i], preferred_normalized_position := Vector2(0.5, 0.5)) -> Dictionary:
	var fallback_index := 0
	var candidate_count := 0
	var best_rect := Rect2i()
	var best_index := -1
	var best_score := -INF
	var preferred_pos := Vector2(preferred_normalized_position.x * MAP_W, preferred_normalized_position.y * MAP_H)
	for y in range(4, MAP_H - size.y - 4):
		for x in range(4, MAP_W - size.x - 4):
			var candidate := Rect2i(x, y, size.x, size.y)
			if _rect_conflicts_reserved(candidate, reserved_rects, 2):
				fallback_index += 1
				continue
			if _frontier_rect_blocks_core_roads(candidate):
				fallback_index += 1
				continue
			candidate_count += 1
			var center := Vector2(candidate.position.x + candidate.size.x * 0.5, candidate.position.y + candidate.size.y * 0.5)
			var edge_penalty := 0.0
			edge_penalty += maxf(0.0, 18.0 - float(candidate.position.x)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(candidate.position.y)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(MAP_W - candidate.end.x)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(MAP_H - candidate.end.y)) * 5.0
			var score := -center.distance_to(preferred_pos) - edge_penalty + float(_hash_cell(candidate.position, 5309) % 100) / 10.0
			if score > best_score:
				best_score = score
				best_rect = candidate
				best_index = fallback_index
			fallback_index += 1
	if best_rect.size != Vector2i.ZERO:
		return {
			"rect": best_rect,
			"candidate_count": candidate_count,
			"chosen_candidate_index": best_index,
			"fallback_used": true,
		}
	var rect := _fallback_plot_rect_near_target(size, reserved_rects, preferred_normalized_position)
	return {
		"rect": rect,
		"candidate_count": candidate_count,
		"chosen_candidate_index": -1,
		"fallback_used": true,
	}

func _fallback_plot_rect_near_target(size: Vector2i, reserved_rects: Array[Rect2i], preferred_normalized_position: Vector2) -> Rect2i:
	var preferred_pos := Vector2(preferred_normalized_position.x * MAP_W, preferred_normalized_position.y * MAP_H)
	var best_rect := _clamped_rect(Vector2i(int(preferred_pos.x), int(preferred_pos.y)), size)
	var best_score := -INF
	for y in range(4, MAP_H - size.y - 4):
		for x in range(4, MAP_W - size.x - 4):
			var candidate := Rect2i(x, y, size.x, size.y)
			if _rect_conflicts_reserved(candidate, reserved_rects, 2):
				continue
			var center := Vector2(candidate.position.x + candidate.size.x * 0.5, candidate.position.y + candidate.size.y * 0.5)
			var edge_penalty := 0.0
			edge_penalty += maxf(0.0, 18.0 - float(candidate.position.x)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(candidate.position.y)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(MAP_W - candidate.end.x)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(MAP_H - candidate.end.y)) * 5.0
			var score := -center.distance_to(preferred_pos) - edge_penalty + float(_hash_cell(candidate.position, 7309) % 100) / 10.0
			if score > best_score:
				best_score = score
				best_rect = candidate
	if best_score > -INF:
		return best_rect
	for y in range(4, MAP_H - size.y - 4):
		for x in range(4, MAP_W - size.x - 4):
			var candidate := Rect2i(x, y, size.x, size.y)
			if _content_rect_overlaps_existing_plot_or_ramp(candidate):
				continue
			var center := Vector2(candidate.position.x + candidate.size.x * 0.5, candidate.position.y + candidate.size.y * 0.5)
			var edge_penalty := 0.0
			edge_penalty += maxf(0.0, 18.0 - float(candidate.position.x)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(candidate.position.y)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(MAP_W - candidate.end.x)) * 5.0
			edge_penalty += maxf(0.0, 18.0 - float(MAP_H - candidate.end.y)) * 5.0
			var score := -center.distance_to(preferred_pos) - edge_penalty + float(_hash_cell(candidate.position, 8317) % 100) / 10.0
			if score > best_score:
				best_score = score
				best_rect = candidate
	return best_rect

func _content_rect_overlaps_existing_plot_or_ramp(rect: Rect2i) -> bool:
	for plot in plots:
		var plot_rect: Rect2i = plot.get("rect", Rect2i())
		if plot_rect.size != Vector2i.ZERO and rect.intersects(plot_rect):
			return true
		for ramp_rect in _plot_ramp_rects(plot):
			if rect.intersects(ramp_rect):
				return true
	return false

func _frontier_rect_blocks_core_roads(rect: Rect2i) -> bool:
	for spine in FRONTIER_ROAD_SPINES:
		var protected_horizontal := Rect2i(3, int(spine) - 3, MAP_W - 6, 7)
		var protected_vertical := Rect2i(int(spine) - 3, 3, 7, MAP_H - 6)
		if rect.intersects(protected_horizontal) or rect.intersects(protected_vertical):
			return true
	return false

func _expanded_rect(rect: Rect2i, margin: int) -> Rect2i:
	return Rect2i(rect.position - Vector2i(margin, margin), rect.size + Vector2i(margin * 2, margin * 2))

func _build_ai_testing_ground_plots() -> void:
	var west_base_rect := Rect2i(10, 30, 12, 14)
	var east_base_rect := Rect2i(74, 30, 12, 14)
	var arena_rect := Rect2i(28, 20, 40, 34)
	for plot in [
		_make_base_plot("ai_west_base", "West faction staging ground", west_base_rect, _make_economy_spaces(west_base_rect, 1), 0.2, 0.6, "Left-side AI test staging base."),
		_make_base_plot("ai_east_base", "East faction staging ground", east_base_rect, _make_economy_spaces(east_base_rect, 1), 0.2, 0.6, "Right-side AI test staging base."),
	]:
		_register_plot(plot)
	_register_plot({
		"id": "ai_arena",
		"name": "Central AI arena",
		"kind": "combat_arena",
		"rect": arena_rect,
		"anchor": arena_rect.position + Vector2i(arena_rect.size.x / 2, arena_rect.size.y / 2),
		"economy_spaces": [],
		"difficulty": 0.5,
		"defensibility": 0.0,
		"story": "Open center lane for two automated armies to find, hunt, path, and fight.",
	})

func _build_fortress_ai_arena_plots() -> void:
	var west_fort_rect := Rect2i(9, 27, 20, 22)
	var east_fort_rect := Rect2i(67, 27, 20, 22)
	var center_lane_rect := Rect2i(30, 25, 36, 30)
	for plot in [
		_make_base_plot("fort_west_base", "West observation fort", west_fort_rect, [], 0.35, 0.82, "Mirrored west fort used by owner 2."),
		_make_base_plot("fort_east_base", "East observation fort", east_fort_rect, [], 0.35, 0.82, "Mirrored east fort used by owner 3."),
	]:
		_register_plot(plot)
	_register_plot({
		"id": "siege_arena_center",
		"name": "Siege arena center",
		"kind": "combat_arena",
		"rect": center_lane_rect,
		"anchor": center_lane_rect.position + Vector2i(center_lane_rect.size.x / 2, center_lane_rect.size.y / 2),
		"economy_spaces": [],
		"difficulty": 0.5,
		"defensibility": 0.0,
		"story": "Central lane where mirrored armies should collide before pushing into forts.",
	})

func _make_economy_spaces(rect: Rect2i, count: int) -> Array[Vector2i]:
	var spaces: Array[Vector2i] = []
	var spacing: int = maxi(2, rect.size.x / (count + 1))
	var y: int = rect.position.y + maxi(2, rect.size.y / 2)
	for i in range(count):
		var x: int = rect.position.x + spacing * (i + 1)
		spaces.append(Vector2i(clampi(x, rect.position.x + 1, rect.end.x - 2), clampi(y, rect.position.y + 1, rect.end.y - 2)))
	return spaces

func _find_plot_rect(size: Vector2i, preferred_elevations: Array, reserved_rects: Array[Rect2i], attempts: int, preferred_normalized_position: Vector2) -> Rect2i:
	var best_rect := _clamped_rect(Vector2i(int(preferred_normalized_position.x * MAP_W), int(preferred_normalized_position.y * MAP_H)), size)
	var best_score := -999999.0
	for i in range(attempts):
		var candidate := _clamped_rect(Vector2i(
			_rng.range_int(3, MAP_W - size.x - 3),
			_rng.range_int(3, MAP_H - size.y - 3)
		), size)
		if _rect_conflicts_reserved(candidate, reserved_rects, 3):
			continue
		var score := _score_plot_rect(candidate, preferred_elevations, preferred_normalized_position)
		if score > best_score:
			best_score = score
			best_rect = candidate
	if best_score < -5000.0:
		best_rect = _fallback_plot_rect(size, reserved_rects)
	return best_rect

func _score_plot_rect(rect: Rect2i, preferred_elevations: Array, preferred_normalized_position: Vector2) -> float:
	var blocked := 0
	var water := 0
	var preferred := 0
	var ramp_cells := 0
	var total: int = maxi(1, rect.size.x * rect.size.y)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var elevation: int = grid[x][y]
			if elevation == E_BLOCKED:
				blocked += 1
			elif elevation == E_WATER:
				water += 1
			elif elevation == E_RAMP:
				ramp_cells += 1
			if preferred_elevations.has(elevation):
				preferred += 1
	if water > 0 or blocked > total / 4 or ramp_cells > 0:
		return -10000.0 - float(water * 100 + blocked * 10 + ramp_cells * 50)
	var center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	var preferred_pos := Vector2(preferred_normalized_position.x * MAP_W, preferred_normalized_position.y * MAP_H)
	var distance_penalty := center.distance_to(preferred_pos) * 1.4
	var lake_penalty := 0.0
	for lake in lakes:
		var lake_center: Vector2i = lake["center"]
		lake_penalty += max(0.0, 12.0 - center.distance_to(Vector2(lake_center))) * 8.0
	return float(preferred) * 12.0 - float(blocked) * 8.0 - distance_penalty - lake_penalty + float(_rng.range_int(0, 60))

func _rect_conflicts_reserved(rect: Rect2i, reserved_rects: Array[Rect2i], margin: int) -> bool:
	var expanded := Rect2i(rect.position - Vector2i(margin, margin), rect.size + Vector2i(margin * 2, margin * 2))
	for reserved in reserved_rects:
		if expanded.intersects(reserved):
			return true
	return false

func _fallback_plot_rect(size: Vector2i, reserved_rects: Array[Rect2i]) -> Rect2i:
	for y in range(3, MAP_H - size.y - 3):
		for x in range(3, MAP_W - size.x - 3):
			var rect := Rect2i(x, y, size.x, size.y)
			if not _rect_conflicts_reserved(rect, reserved_rects, 2):
				return rect
	return _clamped_rect(Vector2i(3, 3), size)

func _clamped_rect(origin: Vector2i, size: Vector2i) -> Rect2i:
	return Rect2i(
		clampi(origin.x, 3, MAP_W - size.x - 3),
		clampi(origin.y, 3, MAP_H - size.y - 3),
		size.x,
		size.y
	)

func _make_base_plot(id: String, name: String, rect: Rect2i, economy_spaces: Array, difficulty: float, defensibility: float, story: String) -> Dictionary:
	var sanitized_spaces: Array[Vector2i] = []
	for space in economy_spaces:
		var cell: Vector2i = space
		if rect.has_point(cell):
			sanitized_spaces.append(cell)
	return {
		"id": id,
		"name": name,
		"kind": "base",
		"rect": rect,
		"anchor": rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2),
		"economy_spaces": sanitized_spaces,
		"economy_count": sanitized_spaces.size(),
		"difficulty": difficulty,
		"defensibility": defensibility,
		"story": story,
	}

func _register_plot(plot: Dictionary) -> void:
	plots.append(plot)
	if plot.get("kind", "") == "base":
		base_plots.append(plot)

func _assign_plot_elevations() -> void:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		for plot in plots:
			plot["elevation"] = ELEVATION_LOW
		return
	var content_index := 0
	for plot in plots:
		var kind := str(plot.get("kind", ""))
		match kind:
			"base":
				if plot.has("base_archetype"):
					plot["elevation"] = str(_base_archetype_data(str(plot["base_archetype"])).get("elevation", ELEVATION_LOW))
				else:
					var defensibility := float(plot.get("defensibility", 0.0))
					plot["elevation"] = ELEVATION_HIGH if defensibility >= 0.72 else ELEVATION_LOW
			"content_blank":
				content_index += 1
				var content_size := str(plot.get("content_size", ""))
				if content_size == "small" or content_index <= 3:
					plot["elevation"] = ELEVATION_LOW
				else:
					plot["elevation"] = ELEVATION_HIGH
			"enemy_outpost", "objective":
				plot["elevation"] = ELEVATION_HIGH if _rng.chance_per_mille(760) else ELEVATION_LOW
			_:
				plot["elevation"] = ELEVATION_LOW

func _build_elevation_zones() -> void:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return
	_frontier_plateaus.clear()
	var original_grid := grid.duplicate(true)
	var original_features := feature_grid.duplicate(true)
	var original_ramps := ramps.duplicate(true)
	for plot in plots:
		if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH:
			_grow_frontier_organic_plateau(plot)
	for plot in plots:
		if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH:
			_ensure_frontier_plot_ramp(plot)
	for plot in plots:
		if str(plot.get("kind", "")) == "base" and not plot.has("road_anchors"):
			_ensure_frontier_plot_ramp(plot)
	if not _validate_frontier_plateau_generation(false):
		push_warning("[MapGenerator] Organic plateau generation failed validation. Falling back to rectangular high zones.")
		grid = original_grid
		feature_grid = original_features
		ramps = original_ramps
		_frontier_plateaus.clear()
		for plot in plots:
			plot.erase("ramp_rect")
			plot.erase("ramp_rects")
			plot.erase("road_anchor")
			plot.erase("road_anchors")
			plot.erase("plateau_id")
			if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH:
				_grow_frontier_elevation_zone(plot, E_HIGH)
		for plot in plots:
			if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH:
				_ensure_frontier_plot_ramp(plot)
		for plot in plots:
			if str(plot.get("kind", "")) == "base" and not plot.has("road_anchors"):
				_ensure_frontier_plot_ramp(plot)

func _grow_frontier_elevation_zone(plot: Dictionary, elevation: int) -> void:
	var rect: Rect2i = plot.get("rect", Rect2i())
	if rect.size == Vector2i.ZERO:
		return
	var margin := 3 if str(plot.get("kind", "")) == "base" else 2
	var zone := _expanded_rect(rect, margin)
	for x in range(zone.position.x, zone.end.x):
		for y in range(zone.position.y, zone.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			if feature_grid[x][y] == "map_border":
				continue
			var edge_distance: int = min(min(x - zone.position.x, zone.end.x - 1 - x), min(y - zone.position.y, zone.end.y - 1 - y))
			if edge_distance <= 0 and _hash_cell(cell, 511) % 1000 < 420:
				continue
			grid[x][y] = elevation
			feature_grid[x][y] = "high_zone"
	plot["plateau_id"] = _frontier_plateaus.size()
	_frontier_plateaus.append({
		"id": plot.get("id", "plateau_%s" % _frontier_plateaus.size()),
		"plot_id": plot.get("id", ""),
		"cells": _cells_in_rect(zone),
		"fallback": true,
	})

func _grow_frontier_organic_plateau(plot: Dictionary) -> void:
	var rect: Rect2i = plot.get("rect", Rect2i())
	if rect.size == Vector2i.ZERO:
		return
	var margin := 5 if str(plot.get("kind", "")) == "base" else 4
	var max_radius := 13 if str(plot.get("kind", "")) == "base" else 9
	var target_size := clampi(rect.size.x * rect.size.y + (margin * 18), rect.size.x * rect.size.y + 36, rect.size.x * rect.size.y + 260)
	var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
	var allowed_rect := _expanded_rect(rect, max_radius)
	var plateau := {}
	var frontier: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			plateau[cell] = true
			_frontier_add_neighbors(cell, frontier, plateau, allowed_rect, center, max_radius)
	var guard := 0
	while plateau.size() < target_size and not frontier.is_empty() and guard < target_size * 18:
		guard += 1
		var best_index := _best_frontier_plateau_candidate(frontier, plateau, rect, center, max_radius)
		var cell: Vector2i = frontier.pop_at(best_index)
		if plateau.has(cell):
			continue
		plateau[cell] = true
		_frontier_add_neighbors(cell, frontier, plateau, allowed_rect, center, max_radius)
	_soften_frontier_plateau_edges(plateau, rect, center)
	_prune_disconnected_frontier_plateau(plateau, rect)
	for cell_value in plateau.keys():
		var cell: Vector2i = cell_value
		if not is_in_bounds(cell):
			continue
		grid[cell.x][cell.y] = E_HIGH
		feature_grid[cell.x][cell.y] = "high_zone"
	var plateau_id := _frontier_plateaus.size()
	plot["plateau_id"] = plateau_id
	_frontier_plateaus.append({
		"id": "plateau_%s" % plateau_id,
		"plot_id": plot.get("id", ""),
		"cells": plateau.keys(),
		"fallback": false,
	})

func _frontier_add_neighbors(cell: Vector2i, frontier: Array[Vector2i], plateau: Dictionary, allowed_rect: Rect2i, center: Vector2i, max_radius: int) -> void:
	for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var next_cell: Vector2i = cell + offset
		if not is_in_bounds(next_cell) or plateau.has(next_cell) or frontier.has(next_cell):
			continue
		if not allowed_rect.has_point(next_cell) or _frontier_plateau_blocks_cell(next_cell, center, max_radius):
			continue
		frontier.append(next_cell)

func _frontier_plateau_blocks_cell(cell: Vector2i, center: Vector2i, max_radius: int) -> bool:
	if not is_in_bounds(cell) or feature_grid[cell.x][cell.y] == "map_border":
		return true
	if grid[cell.x][cell.y] == E_WATER or grid[cell.x][cell.y] == E_BLOCKED:
		return true
	if _is_inside_low_plot_rect(cell):
		return true
	var delta := cell - center
	var ellipse_distance := (float(delta.x * delta.x) / float(max_radius * max_radius)) + (float(delta.y * delta.y) / float(max_radius * max_radius))
	if ellipse_distance > 1.18:
		return true
	return false

func _best_frontier_plateau_candidate(frontier: Array[Vector2i], plateau: Dictionary, rect: Rect2i, center: Vector2i, max_radius: int) -> int:
	var best_index := 0
	var best_score: float = -INF
	for i in frontier.size():
		var cell: Vector2i = frontier[i]
		var delta: Vector2i = cell - center
		var distance: float = sqrt(float(delta.x * delta.x + delta.y * delta.y))
		var neighbor_score: float = float(_plateau_neighbor_count(cell, plateau)) * 22.0
		var blob_bias: float = -abs(distance - float(max_radius) * 0.58) * 3.4
		var edge_noise: float = float(_hash_cell(cell, 1731) % 1000) / 20.0
		var plot_bias: float = 30.0 if rect.has_point(cell) else 0.0
		var score: float = neighbor_score + blob_bias + edge_noise + plot_bias
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func _plateau_neighbor_count(cell: Vector2i, plateau: Dictionary) -> int:
	var count := 0
	for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if plateau.has(cell + offset):
			count += 1
	return count

func _soften_frontier_plateau_edges(plateau: Dictionary, protected_rect: Rect2i, center: Vector2i) -> void:
	var removals: Array[Vector2i] = []
	for cell_value in plateau.keys():
		var cell: Vector2i = cell_value
		if protected_rect.has_point(cell):
			continue
		var neighbors := _plateau_neighbor_count(cell, plateau)
		var hash := _hash_cell(cell, 2459) % 1000
		if neighbors <= 1 or (neighbors == 2 and hash < 520):
			removals.append(cell)
	for cell in removals:
		plateau.erase(cell)

func _prune_disconnected_frontier_plateau(plateau: Dictionary, protected_rect: Rect2i) -> void:
	if plateau.is_empty():
		return
	var start := protected_rect.position + Vector2i(protected_rect.size.x / 2, protected_rect.size.y / 2)
	if not plateau.has(start):
		for cell_value in plateau.keys():
			var cell: Vector2i = cell_value
			if protected_rect.has_point(cell):
				start = cell
				break
	var reached := {}
	var queue: Array[Vector2i] = [start]
	reached[start] = true
	var index := 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next_cell: Vector2i = cell + offset
			if plateau.has(next_cell) and not reached.has(next_cell):
				reached[next_cell] = true
				queue.append(next_cell)
	for cell_value in plateau.keys():
		var cell: Vector2i = cell_value
		if not reached.has(cell):
			plateau.erase(cell)

func _cells_in_rect(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if is_in_bounds(cell):
				cells.append(cell)
	return cells

func _ensure_frontier_plot_ramp(plot: Dictionary) -> void:
	if plot.has("ramp_rects") or plot.has("ramp_rect"):
		return
	var rect: Rect2i = plot.get("rect", Rect2i())
	if rect.size == Vector2i.ZERO:
		return
	if str(plot.get("kind", "")) == "base":
		if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH:
			var ramp_rects := _frontier_ramps_for_plateau(plot, int(plot.get("target_ramp_count", 1)), int(plot.get("ramp_width", 2)))
			if ramp_rects.is_empty():
				ramp_rects = [_frontier_ramp_for_base(rect, int(plot.get("ramp_width", 2)))]
			_set_plot_ramp_rects(plot, ramp_rects)
			return
		_set_plot_entrances(plot, _frontier_low_base_entrances(plot))
		return
	var ramp_rect := _frontier_ramp_for_plateau(plot)
	if ramp_rect.size == Vector2i.ZERO:
		ramp_rect = _frontier_ramp_for_base(rect, 2)
	_set_plot_ramp_rects(plot, [ramp_rect])

func _set_plot_ramp_rects(plot: Dictionary, ramp_rects: Array) -> void:
	var clean_rects: Array[Rect2i] = []
	for value in ramp_rects:
		var rect: Rect2i = value
		if rect.size != Vector2i.ZERO:
			clean_rects.append(rect)
	if clean_rects.is_empty():
		return
	plot["ramp_rects"] = clean_rects
	plot["ramp_rect"] = clean_rects[0]
	plot["actual_ramp_count"] = clean_rects.size()
	var road_anchors: Array[Vector2i] = []
	var plot_rect: Rect2i = plot.get("rect", Rect2i())
	for rect in clean_rects:
		road_anchors.append(_frontier_base_road_anchor(plot_rect, rect))
	plot["road_anchors"] = road_anchors
	plot["road_anchor"] = road_anchors[0]

func _set_plot_entrances(plot: Dictionary, entrances: Array[Vector2i]) -> void:
	var clean_anchors: Array[Vector2i] = []
	for entrance in entrances:
		if is_in_bounds(entrance):
			clean_anchors.append(entrance)
	if clean_anchors.is_empty():
		return
	plot["road_anchors"] = clean_anchors
	plot["road_anchor"] = clean_anchors[0]
	plot["actual_ramp_count"] = clean_anchors.size()

func _frontier_ramp_for_plateau(plot: Dictionary) -> Rect2i:
	var plateau_cells := _plateau_cells_for_plot(plot)
	if plateau_cells.is_empty():
		return Rect2i()
	var rect: Rect2i = plot.get("rect", Rect2i())
	var is_content := str(plot.get("kind", "")) != "base"
	if is_content:
		var entrance_x := rect.position.x + rect.size.x / 2
		return Rect2i(entrance_x - 1, rect.end.y, 3, 3)
	var best_cell := Vector2i(-1, -1)
	var best_dir := Vector2i.ZERO
	var best_score := INF
	for cell_value in plateau_cells:
		var cell: Vector2i = cell_value
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var outside: Vector2i = cell + dir
			if not is_in_bounds(outside) or grid[outside.x][outside.y] == E_HIGH:
				continue
			if grid[outside.x][outside.y] == E_WATER or grid[outside.x][outside.y] == E_BLOCKED:
				continue
			var score := _frontier_ramp_road_score(outside)
			if score < best_score:
				best_score = score
				best_cell = cell
				best_dir = dir
	if best_cell == Vector2i(-1, -1):
		return Rect2i()
	return _ramp_rect_from_edge(best_cell, best_dir, 2)

func _frontier_ramps_for_plateau(plot: Dictionary, target_count: int, ramp_width: int) -> Array[Rect2i]:
	var plateau_cells := _plateau_cells_for_plot(plot)
	var ramp_rects: Array[Rect2i] = []
	if plateau_cells.is_empty():
		return ramp_rects
	var candidates: Array[Dictionary] = []
	for cell_value in plateau_cells:
		var cell: Vector2i = cell_value
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var outside: Vector2i = cell + dir
			if not is_in_bounds(outside) or grid[outside.x][outside.y] == E_HIGH:
				continue
			if grid[outside.x][outside.y] == E_WATER or grid[outside.x][outside.y] == E_BLOCKED:
				continue
			candidates.append({
				"cell": cell,
				"dir": dir,
				"score": _frontier_ramp_road_score(outside),
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"])
	)
	for candidate in candidates:
		var ramp_rect := _ramp_rect_from_edge(candidate["cell"], candidate["dir"], ramp_width)
		if not _ramp_candidate_is_usable(ramp_rect, ramp_rects):
			continue
		ramp_rects.append(ramp_rect)
		if ramp_rects.size() >= target_count:
			break
	return ramp_rects

func _ramp_candidate_is_usable(ramp_rect: Rect2i, existing: Array[Rect2i]) -> bool:
	if ramp_rect.size == Vector2i.ZERO:
		return false
	for x in range(ramp_rect.position.x, ramp_rect.end.x):
		for y in range(ramp_rect.position.y, ramp_rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				return false
			if grid[x][y] == E_WATER or grid[x][y] == E_BLOCKED:
				return false
	for other in existing:
		if _expanded_rect(other, 3).intersects(ramp_rect):
			return false
	return true

func _plateau_cells_for_plot(plot: Dictionary) -> Array:
	var plateau_id := int(plot.get("plateau_id", -1))
	if plateau_id >= 0 and plateau_id < _frontier_plateaus.size():
		return _frontier_plateaus[plateau_id].get("cells", [])
	return []

func _frontier_ramp_road_score(cell: Vector2i) -> float:
	var nearest_spine_distance := INF
	for spine in FRONTIER_ROAD_SPINES:
		nearest_spine_distance = minf(nearest_spine_distance, absf(float(cell.x - int(spine))))
		nearest_spine_distance = minf(nearest_spine_distance, absf(float(cell.y - int(spine))))
	var center_distance := Vector2(cell).distance_to(Vector2(FRONTIER_MAIN_ROAD_X, FRONTIER_MAIN_ROAD_Y)) * 0.18
	return nearest_spine_distance + center_distance + float(_hash_cell(cell, 911) % 100) / 100.0

func _ramp_rect_from_edge(edge_cell: Vector2i, dir: Vector2i, ramp_width: int = 3) -> Rect2i:
	var width: int = clampi(ramp_width, 1, 4)
	if dir == Vector2i.RIGHT:
		return Rect2i(edge_cell.x, edge_cell.y - width / 2, width + 1, width)
	if dir == Vector2i.LEFT:
		return Rect2i(edge_cell.x - width, edge_cell.y - width / 2, width + 1, width)
	if dir == Vector2i.UP:
		return Rect2i(edge_cell.x - width / 2, edge_cell.y - width, width, width + 1)
	return Rect2i(edge_cell.x - width / 2, edge_cell.y, width, width + 1)

func _frontier_ramp_for_base(rect: Rect2i, ramp_width: int = 2) -> Rect2i:
	var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
	var map_center := Vector2i(MAP_W / 2, MAP_H / 2)
	var delta := map_center - center
	var width: int = clampi(ramp_width, 1, 4)
	if abs(delta.x) > abs(delta.y):
		if delta.x >= 0:
			return Rect2i(rect.end.x, center.y - width / 2, width + 1, width)
		return Rect2i(rect.position.x - width, center.y - width / 2, width + 1, width)
	if delta.y >= 0:
		return Rect2i(center.x - width / 2, rect.end.y, width, width + 1)
	return Rect2i(center.x - width / 2, rect.position.y - width, width, width + 1)

func _frontier_low_base_entrances(plot: Dictionary) -> Array[Vector2i]:
	var rect: Rect2i = plot.get("rect", Rect2i())
	var target_count := int(plot.get("target_ramp_count", 1))
	var entrances: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [
		Vector2i(rect.position.x + rect.size.x / 2, rect.position.y - 1),
		Vector2i(rect.position.x + rect.size.x / 2, rect.end.y),
		Vector2i(rect.position.x - 1, rect.position.y + rect.size.y / 2),
		Vector2i(rect.end.x, rect.position.y + rect.size.y / 2),
	]
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _frontier_ramp_road_score(a) < _frontier_ramp_road_score(b)
	)
	for candidate in candidates:
		if is_in_bounds(candidate):
			entrances.append(candidate)
		if entrances.size() >= target_count:
			break
	return entrances

func _is_inside_low_plot_rect(cell: Vector2i) -> bool:
	for plot in plots:
		if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH:
			continue
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.has_point(cell):
			return true
	return false

func _is_inside_high_plot_rect(cell: Vector2i) -> bool:
	for plot in plots:
		if str(plot.get("elevation", ELEVATION_LOW)) != ELEVATION_HIGH:
			continue
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.has_point(cell):
			return true
	return false

func _stamp_plots_into_grid() -> void:
	for plot in plots:
		match str(plot.get("kind", "")):
			"base":
				_stamp_base_plot(plot)
			"content_blank":
				_stamp_blank_content_plot(plot)
			"quest":
				_stamp_hollow_plot(plot, "tower_wall", "tower_floor")
			"enemy_outpost":
				_stamp_hollow_plot(plot, "bandit_wall", "bandit_floor")
			"objective":
				_stamp_objective_plot(plot)

func _stamp_blank_content_plot(plot: Dictionary) -> void:
	var rect: Rect2i = plot["rect"]
	var floor_elevation := E_HIGH if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH else E_LOW
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			grid[x][y] = floor_elevation
			feature_grid[x][y] = "content_plot_blank"
	if bool(plot.get("has_interior", false)):
		_stamp_content_structure_exterior(plot, floor_elevation)
	if floor_elevation == E_HIGH and plot.has("ramp_rect"):
		_stamp_frontier_ramp(plot)
		plot["anchor"] = Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 2)

func _stamp_content_structure_exterior(plot: Dictionary, floor_elevation: int) -> void:
	var structure_rect: Rect2i = plot.get("structure_rect", plot.get("rect", Rect2i()))
	var entrance_cells: Array = plot.get("entrance_cells", [])
	var entrance_lookup := {}
	for entrance_value in entrance_cells:
		entrance_lookup[entrance_value] = true
	for x in range(structure_rect.position.x, structure_rect.end.x):
		for y in range(structure_rect.position.y, structure_rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			var edge := x == structure_rect.position.x or x == structure_rect.end.x - 1 or y == structure_rect.position.y or y == structure_rect.end.y - 1
			grid[x][y] = floor_elevation
			if entrance_lookup.has(cell):
				feature_grid[x][y] = "content_structure_entrance"
				continue
			if edge and _hash_cell(cell, 1211) % 100 > 22:
				grid[x][y] = E_BLOCKED
				feature_grid[x][y] = "content_structure_wall"
			elif edge:
				feature_grid[x][y] = "content_structure_broken_wall"
			else:
				feature_grid[x][y] = "content_structure_exterior"
	var road_anchor: Vector2i = plot.get("road_anchor", Vector2i(structure_rect.position.x + structure_rect.size.x / 2, structure_rect.end.y + 1))
	for y in range(structure_rect.end.y - 1, mini(MAP_H, road_anchor.y + 1)):
		for x in range(structure_rect.position.x + structure_rect.size.x / 2 - 1, structure_rect.position.x + structure_rect.size.x / 2 + 2):
			var approach := Vector2i(x, y)
			if is_in_bounds(approach):
				grid[x][y] = floor_elevation
				feature_grid[x][y] = "content_structure_entrance"

func _stamp_base_plot(plot: Dictionary) -> void:
	var rect: Rect2i = plot["rect"]
	var floor_elevation := E_HIGH if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH else E_LOW
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		floor_elevation = _dominant_elevation_near(rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2))
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			grid[x][y] = floor_elevation
			feature_grid[x][y] = "base_floor"
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER and plot.has("ramp_rect"):
		var ramp_rects: Array = plot.get("ramp_rects", [plot["ramp_rect"]])
		for ramp_rect_value in ramp_rects:
			var ramp_rect: Rect2i = ramp_rect_value
			_stamp_frontier_ramp_rect(plot, ramp_rect)
		var road_anchors: Array[Vector2i] = []
		for ramp_rect_value in ramp_rects:
			var ramp_rect: Rect2i = ramp_rect_value
			road_anchors.append(_frontier_base_road_anchor(rect, ramp_rect))
		if not road_anchors.is_empty():
			plot["road_anchors"] = road_anchors
			plot["road_anchor"] = road_anchors[0]
			plot["actual_ramp_count"] = road_anchors.size()
	for economy_cell in plot.get("economy_spaces", []):
		if is_in_bounds(economy_cell):
			grid[economy_cell.x][economy_cell.y] = floor_elevation
			feature_grid[economy_cell.x][economy_cell.y] = "economy_space"

func _stamp_frontier_ramp(plot: Dictionary) -> void:
	var ramp_rect: Rect2i = plot["ramp_rect"]
	_stamp_frontier_ramp_rect(plot, ramp_rect)

func _stamp_frontier_ramp_rect(plot: Dictionary, ramp_rect: Rect2i) -> void:
	var plot_rect: Rect2i = plot.get("rect", Rect2i())
	if not ramps.has(ramp_rect):
		ramps.append(ramp_rect)
	var ramp_direction := _ramp_plateau_direction(ramp_rect)
	var carved_cells := _carve_plateau_edge_for_ramp(plot, ramp_rect, ramp_direction)
	for x in range(ramp_rect.position.x, ramp_rect.end.x):
		for y in range(ramp_rect.position.y, ramp_rect.end.y):
			var ramp_cell := Vector2i(x, y)
			if not is_in_bounds(ramp_cell):
				continue
			grid[x][y] = E_RAMP
			feature_grid[x][y] = "ramp"
	_stamp_frontier_high_access_corridor_for_ramp(plot, ramp_rect)
	var debug_record := {
		"plateau_id": int(plot.get("plateau_id", -1)),
		"ramp_rect": ramp_rect,
		"direction": ramp_direction,
		"carved_cell_count": carved_cells.size(),
		"landing_size": _ramp_landing_size(plot, ramp_rect, ramp_direction),
	}
	if not plot.has("ramp_carve_debug"):
		plot["ramp_carve_debug"] = []
	plot["ramp_carve_debug"].append(debug_record)
	print("[MapGenerator] Ramp carve plateau=", debug_record["plateau_id"],
		" dir=", ramp_direction,
		" carved=", debug_record["carved_cell_count"],
		" landing=", debug_record["landing_size"])

func _carve_plateau_edge_for_ramp(plot: Dictionary, ramp_rect: Rect2i, plateau_dir: Vector2i) -> Array[Vector2i]:
	var carved_cells: Array[Vector2i] = []
	var plot_rect: Rect2i = plot.get("rect", Rect2i())
	var bottom_dir := -plateau_dir
	var across := Vector2i(-plateau_dir.y, plateau_dir.x)
	var ramp_center := ramp_rect.position + Vector2i(ramp_rect.size.x / 2, ramp_rect.size.y / 2)
	var width: int = maxi(ramp_rect.size.x, ramp_rect.size.y)
	var half_width: int = maxi(1, width / 2)

	for depth in range(0, 2):
		for side in range(-half_width, half_width + 1):
			var cell: Vector2i = ramp_center + plateau_dir * depth + across * side
			if _mark_ramp_cell(cell, "ramp", plot_rect, true):
				carved_cells.append(cell)

	for depth in range(2, 4):
		for side in range(-half_width, half_width + 1):
			var cell: Vector2i = ramp_center + plateau_dir * depth + across * side
			if _mark_high_landing_cell(cell, "ramp_top_landing", plot_rect):
				carved_cells.append(cell)

	for depth in range(1, 4):
		for side in range(-half_width - 1, half_width + 2):
			var cell: Vector2i = ramp_center + bottom_dir * depth + across * side
			if _mark_low_landing_cell(cell, "ramp_bottom_landing", plot_rect):
				carved_cells.append(cell)

	for depth in range(-1, 4):
		for side in [-half_width - 2, half_width + 2]:
			var cell: Vector2i = ramp_center + plateau_dir * depth + across * side
			if _mark_soft_edge_cell(cell, plot_rect):
				carved_cells.append(cell)
	return carved_cells

func _mark_ramp_cell(cell: Vector2i, feature: String, plot_rect: Rect2i, allow_plot: bool) -> bool:
	if not is_in_bounds(cell):
		return false
	if not allow_plot and plot_rect.has_point(cell):
		return false
	if grid[cell.x][cell.y] == E_WATER or grid[cell.x][cell.y] == E_BLOCKED:
		return false
	grid[cell.x][cell.y] = E_RAMP
	feature_grid[cell.x][cell.y] = feature
	return true

func _mark_high_landing_cell(cell: Vector2i, feature: String, plot_rect: Rect2i) -> bool:
	if not is_in_bounds(cell) or not plot_rect.grow(6).has_point(cell):
		return false
	if grid[cell.x][cell.y] == E_WATER or grid[cell.x][cell.y] == E_BLOCKED:
		return false
	grid[cell.x][cell.y] = E_HIGH
	feature_grid[cell.x][cell.y] = feature
	return true

func _mark_low_landing_cell(cell: Vector2i, feature: String, plot_rect: Rect2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if plot_rect.has_point(cell) or _is_inside_high_plot_rect(cell):
		return false
	if grid[cell.x][cell.y] == E_WATER or grid[cell.x][cell.y] == E_BLOCKED:
		return false
	if grid[cell.x][cell.y] == E_HIGH:
		grid[cell.x][cell.y] = E_LOW
	feature_grid[cell.x][cell.y] = feature
	return true

func _mark_soft_edge_cell(cell: Vector2i, plot_rect: Rect2i) -> bool:
	if not is_in_bounds(cell) or plot_rect.has_point(cell) or _is_inside_high_plot_rect(cell):
		return false
	if grid[cell.x][cell.y] != E_HIGH:
		return false
	if _hash_cell(cell, 4289) % 1000 < 460:
		grid[cell.x][cell.y] = E_LOW
		feature_grid[cell.x][cell.y] = "ramp_carve"
		return true
	feature_grid[cell.x][cell.y] = "ramp_soft_edge"
	return true

func _ramp_plateau_direction(ramp_rect: Rect2i) -> Vector2i:
	var scores := {
		Vector2i.RIGHT: _ramp_high_score_on_side(ramp_rect, Vector2i.RIGHT),
		Vector2i.LEFT: _ramp_high_score_on_side(ramp_rect, Vector2i.LEFT),
		Vector2i.DOWN: _ramp_high_score_on_side(ramp_rect, Vector2i.DOWN),
		Vector2i.UP: _ramp_high_score_on_side(ramp_rect, Vector2i.UP),
	}
	var best_dir := Vector2i.UP
	var best_score := -1
	for dir in scores.keys():
		var score := int(scores[dir])
		if score > best_score:
			best_score = score
			best_dir = dir
	return best_dir

func _ramp_high_score_on_side(ramp_rect: Rect2i, dir: Vector2i) -> int:
	var score := 0
	if dir.x != 0:
		var x := ramp_rect.end.x if dir.x > 0 else ramp_rect.position.x - 1
		for y in range(ramp_rect.position.y - 1, ramp_rect.end.y + 1):
			if is_in_bounds(Vector2i(x, y)) and grid[x][y] == E_HIGH:
				score += 1
	else:
		var y := ramp_rect.end.y if dir.y > 0 else ramp_rect.position.y - 1
		for x in range(ramp_rect.position.x - 1, ramp_rect.end.x + 1):
			if is_in_bounds(Vector2i(x, y)) and grid[x][y] == E_HIGH:
				score += 1
	return score

func _ramp_landing_size(plot: Dictionary, ramp_rect: Rect2i, plateau_dir: Vector2i) -> Vector2i:
	var width: int = maxi(ramp_rect.size.x, ramp_rect.size.y)
	var depth := 2
	if plateau_dir.x != 0:
		return Vector2i(depth, width)
	return Vector2i(width, depth)

func _stamp_frontier_high_access_corridor(plot: Dictionary) -> void:
	var ramp_rect: Rect2i = plot["ramp_rect"]
	_stamp_frontier_high_access_corridor_for_ramp(plot, ramp_rect)

func _stamp_frontier_high_access_corridor_for_ramp(plot: Dictionary, ramp_rect: Rect2i) -> void:
	var start := ramp_rect.position + Vector2i(ramp_rect.size.x / 2, ramp_rect.size.y / 2)
	var target: Vector2i = plot.get("anchor", start)
	for cell in _line_cells(start, target):
		for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var access_cell: Vector2i = cell + offset
			if not is_in_bounds(access_cell) or grid[access_cell.x][access_cell.y] == E_RAMP:
				continue
			if grid[access_cell.x][access_cell.y] == E_HIGH:
				feature_grid[access_cell.x][access_cell.y] = "high_access"

func _frontier_base_road_anchor(base_rect: Rect2i, ramp_rect: Rect2i) -> Vector2i:
	var ramp_center := ramp_rect.position + Vector2i(ramp_rect.size.x / 2, ramp_rect.size.y / 2)
	return ramp_center

func _stamp_hollow_plot(plot: Dictionary, wall_feature: String, floor_feature: String) -> void:
	var rect: Rect2i = plot["rect"]
	var floor_elevation := _dominant_elevation_near(plot["anchor"])
	var entrance_x := rect.position.x + rect.size.x / 2
	var entrance_y := rect.end.y - 1
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			var is_edge := _is_rect_edge(cell, rect)
			var is_entrance: bool = y == entrance_y and abs(x - entrance_x) <= 1
			if is_edge and not is_entrance:
				grid[x][y] = E_BLOCKED
				feature_grid[x][y] = wall_feature
			else:
				grid[x][y] = floor_elevation
				feature_grid[x][y] = floor_feature
	plot["anchor"] = Vector2i(entrance_x, entrance_y - 2)
	plot["road_anchor"] = nearest_walkable_cell(Vector2i(entrance_x, entrance_y + 1), 4)

func _stamp_objective_plot(plot: Dictionary) -> void:
	var rect: Rect2i = plot["rect"]
	var floor_elevation := _dominant_elevation_near(plot["anchor"])
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			grid[x][y] = floor_elevation
			feature_grid[x][y] = "objective"
			var edge_distance: int = min(min(x - rect.position.x, rect.end.x - 1 - x), min(y - rect.position.y, rect.end.y - 1 - y))
			if edge_distance == 0 and _rng.chance_per_mille(420):
				grid[x][y] = E_BLOCKED
				feature_grid[x][y] = "giant_mushroom"

func _build_roads() -> void:
	road_cells.clear()
	_frontier_road_debug.clear()
	if map_type_id == MAP_TYPE_AI_TESTING_GROUND or map_type_id == MAP_TYPE_FORTRESS_AI_ARENA:
		return
	if plots.is_empty():
		return
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		_build_frontier_road_network_for_mode()
		_smooth_roads_with_validation()
		_debug_print_frontier_road_summary()
		return
	var hub := nearest_walkable_cell(Vector2i(MAP_W / 2, MAP_H / 2), 24)
	for plot in plots:
		var anchor: Vector2i = plot.get("anchor", hub)
		_carve_road_between(anchor, hub, 2)
	for i in range(plots.size() - 1):
		var from_anchor: Vector2i = plots[i].get("anchor", hub)
		var to_anchor: Vector2i = plots[i + 1].get("anchor", hub)
		_carve_road_between(from_anchor, to_anchor, 1)
	_smooth_roads_with_validation()

func _build_frontier_road_network_for_mode() -> void:
	if frontier_road_layout_mode == ROAD_MODE_ORGANIC_SPINE_AND_BRANCHES:
		var original_grid := grid.duplicate(true)
		var original_features := feature_grid.duplicate(true)
		var original_roads := road_cells.duplicate(true)
		_build_frontier_organic_spine_and_branches()
		var validation := _validate_frontier_organic_road_network()
		if bool(validation.get("passed", false)):
			_frontier_road_debug["mode"] = ROAD_MODE_ORGANIC_SPINE_AND_BRANCHES
			_frontier_road_debug["fallback"] = false
			_frontier_road_debug["validation"] = true
			return
		push_warning("[MapGenerator] organic_spine_and_branches failed validation: %s. Falling back to grid arteries." % str(validation.get("reason", "unknown")))
		grid = original_grid
		feature_grid = original_features
		road_cells = original_roads
		_build_frontier_road_network()
		_frontier_road_debug["mode"] = ROAD_MODE_GRID_ARTERIES
		_frontier_road_debug["fallback"] = true
		_frontier_road_debug["fallback_reason"] = validation.get("reason", "unknown")
		_frontier_road_debug["validation"] = _validate_frontier_organic_road_network().get("passed", false)
		return
	_build_frontier_road_network()
	_frontier_road_debug["mode"] = ROAD_MODE_GRID_ARTERIES
	_frontier_road_debug["fallback"] = false
	_frontier_road_debug["validation"] = _validate_frontier_organic_road_network().get("passed", false)

func _build_frontier_road_network() -> void:
	_carve_frontier_arterial_roads()
	for plot in plots:
		_carve_frontier_plot_approach(plot)
		for anchor in _plot_road_anchors(plot):
			anchor = nearest_walkable_cell(anchor, 8)
			if not is_in_bounds(anchor):
				continue
			var spine_target := _frontier_spine_target_for_anchor(anchor)
			if not is_in_bounds(spine_target):
				spine_target = Vector2i(FRONTIER_MAIN_ROAD_X, FRONTIER_MAIN_ROAD_Y)
			_carve_frontier_road(anchor, spine_target, int(plot.get("ramp_width", FRONTIER_MAIN_SPINE_ROAD_WIDTH)))
	_carve_frontier_landmark_approaches(false)

func _build_frontier_organic_spine_and_branches() -> void:
	_frontier_road_debug = {
		"mode": ROAD_MODE_ORGANIC_SPINE_AND_BRANCHES,
		"main_spine_node_count": 0,
		"branch_count": 0,
		"fallback": false,
		"validation": false,
	}
	for plot in plots:
		_carve_frontier_plot_approach(plot)
	var spine_nodes := _frontier_main_spine_nodes()
	_frontier_road_debug["main_spine_node_count"] = spine_nodes.size()
	var roads_before_spine := road_cells.size()
	for i in range(spine_nodes.size() - 1):
		_carve_frontier_organic_road(spine_nodes[i], spine_nodes[i + 1], 2 + i, FRONTIER_MAIN_SPINE_ROAD_WIDTH)
	_frontier_road_debug["spine_road_cells"] = road_cells.size() - roads_before_spine
	var branch_count := 0
	var roads_before_branches := road_cells.size()
	for plot in plots:
		for anchor in _plot_road_anchors(plot):
			anchor = nearest_walkable_cell(anchor, 8)
			if not is_in_bounds(anchor):
				continue
			var connection := _nearest_road_cell(anchor, road_cells, 96)
			if not is_in_bounds(connection):
				connection = Vector2i(FRONTIER_MAIN_ROAD_X, FRONTIER_MAIN_ROAD_Y)
			var branch_width: int = int(plot.get("ramp_width", FRONTIER_BRANCH_ROAD_WIDTH)) if str(plot.get("kind", "")) == "base" else FRONTIER_BRANCH_ROAD_WIDTH
			_carve_frontier_organic_road(anchor, connection, 101 + branch_count, branch_width)
			branch_count += 1
	branch_count += _carve_frontier_landmark_approaches(true, branch_count)
	_connect_frontier_road_components()
	_frontier_road_debug["branch_count"] = branch_count
	_frontier_road_debug["branch_road_cells"] = road_cells.size() - roads_before_branches
	_frontier_road_debug["junction_count"] = _frontier_junction_count()
	_frontier_road_debug["width_settings"] = "spine=%s branch=%s plot=%s junction_max=%sx%s" % [
		FRONTIER_MAIN_SPINE_ROAD_WIDTH,
		FRONTIER_BRANCH_ROAD_WIDTH,
		FRONTIER_PLOT_APPROACH_ROAD_WIDTH,
		FRONTIER_MAX_JUNCTION_SIZE,
		FRONTIER_MAX_JUNCTION_SIZE,
	]

func _connect_frontier_road_components() -> void:
	var guard := 0
	while guard < 48:
		guard += 1
		var components := _frontier_road_components()
		if components.size() <= 1:
			return
		components.sort_custom(func(a: Array, b: Array) -> bool:
			return a.size() > b.size()
		)
		var main_component: Array = components[0]
		var other_component: Array = components[1]
		var pair := _nearest_road_component_pair(main_component, other_component)
		if pair.size() != 2:
			return
		_carve_frontier_organic_road(pair[0], pair[1], 700 + guard, FRONTIER_BRANCH_ROAD_WIDTH)

func _frontier_road_components() -> Array[Array]:
	var components: Array[Array] = []
	var visited := {}
	for road_cell_value in road_cells.keys():
		var road_cell: Vector2i = road_cell_value
		if visited.has(road_cell):
			continue
		var component: Array[Vector2i] = []
		var queue: Array[Vector2i] = [road_cell]
		visited[road_cell] = true
		var index := 0
		while index < queue.size():
			var cell: Vector2i = queue[index]
			index += 1
			component.append(cell)
			for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var next_cell: Vector2i = cell + offset
				if road_cells.has(next_cell) and not visited.has(next_cell):
					visited[next_cell] = true
					queue.append(next_cell)
		components.append(component)
	return components

func _nearest_road_component_pair(main_component: Array, other_component: Array) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_distance := INF
	for a_value in main_component:
		var a: Vector2i = a_value
		for b_value in other_component:
			var b: Vector2i = b_value
			var distance := Vector2(a).distance_squared_to(Vector2(b))
			if distance < best_distance:
				best_distance = distance
				best = [a, b]
	return best

func _frontier_main_spine_nodes() -> Array[Vector2i]:
	var nodes: Array[Vector2i] = []
	var start := Vector2i(4, FRONTIER_MAIN_ROAD_Y + _seeded_road_offset(19, 8))
	nodes.append(nearest_walkable_cell(start, 10))
	var important := _frontier_important_road_anchors()
	if not important.is_empty():
		var current := nodes[0]
		while not important.is_empty():
			var best_index := 0
			var best_score := INF
			for i in important.size():
				var candidate: Vector2i = important[i]
				var score := Vector2(current).distance_to(Vector2(candidate)) + float(_hash_cell(candidate, 343) % 100) / 8.0
				if score < best_score:
					best_score = score
					best_index = i
			current = important.pop_at(best_index)
			nodes.append(current)
	nodes.append(nearest_walkable_cell(Vector2i(MAP_W - 5, FRONTIER_MAIN_ROAD_Y + _seeded_road_offset(23, 8)), 10))
	nodes.append(nearest_walkable_cell(Vector2i(FRONTIER_MAIN_ROAD_X + _seeded_road_offset(29, 8), 4), 10))
	nodes.append(nearest_walkable_cell(Vector2i(FRONTIER_MAIN_ROAD_X + _seeded_road_offset(31, 8), MAP_H - 5), 10))
	return _dedupe_valid_cells(nodes)

func _frontier_important_road_anchors() -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	for plot in plots:
		var kind := str(plot.get("kind", ""))
		var content_size := str(plot.get("content_size", ""))
		if kind == "base" or kind == "enemy_outpost" or kind == "objective" or content_size == "large":
			for anchor in _plot_road_anchors(plot):
				anchor = nearest_walkable_cell(anchor, 8)
				if is_in_bounds(anchor):
					anchors.append(anchor)
	for anchor in _frontier_landmark_road_anchors():
		anchor = nearest_walkable_cell(anchor, 8)
		if is_in_bounds(anchor):
			anchors.append(anchor)
	return anchors

func _frontier_landmark_road_anchors() -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	for landmark in landmarks:
		if not bool(landmark.get("road_interest", false)):
			continue
		var anchor: Vector2i = landmark.get("road_anchor", landmark.get("center", Vector2i(-1, -1)))
		if is_in_bounds(anchor):
			anchors.append(anchor)
	return anchors

func _carve_frontier_landmark_approaches(organic: bool, salt_offset: int = 0) -> int:
	var branch_count := 0
	for anchor in _frontier_landmark_road_anchors():
		anchor = nearest_walkable_cell(anchor, 8)
		if not is_in_bounds(anchor):
			continue
		var connection := _nearest_road_cell(anchor, road_cells, 96)
		if not is_in_bounds(connection):
			connection = _frontier_spine_target_for_anchor(anchor)
		if not is_in_bounds(connection):
			connection = Vector2i(FRONTIER_MAIN_ROAD_X, FRONTIER_MAIN_ROAD_Y)
		if organic:
			_carve_frontier_organic_road(anchor, connection, 401 + salt_offset + branch_count, FRONTIER_BRANCH_ROAD_WIDTH)
		else:
			_carve_frontier_road(anchor, connection, FRONTIER_BRANCH_ROAD_WIDTH)
		branch_count += 1
	return branch_count

func _dedupe_valid_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var deduped: Array[Vector2i] = []
	var seen := {}
	for cell in cells:
		if not is_in_bounds(cell) or seen.has(cell):
			continue
		seen[cell] = true
		deduped.append(cell)
	return deduped

func _plot_road_anchors(plot: Dictionary) -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	if plot.has("road_anchors"):
		for value in plot["road_anchors"]:
			var anchor: Vector2i = value
			if is_in_bounds(anchor):
				anchors.append(anchor)
	if anchors.is_empty():
		var fallback: Vector2i = plot.get("road_anchor", plot.get("anchor", Vector2i.ZERO))
		if is_in_bounds(fallback):
			anchors.append(fallback)
	return anchors

func _plot_ramp_rects(plot: Dictionary) -> Array[Rect2i]:
	var ramp_rects: Array[Rect2i] = []
	if plot.has("ramp_rects"):
		for value in plot["ramp_rects"]:
			var ramp_rect: Rect2i = value
			if ramp_rect.size != Vector2i.ZERO:
				ramp_rects.append(ramp_rect)
	elif plot.has("ramp_rect"):
		var ramp_rect: Rect2i = plot["ramp_rect"]
		if ramp_rect.size != Vector2i.ZERO:
			ramp_rects.append(ramp_rect)
	return ramp_rects

func _carve_frontier_organic_road(from_cell: Vector2i, to_cell: Vector2i, salt: int, road_width: int = FRONTIER_BRANCH_ROAD_WIDTH) -> void:
	from_cell = nearest_walkable_cell(from_cell, 10)
	to_cell = nearest_walkable_cell(to_cell, 10)
	if not is_in_bounds(from_cell) or not is_in_bounds(to_cell):
		return
	var midpoint := Vector2i((from_cell.x + to_cell.x) / 2, (from_cell.y + to_cell.y) / 2)
	var delta := to_cell - from_cell
	var bend_axis := Vector2i(-clampi(delta.y, -1, 1), clampi(delta.x, -1, 1))
	if bend_axis == Vector2i.ZERO:
		bend_axis = Vector2i(1, 0)
	var bend_amount := _seeded_road_offset(salt, 10)
	var bend := nearest_walkable_cell(midpoint + bend_axis * bend_amount, 14)
	if not is_in_bounds(bend):
		bend = midpoint
	_carve_frontier_road(from_cell, bend, road_width)
	_carve_frontier_road(bend, to_cell, road_width)

func _seeded_road_offset(salt: int, magnitude: int) -> int:
	var value := int((_hash_cell(Vector2i(seed_value & 255, (seed_value >> 8) & 255), salt) % (magnitude * 2 + 1)) - magnitude)
	if abs(value) < 3:
		return 3 if value >= 0 else -3
	return value

func _validate_frontier_organic_road_network() -> Dictionary:
	if road_cells.is_empty():
		return {"passed": false, "reason": "no road cells carved"}
	var start := _road_validation_start_cell(Vector2i(FRONTIER_MAIN_ROAD_X, FRONTIER_MAIN_ROAD_Y))
	start = nearest_walkable_cell(start, 12)
	if not is_in_bounds(start):
		return {"passed": false, "reason": "no reachable spawn/start anchor"}
	var reachable_walkable := _flood_walkable_cells(start)
	for plot in plots:
		var anchor: Vector2i = plot.get("anchor", plot.get("road_anchor", Vector2i(-1, -1)))
		anchor = nearest_walkable_cell(anchor, 8)
		if not is_in_bounds(anchor) or not reachable_walkable.has(anchor):
			return {"passed": false, "reason": "plot unreachable: %s" % plot.get("id", "<unknown>")}
		for road_anchor in _plot_road_anchors(plot):
			if not is_in_bounds(_nearest_road_cell(road_anchor, road_cells, 8)):
				return {"passed": false, "reason": "plot road anchor disconnected: %s" % plot.get("id", "<unknown>")}
	for ramp in ramps:
		var ramp_center := ramp.position + Vector2i(ramp.size.x / 2, ramp.size.y / 2)
		if not is_in_bounds(_nearest_road_cell(ramp_center, road_cells, 4)):
			return {"passed": false, "reason": "ramp disconnected at %s" % ramp_center}
	for landmark in landmarks:
		if not bool(landmark.get("road_interest", false)):
			continue
		var anchor: Vector2i = landmark.get("road_anchor", landmark.get("center", Vector2i(-1, -1)))
		if not is_in_bounds(_nearest_road_cell(anchor, road_cells, 8)):
			return {"passed": false, "reason": "landmark road disconnected: %s" % landmark.get("id", "<unknown>")}
	return {"passed": true, "reason": "ok"}

func _carve_frontier_arterial_roads() -> void:
	for spine in FRONTIER_ROAD_SPINES:
		_carve_frontier_straight_road_segment(Vector2i(4, int(spine)), Vector2i(MAP_W - 5, int(spine)))
		_carve_frontier_straight_road_segment(Vector2i(int(spine), 4), Vector2i(int(spine), MAP_H - 5))

func _carve_frontier_straight_road_segment(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var current := from_cell
	var axis := _frontier_road_axis(from_cell, to_cell)
	_carve_frontier_road_cell(current, axis, FRONTIER_MAIN_SPINE_ROAD_WIDTH)
	while current != to_cell:
		if current.x != to_cell.x:
			current.x += clampi(to_cell.x - current.x, -1, 1)
		elif current.y != to_cell.y:
			current.y += clampi(to_cell.y - current.y, -1, 1)
		_carve_frontier_road_cell(current, axis, FRONTIER_MAIN_SPINE_ROAD_WIDTH)

func _carve_frontier_arterial_path(start: Vector2i, target: Vector2i, horizontal: bool) -> void:
	var arterial := AStarGrid2D.new()
	arterial.region = Rect2i(0, 0, MAP_W, MAP_H)
	arterial.cell_size = Vector2.ONE
	arterial.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	arterial.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	arterial.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	arterial.update()
	for x in MAP_W:
		for y in MAP_H:
			var cell := Vector2i(x, y)
			var solid := cell.x <= 2 or cell.x >= MAP_W - 3 or cell.y <= 2 or cell.y >= MAP_H - 3
			solid = solid or _is_frontier_plot_reserved_for_arterial(cell)
			arterial.set_point_solid(cell, solid)
			if not solid:
				var line_distance: int = abs(cell.y - FRONTIER_MAIN_ROAD_Y) if horizontal else abs(cell.x - FRONTIER_MAIN_ROAD_X)
				arterial.set_point_weight_scale(cell, 1.0 + float(line_distance) * 0.12)
	start = _nearest_frontier_arterial_cell(start, arterial)
	target = _nearest_frontier_arterial_cell(target, arterial)
	if not arterial.is_in_boundsv(start) or not arterial.is_in_boundsv(target) or arterial.is_point_solid(start) or arterial.is_point_solid(target):
		return
	var previous := start
	var path := arterial.get_id_path(start, target)
	for i in range(path.size()):
		var cell: Vector2i = path[i]
		var next: Vector2i = path[min(i + 1, path.size() - 1)]
		var axis := _frontier_road_axis(previous, next)
		_carve_frontier_road_cell(cell, axis, FRONTIER_MAIN_SPINE_ROAD_WIDTH)
		previous = cell

func _nearest_frontier_arterial_cell(origin: Vector2i, arterial: AStarGrid2D) -> Vector2i:
	if arterial.is_in_boundsv(origin) and not arterial.is_point_solid(origin):
		return origin
	for radius in range(1, 12):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if arterial.is_in_boundsv(cell) and not arterial.is_point_solid(cell):
					return cell
	return origin

func _is_frontier_plot_reserved_for_arterial(cell: Vector2i) -> bool:
	for plot in plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if _expanded_rect(rect, 1).has_point(cell):
			return true
		for ramp_rect in _plot_ramp_rects(plot):
			if _expanded_rect(ramp_rect, 1).has_point(cell):
				return true
	return false

func _frontier_spine_target_for_anchor(anchor: Vector2i) -> Vector2i:
	var nearest_horizontal_y := _nearest_frontier_spine(anchor.y)
	var nearest_vertical_x := _nearest_frontier_spine(anchor.x)
	var horizontal_target := Vector2i(anchor.x, nearest_horizontal_y)
	var vertical_target := Vector2i(nearest_vertical_x, anchor.y)
	if abs(anchor.y - nearest_horizontal_y) <= abs(anchor.x - nearest_vertical_x):
		return nearest_walkable_cell(horizontal_target, 8)
	return nearest_walkable_cell(vertical_target, 8)

func _nearest_frontier_spine(value: int) -> int:
	var best := int(FRONTIER_ROAD_SPINES[0])
	var best_distance: int = abs(value - best)
	for spine in FRONTIER_ROAD_SPINES:
		var spine_value := int(spine)
		var distance: int = abs(value - spine_value)
		if distance < best_distance:
			best = spine_value
			best_distance = distance
	return best

func _carve_frontier_road(from_cell: Vector2i, to_cell: Vector2i, road_width: int = FRONTIER_MAIN_SPINE_ROAD_WIDTH) -> void:
	var routed_path := _find_frontier_road_path(from_cell, to_cell)
	if routed_path.size() >= 2:
		for i in range(routed_path.size()):
			var previous: Vector2i = routed_path[maxi(0, i - 1)]
			var current: Vector2i = routed_path[i]
			var next: Vector2i = routed_path[mini(routed_path.size() - 1, i + 1)]
			var axis := _frontier_road_axis(previous, next)
			_carve_frontier_road_cell(current, axis, road_width)
		return
	var bend_x_first := Vector2i(to_cell.x, from_cell.y)
	var bend_y_first := Vector2i(from_cell.x, to_cell.y)
	var score_x := _frontier_road_route_conflict_score(from_cell, bend_x_first) + _frontier_road_route_conflict_score(bend_x_first, to_cell)
	var score_y := _frontier_road_route_conflict_score(from_cell, bend_y_first) + _frontier_road_route_conflict_score(bend_y_first, to_cell)
	var bend := bend_x_first if score_x <= score_y else bend_y_first
	_carve_frontier_road_segment(from_cell, bend, road_width)
	_carve_frontier_road_segment(bend, to_cell, road_width)

func _find_frontier_road_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var start := _nearest_frontier_road_allowed_cell(from_cell, 8)
	var target := _nearest_frontier_road_allowed_cell(to_cell, 12)
	var path: Array[Vector2i] = []
	if not is_in_bounds(start) or not is_in_bounds(target):
		return path
	var router := AStarGrid2D.new()
	router.region = Rect2i(0, 0, MAP_W, MAP_H)
	router.cell_size = Vector2.ONE
	router.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	router.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	router.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	router.update()
	for x in MAP_W:
		for y in MAP_H:
			var cell := Vector2i(x, y)
			router.set_point_solid(cell, not _frontier_road_path_allows_cell(cell))
	if router.is_point_solid(start) or router.is_point_solid(target):
		return path
	var raw_path := router.get_id_path(start, target)
	for value in raw_path:
		path.append(value)
	return path

func _nearest_frontier_road_allowed_cell(origin: Vector2i, max_radius: int) -> Vector2i:
	if is_in_bounds(origin) and _frontier_road_path_allows_cell(origin):
		return origin
	for radius in range(1, max_radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if is_in_bounds(cell) and _frontier_road_path_allows_cell(cell):
					return cell
	return Vector2i(-1, -1)

func _frontier_road_path_allows_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell) or _is_frontier_plot_reserved_for_roads(cell):
		return false
	var feature: String = feature_grid[cell.x][cell.y]
	if feature.ends_with("_wall") or feature == "giant_mushroom":
		return false
	var elevation: int = grid[cell.x][cell.y]
	if elevation == E_BLOCKED or elevation == E_WATER:
		return false
	if elevation == E_HIGH and feature != "ramp" and not _is_near_ramp_cell(cell, 1):
		return false
	return true

func _frontier_road_route_conflict_score(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var current := from_cell
	var score := 0
	while current != to_cell:
		if current.x != to_cell.x:
			current.x += clampi(to_cell.x - current.x, -1, 1)
		elif current.y != to_cell.y:
			current.y += clampi(to_cell.y - current.y, -1, 1)
		if _is_frontier_plot_reserved_for_roads(current):
			score += 1000
		elif not is_in_bounds(current):
			score += 500
		elif grid[current.x][current.y] == E_BLOCKED or grid[current.x][current.y] == E_WATER:
			score += 8
	return score

func _carve_frontier_plot_approach(plot: Dictionary) -> void:
	var rect: Rect2i = plot.get("rect", Rect2i())
	if str(plot.get("kind", "")) != "base" and not plot.has("road_anchor"):
		plot["road_anchor"] = Vector2i(rect.position.x + rect.size.x / 2, rect.end.y)
	var road_anchor: Vector2i = plot.get("road_anchor", plot.get("anchor", rect.position))
	if str(plot.get("kind", "")) == "base":
		var approach_width := int(plot.get("ramp_width", FRONTIER_PLOT_APPROACH_ROAD_WIDTH))
		var ramp_rects: Array = plot.get("ramp_rects", [])
		for ramp_rect_value in ramp_rects:
			var ramp_rect: Rect2i = ramp_rect_value
			var ramp_axis := Vector2i(1, 0) if ramp_rect.size.x >= ramp_rect.size.y else Vector2i(0, 1)
			for x in range(ramp_rect.position.x - 1, ramp_rect.end.x + 1):
				for y in range(ramp_rect.position.y - 1, ramp_rect.end.y + 1):
					var cell := Vector2i(x, y)
					if not is_in_bounds(cell):
						continue
					if ramp_rect.has_point(cell):
						grid[x][y] = E_RAMP
						feature_grid[x][y] = "ramp"
					else:
						_carve_frontier_road_cell(cell, ramp_axis, approach_width)
		if ramp_rects.is_empty():
			for anchor in _plot_road_anchors(plot):
				var axis := _frontier_road_axis(plot.get("anchor", anchor), anchor)
				_carve_frontier_road_cell(anchor, axis, approach_width)
		return
	var entrance := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1)
	for y in range(entrance.y + 1, entrance.y + 5):
		for x in range(entrance.x - 1, entrance.x + 2):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			if not rect.has_point(cell):
				var width := FRONTIER_MAIN_SPINE_ROAD_WIDTH if y == entrance.y + 1 else FRONTIER_PLOT_APPROACH_ROAD_WIDTH
				_carve_frontier_road_cell(cell, Vector2i(0, 1), width)

func _carve_frontier_road_segment(from_cell: Vector2i, to_cell: Vector2i, road_width: int = FRONTIER_MAIN_SPINE_ROAD_WIDTH) -> void:
	var current := from_cell
	var axis := _frontier_road_axis(current, to_cell)
	_carve_frontier_road_cell(current, axis, road_width)
	while current != to_cell:
		if current.x != to_cell.x:
			current.x += clampi(to_cell.x - current.x, -1, 1)
		elif current.y != to_cell.y:
			current.y += clampi(to_cell.y - current.y, -1, 1)
		_carve_frontier_road_cell(current, axis, road_width)

func _frontier_road_axis(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	if abs(to_cell.x - from_cell.x) >= abs(to_cell.y - from_cell.y):
		return Vector2i(1, 0)
	return Vector2i(0, 1)

func _carve_frontier_road_cell(center: Vector2i, axis: Vector2i, road_width: int = FRONTIER_MAIN_SPINE_ROAD_WIDTH) -> void:
	var offsets := _frontier_road_offsets(center, axis, road_width)
	for offset in offsets:
		_carve_frontier_single_road_cell(center + offset)

func _frontier_road_offsets(center: Vector2i, axis: Vector2i, road_width: int) -> Array[Vector2i]:
	var width: int = clampi(road_width, 1, FRONTIER_MAIN_SPINE_ROAD_WIDTH)
	var perpendicular := Vector2i.ZERO
	if axis == Vector2i(1, 0):
		perpendicular = Vector2i(0, 1)
	elif axis == Vector2i(0, 1):
		perpendicular = Vector2i(1, 0)
	if perpendicular == Vector2i.ZERO:
		return [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	if width <= 1:
		return [Vector2i.ZERO]
	if width == 2:
		var side := 1 if _hash_cell(center, 607) % 2 == 0 else -1
		return [Vector2i.ZERO, perpendicular * side]
	return [perpendicular * -1, Vector2i.ZERO, perpendicular]

func _carve_frontier_single_road_cell(cell: Vector2i) -> void:
	if not is_in_bounds(cell):
		return
	if _is_frontier_plot_reserved_for_roads(cell):
		return
	var existing_feature: String = feature_grid[cell.x][cell.y]
	if existing_feature.ends_with("_wall") or existing_feature == "giant_mushroom":
		return
	if grid[cell.x][cell.y] == E_HIGH and existing_feature != "ramp" and not _is_near_ramp_cell(cell, 1):
		return
	if grid[cell.x][cell.y] == E_BLOCKED or grid[cell.x][cell.y] == E_WATER:
		grid[cell.x][cell.y] = _dominant_elevation_near(cell)
	feature_grid[cell.x][cell.y] = "path"
	road_cells[cell] = true

func _is_frontier_plot_reserved_for_roads(cell: Vector2i) -> bool:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return false
	for plot in plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if not rect.has_point(cell):
			continue
		for ramp_rect in _plot_ramp_rects(plot):
			if ramp_rect.has_point(cell):
				return false
		return true
	return false

func _carve_road_between(from_cell: Vector2i, to_cell: Vector2i, width: int) -> void:
	var current := Vector2(from_cell.x, from_cell.y)
	var target := Vector2(to_cell.x, to_cell.y)
	var steps: int = maxi(1, int(current.distance_to(target)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var sway := sin(t * TAU * 1.5 + float(seed_value % 97)) * 2.4
		var p := current.lerp(target, t)
		var cell := Vector2i(roundi(p.x + sway), roundi(p.y))
		_carve_road_cell(cell, width)

func _carve_road_cell(center: Vector2i, width: int) -> void:
	for x in range(center.x - width, center.x + width + 1):
		for y in range(center.y - width, center.y + width + 1):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			var existing_feature: String = feature_grid[x][y]
			if existing_feature.ends_with("_wall") or existing_feature == "giant_mushroom":
				continue
			if grid[x][y] == E_BLOCKED or grid[x][y] == E_WATER:
				if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER and not _is_near_ramp_cell(cell, 2):
					continue
				grid[x][y] = _dominant_elevation_near(cell)
			feature_grid[x][y] = "path"
			road_cells[cell] = true

func _smooth_roads_with_validation() -> void:
	if road_cells.is_empty():
		return
	var original_roads := road_cells.duplicate()
	var original_count := original_roads.size()
	var protected_cells := _required_road_cells()
	var candidate_roads := _copy_cell_dictionary(road_cells)
	if frontier_road_layout_mode != ROAD_MODE_ORGANIC_SPINE_AND_BRANCHES or bool(_frontier_road_debug.get("fallback", false)):
		_round_road_corners(candidate_roads, protected_cells)
	_trim_road_protrusions(candidate_roads, protected_cells)
	if not _validate_road_smoothing(candidate_roads, protected_cells):
		_restore_road_cells(original_roads)
		push_warning("[MapGenerator] Road smoothing failed validation. Reverted to original road grid.")
		print("[MapGenerator] Road smoothing original=", original_count, " smoothed=", original_count, " added=0 removed=0 validation=false")
		if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
			_frontier_road_debug["thinning_before"] = original_count
			_frontier_road_debug["thinning_after"] = original_count
			_frontier_road_debug["thinning_validation"] = false
		return
	var smoothed_count := candidate_roads.size()
	var added := 0
	var removed := 0
	for cell in candidate_roads.keys():
		if not original_roads.has(cell):
			added += 1
	for cell in original_roads.keys():
		if not candidate_roads.has(cell):
			removed += 1
	_restore_road_cells(candidate_roads)
	print("[MapGenerator] Road smoothing original=", original_count, " smoothed=", smoothed_count, " added=", added, " removed=", removed, " validation=true")
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		_frontier_road_debug["thinning_before"] = original_count
		_frontier_road_debug["thinning_after"] = smoothed_count
		_frontier_road_debug["thinning_validation"] = true
		_frontier_road_debug["junction_count"] = _frontier_junction_count()

func _copy_cell_dictionary(source: Dictionary) -> Dictionary:
	var copy := {}
	for cell in source.keys():
		copy[cell] = true
	return copy

func _required_road_cells() -> Dictionary:
	var required := {}
	for plot in plots:
		var anchor: Vector2i = plot.get("road_anchor", plot.get("anchor", Vector2i(-1, -1)))
		if is_in_bounds(anchor):
			var road_cell := _nearest_road_cell(anchor, road_cells, 10)
			if is_in_bounds(road_cell):
				required[road_cell] = true
		for ramp_rect in _plot_ramp_rects(plot):
			var ramp_center := ramp_rect.position + Vector2i(ramp_rect.size.x / 2, ramp_rect.size.y / 2)
			var ramp_road := _nearest_road_cell(ramp_center, road_cells, 5)
			if is_in_bounds(ramp_road):
				required[ramp_road] = true
	if frontier_road_layout_mode != ROAD_MODE_ORGANIC_SPINE_AND_BRANCHES or bool(_frontier_road_debug.get("fallback", false)):
		for spine in FRONTIER_ROAD_SPINES:
			for edge_anchor in [Vector2i(4, int(spine)), Vector2i(MAP_W - 5, int(spine)), Vector2i(int(spine), 4), Vector2i(int(spine), MAP_H - 5)]:
				var road_edge := _nearest_road_cell(edge_anchor, road_cells, 4)
				if is_in_bounds(road_edge):
					required[road_edge] = true
	return required

func _nearest_road_cell(origin: Vector2i, roads: Dictionary, max_radius: int) -> Vector2i:
	if roads.has(origin):
		return origin
	for radius in range(1, max_radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				if abs(x - origin.x) != radius and abs(y - origin.y) != radius:
					continue
				var cell := Vector2i(x, y)
				if roads.has(cell):
					return cell
	return Vector2i(-1, -1)

func _round_road_corners(roads: Dictionary, protected_cells: Dictionary) -> void:
	var additions := {}
	for cell in roads.keys():
		for corner in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var side_a: Vector2i = cell + Vector2i(corner.x, 0)
			var side_b: Vector2i = cell + Vector2i(0, corner.y)
			var diagonal: Vector2i = cell + corner
			if roads.has(side_a) and roads.has(side_b) and not roads.has(diagonal) and _can_be_road_cell(diagonal):
				additions[diagonal] = true
	for cell in additions.keys():
		roads[cell] = true

func _trim_road_protrusions(roads: Dictionary, protected_cells: Dictionary) -> void:
	var removals := {}
	for cell in roads.keys():
		if protected_cells.has(cell):
			continue
		if not _can_trim_road_cell(cell):
			continue
		var cardinal_count := _road_cardinal_neighbor_count(cell, roads)
		var all_count := _road_neighbor_count(cell, roads)
		if cardinal_count <= 1 and all_count <= 3:
			removals[cell] = true
		elif cardinal_count == 2 and all_count <= 2 and _is_road_outside_corner(cell, roads):
			removals[cell] = true
	for cell in removals.keys():
		roads.erase(cell)

func _can_be_road_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell) or _is_frontier_plot_reserved_for_roads(cell):
		return false
	var existing_feature: String = feature_grid[cell.x][cell.y]
	if existing_feature.ends_with("_wall") or existing_feature == "giant_mushroom":
		return false
	if grid[cell.x][cell.y] == E_HIGH and existing_feature != "ramp" and not _is_near_ramp_cell(cell, 1):
		return false
	return grid[cell.x][cell.y] != E_WATER and grid[cell.x][cell.y] != E_BLOCKED

func _can_trim_road_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	for plot in plots:
		for ramp_rect in _plot_ramp_rects(plot):
			if _expanded_rect(ramp_rect, 1).has_point(cell):
				return false
		for anchor in _plot_road_anchors(plot):
			var delta := cell - anchor
			if is_in_bounds(anchor) and delta.x * delta.x + delta.y * delta.y <= 4:
				return false
	return true

func _is_road_outside_corner(cell: Vector2i, roads: Dictionary) -> bool:
	var east := roads.has(cell + Vector2i.RIGHT)
	var west := roads.has(cell + Vector2i.LEFT)
	var south := roads.has(cell + Vector2i.DOWN)
	var north := roads.has(cell + Vector2i.UP)
	var missing_south_east := east and south and not roads.has(cell + Vector2i(1, 1))
	var missing_north_east := east and north and not roads.has(cell + Vector2i(1, -1))
	var missing_south_west := west and south and not roads.has(cell + Vector2i(-1, 1))
	var missing_north_west := west and north and not roads.has(cell + Vector2i(-1, -1))
	return missing_south_east or missing_north_east or missing_south_west or missing_north_west

func _road_cardinal_neighbor_count(cell: Vector2i, roads: Dictionary) -> int:
	var count := 0
	for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if roads.has(cell + offset):
			count += 1
	return count

func _road_neighbor_count(cell: Vector2i, roads: Dictionary) -> int:
	var count := 0
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			if roads.has(cell + Vector2i(x, y)):
				count += 1
	return count

func _frontier_junction_count() -> int:
	var junction_cells := {}
	for cell_value in road_cells.keys():
		var cell: Vector2i = cell_value
		if _road_cardinal_neighbor_count(cell, road_cells) >= 3:
			junction_cells[cell] = true
	var visited := {}
	var count := 0
	for cell_value in junction_cells.keys():
		var cell: Vector2i = cell_value
		if visited.has(cell):
			continue
		count += 1
		var queue: Array[Vector2i] = [cell]
		visited[cell] = true
		var index := 0
		while index < queue.size():
			var current: Vector2i = queue[index]
			index += 1
			for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var next_cell: Vector2i = current + offset
				if junction_cells.has(next_cell) and not visited.has(next_cell):
					visited[next_cell] = true
					queue.append(next_cell)
	return count

func _validate_road_smoothing(candidate_roads: Dictionary, protected_cells: Dictionary) -> bool:
	if candidate_roads.is_empty():
		print("[MapGenerator] Road smoothing validation failed: no roads remain.")
		return false
	var required: Array[Vector2i] = []
	for cell in protected_cells.keys():
		var road_cell := _nearest_road_cell(cell, candidate_roads, 4)
		if not is_in_bounds(road_cell) or not _road_anchor_is_walkable(road_cell):
			print("[MapGenerator] Road smoothing validation failed: required road anchor not walkable near ", cell)
			return false
		required.append(road_cell)
	if required.is_empty():
		print("[MapGenerator] Road smoothing validation failed: no required anchors.")
		return false
	var reachable_roads := _flood_road_cells(required[0], candidate_roads)
	for road_cell in required:
		if not reachable_roads.has(road_cell):
			continue
	var start := _road_validation_start_cell(required[0])
	var reachable_walkable := _flood_walkable_cells(start)
	for plot in plots:
		var anchor: Vector2i = plot.get("anchor", plot.get("road_anchor", Vector2i(-1, -1)))
		anchor = nearest_walkable_cell(anchor, 8)
		if not is_in_bounds(anchor) or not reachable_walkable.has(anchor):
			print("[MapGenerator] Road smoothing validation failed: plot anchor unreachable ", plot.get("id", "<unknown>"), " at ", anchor)
			return false
	return true

func _validate_frontier_elevation_layout(verbose: bool = false) -> bool:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return true
	var errors: Array[String] = []
	var high_zones := _collect_elevation_zones(E_HIGH)
	for zone in high_zones:
		if not _high_zone_has_ramp(zone):
			errors.append("HIGH zone without ramp, size=%s" % zone.size())
	var start := _road_validation_start_cell(Vector2i(FRONTIER_MAIN_ROAD_X, FRONTIER_MAIN_ROAD_Y))
	var reachable_walkable := _flood_walkable_cells(start)
	for plot in plots:
		var anchor: Vector2i = plot.get("anchor", plot.get("road_anchor", Vector2i(-1, -1)))
		anchor = nearest_walkable_cell(anchor, 8)
		if not is_in_bounds(anchor) or not reachable_walkable.has(anchor):
			errors.append("plot unreachable: %s at %s" % [plot.get("id", "<unknown>"), anchor])
		if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH and _plot_ramp_rects(plot).is_empty():
			errors.append("HIGH plot missing ramp: %s" % plot.get("id", "<unknown>"))
		for road_anchor in _plot_road_anchors(plot):
			var nearest_road := _nearest_road_cell(road_anchor, road_cells, 6)
			if not is_in_bounds(nearest_road):
				errors.append("plot road not connected: %s at %s" % [plot.get("id", "<unknown>"), road_anchor])
		if str(plot.get("kind", "")) == "base":
			var target_count := int(plot.get("target_ramp_count", 0))
			var actual_count := _base_access_count(plot)
			plot["validated_ramp_count"] = actual_count
			if target_count > 0 and actual_count < target_count:
				errors.append("base %s entrances below target: %s/%s" % [plot.get("id", "<unknown>"), actual_count, target_count])
	for ramp in ramps:
		var ramp_center := ramp.position + Vector2i(ramp.size.x / 2, ramp.size.y / 2)
		var road_near_ramp := _nearest_road_cell(ramp_center, road_cells, 3)
		if not is_in_bounds(road_near_ramp):
			errors.append("ramp not reachable from road at %s" % ramp_center)
	var passed := errors.is_empty()
	if verbose:
		if passed:
			print("[MapGenerator] Elevation validation passed.")
		else:
			for error in errors:
				push_warning("[MapGenerator] Elevation validation failed: " + error)
	return passed

func _validate_frontier_landmarks(verbose: bool = false) -> bool:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return true
	var errors: Array[String] = []
	var start := _road_validation_start_cell(Vector2i(FRONTIER_MAIN_ROAD_X, FRONTIER_MAIN_ROAD_Y))
	var reachable_walkable := _flood_walkable_cells(start)
	for landmark in landmarks:
		var center: Vector2i = landmark.get("center", Vector2i(-1, -1))
		var rect: Rect2i = landmark.get("rect", Rect2i())
		if not is_in_bounds(center):
			errors.append("%s center out of bounds" % landmark.get("id", "<unknown>"))
		for plot in plots:
			var plot_rect: Rect2i = plot.get("rect", Rect2i())
			if rect.size != Vector2i.ZERO and plot_rect.size != Vector2i.ZERO and rect.intersects(plot_rect):
				errors.append("%s overlaps plot %s" % [landmark.get("id", "<unknown>"), plot.get("id", "<unknown>")])
			for ramp_rect in _plot_ramp_rects(plot):
				if rect.size != Vector2i.ZERO and rect.intersects(ramp_rect):
					errors.append("%s overlaps plot ramp %s" % [landmark.get("id", "<unknown>"), plot.get("id", "<unknown>")])
		var anchor: Vector2i = landmark.get("road_anchor", center)
		var reachable_anchor := nearest_walkable_cell(anchor, 10)
		if bool(landmark.get("road_interest", false)):
			var nearest_road := _nearest_road_cell(reachable_anchor, road_cells, 8)
			if not is_in_bounds(nearest_road):
				errors.append("%s has no nearby road" % landmark.get("id", "<unknown>"))
		if is_in_bounds(reachable_anchor) and not reachable_walkable.has(reachable_anchor):
			errors.append("%s anchor unreachable at %s" % [landmark.get("id", "<unknown>"), reachable_anchor])
		landmark["validation"] = "ok"
	var passed := errors.is_empty()
	if not passed:
		for landmark in landmarks:
			landmark["validation"] = "check_warnings"
	if verbose:
		if passed:
			print("[MapGenerator] Landmark validation passed. count=", landmarks.size())
		else:
			for error in errors:
				push_warning("[MapGenerator] Landmark validation failed: " + error)
	return passed

func _validate_content_structures(verbose: bool = false) -> bool:
	var errors: Array[String] = []
	var generator = ContentStructureGeneratorScript.new()
	for plot in plots:
		if not bool(plot.get("has_interior", false)):
			continue
		var structure: Dictionary = plot.get("content_structure", {})
		var validation: Dictionary = generator.validate_structure(structure)
		structure["validation"] = validation
		plot["content_structure"] = structure
		var entrance_cells: Array = plot.get("entrance_cells", [])
		if entrance_cells.is_empty():
			errors.append("%s missing entrance cells" % plot.get("id", "<unknown>"))
		else:
			var entrance: Vector2i = entrance_cells[0]
			if not is_walkable_cell(entrance):
				errors.append("%s entrance not walkable on exterior map: %s" % [plot.get("id", "<unknown>"), entrance])
			var road_near := _nearest_road_cell(entrance, road_cells, 6)
			if not is_in_bounds(road_near):
				errors.append("%s entrance has no road access: %s" % [plot.get("id", "<unknown>"), entrance])
		if not bool(validation.get("passed", false)):
			errors.append("%s interior invalid: %s" % [plot.get("id", "<unknown>"), validation.get("errors", [])])
		var floors: Array = structure.get("floors", [])
		var stair_links: Array = structure.get("stair_links", [])
		if floors.size() > 0 and stair_links.size() < maxi(0, floors.size() - 1):
			errors.append("%s floor chain not fully connected" % plot.get("id", "<unknown>"))
		if verbose:
			print("[MapGenerator] Content structure validation id=", structure.get("id", "?"),
				" type=", structure.get("structure_type", "?"),
				" floors=", floors.size(),
				" walkable_counts=", validation.get("walkable_counts", []),
				" stairs=", validation.get("stair_count", 0),
				" passed=", validation.get("passed", false))
	var passed := errors.is_empty()
	if verbose and not passed:
		for error in errors:
			push_warning("[MapGenerator] Content structure validation failed: " + error)
	return passed

func _validate_frontier_plateau_generation(verbose: bool = false) -> bool:
	var errors: Array[String] = []
	for plot in plots:
		if str(plot.get("elevation", ELEVATION_LOW)) != ELEVATION_HIGH:
			continue
		if str(plot.get("kind", "")) != "base":
			continue
		var plateau_id := int(plot.get("plateau_id", -1))
		var plateau_cells := _plateau_cells_for_plot(plot)
		if plateau_id < 0 or plateau_cells.is_empty():
			errors.append("HIGH plot has no plateau: %s" % plot.get("id", "<unknown>"))
			continue
		if _plot_ramp_rects(plot).is_empty():
			errors.append("HIGH plot has no ramp: %s" % plot.get("id", "<unknown>"))
	for plateau in _frontier_plateaus:
		var plateau_cells: Array = plateau.get("cells", [])
		if plateau_cells.size() < 24:
			errors.append("plateau too small: %s size=%s" % [plateau.get("id", "<unknown>"), plateau_cells.size()])
	var passed := errors.is_empty()
	if verbose:
		if passed:
			print("[MapGenerator] Plateau generation validation passed.")
		else:
			for error in errors:
				push_warning("[MapGenerator] Plateau generation validation failed: " + error)
	return passed

func _base_access_count(plot: Dictionary) -> int:
	var count := 0
	var ramp_rects := _plot_ramp_rects(plot)
	if not ramp_rects.is_empty():
		for ramp_rect in ramp_rects:
			var ramp_center := ramp_rect.position + Vector2i(ramp_rect.size.x / 2, ramp_rect.size.y / 2)
			if is_in_bounds(_nearest_road_cell(ramp_center, road_cells, 5)):
				count += 1
		return count
	for anchor in _plot_road_anchors(plot):
		if is_in_bounds(_nearest_road_cell(anchor, road_cells, 5)):
			count += 1
	return count

func _flatten_tiny_high_fragments() -> void:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return
	var zones := _collect_elevation_zones(E_HIGH)
	for zone in zones:
		if zone.size() >= 8 or _high_zone_has_ramp(zone):
			continue
		for cell_value in zone:
			var cell: Vector2i = cell_value
			if is_in_bounds(cell) and not _is_cell_inside_plot_or_ramp(cell):
				grid[cell.x][cell.y] = E_LOW
				feature_grid[cell.x][cell.y] = "frontier_canvas"

func _is_cell_inside_plot_or_ramp(cell: Vector2i) -> bool:
	for plot in plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.has_point(cell):
			return true
		for ramp_rect in _plot_ramp_rects(plot):
			if ramp_rect.has_point(cell):
				return true
	for ramp in ramps:
		if ramp.has_point(cell):
			return true
	return false

func _collect_elevation_zones(elevation: int) -> Array[Array]:
	var zones: Array[Array] = []
	var visited := {}
	for x in MAP_W:
		for y in MAP_H:
			var cell := Vector2i(x, y)
			if visited.has(cell) or grid[x][y] != elevation:
				continue
			var zone: Array[Vector2i] = []
			var queue: Array[Vector2i] = [cell]
			visited[cell] = true
			var index := 0
			while index < queue.size():
				var current: Vector2i = queue[index]
				index += 1
				zone.append(current)
				for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var next_cell: Vector2i = current + offset
					if not is_in_bounds(next_cell) or visited.has(next_cell):
						continue
					if grid[next_cell.x][next_cell.y] != elevation:
						continue
					visited[next_cell] = true
					queue.append(next_cell)
			zones.append(zone)
	return zones

func _high_zone_has_ramp(zone: Array) -> bool:
	for cell_value in zone:
		var cell: Vector2i = cell_value
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var nearby := cell + Vector2i(dx, dy)
				if is_in_bounds(nearby) and grid[nearby.x][nearby.y] == E_RAMP:
					return true
	return false

func _road_anchor_is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and grid[cell.x][cell.y] != E_WATER and grid[cell.x][cell.y] != E_BLOCKED

func _road_validation_start_cell(fallback: Vector2i) -> Vector2i:
	for plot in plots:
		var anchor: Vector2i = plot.get("anchor", fallback)
		anchor = nearest_walkable_cell(anchor, 8)
		if is_in_bounds(anchor):
			return anchor
	return fallback

func _flood_road_cells(start: Vector2i, roads: Dictionary) -> Dictionary:
	var visited := {}
	if not roads.has(start):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next_cell: Vector2i = cell + offset
			if roads.has(next_cell) and not visited.has(next_cell):
				visited[next_cell] = true
				queue.append(next_cell)
	return visited

func _flood_walkable_cells(start: Vector2i) -> Dictionary:
	var visited := {}
	if not is_walkable_cell(start):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next_cell: Vector2i = cell + offset
			if is_walkable_cell(next_cell) and not visited.has(next_cell):
				visited[next_cell] = true
				queue.append(next_cell)
	return visited

func _restore_road_cells(new_roads: Dictionary) -> void:
	for cell in road_cells.keys():
		if is_in_bounds(cell) and feature_grid[cell.x][cell.y] == "path":
			feature_grid[cell.x][cell.y] = ""
	road_cells = _copy_cell_dictionary(new_roads)
	for cell in road_cells.keys():
		if not is_in_bounds(cell):
			continue
		if grid[cell.x][cell.y] == E_WATER or grid[cell.x][cell.y] == E_BLOCKED:
			grid[cell.x][cell.y] = _dominant_elevation_near(cell)
		feature_grid[cell.x][cell.y] = "path"

func _build_landmarks() -> void:
	landmarks.clear()
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		_build_frontier_landmarks()
		_build_frontier_blockers()
		return
	if _uses_square_grid_map():
		return
	var attempts := 0
	while landmarks.size() < 18 and attempts < 280:
		attempts += 1
		var cell := Vector2i(_rng.range_int(6, MAP_W - 7), _rng.range_int(6, MAP_H - 7))
		if not is_in_bounds(cell) or grid[cell.x][cell.y] == E_WATER:
			continue
		if feature_grid[cell.x][cell.y] != "" and feature_grid[cell.x][cell.y] != "path":
			continue
		var radius := _rng.range_int(2, 4)
		landmarks.append({
			"kind": "giant_mushroom",
			"cell": cell,
			"radius": radius,
			"height": _rng.range_int(2, 4),
		})
		for x in range(cell.x - 1, cell.x + 2):
			for y in range(cell.y - 1, cell.y + 2):
				var stem := Vector2i(x, y)
				if is_in_bounds(stem) and feature_grid[x][y] == "":
					grid[x][y] = E_BLOCKED
					feature_grid[x][y] = "giant_mushroom"

func _frontier_landmark_archetypes() -> Array[Dictionary]:
	return [
		{"kind": LANDMARK_GIANT_CORRUPTED_TREE, "label": "Giant Corrupted Tree", "rarity": "major", "scale_class": "huge", "weight": 10, "radius": Vector2i(8, 7), "road_interest": true, "blocker_density": 0.82, "chokepoint_score": 0.8, "road_behavior": "toward_and_around", "navigation_role": "dominant central silhouette with root chokes"},
		{"kind": LANDMARK_ELEVATED_SHRINE_PLATEAU, "label": "Elevated Shrine Plateau", "rarity": "major", "scale_class": "large", "weight": 9, "radius": Vector2i(7, 6), "road_interest": true, "blocker_density": 0.36, "chokepoint_score": 0.9, "road_behavior": "toward_ramp", "navigation_role": "high-ground shrine plateau with a readable ramp choke"},
		{"kind": LANDMARK_DEAD_ROOT_CANYON, "label": "Dead Root Canyon", "rarity": "secondary", "scale_class": "large", "weight": 15, "radius": Vector2i(10, 5), "road_interest": true, "blocker_density": 0.72, "chokepoint_score": 0.75, "road_behavior": "through_gap_or_around", "navigation_role": "parallel root walls forming canyon lanes"},
		{"kind": LANDMARK_MUSHROOM_RITUAL_BASIN, "label": "Mushroom Ritual Basin", "rarity": "secondary", "scale_class": "large", "weight": 15, "radius": Vector2i(7, 6), "road_interest": true, "blocker_density": 0.34, "chokepoint_score": 0.45, "road_behavior": "toward_edge", "navigation_role": "glowing basin clearing with ring blockers"},
		{"kind": LANDMARK_CLIFF_RIDGE_BARRIER, "label": "Cliff Ridge Barrier", "rarity": "secondary", "scale_class": "large", "weight": 12, "radius": Vector2i(12, 4), "road_interest": false, "blocker_density": 0.84, "chokepoint_score": 0.88, "road_behavior": "around_gap", "navigation_role": "long hard ridge barrier with narrow gap"},
		{"kind": LANDMARK_ANCIENT_RUIN_CLUSTER, "label": "Ancient Ruin Cluster", "rarity": "common", "scale_class": "medium", "weight": 17, "radius": Vector2i(7, 5), "road_interest": true, "blocker_density": 0.46, "chokepoint_score": 0.55, "road_behavior": "toward", "navigation_role": "large ruin mass beside or around a route"},
		{"kind": LANDMARK_SWAMP_DEPRESSION, "label": "Swamp Depression", "rarity": "common", "scale_class": "medium", "weight": 13, "radius": Vector2i(8, 5), "road_interest": false, "blocker_density": 0.3, "chokepoint_score": 0.65, "road_behavior": "around", "navigation_role": "dark water depression that bends traversal"},
	]

func _build_frontier_landmarks() -> void:
	var target_count := _rng.range_int(3, 4)
	var used_major := false
	var attempts := 0
	while landmarks.size() < target_count and attempts < 420:
		attempts += 1
		var archetype := _choose_frontier_landmark_archetype(used_major, landmarks.is_empty())
		var radius: Vector2i = archetype["radius"]
		var center := Vector2i(_rng.range_int(10 + radius.x, MAP_W - 11 - radius.x), _rng.range_int(10 + radius.y, MAP_H - 11 - radius.y))
		var rect := Rect2i(center - radius, radius * 2 + Vector2i.ONE)
		var clear_margin := 3
		if attempts > 160:
			clear_margin = 1
		if attempts > 260:
			clear_margin = 0
		if not _frontier_landmark_area_clear(rect, clear_margin):
			continue
		var landmark := {
			"id": "landmark_%02d" % landmarks.size(),
			"kind": archetype["kind"],
			"archetype": archetype["kind"],
			"label": archetype["label"],
			"biome": BIOME_DARK_FOREST_FRONTIER_V2,
			"biome_pool": BIOME_DARK_FOREST_FRONTIER_V2,
			"rarity": archetype["rarity"],
			"scale_class": archetype["scale_class"],
			"terrain_hierarchy": _frontier_landmark_hierarchy(archetype),
			"center": center,
			"rect": rect,
			"radius": radius,
			"road_interest": bool(archetype["road_interest"]),
			"blocker_density": float(archetype["blocker_density"]),
			"chokepoint_score": float(archetype["chokepoint_score"]),
			"road_behavior": archetype["road_behavior"],
			"navigation_role": archetype["navigation_role"],
			"footprint_cells": [],
			"blocked_cells": [],
			"water_cells": [],
			"ramp_rects": [],
			"road_anchor": center,
			"validation": "pending",
		}
		match str(archetype["kind"]):
			LANDMARK_GIANT_CORRUPTED_TREE:
				_stamp_giant_corrupted_tree_landmark(landmark)
			LANDMARK_ELEVATED_SHRINE_PLATEAU:
				_stamp_elevated_shrine_plateau_landmark(landmark)
			LANDMARK_DEAD_ROOT_CANYON, LANDMARK_DEAD_ROOT_MAZE:
				_stamp_dead_root_maze_landmark(landmark)
			LANDMARK_MUSHROOM_RITUAL_BASIN, LANDMARK_MUSHROOM_RITUAL_CIRCLE:
				_stamp_mushroom_ritual_circle_landmark(landmark)
			LANDMARK_CLIFF_RIDGE_BARRIER, LANDMARK_CLIFF_WALL_BARRIER:
				_stamp_cliff_wall_barrier_landmark(landmark)
			LANDMARK_ANCIENT_RUIN_CLUSTER, LANDMARK_BROKEN_RUIN_CLUSTER:
				_stamp_broken_ruin_cluster_landmark(landmark)
			LANDMARK_SWAMP_DEPRESSION, LANDMARK_SWAMP_BASIN:
				_stamp_swamp_basin_landmark(landmark)
		if landmark["footprint_cells"].is_empty():
			continue
		landmark["footprint_size"] = landmark["footprint_cells"].size()
		landmark["blocked_count"] = landmark["blocked_cells"].size()
		landmark["water_count"] = landmark["water_cells"].size()
		landmarks.append(landmark)
		if str(archetype["rarity"]) == "major":
			used_major = true
	print("[MapGenerator] Frontier landmarks: count=", landmarks.size(), " target=", target_count, " attempts=", attempts, " biome=", BIOME_DARK_FOREST_FRONTIER_V2)
	for landmark in landmarks:
		print("[MapGenerator] Landmark ",
			landmark.get("id", "?"),
			" kind=", landmark.get("kind", "?"),
			" rarity=", landmark.get("rarity", "?"),
			" scale=", landmark.get("scale_class", "?"),
			" hierarchy=", landmark.get("terrain_hierarchy", "?"),
			" center=", landmark.get("center", Vector2i.ZERO),
			" footprint=", landmark.get("footprint_size", 0),
			" blockers=", landmark.get("blocked_count", 0),
			" water=", landmark.get("water_count", 0),
			" road_anchor=", landmark.get("road_anchor", Vector2i.ZERO),
			" role=", landmark.get("navigation_role", ""))

func _choose_frontier_landmark_archetype(used_major: bool, force_major: bool = false) -> Dictionary:
	var choices := _frontier_landmark_archetypes()
	var total_weight := 0
	for choice in choices:
		if force_major and str(choice.get("rarity", "")) != "major":
			continue
		if used_major and str(choice.get("rarity", "")) == "major":
			continue
		total_weight += int(choice.get("weight", 1))
	var roll := _rng.range_int(1, maxi(1, total_weight))
	var cursor := 0
	for choice in choices:
		if force_major and str(choice.get("rarity", "")) != "major":
			continue
		if used_major and str(choice.get("rarity", "")) == "major":
			continue
		cursor += int(choice.get("weight", 1))
		if roll <= cursor:
			return choice
	return choices[0]

func _frontier_landmark_hierarchy(archetype: Dictionary) -> String:
	var rarity := str(archetype.get("rarity", "common"))
	if rarity == "major":
		return "primary"
	if rarity == "secondary":
		return "secondary"
	return "local"

func _frontier_landmark_area_clear(rect: Rect2i, margin: int) -> bool:
	if rect.position.x < 4 or rect.position.y < 4 or rect.end.x >= MAP_W - 4 or rect.end.y >= MAP_H - 4:
		return false
	var expanded := _expanded_rect(rect, margin)
	for existing in landmarks:
		var existing_rect: Rect2i = existing.get("rect", Rect2i())
		if existing_rect.size != Vector2i.ZERO and expanded.intersects(existing_rect):
			return false
	for x in range(expanded.position.x, expanded.end.x):
		for y in range(expanded.position.y, expanded.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell) or _is_frontier_reserved(cell, 1):
				return false
	return true

func _stamp_landmark_cell(landmark: Dictionary, cell: Vector2i, elevation: int, feature: String) -> void:
	if not is_in_bounds(cell) or _is_frontier_reserved(cell, 0):
		return
	grid[cell.x][cell.y] = elevation
	feature_grid[cell.x][cell.y] = feature
	landmark["footprint_cells"].append(cell)
	if elevation == E_BLOCKED:
		landmark["blocked_cells"].append(cell)
	elif elevation == E_WATER:
		landmark["water_cells"].append(cell)

func _stamp_giant_corrupted_tree_landmark(landmark: Dictionary) -> void:
	var center: Vector2i = landmark["center"]
	var radius: Vector2i = landmark["radius"]
	for x in range(center.x - radius.x, center.x + radius.x + 1):
		for y in range(center.y - radius.y, center.y + radius.y + 1):
			var cell := Vector2i(x, y)
			var delta := cell - center
			var dist: float = Vector2(delta).length()
			var trunk: bool = abs(delta.x) <= 2 and abs(delta.y) <= 2
			var root_arm: bool = (abs(delta.x) <= 1 or abs(delta.y) <= 1 or abs(abs(delta.x) - abs(delta.y)) <= 1) and dist <= float(radius.x)
			var crooked_root: bool = _hash_cell(cell, 601) % 100 < 28 and dist <= float(radius.x)
			if trunk or root_arm or crooked_root:
				_stamp_landmark_cell(landmark, cell, E_BLOCKED, "landmark_giant_tree")
			elif dist <= float(radius.x) and _hash_cell(cell, 603) % 100 < 12:
				_stamp_landmark_cell(landmark, cell, E_BLOCKED, "landmark_mushroom_glow")
	landmark["road_anchor"] = nearest_walkable_cell(center + Vector2i(0, radius.y + 2), 8)

func _stamp_elevated_shrine_plateau_landmark(landmark: Dictionary) -> void:
	var center: Vector2i = landmark["center"]
	var radius: Vector2i = landmark["radius"]
	var rect := Rect2i(center - Vector2i(radius.x - 1, radius.y - 1), (radius - Vector2i.ONE) * 2 + Vector2i.ONE)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			var dx := float(x - center.x) / maxf(1.0, float(radius.x))
			var dy := float(y - center.y) / maxf(1.0, float(radius.y))
			if dx * dx + dy * dy <= 0.92:
				_stamp_landmark_cell(landmark, cell, E_HIGH, "landmark_shrine_plateau")
	var map_center := Vector2i(MAP_W / 2, MAP_H / 2)
	var delta := map_center - center
	var dir := Vector2i.RIGHT
	if abs(delta.x) >= abs(delta.y):
		dir = Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	else:
		dir = Vector2i.DOWN if delta.y >= 0 else Vector2i.UP
	var edge_cell := center
	if dir == Vector2i.RIGHT:
		edge_cell = Vector2i(rect.end.x - 1, center.y)
	elif dir == Vector2i.LEFT:
		edge_cell = Vector2i(rect.position.x, center.y)
	elif dir == Vector2i.DOWN:
		edge_cell = Vector2i(center.x, rect.end.y - 1)
	else:
		edge_cell = Vector2i(center.x, rect.position.y)
	var ramp_rect := _ramp_rect_from_edge(edge_cell, dir, 2)
	landmark["ramp_rects"].append(ramp_rect)
	if not ramps.has(ramp_rect):
		ramps.append(ramp_rect)
	for x in range(ramp_rect.position.x, ramp_rect.end.x):
		for y in range(ramp_rect.position.y, ramp_rect.end.y):
			_stamp_landmark_cell(landmark, Vector2i(x, y), E_RAMP, "ramp")
	landmark["road_anchor"] = nearest_walkable_cell(edge_cell + dir * 4, 8)

func _stamp_dead_root_maze_landmark(landmark: Dictionary) -> void:
	var center: Vector2i = landmark["center"]
	var radius: Vector2i = landmark["radius"]
	var horizontal: bool = _hash_cell(center, 607) % 2 == 0
	landmark["orientation"] = "horizontal" if horizontal else "vertical"
	var gap_offset: int = _rng.range_int(-2, 2)
	for x in range(center.x - radius.x, center.x + radius.x + 1):
		for y in range(center.y - radius.y, center.y + radius.y + 1):
			var cell := Vector2i(x, y)
			var along: int = x - center.x if horizontal else y - center.y
			var across: int = y - center.y if horizontal else x - center.x
			var in_canyon: bool = abs(along) <= radius.x and abs(across) <= radius.y
			var lane_gap: bool = abs(across - gap_offset) <= 1 or abs(along) <= 1
			var canyon_wall: bool = abs(across) >= radius.y - 1 and abs(along) <= radius.x
			var root_wall: bool = in_canyon and not lane_gap and (canyon_wall or abs(across) == 3 or _hash_cell(cell, 607) % 100 < 18)
			if root_wall:
				_stamp_landmark_cell(landmark, cell, E_BLOCKED, "landmark_root_wall")
	landmark["road_anchor"] = nearest_walkable_cell(center + (Vector2i(radius.x + 1, gap_offset) if horizontal else Vector2i(gap_offset, radius.x + 1)), 10)

func _stamp_mushroom_ritual_circle_landmark(landmark: Dictionary) -> void:
	var center: Vector2i = landmark["center"]
	var radius: Vector2i = landmark["radius"]
	for x in range(center.x - radius.x, center.x + radius.x + 1):
		for y in range(center.y - radius.y, center.y + radius.y + 1):
			var cell := Vector2i(x, y)
			var dx := float(x - center.x) / maxf(1.0, float(radius.x))
			var dy := float(y - center.y) / maxf(1.0, float(radius.y))
			var score := dx * dx + dy * dy
			if score <= 1.0:
				if score <= 0.38:
					_stamp_landmark_cell(landmark, cell, E_LOW, "landmark_mushroom_basin_floor")
				elif abs(score - 0.72) < 0.16 or _hash_cell(cell, 611) % 100 < 10:
					_stamp_landmark_cell(landmark, cell, E_BLOCKED, "landmark_mushroom_circle")
				elif _hash_cell(cell, 613) % 100 < 20:
					_stamp_landmark_cell(landmark, cell, E_LOW, "landmark_mushroom_floor")
	landmark["road_anchor"] = nearest_walkable_cell(center + Vector2i(radius.x + 2, 0), 8)

func _stamp_cliff_wall_barrier_landmark(landmark: Dictionary) -> void:
	var center: Vector2i = landmark["center"]
	var radius: Vector2i = landmark["radius"]
	var horizontal: bool = _hash_cell(center, 617) % 2 == 0
	landmark["orientation"] = "horizontal" if horizontal else "vertical"
	var gap_offset: int = _rng.range_int(-2, 2)
	for i in range(-radius.x, radius.x + 1):
		for thickness in range(-2, 3):
			var cell: Vector2i = Vector2i(center.x + i, center.y + thickness) if horizontal else Vector2i(center.x + thickness, center.y + i)
			var gap: bool = abs(i - gap_offset) <= 2
			if gap:
				continue
			_stamp_landmark_cell(landmark, cell, E_BLOCKED, "landmark_cliff_wall")
	landmark["road_anchor"] = nearest_walkable_cell(center + (Vector2i(gap_offset, 0) if horizontal else Vector2i(0, gap_offset)), 5)

func _stamp_broken_ruin_cluster_landmark(landmark: Dictionary) -> void:
	var center: Vector2i = landmark["center"]
	var radius: Vector2i = landmark["radius"]
	for x in range(center.x - radius.x, center.x + radius.x + 1):
		for y in range(center.y - radius.y, center.y + radius.y + 1):
			var cell := Vector2i(x, y)
			var dx: int = abs(x - center.x)
			var dy: int = abs(y - center.y)
			var arch: bool = (dx == radius.x - 1 and dy <= 3) or (dy == radius.y - 1 and dx <= 3)
			var courtyard: bool = dx <= 2 and dy <= 2
			var rubble: bool = _hash_cell(cell, 619) % 100 < 22 and dx + dy > 2
			if arch or rubble:
				_stamp_landmark_cell(landmark, cell, E_BLOCKED, "landmark_ruin")
			elif courtyard:
				_stamp_landmark_cell(landmark, cell, E_LOW, "landmark_ruin_floor")
	landmark["road_anchor"] = nearest_walkable_cell(center + Vector2i(0, radius.y + 1), 8)

func _stamp_swamp_basin_landmark(landmark: Dictionary) -> void:
	var center: Vector2i = landmark["center"]
	var radius: Vector2i = landmark["radius"]
	for x in range(center.x - radius.x, center.x + radius.x + 1):
		for y in range(center.y - radius.y, center.y + radius.y + 1):
			var cell := Vector2i(x, y)
			var dx := float(x - center.x) / maxf(1.0, float(radius.x))
			var dy := float(y - center.y) / maxf(1.0, float(radius.y))
			var score := dx * dx + dy * dy
			if score <= 0.62:
				_stamp_landmark_cell(landmark, cell, E_WATER, "landmark_swamp_basin")
			elif score <= 0.96 and _hash_cell(cell, 623) % 100 < 30:
				_stamp_landmark_cell(landmark, cell, E_BLOCKED, "landmark_swamp_root")
	landmark["road_anchor"] = nearest_walkable_cell(center + Vector2i(radius.x + 2, 0), 8)

func _build_frontier_blockers() -> void:
	var lake_count := _rng.range_int(4, 7)
	for i in range(lake_count):
		var center := Vector2i(_rng.range_int(10, MAP_W - 11), _rng.range_int(10, MAP_H - 11))
		var radius := Vector2i(_rng.range_int(4, 8), _rng.range_int(3, 6))
		lakes.append({"center": center, "radius": radius})
		_stamp_frontier_blob(center, radius, E_WATER, "lake")
	var mountain_count := _rng.range_int(9, 14)
	for i in range(mountain_count):
		_stamp_frontier_blob(
			Vector2i(_rng.range_int(7, MAP_W - 8), _rng.range_int(7, MAP_H - 8)),
			Vector2i(_rng.range_int(3, 7), _rng.range_int(3, 7)),
			E_BLOCKED,
			"mountain"
		)
	var forest_count := _rng.range_int(12, 18)
	for i in range(forest_count):
		_stamp_frontier_blob(
			Vector2i(_rng.range_int(5, MAP_W - 6), _rng.range_int(5, MAP_H - 6)),
			Vector2i(_rng.range_int(3, 8), _rng.range_int(3, 6)),
			E_BLOCKED,
			"forest_blocker"
		)

func _stamp_frontier_blob(center: Vector2i, radius: Vector2i, elevation: int, feature: String) -> void:
	for x in range(center.x - radius.x, center.x + radius.x + 1):
		for y in range(center.y - radius.y, center.y + radius.y + 1):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell) or _is_frontier_reserved(cell, 2):
				continue
			var dx := float(x - center.x) / maxf(1.0, float(radius.x))
			var dy := float(y - center.y) / maxf(1.0, float(radius.y))
			var edge_noise := float(_hash_cell(cell, 919) % 1000) / 1000.0
			if dx * dx + dy * dy <= 0.72 + edge_noise * 0.34:
				grid[x][y] = elevation
				feature_grid[x][y] = feature

func _is_frontier_reserved(cell: Vector2i, margin: int) -> bool:
	if is_in_bounds(cell) and (grid[cell.x][cell.y] == E_HIGH or feature_grid[cell.x][cell.y] == "high_zone" or feature_grid[cell.x][cell.y] == "high_access"):
		return true
	if road_cells.has(cell):
		return true
	for rx in range(cell.x - margin, cell.x + margin + 1):
		for ry in range(cell.y - margin, cell.y + margin + 1):
			if road_cells.has(Vector2i(rx, ry)):
				return true
	for plot in plots:
		var rect: Rect2i = plot["rect"]
		if _expanded_rect(rect, margin).has_point(cell):
			return true
		for ramp_rect in _plot_ramp_rects(plot):
			if _expanded_rect(ramp_rect, margin).has_point(cell):
				return true
	for landmark in landmarks:
		var landmark_rect: Rect2i = landmark.get("rect", Rect2i())
		if landmark_rect.size != Vector2i.ZERO and _expanded_rect(landmark_rect, margin).has_point(cell):
			return true
	return false

func _dominant_elevation_near(cell: Vector2i) -> int:
	if is_in_bounds(cell) and grid[cell.x][cell.y] > E_WATER:
		return grid[cell.x][cell.y]
	var nearest := nearest_walkable_cell(cell, 8)
	if is_in_bounds(nearest):
		return max(E_LOW, grid[nearest.x][nearest.y])
	return E_LOW

# ── PAINT ──────────────────────────────────────────────────────────────────────
func _paint() -> void:
	layer_low.clear()
	layer_mid.clear()
	layer_high.clear()
	if _uses_square_grid_map():
		_paint_square_grid_map()
		return

	var grass_cells: Array[Vector2i] = []
	var road_cells_to_paint: Array[Vector2i] = []
	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			var pos = Vector2i(x, y)
			var feature: String = feature_grid[x][y]

			match e:
				E_BLOCKED:
					pass
				E_WATER:
					_paint_water_cell(pos)
				_:
					if feature == "path":
						road_cells_to_paint.append(pos)
					else:
						grass_cells.append(pos)

	_apply_connected_ground_and_roads(layer_low, grass_cells, road_cells_to_paint)
	_paint_objects()
	_paint_plots()
	_paint_visual_props()
	_update_elevation_debug_overlay()

func _paint_square_grid_map() -> void:
	layer_low.modulate = _square_grid_ground_modulate()
	layer_mid.modulate = Color.WHITE
	layer_high.modulate = Color.WHITE
	var grass_cells: Array[Vector2i] = []
	var road_cells_to_paint: Array[Vector2i] = []
	for x in MAP_W:
		for y in MAP_H:
			var pos := Vector2i(x, y)
			var elevation: int = grid[x][y]
			var feature: String = feature_grid[x][y]
			match elevation:
				E_BLOCKED:
					if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER and feature != "map_border":
						if feature == "forest_blocker":
							layer_low.set_cell(pos, pick("foliage"), Vector2i(0,0))
				E_WATER:
					_paint_water_cell(pos)
				_:
					if feature == "path":
						road_cells_to_paint.append(pos)
					else:
						grass_cells.append(pos)
	_apply_connected_ground_and_roads(layer_low, grass_cells, road_cells_to_paint)
	_paint_plots()
	_paint_visual_props()
	_update_elevation_debug_overlay()

func _apply_connected_ground_and_roads(layer: TileMapLayer, grass_cells: Array[Vector2i], road_cells_to_paint: Array[Vector2i]) -> void:
	if layer == null:
		return
	var tile_set := layer.tile_set
	var tile_set_path := tile_set.resource_path if tile_set != null else "<missing>"
	var expected_tileset_path := _active_asset_pack_tileset_path if _active_asset_pack_tileset_path != "" else RUNTIME_TERRAIN_TILESET_PATH
	if tile_set_path != expected_tileset_path:
		push_warning("[MapGenerator] Connected terrain expected '%s' but got '%s'" % [expected_tileset_path, tile_set_path])
	if not grass_cells.is_empty():
		layer.set_cells_terrain_connect(grass_cells, _low_ground_terrain_set_id, _low_ground_terrain_id, false)
	if not road_cells_to_paint.is_empty():
		layer.set_cells_terrain_connect(road_cells_to_paint, _road_terrain_set_id, _road_terrain_id, false)
	print("[MapGenerator] Connected terrain TileSet=", tile_set_path,
		" grass_cells=", grass_cells.size(),
		" road_cells=", road_cells_to_paint.size(),
		" low_mapping=", _low_ground_terrain_set_id, "/", _low_ground_terrain_id,
		" road_mapping=", _road_terrain_set_id, "/", _road_terrain_id)

func _paint_water_cell(cell: Vector2i) -> void:
	layer_low.set_cell(cell, _water_source_id, _water_atlas)

func _update_elevation_debug_overlay() -> void:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		if _elevation_debug_overlay != null and is_instance_valid(_elevation_debug_overlay):
			_elevation_debug_overlay.set_debug_enabled(false)
		return
	if _elevation_debug_overlay == null or not is_instance_valid(_elevation_debug_overlay):
		_elevation_debug_overlay = ElevationDebugOverlayScript.new()
		_elevation_debug_overlay.name = "ElevationDebugOverlay"
		add_child(_elevation_debug_overlay)
	_elevation_debug_overlay.z_index = 20
	_elevation_debug_overlay.set_debug_enabled(show_elevation_debug)
	_elevation_debug_overlay.configure(grid, feature_grid, road_cells, plots)

func set_elevation_debug_enabled(enabled: bool) -> void:
	show_elevation_debug = enabled
	if _elevation_debug_overlay != null and is_instance_valid(_elevation_debug_overlay):
		_elevation_debug_overlay.set_debug_enabled(enabled)

func set_visual_props_enabled(enabled: bool) -> void:
	show_visual_props = enabled
	if _prop_visual_root != null and is_instance_valid(_prop_visual_root):
		_prop_visual_root.visible = enabled

func _square_grid_ground_modulate() -> Color:
	match map_type_id:
		MAP_TYPE_AI_TESTING_GROUND:
			return Color("#244E34")
		MAP_TYPE_FORTRESS_AI_ARENA:
			return Color("#1E4A34")
		MAP_TYPE_SEEDED_GRID_FRONTIER:
			return Color.WHITE
	return Color("#2D6A3F")

func _paint_objects() -> void:
	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			var feature: String = feature_grid[x][y]
			var pos = Vector2i(x, y)
			if feature == "giant_mushroom":
				_set_plot_cell(pos, "giant_mushroom")
				continue
			if e == E_WATER:
				continue
			if e == E_BLOCKED:
				if not _has_walkable_drop(pos) and _is_deep_forest_cell(pos):
					layer_low.set_cell(pos, pick("foliage"), Vector2i(0,0))
				continue
			if feature == "path":
				continue

			# Foliage border on low layer
			if x <= 3 or x >= MAP_W-4 or y <= 3 or y >= MAP_H-4:
				if (x + y) % 2 == 0:
					layer_low.set_cell(pos, pick("foliage"), Vector2i(0,0))
				continue

			# Economy plot 1 — high ground plateau (easy)
			if e == E_HIGH and x >= 21 and x <= 29 and y >= 8 and y <= 12:
				pass

			# Economy plot 2 — mid ground west (medium)
			elif e == E_MID and x >= 10 and x <= 16 and y >= 24 and y <= 28:
				pass

			# Economy plot 3 — low ground south bowl (hard)
			elif e == E_LOW and x >= 21 and x <= 29 and y >= 40 and y <= 44:
				pass

			# Corrupted scatter on low ground
			elif e == E_LOW and (x*7+y*11)%29==0:
				layer_low.set_cell(pos, pick("corrupted"), Vector2i(0,0))

			# Decoration scatter on mid ground
			elif e == E_MID and (x*5+y*13)%37==0:
				layer_mid.set_cell(pos, pick("decoration"), Vector2i(0,0))

			elif e == E_RAMP:
				pass

func _paint_visual_props() -> void:
	_clear_visual_props()
	_visual_prop_counts = {
		"tree": 0,
		"rock": 0,
		"ruin": 0,
		"decor": 0,
	}
	if not show_visual_props:
		_ensure_visual_prop_root()
		_prop_visual_root.visible = false
		return
	if _prop_textures.is_empty():
		return
	_ensure_visual_prop_root()
	_prop_visual_root.visible = true
	for x in MAP_W:
		for y in MAP_H:
			var cell := Vector2i(x, y)
			if not _can_place_visual_prop(cell):
				continue
			var feature: String = feature_grid[x][y]
			var elevation: int = grid[x][y]
			if feature == "forest_blocker" or feature == "giant_mushroom":
				_try_place_visual_prop(cell, AssetPackConfigScript.TREE, "tree", 760)
			elif elevation == E_BLOCKED:
				_try_place_visual_prop(cell, AssetPackConfigScript.ROCK, "rock", 520)
			elif feature == "content_plot_blank":
				if _cell_hash_chance(cell, 701, 260):
					var tag: StringName = AssetPackConfigScript.RUIN if _cell_hash_chance(cell, 702, 420) else AssetPackConfigScript.DECOR
					_try_place_visual_prop(cell, tag, "ruin" if tag == AssetPackConfigScript.RUIN else "decor", 1000)
	print("[MapGenerator] Visual props trees=", _visual_prop_counts["tree"],
		" rocks=", _visual_prop_counts["rock"],
		" ruins=", _visual_prop_counts["ruin"],
		" decor=", _visual_prop_counts["decor"],
		" visible=", show_visual_props)

func _ensure_visual_prop_root() -> void:
	if _prop_visual_root != null and is_instance_valid(_prop_visual_root):
		return
	_prop_visual_root = Node2D.new()
	_prop_visual_root.name = "VisualProps"
	_prop_visual_root.z_index = 12
	add_child(_prop_visual_root)

func _clear_visual_props() -> void:
	if _prop_visual_root == null or not is_instance_valid(_prop_visual_root):
		return
	for child in _prop_visual_root.get_children():
		child.queue_free()

func _can_place_visual_prop(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if road_cells.has(cell):
		return false
	if grid[cell.x][cell.y] == E_RAMP:
		return false
	var feature: String = feature_grid[cell.x][cell.y]
	if feature == "path" or feature == "ramp" or feature == "high_access":
		return false
	if _is_inside_base_buildable_area(cell):
		return false
	return true

func _is_inside_base_buildable_area(cell: Vector2i) -> bool:
	for plot in base_plots:
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.has_point(cell):
			return true
	return false

func _try_place_visual_prop(cell: Vector2i, tag: StringName, counter_key: String, chance_per_mille: int) -> bool:
	var tag_salt := int(hash(str(tag)) & 0x3fff)
	if not _cell_hash_chance(cell, 611 + tag_salt, chance_per_mille):
		return false
	var textures: Array = _prop_textures.get(tag, [])
	if textures.is_empty():
		return false
	var texture: Texture2D = textures[_cell_hash_index(cell, 631 + tag_salt, textures.size())]
	if texture == null:
		return false
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = layer_low.map_to_local(cell) + Vector2(_cell_hash_offset(cell, 641), _cell_hash_offset(cell, 647))
	sprite.centered = true
	sprite.scale = _visual_prop_scale(texture)
	sprite.z_index = 12
	_prop_visual_root.add_child(sprite)
	_visual_prop_counts[counter_key] = int(_visual_prop_counts.get(counter_key, 0)) + 1
	return true

func _visual_prop_scale(texture: Texture2D) -> Vector2:
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	var target := 58.0
	var scale_value := minf(1.0, target / maxf(size.x, size.y))
	return Vector2(scale_value, scale_value)

func _cell_hash_chance(cell: Vector2i, salt: int, chance_per_mille: int) -> bool:
	return (_hash_cell(cell, salt) % 1000) < chance_per_mille

func _cell_hash_index(cell: Vector2i, salt: int, count: int) -> int:
	if count <= 0:
		return 0
	return _hash_cell(cell, salt) % count

func _cell_hash_offset(cell: Vector2i, salt: int) -> float:
	return float((_hash_cell(cell, salt) % 25) - 12)

func _has_walkable_drop(cell: Vector2i) -> bool:
	for offset in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if is_in_bounds(neighbor) and is_walkable_cell(neighbor):
			return true
	return false

func _is_deep_forest_cell(cell: Vector2i) -> bool:
	if cell.x <= 2 or cell.x >= MAP_W - 3 or cell.y <= 2 or cell.y >= MAP_H - 3:
		return true
	for offset: Vector2i in [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]:
		var neighbor: Vector2i = cell + offset
		if is_in_bounds(neighbor) and is_walkable_cell(neighbor):
			return false
	return _hash_cell(cell, 311) % 1000 < 380

func _paint_plots() -> void:
	for plot in plots:
		var rect: Rect2i = plot["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var cell := Vector2i(x, y)
				if not is_in_bounds(cell):
					continue
				var feature: String = feature_grid[x][y]
				match feature:
					"tower_wall":
						_set_plot_cell(cell, "wizard_tower_wall")
					"tower_floor":
						_set_plot_cell(cell, "wizard_tower_floor")
					"bandit_wall":
						_set_plot_cell(cell, "bandit_wall")
					"bandit_floor":
						if _rng.chance_per_mille(540):
							_set_plot_cell(cell, "bandit_floor")
					"base_floor":
						if _is_rect_edge(cell, rect) and _rng.chance_per_mille(90):
							_set_plot_cell(cell, "foliage")
					"economy_space":
						_set_plot_cell(cell, "economy_plot")
					"objective":
						if _rng.chance_per_mille(520):
							_set_plot_cell(cell, "corrupted")
						else:
							_set_plot_cell(cell, "ruin_floor")
					"giant_mushroom":
						_set_plot_cell(cell, "giant_mushroom")
		for economy_cell in plot.get("economy_spaces", []):
			_set_plot_cell(economy_cell, "economy_plot")

func _set_plot_cell(cell: Vector2i, terrain_name: String) -> void:
	if not is_in_bounds(cell):
		return
	var elevation: int = grid[cell.x][cell.y]
	match elevation:
		E_HIGH:
			layer_high.set_cell(cell, pick(terrain_name), Vector2i(0,0))
		E_MID, E_RAMP:
			layer_mid.set_cell(cell, pick(terrain_name), Vector2i(0,0))
		_:
			layer_low.set_cell(cell, pick(terrain_name), Vector2i(0,0))

func _is_rect_edge(cell: Vector2i, rect: Rect2i) -> bool:
	return cell.x == rect.position.x or cell.y == rect.position.y or cell.x == rect.end.x - 1 or cell.y == rect.end.y - 1

# ── ZONES ──────────────────────────────────────────────────────────────────────
func _register_zones() -> void:
	spawn_positions.clear()
	enemy_spawns.clear()
	chokepoints.clear()
	economy_zones.clear()
	if map_type_id == MAP_TYPE_FORTRESS_AI_ARENA:
		for plot in base_plots:
			var rect: Rect2i = plot["rect"]
			if str(plot["id"]) == "fort_west_base":
				for x in range(rect.position.x, rect.end.x):
					for y in range(rect.position.y, rect.end.y):
						if is_walkable_cell(Vector2i(x, y)):
							spawn_positions.append(Vector2i(x, y))
			economy_zones.append({
				"plot_id": plot["id"],
				"rect": plot["rect"],
				"economy_spaces": plot["economy_spaces"],
				"economy_count": plot["economy_count"],
				"difficulty": plot["difficulty"],
				"defensibility": plot["defensibility"],
				"label": plot["name"],
			})
		for y in range(32, 46, 2):
			enemy_spawns.append(Vector2i(82, y))
		chokepoints.append_array([Vector2i(29, 38), Vector2i(48, 38), Vector2i(66, 38)])
		return
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		for plot in base_plots:
			var rect: Rect2i = plot["rect"]
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					if is_walkable_cell(Vector2i(x, y)):
						spawn_positions.append(Vector2i(x, y))
			economy_zones.append({
				"plot_id": plot["id"],
				"rect": plot["rect"],
				"economy_spaces": plot["economy_spaces"],
				"economy_count": plot["economy_count"],
				"difficulty": plot["difficulty"],
				"defensibility": plot["defensibility"],
				"label": plot["name"],
			})
		for plot in plots:
			var anchor: Vector2i = plot.get("anchor", Vector2i(MAP_W / 2, MAP_H / 2))
			if str(plot.get("kind", "")) != "base":
				enemy_spawns.append(nearest_walkable_cell(anchor, 8))
		chokepoints.append_array(_frontier_chokepoints())
		return
	if map_type_id == MAP_TYPE_AI_TESTING_GROUND:
		for plot in base_plots:
			var rect: Rect2i = plot["rect"]
			if str(plot["id"]) == "ai_west_base":
				for x in range(rect.position.x, rect.end.x):
					for y in range(rect.position.y, rect.end.y):
						spawn_positions.append(Vector2i(x, y))
			economy_zones.append({
				"plot_id": plot["id"],
				"rect": plot["rect"],
				"economy_spaces": plot["economy_spaces"],
				"economy_count": plot["economy_count"],
				"difficulty": plot["difficulty"],
				"defensibility": plot["defensibility"],
				"label": plot["name"],
			})
		for y in range(26, 49, 2):
			enemy_spawns.append(Vector2i(84, y))
		chokepoints.append_array([Vector2i(32, 37), Vector2i(48, 37), Vector2i(64, 37)])
		return
	if map_type_id == MAP_TYPE_GRID_TEST_CANVAS:
		for plot in base_plots:
			var rect: Rect2i = plot["rect"]
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					spawn_positions.append(Vector2i(x, y))
			economy_zones.append({
				"plot_id": plot["id"],
				"rect": plot["rect"],
				"economy_spaces": plot["economy_spaces"],
				"economy_count": plot["economy_count"],
				"difficulty": plot["difficulty"],
				"defensibility": plot["defensibility"],
				"label": plot["name"],
			})
		for x in range(6, MAP_W - 6):
			enemy_spawns.append(Vector2i(x, 4))
			if x % 4 == 0:
				enemy_spawns.append(Vector2i(x, MAP_H - 5))
		for y in range(8, MAP_H - 8, 4):
			enemy_spawns.append(Vector2i(4, y))
			enemy_spawns.append(Vector2i(MAP_W - 5, y))
		chokepoints.append_array([Vector2i(32, 32), Vector2i(48, 48), Vector2i(64, 64)])
		return
	if not base_plots.is_empty():
		var starter: Dictionary = base_plots[min(1, base_plots.size() - 1)]
		var starter_rect: Rect2i = starter["rect"]
		for x in range(starter_rect.position.x, starter_rect.end.x):
			for y in range(starter_rect.position.y, starter_rect.end.y):
				var spawn_cell := Vector2i(x, y)
				if is_walkable_cell(spawn_cell):
					spawn_positions.append(spawn_cell)

	for x in range(hg_x1, hg_x2 + 1):
		if grid[x][2] != E_WATER:
			enemy_spawns.append(Vector2i(x, 2))

	for x in range(5, MAP_W - 5):
		if grid[x][MAP_H - 4] == E_LOW:
			enemy_spawns.append(Vector2i(x, MAP_H - 4))

	for y in range(10, MAP_H - 10):
		if g(3, y) >= E_LOW:
			enemy_spawns.append(Vector2i(3, y))
		if g(MAP_W - 4, y) >= E_LOW:
			enemy_spawns.append(Vector2i(MAP_W - 4, y))

	for ramp in ramps:
		for x in range(ramp.position.x, ramp.end.x):
			for y in range(ramp.position.y, ramp.end.y):
				chokepoints.append(Vector2i(x, y))

	for plot in base_plots:
		economy_zones.append({
			"plot_id": plot["id"],
			"rect": plot["rect"],
			"economy_spaces": plot["economy_spaces"],
			"economy_count": plot["economy_count"],
			"difficulty": plot["difficulty"],
			"defensibility": plot["defensibility"],
			"label": plot["name"],
		})

func _frontier_chokepoints() -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for ramp in ramps:
		points.append(ramp.position + Vector2i(ramp.size.x / 2, ramp.size.y / 2))
	var hub := nearest_walkable_cell(Vector2i(MAP_W / 2, MAP_H / 2), 24)
	if is_in_bounds(hub):
		points.append(hub)
	return points

func get_spawn_position() -> Vector2i:
	if spawn_positions.is_empty():
		return Vector2i(MAP_W / 2, MAP_H / 2)
	return spawn_positions[_rng.range_int(0, spawn_positions.size() - 1)]

func get_chokepoints() -> Array:
	return chokepoints

func get_economy_zones() -> Array:
	return economy_zones

func get_plots() -> Array:
	return plots

func get_base_plots() -> Array:
	return base_plots

func get_landmarks() -> Array:
	return landmarks

func get_map_summary() -> Dictionary:
	return {
		"map_type_id": map_type_id,
		"map_type_name": get_map_type_name(),
		"map_type": get_map_type_data(),
		"seed": seed_value,
		"plots": plots.size(),
		"base_plots": base_plots.size(),
		"chokepoints": chokepoints.size(),
		"economy_spaces": _count_economy_spaces(),
		"layout": {
			"high_ground": Rect2i(hg_x1, hg_y1, hg_x2 - hg_x1 + 1, hg_y2 - hg_y1 + 1),
			"mid_ground": Rect2i(mg_x1, mg_y1, mg_x2 - mg_x1 + 1, mg_y2 - mg_y1 + 1),
			"lake": Vector4i(lk_cx, lk_cy, lk_rx, lk_ry),
			"lakes": lakes.duplicate(true),
			"ramp": Rect2i(cp_x1, cp_y, cp_x2 - cp_x1 + 1, max(1, ramp_y - cp_y + 1)),
			"ramps": ramps.duplicate(),
			"landmarks": landmarks.duplicate(true),
		},
		"base_archetypes": _get_base_archetype_summary(),
		"plot_layout": _get_plot_layout_summary(),
	}

func _debug_print_elevation_summary() -> void:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return
	var high_zones := _collect_elevation_zones(E_HIGH)
	var low_zones := _collect_elevation_zones(E_LOW)
	var high_plots := 0
	var low_plots := 0
	for plot in plots:
		if str(plot.get("elevation", ELEVATION_LOW)) == ELEVATION_HIGH:
			high_plots += 1
		else:
			low_plots += 1
	print("[MapGenerator] Elevation zones high=", high_zones.size(),
		" low=", low_zones.size(),
		" ramps=", ramps.size(),
		" plots_high=", high_plots,
		" plots_low=", low_plots,
		" validation=", _validate_frontier_elevation_layout(false))
	var plateau_sizes: Array[int] = []
	var plateau_ramp_counts: Array[int] = []
	for plateau in _frontier_plateaus:
		var cells: Array = plateau.get("cells", [])
		var ramp_count := 0
		for ramp in ramps:
			for cell_value in cells:
				var cell: Vector2i = cell_value
				if _expanded_rect(ramp, 1).has_point(cell):
					ramp_count += 1
					break
		plateau_sizes.append(cells.size())
		plateau_ramp_counts.append(ramp_count)
	print("[MapGenerator] Plateaus count=", _frontier_plateaus.size(),
		" sizes=", plateau_sizes,
		" ramp_counts=", plateau_ramp_counts,
		" validation=", _validate_frontier_plateau_generation(false))
	print("[MapGenerator] Base archetypes ", _get_base_archetype_summary(),
		" validation=", _validate_frontier_base_archetypes(false))

func _validate_frontier_base_archetypes(verbose: bool = false) -> bool:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return true
	var errors: Array[String] = []
	for plot in base_plots:
		var resources := int(plot.get("resource_node_count", -1))
		var economy_spaces: Array = plot.get("economy_spaces", [])
		var target_ramps := int(plot.get("target_ramp_count", 0))
		var actual_ramps := _base_access_count(plot)
		plot["validated_ramp_count"] = actual_ramps
		if resources != economy_spaces.size():
			errors.append("%s resource count mismatch %s/%s" % [plot.get("id", "<unknown>"), economy_spaces.size(), resources])
		if target_ramps > 0 and actual_ramps < target_ramps:
			errors.append("%s entrance count below target %s/%s" % [plot.get("id", "<unknown>"), actual_ramps, target_ramps])
		if str(plot.get("base_archetype", "")) == "":
			errors.append("%s missing archetype" % plot.get("id", "<unknown>"))
	if verbose:
		for error in errors:
			push_warning("[MapGenerator] Base archetype validation failed: " + error)
	return errors.is_empty()

func _debug_print_frontier_road_summary() -> void:
	if map_type_id != MAP_TYPE_SEEDED_GRID_FRONTIER:
		return
	print("[MapGenerator] Road layout mode=", _frontier_road_debug.get("mode", frontier_road_layout_mode),
		" main_spine_nodes=", _frontier_road_debug.get("main_spine_node_count", 0),
		" branches=", _frontier_road_debug.get("branch_count", 0),
		" widths=", _frontier_road_debug.get("width_settings", "spine=%s branch=%s plot=%s junction_max=%sx%s" % [FRONTIER_MAIN_SPINE_ROAD_WIDTH, FRONTIER_BRANCH_ROAD_WIDTH, FRONTIER_PLOT_APPROACH_ROAD_WIDTH, FRONTIER_MAX_JUNCTION_SIZE, FRONTIER_MAX_JUNCTION_SIZE]),
		" road_cells=", road_cells.size(),
		" thinning=", _frontier_road_debug.get("thinning_before", road_cells.size()), "->", _frontier_road_debug.get("thinning_after", road_cells.size()),
		" junctions=", _frontier_road_debug.get("junction_count", 0),
		" fallback=", _frontier_road_debug.get("fallback", false),
		" validation=", _frontier_road_debug.get("validation", false))

func get_path_telemetry() -> Dictionary:
	return {
		"path_requests": path_requests_total,
		"path_cache_hits": path_cache_hits_total,
		"flow_field_recomputes": flow_field_recomputes_total,
		"units_using_flow_field": units_using_flow_field_total,
		"path_requests_per_second": _path_requests_per_second,
		"path_cache_hits_per_second": _path_cache_hits_per_second,
		"flow_field_recomputes_per_second": _flow_field_recomputes_per_second,
		"units_using_flow_field_per_second": _units_using_flow_field_per_second,
		"path_cache_size": _path_cache.size(),
		"path_cache_version": _path_cache_version,
	}

func _get_plot_layout_summary() -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	for plot in plots:
		layout.append({
			"id": plot.get("id", ""),
			"rect": plot.get("rect", Rect2i()),
			"anchor": plot.get("anchor", Vector2i.ZERO),
			"economy_spaces": plot.get("economy_spaces", []),
		})
	return layout

func _get_base_archetype_summary() -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	for plot in base_plots:
		summary.append({
			"id": plot.get("id", ""),
			"base_archetype": plot.get("base_archetype", ""),
			"plot_size_class": plot.get("plot_size_class", ""),
			"resource_node_count": plot.get("resource_node_count", plot.get("economy_count", 0)),
			"target_ramp_count": plot.get("target_ramp_count", 0),
			"validated_ramp_count": plot.get("validated_ramp_count", plot.get("actual_ramp_count", 0)),
			"ramp_width": plot.get("ramp_width", 0),
			"defence_score": plot.get("defence_score", plot.get("defensibility", 0.0)),
			"economy_score": plot.get("economy_score", 0.0),
			"elevation": plot.get("elevation", ELEVATION_LOW),
		})
	return summary

func _count_economy_spaces() -> int:
	var count := 0
	for plot in base_plots:
		count += int(plot.get("economy_count", 0))
	return count
