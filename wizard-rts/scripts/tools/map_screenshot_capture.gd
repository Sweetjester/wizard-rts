extends Node

# Debug/QA tool: instances a target scene, lets it settle, and saves a PNG of the viewport.
# Usage: godot --path . scenes/tools/map_screenshot_capture.tscn -- --scene=res://path/to/scene.tscn --out=C:/abs/path/out.png [--wait=2.5] [--seed=12345]

func _ready() -> void:
	var args := _parse_args()
	var scene_path := str(args.get("scene", "res://scenes/biomes/dark_forest_frontier_v2_showcase.tscn"))
	var out_path := str(args.get("out", "res://../screenshot.png"))
	var wait_seconds := float(args.get("wait", 2.5))

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: %s" % scene_path)
		get_tree().quit(1)
		return

	var instance := packed.instantiate()
	if args.has("seed"):
		instance.set("seed", int(args["seed"]))
	get_tree().root.add_child.call_deferred(instance)
	await get_tree().process_frame
	await get_tree().process_frame

	get_viewport().size = Vector2i(1600, 1000)

	await get_tree().create_timer(wait_seconds).timeout

	if args.has("list_categories"):
		var reg = instance.get("_registry")
		var cats: Array = reg.call("get_3d_categories")
		for i in range(cats.size()):
			print("CAT_INDEX:", i, " ", cats[i], " z=", float(i) * 2.5)

	if args.has("wide_cam"):
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var parts := str(args["wide_cam"]).split(",")
			cam.position = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
			cam.look_at(Vector3(float(parts[3]), float(parts[4]), float(parts[5])), Vector3.UP)
			await get_tree().process_frame

	if args.has("dump_category"):
		var prefix := str(args["dump_category"])
		var stack: Array[Node] = [instance]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if str(node.name).begins_with(prefix) and node is Node3D:
				print("MARKER_NODE:", node.name, " pos=", node.position, " global=", (node as Node3D).global_position, " visible=", node.visible, " scale=", node.scale)
			for child in node.get_children():
				stack.append(child)

	if args.has("focus_cell"):
		var coords := str(args["focus_cell"]).split(",")
		var cell := Vector2i(int(coords[0]), int(coords[1]))
		var world_pos: Vector3 = instance.call("_cell_to_world", cell, 0.0)
		instance._camera_rig.position = world_pos
		if args.has("dist"):
			instance._camera_distance = float(args["dist"])
		instance.call("_update_camera_transform")
		await get_tree().process_frame
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(out_path)
	if err != OK:
		push_error("Failed to save screenshot to %s (err=%s)" % [out_path, err])
		get_tree().quit(1)
		return

	print("SCREENSHOT_SAVED:", out_path)
	get_tree().quit(0)


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var stripped := arg.substr(2)
			var parts := stripped.split("=", true, 1)
			result[parts[0]] = parts[1]
	return result
