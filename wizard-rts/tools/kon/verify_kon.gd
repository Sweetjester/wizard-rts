extends SceneTree

var failures := 0
class FlatMap extends Node:
	var MAP_W := 64
	var MAP_H := 64
	var generation_complete := false
	func is_walkable_cell(cell: Vector2i) -> bool: return Rect2i(0,0,64,64).has_point(cell)
	func get_height(_cell: Vector2i) -> int: return 0
	func is_cliff_edge_cell(_cell: Vector2i) -> bool: return false
	func cell_to_world(cell: Vector2i) -> Vector2: return Vector2(cell)*64.0+Vector2(32,32)
	func world_to_cell(pos: Vector2) -> Vector2i: return Vector2i((pos/64.0).floor())
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
	else: print("[Kon] PASS: ",message)

func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void: push_error("Kon test timed out"); quit(1))
	var atlas := Image.load_from_file("res://assets_game/units/kon/hero/painted_v2/kon.png")
	check(atlas.get_size()==Vector2i(4608,3072),"96-frame atlas dimensions")
	for row in 8:
		var varied := false
		var first := atlas.get_region(Rect2i(0,row*384,384,384)).get_data()
		for col in 12:
			var tile := atlas.get_region(Rect2i(col*384,row*384,384,384))
			var bounds := tile.get_used_rect()
			check(bounds.has_area() and bounds.position.x>1 and bounds.position.y>1 and bounds.end.x<383 and bounds.end.y<383,"Unclipped frame %s:%s" % [row,col])
			if tile.get_data()!=first: varied=true
		check(varied,"Motion in row %s" % row)
	var spells := Image.load_from_file("res://assets_game/units/kon/hero/painted_v2/spells.png")
	check(spells.get_pixel(0,0).a<0.01,"Spell sheet genuine alpha")
	var stage := Node2D.new()
	root.add_child(stage)
	var economy := EconomyManager.new()
	economy.name="EconomyManager"
	stage.add_child(economy)
	var kon: Node2D=load("res://scenes/wizard.tscn").instantiate()
	stage.add_child(kon)
	kon.set_physics_process(false)
	var ally: Node2D=load("res://scenes/units/oaven_spear.tscn").instantiate()
	stage.add_child(ally)
	ally.set_physics_process(false)
	ally.position=Vector2(250,0)
	var enemy: Node2D=load("res://scenes/units/oaven_spear.tscn").instantiate()
	enemy.set("owner_player_id",2)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position=Vector2(280,0)
	var art: Sprite2D=kon.get_node("ArtSprite")
	check(art.hframes==12 and art.vframes==8 and art.has_meta("death_row"),"Live wizard uses new artwork")
	var selection: Node=load("res://scripts/input/selection_controller.gd").new()
	stage.add_child(selection)
	selection.begin_kon_spell(kon,&"seal_away")
	check(selection._pending_target_command==&"seal_away" and is_instance_valid(selection._kon_spell_preview),"Target mode creates radius preview")
	var cancel := InputEventMouseButton.new()
	cancel.button_index=MOUSE_BUTTON_RIGHT
	cancel.pressed=true
	selection._unhandled_input(cancel)
	check(selection._pending_target_command==&"" and selection._kon_spell_preview==null,"Right-click cancels without issuing movement")
	selection.begin_kon_spell(kon,&"biostorm")
	selection._issue_pending_target_command(Vector2(9999,0))
	check(selection._pending_target_command==&"biostorm","Rejected target remains in aiming mode")
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	selection._unhandled_input(escape)
	check(selection._pending_target_command==&"","Escape cancels targeting")
	check(kon.cast_kon_spell(&"seal_away",Vector2(260,0)),"Seal cast")
	var hp: int=enemy.health
	check(ally.is_banished() and enemy.is_banished() and not kon.is_banished(),"Circle banishes friend and foe only inside radius")
	enemy.take_damage(999,kon)
	check(enemy.health==hp and not kon.can_engage_target(enemy),"Banish blocks damage and targeting")
	check(not kon.cast_kon_spell(&"seal_away",Vector2(260,0)),"Seal cooldown rejects repeat")
	await create_timer(4.7).timeout
	check(ally.is_banished(),"Banish persists before five seconds")
	await create_timer(0.4).timeout
	check(not ally.is_banished() and not enemy.is_banished() and enemy.health==hp,"Same units return after five seconds, HP preserved")
	check(kon.activate_observer_aura(),"Observation enters")
	var location: Vector2=kon.position
	kon.issue_move_order(Vector2(300,0))
	kon.rts_movement_tick(0.5)
	check(kon.position==location and not kon.moving and kon.sight_radius_cells()==18,"Observation immobile and doubles sight")
	check(not kon.cast_kon_spell(&"biostorm",Vector2(250,0)),"Observation requires cancellation before casting")
	kon.activate_observer_aura()
	check(kon.sight_radius_cells()==9,"Cancel restores sight")
	var bio: int=economy.get_resources()[&"bio"]
	check(not kon.cast_kon_spell(&"biostorm",Vector2(9999,0)) and economy.get_resources()[&"bio"]==bio,"Out-of-range cast costs nothing")
	check(kon.cast_kon_spell(&"biostorm",Vector2(180,0)),"Biostorm cast")
	check(economy.get_resources()[&"bio"]==bio-60,"Biostorm pays exactly 60 Bio")
	var ally_hp: int=ally.health
	var kon_hp: int=kon.health
	await create_timer(0.6).timeout
	check(ally.health<ally_hp and enemy.health<hp and kon.health<kon_hp,"Storm damages allies, enemies and caster")
	check(not kon.cast_kon_spell(&"biostorm",Vector2(180,0)),"Biostorm cooldown")
	await create_timer(3.6).timeout
	var storms := 0
	for child in stage.get_children():
		if child.get_script()==load("res://scripts/fx/kon_spell_fx.gd") and child.action==&"biostorm": storms+=1
	check(storms==0,"Storm expires independently")
	kon.kon_abilities.cooldowns[&"biostorm"]=0.0
	economy.spend(1,{&"bio":economy.get_resources()[&"bio"]})
	check(not kon.cast_kon_spell(&"biostorm",Vector2.ZERO),"Insufficient Bio refuses cast")
	var map := FlatMap.new()
	map.name="MapGenerator"
	stage.add_child(map)
	var bridge := BlockNavBridge.new()
	bridge.name="BlockNavBridge"
	stage.add_child(bridge)
	bridge.terrain=map
	bridge.world=BlockNavWorld.new(bridge.library.unit_classes)
	bridge.world.build_from_terrain(map)
	bridge.world.place_structure(bridge.library.get_definition(&"kons_observation_wizard_tower_01"),Vector2i(10,10),0,&"owned_tower",1)
	var build := BuildSystem.new()
	build.name="BuildSystem"
	stage.add_child(build)
	build.set_process(false)
	build.structures.append({"player_id":1,"complete":true,"block_structure":&"kons_observation_wizard_tower_01","block_instance":&"owned_tower"})
	var crown := Vector2i(18,18)
	kon.position=map.cell_to_world(crown)
	kon.nav_level=24
	kon.activate_observer_aura()
	check(not kon.kon_abilities.observer_at_tower_top(),"Near crown but wrong floor gets no Observer bonus")
	kon.nav_level=26
	check(kon.kon_abilities.observer_at_tower_top() and kon.sight_radius_cells()==36,"Owned rotated tower crown multiplies Observation sight")
	check(kon.can_remote_summon(kon.position+Vector2(1000,0)) and not kon.can_remote_summon(kon.position+Vector2(3000,0)),"Observer remote summon radius enforced")
	build.structures[0].player_id=2
	check(not kon.kon_abilities.observer_at_tower_top(),"Enemy tower cannot confer Observer")
	build.structures[0].player_id=1
	build.structures[0].complete=false
	check(not kon.kon_abilities.observer_at_tower_top(),"Unfinished tower cannot confer Observer")
	kon.activate_observer_aura()
	kon.position=Vector2.ZERO
	kon.nav_level=0
	enemy=load("res://scenes/units/oaven_spear.tscn").instantiate()
	enemy.set("owner_player_id",2)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position=Vector2(100,0)
	enemy.health=200
	hp=enemy.health
	kon._fire_attack(enemy)
	kon._fire_attack(enemy)
	await create_timer(0.31).timeout
	check(enemy.health<hp,"Broken Staff first impact")
	var after_first: int=enemy.health
	await create_timer(0.35).timeout
	check(enemy.health<after_first,"Broken Staff distinct second impact")
	kon._die()
	await process_frame
	var corpse: Sprite2D
	for child in stage.get_children():
		if child.get_script()==load("res://scripts/fx/painted_unit_death.gd"): corpse=child
	check(not is_instance_valid(kon) and is_instance_valid(corpse),"Hero removed while painted death remains")
	await create_timer(1.35).timeout
	check(is_instance_valid(corpse) and corpse.frame==95,"Death reaches final collapsed pose")
	stage.queue_free()
	await process_frame
	print("[Kon] failures=",failures)
	quit(1 if failures else 0)
