extends SceneTree
const OUT_DIR := "user://citadel_march_verification"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "march-shot", "bad_kon_willow", "citadel_march", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 60:
		await process_frame
	var view: Node = scene.get_node_or_null("Map3DView")
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var citadel_rect := Rect2i()
	for plot in terrain.get("plots"):
		if str(plot.get("block_structure", "")) != "":
			citadel_rect = plot.get("rect", Rect2i())
	print("[March] map %dx%d, citadel plot %s (%.0f%% of the map)" % [
		int(terrain.get("MAP_W")), int(terrain.get("MAP_H")), citadel_rect,
		100.0 * float(citadel_rect.size.x * citadel_rect.size.y)
			/ float(int(terrain.get("MAP_W")) * int(terrain.get("MAP_H")))])
	var fog: Node = view.get_node_or_null("FogOfWar3D")
	if fog != null:
		(fog as Node3D).visible = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for shot in [
		{"cell": Vector2i(96, 96), "d": 250.0, "n": "01_whole_march"},
		{"cell": citadel_rect.position + Vector2i(48, 48), "d": 130.0, "n": "02_citadel_in_place"},
	]:
		view.call("focus_on_sim_position", terrain.call("cell_to_world", shot["cell"]))
		view.call("set_camera_distance", shot["d"])
		for _f in 14:
			await process_frame
		var image := root.get_texture().get_image()
		if image != null:
			image.save_png("%s/%s.png" % [OUT_DIR, shot["n"]])
	print("[March] saved")
	quit(0)
