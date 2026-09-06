extends SceneTree
const Art := preload("res://scripts/units/serpent_painted_art.gd")
const Puppet := preload("res://tools/serpent/directional_puppet.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("[Serpent8] PASS: ",message)
	else: failures+=1; push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Serpent8 timeout"); quit(1))
	var hashes := {}
	for level in range(1,7):
		for direction in Art.DIRECTIONS:
			var id := "serpent_%d_%s" % [level,direction]
			var img := Image.load_from_file(Art.ROOT+id+".png")
			check(img!=null and img.get_size()==Vector2i(2048,2304),id+" dimensions")
			if img==null: continue
			var valid := true
			var motion := true
			for row in 9:
				var frames := {}
				for f in 8:
					var cell := img.get_region(Rect2i(f*256,row*256,256,256))
					var box := cell.get_used_rect()
					if box.size.x<20 or box.size.y<20 or box.position.x<2 or box.position.y<2 or box.end.x>254 or box.end.y>254:
						valid=false
						print(id," row=",row," frame=",f," bounds=",box)
					frames[hash(cell.get_data())]=true
				if row!=4 and frames.size()<2: motion=false
			check(valid,id+" 72 visible unclipped frames")
			check(motion,id+" eight moving actions; stone hold intentionally still")
			var key := hash(img.get_region(Rect2i(0,0,256,256)).get_data())
			check(not hashes.has(key),id+" unique growth/direction")
			hashes[key]=true
			var page: Texture2D = load(Art.ROOT+id+".png")
			check(page.get_image().is_compressed(),id+" GPU compressed")
	var stage := Node2D.new()
	root.add_child(stage)
	var unit: Node2D = load("res://scenes/units/stone_face_serpent.tscn").instantiate()
	stage.add_child(unit)
	unit.set_physics_process(false)
	unit.set_process(false)
	var art: Sprite2D = unit.get_node("ArtSprite")
	art.set_process(false)
	art._process(0)
	check(art.current_action==&"idle","Initial health does not trigger hit")
	for level in range(1,7):
		if level>1: unit._gain_evolution_xp(45)
		for i in 8:
			unit.velocity=Vector2.from_angle(i*PI/4)*100
			art._process(0)
			art.frame=11
			art.sync_view_facing()
			check(art.facing_index==i and not art.flip_h and art.texture.resource_path.ends_with("serpent_%d_%s.png" % [level,Art.DIRECTIONS[i]]),"Runtime stage %d direction %s" % [level,Art.DIRECTIONS[i]])
			var pivot := Puppet.head_anchor(level,i)
			check((pivot-Vector2(128,128)+art.offset).length()<.01 and absf(float(art.get_meta("foot_anchor_y"))-pivot.y)<.01,"Head anchor agrees with baked stage/direction")
			check(art.frame==11,"Turning preserves animation phase")
	unit.velocity=Vector2.ZERO
	art.sync_view_facing()
	check(art.facing_index==7,"Stopped serpent remembers heading")
	var camera := Camera2D.new()
	camera.ignore_rotation=false
	stage.add_child(camera)
	camera.make_current()
	unit.velocity=Vector2.RIGHT*100
	camera.rotation=PI/2
	art.sync_view_facing()
	check(art.facing_index==6,"2D camera rotation resolves rear direction")
	camera.queue_free()
	await process_frame
	var target := Node2D.new()
	target.position=Vector2(0,100)
	stage.add_child(target)
	unit.attack_target=target
	art.sync_view_facing()
	check(art.facing_index==2,"Attack target overrides movement heading")
	unit.attack_target=null
	unit.ability_animation_action=&""
	unit.moving=true
	art._process(0)
	check(art.current_action==&"move","Move selects slither")
	art.play_attack()
	art._process(.25)
	art._process(0)
	check(art.current_action==&"attack" and art.frame/8==2,"Poison bite animation")
	art._attack_left=0
	unit._stone_cast_remaining=1
	art._process(0)
	check(art.current_action==&"harden","Harden cast animation")
	unit._stone_cast_remaining=0
	unit._stone_form_active=true
	art._process(0)
	check(not art.visible and art.current_action==&"wall","Wall owner hides mobile art")
	unit._stone_form_active=false
	for action in [&"revert_stone",&"evolve_growth"]:
		unit.ability_animation_action=action
		unit._ability_animation_until_msec=Time.get_ticks_msec()+200
		art._process(0)
		check(art.current_action==(&"revert" if action==&"revert_stone" else &"evolve") and art.visible,"Transition "+str(action))
	unit.ability_animation_action=&""
	unit.health-=1
	art._process(0)
	check(art.current_action==&"hit","Damage selects hit reaction")
	var page := art.texture
	var offset := art.offset
	unit._die()
	var corpse: Sprite2D = null
	for child in stage.get_children():
		if child is Sprite2D: corpse=child
	await process_frame
	check(not is_instance_valid(unit) and is_instance_valid(corpse),"Dead unit leaves independent corpse")
	if is_instance_valid(corpse):
		check(corpse.texture==page and corpse.offset==offset and corpse.hframes==8 and corpse.frame>=56 and corpse.frame<64,"Corpse preserves growth, direction and head pivot")
		await create_timer(1.35).timeout
		check(corpse.frame==63,"Death reaches final collapse frame")
		await create_timer(3).timeout
		check(not is_instance_valid(corpse),"Corpse frees after hold/fade")
	stage.queue_free()
	await process_frame
	print("[Serpent8] failures=",failures)
	quit(0 if failures==0 else 1)
