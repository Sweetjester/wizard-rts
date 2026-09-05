extends SceneTree

const PUPPET=preload("res://tools/spawner/spawner_puppet.gd")
const OUT="res://assets_game/units/kon/spawner/painted_v2/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(768,768)
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var puppet:=PUPPET.new()
	puppet.position=Vector2(384,620)
	puppet.scale=Vector2.ONE*1.7
	viewport.add_child(puppet)
	var sheet:=Image.create(384*12,384*PUPPET.ACTIONS.size(),false,Image.FORMAT_RGBA8)
	for row in PUPPET.ACTIONS.size():
		puppet.action=PUPPET.ACTIONS[row]
		for frame in 12:
			var oneshot:=puppet.action in [&"root_cast",&"uproot_cast",&"evolve_wings",&"hit",&"death",&"takeoff",&"landing",&"summon_drone",&"summon_flying"]
			puppet.phase=float(frame)/(11.0 if oneshot else 12.0)
			puppet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered:=viewport.get_texture().get_image()
			rendered.resize(384,384,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(rendered,Rect2i(0,0,384,384),Vector2i(frame*384,row*384))
		print("[SpawnerBake] ",puppet.action)
	assert(sheet.save_png(OUT+"spawner.png")==OK)
	# A separately rendered card portrait retains detail rather than enlarging a sprite.
	puppet.action=&"idle"
	puppet.phase=0
	puppet.position=Vector2(390,805)
	puppet.scale=Vector2.ONE*2.8
	puppet.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var portrait:=viewport.get_texture().get_image()
	portrait.resize(384,384,Image.INTERPOLATE_LANCZOS)
	assert(portrait.save_png(OUT+"portrait.png")==OK)
	viewport.queue_free()
	await process_frame
	quit()
