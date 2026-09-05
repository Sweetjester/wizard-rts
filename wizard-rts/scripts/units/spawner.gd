extends RTSUnit

func _ready() -> void:
	unit_archetype = &"spawner"
	super()
	move_speed = 92.0
	selection_radius = 30.0
	collision_separation = 34.0

func _fire_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	super(target,damage_multiplier)
	var art:=get_node_or_null("ArtSprite")
	if art!=null and art.has_method("play_shot"): art.play_shot()

func _spawn_drone(archetype: StringName, target: Node2D) -> void:
	var previous:=_drone_children.size()
	super(archetype,target)
	var art:=get_node_or_null("ArtSprite")
	if _drone_children.size()>previous and art!=null and art.has_method("play_summon"):
		art.play_summon()

func _spawn_death_fx(source: Node = null) -> void:
	var art:=get_node_or_null("ArtSprite") as Sprite2D
	if art==null or art.texture==null:
		super(source)
		return
	var view:=get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(view) and view.has_method("spawn_painted_unit_death"):
		view.call("spawn_painted_unit_death",self,art)
		return
	var corpse:=preload("res://scripts/fx/painted_unit_death.gd").new()
	get_parent().add_child(corpse)
	corpse.configure(self,art)

# Redrawn 2026-08-31 against the KoN roster doc's concept art: a heavy
# bone-plated insect body over a dark rose underbelly, six thin legs, and the
# large translucent wings that separate the Spawner from its evolved Winged
# form. Rooted, uprooting and takeoff/landing states all keep their existing
# readable tells -- this is a silhouette pass, not a behaviour change.
func _draw() -> void:
	if has_node("ArtSprite") and not use_mass_vector_lod():
		_draw_selection_and_path()
		return
	_draw_unit_transform_begin()
	var flying := unit_archetype == &"winged_spawner"
	var rooted := unit_state in [&"rooted", &"rooting", &"uprooting"]
	var flight_cast := unit_state in [&"takeoff", &"landing"]
	var shell := team_primary_color().lightened(0.34)
	var underbelly := team_accent_color().darkened(0.24)
	var accent := team_accent_color()
	var lift := -10.0 if flying and not flight_cast else 0.0
	if flight_cast:
		lift = -6.0 if unit_state == &"takeoff" else -3.0
	var o := Vector2(0, lift)

	draw_circle(Vector2(0, 18), 27, Color(0, 0, 0, 0.34))
	_draw_spawner_legs(o, shell, rooted)
	if flying or flight_cast:
		_draw_spawner_wings(o, team_primary_color(), true)
	# Abdomen (rose, heavy) then thorax and head (bone plates) over it.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, 2) + o, Vector2(-14, -12) + o, Vector2(6, -10) + o,
		Vector2(12, 6) + o, Vector2(0, 20) + o, Vector2(-20, 16) + o,
	]), underbelly)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -2) + o, Vector2(-12, -15) + o, Vector2(4, -14) + o,
		Vector2(8, -1) + o, Vector2(-4, 6) + o, Vector2(-18, 5) + o,
	]), shell)
	if not flying and not flight_cast:
		_draw_spawner_wings(o, team_primary_color(), false)
	# Head.
	draw_circle(Vector2(15, -8) + o, 10.0, shell)
	draw_circle(Vector2(15, -8) + o, 7.6, shell.lightened(0.12))
	draw_circle(Vector2(19, -10) + o, 3.4, accent)
	draw_circle(Vector2(20, -11) + o, 1.3, accent.lightened(0.5))
	# Antennae.
	draw_line(Vector2(19, -15) + o, Vector2(33, -26) + o, shell.darkened(0.25), 1.6)
	draw_line(Vector2(17, -16) + o, Vector2(26, -30) + o, shell.darkened(0.25), 1.4)
	# Plate seams across the thorax.
	for i in range(3):
		var x := -18.0 + float(i) * 7.0
		draw_line(Vector2(x, -13) + o, Vector2(x + 3, 4) + o, underbelly, 1.4)

	if rooted:
		var cast_color := Color("#D6C7AE") if unit_state in [&"rooting", &"uprooting"] else team_primary_color()
		draw_arc(Vector2(0, 4) + o, 30.0, 0.0, TAU, 32, Color(cast_color.r, cast_color.g, cast_color.b, 0.9), 3.0)
		# The rooted artillery barrel.
		draw_line(Vector2(-4, -12) + o, Vector2(-6, -44) + o, shell.darkened(0.2), 7.0)
		draw_circle(Vector2(-6, -47) + o, 8.0, accent)
		draw_circle(Vector2(-6, -47) + o, 4.0, accent.lightened(0.4))
	elif flight_cast:
		var cast_color := Color("#7DDDE8") if unit_state == &"takeoff" else Color("#D6C7AE")
		draw_arc(Vector2(0, 6) + o, 32.0, 0.0, TAU, 36, Color(cast_color.r, cast_color.g, cast_color.b, 0.82), 3.0)
	_draw_unit_transform_end()
	_draw_selection_and_path()

func _draw_spawner_legs(o: Vector2, shell: Color, rooted: bool) -> void:
	var leg := shell.darkened(0.34)
	var splay := 1.0 if not rooted else 1.25
	for entry in [[-18.0, 4.0, -34.0], [-6.0, 6.0, -22.0], [8.0, 5.0, 26.0]]:
		for side in [-1.0, 1.0]:
			var hip := Vector2(float(entry[0]), float(entry[1])) + o
			var knee := hip + Vector2(side * 12.0 * splay, -6.0)
			var foot := knee + Vector2(side * 9.0 * splay, 22.0)
			draw_line(hip, knee, leg, 3.0)
			draw_line(knee, foot, leg, 2.4)

func _draw_spawner_wings(o: Vector2, plate: Color, spread: bool) -> void:
	var wing := Color(plate.r, plate.g, plate.b, 0.36 if spread else 0.26)
	var vein := Color(plate.r, plate.g, plate.b, 0.7)
	var reach := 40.0 if spread else 28.0
	for side in [-1.0, 1.0]:
		var root := Vector2(-6, -12) + o
		var tip := root + Vector2(-reach * 0.5, -reach * 0.55 * side - 6.0)
		var back := root + Vector2(-reach, -4.0 * side)
		draw_colored_polygon(PackedVector2Array([root, tip, back]), wing)
		draw_line(root, tip, vein, 1.3)
		draw_line(root, back, vein, 1.1)
