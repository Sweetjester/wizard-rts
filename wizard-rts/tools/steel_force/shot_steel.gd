extends SceneTree

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1440,1000)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("20252a")
	background.size = Vector2(1440,1000)
	root.add_child(background)
	var ids := ["poorper","steel_knight","proper_blimp"]
	for y in 3:
		var label := Label.new()
		label.text = ["POORPER","STEEL KNIGHT","PROPER BLIMP"][y]
		label.position = Vector2(24,12+y*330)
		root.add_child(label)
		for x in 6:
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets_game/units/steel_force/painted_v1/"+ids[y]+".png")
			sprite.hframes = 12
			sprite.vframes = 6
			sprite.frame = x*12+(11 if x==4 else 5)
			sprite.scale = Vector2.ONE*0.62
			sprite.position = Vector2(120+x*240,170+y*330)
			root.add_child(sprite)
			var title := Label.new()
			title.text = ["Idle","Move","Attack","Hit","Death","Landed / Ready"][x]
			title.position = Vector2(60+x*240,295+y*330)
			root.add_child(title)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR").path_join("steel_force_review.png"))
	print("[SteelShot] PASS")
	quit()
