extends SceneTree

# Cost + correctness guard for the flow-field rebuild, added 2026-08-31 after
# Andrew's telemetry showed the game freezing repeatedly during normal play.
#
# Root cause, from `test_exports/session_data/20260831 180830_...`: every
# flow-field recompute blocked the physics frame for ~1.27s, and
# physics_ms / flow_field_recomputes came out at ~1270ms in every single spike
# sample, at unit counts from 23 to 81. The cost scales with MAP AREA, not unit
# count, so no amount of unit-scaling stress testing would ever have caught it --
# and `flow_field_smoke_test.gd` passed throughout, because it only ever checked
# that units make progress toward their target.
#
# This test therefore asserts on TIME as well as behaviour. It is the pattern the
# 2026-08-23 Decisions Log entry asked for: "smoke tests check correctness ...
# passing correctly while being slow is invisible to that bar".

# Generous vs the ~79ms measured after the fix, tight vs the ~1220ms before it.
# The point is to fail loudly if the O(n) frontier insert, the per-call
# traversability recompute, or the clear-everything-on-blocker-change behaviour
# ever comes back -- not to police small regressions on slower machines.
const REBUILD_BUDGET_MS := 400.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "flow-field-cost-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 4:
		await process_frame

	var map_generator: Node = scene.get_node_or_null("MapGenerator")
	if map_generator == null:
		_fail("Expected a MapGenerator")
		return

	var target: Vector2i = map_generator.call("nearest_walkable_cell", Vector2i(33, 37), 24)
	if not bool(map_generator.call("_is_path_traversable_cell", target)):
		_fail("Test target cell %s should be traversable" % target)
		return

	# --- first build, cold caches -----------------------------------------
	var first: Dictionary = _timed_build(map_generator, target)
	var reached := int(first["field"].get("cells_reached", 0))
	if reached < 500:
		_fail("Expected the flow field to reach a large part of the map, got %s cells" % reached)
		return

	# --- the case that actually froze the game -----------------------------
	# A building going down invalidates the path cache. That used to throw away
	# every cached traversability answer and force a full recompute; the terrain
	# caches must now survive it.
	map_generator.call("_invalidate_path_cache")
	var second: Dictionary = _timed_build(map_generator, target)
	if int(second["field"].get("cells_reached", 0)) != reached:
		_fail("A path-cache invalidation must not change what the flow field reaches (%s vs %s)" % [second["field"].get("cells_reached", 0), reached])
		return
	if float(second["ms"]) > REBUILD_BUDGET_MS:
		_fail("Flow-field rebuild after a blocker change took %.1fms, budget is %.0fms. This is the regression that froze the game -- see the header." % [second["ms"], REBUILD_BUDGET_MS])
		return

	# --- blockers must still block ----------------------------------------
	# Wall off the ring immediately around the target. Nothing outside it should
	# be able to route in any more, which proves blockers are still applied even
	# though the terrain neighbour sets are cached.
	var wall: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			wall.append(target + Vector2i(dx, dy))
	map_generator.call("add_dynamic_blockers", wall)
	var walled: Dictionary = _timed_build(map_generator, target)
	var walled_reached := int(walled["field"].get("cells_reached", 0))
	if walled_reached != 1:
		_fail("A fully walled-in target should reach only itself, reached %s cells" % walled_reached)
		return
	if float(walled["ms"]) > REBUILD_BUDGET_MS:
		_fail("Flow-field rebuild with blockers took %.1fms, budget is %.0fms" % [walled["ms"], REBUILD_BUDGET_MS])
		return

	# --- and removing them must restore the map ---------------------------
	map_generator.call("remove_dynamic_blockers", wall)
	var restored: Dictionary = _timed_build(map_generator, target)
	if int(restored["field"].get("cells_reached", 0)) != reached:
		_fail("Removing blockers should restore the original reachable set (%s vs %s)" % [restored["field"].get("cells_reached", 0), reached])
		return

	# --- a diagonal squeeze must stay closed ------------------------------
	# The terrain neighbour sets are cached without blockers, so the diagonal
	# corner-cutting rule has to be re-applied per edge at expansion time. If it
	# were not, units would slip diagonally between two blocked cells.
	var corner_a := target + Vector2i(1, 0)
	var corner_b := target + Vector2i(0, 1)
	var diagonal := target + Vector2i(1, 1)
	if bool(map_generator.call("_is_path_traversable_cell", diagonal)):
		map_generator.call("add_dynamic_blockers", [corner_a, corner_b] as Array[Vector2i])
		var squeezed: Dictionary = _timed_build(map_generator, target)
		var next_cells: Dictionary = squeezed["field"].get("next_cells", {})
		if next_cells.has(diagonal) and next_cells[diagonal] == target:
			_fail("A diagonal step between two blocked cells must not be allowed")
			return
		map_generator.call("remove_dynamic_blockers", [corner_a, corner_b] as Array[Vector2i])

	print("[FlowFieldCostSmokeTest] rebuild after a blocker change: %.1fms (budget %.0fms), first build %.1fms, %s cells reached" % [
		float(second["ms"]), REBUILD_BUDGET_MS, float(first["ms"]), reached,
	])
	quit(0)

func _timed_build(map_generator: Node, target: Vector2i) -> Dictionary:
	# Drop the field cache only, so each call measures a real recompute.
	map_generator.set("_flow_field_cache", {})
	var started := Time.get_ticks_usec()
	var field: Dictionary = map_generator.call("_build_flow_field", target)
	return {"field": field, "ms": float(Time.get_ticks_usec() - started) / 1000.0}

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
