extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1000,1200)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor=1
	var scene: Node=load("res://scenes/blocks/block_tower_demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.get("_nav_marks").visible=false
	scene.get("_link_lines").visible=false
	scene.get("_legend").visible=false
	scene.get("_unit").visible=false
	var camera: Camera3D=scene.get("_camera")
	camera.fov=36
	var shots=[
		["tower_front",Vector3(49,29,-35),Vector3(20,17,20)],
		["tower_back",Vector3(-26,33,63),Vector3(20,17,20)],
		["tower_crown",Vector3(43,35,-10),Vector3(20,27,20)]]
	for shot in shots:
		camera.global_position=shot[1]
		camera.look_at(shot[2])
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		var output:=OS.get_environment("ART_SHOT_DIR")
		if output.is_empty(): output="res://assets/structures/observation_tower"
		var error:=root.get_texture().get_image().save_png(output+"/"+shot[0]+".png")
		if error!=OK:
			push_error("Capture failed: "+str(error))
			quit(1)
			return
	print("[TowerCapture] front, back and crown rendered")
	quit()
