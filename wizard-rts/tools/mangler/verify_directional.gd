extends SceneTree

const Facing := preload("res://scripts/units/eight_direction_facing.gd")
const Art := preload("res://scripts/units/mangler_painted_art.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("[Mangler8] PASS: ",message)
	else: failures += 1; push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Mangler8 timeout"); quit(1))
	for i in 8:
		var heading := Vector2.RIGHT.rotated(i*PI/4)
		check(Facing.sector(heading)==i,"Sector "+Art.DIRECTIONS[i])
		var rotated := Basis(Vector3.UP,PI/2)*Basis(Vector3.RIGHT,-PI/4)
		check(Facing.sector(Facing.camera_relative(heading,rotated))==posmod(i+2,8),"Camera yaw "+Art.DIRECTIONS[i])
	check(Facing.sector(Vector2.ZERO,6)==6,"Stationary facing retained")
	check(Facing.sector(Vector2.RIGHT.rotated(deg_to_rad(25)),0)==0,"Boundary jitter stays in sector")
	check(Facing.sector(Vector2.RIGHT.rotated(deg_to_rad(28)),0)==1,"Intentional turn crosses hysteresis")
	check(Facing.sector(Vector2.RIGHT.rotated(deg_to_rad(-2)),0)==0,"Angle wrap remains stable")
	var hashes := {}
	for form in ["mangler","winged_mangler"]:
		for direction in Art.DIRECTIONS:
			var id: String = form+"_"+direction
			var image := Image.load_from_file(Art.ROOT+id+".png")
			check(image!=null and image.get_size()==Vector2i(2048,2304),id+" page dimensions")
			if image==null: continue
			var valid := true
			var motion := true
			for row in 9:
				var row_hashes := {}
				for frame in 8:
					var cell := image.get_region(Rect2i(frame*256,row*256,256,256))
					var bounds := cell.get_used_rect()
					if bounds.size.x<35 or bounds.size.y<25 or bounds.position.x<2 or bounds.end.x>254 or bounds.position.y<2 or bounds.end.y>254:
						valid = false
						print("Bad bounds ",id," row=",row," frame=",frame," ",bounds)
					row_hashes[hash(cell.get_data())] = true
				if row_hashes.size()<2: motion=false
			check(valid,id+" all 72 frames nonblank and unclipped")
			check(motion,id+" every action changes visibly")
			var idle := image.get_region(Rect2i(0,0,256,256))
			var key := hash(idle.get_data())
			check(not hashes.has(key),id+" has distinct art")
			hashes[key] = true
	var stage := Node2D.new()
	root.add_child(stage)
	var unit: Node2D = load("res://scenes/units/mangler.tscn").instantiate()
	stage.add_child(unit)
	unit.set_physics_process(false)
	var art: Sprite2D = unit.get_node("ArtSprite")
	art.set_process(false)
	unit._last_melee_attack_msec = -10000
	for i in 8:
		unit.velocity = Vector2.RIGHT.rotated(i*PI/4)*100
		art.frame = 13
		art.sync_view_facing()
		check(art.facing_index==i and art.texture.resource_path.ends_with("mangler_"+Art.DIRECTIONS[i]+".png") and not art.flip_h,"Runtime selects "+Art.DIRECTIONS[i])
		check(art.frame==13,"Turning preserves animation frame")
	unit.velocity = Vector2.ZERO
	art.sync_view_facing()
	check(art.facing_index==7,"Stopping keeps last world heading")
	unit.moving = true
	art._process(.2)
	check(art.current_action==1,"Movement uses run row")
	unit._last_melee_attack_msec = Time.get_ticks_msec()
	art._process(0)
	check(art.current_action==2,"Attack uses attack row immediately")
	unit._last_melee_attack_msec = -10000
	unit.health -= 1
	art._process(0)
	check(art.current_action==3,"Damage uses hit row")
	art._process(.5)
	unit.debug_force_evolve()
	art._process(0)
	check(art.texture.resource_path.contains("winged_mangler") and art.current_action==7,"Evolution switches form and action")
	unit.leap_age = .1
	unit.leap_start = Vector2.ZERO
	unit.leap_target = Vector2.LEFT*200
	unit.velocity = Vector2.DOWN*100
	art._process(0)
	check(art.current_action==4 and art.facing_index==4,"Leap windup overrides movement heading")
	unit.leap_age = unit.LEAP_WINDUP+.2
	unit.leap_height = 80
	art._process(0)
	check(art.current_action==5 and is_equal_approx(art.get_meta("foot_anchor_y"),220+80/.72),"Airborne row keeps shared 2D/3D lift")
	unit.leap_landed = true
	unit.leap_age = unit.LEAP_WINDUP+unit.LEAP_FLIGHT+.1
	art._process(0)
	check(art.current_action==6,"Landing uses recovery row")
	unit._spawn_death_fx()
	var corpse: Sprite2D = stage.get_child(stage.get_child_count()-1)
	check(corpse.texture==art.texture and corpse.frame==64 and corpse.offset.y==-92,"Death captures current directional form at ground anchor")
	await create_timer(.6).timeout
	check(corpse.frame>64 and corpse.frame<72,"Death advances within directional death row")
	stage.queue_free()
	await process_frame
	print("[Mangler8] failures=",failures)
	quit(0 if failures==0 else 1)
