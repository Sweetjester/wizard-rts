extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1440,1000)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor=1
	var scene: Node=load("res://scenes/blocks/block_splicing_lab_demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for key in ["_nav_marks","_link_lines","_legend","_unit"]: scene.get(key).visible=false
	var camera: Camera3D=scene.get("_camera")
	camera.fov=42
	var shots=[
		["splicing_lab_exterior",Vector3(70,36,-25),Vector3(26,7,25)],
		["splicing_lab_interior",Vector3(52,49,0),Vector3(26,5,25)],
		["splicing_lab_hall",Vector3(26,3.8,20),Vector3(26,3.5,32)]]
	for shot in shots:
		camera.fov=65 if shot[0]=="splicing_lab_hall" else 42
		camera.global_position=shot[1]
		camera.look_at(shot[2])
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		var directory:=OS.get_environment("ART_SHOT_DIR")
		if directory.is_empty(): directory="user://"
		if root.get_texture().get_image().save_png(directory+"/"+shot[0]+".png")!=OK:
			quit(1)
			return
	print("[LabCapture] Exterior and interior saved")
	quit()
