extends SceneTree

var failures := 0
var output := OS.get_environment("ART_SHOT_DIR")

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("[MenuOverhaul] ",label," ",ok)
	if not ok: failures+=1; push_error(label)

func shot(label: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var samples := 0
	for y in range(0,img.get_height(),16):
		for x in range(0,img.get_width(),16):
			if img.get_pixel(x,y).get_luminance()>.06: samples+=1
	check(samples>100,"Rendered "+label)
	if not output.is_empty(): img.save_png(output+"/"+label+".png")

func run() -> void:
	create_timer(120).timeout.connect(func(): quit(9))
	var settings := root.get_node("DisplayManager")
	var old_effects: bool = settings.atmospheric_effects
	var old_perf: bool = settings.performance_mode
	settings.set_atmospheric_effects(true)
	settings.set_performance_mode(false)
	var session := root.get_node("GameSession")
	session.start_new_game("view-test","bad_kon_willow","build_sandbox","",false)
	check(not session.render_3d,"Explicit 2D remains available")
	session.start_new_game("view-test","bad_kon_willow","build_sandbox")
	check(session.render_3d,"Session defaults to 3D")
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	check(menu.use_3d_view,"Menu defaults to 3D")
	for size in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=size
		root.content_scale_size=size
		menu._show_main()
		await shot("menu_home_"+str(size.x))
		check(menu.get_node("LibraryBackdrop").size==menu.size,"Illustration fills viewport")
		menu._on_start_pressed()
		await shot("menu_wizards_"+str(size.x))
		menu._on_bad_kon_pressed()
		menu._on_character_continue_pressed()
		await shot("menu_maps_"+str(size.x))
		check(menu.begin_button.get_global_rect().end.y<=root.size.y,"Map footer inside viewport "+str(size.x))
		menu._on_display_pressed()
		await shot("menu_display_"+str(size.x))
	var backdrop := menu.get_node("LibraryBackdrop")
	var initial: float = backdrop.elapsed
	await create_timer(.2).timeout
	check(backdrop.elapsed>initial,"Library relighting animates")
	settings.set_atmospheric_effects(false)
	check(not backdrop.active_effects,"Reduced effects disables menu animation")
	settings.set_atmospheric_effects(true)
	menu._on_start_pressed()
	menu._on_bad_kon_pressed()
	menu._on_character_continue_pressed()
	menu._on_build_sandbox_pressed()
	for i in 5: await process_frame
	var stage := current_scene
	check(stage!=menu and stage.has_node("MapGenerator"),"Menu starts game")
	while not stage.get_node("MapGenerator").generation_complete: await process_frame
	await create_timer(1).timeout
	var view := stage.get_node("Map3DView")
	check(view.has_node("ObserverLighting"),"Default game builds 3D lighting")
	var renderer := view.get_node("Map3DTerrain")
	var geometry: Node3D = renderer.get("_visual_root")
	var geometry_count := 0
	for child in renderer.get_children():
		if str(child.name).begins_with("PrototypeGeometry"): geometry_count += 1
	check(geometry_count == 1,"Bootstrap leaves exactly one terrain mesh tree")
	for cell in [Vector2i(0,0),Vector2i(80,80),Vector2i(159,159)]:
		var rendered: Vector3 = geometry.to_global(renderer._cell_to_world(cell,0))
		var simulated: Vector3 = renderer.sim_to_world_3d(stage.get_node("MapGenerator").cell_to_world(cell))
		check(rendered.distance_to(simulated)<.001,"Terrain and unit origin agree: "+str(cell))
	root.set_meta("observer_archive_open",-1)
	stage.get_node("FogOfWar").set_reveal_all(true)
	var build := stage.get_node("BuildSystem")
	build.add_free_structure(1, &"terrible_vault", Vector2i(74,74))
	view.focus_on_sim_position(stage.get_node("Wizard").global_position)
	view.set_camera_distance(25)
	# Block structure skins are assembled across frames after placement.
	await create_timer(5).timeout
	check(view.get_node("ObserverGlow").visible,"Visible hero has local light")
	await shot("menu_game_lighting")
	root.remove_meta("observer_archive_open")
	var hud := stage.get_node("RTSHud")
	check(hud.observer_vault.open_archive(build.structures[-1].node,build,stage.get_node("RTSWorld")),"Real vault opens")
	await create_timer(.6).timeout
	await shot("menu_vault")
	hud.observer_vault.close_archive()
	var pause := stage.get_node("PauseMenu")
	pause.show_menu()
	check(paused and pause.overlay.visible,"Pause opens and freezes game")
	await shot("menu_pause")
	for tab in 4:
		pause.menu_panel.get_child(0).get_child(2).current_tab=tab
		await shot("menu_pause_tab_"+str(tab))
	pause._confirm(func(): pass)
	check(pause.confirmation.visible,"Destructive actions require confirmation")
	pause.confirmation.hide()
	check(pause.menu_panel.get_global_rect().end.y<=root.size.y,"Pause fits 720p")
	pause.waiting_for_action="move"
	var escape := InputEventKey.new()
	escape.pressed=true
	escape.physical_keycode=KEY_ESCAPE
	pause._unhandled_input(escape)
	check(pause.waiting_for_action.is_empty() and paused,"Escape cancels rebind without resuming")
	pause.hide_menu()
	check(not paused,"Resume unpauses")
	settings.set_performance_mode(true)
	check(not view.get_node("Environment").environment.glow_enabled,"Performance mode disables bloom")
	settings.set_performance_mode(old_perf)
	settings.set_atmospheric_effects(old_effects)
	stage.queue_free()
	for i in 5: await process_frame
	print("[MenuOverhaul] failures=",failures)
	quit(0 if failures==0 else 1)
