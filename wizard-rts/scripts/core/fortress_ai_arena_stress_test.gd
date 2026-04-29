extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "fortress-stress", "bad_kon_willow", "fortress_ai_arena")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	for _i in 8:
		await process_frame
		await physics_frame

	var wave_director: Node = scene.get_node("WaveDirector")
	var rts_world: RTSWorld = scene.get_node("RTSWorld")
	var combat_system: Node = scene.get_node("CombatSystem")
	var queued: Dictionary = wave_director.call("queue_ai_test_until", 3000)
	for _i in 1200:
		await process_frame
		await physics_frame
	var telemetry := rts_world.get_observation_telemetry()
	var combat: Dictionary = combat_system.call("get_combat_telemetry")
	print("[FortressAIArenaStressTest] queued=", queued, " units=", telemetry.get("units", 0), " structures=", telemetry.get("structures", 0), " avg_candidates=", combat.get("combat_avg_candidates", 0.0), " combat_ms=", combat.get("combat_tick_ms", 0.0))
	if int(telemetry.get("structures", 0)) > 20:
		push_error("Fortress stress test should use lightweight fort walls")
		quit(1)
		return
	if float(combat.get("combat_avg_candidates", 0.0)) > 24.0:
		push_error("Combat candidates remain too high for mass combat")
		quit(1)
		return
	quit(0)
