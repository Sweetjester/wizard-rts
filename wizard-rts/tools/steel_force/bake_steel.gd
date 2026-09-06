extends SceneTree

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384,384)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for id in ["poorper","steel_knight","proper_blimp"]:
		var puppet := preload("res://tools/steel_force/steel_puppet.gd").new()
		puppet.archetype = id
		viewport.add_child(puppet)
		var sheet := Image.create(4608,2304,false,Image.FORMAT_RGBA8)
		for row in 6:
			puppet.row = row
			for frame in 12:
				puppet.phase = float(frame)/(12.0 if row<2 else 11.0)
				puppet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				sheet.blit_rect(viewport.get_texture().get_image(),Rect2i(0,0,384,384),Vector2i(frame*384,row*384))
		var path: String = "res://assets_game/units/steel_force/painted_v1/"+id
		if sheet.save_png(path+".png") != OK: quit(1); return
		sheet.get_region(Rect2i(0,0,384,384)).save_png(path+"_portrait.png")
		puppet.queue_free()
		await process_frame
		print("[SteelBake] ",id," PASS")
	quit()
