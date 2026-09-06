extends Node2D

const ROOT := "res://assets_game/units/steel_force/steel_knight/directional_v2/"
const DIRECTIONS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const SHEETS := ["e_w", "s_se", "s_se", "sw_nw", "e_w", "sw_nw", "n_ne", "n_ne"]
const SOURCE_ROWS := [0, 1, 0, 0, 1, 1, 0, 1]
var source: Texture2D
var pieces: Array = []
var bounds: Array[Rect2] = []
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
	source = load(ROOT + "sources/" + SHEETS[index] + ".png")
	var img := source.get_image()
	if img.is_compressed(): img.decompress()
	var mask := BitMap.new()
	mask.create(img.get_size())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			mask.set_bit(x, y, c.a > .1 and minf(c.r, c.b) - c.g < .28)
	pieces.clear()
	bounds.clear()
	for i in 5:
		pieces.append([])
		bounds.append(Rect2())
	# Connected outlines tolerate the generated poses crossing nominal gutters.
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), .5):
		var box := Rect2(polygon[0], Vector2.ZERO)
		for p in polygon: box = box.expand(p)
		if box.get_area() < 20: continue
		var center := box.get_center() / Vector2(img.get_size())
		if clampi(int(center.y * 2), 0, 1) != SOURCE_ROWS[index]: continue
		var slot := clampi(int(center.x * 5), 0, 4)
		pieces[slot].append(polygon)
		bounds[slot] = bounds[slot].merge(box) if bounds[slot].has_area() else box
	var maximum := Vector2.ZERO
	for i in 5:
		assert(bounds[i].size.y > 30, "Missing Steel Knight pose " + str(i))
		maximum = maximum.max(bounds[i].size)
	# One scale for all poses: a horizontal corpse must not grow into a giant.
	source_scale = minf(180.0 / bounds[0].size.y, minf(210.0 / maximum.y, 226.0 / maximum.x))

func _draw() -> void:
	if source == null: return
	var pose := 0
	var cycle := phase * TAU
	var shape := Vector2.ONE
	var shift := Vector2.ZERO
	var lean := 0.0
	match row:
		0:
			shape.y += sin(cycle) * .006
		1:
			# Passing stance between the two painted stride contacts prevents a pop.
			pose = [1, 1, 0, 0, 2, 2, 0, 0][mini(7, int(phase * 8))]
			shift.y = -absf(sin(cycle)) * 1.8
			shape.y -= absf(sin(cycle)) * .018
		2:
			# Combat applies damage immediately; first frame is the strike contact.
			pose = 3 if phase < .55 else 0
			shift = Vector2.from_angle(direction * PI / 4) * (1.0 - phase) * 4.0
			shape.y -= sin(phase * PI) * .035
		3:
			lean = sin(phase * PI) * .035
			shape.y -= sin(phase * PI) * .07
		4:
			pose = 0 if phase < .14 else 4
			shape.y = .8 if pose == 0 else 1.08 - .08 * phase
	var box := bounds[pose]
	var origin := Vector2(box.get_center().x, box.end.y)
	draw_set_transform(Vector2(128, 220) + shift, lean, shape * source_scale)
	for polygon in pieces[pose]:
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for p in polygon:
			vertices.append(p - origin)
			uvs.append(p / source.get_size())
		draw_polygon(vertices, PackedColorArray([Color.WHITE]), uvs, source)
	draw_set_transform(Vector2.ZERO)
