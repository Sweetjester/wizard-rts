extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "citadel-march", "bad_kon_willow", "citadel_march", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	var started := Time.get_ticks_msec()
	root.add_child(scene)
	for _i in 40:
		await process_frame
	var terrain: Node = scene.get_node_or_null("MapGenerator")
	var bridge: Node = scene.get_node_or_null("BlockNavBridge")
	print("[March] map=%dx%d  built in %d ms" % [int(terrain.get("MAP_W")), int(terrain.get("MAP_H")), Time.get_ticks_msec() - started])
	for plot in terrain.get("plots"):
		if str(plot.get("block_structure", "")) != "":
			print("[March] citadel plot: rect=%s difficulty=%s" % [plot.get("rect"), plot.get("difficulty")])
	var world = bridge.get("world")
	print("[March] lattice nodes: ", 0 if world == null else world.node_count())
	print("[March] placements: ", 0 if world == null else world.placements().size())
	for p in (world.placements() if world != null else []):
		print("    %s at %s" % [p["structure"], p["origin"]])
	quit(0)
