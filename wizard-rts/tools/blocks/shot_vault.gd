extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440,1000)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101c22")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a6c0cc")
	env.environment.ambient_light_energy = 0.65
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-30,0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	stage.add_child(light)
	var builder := BlockStructureBuilder.new()
	stage.add_child(builder)
	builder.build(BlockStructureLibrary.load_default().get_definition(&"kons_observer_vault_01"))
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 38
	var output := OS.get_environment("ART_SHOT_DIR")
	for shot in ["open","closed","interior"]:
		builder.set_gate_open(&"vault_entry_open",shot != "closed")
		camera.position = Vector3(12,11,-12) if shot != "interior" else Vector3(4.0,4.3,-3.3)
		camera.look_at(Vector3(4.5,2.2,3.4) if shot != "interior" else Vector3(4.5,2.5,5.5))
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("observer_vault_"+shot+".png"))
	print("[VaultShots] PASS")
	quit()
