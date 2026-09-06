extends SceneTree

const Art := preload("res://scripts/units/mangler_painted_art.gd")
var sprites: Array[Sprite2D] = []
var status: Label

func _initialize() -> void: call_deferred("run")

func label_at(parent: Node, text: String, pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func run() -> void:
	root.size = Vector2i(1600,850)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("171e22"))
	var stage := Node2D.new()
	root.add_child(stage)
	label_at(stage,"MANGLER  /  EIGHT DIRECTIONS",Vector2(35,24),28)
	status = label_at(stage,"",Vector2(35,64),18)
	for i in 8:
		label_at(stage,Art.DIRECTIONS[i].to_upper(),Vector2(72+i*192,110),20)
	for row in 3:
		label_at(stage,["BASE","EVOLVED","COLLAPSED"][row],Vector2(35,145+row*225),16)
		for i in 8:
			var sprite := Sprite2D.new()
			sprite.texture = load(Art.ROOT+("mangler_" if row==0 else "winged_mangler_")+Art.DIRECTIONS[i]+".png")
			sprite.hframes = 8
			sprite.vframes = 9
			sprite.scale = Vector2.ONE*.78
			sprite.position = Vector2(110+i*192,265+row*225)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			stage.add_child(sprite)
			sprites.append(sprite)
	for action in [0,1,2,5]:
		status.text = ["Idle","Run","Attack","Airborne"][([0,1,2,5] as Array).find(action)]
		for f in 8:
			for i in sprites.size(): sprites[i].frame = (8*8+7) if i>=16 else action*8+f
			await process_frame
			await RenderingServer.frame_post_draw
			if f==3:
				root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/mangler_8direction_"+str(action)+".png")
	print("[Mangler8Preview] PASS: four rendered contact sheets")
	stage.queue_free()
	await process_frame
	quit()
