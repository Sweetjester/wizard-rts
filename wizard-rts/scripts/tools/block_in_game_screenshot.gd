extends SceneTree

# Captures the live 3D map focused on a block structure the nav bridge placed,
# so the in-game result can be checked rather than inferred from telemetry.

const OUT_DIR := "user://block_in_game_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "block-in-game-shot", "bad_kon_willow", "seeded_grid_frontier", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 24:
		await process_frame

	var view: Node = scene.get_node_or_null("Map3DView")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	if view == null or bridge == null:
		push_error("Need Map3DView and BlockNavBridge -- is render_3d on?")
		quit(1)
		return
	var placements: Array = bridge.get("world").placements()
	print("[BlockInGame] placements: ", placements.size())
	if placements.is_empty():
		push_error("No structures were placed on the live map")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for i in placements.size():
		var placement: Dictionary = placements[i]
		var origin: Vector2i = placement["origin"]
		print("[BlockInGame] %s at %s base_level=%s" % [placement["structure"], origin, placement["base_level"]])
		# Centre on the structure rather than its corner.
		var centre: Vector2 = terrain.call("cell_to_world", origin + Vector2i(6, 5))
		view.call("focus_on_sim_position", centre)
		view.call("set_camera_distance", 30.0)
		for _f in 12:
			await process_frame
		var image := root.get_texture().get_image()
		if image != null:
			image.save_png("%s/%s.png" % [OUT_DIR, placement["structure"]])
	print("[BlockInGame] saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)
