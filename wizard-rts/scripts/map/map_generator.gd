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
const GRID_TEST_CELL_SIZE := 64

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
const PATH_CACHE_LIMIT := 768
var path_requests_total := 0
var path_cache_hits_total := 0
var _path_requests_this_second := 0
var _path_cache_hits_this_second := 0
var _path_requests_per_second := 0
var _path_cache_hits_per_second := 0
var _path_meter_elapsed := 0.0

var spawn_positions: Array = []
var enemy_spawns:    Array = []
var chokepoints:     Array = []
var economy_zones:   Array = []
var plots: Array[Dictionary] = []
var base_plots: Array[Dictionary] = []

# ── INIT ───────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer_low  = get_parent().get_node("TileMapLow")
	layer_mid  = get_parent().get_node("TileMapMid")
	layer_high = get_parent().get_node("TileMapHigh")
	_apply_session_settings()
	seed_value = _resolve_seed()
	_rng = DeterministicRng.new(seed_value)
	_configure_map_type()
	_configure_seeded_layout()
	_load_tiles()
	_build_grid()
	_build_plots()
	_stamp_plots_into_grid()
	_build_roads()
	_build_landmarks()
	_build_height_and_cost_maps()
	_build_pathfinder()
	_paint()
	_register_zones()
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
	_path_requests_this_second = 0
	_path_cache_hits_this_second = 0
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
	print("[MapGenerator] Loaded", T.size(), "terrain types")

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
	return map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER or map_type_id == MAP_TYPE_GRID_TEST_CANVAS or map_type_id == MAP_TYPE_AI_TESTING_GROUND or map_type_id == MAP_TYPE_FORTRESS_AI_ARENA

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
		previous = cell
	return true

func _is_path_traversable_cell(cell: Vector2i) -> bool:
	return is_walkable_cell(cell) and not _is_unramped_height_edge(cell)

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

func _is_unramped_height_edge(cell: Vector2i) -> bool:
	if not is_walkable_cell(cell) or grid[cell.x][cell.y] == E_RAMP:
		return false
	var height := int(height_map[cell.x][cell.y])
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if not is_in_bounds(neighbor) or not is_walkable_cell(neighbor):
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
	var base_targets: Array[Vector2] = [
		Vector2(0.20, 0.22),
		Vector2(0.76, 0.23),
		Vector2(0.24, 0.73),
		Vector2(0.72, 0.70),
		Vector2(0.50, 0.16),
	]
	var base_count := 4
	for i in range(base_count):
		var target := base_targets[(i + _rng.range_int(0, base_targets.size() - 1)) % base_targets.size()]
		var rect := _find_open_frontier_rect(Vector2i(10, 10), reserved_rects, target, 220)
		reserved_rects.append(_expanded_rect(rect, 8))
		var plot := _make_base_plot(
			"base_plot_%s" % (i + 1),
			"High-ground base plot %s" % (i + 1),
			rect,
			[rect.position + Vector2i(5, 5)],
			0.22 + float(i) * 0.14,
			0.86,
			"SC2-style high-ground base with a single 2x2 ramp, central economy slot, and one main road approach."
		)
		plot["ramp_rect"] = _frontier_ramp_for_base(rect)
		_register_plot(plot)

	var content_specs := [
		["abandoned_wizard_tower", "Abandoned wizard tower", "quest", Vector2(0.50, 0.48)],
		["bandit_outpost", "Bandit outpost", "enemy_outpost", Vector2(0.66, 0.44)],
		["sealed_archive", "Sealed archive", "quest", Vector2(0.34, 0.50)],
		["raider_supply_camp", "Raider supply camp", "enemy_outpost", Vector2(0.52, 0.78)],
		["ancient_crossroads", "Ancient crossroads", "objective", Vector2(0.50, 0.28)],
	]
	for spec in content_specs:
		var rect := _find_open_frontier_rect(Vector2i(10, 10), reserved_rects, spec[3], 240)
		reserved_rects.append(_expanded_rect(rect, 6))
		_register_plot({
			"id": spec[0],
			"name": spec[1],
			"kind": spec[2],
			"rect": rect,
			"anchor": rect.position + Vector2i(5, 5),
			"economy_spaces": [],
			"difficulty": 0.45 + float(_rng.range_int(0, 450)) / 1000.0,
			"defensibility": 0.35 + float(_rng.range_int(0, 350)) / 1000.0,
			"story": "Reserved 10x10 content plot connected to the road network.",
		})

func _find_open_frontier_rect(size: Vector2i, reserved_rects: Array[Rect2i], preferred_normalized_position: Vector2, attempts: int) -> Rect2i:
	var best_rect := _clamped_rect(Vector2i(int(preferred_normalized_position.x * MAP_W), int(preferred_normalized_position.y * MAP_H)), size)
	var best_score := -INF
	var preferred_pos := Vector2(preferred_normalized_position.x * MAP_W, preferred_normalized_position.y * MAP_H)
	for i in range(attempts):
		var candidate := _clamped_rect(Vector2i(
			_rng.range_int(5, MAP_W - size.x - 5),
			_rng.range_int(5, MAP_H - size.y - 5)
		), size)
		if _rect_conflicts_reserved(candidate, reserved_rects, 2):
			continue
		var center := Vector2(candidate.position.x + candidate.size.x * 0.5, candidate.position.y + candidate.size.y * 0.5)
		var edge_penalty := 0.0
		edge_penalty += maxf(0.0, 12.0 - float(candidate.position.x)) * 3.0
		edge_penalty += maxf(0.0, 12.0 - float(candidate.position.y)) * 3.0
		edge_penalty += maxf(0.0, 12.0 - float(MAP_W - candidate.end.x)) * 3.0
		edge_penalty += maxf(0.0, 12.0 - float(MAP_H - candidate.end.y)) * 3.0
		var score := -center.distance_to(preferred_pos) - edge_penalty + float(_rng.range_int(0, 80))
		if score > best_score:
			best_score = score
			best_rect = candidate
	return best_rect

func _expanded_rect(rect: Rect2i, margin: int) -> Rect2i:
	return Rect2i(rect.position - Vector2i(margin, margin), rect.size + Vector2i(margin * 2, margin * 2))

func _frontier_ramp_for_base(rect: Rect2i) -> Rect2i:
	var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
	var map_center := Vector2i(MAP_W / 2, MAP_H / 2)
	var delta := map_center - center
	if abs(delta.x) > abs(delta.y):
		if delta.x >= 0:
			return Rect2i(rect.end.x, center.y - 1, 2, 2)
		return Rect2i(rect.position.x - 2, center.y - 1, 2, 2)
	if delta.y >= 0:
		return Rect2i(center.x - 1, rect.end.y, 2, 2)
	return Rect2i(center.x - 1, rect.position.y - 2, 2, 2)

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

func _stamp_plots_into_grid() -> void:
	for plot in plots:
		match str(plot.get("kind", "")):
			"base":
				_stamp_base_plot(plot)
			"quest":
				_stamp_hollow_plot(plot, "tower_wall", "tower_floor")
			"enemy_outpost":
				_stamp_hollow_plot(plot, "bandit_wall", "bandit_floor")
			"objective":
				_stamp_objective_plot(plot)

func _stamp_base_plot(plot: Dictionary) -> void:
	var rect: Rect2i = plot["rect"]
	var floor_elevation := E_HIGH if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER else _dominant_elevation_near(rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2))
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			grid[x][y] = floor_elevation
			feature_grid[x][y] = "base_floor"
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER and plot.has("ramp_rect"):
		var ramp_rect: Rect2i = plot["ramp_rect"]
		ramps.append(ramp_rect)
		for x in range(ramp_rect.position.x, ramp_rect.end.x):
			for y in range(ramp_rect.position.y, ramp_rect.end.y):
				var ramp_cell := Vector2i(x, y)
				if not is_in_bounds(ramp_cell):
					continue
				grid[x][y] = E_RAMP
				feature_grid[x][y] = "ramp"
		plot["road_anchor"] = _frontier_base_road_anchor(rect, ramp_rect)
	for economy_cell in plot.get("economy_spaces", []):
		if is_in_bounds(economy_cell):
			grid[economy_cell.x][economy_cell.y] = floor_elevation
			feature_grid[economy_cell.x][economy_cell.y] = "economy_space"

func _frontier_base_road_anchor(base_rect: Rect2i, ramp_rect: Rect2i) -> Vector2i:
	var ramp_center := ramp_rect.position + Vector2i(ramp_rect.size.x / 2, ramp_rect.size.y / 2)
	if ramp_rect.position.x >= base_rect.end.x:
		return nearest_walkable_cell(Vector2i(ramp_rect.end.x, ramp_center.y), 4)
	if ramp_rect.end.x <= base_rect.position.x:
		return nearest_walkable_cell(Vector2i(ramp_rect.position.x - 1, ramp_center.y), 4)
	if ramp_rect.position.y >= base_rect.end.y:
		return nearest_walkable_cell(Vector2i(ramp_center.x, ramp_rect.end.y), 4)
	return nearest_walkable_cell(Vector2i(ramp_center.x, ramp_rect.position.y - 1), 4)

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
	if map_type_id == MAP_TYPE_AI_TESTING_GROUND or map_type_id == MAP_TYPE_FORTRESS_AI_ARENA:
		return
	if plots.is_empty():
		return
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
		_build_frontier_road_network()
		return
	var hub := nearest_walkable_cell(Vector2i(MAP_W / 2, MAP_H / 2), 24)
	for plot in plots:
		var anchor: Vector2i = plot.get("anchor", hub)
		_carve_road_between(anchor, hub, 2)
	for i in range(plots.size() - 1):
		var from_anchor: Vector2i = plots[i].get("anchor", hub)
		var to_anchor: Vector2i = plots[i + 1].get("anchor", hub)
		_carve_road_between(from_anchor, to_anchor, 1)

func _build_frontier_road_network() -> void:
	var hub := nearest_walkable_cell(Vector2i(MAP_W / 2, MAP_H / 2), 24)
	if not is_in_bounds(hub):
		hub = Vector2i(MAP_W / 2, MAP_H / 2)
	var anchors: Array[Vector2i] = []
	for plot in plots:
		var anchor: Vector2i = plot.get("road_anchor", plot.get("anchor", hub))
		anchor = nearest_walkable_cell(anchor, 8)
		if is_in_bounds(anchor):
			anchors.append(anchor)
			_carve_frontier_road(anchor, hub)
	anchors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y
	)
	for i in range(anchors.size() - 1):
		_carve_frontier_road(anchors[i], anchors[i + 1])

func _carve_frontier_road(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var bend_first_x := ((_hash_cell(from_cell + to_cell, 1201) % 2) == 0)
	var bend := Vector2i(to_cell.x, from_cell.y) if bend_first_x else Vector2i(from_cell.x, to_cell.y)
	_carve_frontier_road_segment(from_cell, bend)
	_carve_frontier_road_segment(bend, to_cell)

func _carve_frontier_road_segment(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var current := from_cell
	_carve_road_cell(current, 1)
	while current != to_cell:
		if current.x != to_cell.x:
			current.x += clampi(to_cell.x - current.x, -1, 1)
		elif current.y != to_cell.y:
			current.y += clampi(to_cell.y - current.y, -1, 1)
		_carve_road_cell(current, 1)

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

func _build_landmarks() -> void:
	landmarks.clear()
	if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER:
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
		if plot.has("ramp_rect"):
			var ramp_rect: Rect2i = plot["ramp_rect"]
			if _expanded_rect(ramp_rect, margin).has_point(cell):
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

	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			var pos = Vector2i(x, y)

			match e:
				E_BLOCKED:
					pass
				E_WATER:
					# Water sits on low layer
					layer_low.set_cell(pos, pick("water"), Vector2i(0,0))
				E_LOW:
					layer_low.set_cell(pos, pick("low_ground"), Vector2i(0,0))
				E_MID:
					layer_mid.set_cell(pos, pick("mid_ground"), Vector2i(0,0))
				E_HIGH:
					layer_high.set_cell(pos, pick("high_ground"), Vector2i(0,0))
				E_RAMP:
					layer_low.set_cell(pos, pick("low_ground"), Vector2i(0,0))
					layer_mid.set_cell(pos, pick("path_slope"), Vector2i(0,0))

	_paint_objects()
	_paint_plots()

func _paint_square_grid_map() -> void:
	layer_low.modulate = _square_grid_ground_modulate()
	layer_mid.modulate = Color.WHITE
	layer_high.modulate = Color.WHITE
	var low_id := pick("low_ground")
	var mid_id := pick("mid_ground")
	var high_id := pick("high_ground")
	var water_id := pick("water")
	var ramp_id := pick("path_slope")
	for x in MAP_W:
		for y in MAP_H:
			var pos := Vector2i(x, y)
			var elevation: int = grid[x][y]
			var feature: String = feature_grid[x][y]
			match elevation:
				E_BLOCKED:
					if map_type_id == MAP_TYPE_SEEDED_GRID_FRONTIER and feature != "map_border":
						layer_low.set_cell(pos, pick("foliage" if feature == "forest_blocker" else "high_ground"), Vector2i(0,0))
				E_WATER:
					layer_low.set_cell(pos, water_id, Vector2i(0,0))
				E_MID:
					layer_low.set_cell(pos, mid_id, Vector2i(0,0))
				E_HIGH:
					layer_low.set_cell(pos, high_id, Vector2i(0,0))
				E_RAMP:
					layer_low.set_cell(pos, ramp_id, Vector2i(0,0))
				_:
					layer_low.set_cell(pos, low_id, Vector2i(0,0))
			if feature == "path":
				_set_plot_cell(pos, "path")
	_paint_plots()

func _square_grid_ground_modulate() -> Color:
	match map_type_id:
		MAP_TYPE_AI_TESTING_GROUND:
			return Color("#244E34")
		MAP_TYPE_FORTRESS_AI_ARENA:
			return Color("#1E4A34")
		MAP_TYPE_SEEDED_GRID_FRONTIER:
			return Color("#2B5B3D")
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
				_set_plot_cell(pos, "path")
				continue

			# Foliage border on low layer
			if x <= 3 or x >= MAP_W-4 or y <= 3 or y >= MAP_H-4:
				if (x + y) % 2 == 0:
					layer_low.set_cell(pos, pick("foliage"), Vector2i(0,0))
				continue

			# Economy plot 1 — high ground plateau (easy)
			if e == E_HIGH and x >= 21 and x <= 29 and y >= 8 and y <= 12:
				layer_high.set_cell(pos, pick("high_ground"), Vector2i(0,0))

			# Economy plot 2 — mid ground west (medium)
			elif e == E_MID and x >= 10 and x <= 16 and y >= 24 and y <= 28:
				layer_mid.set_cell(pos, pick("mid_ground"), Vector2i(0,0))

			# Economy plot 3 — low ground south bowl (hard)
			elif e == E_LOW and x >= 21 and x <= 29 and y >= 40 and y <= 44:
				layer_low.set_cell(pos, pick("low_ground"), Vector2i(0,0))

			# Corrupted scatter on low ground
			elif e == E_LOW and (x*7+y*11)%29==0:
				layer_low.set_cell(pos, pick("corrupted"), Vector2i(0,0))

			# Decoration scatter on mid ground
			elif e == E_MID and (x*5+y*13)%37==0:
				layer_mid.set_cell(pos, pick("decoration"), Vector2i(0,0))

			elif e == E_RAMP:
				layer_mid.set_cell(pos, pick("path_slope"), Vector2i(0,0))

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
		"plot_layout": _get_plot_layout_summary(),
	}

func get_path_telemetry() -> Dictionary:
	return {
		"path_requests": path_requests_total,
		"path_cache_hits": path_cache_hits_total,
		"path_requests_per_second": _path_requests_per_second,
		"path_cache_hits_per_second": _path_cache_hits_per_second,
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

func _count_economy_spaces() -> int:
	var count := 0
	for plot in base_plots:
		count += int(plot.get("economy_count", 0))
	return count
