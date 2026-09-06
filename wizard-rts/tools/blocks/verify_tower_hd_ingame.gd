extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("[TowerHDLive] ",label," ",ok)
	if not ok:
		failures+=1
		push_error(label)

func run() -> void:
	create_timer(150).timeout.connect(func(): quit(9))
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
	root.get_node("GameSession").start_new_game("serpent-art-review","bad_kon_willow","seeded_grid_frontier","",true)
	var stage: Node=load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node=stage.get_node("MapGenerator")
	while not terrain.generation_complete: await process_frame
	for i in 25: await process_frame
	# Let the loading overlay finish its real-time fade before freezing the review.
	await create_timer(1.1).timeout
	var view: Node3D=stage.get_node("Map3DView")
	var bridge: BlockNavBridge=stage.get_node("BlockNavBridge")
	var taken: Array[Rect2i]=[]
	for plot in terrain.plots:
		if plot.get("block_structure","")!="": taken.append(plot.rect)
	var site := bridge.find_flat_site(Vector2i(18,18),taken)
	check(site.x>=0,"Flat site on generated map")
	if site.x<0: stage.queue_free(); quit(1); return
	check(bridge.place_runtime_structure(&"kons_observation_wizard_tower_01",site,&"hd_review_tower"),"Real runtime placement API")
	await process_frame
	var tower: BlockStructureBuilder
	for node in view.get_node("BlockStructures3D").get_children():
		if node.definition.id==&"kons_observation_wizard_tower_01":
			tower=node
			break
	check(tower!=null,"Runtime tower placed by the real map")
	if tower==null: quit(1); return
	check(tower.get_node("GothicDetails").get_meta("skin_id")=="observation_tower_hd_v3","Live map uses HD skin")
	check(tower.scale.is_equal_approx(Vector3.ONE),"No additional runtime shrinking")
	var original_gate: bool=bridge.world.gate_states.get("main_gate_open",false)
	bridge.world.gate_states["main_gate_open"]=true
	view._sync_block_gates()
	var origin := Vector2i(roundi(tower.position.x),roundi(tower.position.z))
	var level := roundi(tower.position.y)
	var a := tower.definition._turn_cell(Vector3i(8,0,0),tower.definition.rotation_steps)
	var b := tower.definition._turn_cell(Vector3i(8,26,8),tower.definition.rotation_steps)
	var path := bridge.world.find_path(origin+Vector2i(a.x,a.z),level+a.y,origin+Vector2i(b.x,b.z),level+b.y,&"infantry")
	check(not path.is_empty(),"Live navigation reaches observation floor")
	bridge.world.gate_states["main_gate_open"]=false
	view._sync_block_gates()
	check(tower.get_node("Gate_main_gate_open").visible,"Live gate closes visually")
	bridge.world.gate_states["main_gate_open"]=original_gate
	view._sync_block_gates()
	stage.get_node("FogOfWar").set_reveal_all(true)
	root.set_meta("observer_archive_open",-1)
	stage.process_mode=Node.PROCESS_MODE_DISABLED
	var centre := tower.global_position+Vector3(9,16,9)
	var camera: Camera3D=view.camera
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=40
	camera.global_position=centre+Vector3(34,20,-49)
	camera.look_at(centre)
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var lit := 0
	for x in range(500,1100,8):
		for y in range(100,900,8):
			if img.get_pixel(x,y).get_luminance()>.10: lit+=1
	check(lit>200,"Live tower is visibly rendered")
	var output := OS.get_environment("ART_SHOT_DIR")
	if not output.is_empty(): check(img.save_png(output+"/tower_hd_ingame.png")==OK,"Live screenshot saved")
	stage.queue_free()
	await process_frame
	print("[TowerHDLive] failures=",failures)
	quit(0 if failures==0 else 1)
