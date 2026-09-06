extends SceneTree

# Where Kon's Arena 2.0 actually spends a frame.
#
# The arena exists to measure performance, so "it feels slow" is not an answer
# it is allowed to give. This runs the same fight under four configurations and
# reports Godot's own counters, which separates the three costs that get
# confused with each other:
#
#   terrain      -- what the map costs with nothing alive on it
#   simulation   -- per-unit _process/_physics_process/collision (script VM)
#   presentation -- per-unit Sprite3D billboards and their draw calls
#
#   godot --path . --script tools/arena/profile_arena_2.gd
#
# UNITS sets the army size (default 200).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var target := int(OS.get_environment("UNITS")) if OS.get_environment("UNITS") != "" else 200
	print("[ArenaProfile] target units: ", target)
	print("[ArenaProfile] %-34s %8s %8s %8s %9s %9s" % [
		"configuration", "fps", "frame", "process", "physics", "draws"])
	await _measure("terrain only, 3D", target, true, false, false)
	await _measure("lightweight units, 3D", target, true, true, true)
	await _measure("full units, 3D", target, true, true, false)
	await _measure("full units, 2D", target, false, true, false)
	quit(0)

func _measure(label: String, target: int, use_3d: bool, spawn: bool, lightweight: bool) -> void:
	root.get_node_or_null("GameSession").call("start_new_game", "arena-profile", "bad_kon_willow", "kon_arena_2", "", use_3d)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _i in 900:
		if bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 30:
		await process_frame

	var director: Node = scene.get_node_or_null("WaveDirector")
	var view: Node = scene.get_node_or_null("Map3DView")
	# The switch under test: whether units keep their art and their own logic.
	director.set("arena_2_force_lightweight", lightweight)
	if spawn:
		director.call("queue_ai_test_until", target)
	var centre: Vector2i = map.call("kon_arena_2_centre")
	if view != null and is_instance_valid(view) and view.has_method("focus_on_sim_position"):
		view.call("focus_on_sim_position", map.call("cell_to_world", centre))
		if view.has_method("set_camera_distance"):
			view.call("set_camera_distance", 50.0)
	# Let them arrive and engage; the interesting frame is a frame of combat.
	Engine.time_scale = 6.0
	for _i in 1200:
		await process_frame
		if spawn and _in_contact(scene, map, centre):
			break
	Engine.time_scale = 1.0
	for _i in 30:
		await process_frame

	var frames := 0
	var total := 0.0
	var process_ms := 0.0
	var physics_ms := 0.0
	var draws := 0.0
	for _i in 180:
		var t := Time.get_ticks_usec()
		await process_frame
		total += float(Time.get_ticks_usec() - t) / 1000.0
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		frames += 1
	var world: Node = scene.get_node_or_null("RTSWorld")
	var live: int = int(world.call("count_units_all")) if world != null else 0
	var mean := total / float(frames)
	print("[ArenaProfile] %-34s %8.1f %7.1fms %7.2fms %8.2fms %9d   (live units %d)" % [
		label, 1000.0 / maxf(mean, 0.001), mean,
		process_ms / float(frames), physics_ms / float(frames), int(draws / float(frames)), live])
	scene.queue_free()
	for _i in 10:
		await process_frame

func _in_contact(scene: Node, map: Node, centre: Vector2i) -> bool:
	var west := false
	var east := false
	for u in scene.get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.get("unit_archetype") == null:
			continue
		if Vector2(map.call("world_to_cell", u.global_position) - centre).length() > 18.0:
			continue
		match int(u.get("owner_player_id")):
			2: west = true
			3: east = true
	return west and east
