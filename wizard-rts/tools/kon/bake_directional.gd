extends SceneTree
const Puppet := preload("res://tools/kon/directional_puppet.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var vp := SubViewport.new()
	vp.size=Vector2i(768,768)
	vp.transparent_bg=true
	vp.disable_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var puppet := Puppet.new()
	puppet.scale=Vector2.ONE*2
	vp.add_child(puppet)
	for direction in 8:
		puppet.load_direction(direction)
		var atlas := Image.create(4608,3072,false,Image.FORMAT_RGBA8)
		for row in 8:
			puppet.row=row
			for col in 12:
				puppet.phase=float(col)/(12.0 if row in [0,1,4] else 11.0)
				puppet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				img.resize(384,384,Image.INTERPOLATE_LANCZOS)
				atlas.blit_rect(img,Rect2i(0,0,384,384),Vector2i(col*384,row*384))
		assert(atlas.save_png(Puppet.ROOT+"kon_"+Puppet.DIRECTIONS[direction]+".png")==OK)
		print("[KonDirectionalBake] ",Puppet.DIRECTIONS[direction]," 96 frames")
	vp.queue_free()
	await process_frame
	quit()
