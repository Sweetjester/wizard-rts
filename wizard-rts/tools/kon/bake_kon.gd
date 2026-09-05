extends SceneTree

const OUT = "res://assets_game/units/kon/hero/painted_v2/"
const ACTIONS = ["idle", "move", "attack", "seal_away", "observer_aura", "biostorm", "hit", "death"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(384,384)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(Image.load_from_file(OUT+"source.png"))
	sprite.region_enabled = true
	var key := ShaderMaterial.new()
	key.shader = load("res://tools/oaven/chroma_key.gdshader")
	sprite.material = key
	vp.add_child(sprite)
	var atlas := Image.create(384*12,384*ACTIONS.size(),false,Image.FORMAT_RGBA8)
	for row in ACTIONS.size():
		for col in 12:
			var phase := float(col)/11.0
			var wave := sin(phase*TAU)
			var pose := 0
			var shift := Vector2.ZERO
			var squash := Vector2.ONE
			var angle := 0.0
			match ACTIONS[row]:
				"idle": squash.y = 1.0+wave*0.006
				"move":
					pose = 1 if col%6<3 else 0
					shift.y = -absf(wave)*5.0
					angle = wave*0.012
				"attack":
					pose = 0 if col<2 or col>9 else 2 if col<6 else 3
					shift.x = sin(phase*PI)*9.0
				"seal_away", "biostorm":
					pose = 0 if col<2 else 4
					shift.y = -sin(phase*PI)*7.0
					squash = Vector2(1.0+wave*0.018,1.0-wave*0.018)
				"observer_aura":
					pose = 4
					shift.y = wave*2.0
				"hit":
					angle = -sin(phase*PI)*0.09
					shift.x = -sin(phase*PI)*9.0
				"death":
					pose = 0 if col<2 else 5
					shift.y = -sin(phase*PI)*4.0
					squash.y = 1.0+(1.0-phase)*0.10
			# Bottom-aligned source tiles maintain one ground anchor through every action.
			# Casting/death silhouettes spill slightly across the nominal row boundary.
			var source_rect := Rect2(0,0,512,488)
			source_rect.position = Vector2((pose%3)*512,0 if pose<3 else 492)
			if pose==3: source_rect = Rect2(0,492,526,488)
			if pose==2: source_rect = Rect2(998,0,538,488)
			if pose==1: source_rect = Rect2(512,0,486,488)
			if pose==4: source_rect = Rect2(540,492,392,488)
			if pose==5: source_rect = Rect2(932,492,604,488)
			sprite.region_rect = source_rect
			sprite.position = Vector2(192,340)+shift
			sprite.offset = Vector2(0,-source_rect.size.y*0.5+20)
			sprite.scale = Vector2.ONE*0.55*squash
			sprite.rotation = angle
			await process_frame
			await RenderingServer.frame_post_draw
			atlas.blit_rect(vp.get_texture().get_image(),Rect2i(0,0,384,384),Vector2i(col*384,row*384))
		print("[KonBake] ",ACTIONS[row])
	assert(atlas.save_png(OUT+"kon.png")==OK)
	vp.queue_free()
	await process_frame
	quit()
