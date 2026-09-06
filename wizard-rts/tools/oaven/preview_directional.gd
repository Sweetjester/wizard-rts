extends SceneTree
const Art := preload("res://scripts/units/oaven_painted_art.gd")
var sprites: Array[Sprite2D] = []
var label: Label

func _initialize() -> void: call_deferred("run")

func caption(stage: Node, value: String, position: Vector2, size: int) -> Label:
	var text := Label.new()
	text.text=value
	text.position=position
	text.add_theme_font_size_override("font_size",size)
	stage.add_child(text)
	return text

func run() -> void:
	root.size=Vector2i(1600,850)
	root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("172126"))
	var stage := Node2D.new()
	root.add_child(stage)
	caption(stage,"OAVEN  /  EIGHT DIRECTIONS",Vector2(35,24),28)
	label=caption(stage,"",Vector2(35,64),18)
	for i in 8: caption(stage,Art.DIRECTIONS[i].to_upper(),Vector2(78+i*192,110),20)
	for row in 3:
		caption(stage,["OAVEN","JUMPER","COLLAPSED"][row],Vector2(35,145+row*225),16)
		for i in 8:
			var sprite := Sprite2D.new()
			sprite.texture=load(Art.ROOT+("oaven_" if row==0 else "jumper_")+Art.DIRECTIONS[i]+".png")
			sprite.hframes=8
			sprite.vframes=15
			sprite.position=Vector2(110+i*192,265+row*225)
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			stage.add_child(sprite)
			sprites.append(sprite)
	for action in [0,1,2,3,10]:
		label.text=Art.ACTIONS[action]
		for frame in 8:
			for i in sprites.size(): sprites[i].frame=47 if i>=16 else action*8+frame
			await process_frame
			await RenderingServer.frame_post_draw
			if frame==3: root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/oaven_8direction_"+str(action)+".png")
	print("[Oaven8Preview] PASS: five rendered contact sheets")
	stage.queue_free()
	await process_frame
	quit()
