extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame

	var audio_manager: Node = root.get_node("AudioManager")
	if not audio_manager.call("is_music_playing"):
		push_error("Expected menu music to be playing")
		quit(1)
		return

	var stream_path: String = audio_manager.call("get_music_stream_path")
	if stream_path != "res://Bad John Dillo Fixed.mp3":
		push_error("Unexpected music stream: %s" % stream_path)
		quit(1)
		return

	audio_manager.call("set_music_volume", 0.25)
	audio_manager.call("set_music_muted", true)
	if not bool(audio_manager.get("music_muted")):
		push_error("Mute toggle did not update AudioManager")
		quit(1)
		return

	audio_manager.call("set_music_muted", false)
	print("[AudioMenuSmokeTest] music playing: ", stream_path)
	audio_manager.call("release_music")
	menu.queue_free()
	await process_frame
	quit(0)
