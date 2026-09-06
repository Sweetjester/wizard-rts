extends RefCounted

const INK := Color("101619")
const PAPER := Color("e2dbc9")
const BRASS := Color("ad9470")
const CYAN := Color("72d4d6")
const RED := Color("ad656e")

static func box(color: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_content_margin_all(12)
	s.set_corner_radius_all(3)
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", PAPER)
	t.set_color("default_color", "RichTextLabel", PAPER)
	for type in ["Button", "OptionButton", "CheckBox"]:
		t.set_color("font_color", type, PAPER)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, CYAN)
		t.set_stylebox("normal", type, box(INK, Color("46504d")))
		t.set_stylebox("hover", type, box(Color("24312f"), BRASS))
		t.set_stylebox("pressed", type, box(Color("24312f"), CYAN))
		t.set_stylebox("focus", type, box(Color(0,0,0,0), CYAN))
		t.set_stylebox("disabled", type, box(Color("15191a"), Color("303638")))
	t.set_stylebox("normal", "LineEdit", box(INK, BRASS))
	t.set_color("font_color", "LineEdit", PAPER)
	return t

static func label(text: String, font_size: int = 17, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func display_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Liberation Serif"])
	return font
