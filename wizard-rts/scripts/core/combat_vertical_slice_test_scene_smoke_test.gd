extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/tests/combat_vertical_slice_test.tscn")
	if scene == null:
		push_error("Combat vertical slice test scene failed to load")
		quit(1)
		return
	var node := scene.instantiate()
	root.add_child(node)
	await process_frame
	var world: RTSWorld = node.get_node("RTSWorld")
	if world.all_units().size() < 2:
		push_error("Expected KON and enemy units in combat test scene")
		quit(1)
		return
	if world.all_structures().size() < 2:
		push_error("Expected HQ and enemy outpost structures in combat test scene")
		quit(1)
		return
	print("[CombatVerticalSliceTestSceneSmokeTest] Scene loads with units and structures registered.")
	quit(0)
