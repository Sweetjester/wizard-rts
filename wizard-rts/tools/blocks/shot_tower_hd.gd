extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1080,1440)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor=1
	root.msaa_3d=Viewport.MSAA_4X
	var scene: Node=load("res://scenes/blocks/block_tower_demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for label in ["_nav_marks","_link_lines","_legend","_unit"]: scene.get(label).visible=false
	scene.get("_xray").set_process(false)
	scene.get("_xray").set_physics_process(false)
	scene.get("_xray").visible=false
	var env: Environment
	var sun: DirectionalLight3D
	for node in scene.get_children():
		if node is WorldEnvironment: env=node.environment
		if node is DirectionalLight3D: sun=node
	env.ambient_light_color=Color("9caeb5")
	env.ambient_light_energy=.62
	env.background_color=Color("20292d")
	env.glow_bloom=0
	env.glow_intensity=.35
	env.glow_hdr_threshold=1.15
	sun.light_color=Color("f2dfc2")
	sun.light_energy=1.05
	var camera: Camera3D=scene.get("_camera")
	camera.fov=36
	var builder: BlockStructureBuilder=scene.get("_builder")
	builder.set_gate_open(&"main_gate_open",false)
	var shots=[
		["tower_hd_front",Vector3(49,30,-36),Vector3(20,17,20)],
		["tower_hd_back",Vector3(-24,35,66),Vector3(20,17,20)],
		["tower_hd_crown",Vector3(39,35,-8),Vector3(20,27,20)],
		["tower_hd_entry",Vector3(29,11,-3),Vector3(20,6,17)]]
	for shot in shots:
		camera.global_position=shot[1]
		camera.look_at(shot[2])
		await capture(shot[0])
	builder.set_gate_open(&"main_gate_open",true)
	await capture("tower_hd_entry_open")
	root.size=Vector2i(1280,720)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=64
	camera.global_position=Vector3(50,61,-30)
	camera.look_at(Vector3(20,14,20))
	await capture("tower_hd_rts")
	root.get_node("DisplayManager").performance_mode=true
	root.get_node("DisplayManager").settings_changed.emit()
	env.glow_enabled=false
	await capture("tower_hd_performance")
	print("[TowerHDShots] front/back/crown/entry/open/RTS/performance captured")
	scene.queue_free()
	await process_frame
	quit()

func capture(label: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var nonblank := 0
	for x in range(img.get_width()/4,img.get_width()*3/4,8):
		for y in range(img.get_height()/4,img.get_height()*3/4,8):
			var c := img.get_pixel(x,y)
			if c.r+c.g+c.b>.55: nonblank+=1
	assert(nonblank>80,"Tower render is blank: "+label)
	var output := OS.get_environment("ART_SHOT_DIR")
	assert(not output.is_empty(),"Set ART_SHOT_DIR for review captures")
	assert(img.save_png(output+"/"+label+".png")==OK)
