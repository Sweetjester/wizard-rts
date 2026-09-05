extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	print("[VaultGame] ",label," ",ok)

func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(1))
	root.get_node("GameSession").start_new_game("vault-integration","bad_kon_willow","seeded_grid_frontier","",true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node = stage.get_node("MapGenerator")
	while not bool(terrain.get("generation_complete")): await process_frame
	for i in 10: await process_frame
	var bridge: BlockNavBridge = stage.get_node("BlockNavBridge")
	var build: BuildSystem = stage.get_node("BuildSystem")
	var taken: Array[Rect2i] = []
	var origin := bridge.find_flat_site(Vector2i(9,7),taken)
	check(origin.x >= 0,"Valid site")
	if origin.x >= 0:
		check(build.try_place_structure(1,&"terrible_vault",origin),"Normal build placement")
		var base: int = terrain.get_height(origin)
		var start := origin+Vector2i(3,-1)
		var destination := origin+Vector2i(4,5)
		var visitor: Node2D = load("res://scenes/units/oaven_spear.tscn").instantiate()
		stage.add_child(visitor)
		visitor.set_physics_process(false)
		visitor.global_position = terrain.cell_to_world(start)
		visitor.set("nav_level",base)
		check(bridge.order_to(visitor,destination,base+4,&"infantry"),"Unit accepts gallery route")
		for step in 150:
			visitor.rts_movement_tick(1.0)
			if visitor.get("path").is_empty(): break
		check(visitor.global_position.distance_to(terrain.cell_to_world(destination))<1 and visitor.get("nav_level")==base+4,"Unit reaches gallery")
		var view: Node = stage.get_node("Map3DView")
		view._sync_block_gates()
		var visual: Node = view.get("_block_structure_root").get_node("Block_kons_observer_vault_01_%d_%d" % [origin.x,origin.y])
		check(visual.has_node("GothicDetails/VaultGate"),"Real map uses new skin")
		bridge.world.gate_states["vault_entry_open"] = false
		view._sync_block_gates()
		check(is_zero_approx(visual.get_node("GothicDetails/VaultGate").rotation.y),"Real map closes circular door")
	stage.queue_free()
	for i in 5: await process_frame
	print("[VaultGame] failures=",failures)
	quit(0 if failures==0 else 1)
