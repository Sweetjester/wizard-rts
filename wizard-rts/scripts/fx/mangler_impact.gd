extends "res://scripts/fx/kon_spell_fx.gd"

func _ready() -> void:
	duration = 0.65 if not preview else 999999.0
	radius = maxf(radius, 1.0)
	_view = get_parent().get_node_or_null("Map3DView")
	if is_instance_valid(_view):
		_make_3d()
		visible = false

func _color() -> Color:
	return Color("f06479") if not preview or not valid_target else Color("80ece8")

func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(_spatial):
		_update_3d()
		if not preview:
			_spatial.scale = Vector3.ONE * lerpf(0.25, 1.0, minf(1.0, _age / duration))
			for ring in _rings:
				ring.visible = _age < duration * 0.85
	queue_redraw()
	if _age >= duration: queue_free()

func _draw() -> void:
	var t := clampf(_age / duration, 0.0, 1.0)
	var r := radius if preview else radius * lerpf(0.25, 1.0, t)
	var c := _color()
	c.a = 0.8 if preview else 1.0 - t
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, c, 2.5, true)
	if preview: return
	for i in 18:
		var direction := Vector2.from_angle(i * TAU / 18.0)
		draw_line(direction * r * 0.72, direction * r, c, 2.0, true)
