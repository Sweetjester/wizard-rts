extends Node2D

@export var owner_player_id: int = 1
@export var selection_radius: float = 36.0
@export var archetype: StringName = &"stone_face_serpent_wall"

var serpent: Node
var selected := false
var art_sprite: Sprite2D

func _ready() -> void:
	add_to_group("structures")
	add_to_group("selectable_units")
	art_sprite = Sprite2D.new()
	var part := int(get_meta("wall_part",8))
	art_sprite.texture = load("res://assets_game/units/kon/serpent/painted_v2/wall_%d.png" % part)
	art_sprite.scale = Vector2.ONE*(70.0/art_sprite.texture.get_width())
	art_sprite.position.y = -art_sprite.texture.get_height()*art_sprite.scale.y*0.5
	art_sprite.modulate = Color("93b3b8")
	add_child(art_sprite)

func get_selection_owner() -> Node: return serpent
func set_selected(value: bool) -> void:
	selected = value
	if is_instance_valid(serpent): serpent.set_selected(value)
func is_inside_selection_rect(rect: Rect2) -> bool: return rect.has_point(global_position)

func _process(_delta: float) -> void:
	if is_instance_valid(serpent): selected = serpent.selected

func configure(source_serpent: Node, player_id: int) -> void:
	serpent = source_serpent
	owner_player_id = player_id

func get_selection_kind() -> StringName:
	return &"structure"

func take_damage(amount: int, source: Node = null, damage_type: StringName = &"physical") -> void:
	if serpent != null and is_instance_valid(serpent) and serpent.has_method("take_damage"):
		serpent.take_damage(amount, source, damage_type)

func heal_damage(amount: int) -> void:
	if serpent != null and is_instance_valid(serpent) and serpent.has_method("heal_damage"):
		serpent.heal_damage(amount)

func is_alive() -> bool:
	if serpent != null and is_instance_valid(serpent) and serpent.has_method("is_alive"):
		return bool(serpent.is_alive())
	return false

func salvage_value() -> int:
	if serpent != null and is_instance_valid(serpent) and serpent.has_method("salvage_value"):
		return int(serpent.salvage_value())
	return 0
