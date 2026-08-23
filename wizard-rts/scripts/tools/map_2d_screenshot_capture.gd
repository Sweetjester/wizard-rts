extends Node

# Debug/QA tool: instances the real shipping map scene, waits for map generation,
# and saves a PNG of the viewport. This is the ACTUAL 2D game path, unlike
# map_screenshot_capture.gd which targets the 3D preview/showcase scenes.
# Usage: godot --path . scenes/tools/map_2d_screenshot_capture.tscn -- --out=C:/abs/path/out.png [--wait=3.0] [--zoom=0.35] [--center_x=3800] [--center_y=2000]

func _ready() -> void:
	var args := _parse_args()
	var out_path := str(args.get("out", "res://../../screenshot_2d.png"))
	var wait_seconds := float(args.get("wait", 3.0))
	var character_id := str(args.get("character", "bad_kon_willow"))
	var map_type_id := str(args.get("map_type", "seeded_grid_frontier"))

	# Same setup _on_begin_pressed() does in main_menu.gd before switching scenes -
	# skipping this leaves GameSession unconfigured, which reads as "no wizard/tower"
	# to KonVerticalSliceController and triggers an immediate defeat state.
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("start_new_game"):
		session.call("start_new_game", "", character_id, map_type_id)
		print("SCREENSHOT2D: GameSession configured character=", character_id, " map_type=", map_type_id)
	else:
		print("SCREENSHOT2D: WARNING no GameSession autoload found")

	var packed := load("res://scripts/map/main_map.tscn") as PackedScene
	if packed == null:
		push_error("Could not load main_map.tscn")
		get_tree().quit(1)
		return

	var instance := packed.instantiate()
	get_tree().root.add_child.call_deferred(instance)
	await get_tree().process_frame
	await get_tree().process_frame

	get_viewport().size = Vector2i(1600, 1000)

	# Poll instead of awaiting map_generated directly - by the time this node's own
	# _ready() runs, main_map's whole scene tree (including MapGenerator, whose
	# generation happens synchronously in its own _ready()) has very likely already
	# finished and emitted the signal, so a blind await can hang forever waiting for
	# an event that already fired.
	var map_generator := instance.get_node_or_null("MapGenerator")
	var elapsed := 0.0
	var poll_interval := 0.25
	var found_data := false
	while elapsed < 20.0:
		if map_generator != null and not map_generator.get("plots").is_empty():
			print("SCREENSHOT2D: map data present, plots=", map_generator.get("plots").size())
			found_data = true
			break
		await get_tree().create_timer(poll_interval).timeout
		elapsed += poll_interval
	if not found_data:
		print("SCREENSHOT2D: WARNING timed out waiting for map data")

	await get_tree().create_timer(wait_seconds).timeout

	var camera := instance.get_node_or_null("Camera2D")
	if camera != null:
		if args.has("zoom"):
			var z := float(args["zoom"])
			camera.zoom = Vector2(z, z)
		if args.has("center_x") and args.has("center_y"):
			camera.position = Vector2(float(args["center_x"]), float(args["center_y"]))
		print("SCREENSHOT2D: camera zoom=", camera.zoom, " position=", camera.position)

	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(out_path)
	if err != OK:
		push_error("Failed to save screenshot to %s (err=%s)" % [out_path, err])
		get_tree().quit(1)
		return

	print("SCREENSHOT2D_SAVED:", out_path)
	get_tree().quit(0)


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var stripped := arg.substr(2)
			var parts := stripped.split("=", true, 1)
			result[parts[0]] = parts[1]
	return result
