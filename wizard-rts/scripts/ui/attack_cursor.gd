class_name AttackCursor
extends RefCounted

# The sword the mouse turns into over something you can attack.
#
# WHY A REAL MOUSE CURSOR rather than a sprite drawn at the mouse position:
# a drawn cursor is always one frame behind the pointer, which is invisible when
# the mouse is still and very obvious when it is moving -- exactly when the
# player is sweeping across a fight looking for a target. Input.set_custom_mouse_cursor
# hands the image to the OS, so it tracks perfectly and costs nothing per frame.
# It also works in both presentations, where a drawn one would need the 3D
# overlay and would simply not exist in the 2D view.
#
# WHY IT IS DRAWN IN CODE: this is UI furniture, not art. A 28px cursor authored
# as a PNG would need a source file, an import, a scale decision for every
# display, and a trip through the asset pipeline to change its colour. Drawn
# here it is a dozen lines, it is generated once at startup, and the shape and
# palette are readable and editable in the same place.
#
# The palette is the game's own: pale stone for the blade, brass for the hilt,
# and the same near-black outline the HUD uses, because the map is dark and a
# cursor with no outline disappears over the Observer Vault's glass.

const SIZE := 28
const OUTLINE := Color("#0A1612")
const BLADE := Color("#CBD6DA")
const EDGE := Color("#EAF2F4")
const HILT := Color("#C08A3E")
const GRIP := Color("#4A3626")

# The tip, in pixels. The sword points up-left and aims from its point, the same
# way the ordinary arrow cursor does -- a cursor whose hotspot is not where it
# visibly points makes every click feel slightly wrong.
const HOTSPOT := Vector2(2, 2)

static var _texture: ImageTexture
static var _active := false

# Swaps the pointer for the sword, or puts it back. Idempotent: called every
# frame while the mouse sits over an enemy, and does nothing after the first.
static func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	if not active:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return
	if _texture == null:
		_texture = _build()
	Input.set_custom_mouse_cursor(_texture, Input.CURSOR_ARROW, HOTSPOT)

static func is_active() -> bool:
	return _active

# Exposed so a test can look at the pixels rather than trusting that a texture
# with the right dimensions is a sword.
static func texture() -> ImageTexture:
	if _texture == null:
		_texture = _build()
	return _texture

# --- drawing ----------------------------------------------------------------

static func _build() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Point at the top-left, hilt toward the bottom-right, on the diagonal.
	var tip := Vector2(2.5, 2.5)
	var guard_centre := Vector2(18.0, 18.0)
	var pommel := Vector2(24.0, 24.0)

	# Outline first, as a fatter version of every stroke. Drawing it as a pass
	# rather than tracing an edge means the outline cannot come apart where two
	# strokes meet.
	_line(image, tip, pommel, OUTLINE, 5.0)
	_line(image, guard_centre + Vector2(6, -6), guard_centre + Vector2(-6, 6), OUTLINE, 5.0)

	# Blade, then a lit edge along its upper-left side.
	_line(image, tip, guard_centre, BLADE, 3.0)
	_line(image, tip + Vector2(-0.6, -0.6), guard_centre + Vector2(-0.6, -0.6), EDGE, 1.0)

	# Crossguard and grip.
	_line(image, guard_centre + Vector2(5, -5), guard_centre + Vector2(-5, 5), HILT, 3.0)
	_line(image, guard_centre + Vector2(1.5, 1.5), pommel - Vector2(1.5, 1.5), GRIP, 3.0)
	_dot(image, pommel - Vector2(1.0, 1.0), HILT, 2.0)

	return ImageTexture.create_from_image(image)

static func _line(image: Image, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var steps := int(ceil(from.distance_to(to) * 2.0))
	for i in steps + 1:
		_dot(image, from.lerp(to, float(i) / float(maxi(steps, 1))), color, width * 0.5)

static func _dot(image: Image, at: Vector2, color: Color, radius: float) -> void:
	var min_x := maxi(0, int(floor(at.x - radius)))
	var max_x := mini(SIZE - 1, int(ceil(at.x + radius)))
	var min_y := maxi(0, int(floor(at.y - radius)))
	var max_y := mini(SIZE - 1, int(ceil(at.y + radius)))
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(at) <= radius:
				image.set_pixel(x, y, color)
