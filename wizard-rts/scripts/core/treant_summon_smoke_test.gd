extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var wizard: Node = scene.get_node("Wizard")
	if wizard.has_method("summon_treants"):
		push_error("Kon should no longer have the outdated treant summon ability")
		quit(1)
		return

	print("[TreantSummonSmokeTest] Kon treant summon removed")
	quit(0)
