extends SceneTree

# A real-renderer look at the health bars and damage numbers.
#
# The smoke test proves the geometry -- bars project inside the viewport, above
# their unit, and numbers carry the mitigated figure. It cannot tell you whether
# the result is legible, whether the bars sit at a sensible height over three
# differently-sized units, or whether a burst of numbers turns into a smear.
# That needs eyes, so this stages the case and saves a frame.
#
#   godot --path . --script tools/combat_feedback/shot_combat_feedback.gd
#
# Set ART_SHOT_DIR to choose the output directory, as the other Kon tools do.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "combat-feedback-shot", "bad_kon_willow", "build_sandbox", "", true)
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	var map: Node = scene.get_node_or_null("MapGenerator")
	for _i in 600:
		if map == null or bool(map.get("generation_complete")):
			break
		await process_frame
	for _i in 30:
		await process_frame

	var director: Node = scene.get_node_or_null("WaveDirector")
	var view: Node = scene.get_node_or_null("Map3DView")
	var economy: Node = scene.get_node_or_null("EconomyManager")
	if economy != null:
		economy.call("add_resource", 1, &"bio", 999999)

	# One of each, so the bar height can be judged against three silhouettes at
	# once -- a Poorper, a Steel Knight and a blimp that flies.
	var origin := Vector2i(40, 40)
	var targets: Array[Node2D] = []
	var line := [&"poorper", &"steel_knight", &"poorper", &"proper_blimp", &"steel_knight"]
	for i in line.size():
		var unit: Node2D = director.call("spawn_sandbox_enemy", line[i], origin + Vector2i(i * 2 - 4, 0), scene)
		if unit != null and is_instance_valid(unit):
			# Deliberately NOT flagged as sandbox dummies. The dummy rule heals
			# them to full every frame, which is right for weapon testing and
			# useless here: the first version of this shot showed five identical
			# full bars and told me nothing about how a half-empty one reads.
			targets.append(unit)
	for _i in 20:
		await process_frame
	if not targets.is_empty() and view != null and view.has_method("focus_on_sim_position"):
		view.call("focus_on_sim_position", targets[targets.size() / 2].global_position)
		# Close enough to judge the thing being reviewed. At the default play
		# distance the units are twenty pixels tall and every question about bar
		# height and number legibility answers itself "too small to tell".
		if view.has_method("set_camera_distance"):
			view.call("set_camera_distance", 16.0)
	for _i in 30:
		await process_frame

	# Hurt them by different amounts so the bar colours and the number sizes are
	# both exercised in one frame: a scratch, a heavy hit, and one taken low
	# enough to flip its bar to the danger colour.
	# Fractions rather than flat numbers, so each unit ends at a different point
	# on its own bar regardless of how much health it has: a scratch, a half, and
	# one taken down past the danger threshold.
	var fractions := [0.08, 0.45, 0.5, 0.35, 0.8]
	for i in targets.size():
		var target := targets[i]
		if not is_instance_valid(target):
			continue
		var maximum := int(target.get("max_health"))
		target.call("take_damage", maxi(1, int(round(float(maximum) * float(fractions[i % fractions.size()])))),
			null, &"physical")
		for _wait in 3:
			await process_frame
	# Caught mid-flight: numbers are drawn rising and fading, so a frame taken
	# the instant after the last hit shows only one of them properly.
	for _i in 12:
		await process_frame

	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("ART_SHOT_DIR")
	if directory.is_empty():
		directory = "user://"
	var path: String = directory.path_join("combat_feedback_review.png")
	root.get_texture().get_image().save_png(path)
	print("[CombatFeedbackShot] PASS wrote ", path)
	quit(0)
