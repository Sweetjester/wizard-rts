class_name PlotGenerator
extends Node2D

const MapPlotConfigResource := preload("res://scripts/map/plots/MapPlotConfig.gd")
const TILE_SIZE := Vector2i(64, 64)
const WATER_SOURCE := 0
const TERRAIN_SOURCE := 1
const FOAM_SOURCE := 2
const BUSH_SOURCE_START := 10
const ROCK_SOURCE_START := 20
const WATER_ROCK_SOURCE_START := 30
const TERRAIN_VARIANT_SOURCE_START := 40

const TERRAIN_GRASS_SET := 0
const TERRAIN_GRASS := 0
const TERRAIN_CLIFF_SET := 1
const TERRAIN_CLIFF := 0
const CLIFF_FACE_TILES := [
	Vector2i(5, 4),
	Vector2i(6, 4),
	Vector2i(7, 4),
	Vector2i(8, 4),
	Vector2i(5, 5),
	Vector2i(6, 5),
	Vector2i(7, 5),
	Vector2i(8, 5),
]
const RAMP_LEFT_TILE := Vector2i(0, 4)
const RAMP_RIGHT_TILE := Vector2i(3, 4)
const GRASS_CENTER_TILES := [
	Vector2i(1, 1),
	Vector2i(6, 1),
	Vector2i(7, 1),
]

const WATER_TEXTURE := preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Water Background color.png")
const TERRAIN_TEXTURE := preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png")
const TERRAIN_VARIANT_TEXTURES := [
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color2.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color3.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color4.png"),
	preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color5.png"),
]
const FOAM_TEXTURE := preload("res://Tiny Swords/Tiny Swords (Free Pack)/Terrain/Tileset/Water Foam.png")
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
var water_foam_layer: TileMapLayer
var grass_layer: TileMapLayer
var cliff_faces_layer: TileMapLayer
var cliff_tops_layer: TileMapLayer
var overhang_layer: TileMapLayer
var decoration_layer: TileMapLayer

var _tile_set: TileSet
var _config: Resource
var _rng := RandomNumberGenerator.new()
var _grass_grid: Array = []
var _cliff_grid: Array = []
var _ramp_grid: Array = []
var _ramp_tiles: Dictionary = {}
var _walkable_grid: Array = []
var _elevation_grid: Array = []
var _connection_anchors: Array[Vector2i] = []

@export var auto_generate_on_ready := false

func _ready() -> void:
	_ensure_layers()
	if auto_generate_on_ready and _config == null:
		var default_config: Resource = MapPlotConfigResource.new()
		generate(default_config)

func generate(config: Resource, offset: Vector2i = Vector2i.ZERO) -> void:
	_config = config
	_config.world_offset = offset
	_rng.seed = int(config.seed)
	_ensure_layers()
	_clear_layers()
	_grass_grid = _generate_landmass_shape(config.seed, config.size, config.landmass_roughness)
	_grass_grid = _largest_connected_component(_grass_grid)
	_grass_grid = _ensure_minimum_land(_grass_grid, config.min_land_tiles)
	_cliff_grid = _place_cliffs(_grass_grid, config)
	_ramp_grid = _place_ramps(_grass_grid, _cliff_grid, config)
	_build_metadata()
	_paint_water_base(config.size, offset)
	_paint_grass_terrain(_grass_grid, offset)
	_paint_ground_colour_patches(_grass_grid, _cliff_grid, offset)
	_paint_water_foam(_grass_grid, offset)
	_paint_cliff_terrain(_cliff_grid, offset)
	_paint_ramps(offset)
	_place_overhangs(_cliff_grid, config, offset)
	_scatter_decoration(_grass_grid, _cliff_grid, config, offset)
	_connection_anchors = _find_connection_anchors(_grass_grid, config, offset)

func get_connection_anchors() -> Array[Vector2i]:
	return _connection_anchors.duplicate()

func get_walkable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in _walkable_grid.size():
		for y in _walkable_grid[x].size():
			if _walkable_grid[x][y]:
				cells.append(Vector2i(x, y) + _config.world_offset)
	return cells

func get_ramp_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in _ramp_grid.size():
		for y in _ramp_grid[x].size():
			if _ramp_grid[x][y]:
				cells.append(Vector2i(x, y) + _config.world_offset)
	return cells

func get_local_bounds() -> Rect2i:
	if _config == null:
		return Rect2i()
	return Rect2i(_config.world_offset, _config.size)

func get_elevation_at(cell: Vector2i) -> int:
	var local: Vector2i = cell - _config.world_offset
	if not _in_bounds(local, _config.size):
		return -1
	return int(_elevation_grid[local.x][local.y])

func _ensure_layers() -> void:
	_tile_set = _build_tileset()
	water_layer = _get_or_create_layer("Water", 0)
	water_foam_layer = _get_or_create_layer("WaterFoam", 1)
	grass_layer = _get_or_create_layer("GrassLandmass", 2)
	cliff_faces_layer = _get_or_create_layer("CliffFaces", 3)
	cliff_tops_layer = _get_or_create_layer("CliffTops", 4)
	overhang_layer = _get_or_create_layer("Overhang", 5)
	decoration_layer = _get_or_create_layer("Decoration", 6)

func _get_or_create_layer(layer_name: String, layer_z: int) -> TileMapLayer:
	var layer := get_node_or_null(layer_name) as TileMapLayer
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = layer_name
		add_child(layer)
	layer.tile_set = _tile_set
	layer.z_index = layer_z
	return layer

func _clear_layers() -> void:
	for layer in [water_layer, water_foam_layer, grass_layer, cliff_faces_layer, cliff_tops_layer, overhang_layer, decoration_layer]:
		if layer != null:
			layer.clear()

func _build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_source(_single_tile_source(WATER_TEXTURE), WATER_SOURCE)
	tile_set.add_source(_atlas_source(TERRAIN_TEXTURE, TILE_SIZE), TERRAIN_SOURCE)
	tile_set.add_source(_atlas_source(FOAM_TEXTURE, TILE_SIZE), FOAM_SOURCE)
	for i in TERRAIN_VARIANT_TEXTURES.size():
		tile_set.add_source(_atlas_source(TERRAIN_VARIANT_TEXTURES[i], TILE_SIZE), TERRAIN_VARIANT_SOURCE_START + i)
	for i in BUSH_TEXTURES.size():
		tile_set.add_source(_atlas_source(BUSH_TEXTURES[i], TILE_SIZE), BUSH_SOURCE_START + i)
	for i in ROCK_TEXTURES.size():
		tile_set.add_source(_single_tile_source(ROCK_TEXTURES[i]), ROCK_SOURCE_START + i)
	for i in WATER_ROCK_TEXTURES.size():
		tile_set.add_source(_atlas_source(WATER_ROCK_TEXTURES[i], TILE_SIZE), WATER_ROCK_SOURCE_START + i)
	_configure_terrain_sets(tile_set)
	return tile_set

func _single_tile_source(texture: Texture2D) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
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

func _configure_terrain_sets(tile_set: TileSet) -> void:
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(TERRAIN_GRASS_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tile_set.add_terrain(TERRAIN_GRASS_SET)
	tile_set.set_terrain_name(TERRAIN_GRASS_SET, TERRAIN_GRASS, "grass")
	tile_set.set_terrain_color(TERRAIN_GRASS_SET, TERRAIN_GRASS, Color("#9FD88A"))
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(TERRAIN_CLIFF_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tile_set.add_terrain(TERRAIN_CLIFF_SET)
	tile_set.set_terrain_name(TERRAIN_CLIFF_SET, TERRAIN_CLIFF, "cliff")
	tile_set.set_terrain_color(TERRAIN_CLIFF_SET, TERRAIN_CLIFF, Color("#7AA7A7"))
	var terrain_source := tile_set.get_source(TERRAIN_SOURCE) as TileSetAtlasSource
	if terrain_source != null:
		for coord in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]:
			var grass_data := terrain_source.get_tile_data(coord, 0)
			if grass_data != null:
				grass_data.set_terrain_set(TERRAIN_GRASS_SET)
				grass_data.set_terrain(TERRAIN_GRASS)
		_set_peering(terrain_source, Vector2i(0, 0), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_right(), _peer_bottom(), _peer_bottom_right()])
		_set_peering(terrain_source, Vector2i(1, 0), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_left(), _peer_right(), _peer_bottom_left(), _peer_bottom(), _peer_bottom_right()])
		_set_peering(terrain_source, Vector2i(2, 0), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_left(), _peer_bottom_left(), _peer_bottom()])
		_set_peering(terrain_source, Vector2i(0, 1), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_top(), _peer_top_right(), _peer_right(), _peer_bottom_right(), _peer_bottom()])
		_set_peering(terrain_source, Vector2i(1, 1), TERRAIN_GRASS_SET, TERRAIN_GRASS, _all_peers())
		_set_peering(terrain_source, Vector2i(2, 1), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_top(), _peer_top_left(), _peer_left(), _peer_bottom_left(), _peer_bottom()])
		_set_peering(terrain_source, Vector2i(0, 2), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_top(), _peer_top_right(), _peer_right()])
		_set_peering(terrain_source, Vector2i(1, 2), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_left(), _peer_right(), _peer_top_left(), _peer_top(), _peer_top_right()])
		_set_peering(terrain_source, Vector2i(2, 2), TERRAIN_GRASS_SET, TERRAIN_GRASS, [_peer_top(), _peer_top_left(), _peer_left()])
		for coord in [Vector2i(5, 0), Vector2i(6, 0), Vector2i(6, 3), Vector2i(6, 4), Vector2i(0, 3), Vector2i(1, 3)]:
			var cliff_data := terrain_source.get_tile_data(coord, 0)
			if cliff_data != null:
				cliff_data.set_terrain_set(TERRAIN_CLIFF_SET)
				cliff_data.set_terrain(TERRAIN_CLIFF)
		_set_peering(terrain_source, Vector2i(5, 0), TERRAIN_CLIFF_SET, TERRAIN_CLIFF, _all_peers())
		_set_peering(terrain_source, Vector2i(6, 0), TERRAIN_CLIFF_SET, TERRAIN_CLIFF, [_peer_left(), _peer_right(), _peer_top(), _peer_top_left(), _peer_top_right()])
		_set_peering(terrain_source, Vector2i(6, 3), TERRAIN_CLIFF_SET, TERRAIN_CLIFF, [_peer_left(), _peer_right(), _peer_top(), _peer_top_left(), _peer_top_right()])
		_set_peering(terrain_source, Vector2i(6, 4), TERRAIN_CLIFF_SET, TERRAIN_CLIFF, [_peer_left(), _peer_right(), _peer_top(), _peer_top_left(), _peer_top_right()])
		_set_peering(terrain_source, Vector2i(0, 3), TERRAIN_CLIFF_SET, TERRAIN_CLIFF, [_peer_right(), _peer_top(), _peer_top_right()])
		_set_peering(terrain_source, Vector2i(1, 3), TERRAIN_CLIFF_SET, TERRAIN_CLIFF, [_peer_left(), _peer_top(), _peer_top_left()])
	# Godot's terrain data is resource metadata. The generator still routes grass and
	# cliff painting through the terrain layers; if editor terrain peering needs tuning,
	# the atlas coords below are the authoritative map.
	tile_set.set_meta("terrain_set_land", {
		"terrain": "grass",
		"source_id": TERRAIN_SOURCE,
		"center": Vector2i(1, 1),
		"top_left": Vector2i(0, 0),
		"top": Vector2i(1, 0),
		"top_right": Vector2i(2, 0),
		"left": Vector2i(0, 1),
		"right": Vector2i(2, 1),
		"bottom_left": Vector2i(0, 2),
		"bottom": Vector2i(1, 2),
		"bottom_right": Vector2i(2, 2),
	})
	tile_set.set_meta("terrain_set_cliff", {
		"terrain": "cliff",
		"source_id": TERRAIN_SOURCE,
		"top_center": Vector2i(6, 0),
		"face_center": Vector2i(6, 3),
		"face_bottom": Vector2i(6, 4),
		"overhang_left": Vector2i(0, 3),
		"overhang_right": Vector2i(1, 3),
	})

func _set_peering(source: TileSetAtlasSource, coord: Vector2i, terrain_set: int, terrain: int, peers: Array) -> void:
	var data := source.get_tile_data(coord, 0)
	if data == null:
		return
	data.set_terrain_set(terrain_set)
	data.set_terrain(terrain)
	for peer in peers:
		if data.is_valid_terrain_peering_bit(peer):
			data.set_terrain_peering_bit(peer, terrain)

func _all_peers() -> Array:
	return [_peer_top_left(), _peer_top(), _peer_top_right(), _peer_left(), _peer_right(), _peer_bottom_left(), _peer_bottom(), _peer_bottom_right()]

func _peer_top_left() -> int:
	return TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER

func _peer_top() -> int:
	return TileSet.CELL_NEIGHBOR_TOP_SIDE

func _peer_top_right() -> int:
	return TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER

func _peer_left() -> int:
	return TileSet.CELL_NEIGHBOR_LEFT_SIDE

func _peer_right() -> int:
	return TileSet.CELL_NEIGHBOR_RIGHT_SIDE

func _peer_bottom_left() -> int:
	return TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER

func _peer_bottom() -> int:
	return TileSet.CELL_NEIGHBOR_BOTTOM_SIDE

func _peer_bottom_right() -> int:
	return TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER

func _generate_landmass_shape(seed: int, size: Vector2i, roughness: float) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.095
	noise.fractal_octaves = 3
	var grid := _new_bool_grid(size, false)
	var center := Vector2(size) * 0.5
	var radius: float = minf(size.x, size.y) * _config.landmass_radius * 0.5
	for x in size.x:
		for y in size.y:
			var p := Vector2(x, y)
			var d := p.distance_to(center) / maxf(radius, 1.0)
			var n := (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var edge_score := 1.0 - d + (n - 0.5) * roughness
			grid[x][y] = edge_score > 0.03
	for i in _config.smoothing_passes:
		grid = _smooth_bool_grid(grid, size)
	return grid

func _smooth_bool_grid(grid: Array, size: Vector2i) -> Array:
	var next := _new_bool_grid(size, false)
	for x in size.x:
		for y in size.y:
			var neighbours := _count_neighbours(grid, Vector2i(x, y), size)
			next[x][y] = neighbours >= 5 or (grid[x][y] and neighbours >= 4)
	return next

func _count_neighbours(grid: Array, cell: Vector2i, size: Vector2i) -> int:
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n: Vector2i = cell + Vector2i(dx, dy)
			if _in_bounds(n, size) and grid[n.x][n.y]:
				count += 1
	return count

func _largest_connected_component(grid: Array) -> Array:
	var size := Vector2i(grid.size(), grid[0].size())
	var visited := _new_bool_grid(size, false)
	var best: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			if not grid[x][y] or visited[x][y]:
				continue
			var component := _flood_component(grid, visited, Vector2i(x, y), size)
			if component.size() > best.size():
				best = component
	var result := _new_bool_grid(size, false)
	for cell in best:
		result[cell.x][cell.y] = true
	return result

func _flood_component(grid: Array, visited: Array, start: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	visited[start.x][start.y] = true
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		result.append(cell)
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = cell + dir
			if _in_bounds(n, size) and grid[n.x][n.y] and not visited[n.x][n.y]:
				visited[n.x][n.y] = true
				queue.append(n)
	return result

func _ensure_minimum_land(grid: Array, min_tiles: int) -> Array:
	var size := Vector2i(grid.size(), grid[0].size())
	while _count_true(grid) < min_tiles:
		var candidates: Array[Vector2i] = []
		for x in range(2, size.x - 2):
			for y in range(2, size.y - 2):
				if not grid[x][y] and _count_neighbours(grid, Vector2i(x, y), size) >= 2:
					candidates.append(Vector2i(x, y))
		if candidates.is_empty():
			break
		var chosen := candidates[_rng.randi_range(0, candidates.size() - 1)]
		grid[chosen.x][chosen.y] = true
	return grid

func _place_cliffs(grass_grid: Array, config: Resource) -> Array:
	var size: Vector2i = config.size
	var cliff_grid := _new_bool_grid(size, false)
	var terraces: Array[Rect2i] = [
		_jitter_rect(Rect2i(6, 3, 11, 6), size, 2),
		_jitter_rect(Rect2i(18, 6, 12, 6), size, 2),
		_jitter_rect(Rect2i(8, 14, 13, 5), size, 2),
		_jitter_rect(Rect2i(24, 15, 8, 5), size, 1),
	]
	for rect in terraces:
		_stamp_organic_terrace(cliff_grid, grass_grid, rect, size, config.cliff_edge_clearance)
	return cliff_grid

func _jitter_rect(rect: Rect2i, size: Vector2i, amount: int) -> Rect2i:
	var position := rect.position + Vector2i(_rng.randi_range(-amount, amount), _rng.randi_range(-amount, amount))
	position.x = clampi(position.x, 2, size.x - rect.size.x - 2)
	position.y = clampi(position.y, 2, size.y - rect.size.y - 2)
	return Rect2i(position, rect.size)

func _stamp_organic_terrace(cliff_grid: Array, grass_grid: Array, rect: Rect2i, size: Vector2i, clearance: int) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell, size) or not grass_grid[x][y] or not _has_land_clearance(grass_grid, cell, size, clearance):
				continue
			var local := cell - rect.position
			var on_corner := (local.x == 0 or local.x == rect.size.x - 1) and (local.y == 0 or local.y == rect.size.y - 1)
			var edge_noise := _hash_cell(cell, 1709) % 1000
			if on_corner and edge_noise < 760:
				continue
			if (local.x == 0 or local.x == rect.size.x - 1 or local.y == 0 or local.y == rect.size.y - 1) and edge_noise < 160:
				continue
			cliff_grid[x][y] = true

func _place_ramps(grass_grid: Array, cliff_grid: Array, config: Resource) -> Array:
	var size: Vector2i = config.size
	var ramp_grid := _new_bool_grid(size, false)
	_ramp_tiles.clear()
	var candidates: Array[Vector2i] = []
	for x in range(1, size.x - 1):
		for y in range(1, size.y - 1):
			var cell := Vector2i(x, y)
			var above := cell + Vector2i.UP
			if grass_grid[x][y] and not cliff_grid[x][y] and cliff_grid[above.x][above.y]:
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _hash_cell(a, 2111) < _hash_cell(b, 2111)
	)
	var placed := 0
	for cell in candidates:
		if placed >= 4:
			break
		var clear := true
		for other_key in _ramp_tiles.keys():
			var other: Vector2i = other_key
			if cell.distance_to(other) < 6.0:
				clear = false
				break
		if not clear:
			continue
		ramp_grid[cell.x][cell.y] = true
		_ramp_tiles[cell] = RAMP_LEFT_TILE if (cell.x + cell.y + int(config.seed)) % 2 == 0 else RAMP_RIGHT_TILE
		placed += 1
	return ramp_grid

func _interior_land_cells(grass_grid: Array, size: Vector2i, clearance: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(clearance, size.x - clearance):
		for y in range(clearance, size.y - clearance):
			var cell := Vector2i(x, y)
			if grass_grid[x][y] and _has_land_clearance(grass_grid, cell, size, clearance):
				cells.append(cell)
	return cells

func _has_land_clearance(grass_grid: Array, cell: Vector2i, size: Vector2i, clearance: int) -> bool:
	for dx in range(-clearance, clearance + 1):
		for dy in range(-clearance, clearance + 1):
			var n := cell + Vector2i(dx, dy)
			if not _in_bounds(n, size) or not grass_grid[n.x][n.y]:
				return false
	return true

func _grow_blob(start: Vector2i, target_size: int, grass_grid: Array, occupied: Array, size: Vector2i, clearance: int) -> Array[Vector2i]:
	var blob: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var used := {}
	while not frontier.is_empty() and blob.size() < target_size:
		var index := _rng.randi_range(0, frontier.size() - 1)
		var cell := frontier[index]
		frontier.remove_at(index)
		if used.has(cell):
			continue
		used[cell] = true
		if not _in_bounds(cell, size) or occupied[cell.x][cell.y] or not grass_grid[cell.x][cell.y]:
			continue
		if not _has_land_clearance(grass_grid, cell, size, clearance):
			continue
		blob.append(cell)
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if _rng.randf() < 0.82:
				frontier.append(cell + dir)
	return blob

func _build_metadata() -> void:
	var size: Vector2i = _config.size
	_walkable_grid = _new_bool_grid(size, false)
	_elevation_grid = _new_int_grid(size, -1)
	for x in size.x:
		for y in size.y:
			_walkable_grid[x][y] = _grass_grid[x][y]
			if _ramp_grid[x][y]:
				_elevation_grid[x][y] = 1
			else:
				_elevation_grid[x][y] = 1 if _cliff_grid[x][y] else (0 if _grass_grid[x][y] else -1)

func _paint_water_base(size: Vector2i, offset: Vector2i) -> void:
	for x in size.x:
		for y in size.y:
			water_layer.set_cell(Vector2i(x, y) + offset, WATER_SOURCE, Vector2i.ZERO)

func _paint_grass_terrain(grass_grid: Array, offset: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	var size: Vector2i = _config.size
	for x in size.x:
		for y in size.y:
			if grass_grid[x][y]:
				cells.append(Vector2i(x, y) + offset)
	# Terrain metadata can be tuned in the TileSet editor later. This call keeps
	# generation routed through Godot's terrain workflow.
	grass_layer.set_cells_terrain_connect(cells, TERRAIN_GRASS_SET, TERRAIN_GRASS, false)

func _paint_ground_colour_patches(grass_grid: Array, cliff_grid: Array, offset: Vector2i) -> void:
	var size: Vector2i = _config.size
	for x in range(1, size.x - 1):
		for y in range(1, size.y - 1):
			var cell := Vector2i(x, y)
			if not grass_grid[x][y] or _touches_water(grass_grid, cell, size):
				continue
			if _hash_cell(cell, 4049) % 1000 > 170:
				continue
			var source: int = TERRAIN_VARIANT_SOURCE_START + int(_hash_cell(cell, 4051) % TERRAIN_VARIANT_TEXTURES.size())
			var atlas: Vector2i = GRASS_CENTER_TILES[int(_hash_cell(cell, 4057) % GRASS_CENTER_TILES.size())]
			cliff_tops_layer.set_cell(cell + offset, source, atlas)

func _paint_water_foam(grass_grid: Array, offset: Vector2i) -> void:
	var size: Vector2i = _config.size
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if grass_grid[x][y] or not _touches_grass(grass_grid, cell, size):
				continue
			water_foam_layer.set_cell(cell + offset, FOAM_SOURCE, Vector2i((_rng.randi() % 12), 0))

func _paint_cliff_terrain(cliff_grid: Array, offset: Vector2i) -> void:
	var size: Vector2i = _config.size
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if not cliff_grid[x][y]:
				continue
			if not _same(cliff_grid, cell + Vector2i.DOWN, size) and not _same(_ramp_grid, cell + Vector2i.DOWN, size):
				_paint_cliff_face(cell + Vector2i.DOWN + offset, cell)

func _paint_cliff_face(world_cell: Vector2i, local_source_cell: Vector2i) -> void:
	if not _in_bounds(world_cell - _config.world_offset, _config.size):
		return
	var variant_index: int = abs(local_source_cell.x * 17 + local_source_cell.y * 31 + int(_config.seed)) % CLIFF_FACE_TILES.size()
	cliff_faces_layer.set_cell(world_cell, TERRAIN_SOURCE, CLIFF_FACE_TILES[variant_index])

func _paint_ramps(offset: Vector2i) -> void:
	for local_cell in _ramp_tiles.keys():
		var atlas: Vector2i = _ramp_tiles[local_cell]
		cliff_faces_layer.set_cell(local_cell + offset, TERRAIN_SOURCE, atlas)

func _place_overhangs(cliff_grid: Array, config: Resource, offset: Vector2i) -> void:
	for x in config.size.x:
		for y in config.size.y:
			var cell := Vector2i(x, y)
			if cliff_grid[x][y] and not _same(cliff_grid, cell + Vector2i.DOWN, config.size) and not _same(_ramp_grid, cell + Vector2i.DOWN, config.size) and _rng.randf() < config.overhang_density:
				overhang_layer.set_cell(cell + Vector2i.DOWN + offset, TERRAIN_SOURCE, Vector2i(_rng.randi_range(5, 8), 5))

func _scatter_decoration(grass_grid: Array, cliff_grid: Array, config: Resource, offset: Vector2i) -> void:
	var blocked := _new_bool_grid(config.size, false)
	for x in config.size.x:
		for y in config.size.y:
			var cell := Vector2i(x, y)
			if grass_grid[x][y] and not cliff_grid[x][y] and not blocked[x][y]:
				if _rng.randf() < config.bush_density:
					var source := BUSH_SOURCE_START + _rng.randi_range(0, BUSH_TEXTURES.size() - 1)
					decoration_layer.set_cell(cell + offset, source, Vector2i(_rng.randi_range(0, 7), 0))
					_mark_spacing(blocked, cell, config.size, 2)
				elif _rng.randf() < config.rock_density:
					var rock_source := ROCK_SOURCE_START + _rng.randi_range(0, ROCK_TEXTURES.size() - 1)
					decoration_layer.set_cell(cell + offset, rock_source, Vector2i.ZERO)
					_mark_spacing(blocked, cell, config.size, 2)
			elif not grass_grid[x][y] and _touches_grass(grass_grid, cell, config.size) and _rng.randf() < config.water_rock_density:
				var water_rock_source := WATER_ROCK_SOURCE_START + _rng.randi_range(0, WATER_ROCK_TEXTURES.size() - 1)
				decoration_layer.set_cell(cell + offset, water_rock_source, Vector2i(_rng.randi_range(0, 15), 0))

func _find_connection_anchors(grass_grid: Array, config: Resource, offset: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for x in range(1, config.size.x - 1):
		for y in range(1, config.size.y - 1):
			var cell := Vector2i(x, y)
			if grass_grid[x][y] and not _cliff_grid[x][y] and _touches_water(grass_grid, cell, config.size):
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(config.size / 2) > b.distance_squared_to(config.size / 2)
	)
	var anchors: Array[Vector2i] = []
	for candidate in candidates:
		if anchors.size() >= config.max_anchor_count:
			break
		var far_enough := true
		for anchor in anchors:
			if candidate.distance_to(anchor - offset) < float(config.anchor_spacing):
				far_enough = false
				break
		if far_enough:
			anchors.append(candidate + offset)
	return anchors

func _mark_spacing(blocked: Array, cell: Vector2i, size: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var n: Vector2i = cell + Vector2i(dx, dy)
			if _in_bounds(n, size):
				blocked[n.x][n.y] = true

func _new_bool_grid(size: Vector2i, value: bool) -> Array:
	var grid: Array = []
	for x in size.x:
		var column: Array = []
		for y in size.y:
			column.append(value)
		grid.append(column)
	return grid

func _new_int_grid(size: Vector2i, value: int) -> Array:
	var grid: Array = []
	for x in size.x:
		var column: Array = []
		for y in size.y:
			column.append(value)
		grid.append(column)
	return grid

func _in_bounds(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

func _same(grid: Array, cell: Vector2i, size: Vector2i) -> bool:
	return _in_bounds(cell, size) and grid[cell.x][cell.y]

func _touches_grass(grid: Array, cell: Vector2i, size: Vector2i) -> bool:
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var n: Vector2i = cell + dir
		if _in_bounds(n, size) and grid[n.x][n.y]:
			return true
	return false

func _touches_water(grid: Array, cell: Vector2i, size: Vector2i) -> bool:
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var n: Vector2i = cell + dir
		if not _in_bounds(n, size) or not grid[n.x][n.y]:
			return true
	return false

func _count_true(grid: Array) -> int:
	var count := 0
	for column in grid:
		for value in column:
			if value:
				count += 1
	return count

func _hash_cell(cell: Vector2i, salt: int) -> int:
	var h := int(cell.x * 73856093) ^ int(cell.y * 19349663) ^ int(_config.seed) ^ salt
	h = int((h ^ (h >> 13)) * 1274126177)
	return abs(h)
