extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: Node = load("res://scenes/blocks/block_tower_demo.tscn").instantiate()
	root.add_child(scene)
	for _i in 12:
		await process_frame
	var world = scene.get("world")
	var origin: Vector2i = scene.get("TOWER_ORIGIN")
	var camera: Camera3D = scene.get("_camera")
	print("gate default from spec: ", world.gate_states)
	# Can infantry reach anything above ground with the gate as it starts?
	var up := Vector3i(origin.x + 8, 26, origin.y + 8)
	var p1 = world.find_path(Vector2i(origin.x + 8, origin.y + 0), 0, Vector2i(up.x, up.z), 26, &"infantry")
	print("route to observatory, gate as-shipped: ", p1.size(), " steps")
	world.gate_states["main_gate_open"] = true
	var p2 = world.find_path(Vector2i(origin.x + 8, origin.y + 0), 0, Vector2i(up.x, up.z), 26, &"infantry")
	print("route to observatory, gate open:       ", p2.size(), " steps")
	# Does screen picking find a high vantage point when clicked directly?
	for target in [Vector3i(origin.x + 8, 26, origin.y + 8), Vector3i(origin.x + 3, 12, origin.y + 8), Vector3i(origin.x + 8, 12, origin.y + 8)]:
		var world_point := Vector3(target.x + 0.5, target.y + 0.65, target.z + 0.5)
		var screen := camera.unproject_position(world_point)
		var picked = scene.call("_pick_node", screen)
		print("clicking %s (screen %s) picks %s  %s" % [target, screen.round(), picked, "OK" if picked == target else "*** wrong ***"])
	quit(0)
