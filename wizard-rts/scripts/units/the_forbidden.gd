extends RTSUnit

# Tier 4 of the KoN roster doc: "The forbidden, only in great peril would Kon
# consider unleashing this. Cast at great cost, this tier 4 unit will not obey
# Kon and will turn it's wrath on all."
#
# The "will not obey" part is the whole design, so it is enforced structurally
# rather than by an AI rule that could be forgotten: the unit is spawned under
# BuildSystem.FORBIDDEN_OWNER_ID (0), an owner slot no faction uses. Every
# existing hostility check in the codebase is a plain
# `owner_player_id != my_owner_player_id` comparison, so a unit owned by nobody
# is automatically an enemy of the player who paid for it, of the Deom Legion,
# and of anything added later -- with no special-casing anywhere.
#
# It is also not selectable: SelectionController._is_player_selectable() only
# accepts owner 1, so the player physically cannot give it an order.

func _ready() -> void:
	unit_archetype = &"the_forbidden"
	super()
	move_speed = 132.0
	selection_radius = 38.0
	collision_separation = 34.0
	# Permanently aggressive. Without a standing attack-move it would acquire
	# targets but never walk to them (idle units do not chase).
	command_mode = &"attack_move"
	unit_state = &"attack_move"

# Sent by BuildSystem right after it is unleashed, so it starts by marching on
# whoever released it rather than standing in the spawn clearing.
func rampage_toward(world_position: Vector2) -> void:
	issue_attack_move_order(world_position)

func _draw() -> void:
	if use_mass_vector_lod():
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	_draw_body()
	_draw_unit_transform_end()
	_draw_selection_and_path()

func _draw_body() -> void:
	# Deliberately off-palette from both KoN themes: the Forbidden is the thing
	# the observers sealed away, not something Kon built. Bone-white plates over
	# a bruised void, with the sealed-away red bleeding through the seams.
	var shell := Color("#B9B2A6")
	var void_flesh := Color("#17131C")
	var seal_red := Color("#A9333F")
	draw_circle(Vector2(0, 16), 30, Color(0, 0, 0, 0.38))
	# Bulk.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, -6), Vector2(-14, -28), Vector2(14, -28), Vector2(26, -6),
		Vector2(20, 22), Vector2(-20, 22),
	]), void_flesh)
	# Carapace plates.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -8), Vector2(-11, -26), Vector2(11, -26), Vector2(22, -8), Vector2(0, 2),
	]), shell)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 4), Vector2(17, 4), Vector2(13, 19), Vector2(-13, 19),
	]), shell.darkened(0.18))
	# Seams of the broken seal.
	draw_line(Vector2(-18, -6), Vector2(18, -6), seal_red, 2.4)
	draw_line(Vector2(0, -26), Vector2(0, 2), seal_red, 1.8)
	# Too many eyes.
	for offset in [Vector2(-9, -16), Vector2(0, -19), Vector2(9, -16), Vector2(-5, -10), Vector2(5, -10)]:
		draw_circle(offset, 2.6, seal_red)
	# Limbs.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 20, -2), Vector2(side * 34, 14), shell.darkened(0.3), 3.2)
		draw_line(Vector2(side * 34, 14), Vector2(side * 30, 26), shell.darkened(0.3), 2.6)
