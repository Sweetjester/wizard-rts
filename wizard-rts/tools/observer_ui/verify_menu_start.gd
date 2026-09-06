extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(9))
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._on_start_pressed()
	menu._on_bad_kon_pressed()
	menu._on_character_continue_pressed()
	menu._on_build_sandbox_pressed()
	# A second queued activation must not start another asynchronous map.
	menu._on_begin_pressed()
	await process_frame
	await process_frame
	var scene := current_scene
	if scene == null or scene == menu or not scene.has_node("MapGenerator"):
		push_error("Menu did not start the map")
		quit(1)
		return
	var map := scene.get_node("MapGenerator")
	for i in 1000:
		await process_frame
		if bool(map.get("generation_complete")):
			break
	if not bool(map.get("generation_complete")):
		push_error("Started map did not finish generating")
		quit(1)
		return
	await create_timer(2).timeout
	if not is_instance_valid(scene.get_node("RTSHud").get("observer_vault")):
		push_error("Game started without its archive interface")
		quit(1)
		return
	if root.get_node("GameSession").wizard_class_id != "bad_kon_willow" or not root.get_node("AudioManager").is_music_playing():
		push_error("Menu lost chosen wizard or music")
		quit(1)
		return
	print("[ObserverMenuStart] PASS: menu to playable map, duplicate start guarded")
	scene.queue_free()
	await process_frame
	quit(0)
