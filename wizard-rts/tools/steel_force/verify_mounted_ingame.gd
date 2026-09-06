extends SceneTree

func _initialize() -> void: call_deferred("run")

func fail(message: String) -> void:
	push_error("[MountedInGame] "+message)
	quit(1)

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var lit := 0
	for y in range(150,img.get_height()-150,8):
		for x in range(150,img.get_width()-150,8):
			var c := img.get_pixel(x,y)
			if maxf(c.r,maxf(c.g,c.b))>.15: lit+=1
	assert(lit>100,"Blank battlefield capture")
	assert(img.save_png(OS.get_environment("ART_SHOT_DIR")+"/"+name+".png")==OK)

func sync(view: Node, actors: Array[Node2D]) -> void:
	if view.get("_bar_entries")!=null: view.get("_bar_entries").clear()
	view._sync_unit_sprites(actors)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: fail("Timeout"))
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
	var session: Node = root.get_node("GameSession")
	session.start_new_game("serpent-art-review","bad_kon_willow","seeded_grid_frontier","",true)
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
		origin=bridge.find_flat_site(Vector2i(12,10),taken)
	if origin.x<0: fail("No review site"); return
	var factory: Node = stage.get_node("BuildSystem")
	var scene: PackedScene = factory._scene_for_unit(&"mounted_knight")
	var director: Node = stage.get_node("WaveDirector")
	director.wave_index=7
	if scene==null or not director.enemy_roster().has(&"mounted_knight") or director._enemy_archetype_for_wave(0)!=&"mounted_knight":
		fail("Factory/Steel Force wave registration missing"); return
	var runner: RTSUnit = scene.instantiate()
	runner.position=terrain.cell_to_world(origin+Vector2i(1,2))
	stage.add_child(runner)
	if bridge.class_for(runner)!=&"heavy": fail("Mounted navigation is not heavy"); return
	var view: Node = stage.get_node("Map3DView")
	view.focus_on_sim_position(terrain.cell_to_world(origin+Vector2i(6,5)))
	view.set_camera_distance(20)
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.camera.make_current()
	var start := runner.position
	runner.issue_move_order(terrain.cell_to_world(origin+Vector2i(10,2)))
	var elapsed := 0.0
	while not runner.is_ablaze() and elapsed<8:
		await create_timer(.1).timeout
		elapsed+=.1
	if not runner.is_ablaze() or runner.position.distance_to(start)<315:
		fail("Actual battlefield movement failed to earn five stacks: distance=%s stacks=%s" % [runner.position.distance_to(start),runner.momentum_stacks]); return
	print("[MountedInGame] PASS: real battlefield movement earned flame in ",elapsed," seconds")
	runner.issue_stop_order()
	if not runner.is_ablaze() or runner.momentum_stacks!=0: fail("Stop lost active flame"); return
	stage.process_mode=Node.PROCESS_MODE_DISABLED
	var actors: Array[Node2D] = [runner]
	for i in range(1,8):
		var unit: RTSUnit = scene.instantiate()
		stage.add_child(unit)
		actors.append(unit)
	for i in 8:
		var unit := actors[i]
		unit.position=terrain.cell_to_world(origin+Vector2i(1+(i%4)*3,2+(i/4)*5))
		unit.attack_target=null
		unit.issue_stop_order()
		unit.flame_remaining=0
		unit.velocity=Vector2.from_angle(i*PI/4)*100
		unit.get_node("ArtSprite")._process(0)
		unit.velocity=Vector2.ZERO
	sync(view,actors)
	await capture("mounted_ingame_8directions")
	for unit in actors: unit.get_node("ArtSprite").world_facing=Vector2.RIGHT
	for yaw in 8:
		view.camera.global_basis=Basis(Vector3.UP,yaw*PI/4)*Basis(Vector3.RIGHT,-PI/4)
		sync(view,actors)
		for i in 8:
			var art: Sprite2D = actors[i].get_node("ArtSprite")
			var billboard: Sprite3D = view._sprite_at(i)
			var transform: Transform3D = view._unit_transform(actors[i])
			var lift := (float(art.get_meta("foot_anchor_y"))-128)*billboard.pixel_size
			if art.facing_index!=yaw or billboard.texture!=art.texture or billboard.frame!=art.frame or billboard.flip_h or billboard.modulate!=Color.WHITE or absf(billboard.global_position.y-transform.origin.y-lift)>.001:
				fail("Eight-yaw texture/frame/foot anchoring mismatch"); return
	view._apply_camera_transform()
	for i in 8:
		var unit := actors[i]
		unit.velocity=Vector2.from_angle(i*PI/4)*100
		unit.flame_remaining=12
		unit.ignition_age=1
		unit.attack_visual_age=.2
		unit.get_node("ArtSprite")._process(0)
		unit.velocity=Vector2.ZERO
	sync(view,actors)
	await capture("mounted_ingame_flame")
	var slain := actors[4]
	var art: Sprite2D = slain.get_node("ArtSprite")
	var page := art.texture
	var selection: Node = stage.get_node("SelectionController")
	var corpses_before: Array[Node] = view._sprite_root.get_children()
	var children_before: Array[Node] = stage.get_children()
	var killer: Node = stage.get_children().filter(func(n: Node) -> bool: return n is RTSUnit and n.owner_player_id==1)[0]
	slain.take_damage(99999,killer)
	var riders: Array[Node] = stage.get_children().filter(func(n: Node) -> bool: return not children_before.has(n) and n is RTSUnit and n.unit_archetype==&"steel_knight")
	if riders.size()!=1: fail("Dismount did not create exactly one live rider"); return
	var rider: RTSUnit = riders[0]
	if rider.health!=170 or rider.owner_player_id!=2 or bridge.class_for(rider)!=&"infantry":
		fail("Dismounted health/ownership/navigation mismatch"); return
	if int(session.felled_specimens.get(&"mounted_knight",0))!=1: fail("Mounted Vault discovery not recorded once"); return
	var corpses: Array[Node] = view._sprite_root.get_children().filter(func(n: Node) -> bool: return not corpses_before.has(n))
	if corpses.size()!=1 or corpses[0].texture!=page or corpses[0].frame!=72: fail("Directional mount-only 3D corpse missing"); return
	actors[4]=rider
	rider.issue_stop_order()
	rider.get_node("ArtSprite")._process(.1)
	# Hostile specimens cannot be selected. Exercise actual selection on a friendly mount.
	actors[5].owner_player_id=1
	var selected: Array[Node] = [actors[5]]
	selection._apply_selection(selected)
	if not actors[5].selected: fail("Friendly selection fixture failed"); return
	children_before=stage.get_children()
	actors[5].take_damage(99999,null)
	var friendly_riders: Array[Node] = stage.get_children().filter(func(n: Node) -> bool: return not children_before.has(n) and n is RTSUnit and n.unit_archetype==&"steel_knight")
	if friendly_riders.size()!=1 or not selection.selected_units.has(friendly_riders[0]) or friendly_riders[0].health!=int(ceil(friendly_riders[0].max_health*.5)):
		fail("Live friendly rider selection/half-HP transfer failed"); return
	actors[5]=friendly_riders[0]
	actors[5].issue_stop_order()
	actors[5].get_node("ArtSprite")._process(.1)
	sync(view,actors)
	await capture("mounted_ingame_dismount")
	root.size=Vector2i(1024,720)
	root.content_scale_size=root.size
	await capture("mounted_ingame_small")
	print("[MountedInGame] PASS: factory/wave7, heavy navigation, real charge, eight directions/yaws, flame, half-HP rider, selection, Vault discovery, 3D corpse, desktop/small captures")
	stage.queue_free()
	for i in 5: await process_frame
	quit()
