extends SceneTree

# Drives the tower demo without a human: sends the unit up to the observatory,
# switches to heavy, and captures each state so the build can be checked.

const OUT_DIR := "user://tower_demo_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = load("res://scenes/blocks/block_tower_demo.tscn").instantiate()
	root.add_child(scene)
	for _i in 12:
		await process_frame

	var definition = scene.get("definition")
	var world = scene.get("world")
	print("[Tower] %s solid=%d nav=%d links=%d" % [
		definition.display_name, definition.solid_cells.size(),
		definition.nav_cells.size(), definition.links.size()])
	print("[Tower] stair tread nodes: ", scene.get("_builder").get_node_or_null("Stairs") != null)
	print("[Tower] gate leaf node: ", scene.get("_builder").get_node_or_null("Gate_main_gate_open") != null)

	await _shot(scene, "01_closed_gate")

	# Open the gate and send the unit all the way to the observatory crown.
	scene.set("_gate_open", true)
	world.gate_states["main_gate_open"] = true
	scene.get("_builder").call("set_gate_open", &"main_gate_open", true)
	var origin: Vector2i = scene.get("TOWER_ORIGIN")
	var observatory := Vector3i(origin.x + 8, 26, origin.y + 8)
	scene.call("_order_to", observatory)
	var path: Array = scene.get("_path")
	print("[Tower] infantry route to the observatory: %d steps, %d -> %d" % [
		path.size(), 0 if path.is_empty() else path[0].y, 0 if path.is_empty() else path[path.size() - 1].y])
	await _shot(scene, "02_route_to_observatory")

	# Let it actually climb.
	for _i in 420:
		await process_frame
	print("[Tower] unit ended at level ", (scene.get("_node") as Vector3i).y)
	await _shot(scene, "03_arrived")

	# Heavy: the interior should collapse to almost nothing.
	scene.set("_class_index", 3)
	scene.call("_reset_unit")
	scene.set("_show_nav", true)
	scene.get("_nav_marks").visible = true
	scene.call("_refresh")
	await _shot(scene, "04_heavy_nav")
	print("[Tower] saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)

func _shot(scene: Node, name: String) -> void:
	for _i in 8:
		await process_frame
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png("%s/%s.png" % [OUT_DIR, name])
