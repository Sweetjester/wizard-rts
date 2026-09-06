extends SceneTree
const Art := preload("res://scripts/units/oaven_painted_art.gd")
const Facing := preload("res://scripts/units/eight_direction_facing.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("[Oaven8] PASS: ",message)
	else: failures+=1; push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Oaven8 timeout"); quit(1))
	var hashes := {}
	for form in ["oaven","jumper"]:
		for direction in Art.DIRECTIONS:
			var id: String = form+"_"+direction
			var img := Image.load_from_file(Art.ROOT+id+".png")
			check(img!=null and img.get_size()==Vector2i(1536,2880),id+" dimensions")
			if img==null: continue
			var valid := true
			var motion := true
			for row in 15:
				var frames := {}
				for f in 8:
					var cell := img.get_region(Rect2i(f*192,row*192,192,192))
					var box := cell.get_used_rect()
					if box.size.x<20 or box.size.y<20 or box.position.x<2 or box.position.y<2 or box.end.x>190 or box.end.y>190:
						valid=false
						print(id," row=",row," frame=",f," bounds=",box)
					frames[hash(cell.get_data())]=true
				if frames.size()<2: motion=false
			check(valid,id+" 120 visible unclipped frames")
			check(motion,id+" all 15 actions visibly animate")
			var key := hash(img.get_region(Rect2i(0,0,192,192)).get_data())
			check(not hashes.has(key),id+" distinct direction/form painting")
			hashes[key]=true
	var stage := Node2D.new()
	root.add_child(stage)
	var unit: Node2D = load("res://scenes/units/oaven_spear.tscn").instantiate()
	stage.add_child(unit)
	unit.set_physics_process(false)
	var art: Sprite2D = unit.get_node("ArtSprite")
	art.set_process(false)
	art._process(.016)
	check(art.current_action==&"idle","Initial health does not trigger hit")
	for i in 8:
		unit.velocity=Vector2.RIGHT.rotated(i*PI/4)*100
		art.frame=11
		art.sync_view_facing()
		check(art.facing_index==i and not art.flip_h and art.texture.resource_path.ends_with("oaven_"+Art.DIRECTIONS[i]+".png"),"Runtime direction "+Art.DIRECTIONS[i])
		check(art.frame==11,"Turning preserves frame")
	unit.velocity=Vector2.ZERO
	art.sync_view_facing()
	check(art.facing_index==7,"Stopped units remember their heading")
	check(Facing.sector(Vector2.RIGHT.rotated(deg_to_rad(25)),0)==0 and Facing.sector(Vector2.RIGHT.rotated(deg_to_rad(28)),0)==1,"Boundary hysteresis")
	var target := Node2D.new()
	target.position=Vector2(0,100)
	stage.add_child(target)
	unit.attack_target=target
	unit.velocity=Vector2.LEFT*100
	art.sync_view_facing()
	check(art.facing_index==2,"Attack target overrides travel direction")
	unit.attack_target=null
	for action in Art.ACTIONS:
		unit.ability_animation_action=action
		art._process(.02)
		check(art.current_action==action and art.frame/8==Art.ACTIONS.find(action),"Action row "+str(action))
	unit.set_weapon_mode(&"blowpipe")
	art._process(.01)
	check(art.current_action==&"swap_weapon" and art.frame==56,"Swap to blowpipe starts on spear pose")
	unit._weapon_swap_remaining=0
	art._process(.01)
	check(art.frame==63,"Swap to blowpipe ends on blowpipe pose")
	unit.set_weapon_mode(&"spear")
	art._process(.01)
	check(art.frame==63,"Swap back starts on blowpipe pose")
	unit._weapon_swap_remaining=0
	art._process(.01)
	check(art.frame==56,"Swap back ends on spear pose")
	unit.ability_animation_action=&""
	unit.weapon_mode=&"blowpipe"
	unit.moving=true
	art._process(.1)
	check(art.current_action==&"move_blowpipe","Moving with blowpipe preserves weapon mode")
	unit.unit_state=&"attacking"
	unit._attack_elapsed=0
	art._process(0)
	check(art.current_action==&"attack_blowpipe" and art.frame%8==3,"Blowpipe contact matches authoritative attack clock")
	unit.weapon_mode=&"spear"
	art._process(0)
	check(art.current_action==&"attack_spear" and art.frame%8==3,"Spear contact matches authoritative attack clock")
	unit.debug_force_evolve()
	art._process(0)
	check(art.texture.resource_path.contains("jumper_"),"Evolution switches directional form")
	unit.ability_animation_action=&""
	unit._flight_state=&"flying"
	art._process(0)
	check(art.current_action==&"flying","Flight state selects flight row")
	unit.ability_animation_action=&"landing_stun"
	art._process(0)
	check(art.current_action==&"landing","Landing stun maps to landing art")
	unit.health-=1
	art._process(.01)
	check(art.current_action==&"hit","Damage interrupts art with hit reaction")
	var last_page := art.texture
	unit._die()
	var corpse: Sprite2D = null
	for child in stage.get_children():
		if child is Sprite2D: corpse=child
	await process_frame
	check(not is_instance_valid(unit) and is_instance_valid(corpse),"Dead unit leaves simulation; independent corpse remains")
	if is_instance_valid(corpse):
		check(corpse.texture==last_page and corpse.frame>=40 and corpse.frame<48,"Death uses current directional page and row")
		await create_timer(1.1).timeout
		check(corpse.frame==47 and not corpse.is_in_group("units"),"Directional corpse reaches final frame without unit registration")
		await create_timer(2.0).timeout
		check(not is_instance_valid(corpse),"Corpse fades and frees")
	stage.queue_free()
	await process_frame
	print("[Oaven8] failures=",failures)
	quit(0 if failures==0 else 1)
