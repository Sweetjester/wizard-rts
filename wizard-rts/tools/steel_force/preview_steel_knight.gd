extends SceneTree
const Art := preload("res://scripts/units/steel_knight_directional_art.gd")
var sprites: Array[Sprite2D] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("202927"))
	var stage := Node2D.new()
	root.add_child(stage)
	for row in 4:
		for i in 8:
			var sprite := Sprite2D.new()
			sprite.texture = load(Art.ROOT + "steel_knight_" + Art.DIRECTIONS[i] + ".png")
			sprite.hframes = 8
			sprite.vframes = 5
			sprite.frame = [0, 9, 16, 39][row]
			sprite.scale = Vector2.ONE * .78
			sprite.position = Vector2(i * 200 + 100, row * 240 + 155)
			stage.add_child(sprite)
			sprites.append(sprite)
			var label := Label.new()
			label.text = Art.DIRECTIONS[i].to_upper() + " / " + ["IDLE", "WALK", "STRIKE", "DEATH"][row]
			label.position = Vector2(i * 200 + 24, row * 240 + 25)
			label.add_theme_color_override("font_color", Color("D8C494"))
			stage.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("ART_SHOT_DIR")
	if not output.is_empty():
		root.get_texture().get_image().save_png(output + "/steel_knight_8direction_contacts.png")
	for f in 8:
		for i in 8: sprites[8 + i].frame = 8 + f
		await process_frame
		await RenderingServer.frame_post_draw
		if not output.is_empty(): root.get_texture().get_image().save_png(output + "/steel_knight_walk_%02d.png" % f)
	stage.queue_free()
	await process_frame
	quit()
