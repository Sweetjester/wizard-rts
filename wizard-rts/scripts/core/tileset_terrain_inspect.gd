extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_print_tileset("Runtime main map", "res://assets/tiles/voxel/voxel_tileset.tres")
	_print_tileset("Tiny Swords plot resource", "res://resources/tilesets/tiny_swords_plot_tileset.tres")
	quit(0)

func _print_tileset(label: String, path: String) -> void:
	var tile_set := load(path) as TileSet
	print("[TileSetTerrainInspect] ", label)
	print("  resource path: ", path)
	if tile_set == null:
		print("  ERROR: TileSet could not be loaded")
		return
	var terrain_set_count := tile_set.get_terrain_sets_count()
	print("  terrain sets: ", terrain_set_count)
	if terrain_set_count <= 0:
		print("  ERROR: no terrain sets exist")
		return
	for terrain_set_id in range(terrain_set_count):
		var mode := tile_set.get_terrain_set_mode(terrain_set_id)
		var terrain_count := tile_set.get_terrains_count(terrain_set_id)
		print("  terrain_set_id: ", terrain_set_id, " mode: ", mode, " terrains: ", terrain_count)
		for terrain_id in range(terrain_count):
			print("    terrain_id: ", terrain_id, " name: ", tile_set.get_terrain_name(terrain_set_id, terrain_id))
