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
	var summoned: Array = wizard.call("summon_treants")
	if summoned.size() < 8:
		push_error("Expected a useful treant group, got %s" % summoned.size())
		quit(1)
		return

	var target_cell: Vector2i = map.nearest_walkable_cell(Vector2i(16, 28), 16)
	var target_world: Vector2 = map.cell_to_world(target_cell)
	for i in summoned.size():
		var offset := Vector2(float(i % 4) * 28.0, float(i / 4) * 28.0)
		summoned[i].call("issue_move_order_offset", target_world, offset)

	for _i in 260:
		await physics_frame

	var moved_count := 0
	for unit in summoned:
		if unit.global_position.distance_to(wizard.global_position) > 80.0:
			moved_count += 1

	if moved_count < summoned.size() / 2:
		push_error("Treants did not move as a group. Moved count: %s" % moved_count)
		quit(1)
		return

	print("[TreantSummonSmokeTest] summoned:", summoned.size(), " moved:", moved_count)
	quit(0)
