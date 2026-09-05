extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440,820)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = root.size
	var backdrop := ColorRect.new()
	backdrop.color = Color("11191e")
	backdrop.size = Vector2(root.size)
	root.add_child(backdrop)
	var titles := ["IDLE", "KNUCKLE RUN", "STRIKE", "LEAP / RECOIL", "DEATH"]
	var rows := [0,1,2,5,8]
	for form in 2:
		var label := Label.new()
		label.text = "MANGLER" if form==0 else "WINGED MANGLER"
		label.position = Vector2(30,18+form*400)
		label.add_theme_font_size_override("font_size",24)
		root.add_child(label)
		var tex: Texture2D = load("res://assets_game/units/kon/mangler/painted_v1/"+("mangler.png" if form==0 else "winged_mangler.png"))
		for col in 5:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.hframes = 12
			sprite.vframes = 9
			sprite.frame = (3 if col==3 and form==0 else rows[col])*12+6
			sprite.scale = Vector2.ONE*0.79
			sprite.position = Vector2(145+col*286,220+form*400)
			root.add_child(sprite)
			var caption := Label.new()
			caption.text = titles[col]
			caption.position = Vector2(36+col*286,375+form*400)
			caption.add_theme_color_override("font_color",Color("a9bac5"))
			root.add_child(caption)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR")+"/mangler_animation_review.png")
	print("[ManglerShot] complete")
	quit()
