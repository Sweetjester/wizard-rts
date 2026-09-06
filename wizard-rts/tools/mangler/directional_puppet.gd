extends Node2D

const DIRECTIONS := ["e","se","s","sw","w","nw","n","ne"]
const ACTIONS := ["idle","run","attack","hit","windup","leap","land","evolve","death"]
const ROOT := "res://assets_game/units/kon/mangler/directional_v2/"
# Authored gutters account for the source painter's nonuniform spacing.
const CUTS := {
	"s":[0,450,800,1180,1550,1983], "se":[0,400,795,1185,1570,1983],
	"e":[0,400,797,1175,1540,1983], "ne":[0,400,795,1170,1540,1983],
	"n":[0,400,785,1170,1540,1983], "nw":[0,400,790,1180,1540,1983],
	"w":[0,396,790,1160,1540,1947], "sw":[0,400,795,1190,1540,1983]
}
var source: Texture2D
var regions: Array[Rect2i] = []
var source_scale := 1.0
var direction := 0
var evolved := false
var row := 0
var phase := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var key := ShaderMaterial.new()
	key.shader = preload("res://tools/oaven/chroma_key.gdshader")
	material = key

func load_direction(index: int) -> void:
	direction = index
	source = load(ROOT+"sources/"+DIRECTIONS[index]+".png")
	var image := source.get_image()
	if image.is_compressed(): image.decompress()
	regions.clear()
	var maximum := Vector2.ZERO
	for form in 2:
		var cuts: Array = CUTS[DIRECTIONS[index]].duplicate()
		# The raised evolved wings extend beyond the wingless pose's gutter.
		if index == 2 and form == 1: cuts[4] = 1575
		if index == 3 and form == 1: cuts[4] = 1545
		for pose in 5:
			var region := Rect2i(int(cuts[pose]),form*image.get_height()/2,
				int(cuts[pose+1])-int(cuts[pose]),image.get_height()/2)
			var low := region.end
			var high := region.position
			for y in range(region.position.y,region.end.y):
				for x in range(region.position.x,region.end.x):
					var c := image.get_pixel(x,y)
					if minf(c.r,c.b)-c.g > .3: continue
					low = low.min(Vector2i(x,y))
					high = high.max(Vector2i(x,y))
			var bounds := Rect2i(low,high-low+Vector2i.ONE)
			assert(bounds.has_area(),"Missing directional source pose")
			regions.append(bounds)
			maximum = maximum.max(Vector2(bounds.size))
	# One scale for all poses and both forms: raised arms do not shrink the body.
	source_scale = minf(178.0/regions[0].size.y,minf(230.0/maximum.x,207.0/maximum.y))

func _draw() -> void:
	if source == null: return
	var pose := 0
	var squash := Vector2.ONE
	var shift := Vector2.ZERO
	var lean := 0.0
	var cycle := phase*TAU
	match row:
		0: squash = Vector2(1+sin(cycle)*.012,1-sin(cycle)*.01)
		1:
			pose = 1 if phase < .5 else 2
			shift.y = -absf(sin(cycle))*5
		2:
			# Combat has immediate contact: impact first, then recover through raised arms.
			pose = 0 if phase < .3 or phase > .8 else 3
			squash.y = .84+phase*.16 if phase < .3 else 1.0
		3:
			lean = sin(phase*PI)*.06
			squash.y = 1-sin(phase*PI)*.07
		4: squash.y = 1-phase*.18
		5:
			pose = 3
			squash = Vector2(1+sin(cycle)*.015,.94+sin(cycle)*.035)
		6: squash = Vector2(1.08-phase*.08,.78+phase*.22)
		7: squash = Vector2.ONE*(.95+phase*.05)
		8:
			pose = 0 if phase < .25 else 4
			squash.y = 1-phase*.7 if phase < .25 else 1.0
	var region := regions[(5 if evolved else 0)+pose]
	var size := Vector2(region.size)*source_scale
	draw_set_transform(Vector2(128,220)+shift,lean,squash)
	draw_texture_rect_region(source,Rect2(Vector2(-size.x*.5,-size.y),size),region)
	draw_set_transform(Vector2.ZERO)
