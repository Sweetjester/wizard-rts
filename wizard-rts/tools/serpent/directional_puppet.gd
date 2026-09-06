extends Node2D

const ROOT := "res://assets_game/units/kon/serpent/directional_v3/"
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const CELL := 256
const ACTIONS := ["idle","move","attack","harden","wall","revert","evolve","death","hit"]
var source: Texture2D
var effects: Texture2D
var effect_regions: Array[Rect2] = []
var pieces: Array = []
var bounds: Array[Rect2] = []
var direction := 0
var level := 1
var row := 0
var phase := 0.0

static func projected_facing(index: int) -> Vector2:
	var vector := Vector2.from_angle(index*PI/4)
	return Vector2(vector.x,vector.y*.6)

static func head_anchor(stage: int, index: int) -> Vector2:
	return Vector2(128,128)+projected_facing(index)*(3+2*(clampi(stage,1,6)-1))*5.25

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var key := ShaderMaterial.new()
	key.shader = preload("res://tools/oaven/chroma_key.gdshader")
	material = key
	var img := Image.load_from_file("res://assets_game/units/kon/serpent/painted_v2/source.png")
	effects = ImageTexture.create_from_image(img)
	var cell := Vector2i(img.get_width()/4,img.get_height()/4)
	for i in 16:
		var origin := Vector2i(i%4,i/4)*cell
		var used := img.get_region(Rect2i(origin,cell)).get_used_rect()
		effect_regions.append(Rect2(origin+used.position,used.size))

func load_direction(index: int) -> void:
	direction = index
	source = load(ROOT+"sources/"+DIRECTIONS[index]+".png")
	var img := source.get_image()
	if img.is_compressed(): img.decompress()
	var bitmap := BitMap.new()
	bitmap.create(img.get_size())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			bitmap.set_bit(x,y,minf(c.r,c.b)-c.g<.28 and c.a>.1)
	pieces.clear()
	bounds.clear()
	for i in 8:
		pieces.append([])
		bounds.append(Rect2())
	# Connected outlines retain fins/antennae crossing nominal grid boundaries.
	for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,img.get_size()),.5):
		var box := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: box = box.expand(point)
		if box.get_area()<16: continue
		var center := box.get_center()/Vector2(img.get_size())
		var slot := clampi(int(center.y*2),0,1)*4+clampi(int(center.x*4),0,3)
		pieces[slot].append(polygon)
		bounds[slot] = bounds[slot].merge(box) if bounds[slot].has_area() else box
	for i in 8: assert(bounds[i].size.y>30,"Missing Serpent part "+str(i))

func part(slot: int, center: Vector2, size: Vector2, angle: float=0, tint: Color=Color.WHITE) -> void:
	var box := bounds[slot]
	draw_set_transform(center,angle,size/box.size)
	for polygon in pieces[slot]:
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point in polygon:
			vertices.append(point-box.get_center())
			uvs.append(point/source.get_size())
		draw_polygon(vertices,PackedColorArray([tint]),uvs,source)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if source==null: return
	var count := 3+2*(level-1)
	var forward := projected_facing(direction)
	var side := projected_facing(posmod(direction+2,8))
	var pivot := head_anchor(level,direction)*2
	var cycle := phase*TAU
	var petrify := 0.0
	if row==3: petrify=phase
	if row==4: petrify=1.0
	if row==5: petrify=1-phase
	var dying := smoothstep(.05,.85,phase) if row==7 else 0.0
	var bite := sin(phase*PI) if row==2 else 0.0
	var lunge := forward*bite*24
	var tint := Color.WHITE.lerp(Color("9ca9ae"),petrify)
	if row==8: tint=tint.lerp(Color("e8c2c4"),sin(phase*PI)*.5)
	var draw_parts: Array[Dictionary] = []
	for i in count:
		var fraction := float(i+1)/count
		var distance := (count-i)*21.0
		var wave := sin(fraction*TAU+cycle*(1 if row==1 else .15))*14*(1-petrify)*(1-dying)
		var ground := pivot-forward*distance+side*wave+lunge*fraction
		var width := lerpf(25,49,fraction)
		var size := Vector2(lerpf(width,44,absf(forward.x)),lerpf(width,37,absf(forward.y)/.6))
		size.y *= 1-dying*.35
		draw_parts.append({"slot":7 if dying>.4 else 4+i%2,"center":ground-Vector2(0,22-dying*15),"size":size,"depth":ground.y,"angle":sin(cycle+i*.65)*.045*(1-petrify)*(1-dying)})
	var tail_ground := pivot-forward*(count*21+17)
	var tail_size := Vector2(48 if direction%4==0 else 38,30 if direction%4==0 else 44)
	# Two source tails point toward their head; align these loose parts along the spine.
	var tail_angle := PI if direction in [2,3] else 0.0
	draw_parts.append({"slot":6,"center":tail_ground-Vector2(0,14-dying*10),"size":tail_size,"depth":tail_ground.y,"angle":tail_angle})
	var head_slot := 0
	if row==2 and phase>.12 and phase<.86: head_slot=1
	if petrify>.45: head_slot=3
	if dying>.25: head_slot=2
	var head_size := Vector2(106,103)
	# Keep source aspect and consistent crown height instead of stretching the frontal fin fan.
	head_size.x = minf(118,103*bounds[head_slot].size.x/bounds[head_slot].size.y)
	head_size.y *= 1-dying*.28
	var head_ground := pivot+lunge
	var breathe := sin(cycle)*1.5*(1-petrify)*(1-dying)
	draw_parts.append({"slot":head_slot,"center":head_ground-Vector2(0,head_size.y*.5+7-dying*14+breathe),"size":head_size,"depth":head_ground.y+.1,"angle":sin(phase*PI)*.05 if row==8 else 0.0})
	draw_parts.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.depth<b.depth)
	for p in draw_parts: part(p.slot,p.center,p.size,p.angle,tint)
	if row==2 and phase>.25:
		var size := Vector2(25,35)*sin(phase*PI)
		draw_texture_rect_region(effects,Rect2(pivot+forward*40-Vector2(0,32)-size*.5,size),effect_regions[14],Color(1,1,1,1-phase))
	if row==6:
		var size := Vector2.ONE*(85+phase*60)
		draw_texture_rect_region(effects,Rect2(pivot-Vector2(0,20)-size*.5,size),effect_regions[15],Color(1,1,1,sin(phase*PI)*.65))
