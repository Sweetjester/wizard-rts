extends Node

const MAP_W = 50
const MAP_H = 50

const E_WATER = -1
const E_LOW   =  0
const E_MID   =  1
const E_HIGH  =  2

var layer: TileMapLayer
var T: Dictionary = {}  # "terrain_type" -> [list of source IDs]
var grid: Array = []

var spawn_positions: Array = []
var enemy_spawns: Array = []
var chokepoints: Array = []
var economy_zones: Array = []

func _ready() -> void:
	layer = get_parent().get_node("TileMapLayer")
	_load_tiles()
	_build_grid()
	_paint()
	_register_zones()
	print("[MapGenerator] Sunken Grove complete")
	print("[MapGenerator] Spawns:", spawn_positions.size(),
		"Enemies:", enemy_spawns.size(),
		"Chokepoints:", chokepoints.size())

# ── TILE LOADING ───────────────────────────────────────────────────────────────
func _load_tiles() -> void:
	var ts = layer.tile_set
	if not ts: push_error("No TileSet"); return

	for i in ts.get_source_count():
		var sid = ts.get_source_id(i)
		var src = ts.get_source(sid)
		if not src or not src.texture: continue
		var fname = src.texture.resource_path.get_file().replace(".png", "")
		if not src.has_tile(Vector2i(0,0)):
			src.create_tile(Vector2i(0,0))
		# Extract terrain type from filename e.g. "low_ground_03" -> "low_ground"
		var parts = fname.split("_")
		var terrain = ""
		if parts.size() >= 2:
			# Last part is the number, rest is terrain type
			terrain = "_".join(parts.slice(0, parts.size()-1))
		if terrain != "":
			if not T.has(terrain):
				T[terrain] = []
			T[terrain].append(sid)

	print("[MapGenerator] Terrain types loaded:", T.keys())

func pick(terrain: String) -> int:
	if T.has(terrain) and not T[terrain].is_empty():
		return T[terrain][randi() % T[terrain].size()]
	if T.has("low_ground"):
		return T["low_ground"][0]
	return 0

# ── GRID ───────────────────────────────────────────────────────────────────────
func _build_grid() -> void:
	grid.clear()
	for x in MAP_W:
		grid.append([])
		for y in MAP_H:
			grid[x].append(_calc_elev(x, y))

func _calc_elev(x: int, y: int) -> int:
	# Hard water border
	if x <= 1 or x >= MAP_W-2 or y <= 1 or y >= MAP_H-2:
		return E_WATER

	# SW water channel
	if x >= 3 and x <= 11 and y >= 22 and y <= 38:
		return E_WATER

	# NE water channel
	if x >= 38 and x <= 46 and y >= 12 and y <= 28:
		return E_WATER

	# HIGH ground plateau — north centre with deliberate chokepoint gap
	# Plateau: x 17-33, y 4-17
	# Chokepoint gap cut at south face: x 22-28, y 15-17
	if x >= 17 and x <= 33 and y >= 4 and y <= 17:
		if y >= 15 and x >= 22 and x <= 28:
			return E_MID  # chokepoint gap
		return E_HIGH

	# MID ground — main base area
	if x >= 8 and x <= 42 and y >= 14 and y <= 38:
		return E_MID

	return E_LOW

func g(x: int, y: int) -> int:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H: return E_LOW
	return grid[x][y]

# ── PAINT ──────────────────────────────────────────────────────────────────────
func _paint() -> void:
	layer.clear()

	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			var tile_id = -1

			if e == E_WATER:
				tile_id = pick("water")
			elif e == E_LOW:
				tile_id = pick("low_ground")
			elif e == E_MID:
				tile_id = pick("mid_ground")
			elif e == E_HIGH:
				tile_id = pick("high_ground")

			if tile_id >= 0:
				layer.set_cell(Vector2i(x, y), tile_id, Vector2i(0,0))

	_paint_objects()

func _paint_objects() -> void:
	var cx = MAP_W / 2.0
	var cy = MAP_H / 2.0

	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			if e == E_WATER: continue
			var dx = float(x) - cx
			var dy = float(y) - cy

			# Foliage border — inner edge of map
			if x <= 3 or x >= MAP_W-4 or y <= 3 or y >= MAP_H-4:
				layer.set_cell(Vector2i(x,y), pick("foliage"), Vector2i(0,0))
				continue

			# Economy plot 1 — HIGH ground, easy (inside plateau, 1 plot)
			if e == E_HIGH and abs(dx) < 5 and dy < -cy*0.3 and dy > -cy*0.45:
				layer.set_cell(Vector2i(x,y), pick("economy_plot"), Vector2i(0,0))

			# Economy plot 2 — MID ground, medium exposure
			if e == E_MID and dx > -12 and dx < -3 and abs(dy) < 5:
				layer.set_cell(Vector2i(x,y), pick("economy_plot"), Vector2i(0,0))

			# Economy plot 3 — LOW ground, hard (exposed south bowl)
			if e == E_LOW and abs(dx) < 6 and dy > cy*0.2 and dy < cy*0.36:
				layer.set_cell(Vector2i(x,y), pick("economy_plot"), Vector2i(0,0))

			# Corrupted ground — around depleted zones (decorative for now)
			if e == E_LOW and (x*7+y*11)%31==0:
				layer.set_cell(Vector2i(x,y), pick("corrupted"), Vector2i(0,0))

			# Decoration scatter on mid ground
			if e == E_MID and (x*5+y*13)%37==0:
				layer.set_cell(Vector2i(x,y), pick("decoration"), Vector2i(0,0))

# ── ZONES ──────────────────────────────────────────────────────────────────────
func _register_zones() -> void:
	# Player spawn — mid ground, centre-south
	for x in range(20, 31):
		for y in range(28, 34):
			if grid[x][y] == E_MID:
				spawn_positions.append(Vector2i(x, y))

	# Enemy spawns — north edge behind plateau
	for x in range(17, 34):
		if grid[x][3] != E_WATER:
			enemy_spawns.append(Vector2i(x, 3))

	# Enemy spawns — south map edge
	for x in range(5, MAP_W-5):
		if grid[x][MAP_H-4] == E_LOW:
			enemy_spawns.append(Vector2i(x, MAP_H-4))

	# Chokepoints — the gap in the plateau south face
	for x in range(22, 29):
		for y in range(15, 18):
			if grid[x][y] == E_MID:
				chokepoints.append(Vector2i(x, y))

	# Economy zones
	economy_zones = [
		{"position": Vector2(25, 9),  "plots": 1, "difficulty": 0.3},
		{"position": Vector2(15, 24), "plots": 2, "difficulty": 0.6},
		{"position": Vector2(25, 33), "plots": 2, "difficulty": 0.9},
	]

func get_spawn_position() -> Vector2i:
	if spawn_positions.is_empty():
		return Vector2i(MAP_W/2, MAP_H/2)
	return spawn_positions[randi() % spawn_positions.size()]
