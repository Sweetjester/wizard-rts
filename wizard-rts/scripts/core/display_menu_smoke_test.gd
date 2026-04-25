extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var display_manager: Node = root.get_node("DisplayManager")
	var previous_resolution := int(display_manager.get("resolution_index"))
	var previous_performance := bool(display_manager.get("performance_mode"))

	menu.call("_on_display_pressed")
	await process_frame
	menu.call("_on_resolution_option_item_selected", 0)
	await process_frame
	menu.call("_on_performance_check_toggled", true)
	await process_frame

	if int(display_manager.get("resolution_index")) != 0:
		push_error("Resolution selection did not update DisplayManager")
		quit(1)
		return
	if not bool(display_manager.get("performance_mode")):
		push_error("Performance mode toggle did not update DisplayManager")
		quit(1)
		return

	menu.call("_on_back_pressed")
	await process_frame
	display_manager.call("set_resolution_index", previous_resolution)
	display_manager.call("set_performance_mode", previous_performance)
	print("[DisplayMenuSmokeTest] display settings updated")
	menu.queue_free()
	await process_frame
	quit(0)
