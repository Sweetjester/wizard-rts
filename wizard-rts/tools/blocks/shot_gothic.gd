extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/blocks/block_citadel_demo.tscn").instantiate()
	root.add_child(scene)
	for i in 60:
		await process_frame
	scene.set("_show_nav",false)
	scene.set("_show_links",false)
	scene.get("_nav_marks").visible=false
	scene.get("_link_lines").visible=false
	scene.get("_legend").visible=false
	scene.get("_unit").visible=false
	var camera: Camera3D = scene.get("_camera")
	# Keep the building large enough to judge material and foliage from the overview.
	camera.fov=39.0
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("ART_SHOT_DIR")
	root.get_texture().get_image().save_png(directory+"/citadel_gothic_overview.png")
	# Stop orbit updates for a fixed facade detail capture.
	scene.set_process(false)
	camera.global_position=Vector3(-2,47,137)
	camera.look_at(Vector3(24,24,89))
	camera.fov=48.0
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/citadel_gothic_detail.png")
	camera.global_position=Vector3(118,45,-37)
	camera.look_at(Vector3(58,19,37))
	camera.fov=48.0
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/citadel_gothic_gate.png")
	print("[GothicCapture] overview and detail saved")
	quit()
