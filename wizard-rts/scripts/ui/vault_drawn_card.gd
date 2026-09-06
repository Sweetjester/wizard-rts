extends Button
const Style := preload("res://scripts/ui/observer_theme.gd")
const ART := preload("res://assets/ui/observer_vault/portraits_drawn_v2.png")
const STEEL_ART := preload("res://assets/ui/observer_vault/steel_portraits_drawn_v4.png")
const STEEL_CELLS := {&"poorper":0, &"steel_knight":1, &"proper_blimp":2, &"mounted_knight":3}
const CARD_SIZE := Vector2(280,440)
const CONCEPT_ART := preload("res://assets/ui/observer_vault/concept_portraits_v3.png")
const CONCEPT_CELLS := {&"oaven_spear":0, &"oaven_jumper":1, &"stone_face_serpent":2,
	&"spawner":3, &"winged_spawner":4, &"spawner_drone":5}
const VARIANT_ART := preload("res://assets/ui/observer_vault/variants_drawn_v2.png")
const VARIANTS := {&"oaven_jumper":0, &"winged_spawner":1, &"spawner_drone":2}
const CELLS := {&"life_wizard":0, &"oaven_spear":1, &"oaven_jumper":1, &"mangler":2,
	&"stone_face_serpent":3, &"spawner":4, &"winged_spawner":4, &"spawner_drone":4, &"winged_mangler":5}
const INK := Color("202a2c")
const STOCK := Color("b9c5b0")
var record: Dictionary
var portrait: Texture2D
var portrait_region := Rect2()
var home_position := Vector2.ZERO
var home_rotation := 0.0
var in_hand := false
var motion: Tween

func setup(data: Dictionary) -> void:
	record = data
	name = "Specimen_" + str(data.id)
	custom_minimum_size = CARD_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	focus_mode = Control.FOCUS_ALL
	tooltip_text = str(data.get("requirement", "")) if data.sealed else "Read " + str(data.name)
	if not data.sealed:
		if STEEL_CELLS.has(data.id):
			portrait = STEEL_ART
			var cell: int = STEEL_CELLS[data.id]
			var cell_size := STEEL_ART.get_size()/Vector2(2,2)
			portrait_region = Rect2(Vector2(cell%2,cell/2)*cell_size,cell_size)
		elif CONCEPT_CELLS.has(data.id):
			portrait = CONCEPT_ART
			var cell: int = CONCEPT_CELLS[data.id]
			var cell_size := CONCEPT_ART.get_size()/Vector2(3,2)
			portrait_region = Rect2(Vector2(cell%3,cell/3)*cell_size,cell_size)
		elif VARIANTS.has(data.id):
			portrait = VARIANT_ART
			var cell_size := VARIANT_ART.get_size()/Vector2(3,1)
			portrait_region = Rect2(Vector2(int(VARIANTS[data.id]),0)*cell_size,cell_size)
		elif CELLS.has(data.id):
			portrait = ART
			var cell: int = CELLS[data.id]
			var cell_size := ART.get_size()/Vector2(3,2)
			portrait_region = Rect2(Vector2(cell%3,cell/3)*cell_size,cell_size)
		else:
			var path := str(data.get("portrait", ""))
			if not path.is_empty() and ResourceLoader.exists(path):
				portrait = load(path)
				portrait_region = Rect2(portrait.get_image().get_used_rect())
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(func(): lift(true))
	mouse_exited.connect(func(): lift(false))
	focus_entered.connect(func(): lift(true))
	focus_exited.connect(func(): lift(false))
	_labels()

func arrange(at: Vector2, _angle: float = 0.0, animate: bool = false) -> void:
	in_hand = true
	home_position = at.round()
	home_rotation = 0.0
	if motion != null: motion.kill()
	position = home_position
	rotation = 0.0
	modulate.a = 1.0
	if animate:
		modulate.a = 0
		motion = create_tween()
		motion.tween_property(self,"modulate:a",1.0,.22)

func lift(_raised: bool) -> void:
	queue_redraw()

func show_measurements(stats: Dictionary, note: String) -> void:
	record = record.duplicate()
	record.stats = stats.duplicate()
	record.stat_labels = {}
	record["measurement_note"] = note
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_labels()
	queue_redraw()

func _label(text: String, area: Rect2, font_size: int, color: Color = INK, serif: bool = false) -> void:
	var l := Style.label(text,font_size,color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.max_lines_visible = 2
	if serif: l.add_theme_font_override("font",Style.display_font())
	l.position = area.position
	l.size = area.size
	add_child(l)

func _labels() -> void:
	if record.sealed:
		_label(["0","I","II","III","IV"][clampi(record.tier,0,4)],Rect2(30,150,220,60),42,STOCK,true)
		_label("UNOBSERVED",Rect2(30,270,220,32),14,STOCK)
		_label(str(record.get("requirement", "")),Rect2(26,312,228,86),14,STOCK)
		return
	_label(str(record.name),Rect2(18,12,244,32),20 if str(record.name).length()<21 else 17,INK,true)
	var affiliation := "STEEL FORCE" if STEEL_CELLS.has(record.id) else "KON"
	_label("OBSERVER" if record.tier==0 else "%s / TIER %d" % [affiliation,record.tier],Rect2(18,44,244,21),11)
	var caption := str(record.blurb)
	if caption.is_empty(): caption = str(record.role)
	if caption.length()>62: caption = caption.left(59).rsplit(" ",true,1)[0]+"..."
	_label(caption,Rect2(20,324,240,40),13)
	var notes := "Recorded form" if record.enemy else "%d in the field" % record.instances.size()
	if not record.enemy and not record.changes.is_empty(): notes = "%d run alteration%s" % [record.changes.size(),"s" if record.changes.size()!=1 else ""]
	notes = str(record.get("measurement_note", notes))
	_label(notes,Rect2(18,367,244,23),12,Color("42605c"))
	for i in 3:
		var key: String = ["attack_damage","max_health","armor"][i]
		var value := str(record.get("stat_labels",{}).get(key,int(record.stats.get(key,0))))
		var difference := float(record.stats.get(key,0))-float(record.base.get(key,0))
		var color := Color("20685f") if difference>0 else (Color("953f4e") if difference<0 else INK)
		_label(["ATK ","HP ","ARM "][i]+value,Rect2(12+i*86,401,86,29),14 if value.length()<6 else 11,color)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO,CARD_SIZE)
	var stock := Color("d4c69f") if STEEL_CELLS.has(record.id) else STOCK
	# Filled, integer-aligned insets keep the printed frame sharp at rest and focus.
	draw_rect(rect,INK)
	draw_rect(rect.grow(-3),Color("7f8576"))
	draw_rect(rect.grow(-5),Color("526763") if record.sealed else stock)
	draw_rect(rect.grow(-10),INK)
	draw_rect(rect.grow(-11),Color("526763") if record.sealed else stock)
	if record.sealed:
		for inset in [24.0,32.0]: draw_rect(rect.grow(-inset),Color("9eafa4"),false,1)
		draw_line(Vector2(54,130),Vector2(140,84),STOCK,2,true)
		draw_line(Vector2(140,84),Vector2(226,130),STOCK,2,true)
	else:
		var image_rect := Rect2(18,70,244,244)
		draw_rect(image_rect.grow(3),INK)
		if portrait != null and portrait_region.has_area():
			# Fit rather than stretch non-square legacy portraits.
			var fitted_size := portrait_region.size * minf(image_rect.size.x/portrait_region.size.x,image_rect.size.y/portrait_region.size.y)
			var fitted := Rect2(image_rect.get_center()-fitted_size*.5,fitted_size)
			draw_rect(image_rect,Color("434d47"))
			draw_texture_rect_region(portrait,fitted,portrait_region)
		else:
			draw_rect(image_rect,Color("718d80"))
			draw_arc(image_rect.get_center(),45,0,TAU,48,STOCK,3,true)
		draw_rect(Rect2(18,396,244,2),INK)
		draw_rect(Rect2(98,405,1,20),INK)
		draw_rect(Rect2(184,405,1,20),INK)
	if not record.sealed and (is_hovered() or has_focus()):
		var accent := Color("ffe3a1") if STEEL_CELLS.has(record.id) else Color("b7e7d4")
		for edge in [Rect2(0,0,280,3),Rect2(0,437,280,3),Rect2(0,0,3,440),Rect2(277,0,3,440)]:
			draw_rect(edge,accent)
