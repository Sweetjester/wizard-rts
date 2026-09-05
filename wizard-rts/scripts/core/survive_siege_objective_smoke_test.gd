extends SceneTree

# Regression guard for the third win-objective type added 2026-08-23
# (GameSession.objective_id "survive_siege", KonVerticalSliceController
# ._check_objective_victory()'s OBJECTIVE_SURVIVE_SIEGE branch): win by
# surviving SIEGE_SURVIVAL_SECONDS after the boss spawns, instead of having
# to kill it (a defensive win con, distinct from defeat_boss/destroy_outposts).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "survive-siege-smoke", "bad_kon_willow", "seeded_grid_frontier", "survive_siege")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	# Map generation is spread across frames now, so the scene is not playable
	# the instant it is added. Waits for the generator to say it is finished
	# rather than for a fixed frame count -- a count that happened to be long
	# enough on a 96x96 map is not a guarantee, it is a coincidence.
	for _gen_wait in 400:
		var _gen := scene.get_node_or_null("MapGenerator")
		if _gen == null or bool(_gen.get("generation_complete")):
			break
		await process_frame
	await process_frame
	await process_frame
	await process_frame

	var controller: Node = scene.get_node("KonVerticalSliceController")
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize")
		return
	if str(controller.get("_objective_id")) != "survive_siege":
		_fail("Expected GameSession.objective_id to reach the controller as survive_siege")
		return

	var wave_director: Node = scene.get_node("WaveDirector")
	if wave_director == null:
		_fail("Expected a WaveDirector")
		return

	# Before the boss has spawned, the siege timer must not be running.
	controller.call("_check_objective_victory")
	if bool(controller.get("_victory")) or bool(controller.get("_siege_started")):
		_fail("Siege survival should not start before the boss spawns")
		return

	if not bool(wave_director.call("trigger_boss_now", "survive_siege_smoke_test")):
		_fail("Expected trigger_boss_now to succeed")
		return
	if not bool(wave_director.get("boss_has_spawned")):
		_fail("Expected boss_has_spawned to be true after triggering the boss")
		return

	# First check after the boss spawns should start the timer, not win immediately.
	controller.call("_check_objective_victory")
	if bool(controller.get("_victory")):
		_fail("Siege should not be won the instant the boss spawns")
		return
	if not bool(controller.get("_siege_started")):
		_fail("Expected the siege timer to start once the boss spawned")
		return

	# Not enough time elapsed yet -- still no victory.
	controller.call("_check_objective_victory")
	if bool(controller.get("_victory")):
		_fail("Siege should not be won before SIEGE_SURVIVAL_SECONDS has elapsed")
		return

	# Simulate SIEGE_SURVIVAL_SECONDS having elapsed without waiting on real time.
	# _siege_started (a separate bool) is what gates re-starting the timer, so the
	# timestamp itself can safely go negative here without being misread as "not started."
	var survival_ms := int(float(controller.call("siege_survival_seconds")) * 1000.0)
	controller.set("_siege_started_msec", Time.get_ticks_msec() - survival_ms - 100)

	var completed_reason_box := [""]
	controller.connect("objective_completed", func(reason: String) -> void:
		completed_reason_box[0] = reason
	)
	controller.call("_check_objective_victory")

	if not bool(controller.get("_victory")):
		_fail("Expected surviving the siege duration to trigger victory")
		return
	if str(completed_reason_box[0]).is_empty():
		_fail("Expected objective_completed signal to fire with a reason")
		return
	if str(controller.call("_victory_defeat_state")) != "victory":
		_fail("Expected _victory_defeat_state() to report victory")
		return

	print("[SurviveSiegeObjectiveSmokeTest] victory=true reason='", completed_reason_box[0], "'")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
