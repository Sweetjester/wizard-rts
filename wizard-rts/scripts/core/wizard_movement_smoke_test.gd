extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	var wizard: CharacterBody2D = scene.get_node("Wizard")
	wizard.set("move_speed", 2000.0)

	var target_cell: Vector2i = map.nearest_walkable_cell(Vector2i(12, 24), 16)
	if not map.is_walkable_cell(target_cell):
		push_error("No walkable target cell found")
		quit(1)
		return

	var target_world: Vector2 = map.cell_to_world(target_cell)
	wizard.call("issue_move_order", target_world)
	if wizard.get("path").is_empty():
		push_error("Wizard did not receive a path")
		quit(1)
		return

	for _i in 240:
		await physics_frame
		if wizard.global_position.distance_to(target_world) <= 4.0:
			print("[WizardMovementSmokeTest] reached cell ", target_cell, " at ", wizard.global_position)
			quit(0)
			return

	push_error("Wizard failed to reach target. Distance: %s" % wizard.global_position.distance_to(target_world))
	quit(1)
