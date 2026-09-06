extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	print("[SteelGame] ",label," ",ok)
	if not ok: failures+=1
func _run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1440,1000)
	root.content_scale_size = root.size
	root.get_node("GameSession").start_new_game("steel-force-review","bad_kon_willow","seeded_grid_frontier","",true)
	var stage: Node = load("res://scripts/map/main_map.tscn").instantiate()
	root.add_child(stage)
	var terrain: Node = stage.get_node("MapGenerator")
	while not bool(terrain.get("generation_complete")): await process_frame
	for i in 10: await process_frame
	var director: WaveDirector = stage.get_node("WaveDirector")
	director.enabled = false
	director.enemy_faction = "steel_force"
	director.wave_index = 1
	check(director._enemy_archetype_for_wave(0)==&"poorper","Tier 1 wave")
	director.wave_index = 4
	check(director._enemy_archetype_for_wave(0)==&"proper_blimp","Tier 2 blimp wave")
	var bridge: BlockNavBridge = stage.get_node("BlockNavBridge")
	var taken: Array[Rect2i] = []
	var site := bridge.find_flat_site(Vector2i(14,14),taken)
	check(site.x>=0,"Flat test site")
	if site.x<0: quit(1); return
	var center: Vector2 = terrain.cell_to_world(site+Vector2i(6,6))
	var enemy: Node = director._spawn_enemy(&"proper_blimp",site+Vector2i(11,11),stage,center)
	check(enemy.get("passengers").size()==3,"Enemy wave spawns real crew")
	for passenger in enemy.get("passengers"):
		check(passenger.owner_player_id==2 and passenger.is_banished(),"Enemy crew ownership and exclusion")
	enemy.queue_free()
	await process_frame
	var units: Array[RTSUnit] = []
	for id in ["poorper","steel_knight","proper_blimp"]:
		var unit: RTSUnit = director._scene_for_test_unit(StringName(id)).instantiate()
		unit.owner_player_id = 1
		stage.add_child(unit)
		unit.global_position = center+Vector2((units.size()-1)*160,0)
		units.append(unit)
	for i in 3: await process_frame
	var blimp: RTSUnit = units[2]
	check(blimp.activate_land(),"Live map landing")
	var crew: Array[RTSUnit] = []
	for i in 3:
		var unit: RTSUnit = load("res://scenes/units/poorper.tscn").instantiate()
		unit.owner_player_id = 1
		stage.add_child(unit)
		unit.global_position = blimp.global_position+Vector2(80+i*12,0)
		unit.nav_level = blimp.nav_level
		crew.append(unit)
		check(blimp.board(unit),"Live board "+str(i))
	check(blimp.activate_takeoff(),"Live takeoff")
	blimp.issue_move_order(blimp.global_position+Vector2(0,120))
	for i in 100:
		blimp.rts_movement_tick(0.05)
	check(blimp.passengers.size()==3,"Crew carried intact")
	check(blimp.activate_land(),"Live landing after movement")
	check(blimp.activate_unload(),"Live unload")
	for unit in units: unit.issue_stop_order()
	var view: Node = stage.get_node("Map3DView")
	stage.get_node("FogOfWar").set_reveal_all(true)
	view.focus_on_sim_position(center)
	view.set_camera_distance(19.0)
	view.get("camera").make_current()
	if DisplayServer.get_name() != "headless":
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR").path_join("steel_force_ingame.png"))
	check(units[0].get_node("ArtSprite").texture.resource_path.contains("steel_force"),"Real scene painted art")
	stage.queue_free()
	for i in 5: await process_frame
	print("[SteelGame] failures=",failures)
	quit(0 if failures==0 else 1)
