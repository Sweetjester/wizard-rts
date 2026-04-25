class_name MapGenerator
extends Node

signal map_generated(summary: Dictionary)

# ── CONFIG ─────────────────────────────────────────────────────────────────────
const MAP_W = 50
const MAP_H = 50

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

# ── STATE ──────────────────────────────────────────────────────────────────────
var layer_low:  TileMapLayer
var layer_mid:  TileMapLayer
var layer_high: TileMapLayer
var T: Dictionary = {}
var grid: Array = []
var feature_grid: Array = []
var height_map: Array = []
var movement_costs: Array = []
@export var map_type_id: String = MAP_TYPE_VAMPIRE_MUSHROOM_FOREST
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

func _apply_session_settings() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	if bool(session.get("new_game_requested")):
		map_type_id = String(session.get("map_type_id"))
		map_seed_text = String(session.get("map_seed_text"))

func get_map_type_name() -> String:
	match map_type_id:
		MAP_TYPE_VAMPIRE_MUSHROOM_FOREST:
			return "Vampiric Mushroom Forest"
	return map_type_id

func get_map_type_data() -> Dictionary:
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
	if map_type_id != MAP_TYPE_VAMPIRE_MUSHROOM_FOREST:
		push_warning("[MapGenerator] Unknown map type '%s', using Vampiric Mushroom Forest rules" % map_type_id)
		map_type_id = MAP_TYPE_VAMPIRE_MUSHROOM_FOREST

func _configure_seeded_layout() -> void:
	var plateau_shift := _rng.range_int(-8, 7)
	var plateau_width_delta := _rng.range_int(-3, 4)
	var mid_widen := _rng.range_int(-2, 6)

	hg_x1 = clampi(HG_X1 + plateau_shift, 12, 22)
	hg_x2 = clampi(HG_X2 + plateau_shift + plateau_width_delta, 28, 40)
	hg_y1 = HG_Y1 + _rng.range_int(-2, 4)
	hg_y2 = HG_Y2 + _rng.range_int(-2, 3)
	cp_x1 = clampi(24 + plateau_shift + _rng.range_int(-1, 1), hg_x1 + 3, hg_x2 - 5)
	cp_x2 = cp_x1 + 8
	cp_y = hg_y2
	ramp_y = cp_y + 4
	mg_x1 = clampi(MG_X1 - mid_widen + _rng.range_int(-3, 3), 4, 14)
	mg_x2 = clampi(MG_X2 + mid_widen + _rng.range_int(-3, 3), 35, MAP_W - 4)
	mg_y1 = MG_Y1 + _rng.range_int(-3, 3)
	mg_y2 = MG_Y2 + _rng.range_int(-4, 5)

	ramps.clear()
	ramps.append(Rect2i(cp_x1, cp_y, cp_x2 - cp_x1 + 1, ramp_y - cp_y + 1))
	var side_ramp_x := clampi(_rng.range_int(mg_x1 + 2, mg_x2 - 8), 5, MAP_W - 10)
	var side_ramp_y := clampi(_rng.range_int(mg_y1 + 4, mg_y2 - 7), 8, MAP_H - 12)
	ramps.append(Rect2i(side_ramp_x, side_ramp_y, 7, 4))

	lakes.clear()
	var primary_lake := {
		"center": Vector2i(_rng.range_int(13, 37), _rng.range_int(24, 41)),
		"radius": Vector2i(_rng.range_int(7, 11), _rng.range_int(5, 8)),
	}
	var secondary_lake := {
		"center": Vector2i(_rng.range_int(8, 42), _rng.range_int(9, 36)),
		"radius": Vector2i(_rng.range_int(4, 7), _rng.range_int(3, 5)),
	}
	lakes.append(primary_lake)
	lakes.append(secondary_lake)
	if _rng.chance_per_mille(620):
		lakes.append({
			"center": Vector2i(_rng.range_int(8, 42), _rng.range_int(10, 42)),
			"radius": Vector2i(_rng.range_int(3, 5), _rng.range_int(3, 5)),
		})
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
			grid[x].append(_generate_cell_elevation(cell))
			feature_grid[x].append("")

func _generate_cell_elevation(cell: Vector2i) -> int:
	if cell.x <= 1 or cell.x >= MAP_W - 2 or cell.y <= 1 or cell.y >= MAP_H - 2:
		return E_BLOCKED

	if _is_lake_cell(cell):
		return E_WATER

	if _is_ramp_cell(cell):
		return E_RAMP

	if cell.x >= hg_x1 and cell.x <= hg_x2 and cell.y >= hg_y1 and cell.y <= hg_y2:
		return E_HIGH

	if cell.x >= mg_x1 and cell.x <= mg_x2 and cell.y >= mg_y1 and cell.y <= mg_y2:
		return E_MID

	var block := Vector2i(cell.x / BLOCK_SIZE, cell.y / BLOCK_SIZE)
	var block_roll := _hash_cell(block, 41) % 1000
	if block_roll < 95:
		return E_BLOCKED
	if block_roll >= 95 and block_roll < 145:
		return E_WATER

	var ridge_roll := _hash_cell(block, 73) % 1000
	if ridge_roll < 90 and cell.y < MAP_H - 10:
		return E_MID
	return E_LOW

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
	return grid[cell.x][cell.y] != E_WATER and grid[cell.x][cell.y] != E_BLOCKED

func world_to_cell(world_position: Vector2) -> Vector2i:
	return layer_low.local_to_map(layer_low.to_local(world_position))

func cell_to_world(cell: Vector2i) -> Vector2:
	return layer_low.to_global(layer_low.map_to_local(cell))

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
	var path: Array[Vector2i] = []
	if not is_walkable_cell(start):
		start = nearest_walkable_cell(start)
	if not is_walkable_cell(target):
		target = nearest_walkable_cell(target)
	if not is_walkable_cell(start) or not is_walkable_cell(target):
		return path
	for point in _pathfinder.get_id_path(start, target):
		path.append(point)
	if not path.is_empty() and path[0] == start:
		path.pop_front()
	return path

func find_path_world(start_world: Vector2, target_world: Vector2) -> Array[Vector2]:
	var world_path: Array[Vector2] = []
	for cell in find_path_cells(world_to_cell(start_world), world_to_cell(target_world)):
		world_path.append(cell_to_world(cell))
	return world_path

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
			_pathfinder.set_point_solid(cell, not is_walkable_cell(cell))
			if is_walkable_cell(cell):
				_pathfinder.set_point_weight_scale(cell, get_movement_cost(cell))

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
	var reserved_rects: Array[Rect2i] = []

	var base_1_rect := _find_plot_rect(Vector2i(8, 6), [E_HIGH, E_MID], reserved_rects, 220, Vector2(0.2, 0.18))
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
	var base_2_rect := _find_plot_rect(Vector2i(11, 8), [E_MID, E_LOW], reserved_rects, 220, Vector2(0.25, 0.62))
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
	var base_3_rect := _find_plot_rect(Vector2i(13, 7), [E_LOW, E_MID], reserved_rects, 260, Vector2(0.72, 0.78))
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
		match String(plot.get("kind", "")):
			"base":
				_stamp_base_plot(plot)
			"quest":
				_stamp_hollow_plot(plot, "tower_wall", "tower_floor")
			"enemy_outpost":
				_stamp_hollow_plot(plot, "bandit_wall", "bandit_floor")

func _stamp_base_plot(plot: Dictionary) -> void:
	var rect: Rect2i = plot["rect"]
	var floor_elevation := _dominant_elevation_near(rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2))
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not is_in_bounds(cell):
				continue
			grid[x][y] = floor_elevation
			feature_grid[x][y] = "base_floor"
	for economy_cell in plot.get("economy_spaces", []):
		if is_in_bounds(economy_cell):
			grid[economy_cell.x][economy_cell.y] = floor_elevation
			feature_grid[economy_cell.x][economy_cell.y] = "economy_space"

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

	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			var pos = Vector2i(x, y)

			match e:
				E_BLOCKED:
					layer_low.set_cell(pos, pick("foliage"), Vector2i(0,0))
				E_WATER:
					# Water sits on low layer
					layer_low.set_cell(pos, pick("water"), Vector2i(0,0))
				E_LOW:
					layer_low.set_cell(pos, pick("low_ground"), Vector2i(0,0))
				E_MID:
					# Paint low ground underneath for visual fill
					layer_low.set_cell(pos, pick("low_ground"), Vector2i(0,0))
					# Paint mid ground on mid layer (elevated)
					layer_mid.set_cell(pos, pick("mid_ground"), Vector2i(0,0))
				E_HIGH:
					# Fill all three layers for solid block appearance
					layer_low.set_cell(pos, pick("low_ground"), Vector2i(0,0))
					layer_mid.set_cell(pos, pick("mid_ground"), Vector2i(0,0))
					layer_high.set_cell(pos, pick("high_ground"), Vector2i(0,0))
				E_RAMP:
					# Ramp: low + mid only, represents the slope
					layer_low.set_cell(pos, pick("low_ground"), Vector2i(0,0))
					layer_mid.set_cell(pos, pick("path"), Vector2i(0,0))

	_paint_objects()
	_paint_plots()

func _paint_objects() -> void:
	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			if e == E_WATER or e == E_BLOCKED: continue
			var pos = Vector2i(x, y)

			# Foliage border on low layer
			if x <= 3 or x >= MAP_W-4 or y <= 3 or y >= MAP_H-4:
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

			elif e == E_RAMP and (x + y) % 2 == 0:
				layer_mid.set_cell(pos, pick("path_slope"), Vector2i(0,0))

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
						if _is_rect_edge(cell, rect) and _rng.chance_per_mille(360):
							_set_plot_cell(cell, "foliage")
					"economy_space":
						_set_plot_cell(cell, "economy_plot")
					"objective":
						if _rng.chance_per_mille(520):
							_set_plot_cell(cell, "corrupted")
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

	for y in range(20, 42):
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
		},
		"plot_layout": _get_plot_layout_summary(),
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
