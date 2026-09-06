extends SceneTree
const Art := preload("res://scripts/units/mounted_knight_art.gd")
var sprites: Array[Sprite2D] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1600,850)
	root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("272a2a"))
	var stage := Node2D.new()
	root.add_child(stage)
	var title := Label.new()
	title.position=Vector2(30,20)
	title.add_theme_font_size_override("font_size",26)
	stage.add_child(title)
	for i in 8:
		var label := Label.new()
		label.text=Art.DIRECTIONS[i].to_upper()
		label.position=Vector2(30+(i%4)*400,90+(i/4)*370)
		stage.add_child(label)
		var sprite := Sprite2D.new()
		sprite.texture=load(Art.ROOT+"mounted_knight_"+Art.DIRECTIONS[i]+".png")
		sprite.hframes=8
		sprite.vframes=11
		sprite.position=Vector2(200+(i%4)*400,290+(i/4)*370)
		sprite.scale=Vector2.ONE*1.3
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		stage.add_child(sprite)
		sprites.append(sprite)
	for action in [0,1,3,5,6,7,9]:
		title.text="MOUNTED KNIGHT / "+str(Art.ACTIONS[action]).to_upper().replace("_"," ")
		for frame in 8:
			for sprite in sprites: sprite.frame=action*8+frame
			await process_frame
			await RenderingServer.frame_post_draw
			if frame in [0,3,7]: root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/mounted_"+str(action)+"_"+str(frame)+".png")
	print("[MountedPreview] PASS: seven actions at three phases, eight views")
	stage.queue_free()
	await process_frame
	quit()
