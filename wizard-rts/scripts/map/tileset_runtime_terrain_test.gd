extends Node2D

const GRASS_TERRAIN_SET := 0
const GRASS_TERRAIN_ID := 0
const CLIFF_TERRAIN_SET := 1
const CLIFF_TERRAIN_ID := 0
const WATER_TERRAIN_SET := 2
const WATER_TERRAIN_ID := 0
const ROAD_TERRAIN_SET := 3
const ROAD_TERRAIN_ID := 0

const TEST_SIZE := Vector2i(40, 40)
const TERRAIN_COORDINATES := {
	"grass": {
		"source_id": 1,
		"terrain_set": GRASS_TERRAIN_SET,
		"terrain_id": GRASS_TERRAIN_ID,
		"atlas": [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		],
	},
	"cliff": {
		"source_id": 1,
		"terrain_set": CLIFF_TERRAIN_SET,
		"terrain_id": CLIFF_TERRAIN_ID,
		"atlas": [
			Vector2i(0, 3), Vector2i(1, 3),
			Vector2i(5, 0), Vector2i(6, 0), Vector2i(6, 3), Vector2i(6, 4),
		],
	},
	"water": {
		"source_id": 0,
		"terrain_set": WATER_TERRAIN_SET,
		"terrain_id": WATER_TERRAIN_ID,
		"atlas": [Vector2i(0, 0)],
	},
	"road": {
		"source_id": 40,
		"terrain_set": ROAD_TERRAIN_SET,
		"terrain_id": ROAD_TERRAIN_ID,
		"atlas": [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		],
	},
}

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	generate_test_island()
	camera.position = Vector2(TEST_SIZE) * 32.0

func generate_test_island() -> void:
	terrain_layer.clear()

	var water_cells: Array[Vector2i] = []
	var grass_cells: Array[Vector2i] = []
	var road_cells: Array[Vector2i] = []

	for x in range(TEST_SIZE.x):
		for y in range(TEST_SIZE.y):
			var cell := Vector2i(x, y)
			water_cells.append(cell)
			if _is_island_cell(cell):
				grass_cells.append(cell)

	for x in range(8, 32):
		for y in range(19, 22):
			var road_cell := Vector2i(x, y)
			if _is_island_cell(road_cell):
				road_cells.append(road_cell)

	terrain_layer.set_cells_terrain_connect(water_cells, WATER_TERRAIN_SET, WATER_TERRAIN_ID, false)
	terrain_layer.set_cells_terrain_connect(grass_cells, GRASS_TERRAIN_SET, GRASS_TERRAIN_ID, false)
	terrain_layer.set_cells_terrain_connect(road_cells, ROAD_TERRAIN_SET, ROAD_TERRAIN_ID, false)

	_print_debug(water_cells.size(), grass_cells.size(), road_cells.size())

func _is_island_cell(cell: Vector2i) -> bool:
	var center := Vector2(20.0, 20.0)
	var delta := (Vector2(cell) - center) / Vector2(13.5, 9.5)
	var ellipse := delta.length_squared()
	var wobble := sin(float(cell.x) * 0.75) * 0.08 + cos(float(cell.y) * 0.55) * 0.08
	if ellipse > 1.0 + wobble:
		return false
	if cell.x < 7 or cell.x > 33 or cell.y < 8 or cell.y > 31:
		return false
	return true

func _print_debug(water_count: int, grass_count: int, road_count: int) -> void:
	var tile_set := terrain_layer.tile_set
	print("[TileSetRuntimeTerrainTest] TileSet: ", tile_set.resource_path if tile_set != null else "<missing>")
	print("[TileSetRuntimeTerrainTest] water cells=", water_count, " terrain_set=", WATER_TERRAIN_SET, " terrain=", WATER_TERRAIN_ID)
	print("[TileSetRuntimeTerrainTest] grass cells=", grass_count, " terrain_set=", GRASS_TERRAIN_SET, " terrain=", GRASS_TERRAIN_ID)
	print("[TileSetRuntimeTerrainTest] road cells=", road_count, " terrain_set=", ROAD_TERRAIN_SET, " terrain=", ROAD_TERRAIN_ID)
	print("[TileSetRuntimeTerrainTest] cliff terrain available terrain_set=", CLIFF_TERRAIN_SET, " terrain=", CLIFF_TERRAIN_ID)
	if tile_set == null:
		push_error("[TileSetRuntimeTerrainTest] Terrain layer has no TileSet.")
		return
	for terrain_set_id in range(tile_set.get_terrain_sets_count()):
		for terrain_id in range(tile_set.get_terrains_count(terrain_set_id)):
			print("[TileSetRuntimeTerrainTest] terrain_set=", terrain_set_id, " terrain=", terrain_id, " name=", tile_set.get_terrain_name(terrain_set_id, terrain_id))
	for terrain_name in TERRAIN_COORDINATES.keys():
		var info: Dictionary = TERRAIN_COORDINATES[terrain_name]
		print(
			"[TileSetRuntimeTerrainTest] terrain atlas ",
			terrain_name,
			" source=",
			info["source_id"],
			" terrain_set=",
			info["terrain_set"],
			" terrain=",
			info["terrain_id"],
			" coords=",
			info["atlas"]
		)
