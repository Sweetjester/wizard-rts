extends SceneTree

# Beauty render: the citadel with the debug overlay off, for comparing the skin
# against the reference art rather than against a nav visualisation.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/blocks/block_citadel_demo.tscn").instantiate()
	root.add_child(scene)
	for _i in 90:
		await process_frame
	scene.set("_show_nav", false)
	scene.set("_show_links", false)
	scene.get("_nav_marks").visible = false
	scene.get("_link_lines").visible = false
	scene.get("_legend").visible = false
	for _i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	print("[ShotClean] wrote")
	quit(0)
