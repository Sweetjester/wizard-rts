extends SceneTree

# A look at Kon's Arena 2.0 with both armies in it, and a rough performance
# reading while they fight.
#
#   godot --path . --script tools/combat_feedback/shot_arena_2.gd
#
# ART_SHOT_DIR chooses the output directory. TARGET_UNITS sets the load.

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node_or_null("GameSession").call("start_new_game", "arena2-shot", "bad_kon_willow", "kon_arena_2", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _i in 900:
		if bool(map.get("generation_complete")): break
		await process_frame
	for _i in 30: await process_frame

	var director: Node = scene.get_node_or_null("WaveDirector")
	var view: Node = scene.get_node_or_null("Map3DView")
	var world: Node = scene.get_node_or_null("RTSWorld")
	var target := int(OS.get_environment("TARGET_UNITS")) if OS.get_environment("TARGET_UNITS") != "" else 400
	director.call("queue_ai_test_until", target)

	var centre: Vector2i = map.call("kon_arena_2_centre")
	if view != null and view.has_method("focus_on_sim_position"):
		view.call("focus_on_sim_position", map.call("cell_to_world", centre))
		if view.has_method("set_camera_distance"):
			view.call("set_camera_distance", float(OS.get_environment("ARENA_CAM")) if OS.get_environment("ARENA_CAM") != "" else 60.0)

	# Let them march in, then sample the frame time while the fight is on.
	Engine.time_scale = 6.0
	for _i in 1500:
		await process_frame
		if _in_contact(scene, map, centre): break
	Engine.time_scale = 1.0

	var frames := 0
	var worst := 0.0
	var total := 0.0
	for _i in 240:
		var t := Time.get_ticks_usec()
		await process_frame
		var ms := float(Time.get_ticks_usec() - t) / 1000.0
		total += ms
		worst = maxf(worst, ms)
		frames += 1
	print("[Arena2Shot] units=", world.call("count_units_all"),
		" kon=", world.call("count_units_for_owner", 2),
		" steel=", world.call("count_units_for_owner", 3),
		" mean_frame_ms=", snappedf(total / float(frames), 0.01),
		" worst_frame_ms=", snappedf(worst, 0.01))
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("ART_SHOT_DIR")
	if directory.is_empty(): directory = "user://"
	root.get_texture().get_image().save_png(directory.path_join("arena_2_review.png"))
	print("[Arena2Shot] PASS")
	quit(0)

func _in_contact(scene: Node, map: Node, centre: Vector2i) -> bool:
	var west := false
	var east := false
	for u in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.get("unit_archetype") == null: continue
		if Vector2(map.call("world_to_cell", u.global_position) - centre).length() > 18.0: continue
		match int(u.get("owner_player_id")):
			2: west = true
			3: east = true
	return west and east
