extends Node2D

const ROOT := "res://assets_game/units/kon/oaven/directional_v4/"
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const CELL := 192
const ACTIONS := ["idle","move","attack_spear","attack_blowpipe","hit","death","taunt","swap_weapon","charge","takeoff","flying","landing","evolve","idle_blowpipe","move_blowpipe"]
var source: Texture2D
var pieces: Array = []
var bounds: Array[Rect2] = []
var source_scale := 1.0
var row := 0
var phase := 0.0
var evolved := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var key := ShaderMaterial.new()
	key.shader = preload("res://tools/oaven/chroma_key.gdshader")
	material = key

func load_direction(index: int) -> void:
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
	for i in 12:
		pieces.append([])
		bounds.append(Rect2())
	# Connected outlines preserve weapons/wings that cross nominal column gutters.
	for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,img.get_size()),.5):
		var box := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: box = box.expand(point)
		if box.get_area()<16: continue
		var center := box.get_center()/Vector2(img.get_size())
		var slot := clampi(int(center.y*2),0,1)*6+clampi(int(center.x*6),0,5)
		pieces[slot].append(polygon)
		bounds[slot] = bounds[slot].merge(box) if bounds[slot].has_area() else box
	var maximum := Vector2.ZERO
	for i in 12:
		assert(bounds[i].size.y>30,"Missing Oaven pose "+str(i))
		maximum = maximum.max(bounds[i].size)
	source_scale = minf(190.0/bounds[0].size.y,minf(226.0/maximum.x,188.0/maximum.y))

func _draw() -> void:
	if source==null: return
	var pose := 0
	var shape := Vector2.ONE
	var shift := Vector2.ZERO
	var lean := 0.0
	var cycle := phase*TAU
	match row:
		0: shape.y = 1+sin(cycle)*.014
		1,8:
			pose = 1 if phase<.5 else 2
			shift.y = -absf(sin(cycle))*(5 if row==1 else 8)
			shape.y = .97 if row==8 else 1.0
		2:
			pose = 3 if phase>=.375 and phase<.75 else 0
			shape.y = 1-absf(sin(cycle))*.035
		3:
			pose = 4
			lean = sin(cycle)*.025
		4:
			lean = sin(phase*PI)*.08
			shape.y = 1-sin(phase*PI)*.09
		5:
			pose = 5 if phase>=.285 else 0
			shape.y = 1-phase*.65 if pose==0 else 1.0
		6:
			shape = Vector2(1+sin(cycle)*.025,1+absf(sin(cycle))*.045)
		7: pose = 0 if phase<.5 else 4
		9:
			pose = 1 if phase>.35 else 0
			shift.y = -phase*12
			shape.y = 1-sin(phase*PI)*.1
		10:
			pose = 1 if phase<.5 else 2
			shift.y = -12-sin(cycle)*3
		11:
			shape = Vector2(1.08-phase*.08,.82+phase*.18)
		12: shape = Vector2.ONE*(.96+.04*phase)
		13:
			pose = 4
			shape.y = 1+sin(cycle)*.014
		14:
			pose = 4
			shift.y = -absf(sin(cycle))*4
			lean = sin(cycle)*.035
	var slot := (6 if evolved else 0)+pose
	var box := bounds[slot]
	var origin := Vector2(box.get_center().x,box.end.y)
	draw_set_transform(Vector2(128,210)+shift,lean,shape*source_scale)
	for polygon in pieces[slot]:
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point in polygon:
			var vertex: Vector2 = point-origin
			if row==14:
				# Keep the mouth/weapon steady while the lower limbs alternate contact.
				var weight := smoothstep(.62,.95,(point.y-box.position.y)/box.size.y)
				vertex.y -= weight*maxf(0,sin(cycle+(PI if point.x<origin.x else 0)))*8/source_scale
			vertices.append(vertex)
			uvs.append(point/source.get_size())
		draw_polygon(vertices,PackedColorArray([Color.WHITE]),uvs,source)
	draw_set_transform(Vector2.ZERO)
