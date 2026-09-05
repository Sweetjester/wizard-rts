extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "flow-field-smoke", "bad_kon_willow", "seeded_grid_frontier")
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
	for _i in 8:
		await process_frame
		await physics_frame

	var map: Node = scene.get_node("MapGenerator")
	var wave_director: Node = scene.get_node("WaveDirector")
	if map == null or wave_director == null:
		_fail("Expected MapGenerator and WaveDirector")
		return
	var target: Vector2 = wave_director.call("_player_target_world")
	if target == Vector2.ZERO:
		_fail("Expected a player wave target")
		return
	var before_stats: Dictionary = map.call("get_path_telemetry")
	var before_flow_uses := int(before_stats.get("units_using_flow_field", 0))
	var before_recomputes := int(before_stats.get("flow_field_recomputes", 0))

	wave_director.call("_spawn_wave")
	for _i in 20:
		await process_frame
		await physics_frame

	var enemies := _enemy_units()
	if enemies.is_empty():
		_fail("Expected regular wave enemies to spawn")
		return
	var initial_distance := _average_distance_to(enemies, target)
	# A longer window than the 180 frames this used when the frontier was 96x96.
	# The map is 160x160 now and carries a 96-cell fortress in the middle of it,
	# so a wave that has to walk around the citadel makes very little progress in
	# straight-line terms early on -- it is going sideways on purpose. Measured
	# on the map as it stands: ~148px of progress at 180 frames, ~487px at 540.
	for _i in 540:
		await process_frame
		await physics_frame
	enemies = _enemy_units()
	var final_distance := _average_distance_to(enemies, target)
	var after_stats: Dictionary = map.call("get_path_telemetry")
	var flow_uses := int(after_stats.get("units_using_flow_field", 0)) - before_flow_uses
	var recomputes := int(after_stats.get("flow_field_recomputes", 0)) - before_recomputes
	# NOT "did a rebuild happen during this window". The frontier now carries the
	# citadel, whose placement invalidates the path cache and warms a field for
	# the wave target before the first wave ever spawns -- so the wave finds the
	# field already built and correctly does not rebuild it. A cache hit is the
	# desired outcome, and asserting a cache MISS made a faster game look broken.
	#
	# What actually has to be true is that a field exists and that it routes the
	# wave, which is a stronger claim than a counter going up.
	if int(after_stats.get("flow_field_recomputes", 0)) <= 0:
		_fail("No flow field was ever built for the wave target")
		return
	var routed := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and bool(map.call("has_flow_field_route_world", enemy.global_position, target)):
			routed += 1
	if routed < maxi(1, enemies.size() / 2):
		_fail("Only %s of %s wave units have a flow-field route to the target" % [routed, enemies.size()])
		return
	if flow_uses < maxi(1, enemies.size() / 2):
		_fail("Expected most wave units to sample the flow field, got %s for %s enemies" % [flow_uses, enemies.size()])
		return
	if final_distance >= initial_distance - 16.0:
		_fail("Expected enemies to make progress toward target, initial=%s final=%s" % [initial_distance, final_distance])
		return
	print("[FlowFieldSmokeTest] enemies=", enemies.size(),
		" initial_avg_distance=", snapped(initial_distance, 0.01),
		" final_avg_distance=", snapped(final_distance, 0.01),
		" flow_field_recomputes=", recomputes,
		" units_using_flow_field=", flow_uses,
		" path_requests=", after_stats.get("path_requests", 0),
		" path_cache_hits=", after_stats.get("path_cache_hits", 0))
	quit(0)

func _enemy_units() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for unit in get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D and int(unit.get("owner_player_id")) == 2:
			result.append(unit)
	return result

func _average_distance_to(units: Array[Node2D], target: Vector2) -> float:
	if units.is_empty():
		return INF
	var total := 0.0
	for unit in units:
		total += unit.global_position.distance_to(target)
	return total / float(units.size())

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
