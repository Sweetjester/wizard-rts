extends Node

# ── CONFIG ─────────────────────────────────────────────────────────────────────
const MAP_W = 50
const MAP_H = 50

const E_WATER = -1
const E_LOW   =  0
const E_MID   =  1
const E_HIGH  =  2
const E_RAMP  =  3

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

# ── STATE ──────────────────────────────────────────────────────────────────────
var layer_low:  TileMapLayer
var layer_mid:  TileMapLayer
var layer_high: TileMapLayer
var T: Dictionary = {}
var grid: Array = []

var spawn_positions: Array = []
var enemy_spawns:    Array = []
var chokepoints:     Array = []
var economy_zones:   Array = []

# ── INIT ───────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer_low  = get_parent().get_node("TileMapLow")
	layer_mid  = get_parent().get_node("TileMapMid")
	layer_high = get_parent().get_node("TileMapHigh")
	_load_tiles()
	_build_grid()
	_paint()
	_register_zones()
	print("[MapGenerator] Sunken Grove 50x50 complete")
	print("[MapGenerator] Spawns:", spawn_positions.size(),
		"| Enemies:", enemy_spawns.size(),
		"| Chokepoints:", chokepoints.size())

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
		return T[terrain][randi() % T[terrain].size()]
	return T.get("low_ground", [0])[0]

# ── GRID ───────────────────────────────────────────────────────────────────────
func _build_grid() -> void:
	grid.clear()
	for x in MAP_W:
		grid.append([])
		for y in MAP_H:
			grid[x].append(_calc_elev(x, y))

func _calc_elev(x: int, y: int) -> int:
	if x <= 1 or x >= MAP_W-2 or y <= 1 or y >= MAP_H-2:
		return E_WATER
	var dx = float(x - LK_CX)
	var dy = float(y - LK_CY)
	if (dx*dx)/(LK_RX*LK_RX) + (dy*dy)/(LK_RY*LK_RY) <= 1.0:
		return E_WATER
	if x >= HG_X1 and x <= HG_X2 and y >= HG_Y1 and y <= HG_Y2:
		if y == HG_Y2 and x >= CP_X1 and x <= CP_X2:
			return E_MID
		return E_HIGH
	if y == RAMP_Y and x >= CP_X1 and x <= CP_X2:
		return E_RAMP
	if x >= MG_X1 and x <= MG_X2 and y >= MG_Y1 and y <= MG_Y2:
		return E_MID
	return E_LOW

func g(x: int, y: int) -> int:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H: return E_LOW
	return grid[x][y]

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
					layer_mid.set_cell(pos, pick("mid_ground"), Vector2i(0,0))

	_paint_objects()

func _paint_objects() -> void:
	for x in MAP_W:
		for y in MAP_H:
			var e = grid[x][y]
			if e == E_WATER: continue
			var pos = Vector2i(x, y)

			# Foliage border on low layer
			if x <= 3 or x >= MAP_W-4 or y <= 3 or y >= MAP_H-4:
				layer_low.set_cell(pos, pick("foliage"), Vector2i(0,0))
				continue

			# Economy plot 1 — high ground plateau (easy)
			if e == E_HIGH and x >= 21 and x <= 29 and y >= 8 and y <= 12:
				layer_high.set_cell(pos, pick("economy_plot"), Vector2i(0,0))

			# Economy plot 2 — mid ground west (medium)
			elif e == E_MID and x >= 10 and x <= 16 and y >= 24 and y <= 28:
				layer_mid.set_cell(pos, pick("economy_plot"), Vector2i(0,0))

			# Economy plot 3 — low ground south bowl (hard)
			elif e == E_LOW and x >= 21 and x <= 29 and y >= 40 and y <= 44:
				layer_low.set_cell(pos, pick("economy_plot"), Vector2i(0,0))

			# Corrupted scatter on low ground
			elif e == E_LOW and (x*7+y*11)%29==0:
				layer_low.set_cell(pos, pick("corrupted"), Vector2i(0,0))

			# Decoration scatter on mid ground
			elif e == E_MID and (x*5+y*13)%37==0:
				layer_mid.set_cell(pos, pick("decoration"), Vector2i(0,0))

# ── ZONES ──────────────────────────────────────────────────────────────────────
func _register_zones() -> void:
	for x in range(21, 30):
		for y in range(33, 38):
			if grid[x][y] == E_MID:
				spawn_positions.append(Vector2i(x, y))

	for x in range(HG_X1, HG_X2+1):
		if grid[x][2] != E_WATER:
			enemy_spawns.append(Vector2i(x, 2))

	for x in range(5, MAP_W-5):
		if grid[x][MAP_H-4] == E_LOW:
			enemy_spawns.append(Vector2i(x, MAP_H-4))

	for y in range(20, 42):
		if g(3, y) >= E_LOW:
			enemy_spawns.append(Vector2i(3, y))
		if g(MAP_W-4, y) >= E_LOW:
			enemy_spawns.append(Vector2i(MAP_W-4, y))

	for x in range(CP_X1, CP_X2+1):
		chokepoints.append(Vector2i(x, CP_Y))
		chokepoints.append(Vector2i(x, RAMP_Y))

	economy_zones = [
		{"rect": Rect2i(21,8,8,4),  "difficulty": 0.3, "label": "High ground — easy"},
		{"rect": Rect2i(10,24,6,4), "difficulty": 0.6, "label": "Mid west — medium"},
		{"rect": Rect2i(21,40,8,4), "difficulty": 0.9, "label": "South bowl — hard"},
	]

func get_spawn_position() -> Vector2i:
	if spawn_positions.is_empty():
		return Vector2i(MAP_W/2, MAP_H/2)
	return spawn_positions[randi() % spawn_positions.size()]

func get_chokepoints() -> Array:
	return chokepoints

func get_economy_zones() -> Array:
	return economy_zones
