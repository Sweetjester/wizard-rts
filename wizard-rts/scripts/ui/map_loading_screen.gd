class_name MapLoadingScreen
extends CanvasLayer

# The wait, made into something worth watching.
#
# Map generation takes seconds -- 3.6s at 96x96, 8.6s on the 160x160 frontier --
# and it used to spend all of that inside one blocking add_child(), which froze
# the map select screen solid until Windows offered to kill the process. It is
# now spread across frames, which fixes the freeze but leaves a real wait.
#
# Rather than put a spinner over it, this draws the map AS IT IS BEING MADE.
# Every phase the generator finishes is painted into a live top-down preview:
# the ground rises, plateaus get cut, roads are laid, plots are surveyed, and
# the citadel appears last. It costs almost nothing -- one 160x160 image per
# phase, twelve times -- and it turns dead time into the most informative screen
# in the game. You can see the seed you rolled before you commit to playing it.
#
# It is also, incidentally, the best map debugging view we have: a bad
# generation is obvious here in a way it never is once props are on top.

const PHASE_FLAVOUR := {
	"Reading the seed": "Every world begins as a number.",
	"Loading tiles": "Fetching the stuff of the world.",
	"Raising the ground": "Something has to stand on something.",
	"Surveying plots": "Deciding where things are allowed to happen.",
	"Deciding elevations": "High ground is the oldest advantage.",
	"Cutting plateaus": "The land is made to disagree with itself.",
	"Stamping plots": "Pressing intent into the dirt.",
	"Smoothing high ground": "Removing the cliffs nobody could use.",
	"Placing landmarks": "A world needs things worth walking to.",
	"Laying roads": "Roads are arguments about where you will go.",
	"Checking elevation": "Measuring what was promised against what was built.",
	"Checking landmarks": "Confirming the landmarks can be reached.",
	"Checking structures": "Making sure the doors lead somewhere.",
	"Measuring heights": "Teaching the map how far it is to fall.",
	"Building navigation": "Explaining the world to everything that walks.",
	"Painting terrain": "Putting the skin on.",
	"Registering zones": "Naming the parts.",
	"Ready": "Go and take it.",
}

# Terrain reads as weathered blue-green; roads warm against it so the network is
# legible at a glance, which is the single most useful thing to see going wrong.
const COLOUR_UNBUILT := Color("#0B0F14")
const COLOUR_WATER := Color("#12303F")
const COLOUR_BLOCKED := Color("#0E1519")
const COLOUR_BY_ELEVATION := [
	Color("#25402F"), # low
	Color("#33553D"), # mid
	Color("#456B4C"), # high
	Color("#7A8F5A"), # ramp
]
const COLOUR_ROAD := Color("#8A7340")
const COLOUR_PLOT := Color("#4FE3DC")
const COLOUR_BASE := Color("#E0C36A")
const COLOUR_CITADEL := Color("#66F0E8")

@export var map_generator_path: NodePath = NodePath("../MapGenerator")

var _generator: Node
var _root: Control
var _preview: TextureRect
var _phase_label: Label
var _flavour_label: Label
var _seed_label: Label
var _bar: ProgressBar
var _image: Image
var _texture: ImageTexture
var _finished := false

func _ready() -> void:
	layer = 200
	_generator = get_node_or_null(map_generator_path)
	_build_ui()
	if _generator == null:
		queue_free()
		return
	if _generator.has_signal("generation_progress"):
		_generator.generation_progress.connect(_on_progress)
	if _generator.has_signal("map_generated"):
		_generator.map_generated.connect(_on_generated)
	# Already finished (a small map can generate inside one frame): do not sit
	# on top of a playable game.
	if bool(_generator.get("generation_complete")):
		_finish()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color("#070A0E")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	_root.add_child(column)

	var title := Label.new()
	title.text = "Raising a world"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# The map itself, drawn as it is built. Nearest-neighbour so a cell is a
	# square rather than a smear -- this is a map, not a texture.
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(512, 512)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_preview)

	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 20)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_phase_label)

	_flavour_label = Label.new()
	_flavour_label.add_theme_font_size_override("font_size", 15)
	_flavour_label.add_theme_color_override("font_color", Color("#7F98A8"))
	_flavour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_flavour_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(512, 6)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	column.add_child(_bar)

	_seed_label = Label.new()
	_seed_label.add_theme_font_size_override("font_size", 13)
	_seed_label.add_theme_color_override("font_color", Color("#5C7180"))
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_seed_label)

func _on_progress(label: String, done: int, total: int) -> void:
	_phase_label.text = label
	_flavour_label.text = str(PHASE_FLAVOUR.get(label, ""))
	_bar.value = float(done) / float(maxi(total, 1))
	_seed_label.text = "%s   seed %s" % [
		str(_generator.call("get_map_type_name")) if _generator.has_method("get_map_type_name") else "",
		str(_generator.get("seed_value"))]
	_redraw_preview()

func _on_generated(_summary: Dictionary) -> void:
	_redraw_preview()
	_finish()

# One image per phase, built from whatever the generator has so far. Cells the
# generator has not reached yet stay dark, so the map visibly fills in.
func _redraw_preview() -> void:
	if _generator == null or not is_instance_valid(_generator):
		return
	var grid: Array = _generator.get("grid")
	if grid == null or grid.is_empty():
		return
	var width := int(_generator.get("MAP_W"))
	var height := int(_generator.get("MAP_H"))
	if width <= 0 or height <= 0:
		return
	if _image == null or _image.get_width() != width or _image.get_height() != height:
		_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
		_texture = ImageTexture.create_from_image(_image)
		_preview.texture = _texture

	# Bounded by what the generator has ACTUALLY built, not by MAP_W/MAP_H. The
	# whole point is to draw a half-finished map, and during _build_grid the
	# columns are still being appended -- reading to the declared size walks off
	# the end of the array.
	var built_columns: int = mini(width, grid.size())
	for x in built_columns:
		var column: Array = grid[x]
		var built_rows: int = mini(height, column.size())
		for y in built_rows:
			var value := int(column[y])
			var colour := COLOUR_UNBUILT
			if value == _generator.E_WATER:
				colour = COLOUR_WATER
			elif value == _generator.E_BLOCKED:
				colour = COLOUR_BLOCKED
			elif value >= 0 and value < COLOUR_BY_ELEVATION.size():
				colour = COLOUR_BY_ELEVATION[value]
			_image.set_pixel(x, y, colour)

	# Roads over terrain, because their shape is the map's skeleton.
	var roads: Dictionary = _generator.get("road_cells")
	if roads != null:
		for cell in roads.keys():
			_plot_pixel(cell.x, cell.y, COLOUR_ROAD, width, height)

	_outline_plots(width, height)
	_texture.update(_image)

# Plots are drawn as outlines rather than fills so the terrain under them stays
# readable -- and so a plot landing somewhere daft is immediately obvious.
func _outline_plots(width: int, height: int) -> void:
	for plot in _generator.get("plots"):
		var rect: Rect2i = plot.get("rect", Rect2i())
		if rect.size.x <= 0:
			continue
		var colour := COLOUR_PLOT
		if str(plot.get("block_structure", "")) != "":
			colour = COLOUR_CITADEL
		_draw_rect_outline(rect, colour, width, height)
	for plot in _generator.get("base_plots"):
		_draw_rect_outline(plot.get("rect", Rect2i()), COLOUR_BASE, width, height)

func _draw_rect_outline(rect: Rect2i, colour: Color, width: int, height: int) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		_plot_pixel(x, rect.position.y, colour, width, height)
		_plot_pixel(x, rect.position.y + rect.size.y - 1, colour, width, height)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		_plot_pixel(rect.position.x, y, colour, width, height)
		_plot_pixel(rect.position.x + rect.size.x - 1, y, colour, width, height)

func _plot_pixel(x: int, y: int, colour: Color, width: int, height: int) -> void:
	if x >= 0 and y >= 0 and x < width and y < height:
		_image.set_pixel(x, y, colour)

# A short hold on the finished map before handing over, so the world you are
# about to play is the last thing you saw rather than a flash.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	_phase_label.text = "Ready"
	_flavour_label.text = str(PHASE_FLAVOUR.get("Ready", ""))
	_bar.value = 1.0
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(_root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
