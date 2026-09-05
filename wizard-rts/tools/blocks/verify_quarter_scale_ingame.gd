extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("[QuarterInGame] PASS: ",message)

func _run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: push_error("Quarter-scale integration timed out"); quit(1))
	root.size = Vector2i(1600,1000)
	root.get_node("GameSession").start_new_game("quarter-scale-integration","bad_kon_willow","seeded_grid_frontier","",true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node = stage.get_node("MapGenerator")
	var deadline := Time.get_ticks_msec()+90000
	while not bool(terrain.get("generation_complete")) and Time.get_ticks_msec()<deadline:
		await process_frame
	check(bool(terrain.get("generation_complete")), "Map generation completed")
	if failures > 0:
		stage.queue_free()
		quit(1)
		return
	for i in 10: await process_frame
	var bridge: BlockNavBridge = stage.get_node("BlockNavBridge")
	var view: Node = stage.get_node("Map3DView")
	var build: BuildSystem = stage.get_node("BuildSystem")
	var citadel: Dictionary = {}
	for placement in bridge.world.placements():
		if placement.structure == &"kons_arcane_citadel_01": citadel = placement
	check(not citadel.is_empty(), "Citadel placed on real generated map")
	for plot in terrain.get("plots"):
		if plot.get("block_structure", "") == "kons_arcane_citadel_01":
			check(plot.rect.size == Vector2i(24,24), "Citadel reserves 24x24, not 96x96")
	check(build.rotated_footprint(&"wizard_tower",0) == Vector2i(18,18), "Tower placement uses restored original footprint")
	check(build.rotated_footprint(&"barracks",1) == Vector2i(7,9), "Rotated laboratory placement uses compact footprint")
	var taken: Array[Rect2i] = []
	var lab_origin := bridge.find_flat_site(Vector2i(9,7),taken)
	check(lab_origin.x >= 0, "Compact laboratory has a valid site")
	if lab_origin.x >= 0:
		check(build.try_place_structure(1,&"barracks",lab_origin), "Laboratory builds through real BuildSystem")
		var lab_base: int = terrain.get_height(lab_origin)
		var start := lab_origin+Vector2i(3,-1)
		var destination := lab_origin+Vector2i(4,5)
		bridge.world.gate_states["lab_entry_open"] = true
		var visitor: Node2D = load("res://scenes/units/oaven_spear.tscn").instantiate()
		stage.add_child(visitor)
		visitor.set_physics_process(false)
		visitor.global_position = terrain.cell_to_world(start)
		visitor.set("nav_level",lab_base)
		check(bridge.order_to(visitor,destination,lab_base+4,&"infantry"), "Live unit accepts laboratory entrance and gallery route")
		for step in 150:
			visitor.rts_movement_tick(1.0)
			if visitor.get("path").is_empty(): break
		check(visitor.global_position.distance_to(terrain.cell_to_world(destination))<1.0 and visitor.get("nav_level")==lab_base+4, "Live unit reaches redesigned laboratory gallery")
	if not citadel.is_empty():
		var origin: Vector2i = citadel.origin
		var base: int = citadel.base_level
		var outside := origin+Vector2i(11,-1)
		var goal := origin+Vector2i(10,10)
		bridge.world.gate_states["main_south_gate_open"] = false
		check(bridge.world.find_path(outside,base,goal,base+5,&"infantry").is_empty(), "Closed citadel blocks outside-to-keep route")
		bridge.world.gate_states["main_south_gate_open"] = true
		bridge.world.gate_states["citadel_keep_gate_open"] = true
		var path := bridge.world.find_path(outside,base,goal,base+5,&"infantry")
		check(not path.is_empty(), "Open citadel connects terrain to keep terrace")
		var unit: Node2D = load("res://scenes/units/oaven_spear.tscn").instantiate()
		stage.add_child(unit)
		unit.set_physics_process(false)
		unit.global_position = terrain.cell_to_world(outside)
		unit.set("nav_level",base)
		check(bridge.order_to(unit,goal,base+5,&"infantry"), "Live unit accepts route through gate and stairs")
		# Large explicit simulation steps exercise the real path consumer quickly.
		for step in 300:
			unit.rts_movement_tick(1.0)
			if unit.get("path").is_empty(): break
		check(unit.global_position.distance_to(terrain.cell_to_world(goal))<1.0 and unit.get("nav_level")==base+5, "Live unit arrives on the correct compact floor")
		view._sync_block_gates()
		var builder: Node = view.get("_block_structure_root").get_node("Block_kons_arcane_citadel_01_%d_%d" % [origin.x,origin.y])
		var leaf: Node3D = builder.get_node("PaintedQuarterScale/Gate_main_south_gate_open")
		check(not leaf.visible,"Live open gate hides its painted leaf")
		bridge.world.gate_states["main_south_gate_open"] = false
		view._sync_block_gates()
		check(leaf.visible,"Live closed gate restores its painted leaf")
		bridge.world.gate_states["main_south_gate_open"] = true
		view.focus_on_sim_position(terrain.cell_to_world(origin+Vector2i(12,12)))
		view.set_camera_distance(42.0)
		stage.get_node("FogOfWar").set_reveal_all(true)
		view.get("camera").make_current()
		if DisplayServer.get_name() != "headless":
			await create_timer(2.0).timeout
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			var visible_samples := 0
			for x in range(320,1280,8):
				for y in range(180,820,8):
					var colour := capture.get_pixel(x,y)
					if maxf(colour.r,maxf(colour.g,colour.b))>0.15: visible_samples += 1
			check(visible_samples>200,"Screenshot contains visible game geometry, not an opaque fog plane")
			check(capture.save_png(OS.get_environment("ART_SHOT_DIR")+"/quarter_ingame.png")==OK,"Live-game screenshot saved")
	if lab_origin.x >= 0 and DisplayServer.get_name() != "headless":
		view.focus_on_sim_position(terrain.cell_to_world(lab_origin+Vector2i(4,3)))
		view.set_camera_distance(18.0)
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/redesigned_lab_ingame.png")==OK,"Redesigned laboratory live-game screenshot saved")
	stage.queue_free()
	for i in 5: await process_frame
	print("[QuarterInGame] failures=",failures)
	quit(0 if failures==0 else 1)
