extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600,1000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111a20")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("9cbdc3")
	environment.environment.ambient_light_energy = 0.55
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_color = Color("bdced4")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("273638")
	ground.material_override = material
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 40
	stage.add_child(camera)
	camera.make_current()
	var library := BlockStructureLibrary.load_default()
	var shots := [
		[&"kons_arcane_citadel_01", "quarter_citadel", Vector3(41,35,-31),Vector3(12,4,12)],
		[&"kons_observation_wizard_tower_01", "restored_tower", Vector3(48,39,-46),Vector3(9,16,9)],
		[&"kons_splicing_laboratory_01", "redesigned_laboratory", Vector3(14,10,-12),Vector3(4.5,2.3,3.5)]]
	for shot in shots:
		var builder := BlockStructureBuilder.new()
		stage.add_child(builder)
		builder.build(library.get_definition(shot[0]))
		for key in library.gate_defaults_for(shot[0]): builder.set_gate_open(StringName(key),true)
		camera.position = shot[2]
		camera.look_at(shot[3])
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		var path: String = OS.get_environment("ART_SHOT_DIR")+"/"+str(shot[1])+".png"
		var result := root.get_texture().get_image().save_png(path)
		if result != OK:
			push_error("Could not save "+path)
			quit(1)
			return
		print("[QuarterCapture] ",path)
		builder.queue_free()
		await process_frame
	stage.queue_free()
	for i in 3: await process_frame
	quit()
