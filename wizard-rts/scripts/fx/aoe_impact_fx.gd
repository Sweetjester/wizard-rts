class_name AoeImpactFx
extends Node2D

var radius := 64.0
var color := Color("#E85A5A")
var elapsed := 0.0
var life := 0.75

func configure(new_radius: float, new_color: Color) -> void:
	radius = new_radius
	color = new_color
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= life:
		queue_free()

func _draw() -> void:
	var t := clampf(elapsed / life, 0.0, 1.0)
	var alpha := 1.0 - t
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.10 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(color.r, color.g, color.b, 0.85 * alpha), 3.0)
	draw_arc(Vector2.ZERO, radius * (0.65 + t * 0.25), 0.0, TAU, 64, Color("#D6C7AE", 0.45 * alpha), 1.5)
