extends SceneTree

var failures := 0
class Map extends Node:
	var blocked: Dictionary = {}
	func world_to_cell(p: Vector2) -> Vector2i: return Vector2i((p/64.0).round())
	func cell_to_world(c: Vector2i) -> Vector2: return Vector2(c)*64.0
	func get_height(_c: Vector2i) -> int: return 0
	func is_walkable_cell(c: Vector2i) -> bool: return not blocked.has(c)

func check(ok: bool, message: String) -> void:
	if ok: print("[Mangler] PASS: ",message)
	else: failures += 1; push_error(message)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	create_timer(45).timeout.connect(func() -> void: push_error("Mangler test timeout"); quit(1))
	var stage := Node2D.new()
	root.add_child(stage)
	var map := Map.new()
	map.name = "MapGenerator"
	stage.add_child(map)
	var unit: Node2D = load("res://scenes/units/mangler.tscn").instantiate()
	stage.add_child(unit)
	unit.set_physics_process(false)
	await process_frame
	check(unit.unit_archetype==&"mangler" and unit.move_speed==160.0,"Base form uses the catalog and ground movement")
	check(UnitCatalog.is_unit_allowed_for_class(&"mangler","bad_kon_willow"),"Kon roster includes Mangler")
	check(UnitCatalog.get_definition(&"barracks").get("production",[]).has(&"mangler"),"Barracks production includes Mangler")
	for i in 5:
		unit.accumulate_momentum(64.0)
		check(unit.momentum_stacks==i+1,"Momentum stack %d" % (i+1))
	unit.accumulate_momentum(10000)
	check(unit.momentum_stacks==5 and is_equal_approx(unit._current_move_speed(),224.0),"Speed caps at +40 percent without compounding")
	unit.issue_stop_order()
	check(unit.momentum_stacks==0 and unit._current_move_speed()==160.0,"Stop clears stacks and bonus speed")
	var enemy := RTSUnit.new()
	enemy.owner_player_id = 2
	enemy.position = Vector2(64,0)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.max_health = 2000
	enemy.health = 2000
	enemy.armor = 0
	var ally := RTSUnit.new()
	ally.position = Vector2(80,0)
	stage.add_child(ally)
	ally.set_physics_process(false)
	var ally_hp := ally.health
	unit.accumulate_momentum(320)
	unit.resolve_collision(enemy)
	check(enemy.health==1964 and ally.health==ally_hp and unit.momentum_stacks==0,"Charged enemy contact damages enemies only and consumes stacks")
	unit.resolve_collision(enemy)
	check(enemy.health==1964,"Contact cannot retrigger without a new charge")
	unit.accumulate_momentum(320)
	unit.resolve_collision(ally)
	check(enemy.health==1964 and unit.momentum_stacks==0,"Friendly collision resets without an explosion")
	unit.accumulate_momentum(320)
	unit.resolve_collision(null)
	check(enemy.health==1964 and unit.momentum_stacks==0,"Terrain collision resets without an explosion")
	unit.accumulate_momentum(320)
	unit._fire_attack(enemy)
	check(enemy.health==1898,"Full-charge melee adds exactly one 36-damage area hit")
	unit._fire_attack(enemy)
	check(enemy.health==1868,"Subsequent melee attack is ordinary damage")
	check(not unit.cast_mangler_leap(Vector2(256,0)),"Wingless form cannot leap")
	unit.debug_force_evolve()
	check(unit.unit_archetype==&"winged_mangler" and not unit.ignores_terrain,"Evolution grants wings but not permanent flight")
	check(unit.max_health==UnitCatalog.fielded_max_hp(&"winged_mangler") and unit.attack_damage==UnitCatalog.fielded_attack_damage(&"winged_mangler"),"Evolution matches shared HP and damage accounting")
	check(not unit.cast_mangler_leap(Vector2(900,0)) and unit.leap_remaining==0.0,"Out-of-range target consumes no cooldown")
	map.blocked[Vector2i(4,0)] = true
	check(not unit.cast_mangler_leap(Vector2(256,0)),"Blocked terrain cannot be targeted")
	map.blocked.clear()
	enemy.position = Vector2(330,0)
	ally.position = Vector2(340,0)
	check(unit.cast_mangler_leap(Vector2(256,0)),"Valid clear ground starts manual leap")
	check(not unit.cast_mangler_leap(Vector2(256,0)),"Repeated input cannot start a second leap")
	var hp := enemy.health
	unit._fire_attack(enemy)
	check(enemy.health==hp,"Normal attacks disabled during leap")
	unit.rts_movement_tick(0.65)
	check(unit.leap_height>120.0 and unit.global_position.x>0.0,"Leap follows a lifted arc under central movement")
	unit.rts_movement_tick(0.42)
	check(unit.global_position==Vector2(256,0) and enemy.health==hp-65 and ally.health==ally_hp,"Landing damages enemies once without harming allies")
	check(enemy.stunned_until_msec>Time.get_ticks_msec(),"Landing applies stun")
	unit.rts_movement_tick(0.4)
	check(unit.leap_age<0 and unit.collision_layer==2 and unit.collision_mask==2 and enemy.health==hp-65,"Recovery restores collisions without repeated damage")
	check(not unit.cast_mangler_leap(Vector2(128,128)),"Leap cooldown is enforced after landing")
	unit.leap_remaining = 0
	unit.position = Vector2.ZERO
	check(unit.cast_mangler_leap(Vector2(256,128)),"Second legal leap starts after cooldown")
	map.blocked[Vector2i(4,2)] = true
	unit.rts_movement_tick(1.1)
	check(unit.global_position==Vector2.ZERO and enemy.health==hp-65,"New landing obstruction returns safely without damage")
	map.blocked.clear()
	unit.rts_movement_tick(0.3)
	unit.leap_remaining = 0
	unit.cast_mangler_leap(Vector2(256,128))
	unit.set_meta("kon_banished",true)
	unit.rts_movement_tick(0.5)
	check(unit.leap_age<0 and unit.leap_height==0 and unit.global_position==Vector2.ZERO,"Banish interrupts the leap without an impact")
	unit.set_meta("kon_banished",false)
	var art: Sprite2D = unit.get_node("ArtSprite")
	art._process(0.1)
	check(art.texture!=null and art.texture.resource_path.contains("winged_mangler"),"Evolution switches the painted atlas")
	for form in ["mangler", "winged_mangler"]:
		var img := Image.load_from_file("res://assets_game/units/kon/mangler/painted_v1/"+form+".png")
		check(img.get_size()==Vector2i(4608,3456),form+" atlas has 108 frames")
		var valid := true
		for row in 9:
			for frame in 12:
				var bounds := img.get_region(Rect2i(frame*384,row*384,384,384)).get_used_rect()
				if bounds.size.x<50 or bounds.size.y<40 or bounds.position.x<2 or bounds.end.x>382 or bounds.position.y<2 or bounds.end.y>382: valid=false
		check(valid,form+" frames contain visible, unclipped art")
	var before_count := stage.get_child_count()
	unit._spawn_death_fx()
	check(stage.get_child_count()==before_count+1,"Painted death sequence spawns a corpse")
	print("[Mangler] failures=",failures)
	stage.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
