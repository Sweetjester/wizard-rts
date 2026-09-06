extends SceneTree
const Art := preload("res://scripts/units/serpent_painted_art.gd")

func _initialize() -> void: call_deferred("run")

func fail(message: String) -> void:
	push_error("[Serpent8InGame] "+message)
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
	assert(lit>100,"Blank game capture")
	assert(img.save_png(OS.get_environment("ART_SHOT_DIR")+"/"+name+".png")==OK)

func sync(view: Node, actors: Array[Node2D]) -> void:
	# The frozen fixture bypasses the normal frame-level overlay reset.
	if view.get("_bar_entries")!=null: view.get("_bar_entries").clear()
	view._sync_unit_sprites(actors)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: fail("Timeout"))
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
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
		origin=bridge.find_flat_site(Vector2i(12,10),taken)
	if origin.x<0: fail("No review site"); return
	var factory: Node = stage.get_node("BuildSystem")
	var scene: PackedScene = factory._scene_for_unit(&"stone_face_serpent")
	if scene==null: fail("Production scene missing"); return
	var actors: Array[Node2D] = []
	for i in 8:
		var unit: Node2D = scene.instantiate()
		unit.position=terrain.cell_to_world(origin+Vector2i(2+(i%4)*3,2+(i/4)*5))
		stage.add_child(unit)
		unit._gain_evolution_xp((i%6)*45)
		actors.append(unit)
	var view: Node = stage.get_node("Map3DView")
	view.focus_on_sim_position(terrain.cell_to_world(origin+Vector2i(6,5)))
	view.set_camera_distance(20)
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.camera.make_current()
	var runner := actors[0]
	var start := runner.position
	runner.issue_move_order(terrain.cell_to_world(origin+Vector2i(2,5)))
	await create_timer(1).timeout
	if runner.position.distance_to(start)<20: fail("Real movement did not advance"); return
	runner.issue_stop_order()
	runner.position=start
	stage.process_mode=Node.PROCESS_MODE_DISABLED
	for i in actors.size():
		var unit := actors[i]
		unit.attack_target=null
		unit.ability_animation_action=&""
		unit.unit_state=&"idle"
		unit.moving=false
		unit.velocity=Vector2.from_angle(i*PI/4)*100
		var art: Sprite2D = unit.get_node("ArtSprite")
		art._process(.1)
		unit.velocity=Vector2.ZERO
		if art.facing_index!=i: fail("Initial actor facing mismatch"); return
	sync(view,actors)
	await capture("serpent_ingame_8directions")
	# Exercise every growth-stage anchor under all camera yaws, including stationary units.
	for unit in actors: unit.get_node("ArtSprite").world_facing=Vector2.RIGHT
	for yaw in 8:
		view.camera.global_basis=Basis(Vector3.UP,yaw*PI/4)*Basis(Vector3.RIGHT,-PI/4)
		sync(view,actors)
		for i in actors.size():
			var art: Sprite2D = actors[i].get_node("ArtSprite")
			var billboard: Sprite3D = view._sprite_at(i)
			var transform: Transform3D = view._unit_transform(actors[i])
			var lift := (float(art.get_meta("foot_anchor_y"))-128)*billboard.pixel_size
			if art.facing_index!=yaw or billboard.texture!=art.texture or billboard.frame!=art.frame or billboard.flip_h or billboard.offset.x!=art.offset.x or absf(billboard.global_position.y-transform.origin.y-lift)>.001:
				fail("Camera-relative growth/pivot copy mismatch"); return
	view._apply_camera_transform()
	for i in actors.size():
		var unit := actors[i]
		unit.velocity=Vector2.from_angle(i*PI/4)*100
		var art: Sprite2D = unit.get_node("ArtSprite")
		art.play_attack()
		art._attack_left=.35
		art._process(0)
		unit.velocity=Vector2.ZERO
	sync(view,actors)
	await capture("serpent_ingame_bites")
	var art: Sprite2D = actors[5].get_node("ArtSprite")
	var before: Array[Node] = view._sprite_root.get_children()
	actors[5]._spawn_death_fx()
	var corpses: Array[Node] = view._sprite_root.get_children().filter(func(n: Node) -> bool: return not before.has(n))
	if corpses.size()!=1 or corpses[0].texture!=art.texture or corpses[0].frame!=56 or corpses[0].offset.x!=art.offset.x:
		fail("3D corpse lost growth/direction anchor"); return
	root.size=Vector2i(1024,720)
	root.content_scale_size=root.size
	await capture("serpent_ingame_small")
	print("[Serpent8InGame] PASS: production factory, movement, six lengths, eight directions/yaws, head pivots, bites, 3D corpse, desktop/small captures")
	stage.queue_free()
	for i in 5: await process_frame
	quit()
