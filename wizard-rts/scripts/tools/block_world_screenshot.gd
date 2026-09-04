extends SceneTree

# Runs the block world demo for a few seconds and captures it, so agent movement
# and multi-level pathing can be checked without driving the scene by hand.

const OUT_DIR := "user://block_world_verification"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = load("res://scenes/blocks/block_world_demo.tscn").instantiate()
	root.add_child(scene)
	for _i in 10:
		await process_frame

	var world = scene.get("world")
	print("[BlockWorld] nav nodes: ", world.node_count(), "  placements: ", world.placements().size())

	# How many agents are on a route, and how many of those routes change level.
	# A demo where everything walks on flat ground would look fine and prove
	# nothing, so this is the number that matters.
	for pass_index in 3:
		scene.call("_assign_destinations")
		for _i in 40:
			await process_frame
		var climbing := 0
		var routed := 0
		for agent in scene.get("_agents"):
			var path: Array = agent["path"]
			if path.size() < 2:
				continue
			routed += 1
			var levels := {}
			for step in path:
				levels[step.y] = true
			if levels.size() > 1:
				climbing += 1
		print("[BlockWorld] pass %d: %d agents routed, %d of them change elevation" % [pass_index, routed, climbing])
		# The invariant worth checking every pass: no agent may stand, or plan to
		# stand, anywhere its own class is not permitted. This catches a whole
		# family of bugs -- a heavy on a wall-walk, a unit on a closed gate --
		# that are easy to miss by eye in a moving scene.
		var illegal := 0
		for agent in scene.get("_agents"):
			var unit_class: StringName = agent["class"]
			var here: Vector3i = agent["node"]
			if not world.can_occupy(world.encode(Vector2i(here.x, here.z), here.y), unit_class):
				illegal += 1
				print("  ILLEGAL %s standing at %s" % [unit_class, here])
			for step in agent["path"]:
				if not world.can_occupy(world.encode(Vector2i(step.x, step.z), step.y), unit_class):
					illegal += 1
					print("  ILLEGAL %s routed through %s" % [unit_class, step])
					break
		print("  illegal placements: %d" % illegal)
		var image := root.get_texture().get_image()
		if image != null:
			image.save_png("%s/world_%d.png" % [OUT_DIR, pass_index])

	# And a nav-overlay shot for the heavy class, which should be visibly absent
	# from the wall-walk and the plateaus it cannot ramp onto.
	scene.set("_show_nav", true)
	scene.get("_nav_marks").visible = true
	var classes: Array = scene.get("AGENT_COLORS").keys()
	scene.set("_nav_class_index", classes.find(&"heavy"))
	scene.call("_draw_nav_cells")
	scene.call("_refresh_legend")
	for _i in 6:
		await process_frame
	var overlay := root.get_texture().get_image()
	if overlay != null:
		overlay.save_png("%s/nav_heavy.png" % OUT_DIR)
	print("[BlockWorld] saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit(0)
