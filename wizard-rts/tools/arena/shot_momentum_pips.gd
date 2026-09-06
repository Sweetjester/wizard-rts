extends SceneTree

# The momentum strip over a Mangler and a Mounted Knight, at every stack count.
#
#   godot --path . --script tools/arena/shot_momentum_pips.gd

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node_or_null("GameSession").call("start_new_game", "pips", "bad_kon_willow", "build_sandbox", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _i in 900:
		if bool(map.get("generation_complete")): break
		await process_frame
	for _i in 30: await process_frame
	var director: Node = scene.get_node_or_null("WaveDirector")
	var view: Node = scene.get_node_or_null("Map3DView")

	var origin := Vector2i(40, 40)
	var made: Array = []
	for i in 6:
		var kind: StringName = &"mangler" if i < 3 else &"mounted_knight"
		var u: Node2D = director.call("_spawn_enemy", kind, origin + Vector2i(i * 3 - 8, 0), scene, Vector2.ZERO)
		if u == null or not is_instance_valid(u): continue
		u.set("owner_player_id", 1)
		made.append(u)
	for _i in 30: await process_frame
	# One of each at 0, mid and full stacks.
	var stacks := [0, 3, 5, 0, 3, 5]
	for i in made.size():
		made[i].call("issue_stop_order")
		made[i].global_position = map.call("cell_to_world", origin + Vector2i(i * 4 - 10, 0))
		made[i].set("momentum_stacks", stacks[i % stacks.size()])
		made[i].set("selected", true)
	for _i in 40: await process_frame
	for i in made.size():
		made[i].set("momentum_stacks", stacks[i % stacks.size()])
	for _i in 10: await process_frame

	if view != null and view.has_method("focus_on_sim_position"):
		view.call("focus_on_sim_position", map.call("cell_to_world", origin))
		if view.has_method("set_camera_distance"): view.call("set_camera_distance", 16.0)
	for _i in 30: await process_frame
	for i in made.size():
		made[i].set("momentum_stacks", stacks[i % stacks.size()])
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("ART_SHOT_DIR")
	if dir.is_empty(): dir = "user://"
	root.get_texture().get_image().save_png(dir.path_join("momentum_pips.png"))
	print("[PipShot] PASS stacks=", stacks)
	quit(0)
