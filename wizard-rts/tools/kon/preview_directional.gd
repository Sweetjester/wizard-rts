extends SceneTree
const Art := preload("res://scripts/units/kon_painted_art.gd")
var sprites: Array[Sprite2D] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1600,850)
	root.content_scale_size=root.size
	var bg := ColorRect.new()
	bg.size=Vector2(root.size)
	bg.color=Color("202d30")
	root.add_child(bg)
	var title := Label.new()
	title.text="KON / eight painted directions"
	title.position=Vector2(30,20)
	title.add_theme_font_size_override("font_size",24)
	root.add_child(title)
	for i in 8:
		var sprite := Sprite2D.new()
		sprite.texture=load(Art.ROOT+"kon_"+Art.DIRECTIONS[i]+".png")
		sprite.hframes=12
		sprite.vframes=8
		sprite.offset=Vector2(0,-138)
		sprite.scale=Vector2.ONE
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position=Vector2(200+(i%4)*400,370+int(i/4)*390)
		root.add_child(sprite)
		sprites.append(sprite)
		var label := Label.new()
		label.text=Art.DIRECTIONS[i].to_upper()
		label.position=sprite.position+Vector2(-15,14)
		label.add_theme_font_size_override("font_size",20)
		root.add_child(label)
	for row in [0,1,2,3,4,5,6,7]:
		for sprite in sprites: sprite.frame=row*12+(0 if row==0 else 6)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("ART_SHOT_DIR").path_join("kon_directional_"+str(Art.ACTIONS[row])+".png")
		assert(root.get_texture().get_image().save_png(path)==OK)
	quit()
