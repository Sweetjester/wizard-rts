extends SceneTree

var sprites: Array[Sprite2D]=[]
var elapsed:=0.0
const ROWS=[0,1,2,4,6,12,9,7]
const LABELS=["Spawner / Idle","Heavy gait","Root and brace","Artillery recoil","Release brood","Winged Spawner","Death collapse","Unfurl wings"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1600,880)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor=1
	root.title="Spawner - Painted Animation Review"
	var bg:=ColorRect.new()
	bg.color=Color("172328")
	bg.size=Vector2(1600,880)
	root.add_child(bg)
	for i in 8:
		var sprite:=Sprite2D.new()
		sprite.texture=load("res://assets_game/units/kon/spawner/painted_v2/spawner.png")
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.hframes=12
		sprite.vframes=16
		sprite.offset=Vector2(0,-118)
		sprite.position=Vector2(192+(i%4)*400,350+(i/4)*420)
		root.add_child(sprite)
		sprites.append(sprite)
		var label:=Label.new()
		label.text=LABELS[i]
		label.position=Vector2(24+(i%4)*400,375+(i/4)*420)
		label.add_theme_font_size_override("font_size",22)
		root.add_child(label)
	await create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets_game/units/kon/spawner/painted_v2/animation_review.png")
	if "--capture" in OS.get_cmdline_user_args(): quit()

func _process(delta: float) -> bool:
	elapsed+=delta
	for i in sprites.size():
		var f:=int(elapsed*10)%12
		if i in [2,6,7]: f=mini(11,int(fposmod(elapsed,2.8)*9))
		sprites[i].frame=ROWS[i]*12+f
	return false
