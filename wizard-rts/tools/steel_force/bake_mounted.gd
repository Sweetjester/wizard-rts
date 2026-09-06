extends SceneTree
const Puppet := preload("res://tools/steel_force/mounted_puppet.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet := Puppet.new()
	puppet.scale=Vector2.ONE*2
	viewport.add_child(puppet)
	for direction in 8:
		var args := OS.get_cmdline_user_args()
		if not args.is_empty() and not Puppet.DIRECTIONS[direction] in args: continue
		puppet.load_direction(direction)
		var sheet := Image.create(2048,2816,false,Image.FORMAT_RGBA8)
		for row in 11:
			puppet.row=row
			for f in 8:
				puppet.phase=float(f)/(7.0 if row in [3,4,7,8,9,10] else 8.0)
				puppet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var img := viewport.get_texture().get_image()
				img.resize(256,256,Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(img,Rect2i(0,0,256,256),Vector2i(f*256,row*256))
				if direction==1 and row==0 and f==0:
					assert(img.save_png(Puppet.ROOT+"portrait.png")==OK)
		assert(sheet.save_png(Puppet.ROOT+"mounted_knight_"+Puppet.DIRECTIONS[direction]+".png")==OK)
		print("[MountedBake] PASS: ",Puppet.DIRECTIONS[direction]," 88 frames")
	viewport.queue_free()
	await process_frame
	quit()
