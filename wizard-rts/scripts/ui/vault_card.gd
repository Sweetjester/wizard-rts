extends Button

const ART := preload("res://assets/ui/observer_vault/card_frame.png")
const SEALED := preload("res://assets/ui/observer_vault/sealed_folio.png")
const Style := preload("res://scripts/ui/observer_theme.gd")
var record: Dictionary
var portrait: Texture2D
var portrait_region := Rect2()
static var _portrait_regions: Dictionary = {}

func setup(data: Dictionary) -> void:
	record = data
	name = "Specimen_" + str(data.id)
	custom_minimum_size = Vector2(264, 410)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	focus_mode = Control.FOCUS_ALL
	tooltip_text = str(data.get("requirement", "Read specimen")) if data.sealed else "Read " + str(data.name)
	if not data.sealed:
		var path := str(data.get("portrait", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			portrait = load(path)
			if not _portrait_regions.has(path):
				var pixels := portrait.get_image()
				var region := Rect2(pixels.get_used_rect())
				_portrait_regions[path] = region if region.has_area() else Rect2(Vector2.ZERO, portrait.get_size())
			portrait_region = _portrait_regions[path]
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)
	_build_labels()

func _place(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var l := Style.label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	if rect.position.y == .60:
		l.add_theme_font_override("font", Style.display_font())
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	l.anchor_left = rect.position.x
	l.anchor_top = rect.position.y
	l.anchor_right = rect.end.x
	l.anchor_bottom = rect.end.y
	add_child(l)

func _build_labels() -> void:
	_place(str(record.name), Rect2(.13,.60,.74,.065), 18 if str(record.name).length() < 22 else 15, Style.PAPER)
	if record.sealed:
		_place("TIER %d" % int(record.tier), Rect2(.2,.49,.6,.07), 14, Style.PAPER)
		_place(str(record.requirement), Rect2(.15,.70,.70,.16), 16, Style.PAPER)
		return
	var stats: Dictionary = record.stats
	var stat_labels: Dictionary = record.get("stat_labels", {})
	var changes: Array = record.changes
	_place("THE OBSERVER" if record.tier == 0 else "TIER %d   /   %s" % [record.tier, "FELLED" if record.enemy else "CREATION"], Rect2(.16,.69,.68,.055), 12, Style.BRASS)
	var line := "Recorded form" if record.enemy else ("%d in the field" % record.instances.size())
	if not changes.is_empty() and not record.enemy:
		line = "%d run alteration%s" % [changes.size(), "s" if changes.size() != 1 else ""]
	_place(line, Rect2(.16,.765,.68,.065), 14, Style.CYAN)
	var base: Dictionary = record.base
	var attack := str(stat_labels.get("attack_damage", int(stats.get("attack_damage", 0))))
	var health := str(stat_labels.get("max_health", int(stats.get("max_health", 0))))
	var armor := str(stat_labels.get("armor", int(stats.get("armor", 0))))
	_place(attack, Rect2(.195,.886,.17,.096), 18 if attack.length() < 4 else 12, Style.CYAN if stats.get("attack_damage",0) > base.get("attack_damage",0) else (Style.RED if stats.get("attack_damage",0) < base.get("attack_damage",0) else Style.PAPER))
	_place(health, Rect2(.39,.886,.22,.096), 18 if health.length() < 5 else 11, Style.CYAN if stats.get("max_health",0) > base.get("max_health",0) else (Style.RED if stats.get("max_health",0) < base.get("max_health",0) else Style.PAPER))
	_place(armor, Rect2(.64,.886,.17,.096), 18 if armor.length() < 4 else 12, Style.PAPER)
	_place("ATK", Rect2(.20,.956,.16,.04), 9, Style.BRASS)
	_place("HP", Rect2(.42,.956,.16,.04), 9, Style.BRASS)
	_place("ARM", Rect2(.64,.956,.16,.04), 9, Style.BRASS)

func _draw() -> void:
	draw_texture_rect(ART, Rect2(Vector2.ZERO, size), false)
	var aperture := Rect2(size * Vector2(.14,.11), size * Vector2(.72,.465))
	if record.sealed:
		draw_texture_rect(SEALED, aperture, false)
	elif portrait != null:
		var source_size := portrait_region.size
		var ratio := aperture.size.x / aperture.size.y
		var crop := source_size
		if source_size.x/source_size.y > ratio:
			crop.x = source_size.y * ratio
		else:
			crop.y = source_size.x / ratio
		draw_texture_rect_region(portrait, aperture, Rect2(portrait_region.position + (source_size-crop)*.5, crop))
	else:
		draw_rect(aperture, Color("141e21"))
		var center := aperture.get_center()
		for radius in [32.0, 40.0, 58.0]:
			draw_arc(center, radius, 0, TAU, 64, Style.BRASS.darkened(.45), 1.0, true)
		if record.sealed:
			draw_line(aperture.position, aperture.end, Style.RED.darkened(.4), 6, true)
			draw_line(Vector2(aperture.end.x,aperture.position.y), Vector2(aperture.position.x,aperture.end.y), Style.RED.darkened(.4), 6, true)
		else:
			draw_circle(center, 8, Style.CYAN)
	if is_hovered() or has_focus():
		draw_rect(Rect2(Vector2(2,2), size-Vector2(4,4)), Style.CYAN, false, 2)
