extends SceneTree

const MountedArt := preload("res://scripts/units/mounted_knight_art.gd")
const KnightArt := preload("res://scripts/units/steel_knight_directional_art.gd")

func _initialize() -> void: call_deferred("run")

func label_at(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",18)
	root.add_child(label)

func run() -> void:
	root.size = Vector2i(1440,850)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("232c2d")
	background.size = Vector2(root.size)
	root.add_child(background)
	label_at("Steel Force / rider proportions",Vector2(30,20))
	var stage := Node2D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(stage)
	for i in 6:
		var direction: String = ["s","se","e","n","nw","w"][i]
		var origin := Vector2(30+(i%3)*480,360+int(i/3)*380)
		label_at(direction.to_upper(),origin-Vector2(0,300))
		var knight: RTSUnit = load("res://scenes/units/steel_knight.tscn").instantiate()
		var mount: RTSUnit = load("res://scenes/units/mounted_knight.tscn").instantiate()
		stage.add_child(knight)
		stage.add_child(mount)
		knight.position = origin+Vector2(65,0)
		mount.position = origin+Vector2(260,0)
		var foot: Sprite2D = knight.get_node("ArtSprite")
		var art: Sprite2D = mount.get_node("ArtSprite")
		foot.texture = load(KnightArt.ROOT+"steel_knight_"+direction+".png")
		art.texture = load(MountedArt.ROOT+"mounted_knight_"+direction+".png")
		foot.frame = 0
		art.frame = 0
		assert(is_equal_approx(art.scale.x,.85*1.65))
		assert(is_equal_approx(float(art.get_meta("billboard_pixel_size")),.014*1.65))
		assert(is_zero_approx((218-128+art.offset.y)*art.scale.y),"Hooves shifted off origin")
		assert(mount.max_health == 620 and mount.attack_damage == 54,"Visual scale changed combat stats")
		var corpse := preload("res://scripts/fx/oaven_death_sprite.gd").new()
		stage.add_child(corpse)
		corpse.configure(mount,art)
		assert(corpse.scale == art.scale and corpse.offset == art.offset,"Corpse lost visual scale")
		corpse.hide()
		label_at("Knight",origin+Vector2(30,16))
		label_at("Mounted knight",origin+Vector2(185,16))
	for i in 5: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var dir := OS.get_environment("ART_SHOT_DIR")
		if not dir.is_empty(): root.get_texture().get_image().save_png(dir.path_join("mounted_knight_scale.png"))
	stage.queue_free()
	await process_frame
	print("[MountedScale] PASS: six directions, 2D/3D scale, foot anchor, corpse and unchanged combat stats")
	quit()
