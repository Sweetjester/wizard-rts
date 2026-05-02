extends Node2D

@export var owner_player_id: int = 1
@export var selection_radius: float = 36.0
@export var archetype: StringName = &"stone_face_serpent_wall"

var serpent: Node

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
