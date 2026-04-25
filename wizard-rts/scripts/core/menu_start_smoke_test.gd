extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame

	menu.call("_on_start_pressed")
	await process_frame
	await process_frame

	var current := current_scene
	if current == null:
		push_error("Expected a current scene after pressing Start")
		quit(1)
		return

	if root.get_node_or_null("AudioManager") == null:
		push_error("AudioManager autoload missing after scene change")
		quit(1)
		return

	if not root.get_node("AudioManager").call("is_music_playing"):
		push_error("Music stopped after starting the game")
		quit(1)
		return

	print("[MenuStartSmokeTest] start loads game and music persists")
	root.get_node("AudioManager").call("release_music")
	await process_frame
	quit(0)
