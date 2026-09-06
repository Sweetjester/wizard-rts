extends RefCounted
const Style := preload("res://scripts/ui/observer_theme.gd")

static func install(menu: Control) -> void:
	menu.theme = Style.make()
	var image := preload("res://scripts/ui/library_backdrop.gd").new()
	image.name = "LibraryBackdrop"
	menu.add_child(image)
	menu.move_child(image, 1)
	var veil := ColorRect.new()
	veil.name = "MenuVeil"
	veil.color = Color(0.025,.03,.035,.12)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(veil)
	menu.move_child(veil, 2)
	var subtitle := menu.get_node("RootMargin/Layout/Subtitle") as Label
	subtitle.text = "THE OBSERVER'S CHRONICLE"
	subtitle.add_theme_color_override("font_color", Style.BRASS)
	menu.get_node("RootMargin/Layout/Title").add_theme_color_override("font_color", Style.PAPER)
	menu.get_node("RootMargin/Layout/Title").add_theme_font_override("font", Style.display_font())
	menu.get_node("RootMargin/Layout/Title").text = "Wizard RTS"
	menu.get_node("RootMargin/Layout/Title").add_theme_color_override("font_shadow_color", Color.BLACK)
	menu.get_node("RootMargin/Layout/Title").add_theme_constant_override("shadow_offset_y", 3)
	menu.main_panel.add_theme_constant_override("separation", 8)
	for button in menu.main_panel.get_children():
		if button is Button:
			button.custom_minimum_size = Vector2(300, 50)
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 21)
			var normal := Style.box(Color(0,0,0,.10), Color("625747"))
			normal.border_width_top = 0
			normal.border_width_left = 0
			normal.border_width_right = 0
			button.add_theme_stylebox_override("normal", normal)
			var hover := Style.box(Color(.18,.25,.21,.7), Style.CYAN)
			hover.border_width_left = 3
			hover.border_width_top = 0
			hover.border_width_right = 0
			button.add_theme_stylebox_override("hover", hover)
			button.add_theme_stylebox_override("focus", hover)
	menu.get_node("RootMargin/Layout/MainPanel/StartButton").text = "Begin an expedition"
	menu.get_node("RootMargin/Layout/CharacterPanel/CharacterTitle").text = "Choose your wizard"
	menu.get_node("RootMargin/Layout/MapPanel/MapTitle").text = "Choose your expedition"
	menu.begin_button.hide()
	var effects := CheckBox.new()
	effects.name = "AtmosphericEffects"
	effects.text = "Atmospheric lighting"
	effects.button_pressed = menu.get_node("/root/DisplayManager").atmospheric_effects
	effects.toggled.connect(menu.get_node("/root/DisplayManager").set_atmospheric_effects)
	menu.display_panel.add_child(effects)
	menu.display_panel.move_child(effects, menu.display_panel.get_child_count()-2)
	_compact_maps(menu)
	var character_scroll := menu.get_node("RootMargin/Layout/CharacterPanel/CharacterScroll") as ScrollContainer
	character_scroll.custom_minimum_size.y = 0
	character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	for card in [menu.bad_kon_card, menu.hellfire_baby_card, menu.evangalion_card]:
		card.custom_minimum_size = Vector2(300, 530)
		card.focus_mode = Control.FOCUS_ALL
		var portrait_frame: Control = card.get_node("CardLayout/PortraitFrame")
		portrait_frame.custom_minimum_size.y = 210
		portrait_frame.get_node("Portrait").custom_minimum_size.y = 210
		portrait_frame.get_node("Portrait").stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var lore: RichTextLabel = card.get_node("CardLayout/TextLayout/Description")
		lore.scroll_active = true
		lore.fit_content = false
		lore.custom_minimum_size = Vector2(0,120)
		lore.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.get_node("CardLayout/TextLayout/Name").add_theme_font_override("font", Style.display_font())
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			card.add_theme_stylebox_override(state, Style.box(Color(.035,.045,.05,.94), Style.CYAN if state in ["pressed", "hover_pressed", "focus"] else Style.BRASS))
		menu._set_descendants_mouse_ignore(card.get_node("CardLayout"))
		lore.mouse_filter = Control.MOUSE_FILTER_PASS
	menu.resized.connect(func(): layout(menu))
	layout(menu)

static func layout(menu: Control) -> void:
	var home: bool = menu.main_panel.visible
	var margin := menu.get_node("RootMargin") as MarginContainer
	margin.add_theme_constant_override("margin_left", 72 if menu.size.x >= 1000 else 24)
	margin.add_theme_constant_override("margin_right", 40 if menu.size.x >= 1000 else 24)
	margin.add_theme_constant_override("margin_top", 96 if home and menu.size.y >= 700 else 24)
	menu.get_node("RootMargin/Layout/Title").add_theme_font_size_override("font_size", 58 if home else 28)
	menu.get_node("RootMargin/Layout/Subtitle").visible = home
	if menu.has_node("MenuVeil"):
		menu.get_node("MenuVeil").color.a = .08 if home else .68
	for panel in [menu.audio_panel, menu.display_panel]:
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.custom_minimum_size.x = minf(560, menu.size.x - 80)
	for card in [menu.bad_kon_card, menu.hellfire_baby_card, menu.evangalion_card]:
		card.custom_minimum_size = Vector2(300, 510)
		card.get_node("CardLayout/PortraitFrame").custom_minimum_size.y = 240
		card.get_node("CardLayout/PortraitFrame/Portrait").custom_minimum_size.y = 240

static func _compact_maps(menu: Control) -> void:
	if menu.map_list == null: return
	menu.map_list.add_theme_constant_override("separation", 10)
	for entry in menu.map_list.get_children():
		if not entry is Button: continue
		entry.custom_minimum_size = Vector2(0, 100)
		entry.focus_mode = Control.FOCUS_ALL
		var body: VBoxContainer = entry.get_child(0)
		body.add_theme_constant_override("separation", 5)
		var labels := body.get_children()
		for i in labels.size():
			var label: Control = labels[i]
			if i>1:
				label.hide()
				continue
			label.custom_minimum_size.x = 0
			if label is Label:
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.add_theme_font_size_override("font_size", 23 if i==0 else 15)
				label.add_theme_color_override("font_color", Style.PAPER if i==0 else Color("aabbb0"))
				if i==0: label.add_theme_font_override("font", Style.display_font())
		menu._set_descendants_mouse_ignore(body)
