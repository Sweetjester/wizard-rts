extends Node

const MAP_WIDTH  = 50
const MAP_HEIGHT = 50

var tilemaplayer: TileMapLayer

var TILE_LOW_GROUND   = []
var TILE_MID_GROUND   = []
var TILE_HIGH_GROUND  = []
var TILE_WATER        = []
var TILE_CLIFF        = []
var TILE_FOLIAGE      = []
var TILE_ECONOMY_PLOT = []
var TILE_CORRUPTED    = []

func _ready() -> void:
	tilemaplayer = get_parent().get_node("TileMapLayer")
	_discover_tile_sources()
	generate_sunken_grove()

func _discover_tile_sources() -> void:
	var tileset = tilemaplayer.tile_set
	if tileset == null:
		push_error("[MapGenerator] No TileSet found")
		return

	for i in tileset.get_source_count():
		var source_id = tileset.get_source_id(i)
		var source = tileset.get_source(source_id)
		if source == null:
			continue
		var tex = source.texture
		if tex == null:
			continue
		var name = tex.resource_path.get_file().to_lower()

		if "low_ground" in name:
			TILE_LOW_GROUND.append(source_id)
		elif "mid_ground" in name:
			TILE_MID_GROUND.append(source_id)
		elif "high_ground" in name:
			TILE_HIGH_GROUND.append(source_id)
		elif "water" in name:
			TILE_WATER.append(source_id)
		elif "cliff" in name:
			TILE_CLIFF.append(source_id)
		elif "foliage" in name:
			TILE_FOLIAGE.append(source_id)
		elif "economy" in name:
			TILE_ECONOMY_PLOT.append(source_id)
		elif "corrupted" in name:
			TILE_CORRUPTED.append(source_id)

		if not source.has_tile(Vector2i(0, 0)):
			source.create_tile(Vector2i(0, 0))

	print("[MapGenerator] Low: ", TILE_LOW_GROUND)
	print("[MapGenerator] Mid: ", TILE_MID_GROUND)
	print("[MapGenerator] High: ", TILE_HIGH_GROUND)
	print("[MapGenerator] Water: ", TILE_WATER)

func pick(arr: Array) -> int:
	if arr.is_empty():
		return TILE_LOW_GROUND[0] if not TILE_LOW_GROUND.is_empty() else 0
	return arr[randi() % arr.size()]

func generate_sunken_grove() -> void:
	if TILE_LOW_GROUND.is_empty():
		push_error("[MapGenerator] Tiles not discovered")
		return
	tilemaplayer.clear()
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var source_id = get_tile_for_position(x, y)
			tilemaplayer.set_cell(Vector2i(x, y), source_id, Vector2i(0, 0))
	print("[MapGenerator] Sunken Grove generated")

func get_tile_for_position(x: int, y: int) -> int:
	var cx = MAP_WIDTH  / 2.0
	var cy = MAP_HEIGHT / 2.0
	var dx = x - cx
	var dy = y - cy

	if x <= 1 or x >= MAP_WIDTH - 2 or y <= 1 or y >= MAP_HEIGHT - 2:
		return pick(TILE_FOLIAGE)

	if dy < -cy * 0.55 and abs(dx) < MAP_WIDTH * 0.18:
		return pick(TILE_HIGH_GROUND)

	if dy < -cy * 0.25 and abs(dx) < MAP_WIDTH * 0.35:
		return pick(TILE_HIGH_GROUND)

	if dy < -cy * 0.1 and abs(dx) > MAP_WIDTH * 0.28 and abs(dx) < MAP_WIDTH * 0.38:
		return pick(TILE_CLIFF)

	if dx < -MAP_WIDTH * 0.2 and dy > cy * 0.1 and dy < cy * 0.45:
		return pick(TILE_WATER)

	if dx > MAP_WIDTH * 0.2 and dy < -cy * 0.05 and dy > -cy * 0.35:
		return pick(TILE_WATER)

	if dx > -MAP_WIDTH * 0.28 and dx < -MAP_WIDTH * 0.1 and dy > -cy * 0.1 and dy < cy * 0.1:
		return pick(TILE_ECONOMY_PLOT)

	if abs(dx) < MAP_WIDTH * 0.15 and dy > cy * 0.25 and dy < cy * 0.45:
		return pick(TILE_ECONOMY_PLOT)

	if abs(dx) < MAP_WIDTH * 0.3 and abs(dy) < cy * 0.3:
		return pick(TILE_MID_GROUND)

	if abs(dx) > MAP_WIDTH * 0.38 and abs(dy) < cy * 0.4:
		return pick(TILE_FOLIAGE)

	return pick(TILE_LOW_GROUND)
