extends SceneTree

const OUT_DIR := "user://citadel_demo_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = load("res://scenes/blocks/block_citadel_demo.tscn").instantiate()
	var started := Time.get_ticks_msec()
	root.add_child(scene)
	for _i in 20:
		await process_frame
	print("[Citadel] build + first frames: %d ms" % (Time.get_ticks_msec() - started))
	var d = scene.get("definition")
	var world = scene.get("world")
	print("[Citadel] %s  solid=%d nav=%d links=%d  lattice nodes=%d" % [
		d.display_name, d.solid_cells.size(), d.nav_cells.size(), d.links.size(), world.node_count()])
	print("[Citadel] unit starts at ", scene.get("_node"))
	await _shot(scene, "01_overview")

	# Road -> keep roof, the longest authored route in the castle.
	var origin: Vector2i = scene.get("structure_origin")
	var targets := {
		"keep_roof": Vector3i(origin.x + 48, 40, origin.y + 48),
		"wall_walk": Vector3i(origin.x + 48, 18, origin.y + 88),
		"tower_observatory": Vector3i(origin.x + 12, 28, origin.y + 82),
	}
	for label in targets:
		scene.call("_reset_unit")
		var clicked: Vector3i = targets[label]
		var before := Time.get_ticks_usec()
		scene.call("_order_to", clicked)
		var elapsed := Time.get_ticks_usec() - before
		var path: Array = scene.get("_path")
		print("[Citadel] %-18s -> %s : %d steps, %d -> %d  (A* %.1f ms)" % [
			label, clicked, path.size(),
			0 if path.is_empty() else path[0].y, 0 if path.is_empty() else path[path.size() - 1].y,
			float(elapsed) / 1000.0])
	await _shot(scene, "02_route")

	scene.set("_class_index", 3)
	scene.call("_reset_unit")
	scene.call("_refresh")
	await _shot(scene, "03_heavy")
	print("[Citadel] saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)

func _shot(scene: Node, name: String) -> void:
	for _i in 10:
		await process_frame
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png("%s/%s.png" % [OUT_DIR, name])
