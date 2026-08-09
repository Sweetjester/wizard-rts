extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "flow-field-smoke", "bad_kon_willow", "seeded_grid_frontier")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
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
	for _i in 180:
		await process_frame
		await physics_frame
	enemies = _enemy_units()
	var final_distance := _average_distance_to(enemies, target)
	var after_stats: Dictionary = map.call("get_path_telemetry")
	var flow_uses := int(after_stats.get("units_using_flow_field", 0)) - before_flow_uses
	var recomputes := int(after_stats.get("flow_field_recomputes", 0)) - before_recomputes
	if recomputes <= 0:
		_fail("Expected at least one flow-field recompute")
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
