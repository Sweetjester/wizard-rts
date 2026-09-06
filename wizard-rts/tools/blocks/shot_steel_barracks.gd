extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1800,1400)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("202a30")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c4cbd2")
	env.environment.ambient_light_energy=.65
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-35,0)
	light.light_energy=1.15
	light.shadow_enabled=true
	stage.add_child(light)
	var builder := BlockStructureBuilder.new()
	stage.add_child(builder)
	builder.build(BlockStructureLibrary.load_default().get_definition(&"steel_force_barracks_farm_01"))
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=38
	for shot in ["front","closed","rear","interior","detail"]:
		builder.set_gate_open(&"steel_farm_open",shot!="closed")
		builder.set_gate_open(&"steel_muster_open",shot!="closed")
		builder.set_gate_open(&"steel_service_open",false)
		builder.set_interior_view(shot=="interior")
		camera.position=Vector3(15,13,-14)
		var target := Vector3(4.5,1.8,7)
		if shot=="rear": camera.position=Vector3(-12,14,29)
		if shot=="interior": camera.position=Vector3(8,12,1); target=Vector3(4.5,2,10)
		if shot=="detail": camera.position=Vector3(11,7,-1); target=Vector3(4.5,2.2,8)
		camera.look_at(target)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		assert(img.save_png(OS.get_environment("ART_SHOT_DIR")+"/steel_barracks_"+shot+".png")==OK)
	print("[SteelBarracksShots] PASS")
	stage.queue_free()
	await process_frame
	quit()
