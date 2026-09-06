extends Node2D

var archetype := "poorper"
var row := 0
var phase := 0.0
var source: Texture2D
var regions: Array[Rect2] = []

func _ready() -> void:
	source = load("res://assets_game/units/steel_force/painted_v1/"+archetype+"_source.png")
	var key := ShaderMaterial.new()
	key.shader = load("res://tools/oaven/chroma_key.gdshader")
	material = key
	if archetype == "proper_blimp":
		regions = [Rect2(0,75,605,515),Rect2(627,75,627,515),Rect2(0,685,600,515),Rect2(627,685,627,515)]
	elif archetype == "poorper":
		regions = [Rect2(0,0,390,512),Rect2(400,0,390,512),Rect2(795,0,390,512),Rect2(1185,0,351,512),Rect2(0,530,490,460),Rect2(475,530,315,460),Rect2(795,630,320,355),Rect2(1105,750,431,245)]
	else:
		regions = [Rect2(0,0,380,512),Rect2(380,0,390,512),Rect2(770,0,390,512),Rect2(1160,0,376,512),Rect2(0,520,380,470),Rect2(380,520,370,470),Rect2(750,610,360,380),Rect2(1110,700,426,290)]

func _draw() -> void:
	if source == null: return
	var pose := 0
	var shift := Vector2.ZERO
	var squash := Vector2.ONE
	if archetype == "proper_blimp":
		pose = 1 if row == 2 else 2 if row == 5 else 3 if row == 4 else 0
		shift.y = sin(phase*TAU)*3 if row < 2 else 0
		if row == 3: shift.x = -sin(phase*PI)*5
	else:
		if row == 1:
			pose = 1 if phase < 0.5 else 2
			shift.y = -absf(sin(phase*TAU))*5
		elif row == 2:
			pose = 3 if phase < 0.3 else 4 if phase < 0.7 else 0
		elif row == 3: pose = 5
		elif row == 4: pose = 6 if phase < 0.35 else 7
		if row == 0: squash.y = 1.0+sin(phase*TAU)*0.008
	var region := regions[pose]
	var height := 266.0 if archetype != "proper_blimp" else 260.0
	if row == 4 and archetype != "proper_blimp": height = 170 if pose == 6 else 115
	var factor := minf(height/region.size.y,340.0/region.size.x)
	var size := region.size*factor
	draw_set_transform(Vector2(192,330)+shift,0,squash)
	var outline := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	# The generated pose boundaries are irregular: exclude neighboring weapon fragments.
	if archetype == "poorper" and pose == 4:
		outline = PackedVector2Array([Vector2(0,0),Vector2(0.77,0),Vector2(0.77,0.42),Vector2(1,0.58),Vector2(1,1),Vector2(0,1)])
	elif archetype == "poorper" and pose == 5:
		outline = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0.12,1),Vector2(0.12,0.55),Vector2(0,0.45)])
	elif archetype == "poorper" and pose == 7:
		outline = PackedVector2Array([Vector2(0,0.3),Vector2(0.4,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	elif archetype == "steel_knight" and pose == 4:
		outline = PackedVector2Array([Vector2(0,0),Vector2(0.91,0),Vector2(0.91,0.65),Vector2(1,0.8),Vector2(1,1),Vector2(0,1)])
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in outline:
		points.append(Vector2(-size.x/2,-size.y)+p*size)
		uv.append((region.position+p*region.size)/source.get_size())
	draw_polygon(points,PackedColorArray([Color.WHITE]),uv,source)
	draw_set_transform(Vector2.ZERO)
