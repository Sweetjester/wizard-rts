extends Node2D

const ACTIONS := ["idle", "run", "attack", "hit", "windup", "leap", "land", "evolve", "death"]
var evolved := false
var row := 0
var phase := 0.0
var _poses: Array[Texture2D] = []

# The painter's sheet is not a uniform grid. These authored regions keep each
# complete silhouette and exclude fragments from neighboring poses.
const REGIONS := [
	Rect2i(12,0,299,310), Rect2i(330,25,309,283), Rect2i(650,30,290,280), Rect2i(965,0,289,310),
	Rect2i(0,316,329,295), Rect2i(345,307,300,305), Rect2i(666,330,269,281), Rect2i(940,420,314,191),
	Rect2i(0,614,320,301), Rect2i(321,614,323,300), Rect2i(646,610,305,305), Rect2i(952,610,302,305),
	Rect2i(0,920,351,334), Rect2i(352,916,286,338), Rect2i(639,915,301,300), Rect2i(942,1020,312,234),
]

func _ready() -> void:
	var source := Image.load_from_file("res://assets_game/units/kon/mangler/painted_v1/source.png")
	for i in 16:
		var cell := source.get_region(REGIONS[i])
		_poses.append(ImageTexture.create_from_image(cell.get_region(cell.get_used_rect())))

func _draw() -> void:
	if _poses.is_empty(): return
	var base := 8 if evolved else 0
	var pose := base
	var squash := Vector2.ONE
	var lean := 0.0
	var shift := Vector2.ZERO
	var height := 266.0
	match row:
		0: squash = Vector2(1.0 + sin(phase*TAU)*0.01, 1.0 - sin(phase*TAU)*0.012)
		1:
			pose = base + (1 if phase < 0.5 else 2)
			shift.y = -absf(sin(phase*TAU))*10.0
			height = 240.0
		2:
			pose = base + (3 if phase < 0.34 else 4 if phase < 0.75 else 0)
			shift.x = sin(phase*PI)*16.0
		3:
			pose = 13 if evolved else 6
			lean = sin(phase*PI)*-0.08
			height = 235.0
		4:
			pose = 13 if evolved else 6
			squash.y = 1.0-phase*0.12
			height = 235.0
		5:
			pose = 14 if evolved else 3
			height = 258.0
		6:
			pose = 13 if evolved else 6
			squash = Vector2(1.12-phase*0.12, 0.82+phase*0.18)
		7:
			pose = base
			squash = Vector2.ONE*(0.94+phase*0.06)
		8:
			pose = (13 if evolved else 6) if phase < 0.28 else (15 if evolved else 7)
			height = 235.0 if phase < 0.28 else 125.0
	var tex := _poses[pose]
	var size := Vector2(tex.get_size()) * minf(height / tex.get_height(), 340.0 / tex.get_width())
	draw_set_transform(Vector2(192,330)+shift, lean, squash)
	# A few silhouettes interleave at the atlas corners. Authored UV outlines
	# exclude those neighbors while retaining the complete main silhouette.
	var outline := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	if pose == 10:
		outline = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0.04,1),Vector2(0.04,0.60),Vector2(0,0.60)])
	elif pose == 12:
		outline = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,0.9),Vector2(0.94,0.9),Vector2(0.94,1),Vector2(0,1)])
	elif pose == 14:
		outline = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,0.8),Vector2(0.8,0.8),Vector2(0.8,1),Vector2(0.08,1),Vector2(0.08,0.85),Vector2(0,0.85)])
	var vertices := PackedVector2Array()
	for uv in outline: vertices.append(Vector2(-size.x*0.5,-size.y)+uv*size)
	draw_polygon(vertices,PackedColorArray([Color.WHITE]),outline,tex)
	draw_set_transform(Vector2.ZERO)
