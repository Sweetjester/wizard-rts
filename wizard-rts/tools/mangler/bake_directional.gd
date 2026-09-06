extends SceneTree
const Puppet := preload("res://tools/mangler/directional_puppet.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet := Puppet.new()
	puppet.scale = Vector2.ONE*2
	viewport.add_child(puppet)
	for direction in 8:
		puppet.load_direction(direction)
		for form in 2:
			puppet.evolved = form == 1
			var sheet := Image.create(2048,2304,false,Image.FORMAT_RGBA8)
			for row in 9:
				puppet.row = row
				for frame in 8:
					puppet.phase = float(frame)/(8.0 if row < 2 or row == 5 else 7.0)
					puppet.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var img := viewport.get_texture().get_image()
					img.resize(256,256,Image.INTERPOLATE_LANCZOS)
					sheet.blit_rect(img,Rect2i(0,0,256,256),Vector2i(frame*256,row*256))
			var name: String = ("winged_mangler_" if form else "mangler_")+Puppet.DIRECTIONS[direction]
			assert(sheet.save_png(Puppet.ROOT+name+".png") == OK)
			print("[Mangler8Bake] ",name)
	print("[Mangler8Bake] PASS: 16 pages / 1152 frames")
	quit()
