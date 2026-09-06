extends Node2D

const ACTIONS: Array[StringName] = [&"idle", &"move", &"attack", &"hit", &"death"]
# Authored source bounds; the generated sheet is not a perfectly packed atlas.
const PARTS := [Rect2(30,300,580,255), Rect2(650,325,580,160),
	Rect2(120,847,430,168), Rect2(700,765,420,250)]
var source: Texture2D
var action: StringName = &"idle"
var phase := 0.0

func _ready() -> void:
	source = load("res://assets_game/units/kon/spawner_drone/painted_v1/source_parts.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var key := ShaderMaterial.new()
	key.shader = load("res://tools/oaven/chroma_key.gdshader")
	material = key

func _draw() -> void:
	if source == null: return
	var dead := smoothstep(0.0,1.0,phase) if action == &"death" else 0.0
	var strike := sin(phase*PI) if action == &"attack" else 0.0
	var hurt := sin(phase*PI) if action == &"hit" else 0.0
	var body := Transform2D(dead*1.2+strike*.13-hurt*.2,
		Vector2(strike*12-hurt*5,dead*20-sin(phase*TAU)*2))
	for far in [true,false]:
		for small in [true,false]:
			var flap := sin(phase*TAU+(0.7 if far else 0.0))
			var angle := (-.8 if far else .65)+flap*.55*(1-dead)
			angle = lerpf(angle,.15 if far else -.15,dead)
			var wing := body*Transform2D(angle,Vector2(12,-6))
			draw_set_transform_matrix(wing)
			var length := 65.0 if small else 86.0
			var width := (16.0 if small else 22.0)*(0.48+absf(flap)*.52)
			draw_texture_rect_region(source,Rect2(-length,-width*.5,length,width),PARTS[2 if small else 1],Color(.72,.88,.94) if far else Color.WHITE)
	draw_set_transform_matrix(body)
	draw_texture_rect_region(source,Rect2(-56,-18,105,46),PARTS[3 if dead>.4 else 0],Color.WHITE.lerp(Color(.45,.53,.58),dead))
	draw_set_transform_matrix(Transform2D.IDENTITY)
