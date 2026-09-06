extends SceneTree

const Art := preload("res://scripts/units/kon_painted_art.gd")
const Facing := preload("res://scripts/units/eight_direction_facing.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)

func run() -> void:
	create_timer(100).timeout.connect(func(): quit(9))
	var fingerprints := {}
	var heights: Array[int] = []
	for direction in Art.DIRECTIONS:
		var page := Image.load_from_file(Art.ROOT+"kon_"+direction+".png")
		check(page!=null and page.get_size()==Vector2i(4608,3072),"Wrong atlas dimensions: "+direction)
		if page==null: continue
		fingerprints[hash(page.get_data())] = true
		heights.append(page.get_region(Rect2i(0,0,384,384)).get_used_rect().size.y)
		for row in 8:
			var motion := {}
			for f in 12:
				var tile := page.get_region(Rect2i(f*384,row*384,384,384))
				var bounds := tile.get_used_rect()
				check(bounds.has_area() and bounds.position.x>1 and bounds.position.y>1 and bounds.end.x<383 and bounds.end.y<383,"Clipped/empty %s row%d frame%d" % [direction,row,f])
				motion[hash(tile.get_data())] = true
				check(tile.get_pixel(0,0).a<.01,"Opaque background")
				for y in range(0,384,16):
					for x in range(0,384,16):
						var c := tile.get_pixel(x,y)
						check(not (c.a>.15 and minf(c.r,c.b)-c.g>.30),"Magenta residue")
			check(motion.size()>1,"Frozen animation: %s row%d" % [direction,row])
		check(page.get_region(Rect2i(2*384,2*384,384,384)).get_data()!=page.get_region(Rect2i(6*384,2*384,384,384)).get_data(),"Missing second branch pose")
	check(fingerprints.size()==8,"Directional pages duplicated")
	check(float(heights.max())/float(heights.min())<1.17,"Visible scale jumps between directions")
	var stage := Node2D.new()
	stage.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(stage)
	var kon: Node2D = load("res://scenes/wizard.tscn").instantiate()
	stage.add_child(kon)
	var art: Sprite2D = kon.get_node("ArtSprite")
	for i in 8:
		kon.velocity=Vector2.from_angle(i*PI/4)*100
		art.sync_view_facing()
		check(art.facing_index==i and not art.flip_h,"Wrong movement facing "+str(i))
		check(art.texture.resource_path.ends_with("kon_"+Art.DIRECTIONS[i]+".png"),"Wrong live page")
		var remembered: Vector2 = art.world_facing
		kon.velocity=Vector2.ZERO
		art.sync_view_facing()
		check(art.world_facing==remembered,"Idle loses heading")
		for action in [&"seal_away",&"biostorm",&"observer_aura"]:
			kon.ability_animation_action=action
			art._process(.1)
			check(art.current_action==action and int(art.frame/12)==Art.ACTIONS.find(action),"Wrong spell row")
			check(art.world_facing==remembered,"Stationary spell changed world heading")
		kon.ability_animation_action=&""
	var target := Node2D.new()
	stage.add_child(target)
	target.position=Vector2(-100,0)
	kon.attack_target=target
	art.sync_view_facing()
	check(art.facing_index==4,"Attack target ignored")
	target.free()
	art.sync_view_facing()
	check(art.facing_index==4,"Freed target lost heading")
	kon.attack_target=null
	art.face_world_position(kon.position+Vector2(100,-100))
	kon.ability_animation_action=&"seal_away"
	art.sync_view_facing()
	check(art.facing_index==7,"Targeted cast heading ignored")
	var camera := Camera2D.new()
	camera.ignore_rotation=false
	stage.add_child(camera)
	camera.make_current()
	kon.ability_animation_action=&"observer_aura"
	art.world_facing=Vector2.RIGHT
	for i in 8:
		camera.rotation=i*PI/4
		art.sync_view_facing()
		check(art.facing_index==posmod(-i,8),"2D camera relative heading")
		check(art.world_facing==Vector2.RIGHT,"Camera rotated the observing hero")
	check(Facing.sector(Vector2.from_angle(PI/8+.02),0)==0,"Sector boundary has no hysteresis")
	check(is_zero_approx(art.offset.y+330-192),"Ground anchor changed")
	check(art.scale==Vector2.ONE*.43 and is_equal_approx(art.get_meta("billboard_pixel_size"),.009),"Hero world scale changed")
	stage.queue_free()
	await process_frame
	print("[KonDirectional] 768 frames, eight directions, alpha/bounds/motion, casts, idle, target safety, 2D orbit; failures=",failures)
	quit(0 if failures==0 else 1)
