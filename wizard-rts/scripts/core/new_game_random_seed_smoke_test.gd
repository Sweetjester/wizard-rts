extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: Node = root.get_node("GameSession")
	session.call("start_new_game")
	var first_text: String = session.get("map_seed_text")
	var first_seed := await _build_seed()

	session.call("start_new_game")
	var second_text: String = session.get("map_seed_text")
	var second_seed := await _build_seed()

	if first_text == second_text:
		push_error("New Game generated the same seed text twice: %s" % first_text)
		quit(1)
		return
	if first_seed == second_seed:
		push_error("New Game generated the same numeric map seed twice: %s" % first_seed)
		quit(1)
		return

	print("[NewGameRandomSeedSmokeTest] seeds: ", first_seed, " then ", second_seed)
	quit(0)

func _build_seed() -> int:
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var seed := int(scene.get_node("MapGenerator").get_seed_value())
	scene.queue_free()
	await process_frame
	return seed
