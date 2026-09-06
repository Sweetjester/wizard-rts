extends SceneTree
var failures := 0
var interactive := false
var builder: BlockStructureBuilder
var bridge: BlockNavBridge
var view: Node

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("[BarracksGame] ",label," ",ok)
	if not ok: failures+=1; push_error(label)

func capture(name: String) -> void:
	if OS.get_environment("ART_SHOT_DIR").is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var lit := 0
	for y in range(100,img.get_height()-100,8):
		for x in range(100,img.get_width()-100,8):
			var c := img.get_pixel(x,y)
			if maxf(c.r,maxf(c.g,c.b))>.2: lit+=1
	check(lit>100,"Nonblank "+name)
	img.save_png(OS.get_environment("ART_SHOT_DIR")+"/"+name+".png")

func run() -> void:
	interactive=OS.get_cmdline_user_args().has("--play")
	if not interactive: create_timer(150).timeout.connect(func() -> void: quit(1))
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
	root.get_node("GameSession").start_new_game("steel-musterhouse-review","bad_kon_willow","build_sandbox","",true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node = stage.get_node("MapGenerator")
	while not terrain.generation_complete: await process_frame
	for i in 10: await process_frame
	bridge=stage.get_node("BlockNavBridge")
	var taken: Array[Rect2i] = []
	var origin := bridge.find_flat_site(Vector2i(9,14),taken)
	check(origin.x>=0,"Full 9x14 site found")
	if origin.x<0: quit(1); return
	check(bridge.place_runtime_structure(&"steel_force_barracks_farm_01",origin,&"steel_barracks_review"),"Real map placement")
	# Placement opens new construction gates; restore the authored service state.
	bridge.world.gate_states["steel_service_open"]=false
	view=stage.get_node("Map3DView")
	builder=view.get("_block_structure_root").get_node("Block_steel_force_barracks_farm_01_%d_%d" % [origin.x,origin.y])
	check(builder.has_node("GothicDetails/FarmGate"),"Bespoke skin loaded on real map")
	view.focus_on_sim_position(terrain.cell_to_world(origin+Vector2i(4,7)))
	view.set_camera_distance(18)
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.camera.make_current()
	var base: int = terrain.get_height(origin)
	var visitor: RTSUnit = load("res://scenes/units/poorper.tscn").instantiate()
	visitor.owner_player_id=1
	visitor.position=terrain.cell_to_world(origin+Vector2i(3,-1))
	stage.add_child(visitor)
	for frame in 3: await process_frame
	visitor.nav_level=base
	check(bridge.order_to(visitor,origin+Vector2i(4,12),base+4,&"infantry"),"Infantry accepts farm-to-loft route")
	for step in 250:
		await create_timer(.1).timeout
		if visitor.path.is_empty(): break
	check(visitor.position.distance_to(terrain.cell_to_world(origin+Vector2i(4,12)))<1 and visitor.nav_level==base+4,"Infantry physically reaches loft")
	var mount: RTSUnit = load("res://scenes/units/mounted_knight.tscn").instantiate()
	mount.owner_player_id=1
	mount.position=terrain.cell_to_world(origin+Vector2i(3,-1))
	stage.add_child(mount)
	for frame in 3: await process_frame
	mount.nav_level=base
	check(bridge.order_to(mount,origin+Vector2i(4,10),base+1,&"heavy"),"Cavalry accepts wide farm and entrance")
	# Exercise the real movement scheduler, not move_and_slide in a tight test loop.
	for step in 150:
		await create_timer(.1).timeout
		if mount.path.is_empty(): break
	check(mount.position.distance_to(terrain.cell_to_world(origin+Vector2i(4,10)))<1 and mount.nav_level==base+1,"Cavalry physically enters hall; remaining="+str(mount.position.distance_to(terrain.cell_to_world(origin+Vector2i(4,10)))))
	check(not bridge.order_to(mount,origin+Vector2i(4,12),base+4,&"heavy"),"Cavalry cannot use loft stair")
	view._sync_block_gates()
	await capture("steel_barracks_ingame_exterior")
	var selection: Node = stage.get_node("SelectionController")
	var chosen: Array[Node] = [visitor]
	selection._apply_selection(chosen)
	view._sync_block_gates()
	check(not builder.get_node("GothicDetails/Roof").visible,"Selecting occupant opens interior view")
	await capture("steel_barracks_ingame_interior")
	chosen.clear()
	selection._apply_selection(chosen)
	view._sync_block_gates()
	check(builder.get_node("GothicDetails/Roof").visible,"Deselect restores exterior")
	bridge.world.gate_states["steel_muster_open"]=false
	bridge.world.gate_states["steel_farm_open"]=false
	view._sync_block_gates()
	check(builder.get_node("GothicDetails/MusterGate").visible and builder.get_node("GothicDetails/FarmGate").visible,"Real gate leaves close")
	await capture("steel_barracks_ingame_closed")
	root.size=Vector2i(1024,720)
	root.content_scale_size=root.size
	await capture("steel_barracks_ingame_small")
	print("[BarracksGame] failures=",failures)
	if interactive:
		root.size=Vector2i(1600,1000)
		root.content_scale_size=root.size
		bridge.world.gate_states["steel_muster_open"]=true
		bridge.world.gate_states["steel_farm_open"]=true
		_controls()
		return
	stage.queue_free()
	for i in 5: await process_frame
	quit(0 if failures==0 else 1)

func _controls() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var row := HBoxContainer.new()
	row.position=Vector2(20,65)
	layer.add_child(row)
	for info in [["Farm gate","steel_farm_open"],["Hall gate","steel_muster_open"],["Service gate","steel_service_open"]]:
		var button := Button.new()
		button.text=info[0]
		button.toggle_mode=true
		button.button_pressed=bool(bridge.world.gate_states.get(info[1],false))
		button.toggled.connect(func(opened: bool) -> void: bridge.world.gate_states[info[1]]=opened; view._sync_block_gates())
		row.add_child(button)
