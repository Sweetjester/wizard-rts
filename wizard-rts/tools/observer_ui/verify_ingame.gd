extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(120).timeout.connect(func(): quit(9))
	root.size = Vector2i(1440,900)
	root.content_scale_size = root.size
	var session := root.get_node("GameSession")
	session.start_new_game("archive-integration", "bad_kon_willow", "build_sandbox", "", OS.get_environment("OBSERVER_TEST_3D") == "1")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var map: Node = scene.get_node("MapGenerator")
	for i in 800:
		await process_frame
		if bool(map.get("generation_complete")):
			break
	for i in 12:
		await process_frame
	var build: Node = scene.get_node("BuildSystem")
	var selection: Node = scene.get_node("SelectionController")
	var hud: Node = scene.get_node("RTSHud")
	build.add_free_structure(1, &"terrible_vault", Vector2i(70,70))
	var vault: Node = build.structures[-1].node
	selection.selected_units.assign([vault])
	selection.selection_changed.emit(selection.selected_units)
	await process_frame
	check(hud.observer_vault.overlay.visible, "Selecting the real Vault must open archive")
	check(root.has_meta("observer_archive_open"), "Archive did not own camera input")
	check(not hud.detail_body_label.visible, "World HUD leaked detailed stats")
	var economy: Node = scene.get_node("EconomyManager")
	economy.add_resource(1, &"bio", 2000)
	check(build.research_upgrade(1, &"tier_two_hybrids"), "Real tier research failed")
	hud.observer_vault.section = "Research"
	hud.observer_vault.refresh()
	check(build.unlocked_tier(1) == 2, "Real research did not unlock tier")
	# Escape is delivered through the viewport, not by calling the close method.
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key)
	await process_frame
	check(not hud.observer_vault.overlay.visible, "Escape did not close Vault")
	check(not paused, "Escape also opened pause menu")
	check(not root.has_meta("observer_archive_open"), "Archive left camera input locked")
	hud._open_selected_vault()
	hud.observer_vault.section = "Creations"
	hud.observer_vault.search.text = "oaven"
	hud.observer_vault.refresh()
	check(hud.observer_vault.grid.get_child_count() == 1, "Search must return one Oaven family card")
	hud.observer_vault.search.text = "nonsensequery"
	hud.observer_vault.refresh()
	check(hud.observer_vault.grid.get_child_count() == 0, "Empty search did not clear cards")
	hud.observer_vault.close_archive()
	await create_timer(2.0).timeout
	for i in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR").path_join("observer_battlefield.png"))
	print("[ObserverIntegration] failures=", failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
