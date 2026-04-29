class_name RtsProjectile
extends Node2D

const HORROR_PROJECTILE: Texture2D = preload("res://assets/fx/kon/horror_spore_projectile.png")
const BIO_LAUNCHER_PROJECTILE: Texture2D = preload("res://assets/fx/kon/bio_launcher_projectile.png")
const AOE_IMPACT_FX := preload("res://scripts/fx/aoe_impact_fx.gd")

var source: Node2D
var target: Node2D
var damage: int = 1
var projectile_color := Color("#7DDDE8")
var speed: float = 620.0
var projectile_texture: Texture2D
var source_archetype: String = ""
var aoe_radius: float = 0.0
var owner_player_id: int = -1
var _life: float = 1.4
var _hit := false
var _world: RTSWorld = null

func configure(new_source: Node2D, new_target: Node2D, new_damage: int, color: Color, new_speed: float) -> void:
	source = new_source
	target = new_target
	damage = new_damage
	projectile_color = color
	speed = new_speed
	source_archetype = _archetype_for_source(new_source)
	projectile_texture = _texture_for_source(new_source)
	owner_player_id = int(new_source.get("owner_player_id")) if new_source != null and is_instance_valid(new_source) and _has_property(new_source, "owner_player_id") else -1
	aoe_radius = 0.0
	z_as_relative = false
	z_index = 3600
	_life = 1.4
	_hit = false
	queue_redraw()

func activate(world: RTSWorld) -> void:
	_world = world
	set_process(true)

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or target == null or not is_instance_valid(target):
		_recycle()
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
	if aoe_radius > 0.0 and _world != null and is_instance_valid(_world):
		_hit_area()
	elif target != null and is_instance_valid(target) and target.has_method("take_damage"):
		var damage_source: Node = null
		if source != null and is_instance_valid(source):
			damage_source = source
		target.take_damage(damage, damage_source)
	_recycle()

func set_aoe_radius(radius: float) -> void:
	aoe_radius = radius

func _hit_area() -> void:
	_spawn_aoe_indicator()
	var damage_source: Node = null
	if source != null and is_instance_valid(source):
		damage_source = source
	for unit in _world.query_enemy_units(global_position, aoe_radius, owner_player_id):
		if not is_instance_valid(unit) or not unit.has_method("take_damage"):
			continue
		var distance := unit.global_position.distance_to(global_position)
		var falloff := clampf(1.0 - distance / maxf(1.0, aoe_radius * 1.35), 0.25, 1.0)
		unit.take_damage(maxi(1, int(float(damage) * falloff)), damage_source)

func _spawn_aoe_indicator() -> void:
	var parent: Node = _world if _world != null and is_instance_valid(_world) else get_parent()
	if parent == null:
		return
	var fx: Node2D = AOE_IMPACT_FX.new()
	parent.add_child(fx)
	fx.global_position = global_position
	if fx.has_method("configure"):
		fx.call("configure", aoe_radius, projectile_color)

func _recycle() -> void:
	source = null
	target = null
	if _world != null and is_instance_valid(_world):
		_world.recycle_projectile(self)
	else:
		queue_free()

func _draw() -> void:
	if projectile_texture != null:
		var size := Vector2(26, 26)
		if source_archetype == "bio_launcher":
			size = Vector2(38, 38)
		draw_texture_rect(projectile_texture, Rect2(-size * 0.5, size), false)
		return
	draw_line(Vector2(-8, 0), Vector2(8, 0), projectile_color, 3.0)
	draw_circle(Vector2(8, 0), 4.0, projectile_color.lightened(0.25))
	draw_circle(Vector2(-7, 0), 3.0, projectile_color.darkened(0.35))

func _texture_for_source(new_source: Node2D) -> Texture2D:
	match _archetype_for_source(new_source):
		"horror":
			return HORROR_PROJECTILE
		"bio_launcher":
			return BIO_LAUNCHER_PROJECTILE
	return null

func _archetype_for_source(new_source: Node2D) -> String:
	if new_source == null or not is_instance_valid(new_source):
		return ""
	if _has_property(new_source, "unit_archetype"):
		return str(new_source.get("unit_archetype"))
	if _has_property(new_source, "archetype"):
		return str(new_source.get("archetype"))
	return ""

func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
