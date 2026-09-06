extends Node2D

const ROOT := "res://assets_game/units/steel_force/mounted_knight/directional_v1/"
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const CELL := 256
var source: Texture2D
var pieces: Array = []
var bounds: Array[Rect2] = []
var source_scale := 1.0
var direction := 0
var row := 0
var phase := 0.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var key := ShaderMaterial.new()
	key.shader=preload("res://tools/oaven/chroma_key.gdshader")
	material=key

func load_direction(index: int) -> void:
	direction=index
	source=load(ROOT+"sources/"+DIRECTIONS[index]+".png")
	var img := source.get_image()
	if img.is_compressed(): img.decompress()
	var mask := BitMap.new()
	mask.create(img.get_size())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			mask.set_bit(x,y,minf(c.r,c.b)-c.g<.28 and c.a>.1)
	pieces.clear()
	bounds.clear()
	for i in 10:
		pieces.append([])
		bounds.append(Rect2())
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,img.get_size()),.5):
		var box := Rect2(polygon[0],Vector2.ZERO)
		for p in polygon: box=box.expand(p)
		if box.get_area()<20: continue
		var center := box.get_center()/Vector2(img.get_size())
		var slot := clampi(int(center.y*2),0,1)*5+clampi(int(center.x*5),0,4)
		pieces[slot].append(polygon)
		bounds[slot]=bounds[slot].merge(box) if bounds[slot].has_area() else box
	var maximum := Vector2.ZERO
	for i in 10:
		assert(bounds[i].size.y>30,"Missing mounted pose "+str(i))
		maximum=maximum.max(bounds[i].size)
	source_scale=minf(198.0/maximum.y,222.0/maximum.x)

func _draw() -> void:
	if source==null: return
	var slot := 0
	var cycle := phase*TAU
	var shape := Vector2.ONE
	var shift := Vector2.ZERO
	var lean := 0.0
	match row:
		0,5:
			slot=5 if row==5 else 0
			shape.y=1+sin(cycle)*.009
		1,2,6:
			slot=(6 if phase<.5 else 7) if row==6 else (1 if phase<.5 else 2)
			shift.y=-absf(sin(cycle))*(6 if row==2 else 4)
			shape.y=1-absf(sin(cycle))*.025
		3,7:
			# Damage is authoritative at attack start; contact art begins immediately.
			slot=(8 if row==7 else 3) if phase<.5 else (5 if row==7 else 0)
			shift.x=cos(direction*PI/4)*(1-phase)*5
		4:
			slot=5
			shape=Vector2(1+sin(phase*PI)*.015,1+sin(phase*PI)*.025)
		8,10:
			# Recoil retains the weapon, unlike some generated hit-source poses.
			slot=5 if row==10 else 0
			lean=sin(phase*PI)*.04
			shape.y=1-sin(phase*PI)*.08
		9:
			# The rider is already a live T2 unit: never paint a second rider in the corpse.
			slot=4
			shape.y=1.18-.18*phase
			lean=sin(phase*PI)*.035
	var box := bounds[slot]
	var origin := Vector2(box.get_center().x,box.end.y)
	draw_set_transform(Vector2(128,218)+shift,lean,shape*source_scale)
	for polygon in pieces[slot]:
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for p in polygon:
			var vertex: Vector2 = p-origin
			# Small cloth/weapon motion above the shoulder leaves hoof contacts anchored.
			if row in [0,4,5]:
				var weight := 1-smoothstep(.15,.6,(p.y-box.position.y)/box.size.y)
				vertex.x+=sin(cycle)*weight*1.4/source_scale
			vertices.append(vertex)
			uvs.append(p/source.get_size())
		draw_polygon(vertices,PackedColorArray([Color.WHITE]),uvs,source)
	draw_set_transform(Vector2.ZERO)
