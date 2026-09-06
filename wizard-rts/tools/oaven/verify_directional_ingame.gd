extends SceneTree
const Art := preload("res://scripts/units/oaven_painted_art.gd")

func _initialize() -> void: call_deferred("run")

func fail(message: String) -> void:
	push_error("[Oaven8InGame] "+message)
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

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: fail("Timeout"))
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
	var scene: PackedScene = factory._scene_for_unit(&"oaven_spear")
	if scene==null: fail("Production scene missing"); return
	var actors: Array[Node2D] = []
	for form in 2:
		for i in 8:
			var unit: Node2D = scene.instantiate()
			unit.position=terrain.cell_to_world(origin+Vector2i(2+i,2+form*4))
			stage.add_child(unit)
			if form: unit.debug_force_evolve()
			actors.append(unit)
	var view: Node = stage.get_node("Map3DView")
	view.focus_on_sim_position(terrain.cell_to_world(origin+Vector2i(6,4)))
	view.set_camera_distance(16)
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.camera.make_current()
	var runner := actors[0]
	var start: Vector2 = runner.position
	runner.issue_move_order(terrain.cell_to_world(origin+Vector2i(2,5)))
	await create_timer(1.0).timeout
	if runner.position.distance_to(start)<20: fail("Real movement did not advance"); return
	runner.issue_stop_order()
	runner.position=start
	var jumper := actors[8]
	if not jumper.activate_flight(): fail("Jumper flight rejected"); return
	# Flight expires on wall time; a simulation timer can miss it during startup stalls.
	var saw_flight := false
	var deadline := Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if jumper.get_node("ArtSprite").current_action==&"flying":
			saw_flight=true
			break
		if jumper._flight_state==&"grounded": break
	if not saw_flight:
		fail("Real flight did not select flying art: action=%s flight=%s ability=%s now=%d until=%d" % [jumper.get_node("ArtSprite").current_action,jumper._flight_state,jumper.ability_animation_action,Time.get_ticks_msec(),jumper._ability_animation_until_msec]); return
	if not runner.set_weapon_mode(&"blowpipe"): fail("Weapon switch rejected"); return
	await create_timer(.8).timeout
	if not str(runner.get_node("ArtSprite").current_action).contains("blowpipe"): fail("Blowpipe presentation missing after swap"); return
	stage.process_mode=Node.PROCESS_MODE_DISABLED
	for i in actors.size():
		var unit := actors[i]
		unit.attack_target=null
		unit.ability_animation_action=&""
		unit.unit_state=&"idle"
		unit.moving=false
		unit.weapon_mode=&"spear"
		unit._flight_state=&"grounded"
		unit.velocity=Vector2.RIGHT.rotated((i%8)*PI/4)*100
		var art: Sprite2D = unit.get_node("ArtSprite")
		art._process(.1)
		unit.velocity=Vector2.ZERO
		if art.facing_index!=i%8: fail("Actor facing mismatch"); return
	view._sync_unit_sprites(actors)
	await capture("oaven_ingame_8directions")
	# Both forms must respond to camera yaw even while stationary.
	var pair: Array[Node2D] = [actors[0],actors[8]]
	for yaw in 8:
		view.camera.global_basis=Basis(Vector3.UP,yaw*PI/4)*Basis(Vector3.RIGHT,-PI/4)
		view._sync_unit_sprites(pair)
		for i in 2:
			var art: Sprite2D = pair[i].get_node("ArtSprite")
			var billboard: Sprite3D = view._sprite_at(i)
			if art.facing_index!=yaw or billboard.texture!=art.texture or billboard.frame!=art.frame or billboard.flip_h:
				fail("Sprite3D camera-relative copy mismatch"); return
	view._apply_camera_transform()
	for unit in actors:
		unit.weapon_mode=&"blowpipe"
		unit.unit_state=&"attacking"
		unit._attack_elapsed=0
		unit.get_node("ArtSprite")._process(.1)
	view._sync_unit_sprites(actors)
	await capture("oaven_ingame_blowpipes")
	root.size=Vector2i(1024,720)
	root.content_scale_size=root.size
	await capture("oaven_ingame_small")
	print("[Oaven8InGame] PASS: factory, real movement, weapon swap, flight, 16 actors, all camera yaws, desktop/small captures")
	stage.queue_free()
	for i in 5: await process_frame
	quit()
