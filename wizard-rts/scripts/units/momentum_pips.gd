class_name MomentumPips
extends RefCounted

# The row of stack pips over a unit that builds momentum.
#
# The Mangler had this and the Mounted Knight did not, despite running the same
# mechanic -- run to build stacks, hit the cap, the weapon changes. A mechanic
# the player cannot see is a mechanic the player cannot use, and the Knight's is
# the more important of the two: five stacks kindle its axe for twelve seconds.
#
# WHY THIS IS SHARED RATHER THAN COPIED. The obvious fix was to paste the
# Mangler's pip code into the Knight's art script. Two copies of a display rule
# drift, and these two units already disagree about the thing the rule depends
# on: the Mangler assumes five stacks, the Knight reads momentum_max_stacks from
# its catalog entry. A copy would have baked the Mangler's five into a unit that
# does not own that number. So the maximum is a parameter and there is one
# implementation.
#
# It draws into a generated image rather than an authored texture because the
# pip count changes at runtime and the strip is a dozen rectangles; an atlas
# would need a frame per count per colour and a pipeline trip to change a shade.

const PIP_PITCH := 13
const PIP_WIDTH := 11
const PIP_HEIGHT := 10
const INNER_INSET := Vector2i(2, 2)
const INNER_SIZE := Vector2i(7, 6)

const COLOR_BACKING := Color("101d22")
const COLOR_EMPTY := Color("344751")
const COLOR_FILLED := Color("7ce8e3")
# At the cap the mechanic has fired -- the axe is lit, the charge is armed. It
# reads as a different state, not a fuller version of the same one.
const COLOR_CHARGED := Color("ed667a")

var _canvas: Sprite2D
var _billboard: Sprite3D
var _count := -1
var _max := 0

# `art` is the unit's Sprite2D. The strip is counter-scaled against it so a big
# unit does not get big pips: the Knight's art is drawn at 1.4 and the Mangler's
# at 0.72, and without this the same five pips would be twice the size over one
# of them.
func attach(art: Sprite2D, local_y: float) -> void:
	_canvas = Sprite2D.new()
	_canvas.position = Vector2(0.0, local_y)
	if art.scale.x != 0.0 and art.scale.y != 0.0:
		_canvas.scale = Vector2(1.0 / art.scale.x, 1.0 / art.scale.y)
	art.add_child(_canvas)
	var view := art.get_parent().get_parent().get_node_or_null("Map3DView") if art.get_parent() != null else null
	if is_instance_valid(view):
		_billboard = Sprite3D.new()
		_billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_billboard.pixel_size = 0.012
		view.add_child(_billboard)

# Called every frame by the art script. `lift` is how far above the unit the 3D
# billboard sits, in world units.
func update(unit: Node, stacks: int, max_stacks: int, lift: float) -> void:
	if _canvas == null or not is_instance_valid(_canvas):
		return
	max_stacks = maxi(1, max_stacks)
	if stacks != _count or max_stacks != _max:
		_count = stacks
		_max = max_stacks
		var texture := _render(stacks, max_stacks)
		_canvas.texture = texture
		if is_instance_valid(_billboard):
			_billboard.texture = texture
	# Shown while it matters: any stacks at all, or whenever the unit is picked.
	var shown: bool = bool(unit.get("selected")) or _count > 0
	_canvas.visible = shown
	if not is_instance_valid(_billboard):
		return
	var view := _billboard.get_parent()
	if not is_instance_valid(view) or not view.has_method("_unit_transform"):
		return
	_billboard.global_transform = view.call("_unit_transform", unit, lift)
	# Fog and banishment hide the unit; its pips must go with it, or a hidden
	# unit is given away by a row of lights floating over empty ground.
	var fog: Node = view.get("fog_of_war")
	var hidden: bool = unit.has_method("is_banished") and bool(unit.call("is_banished"))
	var in_fog: bool = fog != null and is_instance_valid(fog) \
		and fog.has_method("is_world_position_visible") \
		and not bool(fog.call("is_world_position_visible", (unit as Node2D).global_position))
	_billboard.visible = shown and not hidden and not in_fog

# For tests: the strip as it currently stands, so an assertion can count lit
# pips rather than trust that a texture exists.
func texture() -> Texture2D:
	return _canvas.texture if is_instance_valid(_canvas) else null

func release() -> void:
	if is_instance_valid(_billboard):
		_billboard.queue_free()

func _render(stacks: int, max_stacks: int) -> ImageTexture:
	var image := Image.create(PIP_PITCH * max_stacks, PIP_HEIGHT, false, Image.FORMAT_RGBA8)
	var lit := COLOR_CHARGED if stacks >= max_stacks else COLOR_FILLED
	for i in max_stacks:
		image.fill_rect(Rect2i(i * PIP_PITCH, 0, PIP_WIDTH, PIP_HEIGHT), COLOR_BACKING)
		image.fill_rect(Rect2i(Vector2i(i * PIP_PITCH, 0) + INNER_INSET, INNER_SIZE),
			lit if i < stacks else COLOR_EMPTY)
	return ImageTexture.create_from_image(image)
