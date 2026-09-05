extends RTSUnit

func _ready() -> void:
	unit_archetype = &"oaven_spear"
	super()
	move_speed = 166.0
	selection_radius = 18.0
	collision_separation = 19.0

func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var evolved := unit_archetype == &"oaven_jumper"
	var flying := evolved and _flight_state == &"flying"
	var body := Color("#214F58") if not evolved else Color("#2C6772")
	var cloth := Color("#8B3F4B")
	var dark := Color("#132327")
	var glow := Color("#55F2F2")
	var lift := -12.0 if flying else 0.0
	var offset := Vector2(0, lift)
	draw_circle(Vector2(0, 13), 15 if not evolved else 18, Color(0, 0, 0, 0.32))
	_draw_limb(Vector2(-9, 7) + offset, Vector2(-22, 20), body.darkened(0.2), 4.0)
	_draw_limb(Vector2(9, 7) + offset, Vector2(22, 20), body.darkened(0.2), 4.0)
	_draw_limb(Vector2(-7, 19) + offset, Vector2(-16, 31), dark, 4.0)
	_draw_limb(Vector2(7, 19) + offset, Vector2(18, 31), dark, 4.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 0) + offset,
		Vector2(10, -2) + offset,
		Vector2(14, 21) + offset,
		Vector2(-10, 23) + offset,
	]), body.darkened(0.08))
	draw_circle(Vector2(0, -14) + offset, 15 if not evolved else 17, body)
	draw_circle(Vector2(-7, -17) + offset, 5.0, glow)
	draw_circle(Vector2(7, -17) + offset, 5.0, glow)
	draw_arc(Vector2(0, -15) + offset, 18.0, 3.25, TAU - 0.1, 24, dark.darkened(0.25), 4.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -2) + offset,
		Vector2(15, -1) + offset,
		Vector2(18, 8) + offset,
		Vector2(-17, 9) + offset,
	]), cloth)
	_draw_spear(offset, glow)
	if evolved:
		_draw_wings(offset, glow, flying)
	if Time.get_ticks_msec() < _taunt_until_msec:
		draw_arc(Vector2(0, 1) + offset, 27.0, 0.0, TAU, 36, Color("#E85A5A", 0.9), 3.0)
	_draw_unit_transform_end()
	_draw_selection_and_path()

func _spawn_death_fx(source: Node = null) -> void:
	var art:=get_node_or_null("ArtSprite") as Sprite2D
	if art==null or art.texture==null:
		super(source)
		return
	var view:=get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and view.has_method("spawn_painted_unit_death"):
		view.call("spawn_painted_unit_death",self,art)
		return
	var corpse:=preload("res://scripts/fx/oaven_death_sprite.gd").new()
	get_parent().add_child(corpse)
	corpse.configure(self,art)

func _draw_limb(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width)
	draw_circle(b, width * 0.85, color.lightened(0.08))

func _draw_spear(offset: Vector2, glow: Color) -> void:
	var base := Vector2(19, 23) + offset
	var tip := Vector2(34, -35) + offset
	draw_line(base, tip, Color("#2B1D1A"), 4.0)
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip + Vector2(-5, 13),
		tip + Vector2(5, 11),
	]), glow)
	draw_circle(base, 4.0, Color("#8B3F4B"))

func _draw_wings(offset: Vector2, glow: Color, flying: bool) -> void:
	var alpha := 0.82 if flying else 0.45
	var left := PackedVector2Array([
		Vector2(-8, -8) + offset,
		Vector2(-38, -34) + offset,
		Vector2(-26, -5) + offset,
	])
	var right := PackedVector2Array([
		Vector2(8, -8) + offset,
		Vector2(38, -34) + offset,
		Vector2(26, -5) + offset,
	])
	draw_colored_polygon(left, Color(glow.r, glow.g, glow.b, alpha * 0.35))
	draw_colored_polygon(right, Color(glow.r, glow.g, glow.b, alpha * 0.35))
	draw_polyline(PackedVector2Array([left[0], left[1], left[2], left[0]]), Color(glow.r, glow.g, glow.b, alpha), 2.0)
	draw_polyline(PackedVector2Array([right[0], right[1], right[2], right[0]]), Color(glow.r, glow.g, glow.b, alpha), 2.0)
