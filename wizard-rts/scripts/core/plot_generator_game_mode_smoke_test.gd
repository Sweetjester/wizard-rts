extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "plot-mode-smoke", "bad_kon_willow", "plot_generator_test")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	if str(map.get("map_type_id")) != "plot_generator_test":
		push_error("Expected plot_generator_test, got %s" % map.get("map_type_id"))
		quit(1)
		return
	if map.get_chokepoints().size() < 2:
		push_error("Plot generator test should expose at least two connection anchors")
		quit(1)
		return
	var walkable_count := 0
	for x in map.MAP_W:
		for y in map.MAP_H:
			if map.is_walkable_cell(Vector2i(x, y)):
				walkable_count += 1
	if walkable_count < 180:
		push_error("Plot generator test should import enough walkable island cells, got %s" % walkable_count)
		quit(1)
		return
	var spawn_cell: Vector2i = map.get_spawn_position()
	if not map.is_walkable_cell(spawn_cell):
		push_error("Plot generator test spawn cell is not walkable: %s" % spawn_cell)
		quit(1)
		return
	var wizard := scene.get_node_or_null("Wizard")
	if wizard == null:
		push_error("Plot generator test should spawn a wizard observer on the island")
		quit(1)
		return
	print("[PlotGeneratorGameModeSmokeTest] seed=", map.get_seed_value(), " walkable=", walkable_count, " anchors=", map.get_chokepoints().size(), " spawn=", spawn_cell)
	quit(0)
