extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
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
	await physics_frame

	var wizard: Node = scene.get_node("Wizard")
	if wizard.has_method("summon_treants"):
		push_error("Kon should no longer have the outdated treant summon ability")
		quit(1)
		return

	print("[TreantSummonSmokeTest] Kon treant summon removed")
	quit(0)
