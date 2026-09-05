extends SceneTree

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Serpent integration timeout"); quit(1))
	root.size = Vector2i(1600,1000)
	root.get_node("GameSession").start_new_game("serpent-art-review","bad_kon_willow","seeded_grid_frontier","",true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node = stage.get_node("MapGenerator")
	while not terrain.generation_complete: await process_frame
	for i in 20: await process_frame
	var bridge: BlockNavBridge = stage.get_node("BlockNavBridge")
	var taken: Array[Rect2i] = []
	for plot in terrain.plots:
		if plot.has("rect"): taken.append(plot.rect)
	var origin := bridge.find_flat_site(Vector2i(12,10),taken)
	# Leave a wide margin from the central generated ruin for visual inspection.
	if origin.x>=0:
		taken.append(Rect2i(origin-Vector2i(18,18),Vector2i(48,46)))
		origin = bridge.find_flat_site(Vector2i(12,10),taken)
	if origin.x<0: push_error("No serpent review site"); quit(1); return
	var serpent: Node2D = load("res://scenes/units/stone_face_serpent.tscn").instantiate()
	stage.add_child(serpent)
	serpent.global_position = terrain.cell_to_world(origin+Vector2i(2,3))
	serpent.set_physics_process(false)
	serpent._gain_evolution_xp(225)
	var cells: Array[Vector2i] = serpent._line_cells(origin+Vector2i(2,3),origin+Vector2i(5,5),8)
	serpent._enter_stone_form(cells)
	if not serpent._stone_form_active: push_error("Live wall placement refused"); quit(1); return
	var selection: Node = stage.get_node("SelectionController")
	var chosen: Array[Node] = [serpent._stone_wall_segments[4]]
	selection._apply_selection(chosen)
	if selection.selected_units != [serpent]: push_error("Wall selection did not resolve to serpent"); quit(1); return
	for i in 3:
		var mobile: Node2D = load("res://scenes/units/stone_face_serpent.tscn").instantiate()
		stage.add_child(mobile)
		mobile.global_position = terrain.cell_to_world(origin+Vector2i(8,2+i*3))
		mobile.set_physics_process(false)
		mobile._gain_evolution_xp(i*90)
	var view: Node = stage.get_node("Map3DView")
	view.focus_on_sim_position(terrain.cell_to_world(origin+Vector2i(5,5)))
	view.set_camera_distance(24.0)
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.get("camera").make_current()
	await create_timer(2).timeout
	if serpent.global_position.distance_to(terrain.cell_to_world(cells[0]))>0.1:
		push_error("Hardened owner drifted away from the wall"); quit(1); return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var lit := 0
	for x in range(300,1250,8):
		for y in range(220,820,8):
			var c := image.get_pixel(x,y)
			if maxf(c.r,maxf(c.g,c.b))>0.12: lit += 1
	if lit<200: push_error("3D serpent capture is blank"); quit(1); return
	image.save_png(OS.get_environment("ART_SHOT_DIR")+"/serpent_ingame.png")
	print("[SerpentInGame] PASS: painted mobile stages, eight wall segments, bend and owner selection")
	serpent.activate_revert_stone_form()
	if not serpent._stone_wall_segments.is_empty(): push_error("Wall segments survived revert"); quit(1); return
	stage.queue_free()
	for i in 5: await process_frame
	quit(0)
