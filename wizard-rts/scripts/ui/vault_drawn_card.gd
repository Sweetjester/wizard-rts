extends Button
const Style := preload("res://scripts/ui/observer_theme.gd")
const ART := preload("res://assets/ui/observer_vault/portraits_drawn_v2.png")
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
	custom_minimum_size = Vector2(280,410)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	focus_mode = Control.FOCUS_ALL
	tooltip_text = str(data.get("requirement", "")) if data.sealed else "Read " + str(data.name)
	if not data.sealed:
		if CONCEPT_CELLS.has(data.id):
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

func arrange(at: Vector2, angle: float, animate: bool = false) -> void:
	in_hand = true
	home_position = at
	home_rotation = angle
	pivot_offset = Vector2(140,390)
	if motion != null: motion.kill()
	position = at
	rotation = angle
	modulate.a = 1.0
	if animate:
		position.y += 22
		modulate.a = 0
		motion = create_tween().set_parallel(true)
		motion.tween_property(self,"position",at,.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_property(self,"modulate:a",1.0,.3)

func lift(raised: bool) -> void:
	queue_redraw()
	if not in_hand or record.sealed: return
	if motion != null: motion.kill()
	z_index = 20 if raised else 0
	motion = create_tween().set_parallel(true)
	motion.tween_property(self,"position",home_position-Vector2(0,28) if raised else home_position,.16)
	motion.tween_property(self,"rotation",0.0 if raised else home_rotation,.16)

func _label(text: String, area: Rect2, font_size: int, color: Color = INK, serif: bool = false) -> void:
	var l := Style.label(text,font_size,color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	if serif: l.add_theme_font_override("font",Style.display_font())
	l.position = area.position
	l.size = area.size
	add_child(l)

func _labels() -> void:
	if record.sealed:
		_label("II" if record.tier==2 else ("III" if record.tier==3 else "IV"),Rect2(30,170,220,60),42,STOCK,true)
		_label("UNOBSERVED",Rect2(30,270,220,32),14,STOCK)
		return
	_label(str(record.name),Rect2(16,12,248,37),20 if str(record.name).length()<21 else 17,INK,true)
	_label("OBSERVER" if record.tier==0 else "TIER %d / %s" % [record.tier,"FELLED" if record.enemy else "CREATION"],Rect2(16,48,248,24),11)
	var caption := str(record.blurb)
	if caption.is_empty(): caption = str(record.role)
	if caption.length()>62: caption = caption.left(59).rsplit(" ",true,1)[0]+"..."
	_label(caption,Rect2(20,284,240,49),13)
	var notes := "Recorded form" if record.enemy else "%d in the field" % record.instances.size()
	if not record.enemy and not record.changes.is_empty(): notes = "%d run alteration%s" % [record.changes.size(),"s" if record.changes.size()!=1 else ""]
	_label(notes,Rect2(18,333,244,25),12,Color("42605c"))
	for i in 3:
		var key: String = ["attack_damage","max_health","armor"][i]
		var value := str(record.get("stat_labels",{}).get(key,int(record.stats.get(key,0))))
		var difference := float(record.stats.get(key,0))-float(record.base.get(key,0))
		var color := Color("20685f") if difference>0 else (Color("953f4e") if difference<0 else INK)
		_label(["ATK ","HP ","ARM "][i]+value,Rect2(12+i*86,365,86,30),14 if value.length()<6 else 11,color)

func _draw() -> void:
	var rect := Rect2(0,0,280,410)
	draw_style_box(Style.box(INK,INK),rect.grow(3))
	draw_rect(rect.grow(-5),Color("667d79") if record.sealed else STOCK)
	draw_rect(rect.grow(-10),INK,false,1.5)
	if record.sealed:
		for inset in [24.0,32.0]: draw_rect(rect.grow(-inset),Color("9eafa4"),false,1)
		draw_line(Vector2(54,130),Vector2(140,84),STOCK,2,true)
		draw_line(Vector2(140,84),Vector2(226,130),STOCK,2,true)
	else:
		var image_rect := Rect2(18,77,244,200)
		draw_rect(image_rect.grow(3),INK)
		if portrait != null and portrait_region.has_area(): draw_texture_rect_region(portrait,image_rect,portrait_region)
		else:
			draw_rect(image_rect,Color("718d80"))
			draw_arc(image_rect.get_center(),45,0,TAU,48,STOCK,3,true)
		draw_line(Vector2(18,359),Vector2(262,359),INK,1.5)
		draw_line(Vector2(98,366),Vector2(98,394),INK,1)
		draw_line(Vector2(184,366),Vector2(184,394),INK,1)
	if not record.sealed and (is_hovered() or has_focus()): draw_rect(rect.grow(1),Color("b7e7d4"),false,3)
