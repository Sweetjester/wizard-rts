extends SceneTree
const Puppet := preload("res://tools/serpent/directional_puppet.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet := Puppet.new()
	viewport.add_child(puppet)
	var count := 0
	for direction in 8:
		var args := OS.get_cmdline_user_args()
		if not args.is_empty() and not Puppet.DIRECTIONS[direction] in args: continue
		puppet.load_direction(direction)
		for level in range(1,7):
			puppet.level = level
			var sheet := Image.create(Puppet.CELL*8,Puppet.CELL*9,false,Image.FORMAT_RGBA8)
			for row in 9:
				puppet.row = row
				for frame in 8:
					puppet.phase = float(frame)/(7.0 if row in [2,3,5,6,7,8] else 8.0)
					puppet.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var img := viewport.get_texture().get_image()
					img.resize(Puppet.CELL,Puppet.CELL,Image.INTERPOLATE_LANCZOS)
					sheet.blit_rect(img,Rect2i(0,0,Puppet.CELL,Puppet.CELL),Vector2i(frame*Puppet.CELL,row*Puppet.CELL))
			var name: String = "serpent_%d_%s" % [level,Puppet.DIRECTIONS[direction]]
			assert(sheet.save_png(Puppet.ROOT+name+".png")==OK)
			count += 1
			print("[Serpent8Bake] ",name)
	assert(count>0)
	print("[Serpent8Bake] PASS: ",count," pages, ",count*72," frames")
	viewport.queue_free()
	await process_frame
	quit()
