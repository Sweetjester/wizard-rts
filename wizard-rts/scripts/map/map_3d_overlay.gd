extends Control

# Screen-space overlay for the 3D view (added 2026-09-02).
#
# In 2D these were drawn by SelectionController._draw() in world space. The 3D
# mode hides every CanvasItem in the map subtree, which took the drag rectangle
# and the order cursor with it -- so selection and attack-move worked but were
# completely invisible, which reads as "it doesn't work".
#
# They are redrawn here instead, in a CanvasLayer that survives the suppression.
# Screen space is also the CORRECT space for these: a drag rectangle is a screen
# gesture, and projecting it onto the ground plane in a perspective view turns
# it into a trapezoid.

var drag_active := false
var drag_rect := Rect2()
var cursor_mode: StringName = &""
var cursor_position := Vector2.ZERO
# Live camera-tuning readout, debug builds only. Empty until a tuning key is
# pressed, so it costs nothing and shows nothing during normal play.
var debug_text := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_drag(active: bool, rect: Rect2) -> void:
	drag_active = active
	drag_rect = rect
	queue_redraw()

func set_cursor(mode: StringName, position_on_screen: Vector2) -> void:
	cursor_mode = mode
	cursor_position = position_on_screen
	queue_redraw()

func _draw() -> void:
	if debug_text != "":
		var font := ThemeDB.fallback_font
		var y := 24.0
		# Top-right: the HUD owns the left and bottom edges.
		for line in debug_text.split("\n"):
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var at := Vector2(size.x - width - 18.0, y)
			draw_string(font, at + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.8))
			draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#7DDDE8"))
			y += 19.0

	if cursor_mode != &"":
		var color := Color("#7DDDE8")
		if cursor_mode == &"attack_move":
			color = Color("#E85A5A")
		elif cursor_mode == &"launcher_ground":
			color = Color("#A95766")
		draw_circle(cursor_position, 11.0, Color(color, 0.18))
		draw_arc(cursor_position, 15.0, 0.0, TAU, 24, color, 2.0)
		if cursor_mode == &"attack_move":
			draw_line(cursor_position + Vector2(-8, -8), cursor_position + Vector2(8, 8), color, 2.0)
			draw_line(cursor_position + Vector2(8, -8), cursor_position + Vector2(-8, 8), color, 2.0)
		else:
			draw_arc(cursor_position, 7.0, 0.4, TAU - 0.4, 18, color, 2.0)
	if not drag_active or drag_rect.size.length() < 6.0:
		return
	draw_rect(drag_rect, Color(0.25, 0.95, 1.0, 0.12), true)
	draw_rect(drag_rect, Color(0.49, 0.87, 0.91, 0.8), false, 2.0)
