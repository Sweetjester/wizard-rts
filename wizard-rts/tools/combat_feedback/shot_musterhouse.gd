extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.get_node_or_null("GameSession").call("start_new_game", "muster-shot", "bad_kon_willow", "build_sandbox", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _i in 900:
		if bool(map.get("generation_complete")): break
		await process_frame
	for _i in 30: await process_frame
	var bs: Node = scene.get_node_or_null("BuildSystem")
	var view: Node = scene.get_node_or_null("Map3DView")
	var sel: Node = scene.get_node_or_null("SelectionController")
	scene.get_node_or_null("EconomyManager").call("add_resource", 1, &"bio", 999999)
	var origin := Vector2i(40, 40)
	bs.call("try_place_structure", 1, &"steel_musterhouse", origin)
	for _i in 12: await process_frame
	var house := {}
	var structures: Array = bs.get("structures")
	for i in structures.size():
		structures[i]["complete"] = true
		var n = structures[i].get("node", null)
		if n != null and is_instance_valid(n): n.set("complete", true)
		if StringName(structures[i].get("archetype", &"")) == &"steel_musterhouse": house = structures[i]
	var ranks: Dictionary = bs.get("researched_upgrade_ranks")
	ranks[&"steel_conscription"] = 4
	bs.set("researched_upgrade_ranks", ranks)
	for a in [&"poorper", &"steel_knight", &"mounted_knight"]:
		bs.call("produce_unit_from_structure", 1, a, house.get("node", null))
	if sel != null and house.get("node", null) != null:
		var chosen: Array[Node] = [house["node"] as Node]
		sel.call("_apply_selection", chosen)
	if view != null:
		view.call("focus_on_sim_position", map.call("cell_to_world", origin + Vector2i(4, 7)))
		view.call("set_camera_distance", 26.0)
	Engine.time_scale = 5.0
	for _i in 700: await process_frame
	Engine.time_scale = 1.0
	for _i in 30: await process_frame
	await RenderingServer.frame_post_draw
	var d := OS.get_environment("ART_SHOT_DIR")
	if d.is_empty(): d = "user://"
	root.get_texture().get_image().save_png(d.path_join("musterhouse_review.png"))
	print("[MusterhouseShot] PASS")
	quit(0)
