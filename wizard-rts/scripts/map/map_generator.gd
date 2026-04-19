extends Node

const MAP_WIDTH  = 50
const MAP_HEIGHT = 50

const TILE_LOW_GROUND   = [22, 23]
const TILE_MID_GROUND   = [24, 25]
const TILE_HIGH_GROUND  = [20, 21]
const TILE_WATER        = [26, 27]
const TILE_CLIFF        = [14, 15]
const TILE_FOLIAGE      = [18, 19]
const TILE_ECONOMY_PLOT = [17]
const TILE_CORRUPTED    = [16]

var tilemap: TileMap

func _ready() -> void:
	tilemap = get_parent().get_node("TileMap")
	generate_sunken_grove()

func pick(arr: Array) -> int:
	return arr[randi() % arr.size()]

func generate_sunken_grove() -> void:
	tilemap.clear()
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var tile_id = get_tile_for_position(x, y)
			tilemap.set_cell(0, Vector2i(x, y), tile_id, Vector2i(0, 0))
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
		return TILE_ECONOMY_PLOT[0]

	if abs(dx) < MAP_WIDTH * 0.15 and dy > cy * 0.25 and dy < cy * 0.45:
		return TILE_ECONOMY_PLOT[0]

	if abs(dx) < MAP_WIDTH * 0.3 and abs(dy) < cy * 0.3:
		return pick(TILE_MID_GROUND)

	if abs(dx) > MAP_WIDTH * 0.38 and abs(dy) < cy * 0.4:
		return pick(TILE_FOLIAGE)

	return pick(TILE_LOW_GROUND)
