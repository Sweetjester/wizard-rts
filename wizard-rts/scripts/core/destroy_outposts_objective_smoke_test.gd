extends SceneTree

# Regression guard for the second win-objective type added 2026-08-23
# (GameSession.objective_id "destroy_outposts", KonVerticalSliceController._check_objective_victory()).
# Previously the only win path was defeating the boss.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "destroy-outposts-smoke", "bad_kon_willow", "seeded_grid_frontier", "destroy_outposts")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var controller: Node = scene.get_node("KonVerticalSliceController")
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize")
		return
	if str(controller.get("_objective_id")) != "destroy_outposts":
		_fail("Expected GameSession.objective_id to reach the controller as destroy_outposts")
		return

	controller.call("_check_objective_victory")
	if bool(controller.get("_victory")):
		_fail("Objective victory triggered before any outpost was destroyed")
		return

	var completed_reason_box := [""]
	controller.connect("objective_completed", func(reason: String) -> void:
		completed_reason_box[0] = reason
	)

	var outposts: Array = controller.get("_outposts")
	if outposts.size() < 1:
		_fail("Expected at least one required outpost")
		return

	for outpost in outposts:
		var node = outpost.get("node", null)
		if node == null or not is_instance_valid(node):
			_fail("Outpost node missing before destruction")
			return
		node.call("take_damage", 999999, null)
	await process_frame
	await process_frame

	controller.call("_check_objective_victory")
	if not bool(controller.get("_victory")):
		_fail("Destroying all required outposts should trigger objective victory")
		return
	if str(completed_reason_box[0]).is_empty():
		_fail("Expected objective_completed signal to fire with a reason")
		return
	if str(controller.call("_victory_defeat_state")) != "victory":
		_fail("Expected _victory_defeat_state() to report victory")
		return

	print("[DestroyOutpostsObjectiveSmokeTest] outposts=", outposts.size(), " victory=true reason='", completed_reason_box[0], "'")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
