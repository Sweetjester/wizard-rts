extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "grid-test-smoke", "bad_kon_willow", "grid_test_canvas")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
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
	if not build_system.call("try_place_structure", 1, &"barracks", target):
		push_error("Expected test barracks placement to succeed")
		quit(1)
		return
	if map.is_walkable_cell(target):
		push_error("Placed building did not block its origin cell")
		quit(1)
		return
	if build_system.call("try_place_structure", 1, &"terrible_vault", target):
		push_error("Overlapping building placement should be rejected")
		quit(1)
		return
	print("[GridTestMapSmokeTest] map=", map.get_map_type_name(), " plots=", map.get_plots().size())
	quit(0)
