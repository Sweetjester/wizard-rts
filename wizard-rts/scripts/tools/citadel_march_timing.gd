extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	# Map generation alone, no bridge, no 3D view.
	for entry in [["seeded_grid_frontier", 96], ["citadel_march", 192]]:
		var session := root.get_node_or_null("GameSession")
		if session != null:
			session.call("start_new_game", "timing-%s" % entry[0], "bad_kon_willow", entry[0])
		var generator: Node = load("res://scripts/map/map_generator.gd").new()
		# MapGenerator needs its tilemap siblings, so time the real scene instead.
		generator.free()
		var started := Time.get_ticks_msec()
		var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
		root.add_child(scene)
		for _i in 3:
			await process_frame
		var gen_ms := Time.get_ticks_msec() - started
		var bridge: Node = scene.get_node_or_null("BlockNavBridge")
		var bridge_started := Time.get_ticks_msec()
		for _i in 40:
			await process_frame
		var bridge_ms := Time.get_ticks_msec() - bridge_started
		var world = bridge.get("world")
		print("[Timing] %-22s scene+gen %5d ms | bridge+place %5d ms | nodes %d | placements %d" % [
			entry[0], gen_ms, bridge_ms, 0 if world == null else world.node_count(),
			0 if world == null else world.placements().size()])
		scene.queue_free()
		await process_frame
		await process_frame
	quit(0)
