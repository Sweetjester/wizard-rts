extends SceneTree

# A real-renderer look at a staffed building.
#
# The smoke tests prove the counting and the clocks. They cannot tell you
# whether a player can SEE that a building is staffed -- which is the whole
# difference between a mechanic and a hidden multiplier. This stages a
# Splicing Laboratory with Oavens posted inside it, selects it, and saves a
# frame showing the crew line in the HUD.
#
#   godot --path . --script tools/combat_feedback/shot_garrison.gd
#
# ART_SHOT_DIR chooses the output directory, as the other tools do.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "garrison-shot", "bad_kon_willow", "build_sandbox", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _i in 600:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 30:
		await process_frame

	var build_system: Node = scene.get_node_or_null("BuildSystem")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	var garrison: Node = scene.get_node_or_null("StructureGarrisonEffects")
	var director: Node = scene.get_node_or_null("WaveDirector")
	var view: Node = scene.get_node_or_null("Map3DView")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	var selection: Node = scene.get_node_or_null("SelectionController")
	if economy != null:
		economy.call("add_resource", 1, &"bio", 999999)

	var origin := Vector2i(40, 40)
	build_system.call("try_place_structure", 1, &"barracks", origin)
	for _i in 10:
		await process_frame
	var structures: Array = build_system.get("structures")
	var lab := {}
	for i in structures.size():
		if StringName(structures[i].get("archetype", &"")) == &"barracks":
			structures[i]["complete"] = true
			structures[i]["build_progress"] = float(structures[i].get("build_time", 0.0))
			var node = structures[i].get("node", null)
			if node != null and is_instance_valid(node):
				node.set("complete", true)
			lab = structures[i]
	var instance: StringName = StringName(lab.get("block_instance", &""))

	# Interior floor cells, found through the lattice rather than guessed.
	var cells: Array[Dictionary] = []
	for radius in range(0, 12):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var cell := origin + Vector2i(dx, dz)
				for level in range(0, 6):
					if StringName(bridge.call("structure_instance_at", cell, level)) == instance:
						var entry := {"cell": cell, "level": level}
						if not cells.has(entry):
							cells.append(entry)
		if cells.size() >= 6:
			break

	for i in mini(3, cells.size()):
		var oaven: Node2D = director.call("_spawn_enemy", &"oaven_spear", origin + Vector2i(-6, i), scene, Vector2.ZERO)
		if oaven == null or not is_instance_valid(oaven):
			continue
		oaven.set("owner_player_id", 1)
		for _wait in 10:
			await process_frame
		oaven.global_position = map.call("cell_to_world", cells[i]["cell"])
		oaven.set("nav_level", int(cells[i]["level"]))
		oaven.call("issue_stop_order")
	for _i in 40:
		await process_frame

	# Queue something so the lab is visibly working, and select it so the HUD
	# draws the crew line.
	build_system.call("produce_unit_from_structure", 1, &"oaven_spear", lab.get("node", null))
	# _apply_selection is the controller's own entry point; going through it
	# rather than setting `selected` by hand means the HUD updates the same way
	# it does for a real click.
	if selection != null and lab.get("node", null) != null:
		var chosen: Array[Node] = [lab["node"] as Node]
		selection.call("_apply_selection", chosen)
	if view != null and view.has_method("focus_on_sim_position"):
		view.call("focus_on_sim_position", map.call("cell_to_world", origin))
		if view.has_method("set_camera_distance"):
			view.call("set_camera_distance", 18.0)
	for _i in 40:
		await process_frame

	print("[GarrisonShot] staffed=", garrison.call("workers_in", instance),
		" rate=", garrison.call("rate_multiplier_for", instance))
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("ART_SHOT_DIR")
	if directory.is_empty():
		directory = "user://"
	var path: String = directory.path_join("garrison_review.png")
	root.get_texture().get_image().save_png(path)
	print("[GarrisonShot] PASS wrote ", path)
	quit(0)
