extends SceneTree

# Windowed verification for the 3D game mode. Boots the REAL shipping scene with
# GameSession.render_3d on, spawns some units, and saves a screenshot.
const OUT_DIR := "user://map_3d_mode_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "map3d-shot", "bad_kon_willow", "seeded_grid_frontier", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 12:
		await process_frame

	var view: Node = scene.get_node_or_null("Map3DView")
	if view == null:
		push_error("Map3DView was freed - session.render_3d did not take")
		quit(1)
		return
	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	economy.call("add_resource", 1, &"bio", 20000)
	var tower: Node = null
	for s in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and str(s.get("archetype")) == "wizard_tower":
			tower = s
			break
	var base_cell: Vector2i = map_generator.call("world_to_cell", (tower as Node2D).global_position)
	build_system.call("add_free_structure", 1, &"barracks", base_cell + Vector2i(5, 5), "")
	build_system.call("add_free_structure", 1, &"bio_absorber", map_generator.call("nearest_walkable_cell", base_cell + Vector2i(-4, 3), 8), "")
	var origin: Vector2 = (tower as Node2D).global_position + Vector2(-160, 180)
	# Mix of units WITH sprite art (terrible_thing, horror, apex) and without
	# (oaven_spear), so both render tiers appear in the same shot.
	var roster := [
		"res://scenes/units/terrible_thing.tscn",
		"res://scenes/units/horror.tscn",
		"res://scenes/units/apex.tscn",
		"res://scenes/units/oaven_spear.tscn",
	]
	for i in 16:
		var unit: Node = (load(roster[i % roster.size()]) as PackedScene).instantiate()
		unit.set("owner_player_id", 1 if i < 11 else 2)
		scene.add_child(unit)
		unit.global_position = origin + Vector2(float(i % 8) * 52.0, float(i / 8) * 62.0)
	for _i in 30:
		await process_frame

	view.call("focus_on_sim_position", origin + Vector2(180.0, 30.0))
	view.call("set_camera_distance", 24.0)
	# Show the interaction chrome that was missing: a pending build footprint and
	# a live drag rectangle.
	build_system.call("start_placement", &"barracks")
	for _i in 4:
		await process_frame
	for _i in 30:
		await process_frame
	var a: Vector2 = view.call("sim_to_screen", origin + Vector2(20.0, 0.0))
	var b: Vector2 = view.call("sim_to_screen", origin + Vector2(330.0, 90.0))
	view.call("set_drag_rect", true, Rect2(a, b - a))
	for _i in 20:
		await process_frame

	print("[Map3DModeScreenshot] telemetry: ", view.call("get_view_telemetry"))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image == null:
		push_error("No viewport image - run windowed, not headless")
		quit(1)
		return
	image.save_png("%s/3d_mode.png" % OUT_DIR)
	print("[Map3DModeScreenshot] saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)
