extends SceneTree

var sprites: Array[Sprite2D]=[]
var elapsed := 0.0
var stage: Node2D
const ROWS=[0,1,2,7]
const LABELS=["Kon / Broken Staff", "Movement", "Two-branch attack", "Death"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1600,1000)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.title="Kon - Life Wizard"
	var bg := ColorRect.new()
	bg.color=Color("172629")
	bg.size=Vector2(1600,1000)
	root.add_child(bg)
	stage=Node2D.new()
	root.add_child(stage)
	for i in 4:
		var sprite := Sprite2D.new()
		sprite.texture=load("res://assets_game/units/kon/hero/painted_v2/kon.png")
		sprite.hframes=12
		sprite.vframes=8
		sprite.position=Vector2(200+i*400,200)
		stage.add_child(sprite)
		sprites.append(sprite)
		_label(LABELS[i],Vector2(32+i*400,380))
	for i in 3:
		var fx := preload("res://scripts/fx/kon_spell_fx.gd").new()
		fx.action=[&"seal_away",&"biostorm",&"observation"][i]
		fx.duration=99999.0
		fx.radius=145.0
		stage.add_child(fx)
		fx.position=Vector2(280+i*520,760)
		_label(["Seal Away", "Biostorm", "Observation"][i],Vector2(130+i*520,930))
	await create_timer(0.55).timeout
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("ART_SHOT_DIR")
	if not out.is_empty():
		assert(root.get_texture().get_image().save_png(out+"/kon_review.png")==OK)
	if "--capture" in OS.get_cmdline_user_args(): quit()

func _label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text=text
	label.position=at
	label.add_theme_font_size_override("font_size",24)
	root.add_child(label)

func _process(delta: float) -> bool:
	elapsed+=delta
	for i in sprites.size():
		var frame_index := int(elapsed*16.0)%12
		if i==3: frame_index=mini(11,int(fposmod(elapsed,3.0)*20))
		sprites[i].frame=ROWS[i]*12+frame_index
	return false
