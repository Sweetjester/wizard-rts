extends Node2D

const ACTIONS: Array[StringName]=[&"idle",&"move",&"root_cast",&"rooted_idle",&"artillery_attack",&"uproot_cast",&"summon_drone",&"evolve_wings",&"hit",&"death",&"takeoff",&"idle_flying",&"move_flying",&"landing",&"air_artillery",&"summon_flying"]
const PARTS=[Rect2(39,44,400,305),Rect2(487,48,280,299),Rect2(831,65,213,289),Rect2(1090,150,337,195),Rect2(103,380,165,315),Rect2(385,384,183,313),Rect2(620,392,475,304),Rect2(1110,455,265,211),Rect2(120,747,146,274),Rect2(370,771,293,245),Rect2(760,754,244,241),Rect2(1103,766,248,257)]
var source: Texture2D
var action: StringName=&"idle"
var phase:=0.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	source=load("res://assets_game/units/kon/spawner/painted_v3/source_parts.png")
	var key:=ShaderMaterial.new()
	key.shader=load("res://tools/oaven/chroma_key.gdshader")
	material=key

func _part(index: int, rect: Rect2, transform: Transform2D, colour: Color=Color.WHITE) -> void:
	draw_set_transform_matrix(transform)
	draw_texture_rect_region(source,rect,PARTS[index],colour)

func _joint(parent: Transform2D, point: Vector2, angle: float) -> Transform2D:
	return parent*Transform2D(angle,point)

func _leg(base: Transform2D, index: int, far: bool, stride: float, brace: float, dead: float, lift: float) -> void:
	var direction: float=[-1.0,1.0][index]
	var hip:=Vector2(-66+index*114,-117+(8 if not far else -15))
	if far: hip.x+=19
	hip.y-=dead*38.0
	var shade:=Color(0.57,0.68,0.69) if far else Color.WHITE
	var swing:=stride*(0.28 if far else -0.28)
	var upper:=_joint(base,hip,-direction*(0.35+brace*0.24)+swing+dead*direction*0.8)
	_part(4,Rect2(-16,-10,34,67),upper,shade)
	var knee:=_joint(upper,Vector2(0,49),direction*0.18-maxf(0,stride)*0.35+dead*0.75-lift*0.008)
	_part(5,Rect2(-14,-7,37,77),knee,shade)

func _draw() -> void:
	if source==null: return
	var cycle:=phase*TAU
	var walking:=action==&"move"
	var aerial:=action in [&"idle_flying",&"move_flying",&"air_artillery",&"summon_flying"]
	var brace:=1.0 if action in [&"rooted_idle",&"artillery_attack"] else 0.0
	if action==&"root_cast": brace=smoothstep(0,1,phase)
	if action==&"uproot_cast": brace=1.0-smoothstep(0,1,phase)
	var dead:=smoothstep(0.08,0.9,phase) if action==&"death" else 0.0
	var summon:=sin(phase*PI) if action in [&"summon_drone",&"summon_flying"] else 0.0
	var shot:=exp(-pow((phase-0.08)*13.0,2.0)) if action in [&"artillery_attack",&"air_artillery"] else 0.0
	var hurt:=sin(phase*PI) if action==&"hit" else 0.0
	var spread:=1.0 if aerial else 0.0
	if action in [&"takeoff",&"evolve_wings"]: spread=smoothstep(0,1,phase)
	if action==&"landing": spread=1.0-smoothstep(0,1,phase)
	var lift:=spread*22.0
	var bob:=absf(sin(cycle))*3.0 if walking else sin(cycle)*1.5
	var base:=Transform2D(-hurt*0.08-dead*0.20,Vector2(-shot*7,brace*16+dead*65-lift-bob))
	for i in 2:
		_leg(base,i,true,sin(cycle+i*PI) if walking else 0.0,brace,dead,lift)
	var abdomen:=_joint(base,Vector2(-34,-144),sin(cycle)*0.015+summon*0.045)
	var swell:=1.0+summon*0.07
	_part(0,Rect2(-89*swell,-69*swell,178*swell,142*swell),abdomen)
	var hatch:=_joint(abdomen,Vector2(-42,26),-0.15)
	_part(9 if summon>0.35 else 11,Rect2(-27,-20,54,44),hatch)
	var thorax:=_joint(base,Vector2(36,-149),hurt*0.12+shot*0.06)
	_part(1,Rect2(-47,-61,98,120),thorax)
	# Four weight-bearing legs match the quadrupedal concept silhouette.
	for i in 2:
		_leg(base,i,false,sin(cycle+i*PI) if walking else 0.0,brace,dead,lift)
	var cannon:=maxf(brace,1.0 if action==&"air_artillery" else 0.0)
	if cannon>0.01:
		_part(8,Rect2(-21,-93*cannon,43,100*cannon),_joint(base,Vector2(0,-190+shot*11),0.20),Color(1,1,1,1-dead*0.6))
	# Folded wings track the shell; flying wings sweep and foreshorten at the root.
	for far in [true,false]:
		var flap:=sin(cycle*2.0+(0.5 if far else 0.0))*spread
		var wing:=_joint(base,Vector2(13,-179),(0.29 if far else -0.09)+spread*(-0.45 if far else 0.10)+flap*0.25+dead*0.35)
		var colour:=Color(0.6,0.82,0.85,0.92) if far else Color(0.85,1,1,0.95)
		_part(7,Rect2(-135,-30-spread*34,141,57+spread*35),wing,colour)
		_part(6,Rect2(-168,-69-spread*28,176,94+spread*26),wing,colour)
	var head:=_joint(base,Vector2(94,-150),0.08+sin(cycle+0.5)*0.02+hurt*0.15+dead*0.48)
	_part(2,Rect2(-33,-43,68,91),head,Color(1-dead*0.45,1-dead*0.55,1-dead*0.55))
	_part(3,Rect2(0,-37,92,54),_joint(head,Vector2(9,-18),sin(cycle)*0.04+dead*0.6))
	if summon>0.35:
		var release:=clampf((phase-0.2)/0.7,0,1)
		_part(10,Rect2(-17,-18,34,34),_joint(base,Vector2(-76-release*36,-123-release*86),-release*0.25),Color(1,1,1,sin(release*PI)))
	draw_set_transform_matrix(Transform2D.IDENTITY)
