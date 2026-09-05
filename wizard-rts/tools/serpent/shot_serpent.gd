extends SceneTree

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var source := Image.load_from_file("res://assets_game/units/kon/serpent/painted_v2/source.png")
	var portrait := source.get_region(Rect2i(0,0,source.get_width()/4,source.get_height()/4))
	portrait.save_png("res://assets_game/units/kon/serpent/painted_v2/portrait.png")
	var cell := Vector2i(source.get_width()/4,source.get_height()/4)
	for i in range(8,12):
		var tile := source.get_region(Rect2i(Vector2i(i%4,i/4)*cell,cell))
		tile.get_region(tile.get_used_rect()).save_png("res://assets_game/units/kon/serpent/painted_v2/wall_%d.png" % i)
	root.size = Vector2i(1500,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(1500,900)
	var stage := Node2D.new()
	root.add_child(stage)
	var bg := ColorRect.new()
	bg.size = Vector2(1500,900)
	bg.color = Color("15252b")
	stage.add_child(bg)
	for i in 6:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets_game/units/kon/serpent/painted_v2/serpent_%d.png" % (i+1))
		sprite.hframes = 12
		sprite.vframes = 9
		sprite.frame = 0
		sprite.position = Vector2(370+(i%2)*740,115+(i/2)*260)
		sprite.scale = Vector2.ONE*1.3
		stage.add_child(sprite)
		var label := Label.new()
		label.text = "STONE-FACED SERPENT  /  " + ("BASE" if i==0 else "EVOLUTION %d" % i)
		label.position = sprite.position+Vector2(-260,125)
		label.add_theme_font_size_override("font_size",18)
		stage.add_child(label)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/serpent_evolutions.png")
	stage.queue_free()
	await process_frame
	quit()
