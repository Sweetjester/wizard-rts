extends RefCounted
const Style := preload("res://scripts/ui/observer_theme.gd")

static func install(menu: Control) -> void:
	menu.theme = Style.make()
	var image := TextureRect.new()
	image.texture = preload("res://assets/ui/observer_vault/library_drawn_v2.png")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	menu.main_panel.add_theme_constant_override("separation", 8)
	for button in menu.main_panel.get_children():
		if button is Button:
			button.custom_minimum_size = Vector2(300, 48)
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 21)
			var normal := Style.box(Color(0,0,0,.10), Color("625747"))
			normal.border_width_top = 0
			normal.border_width_left = 0
			normal.border_width_right = 0
			button.add_theme_stylebox_override("normal", normal)
	menu.get_node("RootMargin/Layout/MainPanel/StartButton").text = "Begin an expedition"
	var character_scroll := menu.get_node("RootMargin/Layout/CharacterPanel/CharacterScroll") as ScrollContainer
	character_scroll.custom_minimum_size.y = 0
	character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	for card in [menu.bad_kon_card, menu.hellfire_baby_card, menu.evangalion_card]:
		card.custom_minimum_size = Vector2(300, 530)
		card.focus_mode = Control.FOCUS_ALL
		var portrait_frame: Control = card.get_node("CardLayout/PortraitFrame")
		portrait_frame.custom_minimum_size.y = 210
		portrait_frame.get_node("Portrait").custom_minimum_size.y = 210
		portrait_frame.get_node("Portrait").stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			card.add_theme_stylebox_override(state, Style.box(Color(.035,.045,.05,.94), Style.CYAN if state in ["pressed", "hover_pressed", "focus"] else Style.BRASS))
	menu.resized.connect(func(): layout(menu))
	layout(menu)

static func layout(menu: Control) -> void:
	var home: bool = menu.main_panel.visible
	var margin := menu.get_node("RootMargin") as MarginContainer
	margin.add_theme_constant_override("margin_left", 72 if menu.size.x >= 1000 else 24)
	margin.add_theme_constant_override("margin_right", 40 if menu.size.x >= 1000 else 24)
	margin.add_theme_constant_override("margin_top", 100 if home and menu.size.y >= 700 else 24)
	menu.get_node("RootMargin/Layout/Title").add_theme_font_size_override("font_size", 54 if home else 28)
	menu.get_node("RootMargin/Layout/Subtitle").visible = home
	if menu.has_node("MenuVeil"):
		menu.get_node("MenuVeil").color.a = .12 if home else .78
	for panel in [menu.audio_panel, menu.display_panel]:
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.custom_minimum_size.x = minf(560, menu.size.x - 80)
