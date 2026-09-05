extends SceneTree

const PUPPET=preload("res://tools/oaven/oaven_puppet.gd")
const OUT="res://assets_game/units/kon/oaven/painted_v2/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet := PUPPET.new()
	puppet.position=Vector2(128,210)
	puppet.scale=Vector2.ONE*0.60
	viewport.add_child(puppet)
	for evolved in [false,true]:
		puppet.winged=evolved
		var sheet := Image.create(256*12,256*PUPPET.ACTIONS.size(),false,Image.FORMAT_RGBA8)
		for row in PUPPET.ACTIONS.size():
			puppet.action=PUPPET.ACTIONS[row]
			for frame in 12:
				puppet.phase=float(frame)/11.0 if puppet.action in [&"death",&"hit",&"takeoff",&"landing",&"evolve"] else float(frame)/12.0
				puppet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var rendered := viewport.get_texture().get_image()
				sheet.blit_rect(rendered,Rect2i(0,0,256,256),Vector2i(frame*256,row*256))
			print("[OavenBake] %s %s" % ["jumper" if evolved else "base",puppet.action])
		var filename := "jumper.png" if evolved else "oaven.png"
		assert(sheet.save_png(OUT+filename)==OK)
	viewport.queue_free()
	await process_frame
	quit()
