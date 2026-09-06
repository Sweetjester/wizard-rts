extends SceneTree
const Art := preload("res://scripts/units/serpent_painted_art.gd")
var sprites: Array[Sprite2D] = []

func _initialize() -> void: call_deferred("run")

func caption(stage: Node, value: String, at: Vector2, size: int) -> void:
	var label := Label.new()
	label.text=value
	label.position=at
	label.add_theme_font_size_override("font_size",size)
	stage.add_child(label)

func run() -> void:
	root.size=Vector2i(1920,1000)
	root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("172126"))
	var stage := Node2D.new()
	root.add_child(stage)
	caption(stage,"STONE-FACED SERPENT / EIGHT DIRECTIONS",Vector2(35,24),28)
	for i in 8: caption(stage,Art.DIRECTIONS[i].to_upper(),Vector2(100+i*236,100),20)
	for row in 3:
		caption(stage,["STAGE 1","STAGE 6","COLLAPSED / STAGE 6"][row],Vector2(35,145+row*275),16)
		for i in 8:
			var sprite := Sprite2D.new()
			sprite.texture=load(Art.ROOT+"serpent_%d_%s.png" % [1 if row==0 else 6,Art.DIRECTIONS[i]])
			sprite.hframes=8
			sprite.vframes=9
			sprite.position=Vector2(120+i*236,310+row*275)
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			stage.add_child(sprite)
			sprites.append(sprite)
	for action in [0,1,2,3,6]:
		for frame in 8:
			for i in sprites.size(): sprites[i].frame=63 if i>=16 else action*8+frame
			await process_frame
			await RenderingServer.frame_post_draw
			if frame==3: root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/serpent_8direction_"+str(action)+".png")
	for child in stage.get_children(): child.queue_free()
	await process_frame
	sprites.clear()
	root.size=Vector2i(1280,760)
	root.content_scale_size=root.size
	caption(stage,"STONE-FACED SERPENT / FULLY GROWN",Vector2(30,20),26)
	for i in 8:
		var at := Vector2(160+(i%4)*320,260+(i/4)*310)
		caption(stage,Art.DIRECTIONS[i].to_upper(),at-Vector2(130,155),20)
		var sprite := Sprite2D.new()
		sprite.texture=load(Art.ROOT+"serpent_6_"+Art.DIRECTIONS[i]+".png")
		sprite.hframes=8
		sprite.vframes=9
		sprite.frame=11
		sprite.position=at
		sprite.scale=Vector2.ONE*1.5
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		stage.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/serpent_8direction_close.png")
	print("[Serpent8Preview] PASS: five contact sheets and grown-stage close-up")
	stage.queue_free()
	await process_frame
	quit()
