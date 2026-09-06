extends SceneTree

func _initialize() -> void: call_deferred("run")

func fail(message: String) -> void:
	push_error("[Kon3D] "+message)
	quit(1)

func sync(view: Node, actors: Array[Node2D]) -> void:
	view._bar_entries.clear()
	view._sync_unit_sprites(actors)

func capture(name: String) -> void:
	if OS.get_environment("ART_SHOT_DIR").is_empty() or DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var lit := 0
	for y in range(150,img.get_height()-150,8):
		for x in range(150,img.get_width()-150,8):
			var color := img.get_pixel(x,y)
			if maxf(color.r,maxf(color.g,color.b))>.15: lit+=1
	assert(lit>100,"Blank battlefield capture")
	assert(img.save_png(OS.get_environment("ART_SHOT_DIR")+"/"+name+".png")==OK)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: fail("Timeout"))
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
	root.get_node("GameSession").start_new_game("kon-directional-review","bad_kon_willow","build_sandbox","",true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node = stage.get_node("MapGenerator")
	while not terrain.generation_complete: await process_frame
	await create_timer(1.5).timeout
	var view: Node = stage.get_node("Map3DView")
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.focus_on_sim_position(terrain.cell_to_world(Vector2i(76,76)))
	view.set_camera_distance(19)
	view.camera.make_current()
	stage.process_mode=Node.PROCESS_MODE_DISABLED
	var actors: Array[Node2D] = []
	for i in 8:
		var kon: Node2D = load("res://scenes/wizard.tscn").instantiate()
		stage.add_child(kon)
		actors.append(kon)
		kon.position=terrain.cell_to_world(Vector2i(72+(i%4)*3,74+(i/4)*5))
		kon.velocity=Vector2.from_angle(i*PI/4)*100
		kon.attack_target=null
		kon.get_node("ArtSprite")._process(0)
		kon.velocity=Vector2.ZERO
	sync(view,actors)
	await capture("kon_ingame_8directions")
	for kon in actors:
		kon.ability_animation_action=&"observer_aura"
		kon.get_node("ArtSprite").world_facing=Vector2.RIGHT
		kon.get_node("ArtSprite").frame=52
	for yaw in 8:
		view.camera.global_basis=Basis(Vector3.UP,yaw*PI/4)*Basis(Vector3.RIGHT,-PI/4)
		sync(view,actors)
		for i in 8:
			var art: Sprite2D = actors[i].get_node("ArtSprite")
			var billboard: Sprite3D = view._sprite_at(i)
			var ground: Transform3D = view._unit_transform(actors[i])
			var lift := (float(art.get_meta("foot_anchor_y"))-192)*billboard.pixel_size
			if art.facing_index!=yaw or billboard.texture!=art.texture or billboard.frame!=52 or billboard.flip_h or billboard.modulate!=Color.WHITE or absf(billboard.global_position.y-ground.origin.y-lift)>.001:
				fail("Eight-yaw page/frame/palette/foot anchor mismatch"); return
			if art.world_facing!=Vector2.RIGHT:
				fail("Camera orbit rotated observing Kon in world space"); return
	view._apply_camera_transform()
	var kon := actors[0]
	kon.set_meta("kon_banished",true)
	if view._is_revealed(kon): fail("Banished hero visible in 3D"); return
	kon.remove_meta("kon_banished")
	var fx: Node2D = kon.kon_abilities.spawn_fx(&"biostorm",kon.position+Vector2(160,0),200.0,4.0)
	await process_frame
	if not is_instance_valid(fx._spatial) or fx._painted_3d==null:
		fail("Spell missing 3D painted effect"); return
	for i in 8:
		var art: Sprite2D = actors[i].get_node("ArtSprite")
		actors[i].ability_animation_action=&""
		actors[i].velocity=Vector2.from_angle(i*PI/4)*100
		art.sync_view_facing()
		actors[i].velocity=Vector2.ZERO
		art.frame=i*12+5
	sync(view,actors)
	await capture("kon_ingame_actions")
	root.size=Vector2i(1024,720)
	root.content_scale_size=root.size
	await capture("kon_ingame_small")
	var art: Sprite2D = kon.get_node("ArtSprite")
	var before: Array[Node] = view._sprite_root.get_children()
	# Exercise the production corpse renderer without triggering match defeat.
	view.spawn_painted_unit_death(kon,art)
	var corpses: Array[Node] = view._sprite_root.get_children().filter(func(n: Node) -> bool: return not before.has(n))
	if corpses.size()!=1 or corpses[0].texture!=art.texture or corpses[0].frame!=84 or corpses[0].flip_h or not is_equal_approx(corpses[0].pixel_size,.009):
		fail("Directional corpse texture/frame/scale mismatch"); return
	print("[Kon3D] PASS: real map, eight headings/yaws, frame sync, palette, foot anchors, stationary observation, banish concealment, spatial spell, corpse renderer, desktop/small captures")
	stage.queue_free()
	for i in 5: await process_frame
	quit()
