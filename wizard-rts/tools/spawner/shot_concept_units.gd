extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440,850)
	root.content_scale_size = root.size
	var bg := ColorRect.new()
	bg.color = Color("283d42")
	bg.size = root.size
	root.add_child(bg)
	var title := Label.new()
	title.text = "KON / CONCEPT-FAITHFUL UNITS"
	title.position = Vector2(40,26)
	title.add_theme_font_size_override("font_size",28)
	root.add_child(title)
	var scenes := ["oaven_spear","spawner","spawner_drone"]
	for i in 3:
		var unit = load("res://scenes/units/"+scenes[i]+".tscn").instantiate()
		root.add_child(unit)
		unit.set_physics_process(false)
		unit.position = Vector2(260+i*460,515)
		unit.scale = Vector2.ONE*3
		var label := Label.new()
		label.text = ["Oaven","Spawner","Spawner Drone"][i]
		label.position = Vector2(185+i*460,600)
		label.add_theme_font_size_override("font_size",25)
		root.add_child(label)
		var small = load("res://scenes/units/"+scenes[i]+".tscn").instantiate()
		root.add_child(small)
		small.set_physics_process(false)
		small.position = Vector2(260+i*460,800)
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("ART_SHOT_DIR").path_join("concept_units_v3.png"))
	quit()
