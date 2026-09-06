extends Node2D

const ROOT := "res://assets_game/units/kon/hero/directional_v3/"
const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
var source: Texture2D
var pieces: Array = []
var bounds: Array[Rect2] = []
var anchors: Array[Vector2] = []
var source_scale := 1.0
var direction := 0
var row := 0
var phase := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var key := ShaderMaterial.new()
	key.shader = preload("res://tools/oaven/chroma_key.gdshader")
	material = key

func load_direction(index: int) -> void:
	direction = index
	source = ImageTexture.create_from_image(Image.load_from_file(ROOT+"sources/"+DIRECTIONS[index]+".png"))
	var img := source.get_image()
	var mask := BitMap.new()
	mask.create(img.get_size())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			mask.set_bit(x,y,c.a>.1 and minf(c.r,c.b)-c.g<.28)
	pieces.clear()
	bounds.clear()
	anchors.clear()
	var bodies: Array[Rect2] = []
	for i in 9:
		pieces.append([])
		bounds.append(Rect2())
		bodies.append(Rect2())
	# Connected silhouettes preserve branch tips crossing nominal cell gutters.
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,img.get_size()),.5):
		var box := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: box = box.expand(point)
		if box.get_area()<16: continue
		var center := box.get_center()/Vector2(img.get_size())
		var slot := clampi(int(center.y*3),0,2)*3+clampi(int(center.x*3),0,2)
		pieces[slot].append(polygon)
		bounds[slot] = bounds[slot].merge(box) if bounds[slot].has_area() else box
		if box.get_area()>bodies[slot].get_area(): bodies[slot]=box
	var maximum := Vector2.ZERO
	for i in 9:
		assert(bodies[i].size.y>60,"Missing Kon pose "+str(i))
		# Tiny detached marks in the lower gutter belong to the next source row.
		# Keep substantial detached branches and sparks alongside the casting hand.
		var kept: Array = []
		bounds[i]=Rect2()
		for polygon in pieces[i]:
			var box := Rect2(polygon[0],Vector2.ZERO)
			for point in polygon: box=box.expand(point)
			if i!=8 and box.position.y>bodies[i].end.y+3: continue
			kept.append(polygon)
			bounds[i]=bounds[i].merge(box) if bounds[i].has_area() else box
		pieces[i]=kept
		maximum = maximum.max(bounds[i].size)
		var body := bodies[i]
		var sum_x := 0.0
		var pixels := 0
		# Anchor to feet, not the bounding centre of an extended attack branch.
		for y in range(int(body.end.y)-12,int(body.end.y)):
			for x in range(int(body.position.x),int(body.end.x)):
				if mask.get_bit(x,y): sum_x+=x; pixels+=1
		anchors.append(Vector2(sum_x/maxi(pixels,1) if pixels>0 else body.get_center().x,body.end.y))
		if i==8: anchors[i]=Vector2(bounds[i].get_center().x,bounds[i].end.y)
	source_scale = minf(278.0/bounds[0].size.y,minf(300.0/maximum.y,320.0/maximum.x))
	# Reserve edge padding for attack lean and detached spell sparks. Extended
	# strikes may offset the stance, but never shrink a pose or cut off a branch.
	for i in 9:
		anchors[i].x=clampf(anchors[i].x,bounds[i].end.x-174.0/source_scale,bounds[i].position.x+174.0/source_scale)

func _draw() -> void:
	if source==null: return
	var pose := 0
	var cycle := phase*TAU
	var shape := Vector2.ONE
	var shift := Vector2.ZERO
	var lean := 0.0
	match row:
		0: shape.y += sin(cycle)*.006
		1:
			pose = [1,1,1,0,0,0,2,2,2,0,0,0][mini(11,int(phase*12))]
			shift.y = -absf(sin(cycle))*2.5
			shape.y -= absf(sin(cycle))*.015
		2:
			# Contacts at .12s and .36s match the authoritative Broken Staff pair.
			pose = 0 if phase<.14 or phase>.8 else (3 if phase<.46 else 4)
			shift = Vector2.from_angle(direction*PI/4)*sin(phase*PI)*4
		3:
			pose = 5 if phase>.08 else 0
			shape.y += sin(phase*PI)*.012
		4:
			pose = 6
			shape.y += sin(cycle)*.004
		5:
			pose = 7 if phase>.08 else 0
			shape.y += sin(phase*PI)*.018
		6:
			lean = sin(phase*PI)*.04
			shape.y -= sin(phase*PI)*.055
		7:
			pose = 0 if phase<.1 else 8
			shape.y = .88 if pose==0 else 1.04-.04*phase
	draw_set_transform(Vector2(192,330)+shift,lean,shape*source_scale)
	for polygon in pieces[pose]:
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for p in polygon:
			vertices.append(p-anchors[pose])
			uvs.append(p/source.get_size())
		draw_polygon(vertices,PackedColorArray([Color.WHITE]),uvs,source)
	draw_set_transform(Vector2.ZERO)
