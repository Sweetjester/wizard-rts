extends SceneTree

# Diagnoses "I can't find the block structures in game".
#
# Boots the real 3D path exactly as the menu does, then reports every link in
# the chain: is the bridge there, did it place anything, where, is the B key
# actually reaching Map3DView, and is the structure inside explored fog.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "", "bad_kon_willow", "seeded_grid_frontier", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 30:
		await process_frame

	print("--- 1. is the 3D view alive? ---")
	var view: Node = scene.get_node_or_null("Map3DView")
	print("  Map3DView present: ", view != null)
	if view == null:
		print("  -> render_3d was off. The 3D checkbox on the main menu is required.")
		quit(1)
		return

	print("--- 2. did the bridge place anything? ---")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	print("  BlockNavBridge present: ", bridge != null)
	if bridge == null:
		quit(1)
		return
	var block_world = bridge.get("world")
	print("  lattice nodes: ", 0 if block_world == null else block_world.node_count())
	var placements: Array = [] if block_world == null else block_world.placements()
	print("  placements: ", placements.size())
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	var tower_cell := Vector2i(-1, -1)
	for structure in scene.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(structure) and str(structure.get("archetype")) == "wizard_tower" \
				and int(structure.get("owner_player_id")) == 1:
			tower_cell = terrain.call("world_to_cell", (structure as Node2D).global_position)
	print("  player tower at cell: ", tower_cell)
	for placement in placements:
		var origin: Vector2i = placement["origin"]
		print("    %s at %s  (%.1f cells from the tower)" % [
			placement["structure"], origin, Vector2(origin - tower_cell).length()])

	print("--- 3. is it rendered in 3D? ---")
	var block_root: Node = view.get_node_or_null("BlockStructures3D")
	print("  BlockStructures3D node: ", block_root != null,
		"  children: ", 0 if block_root == null else block_root.get_child_count())

	print("--- 4. does the B key reach Map3DView? ---")
	var before: Vector3 = view.get("_camera_focus")
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.pressed = true
	# Pushed through the real input pipeline, not called directly, so this tests
	# whether anything else swallows the key first.
	Input.parse_input_event(event)
	for _i in 6:
		await process_frame
	var after: Vector3 = view.get("_camera_focus")
	print("  camera focus before: ", before)
	print("  camera focus after:  ", after)
	print("  B moved the camera: ", before.distance_to(after) > 0.5)
	print("  is_debug_build (B is gated on it): ", OS.is_debug_build())

	print("--- 5. would fog hide it? ---")
	var fog: Node = scene.get_node_or_null("FogOfWar")
	if fog != null and not placements.is_empty() and fog.has_method("is_cell_explored"):
		var origin: Vector2i = placements[0]["origin"]
		print("  structure cell explored at start: ", fog.call("is_cell_explored", origin + Vector2i(6, 5)))
	else:
		print("  (FogOfWar has no is_cell_explored; skipping)")
	quit(0)
