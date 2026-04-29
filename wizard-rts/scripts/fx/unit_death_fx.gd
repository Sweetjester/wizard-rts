class_name UnitDeathFx
extends Node2D

const LIFE_SECONDS := 5.0

var velocity := Vector2.ZERO
var angular_velocity := 0.0
var lift_velocity := 0.0
var lift := 0.0
var elapsed := 0.0
var shadow_scale := 1.0
var _sprite: Sprite2D

func configure_from_unit(unit: Node2D, source: Node = null) -> void:
	global_position = unit.global_position
	z_index = int(global_position.y) + 4
	_sprite = Sprite2D.new()
	add_child(_sprite)
	var art := unit.get_node_or_null("ArtSprite")
	if art is Sprite2D:
		_copy_sprite(art)
	else:
		_sprite.texture = null
		_sprite.scale = Vector2.ONE
	var impulse := _death_impulse(unit, source)
	velocity = impulse
	lift_velocity = randf_range(170.0, 245.0)
	angular_velocity = randf_range(-5.8, 5.8)
	shadow_scale = maxf(0.65, float(unit.get("selection_radius")) / 26.0 if _has_property(unit, "selection_radius") else 1.0)

func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / LIFE_SECONDS, 0.0, 1.0)
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
	lift += lift_velocity * delta
	lift_velocity -= 520.0 * delta
	if lift < 0.0:
		lift = 0.0
		lift_velocity = 0.0
		velocity *= 0.72
	rotation += angular_velocity * delta
	angular_velocity = move_toward(angular_velocity, 0.0, 2.3 * delta)
	if _sprite != null:
		_sprite.position = Vector2(0, -lift)
		_sprite.modulate = Color(1.0, 1.0 - t * 0.22, 1.0 - t * 0.22, 1.0 - smoothstep(0.72, 1.0, t))
	queue_redraw()
	if elapsed >= LIFE_SECONDS:
		queue_free()

func _draw() -> void:
	var alpha := 0.28 * (1.0 - smoothstep(0.6, 1.0, elapsed / LIFE_SECONDS))
	var points := PackedVector2Array()
	for i in 18:
		var angle := float(i) * TAU / 18.0
		points.append(Vector2(cos(angle) * 15.0 * shadow_scale, 10.0 + sin(angle) * 5.0 * shadow_scale))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, alpha))

func _copy_sprite(source: Sprite2D) -> void:
	_sprite.texture = source.texture
	_sprite.centered = source.centered
	_sprite.offset = source.offset
	_sprite.hframes = source.hframes
	_sprite.vframes = source.vframes
	_sprite.frame = source.frame
	_sprite.flip_h = source.flip_h
	_sprite.flip_v = source.flip_v
	_sprite.region_enabled = source.region_enabled
	_sprite.region_rect = source.region_rect
	_sprite.scale = source.scale
	_sprite.position = source.position
	_sprite.modulate = source.modulate

func _death_impulse(unit: Node2D, source: Node) -> Vector2:
	var away := Vector2(randf_range(-1.0, 1.0), randf_range(-0.7, 0.7))
	if source != null and is_instance_valid(source) and source is Node2D:
		away = unit.global_position - (source as Node2D).global_position
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	away = away.normalized()
	return away * randf_range(185.0, 310.0) + Vector2(randf_range(-25.0, 25.0), randf_range(-55.0, 25.0))

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
