extends Node2D

const ACTIONS := [&"idle", &"move", &"attack", &"harden", &"wall", &"revert", &"evolve", &"death", &"hit"]
var action: StringName = &"idle"
var phase := 0.0
var level := 1
var source: Texture2D
var regions: Array[Rect2] = []

func _ready() -> void:
	var img := Image.load_from_file("res://assets_game/units/kon/serpent/painted_v2/source.png")
	source = ImageTexture.create_from_image(img)
	var cell := Vector2i(img.get_width()/4,img.get_height()/4)
	for i in 16:
		var origin := Vector2i(i%4,i/4)*cell
		var crop := img.get_region(Rect2i(origin,cell))
		var used := crop.get_used_rect()
		regions.append(Rect2(origin+used.position,used.size))

func part(index: int, centre: Vector2, size: Vector2, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	draw_set_transform(centre,angle)
	draw_texture_rect_region(source,Rect2(-size*0.5,size),regions[index],tint)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if source == null: return
	var t := phase*TAU
	var count := 3+2*(level-1)
	var length := count*21.0
	var head := Vector2(256+length*0.5,148)
	var dying := action == &"death"
	var petrify := 1.0 if action == &"wall" else (phase if action == &"harden" else (1.0-phase if action == &"revert" else 0.0))
	var colour := Color.WHITE.lerp(Color("849da1"),petrify*0.8)
	var lunge := sin(phase*PI)*20.0 if action == &"attack" else 0.0
	head.x += lunge
	if dying: head.y += phase*34
	for i in count:
		var curve := sin(float(i)/count*TAU+0.5)*12.0
		var p := Vector2(head.x-(count-i)*21,169+curve*(1-petrify)+sin(t+i*0.7)*(5.0 if action == &"move" else 1.7)*(1-petrify))
		if dying: p.y += sin(i*1.2)*phase*10
		part(12 if dying and phase>0.4 else (8 if petrify>0.7 else 4+i%2),p,Vector2(44,lerpf(30,57,float(i+1)/count)),sin(t+i*0.5)*0.06*(1-petrify),colour)
	part(11 if petrify>0.7 else 6,Vector2(head.x-length-20,172),Vector2(55,35),0,colour)
	var skull := 2 if dying else (3 if petrify>0.65 else (1 if action == &"attack" and phase>0.2 and phase<0.8 else 0))
	part(skull,head,Vector2(106,103)*(1.0+sin(t)*0.012),phase*0.4 if dying else -lunge*0.003,colour)
	if action == &"attack" and phase>0.35:
		part(14,head+Vector2(45,25),Vector2(27,37)*sin(phase*PI),0,Color(1,1,1,1-phase))
	if action == &"evolve": part(15,Vector2(256,159),Vector2(150,130)*(0.7+phase),phase,Color(1,1,1,sin(phase*PI)*0.65))
	if action == &"hit":
		part(13,head+Vector2(0,-25),Vector2(40,32),phase,Color(1,0.6,0.7,1-phase))
	if dying:
		for i in 3: part(13,Vector2(head.x-i*length/3,194),Vector2(40,24),0,Color(1,1,1,phase))
