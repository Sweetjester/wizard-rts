extends SceneTree

# Times a single flow-field build on the real shipping map.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "flowfield-bench", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 4:
		await process_frame
	var mg: Node = scene.get_node("MapGenerator")
	var tower_cell: Vector2i = Vector2i(48, 48)
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and int(structure.get("owner_player_id")) == 1 and str(structure.get("archetype")) == "wizard_tower":
			tower_cell = mg.call("world_to_cell", (structure as Node2D).global_position)
			break
	tower_cell = mg.call("nearest_walkable_cell", tower_cell + Vector2i(4, 4), 20)
	print("  target cell: ", tower_cell, " traversable=", mg.call("_is_path_traversable_cell", tower_cell))
	var total := 0.0
	var runs := 5
	for i in runs:
		mg.call("_invalidate_path_cache")
		mg.set("_flow_field_cache", {})
		var t0 := Time.get_ticks_usec()
		var field: Dictionary = mg.call("_build_flow_field", tower_cell)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		print("  run %d: %.1f ms  cells_reached=%d" % [i + 1, ms, int(field.get("cells_reached", 0))])
	print("[FlowFieldBench] mean %.1f ms over %d runs (target cell %s)" % [total / float(runs), runs, tower_cell])
	quit(0)
