extends SceneTree

const PUPPET = preload("res://tools/serpent/serpent_puppet.gd")
const OUT = "res://assets_game/units/kon/serpent/painted_v2/"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,256)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet := PUPPET.new()
	viewport.add_child(puppet)
	for level in range(1,7):
		puppet.level = level
		var sheet := Image.create(512*12,256*PUPPET.ACTIONS.size(),false,Image.FORMAT_RGBA8)
		for row in PUPPET.ACTIONS.size():
			puppet.action = PUPPET.ACTIONS[row]
			for frame in 12:
				puppet.phase = float(frame)/(12.0 if row<2 else 11.0)
				puppet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var img := viewport.get_texture().get_image()
				sheet.blit_rect(img,Rect2i(0,0,512,256),Vector2i(frame*512,row*256))
		assert(sheet.save_png(OUT+"serpent_%d.png" % level)==OK)
		print("[SerpentBake] level ",level," complete")
	viewport.queue_free()
	await process_frame
	quit()
