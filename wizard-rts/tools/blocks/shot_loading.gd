extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "loading-shot", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	var shots := 0
	var frames := 0
	while frames < 400 and shots < 3:
		await process_frame
		frames += 1
		# Grab at roughly a third and two thirds of the way through, then at the end.
		if (frames == 5 or frames == 9) or (bool(terrain.get("generation_complete")) and shots < 3):
			await RenderingServer.frame_post_draw
			shots += 1
			root.get_texture().get_image().save_png("%s/phase_%d.png" % [OS.get_environment("SHOT_DIR"), shots])
			print("[ShotLoading] captured %d at frame %d" % [shots, frames])
			if bool(terrain.get("generation_complete")):
				break
	quit(0)
