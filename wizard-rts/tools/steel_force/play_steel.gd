extends SceneTree

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.get_node("GameSession").start_new_game("steel-force-skirmish","bad_kon_willow","seeded_grid_frontier","",true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	var director: WaveDirector = stage.get_node("WaveDirector")
	director.enemy_faction = "steel_force"
	print("[SteelForce] Skirmish enabled: Poorpers, Knights and crewed Proper Blimps. Existing wave schedule retained.")
