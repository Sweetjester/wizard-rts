extends SceneTree

# Puts Kon's Arcane Citadel on the real seeded_grid_frontier map and photographs
# it, so its scale against an actual playfield can be judged rather than guessed.

const OUT_DIR := "user://citadel_frontier_verification"
const CITADEL := &"kons_arcane_citadel_01"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "citadel-frontier", "bad_kon_willow", "seeded_grid_frontier", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 26:
		await process_frame

	var view: Node = scene.get_node_or_null("Map3DView")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	if view == null or bridge == null or terrain == null:
		push_error("Need Map3DView, BlockNavBridge and MapGenerator")
		quit(1)
		return

	var library: BlockStructureLibrary = bridge.get("library")
	var definition := library.get_definition(CITADEL)
	var map_size := Vector2i(int(terrain.get("MAP_W")), int(terrain.get("MAP_H")))
	print("[Frontier] map is %s cells; the citadel is %s" % [map_size, definition.dimensions])
	print("[Frontier] the castle covers %.0f%% of the playfield" % [
		100.0 * float(definition.dimensions.x * definition.dimensions.z)
		/ float(map_size.x * map_size.y)])

	# Placed at the origin because there is nowhere else it fits -- find_flat_site
	# cannot return a 96x96 site inside a 96x96 map with any margin at all.
	var origin := Vector2i(0, 0)
	bridge.call("place_and_block", CITADEL, origin, CITADEL)
	var placements: Array = bridge.get("world").placements()
	print("[Frontier] placements now: ", placements.size())
	# The view builds its block geometry from the bridge's signal, which already
	# fired at startup, so this placement is handed to it directly.
	view.call("_on_block_structures_placed", [{
		"id": CITADEL, "origin": origin,
		"base_level": int(terrain.call("get_height", origin)),
	}])
	for _i in 20:
		await process_frame

	# Fog off for the capture. The map starts unexplored and the fog plane now
	# sits above a 46-block castle, so every shot was solid black -- correct
	# behaviour, useless photograph.
	var fog_plane: Node = view.get_node_or_null("FogOfWar3D")
	if fog_plane != null:
		(fog_plane as Node3D).visible = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var shots := [
		{"cell": Vector2i(48, 48), "distance": 150.0, "name": "01_whole_map"},
		{"cell": Vector2i(48, 12), "distance": 60.0, "name": "02_gatehouse"},
		{"cell": Vector2i(20, 80), "distance": 55.0, "name": "03_tower_corner"},
	]
	for shot in shots:
		view.call("focus_on_sim_position", terrain.call("cell_to_world", shot["cell"]))
		view.call("set_camera_distance", shot["distance"])
		for _f in 12:
			await process_frame
		var image := root.get_texture().get_image()
		if image != null:
			image.save_png("%s/%s.png" % [OUT_DIR, shot["name"]])
	print("[Frontier] saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)
