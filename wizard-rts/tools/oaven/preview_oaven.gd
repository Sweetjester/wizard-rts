extends SceneTree

var sprites: Array[Sprite2D]=[]
var elapsed:=0.0
const ROWS=[0,1,2,3,4,5,10,12]
const LABELS=["Oaven / Idle","Run","Spear thrust","Blowpipe","Hit reaction","Death","Jumper / Flight","Evolution"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor=1.0
	root.title="Oaven - Painted Animation Review"
	var background:=ColorRect.new()
	background.color=Color("141c20")
	background.size=Vector2(1280,720)
	root.add_child(background)
	for i in 8:
		var sprite:=Sprite2D.new()
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.texture=load("res://assets_game/units/kon/oaven/painted_v2/"+("jumper.png" if i>=6 else "oaven.png"))
		sprite.hframes=12
		sprite.vframes=15
		sprite.scale=Vector2.ONE*1.8
		sprite.offset=Vector2(0,-82)
		sprite.position=Vector2(140+(i%4)*320,300+(i/4)*340)
		root.add_child(sprite)
		sprites.append(sprite)
		var label:=Label.new()
		label.text=LABELS[i]
		label.position=Vector2(25+(i%4)*320,315+(i/4)*340)
		label.add_theme_font_size_override("font_size",19)
		root.add_child(label)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets_game/units/kon/oaven/painted_v2/animation_review.png")
	if "--capture" in OS.get_cmdline_user_args(): quit()

func _process(delta: float) -> bool:
	elapsed+=delta
	for i in sprites.size():
		var f:=int(elapsed*12.0)%12
		if i==5: f=mini(11,int(fposmod(elapsed,2.5)*12.0))
		sprites[i].frame=ROWS[i]*12+f
	return false
