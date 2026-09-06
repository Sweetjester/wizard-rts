extends SceneTree
const Puppet := preload("res://tools/spawner/drone_puppet.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet := Puppet.new()
	puppet.position = Vector2(256,260)
	puppet.scale = Vector2.ONE*2.2
	viewport.add_child(puppet)
	var sheet := Image.create(256*12,256*5,false,Image.FORMAT_RGBA8)
	for row in 5:
		puppet.action = Puppet.ACTIONS[row]
		for frame in 12:
			puppet.phase = float(frame)/(11.0 if row >= 2 else 12.0)
			puppet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			rendered.resize(256,256,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(rendered,Rect2i(0,0,256,256),Vector2i(frame*256,row*256))
	var error := sheet.save_png("res://assets_game/units/kon/spawner_drone/painted_v1/drone.png")
	assert(error == OK)
	print("[DroneBake] 60 frames saved")
	quit()
