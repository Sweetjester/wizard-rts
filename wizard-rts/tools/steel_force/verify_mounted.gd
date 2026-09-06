extends SceneTree
const Art := preload("res://scripts/units/mounted_knight_art.gd")
const Records := preload("res://scripts/ui/vault_records.gd")
var failures := 0

class Terrain extends Node:
	var blocked := false
	func cell_to_world(cell: Vector2i) -> Vector2: return Vector2(cell)*64
	func world_to_cell(pos: Vector2) -> Vector2i: return Vector2i(pos/64)
	func is_walkable_cell(_cell: Vector2i) -> bool: return not blocked
	func get_height(_cell: Vector2i) -> int: return 0
	func get_spawn_position() -> Vector2i: return Vector2i(99,99)
	func nearest_walkable_cell(cell: Vector2i) -> Vector2i: return cell

class Selection extends Node:
	var selected_units: Array[Node] = []
	func _apply_selection(nodes: Array[Node]) -> void: selected_units=nodes

class Research extends Node:
	func _apply_upgrades_to_unit(unit: Node) -> void: unit.max_health+=40

func check(ok: bool, label: String) -> void:
	if ok: print("[Mounted] PASS: ",label)
	else: failures+=1; push_error(label)

func _initialize() -> void: call_deferred("run")

func spawn(stage: Node2D, owner: int=2) -> RTSUnit:
	var unit: RTSUnit = load("res://scenes/units/mounted_knight.tscn").instantiate()
	unit.owner_player_id=owner
	stage.add_child(unit)
	unit.set_process(false)
	unit.set_physics_process(false)
	unit.get_node("ArtSprite").set_process(false)
	return unit

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Mounted test timeout"); quit(1))
	var hashes := {}
	for direction in Art.DIRECTIONS:
		var img := Image.load_from_file(Art.ROOT+"mounted_knight_"+direction+".png")
		check(img!=null and img.get_size()==Vector2i(2048,2816),direction+" atlas dimensions")
		if img==null: continue
		var valid := true
		var motion := true
		for row in 11:
			var frames := {}
			for f in 8:
				var cell := img.get_region(Rect2i(f*256,row*256,256,256))
				var box := cell.get_used_rect()
				if box.size.x<20 or box.size.y<20 or box.position.x<2 or box.position.y<2 or box.end.x>254 or box.end.y>254:
					valid=false
					print(direction," row=",row," frame=",f," bounds=",box)
				frames[hash(cell.get_data())]=true
			if frames.size()<2: motion=false
		check(valid,direction+" all 88 frames visible and unclipped")
		check(motion,direction+" all eleven actions visibly animate")
		var key := hash(img.get_region(Rect2i(0,0,256,256)).get_data())
		check(not hashes.has(key),direction+" distinct directional art")
		hashes[key]=true
		var page: Texture2D = load(Art.ROOT+"mounted_knight_"+direction+".png")
		check(page.get_image().is_compressed(),direction+" GPU compressed")
	var stage := Node2D.new()
	root.add_child(stage)
	var terrain := Terrain.new()
	terrain.name="MapGenerator"
	stage.add_child(terrain)
	var selection := Selection.new()
	selection.name="SelectionController"
	stage.add_child(selection)
	var research := Research.new()
	research.name="BuildSystem"
	stage.add_child(research)
	var unit := spawn(stage)
	var art: Sprite2D = unit.get_node("ArtSprite")
	art._process(0)
	check(UnitCatalog.tier_of(&"mounted_knight")==3 and unit.max_health==620 and unit.attack_damage==54,"Tier 3 heavy catalog applied")
	var base_speed := unit._current_move_speed()
	unit.accumulate_momentum(-99)
	check(unit.momentum_stacks==0,"Negative travel cannot grant stacks")
	unit.accumulate_momentum(63)
	check(unit.momentum_stacks==0,"A full cell is needed for first stack")
	unit.accumulate_momentum(1)
	check(unit.momentum_stacks==1 and is_equal_approx(unit._current_move_speed(),base_speed*1.08),"First stack grants eight percent speed")
	unit.accumulate_momentum(256)
	check(unit.momentum_stacks==5 and is_equal_approx(unit._current_move_speed(),base_speed*1.4) and unit.flame_remaining==12,"Five cells ignite axe for twelve seconds and cap speed at +40 percent")
	unit._tick_presentation_timers(3)
	unit.accumulate_momentum(999)
	check(unit.flame_remaining==9,"Staying at max stacks does not refresh flame")
	unit.issue_stop_order()
	check(unit.momentum_stacks==0 and unit.flame_remaining==9,"Stop clears momentum but preserves active flame")
	unit.accumulate_momentum(320)
	check(unit.flame_remaining==9,"Recharging during flame does not extend it")
	unit.resolve_collision(null)
	check(unit.momentum_stacks==0 and unit.flame_remaining==9,"Collision clears stacks without extinguishing axe")
	check(Records.specimen_stats(weakref(unit)).attack_damage==81 and unit.attack_damage==54,"Live display includes buff without mutating base damage")
	var enemy: RTSUnit = load("res://scenes/units/steel_knight.tscn").instantiate()
	enemy.owner_player_id=1
	stage.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.armor=0
	enemy.position=Vector2(500,500)
	var hp := enemy.health
	unit._fire_attack(enemy,2)
	check(hp-enemy.health==162,"Fire multiplies current melee damage and incoming modifiers exactly once")
	unit._tick_presentation_timers(8.99)
	check(unit.is_ablaze(),"Flame active immediately before twelve-second deadline")
	unit._tick_presentation_timers(.02)
	check(not unit.is_ablaze() and unit.current_attack_damage_for_display()==54,"Fire expires and base damage remains intact")
	unit.accumulate_momentum(320)
	check(unit.is_ablaze() and unit.flame_remaining==12,"Fresh charge after expiry can ignite again")
	unit._tick_presentation_timers(12)
	unit.accumulate_momentum(64)
	check(not unit.is_ablaze(),"No automatic re-ignition from continuously held five stacks")
	unit.issue_hold_position_order()
	check(unit.momentum_stacks==0,"Hold resets charge")
	unit.stun_for_seconds(2)
	unit.accumulate_momentum(320)
	check(unit.momentum_stacks==0,"Stun cannot build charge")
	unit.stunned_until_msec=0
	unit.set_meta("kon_banished",true)
	unit.accumulate_momentum(320)
	check(unit.momentum_stacks==0,"Banishment cannot build charge")
	unit.remove_meta("kon_banished")
	unit.attack_visual_age=99
	for i in 8:
		unit.velocity=Vector2.from_angle(i*PI/4)*100
		art.frame=13
		art.sync_view_facing()
		check(art.facing_index==i and not art.flip_h and art.frame==13,"Direction "+Art.DIRECTIONS[i]+" preserves animation phase")
	unit.velocity=Vector2.ZERO
	art.sync_view_facing()
	check(art.facing_index==7,"Stopped mount remembers heading")
	unit.attack_target=enemy
	enemy.position=Vector2(0,100)
	art.sync_view_facing()
	check(art.facing_index==2,"Attack target controls facing")
	enemy.health=0
	unit.velocity=Vector2.LEFT*100
	art.sync_view_facing()
	check(art.facing_index==4,"Dead targets do not pin facing")
	unit.attack_target=null
	unit.moving=true
	art._process(0)
	check(art.current_action==&"move","Ordinary gallop")
	unit.accumulate_momentum(64)
	art._process(0)
	check(art.current_action==&"charge","Momentum gallop")
	unit.accumulate_momentum(256)
	art._process(0)
	check(art.current_action==&"ignite","Ignition visible")
	unit.ignition_age=1
	art._process(0)
	check(art.current_action==&"ablaze_move","Burning gallop")
	unit.moving=false
	art._process(0)
	check(art.current_action==&"ablaze_idle","Flame persists while stationary")
	unit.attack_visual_age=0
	art._process(0)
	check(art.current_action==&"ablaze_attack" and art.frame%8==0,"Burning contact art starts with attack event")
	unit.health-=1
	art._process(0)
	check(art.current_action==&"ablaze_hit","Hit reaction does not extinguish active flame")
	await process_frame
	unit.position=Vector2(400,400)
	unit.nav_level=4
	unit.selected=true
	selection.selected_units=[unit]
	terrain.blocked=true
	var page := art.texture
	unit.take_damage(99999,null,&"magic")
	unit._die()
	var riders: Array[Node] = stage.get_children().filter(func(n: Node) -> bool: return n is RTSUnit and n.unit_archetype==&"steel_knight" and n!=enemy)
	check(riders.size()==1,"Slain mount spawns exactly one Tier 2 rider, including repeated death calls")
	if riders.size()==1:
		var rider: RTSUnit = riders[0]
		rider.set_process(false)
		rider.set_physics_process(false)
		check(rider.owner_player_id==2 and rider.health==170 and rider.max_health==340,"Enemy rider inherits owner and half T2 health")
		check(selection.selected_units==[rider],"Selection transfers to surviving rider")
		await process_frame
		check(rider.position==Vector2(400,400) and rider.nav_level==4,"Deferred spawn snap preserves elevated dismount position")
		var corpses := stage.get_children().filter(func(n: Node) -> bool: return n is Sprite2D)
		check(corpses.size()==1 and corpses[0].texture==page and corpses[0].frame>=72 and corpses[0].frame<80,"Independent directional mount-only corpse")
		rider.take_damage(99999,null,&"magic")
		await process_frame
		check(not is_instance_valid(rider),"Ordinary rider death cannot dismount again")
	terrain.blocked=false
	var friendly := spawn(stage,1)
	friendly.position=Vector2(700,700)
	friendly.take_damage(99999,null,&"magic")
	var friendly_riders := stage.get_children().filter(func(n: Node) -> bool: return n is RTSUnit and n.unit_archetype==&"steel_knight" and n!=enemy and n.is_alive())
	check(friendly_riders.size()==1 and friendly_riders[0].max_health==380 and friendly_riders[0].health==190,"Half HP is calculated after applicable rider upgrades")
	stage.queue_free()
	await process_frame
	print("[Mounted] failures=",failures)
	quit(0 if failures==0 else 1)
