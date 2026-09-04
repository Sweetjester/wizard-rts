extends Node3D

# Runnable viewer for the authored block structures (experimental).
#
# Standalone on purpose -- it touches nothing in the shipping game. Run it with:
#   Godot --path . scenes/blocks/block_structure_test.tscn
#
# Controls
#   Tab / Shift+Tab   cycle structure
#   C                 cycle unit class (infantry, archer, climber, heavy, siege, flying)
#   G                 toggle every gate
#   1 2 3 4           toggle nav cells / links / sockets / solid blocks
#   drag / wheel      orbit and zoom
#
# The view that matters is the nav-cell colouring: GREEN reachable by the
# current class, YELLOW standable but unreachable, GREY not standable, and gates
# in blue when open, red when shut. Yellow is the interesting one -- it is what
# a wall-walk looks like to a heavy unit that cannot climb stairs.

const CLASSES: Array[StringName] = [&"infantry", &"archer", &"climber", &"heavy", &"siege", &"flying"]

@export var start_structure: StringName = &"fortress_gatehouse_02_walkable"

var library: BlockStructureLibrary
var definition: BlockStructureDefinition
var navigation: BlockStructureNavigation

var _builder: BlockStructureBuilder
var _debug: BlockStructureDebugDraw
var _camera: Camera3D
var _pivot: Node3D
var _legend: Label

var _structure_index := 0
var _class_index := 0
var _orbit := Vector2(-0.62, 0.7)
var _distance := 28.0
var _dragging := false

func _ready() -> void:
	library = BlockStructureLibrary.load_default()
	var ids := library.structure_ids()
	if ids.is_empty():
		push_error("No block structures loaded -- run tools/blocks/convert_structures.py")
		return
	_structure_index = maxi(0, ids.find(start_structure))
	_build_world()
	_load_structure(ids[_structure_index])

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#12141A")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#5A6070")
	env.ambient_light_energy = 0.9
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 600.0
	_pivot.add_child(_camera)

	_builder = BlockStructureBuilder.new()
	add_child(_builder)
	_debug = BlockStructureDebugDraw.new()
	add_child(_debug)

	var layer := CanvasLayer.new()
	add_child(layer)
	_legend = Label.new()
	_legend.position = Vector2(16, 12)
	_legend.add_theme_color_override("font_color", Color("#E2E8F0"))
	_legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_legend.add_theme_constant_override("outline_size", 5)
	layer.add_child(_legend)

func _load_structure(structure_id: StringName) -> void:
	definition = library.get_definition(structure_id)
	navigation = library.navigation_for(structure_id)
	if definition == null or navigation == null:
		return
	# Gates start OPEN in the viewer so a structure reads as connected on first
	# look. The navigation layer itself defaults them closed, which is the safer
	# default for the game and is asserted in the smoke test.
	navigation.gate_states = {"gate_open": true}
	_builder.build(definition)
	_debug.setup(definition, navigation)
	_debug.set_unit_class(CLASSES[_class_index])
	# Frame the structure rather than assuming a distance: the pack ranges from a
	# 10x6x10 watchfort to a 20x5x6 bridge.
	var size := Vector3(definition.dimensions)
	_pivot.position = size * 0.5
	_distance = maxf(14.0, size.length() * 1.35)
	_apply_camera()
	_refresh_legend()

func _apply_camera() -> void:
	var pitch := clampf(_orbit.x, -1.45, -0.05)
	var yaw := _orbit.y
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		-sin(pitch),
		cos(pitch) * cos(yaw)) * _distance
	_camera.position = offset
	_camera.look_at_from_position(_pivot.global_position + offset, _pivot.global_position, Vector3.UP)
	_camera.position = _camera.global_position - _pivot.global_position

func _refresh_legend() -> void:
	var unit_class := CLASSES[_class_index]
	var reachable := 0
	var stranded := 0
	for cell in definition.nav_cells:
		if navigation.can_occupy(cell, unit_class):
			stranded += 1
	var entry: Variant = _debug._entry_cell()
	if entry != null:
		reachable = navigation.reachable_from(entry, unit_class).size()
	var gate_open := bool(navigation.gate_states.get("gate_open", false))
	var lines := [
		"%s   (%s)" % [definition.display_name, definition.id],
		"dims %s   solid %d   nav %d   links %d   sockets %d" % [
			definition.dimensions, definition.solid_cells.size(),
			definition.nav_cells.size(), definition.links.size(), definition.sockets.size()],
		"",
		"class: %s      gates: %s" % [unit_class, "OPEN" if gate_open else "SHUT"],
		"reachable %d of %d standable cells" % [reachable, stranded],
		"",
		"green reachable   yellow standable-but-cut-off   grey no",
		"Tab structure   C class   G gates   1-4 layers   drag/wheel camera",
	]
	_legend.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(6.0, _distance - 2.5)
			_apply_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(220.0, _distance + 2.5)
			_apply_camera()
	elif event is InputEventMouseMotion and _dragging:
		_orbit.y -= event.relative.x * 0.006
		_orbit.x -= event.relative.y * 0.005
		_apply_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)

func _handle_key(event: InputEventKey) -> void:
	var ids := library.structure_ids()
	match event.keycode:
		KEY_TAB:
			var step := -1 if event.shift_pressed else 1
			_structure_index = wrapi(_structure_index + step, 0, ids.size())
			_load_structure(ids[_structure_index])
		KEY_C:
			_class_index = wrapi(_class_index + 1, 0, CLASSES.size())
			_debug.set_unit_class(CLASSES[_class_index])
			_refresh_legend()
		KEY_G:
			var open := not bool(navigation.gate_states.get("gate_open", false))
			navigation.gate_states = {"gate_open": open}
			_debug.refresh()
			_refresh_legend()
		KEY_1:
			_debug.set_layer_visible(BlockStructureDebugDraw.Layer.NAV,
				not _debug.layer_visible(BlockStructureDebugDraw.Layer.NAV))
		KEY_2:
			_debug.set_layer_visible(BlockStructureDebugDraw.Layer.LINKS,
				not _debug.layer_visible(BlockStructureDebugDraw.Layer.LINKS))
		KEY_3:
			_debug.set_layer_visible(BlockStructureDebugDraw.Layer.SOCKETS,
				not _debug.layer_visible(BlockStructureDebugDraw.Layer.SOCKETS))
		KEY_4:
			_toggle_blocks()
		_:
			return

# Hiding the blocks is the most useful toggle of the four: with the stone gone
# you can see the nav cells and links that are otherwise buried inside it.
var _blocks_shown := true

func _toggle_blocks() -> void:
	_blocks_shown = not _blocks_shown
	_builder.set_blocks_visible(_blocks_shown)
