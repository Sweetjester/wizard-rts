extends SceneTree

func _initialize() -> void: call_deferred("_run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	create_timer(120).timeout.connect(func() -> void: fail("Mangler integration timeout"))
	root.size = Vector2i(1600,1000)
	root.content_scale_size = root.size
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
	if origin.x>=0:
		taken.append(Rect2i(origin-Vector2i(18,18),Vector2i(48,46)))
		origin = bridge.find_flat_site(Vector2i(12,10),taken)
	if origin.x<0: fail("No Mangler review site"); return
	var build: Node = stage.get_node("BuildSystem")
	var scene: PackedScene = build._scene_for_unit(&"mangler")
	if scene==null: fail("Mangler production has no scene"); return
	var runner: Node2D = scene.instantiate()
	runner.position = terrain.cell_to_world(origin+Vector2i(2,2))
	stage.add_child(runner)
	var winged: Node2D = scene.instantiate()
	winged.position = terrain.cell_to_world(origin+Vector2i(2,6))
	stage.add_child(winged)
	winged.debug_force_evolve()
	var selection: Node = stage.get_node("SelectionController")
	var chosen: Array[Node] = [winged]
	selection._apply_selection(chosen)
	var view: Node = stage.get_node("Map3DView")
	view.focus_on_sim_position(terrain.cell_to_world(origin+Vector2i(5,5)))
	view.set_camera_distance(24.0)
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.get("camera").make_current()
	await create_timer(0.5).timeout
	runner.issue_move_order(terrain.cell_to_world(origin+Vector2i(10,2)))
	var reached_full := false
	for i in 180:
		await physics_frame
		if runner.momentum_stacks == 5:
			reached_full = true
			break
	if not reached_full: fail("Actual running failed to build five momentum stacks"); return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/mangler_ingame_charge.png")
	runner.issue_stop_order()
	if runner.momentum_stacks!=0: fail("In-game Stop did not clear momentum"); return
	var destination: Vector2 = terrain.cell_to_world(origin+Vector2i(6,6))
	selection.begin_mangler_leap(winged)
	if selection._mangler_preview==null: fail("Leap preview was not created"); return
	selection._issue_pending_target_command(destination)
	if winged.leap_age<0: fail("Manual leap targeting failed: "+winged.last_leap_error); return
	if selection._mangler_preview!=null: fail("Leap targeting preview survived cast"); return
	await create_timer(0.6).timeout
	if winged.leap_height<40: fail("Winged form did not leave the ground"); return
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var lit := 0
	for x in range(300,1250,8):
		for y in range(220,820,8):
			var c := capture.get_pixel(x,y)
			if maxf(c.r,maxf(c.g,c.b))>0.12: lit += 1
	if lit<200: fail("Mangler in-game capture is blank"); return
	capture.save_png(OS.get_environment("ART_SHOT_DIR")+"/mangler_ingame_leap.png")
	await create_timer(1.0).timeout
	if winged.leap_age>=0 or winged.global_position.distance_to(destination)>2: fail("Leap failed to land and recover"); return
	# Exercise the real Sprite3D bridge, including a stationary unit and rotated camera.
	view.set_process(false)
	runner.set_physics_process(false)
	winged.set_physics_process(false)
	runner.velocity = Vector2.RIGHT*100
	winged.velocity = Vector2.RIGHT*100
	var actors: Array[Node2D] = [runner,winged]
	view._sync_unit_sprites(actors)
	runner.velocity = Vector2.ZERO
	winged.velocity = Vector2.ZERO
	for yaw in 8:
		view.camera.global_basis = Basis(Vector3.UP,yaw*PI/4)*Basis(Vector3.RIGHT,-PI/4)
		view._sync_unit_sprites(actors)
		for actor_index in 2:
			var art: Sprite2D = actors[actor_index].get_node("ArtSprite")
			var billboard: Sprite3D = view._sprite_at(actor_index)
			if art.facing_index!=yaw or billboard.texture!=art.texture or billboard.frame!=art.frame or billboard.flip_h:
				fail("Camera-relative Sprite3D direction mismatch at "+str(yaw)); return
	print("[ManglerInGame] PASS: both forms resolve all eight stationary camera-relative Sprite3D pages")
	view._apply_camera_transform()
	root.size = Vector2i(1024,720)
	root.content_scale_size = root.size
	view._sync_unit_sprites(actors)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/mangler_ingame_small.png")
	print("[ManglerInGame] PASS: factory, real running, five stacks, stop, selection, manual targeting, airborne art, landing")
	stage.queue_free()
	for i in 5: await process_frame
	quit(0)
