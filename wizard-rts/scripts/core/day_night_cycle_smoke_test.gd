extends SceneTree

# Regression guard for the day/night cycle added 2026-08-23
# (KonVerticalSliceController._update_day_night(), which deliberately hooks
# only economy income rate and outpost-defender composition -- not wave
# spawn cadence or fog of war, both flagged too risky/out of scope to touch).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "day-night-smoke", "bad_kon_willow", "seeded_grid_frontier")
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
	var economy_manager: Node = scene.get_node("EconomyManager")
	if controller == null or not bool(controller.get("_initialized")):
		_fail("Vertical slice controller did not initialize")
		return
	if economy_manager == null:
		_fail("Expected an EconomyManager")
		return

	if bool(controller.get("_is_night")):
		_fail("Expected the run to start in Day")
		return
	var day_multiplier := float(economy_manager.get("income_multiplier"))
	if not is_equal_approx(day_multiplier, 1.15):
		_fail("Expected the Day economy multiplier to be applied at start, got %s" % day_multiplier)
		return
	var day_chance := float(controller.call("heavy_defender_chance"))
	if not is_equal_approx(day_chance, 1.0 / 3.0):
		_fail("Expected the Day heavy-defender chance to be 1/3, got %s" % day_chance)
		return

	# A single large delta should push straight past DAY_SECONDS and flip to Night.
	# (DAY_SECONDS/NIGHT_SECONDS are consts, not readable via get() from outside
	# the script -- see the "const not readable via Object.get()" note this
	# session already ran into twice; hardcoded here to match the actual values.)
	const DAY_SECONDS := 120.0
	const NIGHT_SECONDS := 90.0
	controller.call("_update_day_night", DAY_SECONDS + 1.0)
	if not bool(controller.get("_is_night")):
		_fail("Expected the cycle to flip to Night after DAY_SECONDS elapsed")
		return
	var night_multiplier := float(economy_manager.get("income_multiplier"))
	if not is_equal_approx(night_multiplier, 0.85):
		_fail("Expected the Night economy multiplier to apply on flip, got %s" % night_multiplier)
		return
	var night_chance := float(controller.call("heavy_defender_chance"))
	if not is_equal_approx(night_chance, 0.55):
		_fail("Expected the Night heavy-defender chance to be 0.55, got %s" % night_chance)
		return

	# A small delta right after the flip should not immediately flip back to Day.
	controller.call("_update_day_night", 1.0)
	if not bool(controller.get("_is_night")):
		_fail("Should still be Night after only 1 more second")
		return

	# A second large delta (past NIGHT_SECONDS) should flip back to Day.
	controller.call("_update_day_night", NIGHT_SECONDS + 1.0)
	if bool(controller.get("_is_night")):
		_fail("Expected the cycle to flip back to Day after NIGHT_SECONDS elapsed")
		return
	if not is_equal_approx(float(economy_manager.get("income_multiplier")), 1.15):
		_fail("Expected the Day economy multiplier to reapply on flip back")
		return

	print("[DayNightCycleSmokeTest] day<->night<->day transitions and hooked multipliers all correct")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
