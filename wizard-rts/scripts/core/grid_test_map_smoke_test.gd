extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "grid-test-smoke", "bad_kon_willow", "grid_test_canvas")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	# Map generation is spread across frames now, so the scene is not playable
	# the instant it is added. Waits for the generator to say it is finished
	# rather than for a fixed frame count -- a count that happened to be long
	# enough on a 96x96 map is not a guarantee, it is a coincidence.
	for _gen_wait in 400:
		var _gen := scene.get_node_or_null("MapGenerator")
		if _gen == null or bool(_gen.get("generation_complete")):
			break
		await process_frame
	await process_frame
	await physics_frame
	var map: Node = scene.get_node("MapGenerator")
	if str(map.get("map_type_id")) != "grid_test_canvas":
		push_error("Expected grid_test_canvas, got %s" % map.get("map_type_id"))
		quit(1)
		return
	if int(map.get_plots().size()) < 4:
		push_error("Grid test map did not create expected plots")
		quit(1)
		return
	if int(map.get_economy_zones().size()) != 3:
		push_error("Grid test map should expose three economy zones")
		quit(1)
		return
	var target := Vector2i(20, 20)
	if not map.is_walkable_cell(target):
		push_error("Grid test map should be fully walkable before buildings")
		quit(1)
		return
	var build_system: Node = scene.get_node("BuildSystem")
	# Deliberately a GROUND building. Production and research are tower modules
	# (master doc section 39) and have no map position, so they cannot block a
	# cell or collide with anything -- using one here would assert nothing.
	if not build_system.call("try_place_structure", 1, &"bio_launcher", target):
		push_error("Expected test building placement to succeed")
		quit(1)
		return
	if map.is_walkable_cell(target):
		push_error("Placed building did not block its origin cell")
		quit(1)
		return
	if build_system.call("try_place_structure", 1, &"vinewall", target):
		push_error("Overlapping building placement should be rejected")
		quit(1)
		return
	print("[GridTestMapSmokeTest] map=", map.get_map_type_name(), " plots=", map.get_plots().size())
	quit(0)
