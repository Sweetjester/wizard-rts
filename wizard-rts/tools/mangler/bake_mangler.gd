extends SceneTree

const PUPPET = preload("res://tools/mangler/mangler_puppet.gd")
const OUT := "res://assets_game/units/kon/mangler/painted_v1/"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384,384)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet := PUPPET.new()
	viewport.add_child(puppet)
	for form in 2:
		puppet.evolved = form == 1
		var sheet := Image.create(384*12,384*9,false,Image.FORMAT_RGBA8)
		for row in 9:
			puppet.row = row
			for frame in 12:
				puppet.phase = float(frame)/(12.0 if row < 2 else 11.0)
				puppet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var img := viewport.get_texture().get_image()
				sheet.blit_rect(img, Rect2i(0,0,384,384), Vector2i(frame*384,row*384))
		assert(sheet.save_png(OUT+("winged_mangler.png" if form else "mangler.png")) == OK)
		if form == 0: sheet.get_region(Rect2i(0,0,384,384)).save_png(OUT+"portrait.png")
		print("[ManglerBake] form ",form," complete")
	viewport.queue_free()
	await process_frame
	quit()
