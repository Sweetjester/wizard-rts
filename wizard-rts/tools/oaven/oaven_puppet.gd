extends Node2D

const ACTIONS: Array[StringName] = [&"idle",&"move",&"attack_spear",&"attack_blowpipe",&"hit",&"death",&"taunt",&"swap_weapon",&"charge",&"takeoff",&"flying",&"landing",&"evolve",&"idle_blowpipe",&"move_blowpipe"]
const PARTS := [Rect2(65,40,355,303),Rect2(444,38,285,326),Rect2(756,54,305,312),Rect2(1110,70,291,272),Rect2(100,382,171,281),Rect2(446,384,215,279),Rect2(778,388,191,278),Rect2(1124,388,190,279),Rect2(161,677,77,365),Rect2(509,677,76,365),Rect2(794,676,153,365),Rect2(1139,758,131,250)]
var source: Texture2D
var action: StringName=&"idle"
var phase := 0.0
var winged := false

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	source=load("res://assets_game/units/kon/oaven/painted_v2/source_parts.png")
	var key := ShaderMaterial.new()
	key.shader=load("res://tools/oaven/chroma_key.gdshader")
	material=key

func _part(index: int, rect: Rect2, transform: Transform2D, colour: Color=Color.WHITE) -> void:
	draw_set_transform_matrix(transform)
	draw_texture_rect_region(source,rect,PARTS[index],colour)

func _joint(parent: Transform2D, point: Vector2, angle: float) -> Transform2D:
	return parent*Transform2D(angle,point)

func _draw() -> void:
	if source==null:
		return
	var cycle := phase*TAU
	var moving := action in [&"move",&"move_blowpipe",&"charge"]
	var stride := sin(cycle) if moving else 0.0
	var thrust := sin(clampf((phase-0.12)/0.55,0.0,1.0)*PI) if action==&"attack_spear" else 0.0
	var recoil := sin(phase*PI) if action==&"hit" else 0.0
	var puff := exp(-pow((phase-0.42)*18.0,2.0)) if action==&"attack_blowpipe" else 0.0
	modulate=Color.WHITE.lerp(Color(0.55,1.0,1.0),sin(phase*PI)*0.65) if action==&"evolve" else Color.WHITE
	var dead := smoothstep(0.12,0.88,phase) if action==&"death" else 0.0
	var taunt := sin(phase*PI) if action==&"taunt" else 0.0
	var flying := action in [&"flying",&"takeoff",&"landing"]
	var lift := 0.0
	if flying:
		lift=18.0
		if action==&"takeoff": lift*=smoothstep(0.0,1.0,phase)
		if action==&"landing": lift*=1.0-smoothstep(0.0,1.0,phase)
	var angle := -dead*1.48-recoil*0.18+(0.16 if action==&"charge" else 0.0)
	var hip := Vector2(thrust*12.0-puff*4.0, -69.0+dead*55.0-lift-absf(stride)*3.0+sin(cycle)*0.8)
	var base := Transform2D(angle, hip-Vector2(0,-69).rotated(angle))
	var body := _joint(base,Vector2(0,-69),0.07*stride+thrust*0.13)
	_part(3,Rect2(-51,-3,55,50),_joint(body,Vector2(-10,9),sin(cycle)*0.1))
	if winged:
		for side: float in [-1.0,1.0]:
			var flap := sin(cycle*2.0)*0.28 if flying else sin(cycle)*0.025
			_part(10,Rect2(-12,-91,32,95),_joint(body,Vector2(-2,-35),side*(0.62+flap)),Color(0.7,0.95,1,0.85))
			_part(11,Rect2(-8,-62,24,68),_joint(body,Vector2(-2,-26),side*(1.1-flap)),Color(0.7,0.95,1,0.8))
	for side: float in [-1.0,1.0]:
		var far := side<0
		var colour := Color(0.7,0.78,0.83) if far else Color.WHITE
		var thigh := _joint(base,Vector2(side*11,-67),stride*side*0.58+dead*side*0.35)
		_part(6,Rect2(-12,-6,26,42),thigh,colour)
		var knee := _joint(thigh,Vector2(0,29),maxf(0.0,-stride*side)*0.7+dead*0.22)
		_part(7,Rect2(-9,-4,28,43),knee,colour)
	var rear := _joint(body,Vector2(-19,-30),0.18+stride*0.4-taunt*1.6)
	_part(4,Rect2(-12,-4,25,37),rear,Color(0.72,0.8,0.86))
	_part(5,Rect2(-9,-4,24,35),_joint(rear,Vector2(0,25),-0.6),Color(0.72,0.8,0.86))
	_part(1,Rect2(-28,-48,58,79),body)
	var head := _joint(body,Vector2(1,-59),-0.06+recoil*0.22-taunt*0.13)
	_part(0,Rect2(-44,-56,88,75),head,Color(1.0-dead*0.38,1.0-dead*0.4,1.0-dead*0.38))
	_part(2,Rect2(-30,-56,60,49),_joint(body,Vector2.ZERO,sin(cycle+0.6)*0.025))
	var ranged := action in [&"attack_blowpipe",&"idle_blowpipe",&"move_blowpipe"]
	var arm_angle := -0.22-stride*0.3-thrust*0.7-taunt*0.9
	if ranged: arm_angle=-0.85
	if action==&"swap_weapon": arm_angle-=sin(phase*PI)*1.2
	var arm := _joint(body,Vector2(21,-31),arm_angle)
	_part(4,Rect2(-12,-5,26,37),arm)
	var forearm := _joint(arm,Vector2(0,25),-0.92-thrust*0.8)
	if ranged: forearm=_joint(arm,Vector2(0,25),-1.35)
	var hand := forearm*Vector2(7,23)
	var weapon_angle := 0.22+thrust*1.18+dead*0.7
	if ranged: weapon_angle=PI*0.5
	var weapon := Transform2D(weapon_angle+angle,hand)
	if ranged:
		_part(9,Rect2(-3,-64,8,80),weapon)
	else:
		_part(8,Rect2(-6,-111,13,143),weapon)
	_part(5,Rect2(-10,-4,26,36),forearm)
	draw_set_transform_matrix(Transform2D.IDENTITY)
