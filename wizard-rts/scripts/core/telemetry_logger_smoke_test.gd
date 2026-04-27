extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("start_new_game", "telemetry-smoke", "bad_kon_willow", "ai_testing_ground")
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var wave_director: Node = scene.get_node("WaveDirector")
	wave_director.call("spawn_ai_test_wave")
	await process_frame
	await physics_frame
	var logger: Node = scene.get_node("TelemetryLogger")
	logger.call("capture_sample")
	logger.call("finalize", "smoke_test")
	var paths: Dictionary = logger.call("get_export_paths")
	var summary_path := str(paths.get("summary", ""))
	var samples_path := str(paths.get("samples", ""))
	if not FileAccess.file_exists(summary_path):
		push_error("Telemetry summary was not written: %s" % summary_path)
		quit(1)
		return
	if not FileAccess.file_exists(samples_path):
		push_error("Telemetry samples were not written: %s" % samples_path)
		quit(1)
		return
	var summary_text := FileAccess.get_file_as_string(summary_path)
	if not summary_text.contains("peak_units_observed"):
		push_error("Telemetry summary missing expected fields")
		quit(1)
		return
	print("[TelemetryLoggerSmokeTest] exported=", paths.get("folder", ""))
	quit(0)
