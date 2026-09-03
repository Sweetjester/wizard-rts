extends SceneTree
const OUT_DIR := "user://fog_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _shoot(false, "fog_2d.png")
	await _shoot(true, "fog_3d.png")
	print("[FogScreenshot] wrote to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)

func _shoot(use_3d: bool, file_name: String) -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "fog-shot", "bad_kon_willow", "seeded_grid_frontier", "", use_3d)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 10:
		await process_frame
	var map_generator: Node = scene.get_node("MapGenerator")
	var fog: Node = scene.get_node("FogOfWar")
	var tower: Node = null
	for s in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and str(s.get("archetype")) == "wizard_tower":
			tower = s
			break
	var origin: Vector2 = (tower as Node2D).global_position
	# A few scouts so there is a lit pocket with fog around it.
	for i in 5:
		var unit: Node = (load("res://scenes/units/terrible_thing.tscn") as PackedScene).instantiate()
		unit.set("owner_player_id", 1)
		scene.add_child(unit)
		unit.global_position = origin + Vector2(float(i) * 90.0 - 180.0, 140.0)
	for _i in 20:
		await process_frame
	fog.set("reveal_radius_cells", 40)
	for _p in 30:
		fog.call("_update_visibility")
	fog.call("_refresh_fog_texture")
	if use_3d:
		var view: Node = scene.get_node("Map3DView")
		view.call("focus_on_sim_position", origin)
		view.call("set_camera_distance", 34.0)
	else:
		var cam: Camera2D = scene.get_node("Camera2D")
		# Frame an actual cliff edge, not the base -- the base plot is flat, so a
		# shot centred there shows nothing the overlay is for.
		# Nearest cliff edge to the base, so it is inside the revealed area.
		var base_cell: Vector2i = map_generator.call("world_to_cell", origin)
		var cliff := origin
		var best := 1 << 30
		for cx in range(maxi(2, base_cell.x - 26), mini(int(map_generator.MAP_W) - 2, base_cell.x + 26)):
			for cy in range(maxi(2, base_cell.y - 26), mini(int(map_generator.MAP_H) - 2, base_cell.y + 26)):
				if not bool(map_generator.call("is_cliff_edge_cell", Vector2i(cx, cy))):
					continue
				var d: int = absi(cx - base_cell.x) + absi(cy - base_cell.y)
				if d < best:
					best = d
					cliff = map_generator.call("cell_to_world", Vector2i(cx, cy))
		print("[FogScreenshot] cliff at distance ", best, " cells from base")
		cam.position = cliff
		cam.zoom = Vector2(1.5, 1.5)
		# The plot/grid debug overlays paint large flat colour blocks that make
		# the fog impossible to judge in a screenshot.
		for debug_layer in ["GridOverlay", "PlotRenderer"]:  # not ImpassableOverlay
			var node := scene.get_node_or_null(debug_layer)
			if node != null and node is CanvasItem:
				(node as CanvasItem).visible = false
	for _i in 20:
		await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png("%s/%s" % [OUT_DIR, file_name])
		print("[FogScreenshot] saved ", file_name)
	scene.queue_free()
	await process_frame
	await process_frame
