class_name RtsProjectile
extends Node2D

var source: Node2D
var target: Node2D
var damage: int = 1
var projectile_color := Color("#7DDDE8")
var speed: float = 620.0
var _life: float = 1.4
var _hit := false

func configure(new_source: Node2D, new_target: Node2D, new_damage: int, color: Color, new_speed: float) -> void:
	source = new_source
	target = new_target
	damage = new_damage
	projectile_color = color
	speed = new_speed
	z_as_relative = false
	z_index = 3600

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or target == null or not is_instance_valid(target):
		queue_free()
		return
	var aim := target.global_position + Vector2(0, -12)
	var to_target := aim - global_position
	var step := speed * delta
	if to_target.length() <= step:
		global_position = aim
		_hit_target()
		return
	global_position += to_target.normalized() * step
	rotation = to_target.angle()
	queue_redraw()

func _hit_target() -> void:
	if _hit:
		return
	_hit = true
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage, source)
	queue_free()

func _draw() -> void:
	draw_line(Vector2(-8, 0), Vector2(8, 0), projectile_color, 3.0)
	draw_circle(Vector2(8, 0), 4.0, projectile_color.lightened(0.25))
	draw_circle(Vector2(-7, 0), 3.0, projectile_color.darkened(0.35))
