extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "garrison-probe", "bad_kon_willow", "citadel_march")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 70:
		await process_frame
	var garrison: Node = scene.get_node_or_null("CitadelGarrison")
	if garrison == null:
		push_error("no CitadelGarrison node")
		quit(1)
		return
	print("[Garrison] defenders: ", garrison.call("defenders_remaining"))
	print("[Garrison] captured at start: ", garrison.call("is_captured"))
	print("[Garrison] keep plinth cell: ", garrison.call("keep_plinth_cell"))
	# Where are they, and are they on the levels the structure declares?
	var levels := {}
	var owners := {}
	for unit in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var owner_id := int(unit.get("owner_player_id"))
		owners[owner_id] = int(owners.get(owner_id, 0)) + 1
		if owner_id == 2:
			var level := int(unit.get("nav_level"))
			levels[level] = int(levels.get(level, 0)) + 1
	print("[Garrison] units by owner: ", owners)
	print("[Garrison] enemy nav levels: ", levels)
	quit(0)
