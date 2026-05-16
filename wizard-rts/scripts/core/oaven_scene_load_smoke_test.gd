extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/units/oaven_spear.tscn")
	if scene == null:
		push_error("Oaven scene failed to load")
		quit(1)
		return
	var unit := scene.instantiate()
	root.add_child(unit)
	print("[OavenSceneLoadSmokeTest] Loaded Oaven scene as %s" % str(unit.get("unit_archetype")))
	quit(0)
