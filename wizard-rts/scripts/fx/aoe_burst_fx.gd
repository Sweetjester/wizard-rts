extends Node2D

var radius := 96.0
var age := 0.0
var lifetime := 0.42
var core_color := Color("#7BC47F")
var ring_color := Color("#8B1A1F")

func configure(new_radius: float, new_core_color: Color, new_ring_color: Color) -> void:
	radius = new_radius
	core_color = new_core_color
	ring_color = new_ring_color
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / lifetime, 0.0, 1.0)
	var alpha := 1.0 - t
	draw_circle(Vector2.ZERO, radius * (0.18 + t * 0.24), Color(core_color, 0.22 * alpha))
	draw_arc(Vector2.ZERO, radius * (0.35 + t * 0.65), 0, TAU, 48, Color(ring_color, 0.95 * alpha), 4.0)
	draw_arc(Vector2.ZERO, radius * (0.18 + t * 0.4), 0, TAU, 36, Color(core_color, 0.8 * alpha), 2.0)
	for i in 8:
		var angle := float(i) * TAU / 8.0 + t * 0.6
		var start := Vector2(cos(angle), sin(angle) * 0.72) * radius * 0.16
		var end := Vector2(cos(angle), sin(angle) * 0.72) * radius * (0.55 + t * 0.38)
		draw_line(start, end, Color("#E85A5A", 0.45 * alpha), 2.0)
