extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _run() -> void:
	var atlas:=Image.load_from_file("res://assets_game/units/kon/spawner/painted_v2/spawner.png")
	if not _check(atlas.get_size()==Vector2i(4608,6144),"Atlas dimensions"): return
	for row in 16:
		var first: PackedByteArray
		var varied:=false
		for column in 12:
			var tile:=atlas.get_region(Rect2i(column*384,row*384,384,384))
			var bounds:=tile.get_used_rect()
			if not _check(bounds.has_area() and bounds.position.x>1 and bounds.position.y>1 and bounds.end.x<383 and bounds.end.y<383,"Empty or clipped row %s frame %s: %s" % [row,column,bounds]): return
			if column==0: first=tile.get_data()
			elif tile.get_data()!=first: varied=true
		if not _check(varied,"Action row %s has no motion" % row): return
	var stage:=Node2D.new()
	root.add_child(stage)
	var unit: Node2D=load("res://scenes/units/spawner.tscn").instantiate()
	stage.add_child(unit)
	unit.set_physics_process(false)
	var art: Sprite2D=unit.get_node("ArtSprite")
	art.set_process(false)
	art._process(0.01)
	if not _check(art.current_action==&"idle","Initial idle"): return
	unit.set("moving",true)
	unit.set("velocity",Vector2(-25,0))
	art._process(0.1)
	if not _check(art.current_action==&"move" and art.flip_h,"Movement and facing"): return
	if not _check(unit.call("activate_root"),"Root activation"): return
	unit.call("_update_spawner_root_casts",1.0)
	art._process(0.1)
	if not _check(art.current_action==&"root_cast" and art.frame%12==5,"Root uses actual cast progress"): return
	unit.call("_update_spawner_root_casts",1.1)
	art._process(0.1)
	if not _check(art.current_action==&"rooted_idle","Rooted hold"): return
	if not _check(unit.call("activate_summon_drone"),"Drone summon"): return
	art._process(0.1)
	if not _check(art.current_action==&"summon_drone" and unit.get("_drone_children").size()==1,"Successful brood event"): return
	art._process(1.2)
	var victim: Node2D=load("res://scenes/units/oaven_spear.tscn").instantiate()
	victim.set("owner_player_id",2)
	stage.add_child(victim)
	victim.set_physics_process(false)
	victim.position=Vector2(100,0)
	unit.call("_fire_attack",victim)
	art._process(0.01)
	if not _check(art.current_action==&"artillery_attack","Actual cannon event"): return
	art._process(1)
	if not _check(unit.call("activate_uproot"),"Uproot activation"): return
	unit.call("_update_spawner_root_casts",1)
	art._process(0.1)
	if not _check(art.current_action==&"uproot_cast" and art.frame%12==5,"Uproot progress"): return
	unit.call("_update_spawner_root_casts",1.1)
	unit.call("_evolve",UnitCatalog.get_definition(&"spawner"))
	art._process(0.01)
	if not _check(art.current_action==&"evolve_wings","Evolution cue"): return
	unit.set("ability_animation_action",&"")
	unit.call("_start_takeoff")
	unit.call("_update_winged_spawner_flight",0.25)
	art._process(0.01)
	if not _check(art.current_action==&"takeoff" and art.frame%12==5,"Takeoff progress"): return
	unit.set("_flight_state",&"flying")
	unit.set("unit_state",&"moving")
	unit.set("moving",true)
	art._process(0.1)
	if not _check(art.current_action==&"move_flying","Flying movement"): return
	unit.set("health",int(unit.get("health"))-5)
	art._process(0.01)
	if not _check(art.current_action==&"hit","Hit reaction"): return
	unit.call("_die")
	var corpse: Sprite2D=null
	for child in stage.get_children():
		if child is Sprite2D and child.get_script()==load("res://scripts/fx/painted_unit_death.gd"): corpse=child
	await process_frame
	if not _check(not is_instance_valid(unit) and is_instance_valid(corpse),"Corpse outlives unit"): return
	await create_timer(1.5).timeout
	if not _check(corpse.frame==119 and not corpse.is_in_group("units"),"Corpse final pose and no gameplay registration"): return
	await create_timer(2.8).timeout
	if not _check(not is_instance_valid(corpse),"Corpse cleanup"): return
	stage.queue_free()
	await process_frame
	print("[SpawnerArt] PASS: 192 animated/unclipped frames; movement, facing, root, summon, cannon, uproot, evolution, flight, hit, death")
	quit()
